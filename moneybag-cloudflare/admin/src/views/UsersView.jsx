import { useEffect, useRef, useState } from 'react';
import { api, timeAgo } from '../api.js';
import { Badge, Button, Card, Input, Modal } from '../components.jsx';

const PAGE_SIZE = 200;

export default function UsersView({ toast }) {
  const [users, setUsers] = useState(null);
  const [total, setTotal] = useState(0);
  const [search, setSearch] = useState('');
  const [page, setPage] = useState(0);
  const [error, setError] = useState('');

  // push modal state
  const [target, setTarget] = useState(null);
  const [title, setTitle] = useState('');
  const [body, setBody] = useState('');
  const [busy, setBusy] = useState(false);

  // Sequence guard: a stale in-flight search response must never clobber
  // the list of a newer one (the old view had this race).
  const seq = useRef(0);

  const load = async (q = '', p = 0) => {
    const id = ++seq.current;
    try {
      const res = await api(
        `/api/v1/admin/users?limit=${PAGE_SIZE}&offset=${p * PAGE_SIZE}` +
          `${q ? `&search=${encodeURIComponent(q)}` : ''}`
      );
      if (id !== seq.current) return; // stale response — discard
      setUsers(Array.isArray(res.users) ? res.users : []);
      setTotal(typeof res.total === 'number' ? res.total : 0);
      setError('');
    } catch (e) {
      if (id === seq.current) setError(e.message);
    }
  };

  // Debounced load — also covers the initial mount (no duplicate fetch).
  useEffect(() => {
    const t = setTimeout(() => load(search, page), search ? 350 : 0);
    return () => clearTimeout(t);
  }, [search, page]);

  const sendPush = async () => {
    if (!target || !title.trim() || !body.trim()) return;
    setBusy(true);
    try {
      await api('/api/v1/admin/users/push', {
        method: 'POST',
        body: { uid: target.uid, title: title.trim(), body: body.trim() },
      });
      toast(`Notification sent to ${target.name || target.email || target.uid}`);
      setTarget(null);
      setTitle('');
      setBody('');
    } catch (e) {
      toast(`Failed: ${e.message}`, 'err');
    } finally {
      setBusy(false);
    }
  };

  const hasMore = users != null && users.length === PAGE_SIZE;

  return (
    <div className="space-y-4">
      <Card
        title={
          search
            ? `${users?.length ?? 0} match${(users?.length ?? 0) === 1 ? '' : 'es'} for “${search}”`
            : `Registered users (${total})`
        }
        right={
          <input
            value={search}
            onChange={(e) => {
              setSearch(e.target.value);
              setPage(0); // reset pagination when the filter changes
            }}
            placeholder="Search name / email…"
            className="w-48 rounded-xl border border-slate-200 px-3 py-1.5 text-xs outline-none focus:border-brand-500 focus:ring-2 focus:ring-brand-100 sm:w-64"
          />
        }
      >
        {error && (
          <div className="flex items-center justify-between gap-3 rounded-xl bg-red-50 px-4 py-2.5 text-sm font-medium text-red-600">
            <span>{error}</span>
            <Button kind="ghost" onClick={() => load(search, page)} className="!px-3 !py-1 !text-xs">
              Retry
            </Button>
          </div>
        )}
        {!users ? (
          <div className="animate-pulse py-8 text-center text-sm text-slate-400">Loading…</div>
        ) : users.length === 0 ? (
          <div className="py-10 text-center text-sm text-slate-400">
            {search
              ? 'No users match this search.'
              : 'No users yet. Users appear here automatically right after they sign in with Google inside the app.'}
          </div>
        ) : (
          <>
            <div className="-mx-5 overflow-x-auto">
              <table className="min-w-full text-sm">
                <thead>
                  <tr className="border-b border-slate-100 text-left text-[11px] uppercase tracking-wide text-slate-400">
                    <th className="px-5 py-2 font-semibold">User</th>
                    <th className="px-3 py-2 font-semibold">Platform</th>
                    <th className="px-3 py-2 font-semibold">App</th>
                    <th className="px-3 py-2 font-semibold">Last login</th>
                    <th className="px-3 py-2 font-semibold">Push</th>
                    <th className="px-5 py-2" />
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-50">
                  {users.map((u) => (
                    <tr key={u.uid} className="hover:bg-slate-50/60">
                      <td className="px-5 py-3">
                        <div className="font-semibold text-slate-700">
                          {u.name || '(no name)'}
                        </div>
                        <div className="text-xs text-slate-400">{u.email || '—'}</div>
                      </td>
                      <td className="px-3 py-3 text-xs text-slate-500">
                        {u.platform || '—'}
                      </td>
                      <td className="px-3 py-3 text-xs text-slate-500">
                        {u.appVersion || '—'}
                      </td>
                      <td className="px-3 py-3 text-xs text-slate-500">
                        {timeAgo(u.lastLogin)}
                      </td>
                      <td className="px-3 py-3">
                        <Badge tone={u.hasToken ? 'green' : 'slate'}>
                          {u.hasToken ? 'ready' : 'no token'}
                        </Badge>
                      </td>
                      <td className="px-5 py-3 text-right">
                        <Button
                          kind="soft"
                          disabled={!u.hasToken}
                          onClick={() => setTarget(u)}
                          className="!px-3 !py-1.5 !text-xs"
                        >
                          Send Notification
                        </Button>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
            {!search && (
              <div className="flex items-center justify-between pt-4 text-xs text-slate-400">
                <span>
                  {total > 0
                    ? `Showing ${page * PAGE_SIZE + 1}–${page * PAGE_SIZE + users.length} of ${total}`
                    : ''}
                </span>
                <div className="flex gap-2">
                  <Button
                    kind="ghost"
                    disabled={page === 0}
                    onClick={() => setPage((p) => Math.max(0, p - 1))}
                    className="!px-3 !py-1.5 !text-xs"
                  >
                    ← Prev
                  </Button>
                  <Button
                    kind="ghost"
                    disabled={!hasMore}
                    onClick={() => setPage((p) => p + 1)}
                    className="!px-3 !py-1.5 !text-xs"
                  >
                    Next →
                  </Button>
                </div>
              </div>
            )}
          </>
        )}
      </Card>

      <Modal
        open={Boolean(target)}
        title={`Send to ${target?.name || target?.email || target?.uid || ''}`}
        onClose={() => setTarget(null)}
      >
        <div className="space-y-4">
          <Input label="Title" value={title} onChange={setTitle} placeholder="নোটিফিকেশনের শিরোনাম" />
          <Input label="Body" value={body} onChange={setBody} placeholder="মেসেজ…" />
          <div className="flex justify-end gap-2 pt-1">
            <Button kind="ghost" onClick={() => setTarget(null)}>
              Cancel
            </Button>
            <Button onClick={sendPush} disabled={busy || !title.trim() || !body.trim()}>
              {busy ? 'Sending…' : 'Send now'}
            </Button>
          </div>
        </div>
      </Modal>
    </div>
  );
}
