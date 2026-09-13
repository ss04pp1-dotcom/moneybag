# মানিব্যাগ — MoneyBag 🐷

**Track your money. Understand your spending. Build your savings.**

A local-first, privacy-first personal finance & expense tracker for Bangladesh.
Bengali-first UI, BDT (৳) currency, works fully offline — your financial data
never leaves your device. MoneyBag is a pure record-keeping app: it is **not**
a banking app and never asks for bank accounts or passwords.

Optional (off by default): the **Cloudflare Worker API**
(`../moneybag-cloudflare/worker/`) can push announcements, toggle AdMob ads
and version notices into the app — it never sees any financial record.

| | |
|---|---|
| Platform | Android 5.0+ (minSdk 21) · iOS 12+ |
| Framework | Flutter 3.24 / Dart 3.5 (single codebase) |
| Storage | SQLite via Drift (versioned schema + migrations) |
| State | Provider (`ChangeNotifier`) |
| Backup | AES-256-GCM + PBKDF2 encrypted `.mbbak` — local, share, Google Drive |
| Language | বাংলা (default) + English, in-app toggle |
| Currency | BDT ৳ — lakh/crore grouping, Bengali numerals option |

---

## Features

- **Branded splash** — the MoneyBag logo animates in on a deep-green screen
  on every launch (native launch screen + in-app intro, no white flash),
  then the app opens
- **Login** — Google Sign-In is the only login option (shown once after
  onboarding; a "continue without signing in" escape keeps everything
  local-first). Signing in pre-fills the name/photo and unlocks one-tap
  Drive backup. Sign in/out anytime from Profile → Account
- **Onboarding** — 6-screen Bengali-first intro → login → 1-time profile
  setup (name, photo, optional monthly income, language, theme —
  pre-filled from Google when signed in)
- **Profile photo** — pick from camera or gallery, stored privately in the
  app's documents directory, shown on the dashboard & profile
- **Dashboard** — FIXED branded greeting banner (deep-green gradient with
  the app logo watermark + slow shimmer sweep, "শুভ সকাল" + your name +
  profile photo on top), monthly income/expense/net savings with a count-up
  animation, savings-rate chip, admin announcement card (remote), auto-rotating
  tips banner (backup nudge, savings progress, goal update — all computed from
  live data), budget pulse banner, weekly summary, live insights,
  top-categories donut (animated), recent transactions, AdMob banner slot
  (only when the admin panel enables ads)
- **Transactions** — add/edit/delete expenses & income, category picker,
  date picker, notes; list with search + type/category filters, grouped by
  day with day totals
- **Categories** — 10 defaults (খাবার, যাতায়াত, বিল, বাজার, শপিং, বিনোদন,
  স্বাস্থ্য, শিক্ষা, ব্যক্তিগত, বেতন) + unlimited custom (emoji + color)
- **Budgets** — overall monthly cap + per-category caps, 85% warning zone,
  rollover of unused amount into next month
- **Goals (শুয়োরের ব্যাংক)** — savings goals with animated progress rings,
  contributions & withdrawals, history, deadline days-left
- **Analytics** — donut by category, weekly bars, 6-month income-vs-expense
  trend, this-month/last-month/this-year scopes, full insights stack
- **Insights engine** — rule-based cards: top spending area, month-over-month
  change, savings rate, daily average, month-end projection, biggest
  transaction, no-spend days, budget warnings
- **Real notifications** — the 2 AUTO reminders (daily “log today's
  spending” + weekly Friday summary with the real last-7-day spend) are ON by
  default and ask the system permission exactly once after setup; exact-alarm
  scheduling with automatic inexact fallback, survive reboots, rescheduled on
  every app open. Budget-threshold alerts fire once per crossing.
  System-level via `flutter_local_notifications`
- **Data export** — CSV (Excel-friendly, UTF-8 BOM, Bengali notes intact),
  share to anywhere
- **Encrypted backup/restore** — `moneybag-backup-v1` format:
  PBKDF2-HMAC-SHA256 (120k iterations) → AES-256-GCM, passphrase-protected
  `.mbbak` file, share/save/restore with Replace or Merge modes
- **Google Drive backup** — direct-to-Drive upload of the encrypted envelope
  into the hidden `appDataFolder` via Google Sign-In (`drive.appdata` scope;
  one-time OAuth setup, see below) + an always-available “share to Drive”
  fallback
- **Google account** — Profile → Account shows the signed-in Google account
  (name, email, photo) with sign out; guest mode always available
- **Admin panel connection** — Profile → Admin/Server: paste your Admin API
  URL, tap Test, done. Notices/ads/updates flow in on next app open
  (offline-safe with cached config)
- **Settings** — language, dark/light theme, Bengali numerals, monthly
  income, notification preferences, sample data loader, full reset
- **Polish** — true-black AMOLED dark theme, staggered card entrances,
  press-scale feedback, fade page transitions, animated charts

Everything is computed by one **centralized calculation engine**
(`lib/core/calc.dart`) — a single source of truth for every taka of math
(all amounts are integers in poisha, so no floating-point drift, ever).

---

## Project structure

```
lib/
├── main.dart                # entry point
├── app.dart                 # MaterialApp, themes, splash, routing
├── core/
│   ├── palette.dart         # design tokens (colors)
│   ├── app_theme.dart       # Material 3 dark + light themes
│   ├── l10n.dart            # বাংলা/English string tables
│   ├── format.dart          # ৳ money + date formatting (lakh grouping)
│   ├── calc.dart            # THE calculation engine (pure, tested)
│   ├── insights.dart        # rule-based insights engine
│   └── utils.dart           # uuid v4
├── data/
│   ├── tables.dart          # Drift tables (5)
│   ├── database.dart        # MbDatabase + migration + seed
│   └── defaults.dart        # 10 default categories
├── state/app_state.dart     # root ChangeNotifier (settings + data)
├── services/
│   ├── auth_service.dart    # Google Sign-In (login)
│   ├── drive_service.dart   # Google Drive v3 REST backup
│   ├── remote_config_service.dart  # Admin API client (notices/ads/update)
│   ├── notification_service.dart   # real local notifications
│   ├── backup_service.dart  # AES-256-GCM encrypted backup/restore
│   └── csv_service.dart     # CSV export + share
├── widgets/
│   ├── app_logo.dart        # vector MoneyBag logo (custom painter)
│   ├── greeting_banner.dart # fixed branded greeting card w/ logo
│   ├── ad_banner.dart       # AdMob banner (admin-gated)
│   ├── announcement_card.dart # remote notice from the admin panel
│   ├── google_logo.dart     # Google "G" mark (custom painter)
│   ├── avatar.dart          # profile photo (camera/gallery)
│   ├── banner.dart          # auto-rotating tips carousel
│   ├── animations.dart      # motion toolkit (fade/slide/count-up/press)
│   ├── common.dart          # cards, tiles, empty states, progress bars
│   ├── charts.dart          # donut / bars / ring (custom painters)
│   └── illustrations.dart   # onboarding art (custom painted)
└── screens/                 # 14 screens (splash → onboarding → login → shell)
```

---

## Build & run

### Prerequisites
- Flutter SDK ≥ 3.24 (Dart ≥ 3.5) — <https://docs.flutter.dev/get-started/install>
- Android: Android Studio or command-line tools (SDK 34)
- iOS: Xcode 15+ on macOS

### Quick start
```bash
cd moneybag_flutter
flutter pub get

# generate drift code (already committed, regenerate after schema edits):
dart run build_runner build --delete-conflicting-outputs

# run on device/emulator
flutter run

# lint
flutter analyze
```

### Release builds
```bash
# Android APK (debug-signed out of the box — installable directly)
flutter build apk --release
# → build/app/outputs/flutter-apk/app-release.apk

# Split per-ABI (smaller downloads)
flutter build apk --split-per-abi

# Android App Bundle (Play Store)
flutter build appbundle --release

# iOS (on macOS)
flutter build ipa
```

### Play Store signing (production)
Create your own keystore and wire it in
`android/app/build.gradle` → `signingConfigs.release`, then set
`signingConfig = signingConfigs.release` in the `release` buildType.
Keep the keystore + passwords safe; they can never be recovered.

```gradle
signingConfigs {
    release {
        storeFile file("../upload-keystore.jks")
        storePassword System.getenv("KEYSTORE_PASSWORD")
        keyAlias "upload"
        keyPassword System.getenv("KEY_PASSWORD")
    }
}
```

---

## Admin panel & ads — how they work

The companion **Admin API** is a Cloudflare Worker + D1 database at
`../moneybag-cloudflare/worker/`, controlled from the React dashboard at
`../moneybag-cloudflare/admin/` (Cloudflare Pages). Full guide (deploy,
connect, ads) in `../README_FIRST.md`.

**Connect (one rebuild needed):**
1. Deploy the Worker (`npx wrangler deploy`) and the admin dashboard
   (Cloudflare Pages).
2. In the app: `lib/core/config.dart` → `adminApiBaseUrl` → paste the
   Worker URL, rebuild. (Everything else is remote-controlled.)
3. Every app open fetches `/api/v1/app` (cached, offline-safe, ETag/304).

**Push a notice to every user:**
```bash
curl -X POST https://moneybag-api.your-name.workers.dev/api/v1/admin/announcements \
  -H "x-api-key: YOUR_ADMIN_KEY" -H "Content-Type: application/json" \
  -d '{"title":"শুভ বৈশাখ!","body":"নতুন অফার এসেছে","kind":"promo"}'
```

**Ads (future-ready, off by default):**
- The AdMob SDK (`google_mobile_ads`) ships inside the app; the dashboard has
  a banner slot that stays invisible until ads are enabled.
- When ready: create an AdMob account → App ID → replace the test
  `com.google.android.gms.ads.APPLICATION_ID` meta-data in
  `android/app/src/main/AndroidManifest.xml` → rebuild once → put your banner
  unit id in the Admin API → `{"enabled": true, "testMode": false}`.
- `testMode: true` serves Google's official test ads (always safe to try —
  never click your own live ads).

## Google Drive backup — one-time setup

Drive backup is fully implemented (Google Sign-In + Drive v3 REST, hidden
`appDataFolder`, ciphertext only) but OAuth needs **your own** Google Cloud
credentials (Google requires every app to have its own client ID):

1. Open <https://console.cloud.google.com/apis/credentials>
2. Create an **OAuth client ID → Web application**
3. In the OAuth consent screen, add your Android app's package name
   `bd.moneybag.moneybag` and its SHA-1 fingerprint:
   ```bash
   keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey
   ```
4. Copy the Web client ID (ends in `.apps.googleusercontent.com`) into
   `lib/core/config.dart` → `googleWebClientId`
5. `flutter build apk --release` again

The same Web client ID powers **Google login** — one setup unlocks both.

Until then the Drive tab and the login screen show these steps in-app, login
can be skipped (everything works signed-out), and Drive backup offers
**Share backup → pick Drive**, which works immediately with zero setup.

---

## Data & privacy

- **100% local.** SQLite file at `<app documents>/moneybag.sqlite`.
  Financial data has no network calls. The only optional network features —
  Google Sign-In/Drive backup (your encrypted file only) and the Admin API
  (notices/ads config only, never financial records) — are opt-in.
- The AdMob SDK stays dormant (never initialized) until the admin panel
  turns ads on.
- **Backups are encrypted before they ever leave the app** — AES-256-GCM
  authenticated encryption, key derived with PBKDF2 (120,000 iterations).
  Losing the passphrase = losing the backup (by design).
- **Reset** wipes everything instantly — no server copy exists anywhere.

## Verification

- `flutter analyze` — **0 issues**
- `flutter build apk --release` — builds cleanly
- The test suite (31 tests) shipped through v2.0.3 was retired in
  v2.0.4 together with the dev-only sample-data loader and test
  notification tile — the production app now carries zero test-only code.

## Changelog

### v2.1.2 — The cold-start & widget data fix

- **App lock: cold-start race fixed** — v2.1.1 read the lock flag in
  `initState`, but the flag loads asynchronously from SharedPreferences
  during boot, so on every fresh app open it was still `false` at that
  instant. Killing the app and reopening it therefore skipped the lock
  entirely. The gate now listens for boot completion (`state.ready`) and
  arms the lock exactly once, when the persisted flag has actually
  arrived from disk. Backgrounding/re-suming still re-arms the lock
  as before.
- **Home screen widget: blank-widget data bug fixed** — the widget
  provider was reading a SharedPreferences file that the home_widget
  plugin never writes to (`home_widget_preferences` vs the plugin's
  actual `HomeWidgetPreferences`), so the widget stayed permanently
  blank. The provider now extends the plugin's own
  `HomeWidgetProvider` base class, which hands it the exact prefs
  instance the Dart side writes into — the file name can never drift
  again. The layout also ships Bangla-first placeholders, and the
  widget snapshot is re-pushed on every app open.
- **"What's New" guide** re-shown for this version — announces both
  fixes and re-caps where all 8 v2.1 features live.
- `flutter analyze`: 0 issues. Kotlin verified compiling
  (`:app:compileReleaseKotlin`).
- Upgrade-safe `versionCode`: 2.1.1 (2011) → **2.1.2 (2012)** — installs
  directly as an update over any earlier version.
- Version bumped to `2.1.2+12` (+ `MbConfig.appVersion`).

### v2.1.1 — The fix update (guide + guaranteed unlock + widget)

- **"What's New" guide dialog** — existing users who upgrade now get a
  one-time, bilingual guide right after launch that walks through all 8
  v2.1 features and exactly where each one lives (v2.1.0 shipped the
  features but upgraders had no way to discover them; fresh installs see
  onboarding instead and are never double-prompted).
- **Fingerprint lock: guaranteed PIN fallback** — on many OEM devices
  (Xiaomi/Samsung/Oppo…) the system biometric prompt never offers the
  device-PIN option, leaving fingerprint as the only way in. The lock now
  also supports a **4-digit backup PIN**: offered when you enable the
  lock, manageable in Settings → General → Backup PIN (set / change /
  remove), stored as salted SHA-256. The unlock screen auto-prompts the
  fingerprint and always keeps a "Unlock with PIN" path — no device can
  lock you out anymore.
- **Home screen widget fixed** — the widget receiver was not exported, so
  launcher update broadcasts never reached it on many devices. It is now
  `exported="true"` per the home_widget docs: the widget reliably appears
  in the picker and stays in sync.
- **Slimmer APK** — arm64-only native libs strip the unused x86/armeabi
  ML Kit OCR pipelines: 34.6 MB → **21.2 MB**.
- Upgrade-safe `versionCode` scheme: 2.1.0 (2010) → **2.1.1 (2011)** —
  installs directly as an update over v2.1.0/v2.0.x.
- Version bumped to `2.1.1+11` (+ new `MbConfig.appVersion`).

### v2.1.0 — The smart update

- **Receipt scan (OCR)** — tap "Scan receipt" while adding an expense:
  point the camera at a paper receipt (or pick it from the gallery) and
  on-device ML Kit reads the amounts — completely offline, nothing leaves
  the phone. The biggest numbers it finds appear as one-tap chips.
- **Smart budget suggestions** — when setting a budget, MoneyBag shows the
  real average of the last 3 months for that category with a "Use this"
  button. No more guessing.
- **Smarter insights** — two new automatic insight cards: *Budget pace*
  ("at this rate the month would end at ৳X — over your ৳Y budget") and
  *Weekend pattern* (Fri–Sat vs weekday daily spend).
- **Fingerprint lock** — Settings → General → Fingerprint lock. Uses
  fingerprint/face when enrolled, device PIN/pattern as fallback. Enabling
  it runs one real unlock test first, so a broken lock can never be saved.
- **Home screen widget** — add "মানিব্যাগ" from your launcher's widget
  picker: today's spend + this month's total, always in sync, tap to open.
- **Material You** — on Android 12+ the app now follows the wallpaper's
  color palette (dynamic color); older devices keep the MoneyBag navy.
- **Savings goal ETA** — each goal card shows "At this pace · N months
  left → month name" based on the goal's own deposit rate.
- **Duplicate warning** — saving an expense that matches an entry from the
  same day (same amount + category) asks "Save it again?" first. "Save
  anyway" always lets intentional double purchases through.
- New dependencies: `google_mlkit_text_recognition`, `local_auth`,
  `home_widget`, `dynamic_color`. MainActivity switched to
  `FlutterFragmentActivity` (required by the biometric prompt).
- Version bumped to `2.1.0+10`.

### v2.0.4 — Production polish: cleaner app + richer motion

- **Removed everything test-only** — the `test/` suite (31 tests), the
  "Load sample data" tile in Settings, the "Test notification" tile in
  the notification center, and the dev-only `testConnection()` /
  `MbDatabase.forTesting` helpers. What ships is exactly what users use.
- **Every screen now speaks the same motion language** — staggered
  fade/slide entrances on Transactions, Budget, Savings, Analytics,
  Categories, Notification center and Profile; pop-in scale for
  empty-state emojis, the savings piggy and the profile avatar; the
  center + button springs in on launch.
- **Unified page transitions** — every navigation now uses the app's
  soft fade-rise route (previously 11 spots still used the default
  Material slide).
- Version bumped to `2.0.4+9`.
- **Build fix (v2.0.4 hotfix)** — restored the missing
  `import '../core/l10n.dart';` in `notification_service.dart` (caught when
  compiling the release APK; the notification texts need `L.stringsFor`).
  Release APK verified: `bd.moneybag.moneybag` 2.0.4+9, minSdk 21,
  targetSdk 34, valid signature.

### v1.2.0 — Login, splash, branded banner, admin panel & ads-ready

- **Login (Google-only)** — a beautiful login screen appears once after
  onboarding with a real "Sign in with Google" button (4-color G mark,
  custom-painted); signing in syncs name + photo into the profile and
  pre-fills profile setup. "Continue without signing in" keeps the app fully
  local. Existing installs see it once; Profile → Account manages the
  sign-in/out afterwards.
- **Branded splash screen** — app open now shows the MoneyBag logo first
  (native Android 12+ splash + pre-12 launch screen + iOS launch storyboard
  + an animated in-app intro with breathing glow, name & tagline fade-up and
  a boot progress bar) instead of a white flash jumping straight to home.
- **Fixed greeting banner** — the "শুভ সকাল" card is now a proper branded
  banner: deep-green gradient, white MoneyBag logo watermark, soft glow
  circles, slow shimmer sweep, profile photo on top.
- **Admin API + in-app connection** — Cloudflare Worker (`moneybag-cloudflare/worker`,
  Hono.js + D1) + `MbRemoteConfigService` in the app; the Worker URL is set
  once in `lib/core/config.dart`. Admin can push announcements (dashboard
  notice card, dismissible, now with time windows), toggle ads, set
  force-update/min-version.
- **Ads-ready (AdMob)** — `google_mobile_ads` SDK integrated with a
  dashboard banner slot that is invisible until the admin enables ads; unit
  ids + test mode come from the Admin API at runtime (Google test ids as
  safe defaults).
- **Notifications fully auto** — the daily reminder and weekly summary are
  ON by default; the system permission is requested exactly once (right
  after first setup / first open), scheduling prefers exact alarms and
  silently falls back to inexact (never lost), everything re-applied on
  every app open and after reboot.
- 31 tests (was 22), analyze 0 issues.

### v1.1.0 — Black theme, profile photo, Drive backup, real notifications

- **Dark theme is true black now** (AMOLED-friendly `#000000` background,
  neutral `#121212` surfaces) — green stays as the accent color, the whole
  screen no longer looks light-green.
- **Profile photo** — tap the avatar on the dashboard header or profile
  screen to pick from camera/gallery, or remove it. Stored privately in the
  app documents dir; also offered during profile setup.
- **Google Drive backup** — new third tab on the Backup screen: encrypted
  backups upload to your Drive's hidden `appDataFolder` (list / restore /
  delete, sign in/out). Real Google Sign-In + Drive v3 REST; one-time OAuth
  setup documented in-app and in this README. “Share to Drive” fallback
  always available.
- **Real system notifications** — budget alerts fire the moment a budget
  crosses 85%/100% (once per crossing, per month); daily reminder at a
  user-chosen time; weekly summary carries the real last-7-day spend.
  Permission flow + test button in Settings → Notifications.
- **Dashboard banner** — auto-rotating slide deck at the top of the home
  screen (backup nudge with real backup age, live savings rate, goal
  progress, log-today nudge) with animated dot indicators.
- **Animations everywhere** — staggered card entrances, count-up money
  values, sweeping donut, animated progress bars & goal rings, springy nav
  icons, press-scale FAB/cards, fade page transitions, animated splash.
- Backup screen now tracks “last backup” and the tips banner uses it.

### v1.0.1 — Bugfix release

- **Fixed: Profile tab blank screen.** The bottom nav has 5 slots
  (Home | Transactions | + | Budget | Profile) but the pages list held only
  4 screens — tapping Profile indexed out of range, threw a RangeError and
  rendered as a blank screen in release builds. The pages list now mirrors
  the 5-slot layout 1:1 (center slot is the FAB placeholder).
- **Fixed: Budget tab showed the wrong screen** (the profile page without an
  AppBar, jammed behind the status bar — "content too high at top").
  Budget now opens the real Budget screen; Profile got a `SafeArea` +
  proper top padding.
- **Real savings numbers.** The Savings hero and the dashboard shortcut now
  show live, computed data: this month's net savings (income − expense),
  total saved and amount in goals — all from actual transactions, no
  placeholders.
- **Localized insight amounts.** Insight cards now format money exactly like
  the rest of the app (Bengali numerals, ৳, lakh grouping) instead of plain
  ASCII `৳2500`.
- **FAB docked properly** — center button no longer floats detached above
  the nav bar.
- **New regression test suite** (`test/`) covering the navigation fix and
  the calculation/insights engines.

### v1.0.0 — Initial release

## Roadmap (post-v1)

- Bengali (BCS) calendar month views
- Interstitial ads after key actions (SDK already integrated)
- Recurring transactions & reminders
