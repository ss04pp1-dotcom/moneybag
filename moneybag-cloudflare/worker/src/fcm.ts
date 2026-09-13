/**
 * FCM (Firebase Cloud Messaging) HTTP v1 for Cloudflare Workers.
 *
 * The Worker signs an RS256 JWT with the service-account private key using
 * WebCrypto (crypto.subtle — available inside Workers), exchanges it for an
 * OAuth access token, and posts messages to:
 *   POST https://fcm.googleapis.com/v1/projects/{projectId}/messages:send
 *
 * Credentials come from the secret `FCM_SERVICE_ACCOUNT` (the full
 * service-account JSON, single line).
 *
 * v2 fixes: SINGLE-FLIGHT token cache. Previously 40 concurrent sendFcm()
 * calls raced getAccessToken() and each fetched its own OAuth token
 * (40 sign + 40 token requests → wasted subrequests, Google rate limits).
 * Now the first caller creates one shared in-flight promise; the rest await it.
 */

export class FcmConfigError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'FcmConfigError';
  }
}

export interface ServiceAccount {
  project_id: string;
  client_email: string;
  private_key: string;
}

interface SendResult {
  ok: boolean;
  /** true when FCM says the token is unregistered → safe to delete. */
  stale: boolean;
  error?: string;
}

// ── base64url helpers (Workers runtime has btoa/atob) ──────────────────────

function b64urlFromString(s: string): string {
  return btoa(s).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

function b64urlFromBytes(bytes: Uint8Array): string {
  let bin = '';
  for (let i = 0; i < bytes.length; i++) bin += String.fromCharCode(bytes[i]);
  return btoa(bin).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

function base64ToBytes(b64: string): Uint8Array {
  const bin = atob(b64.replace(/-/g, '+').replace(/_/g, '/'));
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}

function pemToPkcs8Bytes(pem: string): Uint8Array {
  const body = pem
    .replace('-----BEGIN PRIVATE KEY-----', '')
    .replace('-----END PRIVATE KEY-----', '')
    .replace(/\s+/g, '');
  return base64ToBytes(body);
}

// ── service account ────────────────────────────────────────────────────────

let saCache: { raw: string; sa: ServiceAccount } | null = null;

export function parseServiceAccount(envJson: string): ServiceAccount {
  if (saCache && saCache.raw === envJson) return saCache.sa;
  try {
    const sa = JSON.parse(envJson) as Record<string, unknown>;
    if (!sa.project_id || !sa.client_email || !sa.private_key) {
      throw new Error('missing fields');
    }
    const parsed: ServiceAccount = {
      project_id: String(sa.project_id),
      client_email: String(sa.client_email),
      private_key: String(sa.private_key),
    };
    saCache = { raw: envJson, sa: parsed };
    return parsed;
  } catch {
    throw new FcmConfigError(
      'FCM_SERVICE_ACCOUNT secret is missing or invalid. Set it with: ' +
        'npx wrangler secret put FCM_SERVICE_ACCOUNT (paste the FULL service-account JSON as one line).'
    );
  }
}

// ── OAuth2 access token (cached per isolate, single-flight) ────────────────

let tokenCache: { email: string; token: string; exp: number } | null = null;
let tokenInflight: Promise<string> | null = null;

export async function getAccessToken(envJson: string): Promise<string> {
  const sa = parseServiceAccount(envJson);
  const now = Math.floor(Date.now() / 1000);

  if (
    tokenCache &&
    tokenCache.email === sa.client_email &&
    Date.now() < (tokenCache.exp - 120) * 1000
  ) {
    return tokenCache.token;
  }

  // Single-flight: concurrent callers share one token fetch.
  if (tokenInflight) return tokenInflight;

  tokenInflight = (async () => {
    try {
      const header = b64urlFromString(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
      const claims = b64urlFromString(
        JSON.stringify({
          iss: sa.client_email,
          scope: 'https://www.googleapis.com/auth/firebase.messaging',
          aud: 'https://oauth2.googleapis.com/token',
          iat: now,
          exp: now + 3600,
        })
      );
      const unsigned = `${header}.${claims}`;

      const key = await crypto.subtle.importKey(
        'pkcs8',
        pemToPkcs8Bytes(sa.private_key) as unknown as ArrayBuffer,
        { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
        false,
        ['sign']
      );
      const sigBuf = await crypto.subtle.sign(
        'RSASSA-PKCS1-v1_5',
        key,
        new TextEncoder().encode(unsigned)
      );
      const jwt = `${unsigned}.${b64urlFromBytes(new Uint8Array(sigBuf))}`;

      const res = await fetch('https://oauth2.googleapis.com/token', {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: new URLSearchParams({
          grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
          assertion: jwt,
        }),
      });
      if (!res.ok) {
        const text = await res.text().catch(() => '');
        throw new Error(`FCM OAuth failed (${res.status}): ${text.slice(0, 200)}`);
      }
      const j = (await res.json()) as { access_token: string; expires_in?: number };
      tokenCache = {
        email: sa.client_email,
        token: j.access_token,
        exp: now + (j.expires_in ?? 3600),
      };
      return j.access_token;
    } finally {
      tokenInflight = null;
    }
  })();

  return tokenInflight;
}

// ── send one message ───────────────────────────────────────────────────────

export async function sendFcm(
  envJson: string,
  token: string,
  title: string,
  body: string,
  data?: Record<string, string>
): Promise<SendResult> {
  const sa = parseServiceAccount(envJson);
  const accessToken = await getAccessToken(envJson);

  const message = {
    token,
    notification: { title, body },
    android: {
      priority: 'HIGH',
      notification: { channel_id: 'moneybag_push' },
    },
    apns: { payload: { aps: { sound: 'default' } } },
    data: {
      type: 'announcement',
      ...(data ?? {}),
    },
  };

  try {
    const res = await fetch(
      `https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`,
      {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${accessToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ message }),
      }
    );
    if (res.ok) return { ok: true, stale: false };

    let errStatus = '';
    let errMsg = '';
    try {
      const j = (await res.json()) as {
        error?: { status?: string; message?: string };
      };
      errStatus = j.error?.status ?? '';
      errMsg = j.error?.message ?? '';
    } catch {
      /* non-JSON error body */
    }
    // 404 / 410 / UNREGISTERED → the token is gone; delete it from the DB.
    const stale =
      res.status === 404 ||
      res.status === 410 ||
      errStatus === 'UNREGISTERED';
    return { ok: false, stale, error: `${res.status} ${errStatus} ${errMsg}`.trim() };
  } catch (e) {
    return { ok: false, stale: false, error: String(e) };
  }
}
