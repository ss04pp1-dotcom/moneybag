import { describe, it, expect } from 'vitest';
import {
  validateConfig,
  validateAds,
  validateAnnouncement,
  validateUserSync,
  escapeLike,
} from '../src/validate';

describe('validateConfig', () => {
  it('accepts a well-formed dashboard payload', () => {
    const r = validateConfig({
      latestVersion: '2.1.2',
      minVersion: '1.0.0',
      forceUpdate: false,
      maintenance: true,
      message: { title: 'কাজ চলছে', body: 'অল্প সময়েই ফিরে আসছি' },
    });
    expect(r.ok).toBe(true);
    expect(r.clean.maintenance).toBe(true);
  });

  it('rejects wrong types (numbers instead of strings)', () => {
    const r = validateConfig({ latestVersion: 2.1, minVersion: 1 });
    expect(r.ok).toBe(false);
    expect(r.errors.latestVersion).toBeTruthy();
    expect(r.errors.minVersion).toBeTruthy();
  });

  it('rejects non-boolean forceUpdate', () => {
    expect(validateConfig({ forceUpdate: 'yes' }).ok).toBe(false);
  });

  it('treats both-empty message as null (legacy dashboard round-trip)', () => {
    const r = validateConfig({ message: { title: '', body: '' } });
    expect(r.ok).toBe(true);
    expect(r.clean.message).toBeNull();
  });

  it('rejects message with only one empty field', () => {
    const r = validateConfig({ message: { title: 'hello', body: '' } });
    expect(r.ok).toBe(false);
    expect(r.errors['message.body']).toBeTruthy();
  });

  it('rejects junk version strings', () => {
    expect(validateConfig({ latestVersion: 'a'.repeat(50) }).ok).toBe(false);
    expect(validateConfig({ latestVersion: 'x!@#' }).ok).toBe(false);
  });

  it('ignores unknown fields (strips them)', () => {
    const r = validateConfig({ latestVersion: '1.2.3', hackerField: 'x' });
    expect(r.ok).toBe(true);
    expect('hackerField' in r.clean).toBe(false);
  });
});

describe('validateAds', () => {
  it('accepts the default ads object', () => {
    const r = validateAds({
      enabled: true,
      testMode: false,
      admobAppId: 'ca-app-pub-3940256099942544~3347511713',
      bannerUnitId: 'ca-app-pub-3940256099942544/6300978111',
      interstitialUnitId: 'ca-app-pub-3940256099942544/1033173712',
      rewardedUnitId: 'ca-app-pub-3940256099942544/5224354917',
      refreshMinutes: 30,
    });
    expect(r.ok).toBe(true);
  });

  it('rejects malformed admob ids', () => {
    const r = validateAds({ bannerUnitId: 'javascript:alert(1)' });
    expect(r.ok).toBe(false);
    expect(r.errors.bannerUnitId).toBeTruthy();
  });

  it('allows empty unit ids (→ stored as empty string)', () => {
    const r = validateAds({ bannerUnitId: '' });
    expect(r.ok).toBe(true);
    expect(r.clean.bannerUnitId).toBe('');
  });

  it('rejects out-of-range refreshMinutes', () => {
    expect(validateAds({ refreshMinutes: 0 }).ok).toBe(false);
    expect(validateAds({ refreshMinutes: 100000 }).ok).toBe(false);
    expect(validateAds({ refreshMinutes: 30.5 }).ok).toBe(false);
    expect(validateAds({ refreshMinutes: 60 }).ok).toBe(true);
  });

  it('rejects null testMode', () => {
    expect(validateAds({ testMode: null }).ok).toBe(false);
  });
});

describe('validateAnnouncement', () => {
  it('accepts a full announcement with a valid window', () => {
    const r = validateAnnouncement({
      title: 'নতুন আপডেট',
      body: 'ভার্সন ২.১.২ এসেছে',
      kind: 'update',
      active: true,
      startsAt: '2026-01-01T00:00:00Z',
      endsAt: '2026-02-01T00:00:00Z',
    });
    expect(r.ok).toBe(true);
    expect(r.clean.kind).toBe('update');
  });

  it('rejects invalid kind', () => {
    expect(validateAnnouncement({ title: 't', body: 'b', kind: 'evil' }).ok).toBe(false);
  });

  it('rejects garbage dates', () => {
    const r = validateAnnouncement({ title: 't', body: 'b', startsAt: 'not-a-date' });
    expect(r.ok).toBe(false);
    expect(r.errors.startsAt).toBeTruthy();
  });

  it('rejects endsAt before startsAt', () => {
    const r = validateAnnouncement({
      title: 't',
      body: 'b',
      startsAt: '2026-05-01T00:00:00Z',
      endsAt: '2026-04-01T00:00:00Z',
    });
    expect(r.ok).toBe(false);
    expect(r.errors.endsAt).toMatch(/after/);
  });

  it('defaults kind to info and active to true', () => {
    const r = validateAnnouncement({ title: 't', body: 'b' });
    expect(r.clean.kind).toBe('info');
    expect(r.clean.active).toBe(true);
  });
});

describe('validateUserSync', () => {
  it('accepts a realistic Google uid', () => {
    expect(validateUserSync({ uid: '1049585732987392837' }).ok).toBe(true);
    expect(validateUserSync({ uid: 'google_1234' }).ok).toBe(true);
  });

  it('rejects short/empty/garbage uids', () => {
    expect(validateUserSync({ uid: '' }).ok).toBe(false);
    expect(validateUserSync({ uid: 'ab' }).ok).toBe(false);
    expect(validateUserSync({ uid: 'has space in it' }).ok).toBe(false);
    expect(validateUserSync({ uid: ' UNION SELECT * FROM users--' }).ok).toBe(false);
    expect(validateUserSync({}).ok).toBe(false);
  });

  it('rejects clearly invalid emails', () => {
    expect(validateUserSync({ uid: '12345678', email: 'nope' }).ok).toBe(false);
    expect(validateUserSync({ uid: '12345678', email: 'a@b.com' }).ok).toBe(true);
    expect(validateUserSync({ uid: '12345678', email: '' }).ok).toBe(true);
  });
});

describe('escapeLike', () => {
  it('escapes SQL LIKE wildcards', () => {
    expect(escapeLike('100%')).toBe('100\\%');
    expect(escapeLike('a_b')).toBe('a\\_b');
    expect(escapeLike('plain')).toBe('plain');
    expect(escapeLike('back\\slash')).toBe('back\\\\slash');
  });
});
