import { useState } from 'react';
import { checkLogin, getBase, getKey, saveApi } from '../api.js';
import { Button, Input } from '../components.jsx';

export default function LoginView({ onDone, toast }) {
  const [base, setBase] = useState(getBase() || 'https://');
  const [key, setKey] = useState(getKey());
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');

  const submit = async (e) => {
    e.preventDefault();
    setError('');
    // Real URL validation: must parse and be https (http only for localhost).
    let u;
    try {
      u = new URL(base.trim());
    } catch {
      setError('Enter the full Worker URL (https://…)');
      return;
    }
    if (u.protocol !== 'https:' && !/^localhost|127\.0\.0\.1|\[::1\]$/.test(u.hostname)) {
      setError('Only https:// URLs are supported (except localhost for dev).');
      return;
    }
    setBusy(true);
    try {
      await checkLogin(base, key);
      saveApi(base, key);
      toast('Signed in');
      onDone();
    } catch (err) {
      setError(err.message);
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="flex min-h-screen items-center justify-center bg-slate-900 p-4">
      <form
        onSubmit={submit}
        className="w-full max-w-sm rounded-3xl bg-white p-7 shadow-2xl"
      >
        <div className="mb-1 flex items-center gap-3">
          <div className="flex h-11 w-11 items-center justify-center rounded-2xl bg-slate-900 text-xl font-bold text-brand-500">
            ৳
          </div>
          <div>
            <div className="text-lg font-bold text-slate-800">MoneyBag Admin</div>
            <div className="text-xs text-slate-400">Cloudflare Worker control panel</div>
          </div>
        </div>

        <div className="mt-6 space-y-4">
          <Input
            label="Worker API URL"
            value={base}
            onChange={setBase}
            placeholder="https://moneybag-api.your-name.workers.dev"
            hint="From `npx wrangler deploy` output"
          />
          <Input
            label="Admin API Key"
            value={key}
            onChange={setKey}
            placeholder="the ADMIN_API_KEY secret"
            hint="Set with `npx wrangler secret put ADMIN_API_KEY`"
          />
        </div>

        {error && (
          <div className="mt-4 rounded-xl bg-red-50 px-3 py-2 text-xs font-medium text-red-600">
            {error}
          </div>
        )}

        <Button type="submit" disabled={busy} className="mt-6 w-full">
          {busy ? 'Checking…' : 'Sign in'}
        </Button>
      </form>
    </div>
  );
}
