import { useEffect, useState } from 'react';
import { api, timeAgo } from '../api.js';
import { Badge, Button, Card, Input } from '../components.jsx';

const KINDS = ['info', 'update', 'promo'];

/** datetime-local value → ISO 8601 (or null when empty). */
const toIso = (v) => (v ? new Date(v).toISOString() : null);

export default function AnnouncementsView({ toast }) {
  const [items, setItems] = useState(null);
  const [title, setTitle] = useState('');
  const [body, setBody] = useState('');
  const [kind, setKind] = useState('info');
  const [startsAt, setStartsAt] = useState(''); // datetime-local strings
  const [endsAt, setEndsAt] = useState('');
  const [busy, setBusy] = useState(false);
  const [busyId, setBusyId] = useState(null); // guards toggle/delete double-clicks
  const [error, setError] = useState('');

  const load = async () => {
    try {
      const res = await api('/api/v1/admin/announcements');
      setItems(Array.isArray(res) ? res : []);
      setError('');
    } catch (e) {
      setError(e.message);
    }
  };

  useEffect(() => {
    load();
  }, []);

  const create = async () => {
    if (!title.trim() || !body.trim()) return;
    // Client-side date validation mirrors the Worker's rules.
    if (startsAt && endsAt && new Date(startsAt) >= new Date(endsAt)) {
      toast('End date must be after the start date', 'err');
      return;
    }
    setBusy(true);
    try {
      await api('/api/v1/admin/announcements', {
        method: 'POST',
        body: {
          title: title.trim(),
          body: body.trim(),
          kind,
          startsAt: toIso(startsAt),
          endsAt: toIso(endsAt),
        },
      });
      toast('Announcement published');
      setTitle('');
      setBody('');
      setStartsAt('');
      setEndsAt('');
      load();
    } catch (e) {
      toast(`Failed: ${e.message}`, 'err');
    } finally {
      setBusy(false);
    }
  };

  const toggle = async (id) => {
    if (busyId) return;
    setBusyId(id);
    try {
      await api(`/api/v1/admin/announcements/${id}/toggle`, { method: 'PATCH' });
      await load();
    } catch (e) {
      toast(`Failed: ${e.message}`, 'err');
    } finally {
      setBusyId(null);
    }
  };

  const remove = async (id) => {
    if (!window.confirm('Delete this announcement?')) return;
    if (busyId) return;
    setBusyId(id);
    try {
      await api(`/api/v1/admin/announcements/${id}`, { method: 'DELETE' });
      toast('Deleted');
      await load();
    } catch (e) {
      toast(`Failed: ${e.message}`, 'err');
    } finally {
      setBusyId(null);
    }
  };

  const fmtDate = (iso) => {
    if (!iso) return null;
    const d = new Date(iso);
    return Number.isNaN(d.getTime()) ? null : d.toLocaleString();
  };

  return (
    <div className="grid gap-4 md:grid-cols-2">
      <Card title="New announcement">
        <div className="space-y-4">
          <Input label="Title" value={title} onChange={setTitle} placeholder="শিরোনাম…" />
          <Input label="Body" value={body} onChange={setBody} placeholder="বিস্তারিত…" />
          <div>
            <span className="mb-1 block text-xs font-semibold text-slate-500">Kind</span>
            <div className="flex gap-2">
              {KINDS.map((k) => (
                <button
                  key={k}
                  onClick={() => setKind(k)}
                  className={`rounded-xl px-3.5 py-1.5 text-xs font-semibold transition ${
                    kind === k
                      ? 'bg-slate-900 text-white'
                      : 'bg-slate-100 text-slate-500 hover:bg-slate-200'
                  }`}
                >
                  {k}
                </button>
              ))}
            </div>
          </div>
          <div className="grid grid-cols-2 gap-3">
            <Input
              label="Show from (optional)"
              type="datetime-local"
              value={startsAt}
              onChange={setStartsAt}
              hint="Empty = visible immediately"
            />
            <Input
              label="Hide after (optional)"
              type="datetime-local"
              value={endsAt}
              onChange={setEndsAt}
              hint="Empty = no end date"
            />
          </div>
          <Button onClick={create} disabled={busy || !title.trim() || !body.trim()} className="w-full">
            {busy ? 'Publishing…' : 'Publish'}
          </Button>
          <div className="rounded-xl bg-slate-50 px-3.5 py-2.5 text-[11px] leading-relaxed text-slate-500">
            Announcements appear on the app's dashboard the next time it
            refreshes its remote config. Kind colors: info = blue, update =
            amber, promo = green. Dates are optional — use them to schedule
            time-boxed campaigns.
          </div>
        </div>
      </Card>

      <Card title={`All announcements (${items?.length ?? 0})`}>
        {error && (
          <div className="flex items-center justify-between gap-3 rounded-xl bg-red-50 px-4 py-2.5 text-sm font-medium text-red-600">
            <span>{error}</span>
            <Button kind="ghost" onClick={load} className="!px-3 !py-1 !text-xs">
              Retry
            </Button>
          </div>
        )}
        {!items ? (
          <div className="animate-pulse py-8 text-center text-sm text-slate-400">Loading…</div>
        ) : items.length === 0 ? (
          <div className="py-10 text-center text-sm text-slate-400">
            No announcements yet.
          </div>
        ) : (
          <ul className="space-y-3">
            {items.map((a) => {
              const from = fmtDate(a.startsAt);
              const to = fmtDate(a.endsAt);
              return (
                <li
                  key={a.id}
                  className="rounded-xl border border-slate-100 p-3.5 transition hover:border-slate-200"
                >
                  <div className="flex items-start justify-between gap-3">
                    <div className="min-w-0">
                      <div className="flex items-center gap-2">
                        <span className="truncate text-sm font-semibold text-slate-700">
                          {a.title}
                        </span>
                        <Badge
                          tone={
                            a.kind === 'promo' ? 'green' : a.kind === 'update' ? 'amber' : 'blue'
                          }
                        >
                          {a.kind}
                        </Badge>
                        {!a.active && <Badge tone="red">hidden</Badge>}
                      </div>
                      <p className="mt-1 line-clamp-2 text-xs text-slate-500">{a.body}</p>
                      {(from || to) && (
                        <p className="mt-1 text-[11px] text-slate-400">
                          ⏱ {from ?? '…'} → {to ?? '∞'}
                        </p>
                      )}
                      <p className="mt-1 text-[11px] text-slate-400">
                        created {timeAgo(a.created)}
                      </p>
                    </div>
                    <div className="flex shrink-0 gap-1.5">
                      <Button
                        kind="ghost"
                        disabled={busyId === a.id}
                        onClick={() => toggle(a.id)}
                        className="!px-2.5 !py-1 !text-xs"
                      >
                        {busyId === a.id ? '…' : a.active ? 'Hide' : 'Show'}
                      </Button>
                      <Button
                        kind="danger"
                        disabled={busyId === a.id}
                        onClick={() => remove(a.id)}
                        className="!px-2.5 !py-1 !text-xs"
                      >
                        Delete
                      </Button>
                    </div>
                  </div>
                </li>
              );
            })}
          </ul>
        )}
      </Card>
    </div>
  );
}
