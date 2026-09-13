# Security Notes — MoneyBag v2.2.0

## Key management
- **ADMIN_API_KEY** must be a long random string (`openssl rand -hex 32`). It
  grants full dashboard control (config mutation + mass push). Rotate it any
  time with `wrangler secret put`; to avoid lockout during rotation, set the
  new key via `ADMIN_API_KEYS` (comma-separated extras), deploy, update the
  dashboard, then remove the old secret.
- The dashboard stores the key in `localStorage` on the ADMIN'S OWN BROWSER`
  only. A CSP is shipped (`admin/public/_headers` + index.html meta) that
  blocks external scripts. If multiple people use the dashboard, prefer
  separate keys via `ADMIN_API_KEYS`.
- The Worker's admin error is generic (`unauthorized`) — it no longer
  advertises which header to send. Key comparison is timing-safe.

## Transport & browser
- Everything runs over HTTPS (workers.dev / pages.dev force TLS).
- CORS: default is `*` (mobile apps don't need CORS; the dashboard is hosted
  on a different origin). Once your dashboard domain is fixed, set
  `ALLOWED_ORIGINS` in `wrangler.toml [vars]` to lock admin routes to it.
- Security headers on both server (nosniff, DENY, no-referrer,
  permissions-policy, no-store on admin) and Pages (CSP).

## App-side
- **PIN**: 60,000-round chained SHA-256 with per-install random salt,
  constant-time compare, brute-force cooldown, legacy hashes auto-upgrade on
  first successful verification.
- **Backups**: AES-256-GCM with PBKDF2-HMAC-SHA256 (120 k iterations);
  Drive stores ciphertext only; minimum passphrase length enforced.
- **Lock gate**: fail-closed when a backup PIN exists; biometric prompt is
  `biometricOnly: false` so the device credential also works.

## Known limitations (read before production)
1. **Drive passphrase at rest** — stored base64-obfuscated in
   SharedPreferences, not in the Android Keystore. This package deliberately
   avoids new dependencies; if you want hardware-backed storage, add
   `flutter_secure_storage` and replace
   `MbAutoSyncService.rememberPassphrase/forgetPassphrase` (two functions).
2. **Rate limiting is per-isolate** — Cloudflare Workers run many isolates;
   the limiter is best-effort (typically caps a single client to ~N×isolates
   requests/min). For hard guarantees, add a WAF rate-limiting rule
   (dash.cloudflare.com → Security → WAF → Rate limiting rules) matching
   `/api/v1/` — 1 request per 2 seconds per IP is a reasonable start.
3. **`users/sync` is unauthenticated by design** (the app has no user
   auth tokens — Google Sign-In is client-side). It is shape-validated,
   length-capped and rate-limited, but anyone can register a fake uid. If
   this becomes a problem, add Firebase-ID-token verification in the Worker
   before the upsert.
4. **Placeholders that MUST be replaced before release** (deployer-owned
   credentials): `lib/core/config.dart` (Web Client ID, Worker URL),
   `android/app/google-services.json`, iOS `GoogleService-Info.plist`,
   AdMob APPLICATION_ID in AndroidManifest (currently Google's test id).
5. The AdMob test App ID in the manifest must be replaced with a real one
   before serving live ads (policy requirement).

## Reporting
Found something? Check `worker/src` (all security logic is commented with
the rationale) and CHANGELOG.md for what was already hardened.
