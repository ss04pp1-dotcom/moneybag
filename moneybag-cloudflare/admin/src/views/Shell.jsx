import { useState } from 'react';
import LoginView from './LoginView.jsx';
import DashboardView from './DashboardView.jsx';
import UsersView from './UsersView.jsx';
import GlobalPushView from './GlobalPushView.jsx';
import ConfigView from './ConfigView.jsx';
import AnnouncementsView from './AnnouncementsView.jsx';

const TABS = [
  { id: 'dashboard', label: 'Dashboard', icon: '📊' },
  { id: 'users', label: 'Users', icon: '👥' },
  { id: 'push', label: 'Global Push', icon: '📣' },
  { id: 'config', label: 'Ads & Config', icon: '⚙️' },
  { id: 'announcements', label: 'Announcements', icon: '📢' },
];

export default function Shell({ onLogout, toast }) {
  const [tab, setTab] = useState('dashboard');

  return (
    <div className="min-h-screen">
      {/* top bar */}
      <header className="sticky top-0 z-40 border-b border-slate-200 bg-white/90 backdrop-blur">
        <div className="mx-auto flex max-w-6xl items-center justify-between px-4 py-3">
          <div className="flex items-center gap-2.5">
            <div className="flex h-9 w-9 items-center justify-center rounded-xl bg-slate-900 text-base font-bold text-brand-500">
              ৳
            </div>
            <div>
              <div className="text-sm font-bold text-slate-800">MoneyBag Admin</div>
              <div className="text-[10px] text-slate-400">Cloudflare Worker + D1</div>
            </div>
          </div>
          <button
            onClick={onLogout}
            className="rounded-xl px-3 py-1.5 text-xs font-semibold text-slate-500 ring-1 ring-slate-200 transition hover:bg-slate-50"
          >
            Sign out
          </button>
        </div>

        {/* tabs */}
        <nav className="mx-auto max-w-6xl overflow-x-auto px-4">
          <div className="flex gap-1 pb-2">
            {TABS.map((t) => (
              <button
                key={t.id}
                onClick={() => setTab(t.id)}
                className={`whitespace-nowrap rounded-xl px-3.5 py-2 text-sm font-semibold transition ${
                  tab === t.id
                    ? 'bg-slate-900 text-white'
                    : 'text-slate-500 hover:bg-slate-100'
                }`}
              >
                <span className="mr-1.5">{t.icon}</span>
                {t.label}
              </button>
            ))}
          </div>
        </nav>
      </header>

      <main className="mx-auto max-w-6xl px-4 py-6">
        {tab === 'dashboard' && <DashboardView toast={toast} />}
        {tab === 'users' && <UsersView toast={toast} />}
        {tab === 'push' && <GlobalPushView toast={toast} />}
        {tab === 'config' && <ConfigView toast={toast} />}
        {tab === 'announcements' && <AnnouncementsView toast={toast} />}
      </main>
    </div>
  );
}
