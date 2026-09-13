import { useState } from 'react';
import { api, sleep } from '../api.js';
import { Button, Card, Input, Modal } from '../components.jsx';

const MAX_BATCHES = 5_000; // 40 users/batch → 200k users; generous hard stop

/**
 * Global push — the Worker sends 40 users per request (free-plan safe),
 * this view repeats the call with the returned cursor/offset until everyone
 * got it. v2: validates every batch response, survives 429 with backoff,
 * prefers the stable cursor paging and never reports a truncated push as
 * "done" (the old loop silently stopped after 4000 users).
 */
export default function GlobalPushView({ toast }) {
  const [title, setTitle] = useState('');
  const [body, setBody] = useState('');
  const [busy, setBusy] = useState(false);
  const [progress, setProgress] = useState(null); // {sent, failed, total, done}
  const [confirming, setConfirming] = useState(false);

  const send = async () => {
    setConfirming(false);
    if (!title.trim() || !body.trim()) return;
    setBusy(true);
    setProgress({ sent: 0, failed: 0, total: 0, done: false });
    try {
      let offset = 0;
      let cursor = null;
      let sent = 0;
      let failed = 0;
      let total = 0;
      let truncated = false;

      for (let batch = 0; batch < MAX_BATCHES; batch++) {
        let res;
        // Retry the SAME batch on 429/5xx instead of aborting the broadcast.
        for (let attempt = 0; ; attempt++) {
          try {
            res = await api('/api/v1/admin/push', {
              method: 'POST',
              body: {
                title: title.trim(),
                body: body.trim(),
                offset,
                ...(cursor ? { cursor } : {}),
              },
            });
            break;
          } catch (e) {
            const retriable = e.status === 429 || e.status === 0 || e.status >= 500;
            if (!retriable || attempt >= 3) throw e;
            await sleep(Math.min(30, (e.retryAfter ?? 5) * (attempt + 1)) * 1000);
          }
        }

        // Guard against a malformed response producing fake "success".
        if (
          typeof res.sent !== 'number' ||
          typeof res.failed !== 'number' ||
          typeof res.total !== 'number'
        ) {
          throw new Error(`Malformed push response after ${sent} delivered — stopped.`);
        }

        sent += res.sent;
        failed += res.failed;
        total = res.total;
        setProgress({ sent, failed, total, done: false });

        const more =
          (res.nextCursor != null && typeof res.nextCursor === 'object') ||
          (res.nextCursor == null && res.nextOffset != null);

        if (!more) break;
        if (res.nextCursor && typeof res.nextCursor === 'object') {
          cursor = res.nextCursor;
          offset = 0;
        } else {
          offset = res.nextOffset;
          cursor = null;
        }
        if (batch === MAX_BATCHES - 1) truncated = true;
      }

      setProgress({ sent, failed, total, done: true });
      if (truncated) {
        toast(`Stopped at the safety limit after ${sent} delivered — resume manually`, 'err');
      } else {
        toast(`Global push done — ${sent} delivered, ${failed} failed`);
      }
    } catch (e) {
      toast(`Push failed: ${e.message}`, 'err');
      setProgress((p) => (p ? { ...p, done: true } : null));
    } finally {
      setBusy(false);
    }
  };

  const askConfirm = () => {
    if (!title.trim() || !body.trim()) return;
    setConfirming(true);
  };

  return (
    <div className="grid gap-4 md:grid-cols-2">
      <Card title="Send to ALL users">
        <div className="space-y-4">
          <Input label="Title" value={title} onChange={setTitle} placeholder="সবাইকে জানানোর শিরোনাম" />
          <Input label="Body" value={body} onChange={setBody} placeholder="মেসেজ…" />
          <div className="rounded-xl bg-slate-50 px-3.5 py-2.5 text-[11px] leading-relaxed text-slate-500">
            Delivered as a real FCM notification to every user with a synced FCM
            token (40 per batch, automatically paged). Reachable users are shown
            on the Dashboard tab. <b>This cannot be undone.</b>
          </div>
          <Button
            onClick={askConfirm}
            disabled={busy || !title.trim() || !body.trim()}
            className="w-full"
          >
            {busy ? 'Sending…' : 'Send global push'}
          </Button>
        </div>
      </Card>

      <Card title="Progress">
        {!progress ? (
          <div className="py-10 text-center text-sm text-slate-400">
            Nothing sent yet.
          </div>
        ) : (
          <div className="space-y-4">
            <div className="grid grid-cols-3 gap-3 text-center">
              <div className="rounded-xl bg-green-50 p-4">
                <div className="text-2xl font-bold text-green-700">{progress.sent}</div>
                <div className="text-[11px] font-semibold text-green-600">delivered</div>
              </div>
              <div className="rounded-xl bg-red-50 p-4">
                <div className="text-2xl font-bold text-red-700">{progress.failed}</div>
                <div className="text-[11px] font-semibold text-red-600">failed</div>
              </div>
              <div className="rounded-xl bg-slate-50 p-4">
                <div className="text-2xl font-bold text-slate-700">{progress.total}</div>
                <div className="text-[11px] font-semibold text-slate-500">pushable</div>
              </div>
            </div>
            <div className="h-2.5 overflow-hidden rounded-full bg-slate-100">
              <div
                className="h-full rounded-full bg-brand-500 transition-all"
                style={{
                  width: `${
                    progress.total
                      ? Math.min(100, ((progress.sent + progress.failed) / progress.total) * 100)
                      : 0
                  }%`,
                }}
              />
            </div>
            <div className="text-center text-xs text-slate-400">
              {progress.done ? 'Done ✓' : 'Sending in batches…'}
            </div>
          </div>
        )}
      </Card>

      <Modal open={confirming} title="Confirm global push" onClose={() => setConfirming(false)}>
        <div className="space-y-4">
          <p className="text-sm text-slate-600">
            This sends a real push notification to <b>every user with a synced FCM
            token</b>. Make sure the title and message are final — there is no undo.
          </p>
          <div className="rounded-xl bg-slate-50 p-3.5 text-sm">
            <div className="font-semibold text-slate-700">{title}</div>
            <div className="mt-1 text-slate-500">{body}</div>
          </div>
          <div className="flex justify-end gap-2">
            <Button kind="ghost" onClick={() => setConfirming(false)}>
              Cancel
            </Button>
            <Button kind="danger" onClick={send}>
              Send to everyone
            </Button>
          </div>
        </div>
      </Modal>
    </div>
  );
}
