import { describe, it, expect } from 'vitest';
import {
  checkRate,
  sweepBuckets,
  timingSafeEqual,
} from '../src/middleware';
import {
  announcementActive,
  makeEtag,
  sanitizeConfig,
  sanitizeAds,
  DEFAULT_CONFIG,
  DEFAULT_ADS,
} from '../src/state';
import { parseServiceAccount } from '../src/fcm';
import type { AnnouncementRow } from '../src/state';

const row = (over: Partial<AnnouncementRow>): AnnouncementRow => ({
  id: 'x',
  title: 't',
  body: 'b',
  kind: 'info',
  active: 1,
  starts_at: null,
  ends_at: null,
  created: 0,
  ...over,
});

describe('announcementActive', () => {
  const now = Date.parse('2026-06-15T12:00:00Z');

  it('respects active flag', () => {
    expect(announcementActive(row({ active: 0 }), now)).toBe(false);
  });

  it('respects starts/ends windows', () => {
    expect(announcementActive(row({ starts_at: '2026-06-16T00:00:00Z' }), now)).toBe(false);
    expect(announcementActive(row({ starts_at: '2026-06-14T00:00:00Z' }), now)).toBe(true);
    expect(announcementActive(row({ ends_at: '2026-06-14T00:00:00Z' }), now)).toBe(false);
    expect(announcementActive(row({ ends_at: '2026-06-16T00:00:00Z' }), now)).toBe(true);
  });

  it('ignores unparseable dates instead of hiding the announcement', () => {
    // old code: Date.parse(garbage)=NaN → NaN > now = false → announcement hidden
    expect(announcementActive(row({ starts_at: 'garbage' }), now)).toBe(true);
    expect(announcementActive(row({ ends_at: 'garbage' }), now)).toBe(true);
  });
});

describe('makeEtag', () => {
  it('is stable for the same content', () => {
    expect(makeEtag({ a: 1 })).toBe(makeEtag({ a: 1 }));
  });
  it('changes when content changes', () => {
    expect(makeEtag({ a: 1 })).not.toBe(makeEtag({ a: 2 }));
  });
});

describe('sanitizeConfig / sanitizeAds', () => {
  it('repairs legacy junk types on read', () => {
    const c = sanitizeConfig({
      latestVersion: 2.1, // number!
      minVersion: null,
      forceUpdate: 'true',
      maintenance: 1,
      message: { title: '', body: '' },
    });
    expect(c.latestVersion).toBe(DEFAULT_CONFIG.latestVersion);
    expect(c.minVersion).toBe(DEFAULT_CONFIG.minVersion);
    expect(c.forceUpdate).toBe(false);
    expect(c.maintenance).toBe(false);
    expect(c.message).toBeNull();
  });

  it('keeps a real message object', () => {
    const c = sanitizeConfig({ message: { title: 'হেড', body: 'বডি' } });
    expect(c.message).toEqual({ title: 'হেড', body: 'বডি' });
  });

  it('normalises null testMode to ON and bad refreshMinutes to default', () => {
    const a = sanitizeAds({ ...DEFAULT_ADS, testMode: null, refreshMinutes: 'x' });
    expect(a.testMode).toBe(true);
    expect(a.refreshMinutes).toBe(DEFAULT_ADS.refreshMinutes);
    const b = sanitizeAds({ ...DEFAULT_ADS, testMode: false, refreshMinutes: 90 });
    expect(b.testMode).toBe(false);
    expect(b.refreshMinutes).toBe(90);
  });
});

describe('checkRate', () => {
  it('allows up to the limit inside a window then blocks', () => {
    const t0 = 1_000_000;
    let r = { allowed: true } as ReturnType<typeof checkRate>;
    for (let i = 0; i < 3; i++) r = checkRate('k1', 3, 60_000, t0);
    expect(r.allowed).toBe(true);
    r = checkRate('k1', 3, 60_000, t0);
    expect(r.allowed).toBe(false);
    // a different key is unaffected
    expect(checkRate('k2', 3, 60_000, t0).allowed).toBe(true);
  });

  it('resets after the window passes', () => {
    const t0 = 1_000_000;
    for (let i = 0; i < 5; i++) checkRate('k3', 3, 60_000, t0);
    expect(checkRate('k3', 3, 60_000, t0).allowed).toBe(false);
    expect(checkRate('k3', 3, 60_000, t0 + 61_000).allowed).toBe(true);
  });

  it('sweep removes expired buckets', () => {
    const t0 = 5_000_000;
    checkRate('s1', 1, 1000, t0);
    const removed = sweepBuckets(t0 + 5000);
    expect(removed).toBeGreaterThanOrEqual(1);
  });
});

describe('timingSafeEqual', () => {
  it('matches identical strings', async () => {
    expect(await timingSafeEqual('secret-key-123', 'secret-key-123')).toBe(true);
  });
  it('rejects different strings of equal length', async () => {
    expect(await timingSafeEqual('secret-key-123', 'secret-key-456')).toBe(false);
  });
  it('rejects different lengths', async () => {
    expect(await timingSafeEqual('short', 'a-much-longer-key-value')).toBe(false);
  });
});

describe('parseServiceAccount', () => {
  it('parses a valid single-line service account JSON', () => {
    const sa = JSON.stringify({
      project_id: 'moneybag-dev',
      client_email: 'push@moneybag-dev.iam.gserviceaccount.com',
      private_key: '-----BEGIN PRIVATE KEY-----\\nabc\\n-----END PRIVATE KEY-----\\n',
    });
    const parsed = parseServiceAccount(sa);
    expect(parsed.project_id).toBe('moneybag-dev');
    expect(parsed.client_email).toContain('@');
  });

  it('throws FcmConfigError for garbage', () => {
    expect(() => parseServiceAccount('not json')).toThrow();
    expect(() =>
      parseServiceAccount(JSON.stringify({ project_id: 'x' }))
    ).toThrow();
  });
});
