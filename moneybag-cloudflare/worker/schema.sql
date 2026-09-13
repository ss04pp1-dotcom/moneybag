-- MoneyBag Admin API — Cloudflare D1 schema (v2)
-- Apply with:
--   npx wrangler d1 execute moneybag-db --local  --file=schema.sql
--   npx wrangler d1 execute moneybag-db --remote --file=schema.sql
-- Already have a v1 database? Just run migrations/0002_indexes.sql.

-- Key/value app configuration (config + ads), values are JSON strings.
CREATE TABLE IF NOT EXISTS app_config (
  key        TEXT PRIMARY KEY,
  value      TEXT NOT NULL,
  updated_at INTEGER NOT NULL DEFAULT (unixepoch())
);

-- Registered users (synced from the app on Google Sign-In).
CREATE TABLE IF NOT EXISTS users (
  uid         TEXT PRIMARY KEY,          -- Google account id (stable)
  email       TEXT,
  name        TEXT,
  photo_url   TEXT,
  fcm_token   TEXT,                      -- current Firebase token
  platform    TEXT,                      -- android | ios
  app_version TEXT,
  last_login  INTEGER NOT NULL DEFAULT (unixepoch()),
  created     INTEGER NOT NULL DEFAULT (unixepoch())
);
CREATE INDEX IF NOT EXISTS idx_users_token  ON users(fcm_token);
CREATE INDEX IF NOT EXISTS idx_users_login  ON users(last_login DESC);

-- Dashboard announcements shown inside the app.
CREATE TABLE IF NOT EXISTS announcements (
  id       TEXT PRIMARY KEY,
  title    TEXT NOT NULL,
  body     TEXT NOT NULL,
  kind     TEXT NOT NULL DEFAULT 'info', -- info | update | promo
  active   INTEGER NOT NULL DEFAULT 1,
  starts_at TEXT,                        -- ISO 8601 or NULL
  ends_at   TEXT,                        -- ISO 8601 or NULL
  created  INTEGER NOT NULL DEFAULT (unixepoch())
);
-- v2: window filter for the public announcement list.
CREATE INDEX IF NOT EXISTS idx_ann_active ON announcements(active, created DESC);

-- Push notification history (global + targeted).
CREATE TABLE IF NOT EXISTS push_log (
  id      INTEGER PRIMARY KEY AUTOINCREMENT,
  target  TEXT NOT NULL,                 -- 'all' or the user's uid/email
  title   TEXT,
  body    TEXT,
  sent    INTEGER NOT NULL DEFAULT 0,
  failed  INTEGER NOT NULL DEFAULT 0,
  created INTEGER NOT NULL DEFAULT (unixepoch())
);
-- v2: the dashboard reads the newest 25 rows.
CREATE INDEX IF NOT EXISTS idx_pushlog_created ON push_log(created DESC);
