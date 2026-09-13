/**
 * Self-contained API documentation: /docs (HTML) + /openapi.json (OpenAPI 3.1).
 * No external CDNs — everything inline so the dashboard works offline.
 */

export const docsHtml = `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>MoneyBag Admin API — docs</title>
<style>
  :root{color-scheme:light}
  *{box-sizing:border-box}
  body{margin:0;font:14px/1.6 ui-sans-serif,system-ui,-apple-system,"Segoe UI",Roboto,sans-serif;background:#f8fafc;color:#0f172a}
  .wrap{max-width:880px;margin:0 auto;padding:32px 20px 64px}
  h1{font-size:24px;margin:0 0 4px}
  h2{font-size:18px;margin:32px 0 8px;padding-bottom:6px;border-bottom:2px solid #e2e8f0}
  .sub{color:#64748b;margin-bottom:24px}
  table{width:100%;border-collapse:collapse;background:#fff;border:1px solid #e2e8f0;border-radius:8px;overflow:hidden}
  th,td{padding:8px 12px;border-bottom:1px solid #eef2f7;text-align:left;vertical-align:top}
  th{background:#f1f5f9;font-size:12px;text-transform:uppercase;letter-spacing:.04em;color:#475569}
  code{font:12px/1.4 ui-monospace,SFMono-Regular,Menlo,monospace;background:#eef2f7;padding:1px 5px;border-radius:4px}
  .m{display:inline-block;min-width:52px;padding:2px 8px;border-radius:6px;font:600 11px/1.6 ui-monospace,monospace;color:#fff}
  .get{background:#2563eb}.post{background:#16a34a}.put{background:#d97706}
  .del{background:#dc2626}.patch{background:#7c3aed}
  .tag{display:inline-block;font-size:11px;padding:1px 8px;border-radius:99px;font-weight:600}
  .pub{background:#dcfce7;color:#166534}.adm{background:#fef3c7;color:#92400e}
  .note{background:#eff6ff;border:1px solid #bfdbfe;border-radius:8px;padding:10px 14px;font-size:13px}
  pre{background:#0f172a;color:#e2e8f0;padding:14px;border-radius:8px;overflow:auto;font-size:12.5px}
  ul{margin:6px 0;padding-left:22px}
</style>
</head>
<body><div class="wrap">
<h1>💸 MoneyBag Admin API</h1>
<div class="sub">cloudflare-worker + hono + d1 · <a href="/openapi.json">openapi.json</a> · <a href="/health?deep=1">deep health</a></div>

<div class="note"><b>Admin auth:</b> send header <code>x-api-key: &lt;ADMIN_API_KEY secret&gt;</code> on every <span class="tag adm">admin</span> endpoint.
Rate limits: public 240/min, users-sync 30/min, admin 600/min per IP (HTTP 429 + <code>Retry-After</code> when exceeded).</div>

<h2>Public <span class="tag pub">no key needed</span></h2>
<table>
<tr><th>Method</th><th>Path</th><th>Description</th></tr>
<tr><td><span class="m get">GET</span></td><td><code>/</code></td><td>Service info (name, version, time)</td></tr>
<tr><td><span class="m get">GET</span></td><td><code>/health</code></td><td>Shallow health check. <code>?deep=1</code> also pings D1 (503 if DB down)</td></tr>
<tr><td><span class="m get">GET</span></td><td><code>/api/v1/app</code></td><td>One-shot bootstrap: <code>{config, ads, announcements}</code> (active only)</td></tr>
<tr><td><span class="m get">GET</span></td><td><code>/api/v1/config</code></td><td>App config: versions, forceUpdate, maintenance, message</td></tr>
<tr><td><span class="m get">GET</span></td><td><code>/api/v1/ads</code></td><td>AdMob settings</td></tr>
<tr><td><span class="m get">GET</span></td><td><code>/api/v1/announcements</code></td><td>Active announcements (window-filtered)</td></tr>
<tr><td><span class="m post">POST</span></td><td><code>/api/v1/users/sync</code></td><td>Upsert user + FCM token after Google Sign-In. Body: <code>{uid, email, name, photoUrl?, fcmToken?, platform?, appVersion?}</code>. One FCM token belongs to exactly one user.</td></tr>
</table>
<p>All public GETs send <code>ETag</code> + <code>Cache-Control: max-age=30</code> — send <code>If-None-Match</code> to get 304.</p>

<h2>Admin <span class="tag adm">x-api-key</span></h2>
<table>
<tr><th>Method</th><th>Path</th><th>Description</th></tr>
<tr><td><span class="m get">GET</span></td><td><code>/api/v1/admin/login</code></td><td>Key check — 200 ok / 401</td></tr>
<tr><td><span class="m get">GET</span></td><td><code>/api/v1/admin/overview</code></td><td>Dashboard counters (users, tokens, pushes, announcements, ads, config flags)</td></tr>
<tr><td><span class="m get">GET</span></td><td><code>/api/v1/admin/users?limit=100&amp;offset=0&amp;search=</code></td><td>Users list (limit ≤ 500, LIKE-escaped search on email/name/uid)</td></tr>
<tr><td><span class="m post">POST</span></td><td><code>/api/v1/admin/users/push</code></td><td>Targeted push. Body: <code>{uid, title, body}</code> → 404 unknown, 409 no token</td></tr>
<tr><td><span class="m post">POST</span></td><td><code>/api/v1/admin/push</code></td><td>Global push, 40 users/batch. Body: <code>{title, body, offset?}</code> (classic) or <code>{title, body, cursor:{lastLogin, uid}}</code> (stable). Response: <code>{sent, failed, total, nextOffset, nextCursor}</code></td></tr>
<tr><td><span class="m get">GET</span></td><td><code>/api/v1/admin/push/log</code></td><td>Last 25 pushes</td></tr>
<tr><td><span class="m get">GET</span></td><td><code>/api/v1/admin/config</code></td><td>Full config (edit forms)</td></tr>
<tr><td><span class="m put">PUT</span></td><td><code>/api/v1/admin/config</code></td><td>Partial update, validated (versions, booleans, message)</td></tr>
<tr><td><span class="m get">GET</span></td><td><code>/api/v1/admin/ads</code></td><td>Full ads settings (edit forms)</td></tr>
<tr><td><span class="m put">PUT</span></td><td><code>/api/v1/admin/ads</code></td><td>Partial update, validated (booleans, admob ids, refreshMinutes 1–1440)</td></tr>
<tr><td><span class="m get">GET</span></td><td><code>/api/v1/admin/announcements</code></td><td>All announcements</td></tr>
<tr><td><span class="m post">POST</span></td><td><code>/api/v1/admin/announcements</code></td><td>Create. Body: <code>{title, body, kind? info|update|promo, active?, startsAt?, endsAt?}</code> (ISO 8601)</td></tr>
<tr><td><span class="m patch">PATCH</span></td><td><code>/api/v1/admin/announcements/:id/toggle</code></td><td>Enable/disable</td></tr>
<tr><td><span class="m del">DELETE</span></td><td><code>/api/v1/admin/announcements/:id</code></td><td>Delete</td></tr>
</table>

<h2>Errors</h2>
<pre>{"error":"unauthorized"}           ← 401 (bad/missing x-api-key)
{"error":"rate limited — retry after 12s"} ← 429 (Retry-After header set)
{"error":"invalid fields: message.body","fields":{...}} ← 400
{"error":"not found"}              ← 404
{"error":"internal error","requestId":"…"} ← 500 (id matches the log line)</pre>
</div></body></html>`;

interface Op {
  method: string;
  path: string;
  summary: string;
  tag: 'public' | 'admin';
  body?: Record<string, unknown>;
}

const ops: Op[] = [
  { method: 'get', path: '/', summary: 'Service info', tag: 'public' },
  { method: 'get', path: '/health', summary: 'Health check (add ?deep=1 to ping D1)', tag: 'public' },
  { method: 'get', path: '/api/v1/app', summary: 'One-shot bootstrap: config + ads + active announcements', tag: 'public' },
  { method: 'get', path: '/api/v1/config', summary: 'App config', tag: 'public' },
  { method: 'get', path: '/api/v1/ads', summary: 'AdMob settings', tag: 'public' },
  { method: 'get', path: '/api/v1/announcements', summary: 'Active announcements', tag: 'public' },
  {
    method: 'post',
    path: '/api/v1/users/sync',
    summary: 'Upsert user + FCM token (Google Sign-In)',
    tag: 'public',
    body: {
      uid: { type: 'string', description: 'Google account id, 4–128 chars' },
      email: { type: 'string' },
      name: { type: 'string' },
      photoUrl: { type: 'string' },
      fcmToken: { type: 'string', description: 'binds to exactly one user' },
      platform: { type: 'string', enum: ['android', 'ios'] },
      appVersion: { type: 'string' },
    },
  },
  { method: 'get', path: '/api/v1/admin/login', summary: 'Key check', tag: 'admin' },
  { method: 'get', path: '/api/v1/admin/overview', summary: 'Dashboard counters', tag: 'admin' },
  {
    method: 'get',
    path: '/api/v1/admin/users',
    summary: 'Users list with search/paging',
    tag: 'admin',
  },
  {
    method: 'post',
    path: '/api/v1/admin/users/push',
    summary: 'Targeted push to one user',
    tag: 'admin',
    body: {
      uid: { type: 'string' },
      title: { type: 'string', maxLength: 200 },
      body: { type: 'string', maxLength: 1000 },
    },
  },
  {
    method: 'post',
    path: '/api/v1/admin/push',
    summary: 'Global push (paged batches of 40)',
    tag: 'admin',
    body: {
      title: { type: 'string', maxLength: 200 },
      body: { type: 'string', maxLength: 1000 },
      offset: { type: 'integer', minimum: 0 },
      cursor: {
        type: 'object',
        properties: { lastLogin: { type: 'integer' }, uid: { type: 'string' } },
      },
    },
  },
  { method: 'get', path: '/api/v1/admin/push/log', summary: 'Recent push history', tag: 'admin' },
  { method: 'get', path: '/api/v1/admin/config', summary: 'Full config', tag: 'admin' },
  { method: 'put', path: '/api/v1/admin/config', summary: 'Update config (validated)', tag: 'admin' },
  { method: 'get', path: '/api/v1/admin/ads', summary: 'Full ads settings', tag: 'admin' },
  { method: 'put', path: '/api/v1/admin/ads', summary: 'Update ads (validated)', tag: 'admin' },
  { method: 'get', path: '/api/v1/admin/announcements', summary: 'All announcements', tag: 'admin' },
  { method: 'post', path: '/api/v1/admin/announcements', summary: 'Create announcement (validated)', tag: 'admin' },
  { method: 'patch', path: '/api/v1/admin/announcements/{id}/toggle', summary: 'Toggle announcement', tag: 'admin' },
  { method: 'delete', path: '/api/v1/admin/announcements/{id}', summary: 'Delete announcement', tag: 'admin' },
];

function opEntry(op: Op): Record<string, unknown> {
  const responses: Record<string, unknown> = {
    200: { description: 'OK' },
    401: { description: 'unauthorized (admin only)' },
    429: { description: 'rate limited' },
  };
  const entry: Record<string, unknown> = { summary: op.summary, tags: [op.tag], responses };
  if (op.body) {
    entry.requestBody = {
      required: true,
      content: { 'application/json': { schema: { type: 'object', properties: op.body } } },
    };
    if (op.method === 'post' || op.method === 'put' || op.method === 'patch') {
      responses[400] = { description: 'validation error' };
    }
  }
  if (op.path.includes('{id}')) {
    entry.parameters = [
      { name: 'id', in: 'path', required: true, schema: { type: 'string' } },
    ];
  }
  if (op.tag === 'admin' && op.method !== 'get' || op.tag === 'admin') {
    // admin ops all require the key
  }
  return entry;
}

export const openApiJson = {
  openapi: '3.1.0',
  info: {
    title: 'MoneyBag Admin API',
    version: '2.0.0',
    description:
      'Bengali-first personal finance backend — app bootstrap config, user/FCM sync, announcements and admin push. Admin routes require the x-api-key header.',
  },
  servers: [{ url: '/' }],
  tags: [
    { name: 'public', description: 'App-facing endpoints (rate-limited)' },
    { name: 'admin', description: 'Dashboard endpoints (x-api-key)' },
  ],
  components: {
    securitySchemes: {
      ApiKeyAuth: { type: 'apiKey', in: 'header', name: 'x-api-key' },
    },
    schemas: {
      AppConfig: {
        type: 'object',
        properties: {
          latestVersion: { type: 'string' },
          minVersion: { type: 'string' },
          forceUpdate: { type: 'boolean' },
          maintenance: { type: 'boolean' },
          message: {
            oneOf: [
              { type: 'null' },
              {
                type: 'object',
                properties: { title: { type: 'string' }, body: { type: 'string' } },
              },
            ],
          },
        },
      },
      AdsConfig: {
        type: 'object',
        properties: {
          enabled: { type: 'boolean' },
          testMode: { type: 'boolean' },
          admobAppId: { type: 'string' },
          bannerUnitId: { type: 'string' },
          interstitialUnitId: { type: 'string' },
          rewardedUnitId: { type: 'string' },
          refreshMinutes: { type: 'integer' },
        },
      },
      Announcement: {
        type: 'object',
        properties: {
          id: { type: 'string' },
          title: { type: 'string' },
          body: { type: 'string' },
          kind: { type: 'string', enum: ['info', 'update', 'promo'] },
          active: { type: 'boolean' },
          startsAt: { type: 'string', format: 'date-time', nullable: true },
          endsAt: { type: 'string', format: 'date-time', nullable: true },
        },
      },
    },
  },
  'x-rate-limits': { public_per_min: 240, users_sync_per_min: 30, admin_per_min: 600 },
  paths: Object.fromEntries(
    ops.map((op) => [
      op.path,
      {
        [op.method]: {
          ...opEntry(op),
          security: op.tag === 'admin' ? [{ ApiKeyAuth: [] }] : undefined,
        },
      },
    ])
  ),
} as const;
