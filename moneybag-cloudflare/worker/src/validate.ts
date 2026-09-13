/**
 * Strict payload validators for admin write endpoints.
 *
 * Old behaviour merged ANY JSON into stored config/ads — a typo or wrong type
 * (e.g. `latestVersion: 2.1`) could break every app client on next sync.
 * These validators whitelist known fields, coerce nothing and reject wrong
 * types with a precise error the dashboard can show.
 */

export interface ValidationErrors {
  [field: string]: string;
}

const VERSION_RE = /^[0-9A-Za-z][0-9A-Za-z.+-]{0,19}$/;
const ADMOB_RE = /^ca-app-pub-[0-9]+[~/][0-9A-Za-z]+$/;
// Printable ASCII, no spaces/control — matches Google/Firebase uid shapes.
const UID_RE = /^[A-Za-z0-9._:-]{4,128}$/;
const ISO_RE =
  /^(\d{4}-\d{2}-\d{2})([T ]\d{2}:\d{2}(:\d{2}(\.\d+)?)?(Z|[+-]\d{2}:?\d{2})?)?$/;

function str(v: unknown, max: number): string | null {
  if (typeof v !== 'string') return null;
  if (v.length > max) return null;
  return v;
}

function bool(v: unknown): boolean | null {
  return typeof v === 'boolean' ? v : null;
}

/** PUT /api/v1/admin/config */
export function validateConfig(
  b: Record<string, unknown>
): { ok: boolean; errors: ValidationErrors; clean: Record<string, unknown> } {
  const errors: ValidationErrors = {};
  const clean: Record<string, unknown> = {};

  if ('latestVersion' in b) {
    const v = str(b.latestVersion, 20);
    if (v === null || !VERSION_RE.test(v))
      errors.latestVersion = 'string like "2.1.2" expected';
    else clean.latestVersion = v;
  }
  if ('minVersion' in b) {
    const v = str(b.minVersion, 20);
    if (v === null || !VERSION_RE.test(v))
      errors.minVersion = 'string like "1.0.0" expected';
    else clean.minVersion = v;
  }
  if ('forceUpdate' in b) {
    const v = bool(b.forceUpdate);
    if (v === null) errors.forceUpdate = 'boolean expected';
    else clean.forceUpdate = v;
  }
  if ('maintenance' in b) {
    const v = bool(b.maintenance);
    if (v === null) errors.maintenance = 'boolean expected';
    else clean.maintenance = v;
  }
  if ('message' in b) {
    const m = b.message;
    if (m === null || m === '') {
      clean.message = null;
    } else if (typeof m === 'object' && m !== null) {
      const mo = m as Record<string, unknown>;
      const title = str(mo.title, 200);
      const body = str(mo.body, 2000);
      // Legacy dashboard round-trips message: {title, body} where the
      // untouched sibling field is '' — both empty means "no message".
      if ((title == null || title.length === 0) && (body == null || body.length === 0)) {
        clean.message = null;
      } else {
        if (title === null || title.length === 0)
          errors['message.title'] = 'non-empty string (max 200) expected';
        if (body === null || body.length === 0)
          errors['message.body'] = 'non-empty string (max 2000) expected';
        if (title && body)
          clean.message = { title: String(title), body: String(body) };
      }
    } else {
      errors.message = 'null or {title, body} expected';
    }
  }

  return { ok: Object.keys(errors).length === 0, errors, clean };
}

/** PUT /api/v1/admin/ads */
export function validateAds(
  b: Record<string, unknown>
): { ok: boolean; errors: ValidationErrors; clean: Record<string, unknown> } {
  const errors: ValidationErrors = {};
  const clean: Record<string, unknown> = {};

  if ('enabled' in b) {
    const v = bool(b.enabled);
    if (v === null) errors.enabled = 'boolean expected';
    else clean.enabled = v;
  }
  if ('testMode' in b) {
    const v = bool(b.testMode);
    if (v === null) errors.testMode = 'boolean expected';
    else clean.testMode = v;
  }
  for (const f of [
    'admobAppId',
    'bannerUnitId',
    'interstitialUnitId',
    'rewardedUnitId',
  ]) {
    if (f in b) {
      const v = b[f];
      if (v === null || v === '') {
        clean[f] = '';
      } else {
        const s = str(v, 100);
        if (s === null || !ADMOB_RE.test(s))
          errors[f] = 'admob id like "ca-app-pub-…/…" expected (or empty)';
        else clean[f] = s;
      }
    }
  }
  if ('refreshMinutes' in b) {
    const v = b.refreshMinutes;
    if (typeof v !== 'number' || !Number.isInteger(v) || v < 1 || v > 1440)
      errors.refreshMinutes = 'integer 1–1440 expected';
    else clean.refreshMinutes = v;
  }

  return { ok: Object.keys(errors).length === 0, errors, clean };
}

/** POST /api/v1/admin/announcements */
export function validateAnnouncement(
  b: Record<string, unknown>
): { ok: boolean; errors: ValidationErrors; clean: Record<string, unknown> } {
  const errors: ValidationErrors = {};
  const clean: Record<string, unknown> = {};

  const title = str(b.title, 200);
  if (!title || title.trim().length === 0)
    errors.title = 'non-empty string (max 200) required';
  else clean.title = title;

  const body = str(b.body, 2000);
  if (!body || body.trim().length === 0)
    errors.body = 'non-empty string (max 2000) required';
  else clean.body = body;

  const kind = b.kind == null ? 'info' : String(b.kind);
  if (!['info', 'update', 'promo'].includes(kind))
    errors.kind = 'info | update | promo expected';
  else clean.kind = kind;

  if ('active' in b) {
    const a = bool(b.active);
    if (a === null) errors.active = 'boolean expected';
    else clean.active = a;
  } else clean.active = true;

  for (const f of ['startsAt', 'endsAt']) {
    if (f in b && b[f] != null && b[f] !== '') {
      const s = str(b[f], 40);
      if (s === null || !ISO_RE.test(s) || Number.isNaN(Date.parse(s)))
        errors[f] = 'ISO 8601 date expected (e.g. 2026-01-31T10:00:00Z)';
      else clean[f] = s;
    } else clean[f] = null;
  }

  if (
    clean.startsAt &&
    clean.endsAt &&
    Date.parse(String(clean.startsAt)) >= Date.parse(String(clean.endsAt))
  ) {
    errors.endsAt = 'endsAt must be after startsAt';
  }

  return { ok: Object.keys(errors).length === 0, errors, clean };
}

/** POST /api/v1/users/sync — shape guard (public endpoint!). */
export function validateUserSync(
  b: Record<string, unknown>
): { ok: boolean; errors: ValidationErrors; uid: string } {
  const errors: ValidationErrors = {};
  const uid = typeof b.uid === 'string' ? b.uid : '';
  if (!UID_RE.test(uid)) {
    errors.uid =
      'uid must be 4–128 chars, letters/digits/._:- (Google account id)';
  }
  if (b.email != null && b.email !== '' && b.email !== null) {
    if (typeof b.email !== 'string' || b.email.length > 320 || !b.email.includes('@')) {
      errors.email = 'valid email or empty expected';
    }
  }
  return { ok: Object.keys(errors).length === 0, errors, uid };
}

/** Escape SQL LIKE wildcards in user search input. */
export function escapeLike(s: string): string {
  return s.replace(/[\\%_]/g, (ch) => '\\' + ch);
}
