import { useEffect, useRef, useState } from 'react';
import { api, timeAgo } from '../api.js';
import { Badge, Button, Card, Stat } from '../components.jsx';

export default function DashboardView({ toast }) {
  const [ov, setOv] = useState(null);
  const [log, setLog] = useState([]);
  const [error, setError] = useState('');
  const inFlight = useRef(false);

  const load = async () => {
    if (inFlight.current) return; // don't stack requests on slow networks
    inFlight.current = true;
    try {
      const [overview, pushLog] = await Promise.all([
        api('/api/v1/admin/overview'),
        api('/api/v1/admin/push/log'),
      ]);
      setOv(overview);
      setLog(Array.isArray(pushLog?.pushes) ? pushLog.pushes : []);
      setError('');
    } catch (e) {
      // Keep the last-good data visible; show a banner instead of blanking.
      setError(e.message);
    } finally {
      inFlight.current = false;
    }
  };

  useEffect(() => {
    let alive = true;
    (async () => {
      const [overview, pushLog] = await Promise.all([
        api('/api/v1/admin/overview'),
        api('/api/v1/admin/push/log'),
      ]).catch(() => [null, null]);
      if (!alive) return;
      if (overview) {
        setOv(overview);
        setLog(Array.isArray(pushLog?.pushes) ? pushLog.pushes : []);
      } else {
        setError('Could not load the dashboard.');
      }
    })();
    const t = setInterval(() => load(), 30000);
    return () => {
      alive = false;
      clearInterval(t);
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  if (!ov) {
    return (
      <div className="space-y-4">
        {error && (
          <div className="flex items-center justify-between gap-4 rounded-2xl bg-red-50 p-5 text-sm font-medium text-red-600">
            <span>{error}</span>
            <Button kind="ghost" onClick={load} className="!px-3 !py-1.5 !text-xs">
              Retry
            </Button>
          </div>
        )}
        {!error && <div className="animate-pulse text-sm text-slate-400">Loading…</div>}
      </div>
    );
  }

  return (
    <div className="space-y-6">
      {error && (
        <div className="flex items-center justify-between gap-4 rounded-2xl bg-amber-50 p-4 text-sm font-medium text-amber-700">
          <span>Showing cached data — {error}</span>
          <Button kind="ghost" onClick={load} className="!px-3 !py-1.5 !text-xs">
            Retry
          </Button>
        </div>
      )}
      <div className="grid grid-cols-2 gap-4 md:grid-cols-4">
        <Stat label="Total Users" value={ov.users} sub={`${ov.usersWithToken} pushable`} tone="blue" />
        <Stat label="Pushes Sent" value={ov.pushSentTotal} sub="all-time" tone="green" />
        <Stat
          label="Announcements"
          value={ov.announcementsActive}
          sub={`${ov.announcementsTotal} total`}
          tone="amber"
        />
        <Stat
          label="Ads"
          value={ov.ads?.enabled ? 'ON' : 'OFF'}
          sub={ov.ads?.testMode ? 'test mode' : 'live ids'}
          tone={ov.ads?.enabled ? 'green' : 'slate'}
        />
      </div>

      <div className="grid gap-4 md:grid-cols-2">
        <Card title="App status">
          <ul className="divide-y divide-slate-100 text-sm">
            <li className="flex items-center justify-between py-2.5">
              <span className="text-slate-500">Maintenance mode</span>
              <Badge tone={ov.config?.maintenance ? 'red' : 'green'}>
                {ov.config?.maintenance ? 'ON' : 'OFF'}
              </Badge>
            </li>
            <li className="flex items-center justify-between py-2.5">
              <span className="text-slate-500">Force update</span>
              <Badge tone={ov.config?.forceUpdate ? 'amber' : 'green'}>
                {ov.config?.forceUpdate ? 'ON' : 'OFF'}
              </Badge>
            </li>
            <li className="flex items-center justify-between py-2.5">
              <span className="text-slate-500">Min version</span>
              <span className="font-semibold text-slate-700">{ov.config?.minVersion ?? '—'}</span>
            </li>
            <li className="flex items-center justify-between py-2.5">
              <span className="text-slate-500">Latest version</span>
              <span className="font-semibold text-slate-700">{ov.config?.latestVersion ?? '—'}</span>
            </li>
          </ul>
        </Card>

        <Card title="Recent pushes" right={<span className="text-[11px] text-slate-400">auto-refresh 30s</span>}>
          {log.length === 0 ? (
            <div className="py-8 text-center text-sm text-slate-400">
              No pushes yet — send one from the Users or Global Push tab.
            </div>
          ) : (
            <ul className="divide-y divide-slate-100 text-sm">
              {log.slice(0, 8).map((p) => (
                <li key={p.id} className="py-2.5">
                  <div className="flex items-center justify-between gap-2">
                    <span className="truncate font-medium text-slate-700">{p.title}</span>
                    <span className="shrink-0 text-[11px] text-slate-400">{timeAgo(p.created)}</span>
                  </div>
                  <div className="flex items-center gap-2 text-[11px] text-slate-400">
                    <Badge tone={p.target === 'all' ? 'blue' : 'slate'}>{p.target}</Badge>
                    <span>
                      ✓ {p.sent} · ✗ {p.failed}
                    </span>
                  </div>
                </li>
              ))}
            </ul>
          )}
        </Card>
      </div>
    </div>
  );
}
