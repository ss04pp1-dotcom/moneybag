/**
 * MoneyBag (মানিব্যাগ) Admin API — Cloudflare Worker. v2.0.0
 *
 * Stack : Hono.js + Cloudflare D1 (permanent SQLite storage)
 * Auth  : public app routes are open; admin routes need `x-api-key`
 *
 * v2 hardening (full list in ../CHANGELOG.md):
 *   - rate limiting (public / users-sync / admin buckets) → 429 + Retry-After
 *   - timing-safe admin key check, generic 401, optional key list (rotation)
 *   - CORS origin allowlist via ALLOWED_ORIGINS (default '*' = old behaviour)
 *   - strict payload validation for config/ads/announcements/user-sync
 *   - ETag + Cache-Control on public endpoints, no-store on admin
 *   - body-size guard (64 KB), security headers, request-id + timing
 *   - deep health (?deep=1 pings D1), /openapi.json + /docs
 *   - global push: single-flight OAuth token, batched stale-token cleanup,
 *     cursor paging (offset kept for backward compatibility)
 *
 * Public (app-facing):
 *   GET  /                     → service info
 *   GET  /health               → health check (?deep=1 checks D1)
 *   GET  /api/v1/app           → one-shot { config, ads, announcements }
 *   GET  /api/v1/config        → app config
 *   GET  /api/v1/ads           → ads control
 *   GET  /api/v1/announcements → active announcements
 *   POST /api/v1/users/sync    → upsert user + FCM token (Google Sign-In)
 *   GET  /docs, /openapi.json  → API documentation
 *
 * Admin (x-api-key header):
 *   GET    /api/v1/admin/login            → key check (dashboard login)
 *   GET    /api/v1/admin/overview         → dashboard counters
 *   GET    /api/v1/admin/users            → users list (+search/paging)
 *   POST   /api/v1/admin/users/push       → targeted push (single user)
 *   POST   /api/v1/admin/push             → global push (paged, 40/batch)
 *   GET    /api/v1/admin/push/log         → recent push history
 *   GET    /api/v1/admin/config           → full config (edit form)
 *   PUT    /api/v1/admin/config           → update app config (validated)
 *   GET    /api/v1/admin/ads              → full ads settings (edit form)
 *   PUT    /api/v1/admin/ads              → update ads (validated)
 *   GET    /api/v1/admin/announcements    → all announcements
 *   POST   /api/v1/admin/announcements    → create (validated)
 *   PATCH  /api/v1/admin/announcements/:id/toggle
 *   DELETE /api/v1/admin/announcements/:id
 */

import { Hono } from 'hono';
import type { Context, MiddlewareHandler } from 'hono';
import { cors } from 'hono/cors';
import { FcmConfigError, sendFcm } from './fcm';
import {
  requestId,
  securityHeaders,
  trailingSlash,
  bodySizeLimit,
  rateLimit,
  sweepBuckets,
  adminAuth,
} from './middleware';
import {
  loadState,
  saveKey,
  announcementOut,
  announcementActive,
  makeEtag,
  nowSec,
} from './state';
import {
  validateConfig,
  validateAds,
  validateAnnouncement,
  validateUserSync,
  escapeLike,
} from './validate';
import { openApiJson, docsHtml } from './openapi';
import type { WorkerBindings } from './middleware';

interface Bindings extends WorkerBindings {
  DB: D1Database;
  FCM_SERVICE_ACCOUNT: string;
  APP_VERSION?: string;
}

type AppEnv = { Bindings: Bindings; Variables: { requestId: string } };

const app = new Hono<AppEnv>();

// ── global middleware ───────────────────────────────────────────────────────

app.use('/*', requestId); // x-request-id + server-timing + structured log
app.use('/*', async (_c, next) => {
  sweepBuckets();
  return next();
});
app.use('/*', trailingSlash); // GET /api/v1/config/ → 308 → /api/v1/config
app.use('/*', bodySizeLimit(64 * 1024));

// CORS — same default as before (any origin), but an allowlist can be set
// via the ALLOWED_ORIGINS var ("https://panel.example.com,https://x").
app.use('/*', async (c, next) => {
  const list = (c.env.ALLOWED_ORIGINS || '')
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean);
  return cors({
    origin: list.length ? list : '*',
    allowMethods: ['GET', 'HEAD', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
    allowHeaders: ['Content-Type', 'x-api-key', 'x-request-id'],
    exposeHeaders: [
      'X-Request-Id',
      'X-RateLimit-Limit',
      'X-RateLimit-Remaining',
      'Retry-After',
    ],
    maxAge: 86_400,
  })(c, next);
});

app.use('/*', securityHeaders);

// ── rate limiting ───────────────────────────────────────────────────────────

const num = (v: string | undefined, dflt: number): number => {
  const n = Number(v);
  return Number.isFinite(n) && n > 0 ? Math.floor(n) : dflt;
};

// Public app endpoints (NOT admin — those get their own, bigger bucket).
app.use('/api/v1/*', async (c, next) => {
  if (c.req.path.startsWith('/api/v1/admin')) return next();
  return rateLimit('pub', num(c.env.RL_PUBLIC_PER_MIN, 240))(c, next);
});

// users/sync is an unauthenticated WRITE endpoint — strict per-IP limit.
app.use('/api/v1/users/sync', async (c, next) =>
  rateLimit('sync', num(c.env.RL_SYNC_PER_MIN, 30))(c, next)
);

// ── helpers ─────────────────────────────────────────────────────────────────

interface UserRow {
  uid: string;
  email: string | null;
  name: string | null;
  photo_url: string | null;
  fcm_token: string | null;
  platform: string | null;
  app_version: string | null;
  last_login: number;
  created: number;
}

function fcmError(c: Context, e: unknown): Response {
  const msg = e instanceof FcmConfigError ? e.message : `FCM error: ${String(e)}`;
  return c.json({ error: msg }, 503);
}

/** Read JSON object body safely (null on malformed/missing/wrong shape). */
async function readJson(c: Context): Promise<Record<string, unknown> | null> {
  try {
    const v = await c.req.json();
    if (v && typeof v === 'object' && !Array.isArray(v)) {
      return v as Record<string, unknown>;
    }
    return null;
  } catch {
    return null;
  }
}

const PUBLIC_CACHE = 'public, max-age=30, stale-while-revalidate=120';
const NO_STORE = 'no-store';

function fieldErr(errors: Record<string, string>): string {
  return 'invalid fields: ' + Object.keys(errors).join(', ');
}

/** ETag / If-None-Match → 304 support for public GETs. */
function etagResponse(c: Context, body: unknown): Response {
  const etag = makeEtag(body);
  const inm = c.req.header('if-none-match');
  if (inm && inm.trim() === etag) {
    return new Response(null, {
      status: 304,
      headers: { ETag: etag, 'Cache-Control': PUBLIC_CACHE },
    });
  }
  return c.json(body, 200, { ETag: etag, 'Cache-Control': PUBLIC_CACHE });
}

// ── public routes ───────────────────────────────────────────────────────────

app.get('/', (c) =>
  c.json(
    {
      ok: true,
      name: 'moneybag-admin-api',
      version: c.env.APP_VERSION ?? '2.0.0',
      stack: 'cloudflare-worker + hono + d1',
      docs: '/docs',
      time: new Date().toISOString(),
    },
    200,
    { 'Cache-Control': NO_STORE }
  )
);

app.get('/health', async (c) => {
  if (c.req.query('deep') !== '1') {
    return c.json({ ok: true, time: new Date().toISOString() }, 200, {
      'Cache-Control': NO_STORE,
    });
  }
  try {
    const ping = Promise.race([
      c.env.DB.prepare('SELECT 1 AS ok').first(),
      new Promise((_, rej) => setTimeout(() => rej(new Error('db timeout')), 3500)),
    ]);
    const row = (await ping) as { ok: number } | null;
    if (!row || row.ok !== 1) throw new Error('bad ping');
    return c.json({ ok: true, db: 'up', time: new Date().toISOString() }, 200, {
      'Cache-Control': NO_STORE,
    });
  } catch {
    return c.json({ ok: false, db: 'down', time: new Date().toISOString() }, 503, {
      'Cache-Control': NO_STORE,
    });
  }
});

app.get('/docs', (c) => {
  c.header('Cache-Control', 'public, max-age=3600');
  return c.html(docsHtml);
});

app.get('/openapi.json', (c) => {
  c.header('Cache-Control', 'public, max-age=3600');
  return c.json(openApiJson);
});

app.get('/api/v1/app', async (c) => {
  const state = await loadState(c.env.DB);
  const anns = state.announcements.filter(announcementActive);
  return etagResponse(c, {
    config: state.config,
    ads: state.ads,
    announcements: anns.map(announcementOut),
  });
});

app.get('/api/v1/config', async (c) => {
  const state = await loadState(c.env.DB);
  return etagResponse(c, state.config);
});

app.get('/api/v1/ads', async (c) => {
  const state = await loadState(c.env.DB);
  return etagResponse(c, state.ads);
});

app.get('/api/v1/announcements', async (c) => {
  const state = await loadState(c.env.DB);
  const anns = state.announcements.filter(announcementActive);
  return etagResponse(c, anns.map(announcementOut));
});

/**
 * POST /api/v1/users/sync — called by the app right after Google Sign-In
 * (and whenever the FCM token refreshes).
 *
 * Body: { uid, email, name, photoUrl?, fcmToken?, platform?, appVersion? }
 * A token is bound to exactly one user; an old owner loses it.
 * v2: shape-validated + rate-limited (was: write-anything, unlimited).
 */
app.post('/api/v1/users/sync', async (c) => {
  const b = await readJson(c);
  if (!b) return c.json({ error: 'invalid JSON body' }, 400);

  const v = validateUserSync(b);
  if (!v.ok) {
    return c.json({ error: Object.values(v.errors)[0], fields: v.errors }, 400);
  }

  const uid = v.uid;
  const email = b.email == null ? '' : String(b.email).slice(0, 320);
  const name = b.name == null ? '' : String(b.name).slice(0, 200);
  const photoUrl =
    b.photoUrl == null || b.photoUrl === '' ? null : String(b.photoUrl).slice(0, 500);
  const fcmToken =
    b.fcmToken == null || b.fcmToken === '' ? null : String(b.fcmToken).slice(0, 512);
  const platform = b.platform == null ? '' : String(b.platform).slice(0, 20);
  const appVersion = b.appVersion == null ? '' : String(b.appVersion).slice(0, 20);
  const t = nowSec();

  if (fcmToken) {
    // The token moved to this account — clear it from any other user.
    await c.env.DB
      .prepare('UPDATE users SET fcm_token = NULL WHERE fcm_token = ? AND uid != ?')
      .bind(fcmToken, uid)
      .run();
  }

  await c.env.DB
    .prepare(
      `INSERT INTO users (uid, email, name, photo_url, fcm_token, platform, app_version, last_login, created)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
       ON CONFLICT(uid) DO UPDATE SET
         email = excluded.email,
         name = excluded.name,
         photo_url = excluded.photo_url,
         fcm_token = COALESCE(excluded.fcm_token, users.fcm_token),
         platform = excluded.platform,
         app_version = excluded.app_version,
         last_login = excluded.last_login`
    )
    .bind(uid, email, name, photoUrl, fcmToken, platform, appVersion, t, t)
    .run();

  return c.json({ ok: true }, 200, { 'Cache-Control': NO_STORE });
});

// ── admin group (x-api-key) ─────────────────────────────────────────────────

const admin = new Hono<{ Bindings: Bindings; Variables: { requestId: string } }>();

admin.use('*', async (c, next) =>
  rateLimit('admin', num(c.env.RL_ADMIN_PER_MIN, 600))(c, next)
);
admin.use('*', adminAuth as MiddlewareHandler);

admin.get('/login', (c) =>
  c.json({ ok: true, time: new Date().toISOString() }, 200, {
    'Cache-Control': NO_STORE,
  })
);

// Full config/ads for the dashboard edit forms.
admin.get('/config', async (c) => {
  const state = await loadState(c.env.DB);
  return c.json(state.config, 200, { 'Cache-Control': NO_STORE });
});

admin.get('/ads', async (c) => {
  const state = await loadState(c.env.DB);
  return c.json(state.ads, 200, { 'Cache-Control': NO_STORE });
});

admin.get('/overview', async (c) => {
  const state = await loadState(c.env.DB);

  const [users, withToken, pushReachable] = await Promise.all([
    c.env.DB.prepare('SELECT COUNT(*) AS n FROM users').first<{ n: number }>(),
    c.env.DB
      .prepare('SELECT COUNT(*) AS n FROM users WHERE fcm_token IS NOT NULL')
      .first<{ n: number }>(),
    c.env.DB
      .prepare('SELECT COALESCE(SUM(sent), 0) AS n FROM push_log')
      .first<{ n: number }>(),
  ]);
  const anns = state.announcements;

  return c.json(
    {
      users: users?.n ?? 0,
      usersWithToken: withToken?.n ?? 0,
      pushSentTotal: pushReachable?.n ?? 0,
      announcementsTotal: anns.length,
      announcementsActive: anns.filter(announcementActive).length,
      ads: {
        enabled: state.ads.enabled === true,
        testMode: state.ads.testMode !== false,
      },
      config: {
        maintenance: state.config.maintenance === true,
        forceUpdate: state.config.forceUpdate === true,
        minVersion: state.config.minVersion,
        latestVersion: state.config.latestVersion,
      },
    },
    200,
    { 'Cache-Control': NO_STORE }
  );
});

admin.get('/users', async (c) => {
  const limit = Math.min(Number(c.req.query('limit') ?? 100) || 100, 500);
  const offset = Math.max(Number(c.req.query('offset') ?? 0) || 0, 0);
  const search = (c.req.query('search') ?? '').trim().toLowerCase();

  let total: { n: number } | null;
  let rows: UserRow[];

  if (search) {
    // LIKE wildcards from user input are escaped (searching "100%" no longer
    // matches everything); ESCAPE '\' makes the backslash meaningful.
    const like = `%${escapeLike(search)}%`;
    const where = `LOWER(email) LIKE ?1 ESCAPE '\\' OR LOWER(name) LIKE ?1 ESCAPE '\\' OR LOWER(uid) LIKE ?1 ESCAPE '\\'`;
    const [t, r] = await Promise.all([
      c.env.DB
        .prepare(`SELECT COUNT(*) AS n FROM users WHERE ${where}`)
        .bind(like)
        .first<{ n: number }>(),
      c.env.DB
        .prepare(
          `SELECT * FROM users WHERE ${where} ORDER BY last_login DESC LIMIT ?2 OFFSET ?3`
        )
        .bind(like, limit, offset)
        .all<UserRow>(),
    ]);
    total = t;
    rows = r.results;
  } else {
    const [t, r] = await Promise.all([
      c.env.DB.prepare('SELECT COUNT(*) AS n FROM users').first<{ n: number }>(),
      c.env.DB
        .prepare('SELECT * FROM users ORDER BY last_login DESC LIMIT ?1 OFFSET ?2')
        .bind(limit, offset)
        .all<UserRow>(),
    ]);
    total = t;
    rows = r.results;
  }

  return c.json(
    {
      total: total?.n ?? 0,
      users: rows.map((u) => ({
        uid: u.uid,
        email: u.email ?? '',
        name: u.name ?? '',
        photoUrl: u.photo_url ?? '',
        hasToken: u.fcm_token != null,
        platform: u.platform ?? '',
        appVersion: u.app_version ?? '',
        lastLogin: u.last_login,
        created: u.created,
      })),
    },
    200,
    { 'Cache-Control': NO_STORE }
  );
});

/** Targeted push: send to ONE user by uid. */
admin.post('/users/push', async (c) => {
  const b = await readJson(c);
  if (!b || !b.uid || !b.title || !b.body) {
    return c.json({ error: 'uid, title and body are required' }, 400);
  }
  const uid = String(b.uid).slice(0, 128);
  const title = String(b.title).slice(0, 200);
  const body = String(b.body).slice(0, 1000);

  const user = await c.env.DB
    .prepare('SELECT uid, email, fcm_token FROM users WHERE uid = ?')
    .bind(uid)
    .first<{ uid: string; email: string | null; fcm_token: string | null }>();

  if (!user) return c.json({ error: 'user not found' }, 404);
  if (!user.fcm_token) {
    return c.json(
      { error: 'this user has no FCM token (app not synced or notifications off)' },
      409
    );
  }

  try {
    const r = await sendFcm(c.env.FCM_SERVICE_ACCOUNT, user.fcm_token, title, body);
    if (!r.ok && r.stale) {
      await c.env.DB
        .prepare('UPDATE users SET fcm_token = NULL WHERE uid = ?')
        .bind(uid)
        .run();
    }
    await c.env.DB
      .prepare(
        'INSERT INTO push_log (target, title, body, sent, failed, created) VALUES (?, ?, ?, ?, ?, ?)'
      )
      .bind(user.email ?? uid, title, body, r.ok ? 1 : 0, r.ok ? 0 : 1, nowSec())
      .run();
    return c.json({ ok: r.ok, sent: r.ok ? 1 : 0, error: r.error }, 200, {
      'Cache-Control': NO_STORE,
    });
  } catch (e) {
    return fcmError(c, e);
  }
});

/**
 * Global push — sends to all users that have an FCM token.
 *
 * Free-plan subrequest budget per call: 1 OAuth token (single-flight) + ≤40
 * FCM sends + 2 SELECTs + 1 batched stale cleanup + 1 push_log insert = 45 < 50.
 *
 * Paging modes (both supported):
 *   - offset  : body {title, body, offset} — the original contract.
 *   - cursor  : body {title, body, cursor: {lastLogin, uid}} — stable paging
 *               that cannot skip/duplicate users when last_login changes
 *               mid-broadcast. Response carries nextCursor when cursor mode
 *               is used, nextOffset otherwise.
 */
admin.post('/push', async (c) => {
  const b = (await readJson(c)) ?? {};
  const title = String(b.title ?? '').slice(0, 200);
  const body = String(b.body ?? '').slice(0, 1000);
  const limit = Math.min(Math.max(Number(b.limit ?? 40) || 40, 1), 45);
  const offset = Math.max(Number(b.offset ?? 0) || 0, 0);
  const cursor =
    b.cursor && typeof b.cursor === 'object'
      ? (b.cursor as { lastLogin?: unknown; uid?: unknown })
      : null;
  const cursorLogin = Number(cursor?.lastLogin);
  const cursorUid = cursor?.uid == null ? null : String(cursor.uid).slice(0, 128);

  if (!title || !body) {
    return c.json({ error: 'title and body are required' }, 400);
  }
  const useCursor = cursor != null && Number.isFinite(cursorLogin) && cursorUid != null;

  const totalRow = await c.env.DB
    .prepare('SELECT COUNT(*) AS n FROM users WHERE fcm_token IS NOT NULL')
    .first<{ n: number }>();
  const total = totalRow?.n ?? 0;

  const pageSql = useCursor
    ? `SELECT uid, fcm_token, last_login FROM users
       WHERE fcm_token IS NOT NULL AND (last_login, uid) < (?1, ?2)
       ORDER BY last_login DESC, uid DESC LIMIT ?3`
    : `SELECT uid, fcm_token FROM users
       WHERE fcm_token IS NOT NULL ORDER BY last_login DESC LIMIT ?1 OFFSET ?2`;

  const stmt = useCursor
    ? c.env.DB.prepare(pageSql).bind(cursorLogin, cursorUid, limit)
    : c.env.DB.prepare(pageSql).bind(limit, offset);
  const rows = (await stmt.all<{ uid: string; fcm_token: string; last_login?: number }>())
    .results;

  if (rows.length === 0) {
    return c.json(
      {
        ok: true,
        sent: 0,
        failed: 0,
        total,
        nextOffset: null,
        nextCursor: null,
        message: 'no more users with FCM tokens',
      },
      200,
      { 'Cache-Control': NO_STORE }
    );
  }

  let sent = 0;
  let failed = 0;
  const staleTokens: string[] = [];

  try {
    const results = await Promise.all(
      rows.map((r) => sendFcm(c.env.FCM_SERVICE_ACCOUNT, r.fcm_token, title, body))
    );
    results.forEach((r, i) => {
      if (r.ok) sent++;
      else {
        failed++;
        if (r.stale) staleTokens.push(rows[i].fcm_token);
      }
    });
  } catch (e) {
    return fcmError(c, e);
  }

  // Drop tokens FCM says are unregistered — ONE batched statement
  // (was N single-row UPDATEs that could blow the subrequest limit).
  if (staleTokens.length > 0) {
    const ph = staleTokens.map((_, i) => `?${i + 1}`).join(', ');
    await c.env.DB
      .prepare(`UPDATE users SET fcm_token = NULL WHERE fcm_token IN (${ph})`)
      .bind(...staleTokens)
      .run();
  }

  await c.env.DB
    .prepare(
      'INSERT INTO push_log (target, title, body, sent, failed, created) VALUES (?, ?, ?, ?, ?, ?)'
    )
    .bind('all', title, body, sent, failed, nowSec())
    .run();

  const last = rows[rows.length - 1];
  const nextCursor =
    useCursor && last?.last_login != null && last?.uid != null
      ? { lastLogin: last.last_login, uid: last.uid }
      : null;
  const rawNextOffset = useCursor ? null : offset + rows.length;
  const nextOffset = rawNextOffset != null && rawNextOffset < total ? rawNextOffset : null;

  return c.json(
    {
      ok: failed === 0,
      sent,
      failed,
      total,
      nextOffset,
      nextCursor,
    },
    200,
    { 'Cache-Control': NO_STORE }
  );
});

admin.get('/push/log', async (c) => {
  const rows = (
    await c.env.DB
      .prepare(
        'SELECT id, target, title, body, sent, failed, created FROM push_log ORDER BY created DESC LIMIT 25'
      )
      .all<{
        id: number;
        target: string;
        title: string;
        body: string;
        sent: number;
        failed: number;
        created: number;
      }>()
  ).results;
  return c.json({ pushes: rows }, 200, { 'Cache-Control': NO_STORE });
});

admin.put('/config', async (c) => {
  const b = await readJson(c);
  if (!b) return c.json({ error: 'invalid JSON body' }, 400);
  const v = validateConfig(b);
  if (!v.ok) return c.json({ error: fieldErr(v.errors), fields: v.errors }, 400);
  const state = await loadState(c.env.DB);
  const merged = { ...state.config, ...v.clean };
  delete (merged as Record<string, unknown>).error;
  await saveKey(c.env.DB, 'config', merged);
  return c.json({ ok: true, config: merged }, 200, { 'Cache-Control': NO_STORE });
});

admin.put('/ads', async (c) => {
  const b = await readJson(c);
  if (!b) return c.json({ error: 'invalid JSON body' }, 400);
  const v = validateAds(b);
  if (!v.ok) return c.json({ error: fieldErr(v.errors), fields: v.errors }, 400);
  const state = await loadState(c.env.DB);
  const merged = { ...state.ads, ...v.clean };
  await saveKey(c.env.DB, 'ads', merged);
  return c.json({ ok: true, ads: merged }, 200, { 'Cache-Control': NO_STORE });
});

admin.get('/announcements', async (c) => {
  const state = await loadState(c.env.DB);
  return c.json(state.announcements.map(announcementOut), 200, {
    'Cache-Control': NO_STORE,
  });
});

admin.post('/announcements', async (c) => {
  const b = await readJson(c);
  if (!b) return c.json({ error: 'invalid JSON body' }, 400);
  const v = validateAnnouncement(b);
  if (!v.ok) return c.json({ error: fieldErr(v.errors), fields: v.errors }, 400);
  const item = {
    id: crypto.randomUUID(),
    title: v.clean.title as string,
    body: v.clean.body as string,
    kind: v.clean.kind as string,
    active: v.clean.active === true ? 1 : 0,
    starts_at: (v.clean.startsAt as string | null) ?? null,
    ends_at: (v.clean.endsAt as string | null) ?? null,
    created: nowSec(),
  };
  await c.env.DB
    .prepare(
      `INSERT INTO announcements (id, title, body, kind, active, starts_at, ends_at, created)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?)`
    )
    .bind(
      item.id,
      item.title,
      item.body,
      item.kind,
      item.active,
      item.starts_at,
      item.ends_at,
      item.created
    )
    .run();
  return c.json(
    { ok: true, announcement: { ...item, active: item.active === 1 } },
    201,
    { 'Cache-Control': NO_STORE }
  );
});

admin.patch('/announcements/:id/toggle', async (c) => {
  const id = c.req.param('id');
  const row = await c.env.DB
    .prepare('SELECT active FROM announcements WHERE id = ?')
    .bind(id)
    .first<{ active: number }>();
  if (!row) return c.json({ error: 'not found' }, 404);
  const next = row.active === 1 ? 0 : 1;
  await c.env.DB
    .prepare('UPDATE announcements SET active = ? WHERE id = ?')
    .bind(next, id)
    .run();
  return c.json({ ok: true, active: next === 1 }, 200, { 'Cache-Control': NO_STORE });
});

admin.delete('/announcements/:id', async (c) => {
  const id = c.req.param('id');
  const res = await c.env.DB
    .prepare('DELETE FROM announcements WHERE id = ?')
    .bind(id)
    .run();
  return c.json(
    { ok: true, deleted: res.meta.changes ?? 0 },
    200,
    { 'Cache-Control': NO_STORE }
  );
});

app.route('/api/v1/admin', admin);

// ── fallthrough ─────────────────────────────────────────────────────────────

app.all('*', (c) => c.json({ error: 'not found' }, 404));

app.onError((err, c) => {
  console.error(
    JSON.stringify({
      lvl: 'error',
      rid: (c.get('requestId') as string | undefined) ?? 'n/a',
      path: c.req.path,
      err: err instanceof Error ? `${err.name}: ${err.message}` : String(err),
    })
  );
  return c.json(
    {
      error: 'internal error',
      requestId: (c.get('requestId') as string | undefined) ?? null,
    },
    500
  );
});

export default app;
