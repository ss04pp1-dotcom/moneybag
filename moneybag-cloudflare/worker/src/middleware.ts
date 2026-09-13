/**
 * Middleware: request-id + timing, security headers, body-size guard,
 * in-memory rate limiting and timing-safe admin key auth.
 *
 * The rate limiter is per-isolate (best effort) — for hard guarantees also
 * enable a Cloudflare WAF rate-limiting rule in front of the Worker.
 */

import type { Context, MiddlewareHandler } from 'hono';

export interface WorkerBindings {
  ADMIN_API_KEY: string;
  ADMIN_API_KEYS?: string; // optional comma-separated extra keys (v2)
  ALLOWED_ORIGINS?: string;
  RL_PUBLIC_PER_MIN?: string;
  RL_SYNC_PER_MIN?: string;
  RL_ADMIN_PER_MIN?: string;
}

export type WorkerEnv = {
  Bindings: WorkerBindings;
  Variables: { requestId: string };
};

// ── request id + server timing ─────────────────────────────────────────────

export const requestId: MiddlewareHandler<WorkerEnv> = async (c, next) => {
  const id =
    (c.req.header('x-request-id') || '').slice(0, 64) || crypto.randomUUID();
  c.set('requestId', id);
  const start = Date.now();
  await next();
  const dur = Date.now() - start;
  try {
    c.header('x-request-id', id);
    c.header('Server-Timing', `app;dur=${dur}`);
  } catch {
    /* response already committed (streaming) — ignore */
  }
  console.log(
    JSON.stringify({
      lvl: 'info',
      rid: id,
      method: c.req.method,
      path: c.req.path,
      status: c.res.status,
      durMs: dur,
      ip: clientIp(c),
    })
  );
};

// ── security headers (applied to every response) ───────────────────────────

export const securityHeaders: MiddlewareHandler = async (c, next) => {
  await next();
  c.header('X-Content-Type-Options', 'nosniff');
  c.header('X-Frame-Options', 'DENY');
  c.header('Referrer-Policy', 'no-referrer');
  c.header('Permissions-Policy', 'camera=(), microphone=(), geolocation=()');
};

// ── client ip ──────────────────────────────────────────────────────────────

export function clientIp(c: Context): string {
  return (c.req.header('cf-connecting-ip') || '').slice(0, 64) || 'unknown';
}

// ── body size guard (rejects BEFORE reading the body) ─────────────────────

export function bodySizeLimit(bytes: number): MiddlewareHandler {
  return async (c, next) => {
    if (!['GET', 'HEAD'].includes(c.req.method)) {
      const len = Number(c.req.header('content-length') || 0);
      if (len > bytes) {
        return c.json({ error: `payload too large (max ${bytes} bytes)` }, 413);
      }
    }
    await next();
  };
}

// ── trailing-slash normalisation (GET/HEAD → 308) ──────────────────────────

export const trailingSlash: MiddlewareHandler = async (c, next) => {
  const p = c.req.path;
  if (
    (c.req.method === 'GET' || c.req.method === 'HEAD') &&
    p.length > 1 &&
    p.endsWith('/')
  ) {
    const url = new URL(c.req.url);
    url.pathname = p.replace(/\/+$/, '') || '/';
    return c.redirect(url.toString(), 308);
  }
  await next();
};

// ── rate limiting (fixed window, per isolate) ──────────────────────────────

interface Window {
  count: number;
  resetAt: number;
}

const MAX_TRACKED_KEYS = 10_000; // memory guard
const buckets = new Map<string, Window>();

export interface RateLimitResult {
  allowed: boolean;
  limit: number;
  remaining: number;
  resetAt: number; // epoch ms
}

/** Testable: `now` injectable. */
export function checkRate(
  key: string,
  limit: number,
  windowMs: number,
  now: number = Date.now()
): RateLimitResult {
  let w = buckets.get(key);
  if (!w || w.resetAt <= now) {
    if (buckets.size >= MAX_TRACKED_KEYS) {
      // evict the oldest expired-ish entry cheaply
      const first = buckets.keys().next().value;
      if (first !== undefined) buckets.delete(first);
    }
    w = { count: 0, resetAt: now + windowMs };
    buckets.set(key, w);
  }
  w.count += 1;
  const resetAt = w.resetAt;
  if (w.count > limit) {
    return { allowed: false, limit, remaining: 0, resetAt };
  }
  return { allowed: true, limit, remaining: Math.max(0, limit - w.count), resetAt };
}

export function rateLimit(
  bucket: string,
  limit: number,
  windowMs = 60_000
): MiddlewareHandler {
  return async (c, next) => {
    const r = checkRate(`${bucket}:${clientIp(c)}`, limit, windowMs);
    c.header('X-RateLimit-Limit', String(r.limit));
    c.header('X-RateLimit-Remaining', String(r.remaining));
    if (!r.allowed) {
      const retry = Math.max(1, Math.ceil((r.resetAt - Date.now()) / 1000));
      c.header('Retry-After', String(retry));
      return c.json(
        { error: `rate limited — retry after ${retry}s` },
        429
      );
    }
    await next();
  };
}

// Periodic janitor so the map never grows unbounded between evictions.
let lastSweep = 0;
export function sweepBuckets(now: number = Date.now()): number {
  if (now - lastSweep < 60_000) return 0;
  lastSweep = now;
  let removed = 0;
  for (const [k, w] of buckets) {
    if (w.resetAt <= now) {
      buckets.delete(k);
      removed++;
    }
  }
  return removed;
}

// ── timing-safe string compare (via SHA-256 digests) ───────────────────────

export async function timingSafeEqual(a: string, b: string): Promise<boolean> {
  const enc = new TextEncoder();
  const [da, db] = await Promise.all([
    crypto.subtle.digest('SHA-256', enc.encode(a)),
    crypto.subtle.digest('SHA-256', enc.encode(b)),
  ]);
  const ha = new Uint8Array(da);
  const hb = new Uint8Array(db);
  if (ha.length !== hb.length) return false;
  let diff = 0;
  for (let i = 0; i < ha.length; i++) diff |= ha[i] ^ hb[i];
  return diff === 0;
}

/**
 * Auth for admin routes. Accepts the legacy `ADMIN_API_KEY` secret plus an
 * optional comma-separated `ADMIN_API_KEYS` for key rotation. Comparison is
 * timing-safe and the error is deliberately generic.
 */
export const adminAuth: MiddlewareHandler<WorkerEnv> = async (c, next) => {
  const keys = [
    c.env.ADMIN_API_KEY,
    ...(c.env.ADMIN_API_KEYS || '')
      .split(',')
      .map((s) => s.trim())
      .filter(Boolean),
  ].filter(Boolean);

  const given = c.req.header('x-api-key') || '';
  if (!given || keys.length === 0) {
    return c.json({ error: 'unauthorized' }, 401);
  }
  let ok = false;
  for (const k of keys) {
    if (await timingSafeEqual(given, k)) {
      ok = true;
      break;
    }
  }
  if (!ok) {
    // tiny delay to blunt brute-force even further
    await new Promise((r) => setTimeout(r, 20));
    return c.json({ error: 'unauthorized' }, 401);
  }
  await next();
};
