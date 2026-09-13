import { useEffect, useState } from 'react';
import { api } from '../api.js';
import { Button, Card, Input, Toggle } from '../components.jsx';

export default function ConfigView({ toast }) {
  const [config, setConfig] = useState(null);
  const [ads, setAds] = useState(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');

  const load = async () => {
    try {
      const [c, a] = await Promise.all([
        api('/api/v1/admin/config'),
        api('/api/v1/admin/ads'),
      ]);
      setConfig(c && typeof c === 'object' ? c : null);
      setAds(a && typeof a === 'object' ? a : null);
      setError('');
    } catch (e) {
      setError(e.message);
    }
  };

  useEffect(() => {
    let alive = true;
    (async () => {
      try {
        const [c, a] = await Promise.all([
          api('/api/v1/admin/config'),
          api('/api/v1/admin/ads'),
        ]);
        if (!alive) return;
        setConfig(c && typeof c === 'object' ? c : null);
        setAds(a && typeof a === 'object' ? a : null);
      } catch (e) {
        if (alive) setError(e.message);
      }
    })();
    return () => {
      alive = false;
    };
  }, []);

  if (error) {
    return (
      <div className="flex items-center justify-between gap-4 rounded-2xl bg-red-50 p-5 text-sm font-medium text-red-600">
        <span>{error}</span>
        <Button kind="ghost" onClick={load} className="!px-3 !py-1.5 !text-xs">
          Retry
        </Button>
      </div>
    );
  }
  if (!config || !ads) {
    return <div className="animate-pulse text-sm text-slate-400">Loading…</div>;
  }

  /**
   * PUT whitelisted, type-safe fields only.
   * The server validates strictly now — a message with one empty field or a
   * null boolean would be rejected, so the payload is normalised here:
   *   - message: both fields empty → null (no notice), else both required
   *   - booleans are real booleans, versions trimmed
   */
  const buildConfigPayload = () => ({
    latestVersion: String(config.latestVersion ?? '').trim(),
    minVersion: String(config.minVersion ?? '').trim(),
    forceUpdate: config.forceUpdate === true,
    maintenance: config.maintenance === true,
    message:
      config.message &&
      (String(config.message.title ?? '').trim() || String(config.message.body ?? '').trim())
        ? {
            title: String(config.message.title ?? '').trim(),
            body: String(config.message.body ?? '').trim(),
          }
        : null,
  });

  const buildAdsPayload = () => ({
    enabled: ads.enabled === true,
    testMode: ads.testMode !== false, // null/undefined → ON (server default)
    admobAppId: String(ads.admobAppId ?? '').trim(),
    bannerUnitId: String(ads.bannerUnitId ?? '').trim(),
    interstitialUnitId: String(ads.interstitialUnitId ?? '').trim(),
    rewardedUnitId: String(ads.rewardedUnitId ?? '').trim(),
    refreshMinutes:
      Number.isInteger(ads.refreshMinutes) && ads.refreshMinutes >= 1
        ? ads.refreshMinutes
        : 30,
  });

  const saveAds = async () => {
    setBusy(true);
    try {
      await api('/api/v1/admin/ads', { method: 'PUT', body: buildAdsPayload() });
      toast('Ads settings saved');
    } catch (e) {
      toast(`Save failed: ${e.message}`, 'err');
    } finally {
      setBusy(false);
    }
  };

  const saveConfig = async () => {
    setBusy(true);
    try {
      await api('/api/v1/admin/config', { method: 'PUT', body: buildConfigPayload() });
      toast('App config saved');
    } catch (e) {
      toast(`Save failed: ${e.message}`, 'err');
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="grid gap-4 md:grid-cols-2">
      {/* ── Ads ── */}
      <Card
        title="AdMob / Ads control"
        right={
          <Button onClick={saveAds} disabled={busy} className="!px-3 !py-1.5 !text-xs">
            Save ads
          </Button>
        }
      >
        <Toggle
          label="Ads enabled"
          hint="Master switch — off = no ad SDK activity in the app"
          checked={ads.enabled === true}
          onChange={(v) => setAds({ ...ads, enabled: v })}
        />
        <Toggle
          label="Test mode"
          hint="ON = Google's official test ad units (safe)"
          checked={ads.testMode !== false}
          onChange={(v) => setAds({ ...ads, testMode: v })}
        />
        <div className="mt-3 space-y-3 border-t border-slate-100 pt-4">
          <Input
            label="Banner unit ID"
            value={ads.bannerUnitId ?? ''}
            onChange={(v) => setAds({ ...ads, bannerUnitId: v })}
            placeholder="ca-app-pub-…"
          />
          <Input
            label="Interstitial unit ID"
            value={ads.interstitialUnitId ?? ''}
            onChange={(v) => setAds({ ...ads, interstitialUnitId: v })}
            placeholder="ca-app-pub-…"
          />
          <Input
            label="Rewarded unit ID"
            value={ads.rewardedUnitId ?? ''}
            onChange={(v) => setAds({ ...ads, rewardedUnitId: v })}
            placeholder="ca-app-pub-…"
          />
          <div className="rounded-xl bg-slate-50 px-3.5 py-2.5 text-[11px] leading-relaxed text-slate-500">
            While <b>test mode</b> is ON the app shows Google's safe test ads
            using these unit IDs — flip it off only after you replace them with
            your real AdMob unit IDs.
          </div>
        </div>
      </Card>

      {/* ── App config ── */}
      <Card
        title="App config"
        right={
          <Button onClick={saveConfig} disabled={busy} className="!px-3 !py-1.5 !text-xs">
            Save config
          </Button>
        }
      >
        <Toggle
          label="Maintenance mode"
          hint="Shows a maintenance notice inside the app"
          checked={config.maintenance === true}
          onChange={(v) => setConfig({ ...config, maintenance: v })}
        />
        <Toggle
          label="Force update"
          hint="Below-min-version apps ask the user to update"
          checked={config.forceUpdate === true}
          onChange={(v) => setConfig({ ...config, forceUpdate: v })}
        />
        <div className="mt-3 space-y-3 border-t border-slate-100 pt-4">
          <Input
            label="Minimum app version"
            value={config.minVersion ?? ''}
            onChange={(v) => setConfig({ ...config, minVersion: v })}
            hint="e.g. 1.0.0 — required, cannot be empty"
          />
          <Input
            label="Latest app version"
            value={config.latestVersion ?? ''}
            onChange={(v) => setConfig({ ...config, latestVersion: v })}
            hint="Shown as the current release"
          />
          <Input
            label="Maintenance notice title"
            value={config.message?.title ?? ''}
            onChange={(v) =>
              setConfig({
                ...config,
                message: { title: v, body: config.message?.body ?? '' },
              })
            }
          />
          <Input
            label="Maintenance notice body"
            value={config.message?.body ?? ''}
            onChange={(v) =>
              setConfig({
                ...config,
                message: { title: config.message?.title ?? '', body: v },
              })
            }
            hint="Both fields must be filled, or both empty to remove the notice"
          />
        </div>
      </Card>
    </div>
  );
}
