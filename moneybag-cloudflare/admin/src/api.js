// API client — base URL + admin key live in localStorage.
//
// v2 hardening:
//   - 15 s request timeout (AbortController) — no more hanging saves
//   - non-JSON responses surface a real error instead of silent {}
//   - 401 broadcasts 'mb:unauthorized' → App logs out automatically
//   - 429 attaches err.retryAfter so callers can back off
//   - checkLogin distinguishes wrong-key (401) from unreachable server

const BASE_KEY = 'mb_api_base';
const KEY_KEY = 'mb_api_key';
const DEFAULT_TIMEOUT_MS = 15_000;

export const getBase = () => localStorage.getItem(BASE_KEY) || '';
export const getKey = () => localStorage.getItem(KEY_KEY) || '';

export function saveApi(base, key) {
  const clean = String(base || '').trim().replace(/\/+$/, '');
  localStorage.setItem(BASE_KEY, clean);
  localStorage.setItem(KEY_KEY, String(key || '').trim());
}

export function clearApi() {
  localStorage.removeItem(BASE_KEY);
  localStorage.removeItem(KEY_KEY);
}

const authHeaders = () => ({
  'Content-Type': 'application/json',
  'x-api-key': getKey(),
});

export async function api(path, { method = 'GET', body, timeoutMs = DEFAULT_TIMEOUT_MS } = {}) {
  const base = getBase();
  if (!base) throw Object.assign(new Error('API URL is not set'), { status: 0 });

  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), timeoutMs);
  let res;
  try {
    res = await fetch(base + path, {
      method,
      headers: authHeaders(),
      body: body === undefined ? undefined : JSON.stringify(body),
      signal: ctrl.signal,
    });
  } catch (e) {
    const msg =
      e && e.name === 'AbortError'
        ? `Request timed out (${Math.round(timeoutMs / 1000)}s)`
        : `Network error: ${e?.message ?? 'fetch failed'}`;
    throw Object.assign(new Error(msg), { status: 0 });
  } finally {
    clearTimeout(timer);
  }

  // Robust body handling: a 200 with a non-JSON body used to become {} and
  // silently produced false success / infinite loading downstream.
  const text = await res.text().catch(() => '');
  let data = null;
  if (text) {
    try {
      data = JSON.parse(text);
    } catch {
      data = null;
    }
  }

  if (!res.ok) {
    const err = new Error(
      (data && data.error) || `HTTP ${res.status} ${res.statusText || ''}`.trim()
    );
    err.status = res.status;
    err.body = data;
    if (res.status === 401 && path.startsWith('/api/v1/admin')) {
      // Key removed/rotated server-side → the whole app is unusable.
      window.dispatchEvent(new Event('mb:unauthorized'));
    }
    if (res.status === 429) {
      const ra = res.headers.get('Retry-After');
      err.retryAfter = ra && /^\d+$/.test(ra) ? Number(ra) : 5;
    }
    throw err;
  }

  if (data === null || typeof data !== 'object') {
    // Announcements GET returns an array (fine); everything else objects.
    // A truly empty body is only acceptable for 204-style endpoints — none
    // exist here, so treat it as an error instead of fake success.
    if (text === '') throw Object.assign(new Error('Empty response from server'), { status: res.status });
    if (typeof data === 'number' || typeof data === 'string') {
      throw Object.assign(new Error('Unexpected response shape from server'), { status: res.status });
    }
  }
  return data;
}

/** Validate the key at login time. Throws with a precise status. */
export async function checkLogin(base, key) {
  const clean = String(base || '').trim().replace(/\/+$/, '');
  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), DEFAULT_TIMEOUT_MS);
  try {
    const res = await fetch(clean + '/api/v1/admin/login', {
      headers: { 'x-api-key': String(key || '').trim() },
      signal: ctrl.signal,
    });
    if (res.ok) return true;
    if (res.status === 401) {
      throw Object.assign(new Error('Wrong API key.'), { status: 401 });
    }
    throw Object.assign(new Error(`Server error (HTTP ${res.status}).`), { status: res.status });
  } catch (e) {
    if (e.status) throw e;
    const msg = e?.name === 'AbortError' ? 'Timed out' : 'Unreachable';
    throw Object.assign(new Error(`${msg} — is the Worker URL correct?`), { status: 0 });
  } finally {
    clearTimeout(timer);
  }
}

export const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

export const timeAgo = (unixSec) => {
  if (!unixSec) return '—';
  // Clock-skewed future timestamps rendered as "-30s ago" before.
  const s = Math.max(0, Math.floor(Date.now() / 1000) - unixSec);
  if (s < 60) return `${s}s ago`;
  if (s < 3600) return `${Math.floor(s / 60)}m ago`;
  if (s < 86400) return `${Math.floor(s / 3600)}h ago`;
  return `${Math.floor(s / 86400)}d ago`;
};
