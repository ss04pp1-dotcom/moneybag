/**
 * app_config state loader with a short micro-cache + ETag.
 *
 * Every app launch calls /api/v1/app — previously that meant 2 D1 reads per
 * request with zero caching. The values change rarely, so a 20 s in-isolate
 * cache + ETag/304 support cuts D1 reads dramatically while staying
 * eventually-consistent for the mobile clients.
 */

export interface AppConfig {
  latestVersion: string;
  minVersion: string;
  forceUpdate: boolean;
  maintenance: boolean;
  message: null | { title: string; body: string };
}

export interface AdsConfig {
  enabled: boolean;
  testMode: boolean;
  admobAppId: string;
  bannerUnitId: string;
  interstitialUnitId: string;
  rewardedUnitId: string;
  refreshMinutes: number;
}

export const DEFAULT_CONFIG: AppConfig = {
  latestVersion: '2.0.3',
  minVersion: '1.0.0',
  forceUpdate: false,
  maintenance: false,
  message: null,
};

export const DEFAULT_ADS: AdsConfig = {
  enabled: false,
  testMode: true,
  admobAppId: 'ca-app-pub-3940256099942544~3347511713',
  bannerUnitId: 'ca-app-pub-3940256099942544/6300978111',
  interstitialUnitId: 'ca-app-pub-3940256099942544/1033173712',
  rewardedUnitId: 'ca-app-pub-3940256099942544/5224354917',
  refreshMinutes: 30,
};

export interface AnnouncementRow {
  id: string;
  title: string;
  body: string;
  kind: string;
  active: number;
  starts_at: string | null;
  ends_at: string | null;
  created: number;
}

export interface AppState {
  config: AppConfig;
  ads: AdsConfig;
  announcements: AnnouncementRow[];
}

const CACHE_TTL_MS = 20_000;
let cache: { state: AppState; etag: string; expires: number } | null = null;

export const nowSec = () => Math.floor(Date.now() / 1000);

/**
 * Read-side sanitising: values written by the old "merge-anything" worker
 * (nulls, numbers, legacy junk) are normalised to the shapes the app and
 * dashboard expect, so the edit forms never PUT a wrong type back.
 */
export function sanitizeConfig(v: Record<string, unknown>): AppConfig {
  const message =
    v.message && typeof v.message === 'object'
      ? {
          title: String((v.message as Record<string, unknown>).title ?? ''),
          body: String((v.message as Record<string, unknown>).body ?? ''),
        }
      : null;
  return {
    latestVersion: v.latestVersion == null || typeof v.latestVersion !== 'string' ? DEFAULT_CONFIG.latestVersion : v.latestVersion,
    minVersion: v.minVersion == null || typeof v.minVersion !== 'string' ? DEFAULT_CONFIG.minVersion : v.minVersion,
    forceUpdate: v.forceUpdate === true,
    maintenance: v.maintenance === true,
    message: message && (message.title || message.body) ? message : null,
  };
}

export function sanitizeAds(v: Record<string, unknown>): AdsConfig {
  const id = (f: string, d: string) =>
    v[f] == null || typeof v[f] !== 'string' ? d : (v[f] as string);
  return {
    enabled: v.enabled === true,
    testMode: v.testMode !== false, // null/undefined → default ON
    admobAppId: id('admobAppId', DEFAULT_ADS.admobAppId),
    bannerUnitId: id('bannerUnitId', DEFAULT_ADS.bannerUnitId),
    interstitialUnitId: id('interstitialUnitId', DEFAULT_ADS.interstitialUnitId),
    rewardedUnitId: id('rewardedUnitId', DEFAULT_ADS.rewardedUnitId),
    refreshMinutes:
      typeof v.refreshMinutes === 'number' && Number.isInteger(v.refreshMinutes) && v.refreshMinutes > 0
        ? Math.min(v.refreshMinutes, 1440)
        : DEFAULT_ADS.refreshMinutes,
  };
}

export async function loadState(db: D1Database): Promise<AppState> {
  if (cache && Date.now() < cache.expires) return cache.state;

  const [cfgRows, annRows] = await Promise.all([
    db.prepare('SELECT key, value FROM app_config').all<{
      key: string;
      value: string;
    }>(),
    db
      .prepare('SELECT * FROM announcements ORDER BY created DESC LIMIT 200')
      .all<AnnouncementRow>(),
  ]);

  const map = new Map<string, Record<string, unknown>>();
  for (const r of cfgRows.results) {
    try {
      map.set(r.key, JSON.parse(r.value) as Record<string, unknown>);
    } catch {
      /* skip corrupted row */
    }
  }

  const state: AppState = {
    config: sanitizeConfig({ ...DEFAULT_CONFIG, ...(map.get('config') ?? {}) }),
    ads: sanitizeAds({ ...DEFAULT_ADS, ...(map.get('ads') ?? {}) }),
    announcements: annRows.results,
  };

  cache = { state, etag: makeEtag(state), expires: Date.now() + CACHE_TTL_MS };
  return state;
}

export async function saveKey(db: D1Database, key: string, value: unknown) {
  await db
    .prepare(
      `INSERT INTO app_config (key, value, updated_at) VALUES (?, ?, ?)
       ON CONFLICT(key) DO UPDATE SET value = excluded.value, updated_at = excluded.updated_at`
    )
    .bind(key, JSON.stringify(value), nowSec())
    .run();
  invalidateState();
}

export function invalidateState() {
  cache = null;
}

/** Stable weak ETag from the content itself. */
export function makeEtag(s: unknown): string {
  const json = JSON.stringify(s);
  // FNV-1a 32-bit — fast, no deps, stable per isolate run.
  let h = 0x811c9dc5;
  for (let i = 0; i < json.length; i++) {
    h ^= json.charCodeAt(i);
    h = Math.imul(h, 0x01000193) >>> 0;
  }
  return `W/"v2-${h.toString(16)}-${json.length}"`;
}

export function currentStateEtag(): string | null {
  return cache?.etag ?? null;
}

// ── announcements ──────────────────────────────────────────────────────────

export function announcementOut(r: AnnouncementRow) {
  return {
    id: r.id,
    title: r.title,
    body: r.body,
    kind: r.kind,
    active: r.active === 1,
    startsAt: r.starts_at,
    endsAt: r.ends_at,
  };
}

export function announcementActive(r: AnnouncementRow, now = Date.now()): boolean {
  if (r.active !== 1) return false;
  if (r.starts_at) {
    const t = Date.parse(r.starts_at);
    if (!Number.isNaN(t) && t > now) return false;
  }
  if (r.ends_at) {
    const t = Date.parse(r.ends_at);
    if (!Number.isNaN(t) && t < now) return false;
  }
  return true;
}
