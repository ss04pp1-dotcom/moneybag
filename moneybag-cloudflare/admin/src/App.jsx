import { useEffect, useState } from 'react';
import { api, clearApi, getBase, getKey } from './api.js';
import { Toast, useToast } from './components.jsx';
import LoginView from './views/LoginView.jsx';
import Shell from './views/Shell.jsx';

export default function App() {
  const [authed, setAuthed] = useState(() => Boolean(getBase() && getKey()));
  const [checking, setChecking] = useState(true);
  const { toast, show } = useToast();

  // Re-validate the stored key on load.
  useEffect(() => {
    (async () => {
      if (!authed) {
        setChecking(false);
        return;
      }
      try {
        await api('/api/v1/admin/login');
      } catch (e) {
        if (e.status === 401) {
          clearApi();
          setAuthed(false);
        }
      }
      setChecking(false);
    })();
  }, [authed]);

  // The api client broadcasts this when ANY admin call returns 401 —
  // e.g. the key was rotated/removed server-side while the panel is open.
  useEffect(() => {
    const h = () => {
      clearApi();
      setAuthed(false);
    };
    window.addEventListener('mb:unauthorized', h);
    return () => window.removeEventListener('mb:unauthorized', h);
  }, []);

  const logout = () => {
    clearApi();
    setAuthed(false);
  };

  if (checking) {
    return (
      <div className="flex min-h-screen items-center justify-center">
        <div className="animate-pulse text-sm font-medium text-slate-400">Loading MoneyBag Admin…</div>
      </div>
    );
  }

  return (
    <>
      {authed ? (
        <Shell onLogout={logout} toast={show} />
      ) : (
        <LoginView
          onDone={() => setAuthed(true)}
          toast={show}
        />
      )}
      <Toast toast={toast} />
    </>
  );
}
