-- 0002: v2 index additions for an EXISTING v1 database.
-- Safe to run repeatedly (IF NOT EXISTS). New installs get these from
-- schema.sql automatically.
CREATE INDEX IF NOT EXISTS idx_ann_active ON announcements(active, created DESC);
CREATE INDEX IF NOT EXISTS idx_pushlog_created ON push_log(created DESC);
