# Changelog — MoneyBag Production Package

## v2.2.5 (2026-09-13) — Category budgets actually work · free-text category box · notification & backup repair

User feedback round (real device): "catagory budget e kono catagory nai",
"note ar catagory jekono akta dile save logic koreso ja ami chai ni",
"notification full logic again dekho", "backup o dekho".

### 🔴 CRITICAL — Category Budget was impossible to use

**FIX (budget_screen.dart):** an operator-precedence bug —
`overall: overall || existing?.categoryId == null` — evaluated the right side
TRUE for every NEW budget (existing is null), so "+ বাজেট যোগ করুন" (Category
Budget) opened the sheet in OVERALL mode: category chips never rendered, and
saving wrote an overall budget instead of a category one. This single bug
explains both "category budget has no categories" AND the earlier "two
budgets look the same" report. Fixed in all three places (_openEditor, sheet
_save, sheet build): the null-categoryId clause now only applies when an
EXISTING overall row is edited. The sheet's "manage categories" escape hatch
now actually opens the categories screen (was a dead button).

### ✨ Tx editor — the exact save flow the user asked for

**CHANGE (transaction_edit_screen.dart + app_state.dart):** the editor now has
a "কিসে খরচ হলো?" box ABOVE the amount (user's spec: box upore, taka niche):

* box filled → the typed text IS the category — saved via the new
  `findOrCreateCategoryByName` (matches an existing category case-insensitively
  or creates a custom one), chips not needed;
* box empty → a category chip must be picked;
* neither → save blocked ("ক্যাটাগরি বাছাই করুন বা উপরে কিসে খরচ হলো লিখুন");
* the NOTE is back to being purely optional extra detail.

Recent-entry quick chips (max 3, last 7 days) now fill the category box and
also draw from custom category names, not just notes. Editing a tx whose
category was deleted/deactivated round-trips through the box instead of
silently dropping it. Income gets the same flow ("কিসে আয় হলো?").

### 🔔 Notifications — full logic re-audit

**FIX (notification_service.dart):** the WEEKLY summary was scheduled with
`DateTimeComponents.time` — which means repeat DAILY. Users got the "weekly"
summary every single day on top of the daily reminder. Now daily uses `time`
and weekly uses `dayOfWeekAndTime` (true weekly repeat, Fridays). Also: the
missed-reminder catch-up body was the title string with an empty time
argument — it now carries the live smart numbers like the scheduled reminder.

**AUDIT PASSED:** init/timezone (flutter_timezone → Asia/Dhaka fallback),
permission flow (ask-once + non-interactive check), alarmClock → exact →
inexact fallback chain, schedule re-apply on every resume (OEM self-heal),
budget alerts (85%/100%, once per crossing per month), notification-center
toggles all call applySchedule, diagnostics persisted as plain strings.

### 💾 Backup — audited + hardened

**HARDENING (backup_service.dart + database.dart):** restore read booleans
with `?? false` — a backup missing the `isActive`/`active` keys (older or
hand-edited file) restored every category as INACTIVE and every budget as
INVISIBLE: blank pickers everywhere. Missing keys now honour the column
default (true). `ensureDefaultCategories` additionally REACTIVATES inactive
default rows (insertOrIgnore alone skips existing rows, leaving the pickers
blank forever). Core encrypt/decrypt/restore logic verified correct
(PBKDF2-HMAC-SHA256 120k iterations → AES-256-GCM, magic/version validation,
auth-error → "wrong passphrase", merge + replace modes, post-restore state
re-init).

### Misc

- `MbConfig.appVersion` was stale at '2.1.2' since the 2.2.0 series — the
  What's-New guide gating never re-triggered for upgrades. Now tracks the
  real version (2.2.5), so upgraders see the guide once.
- New l10n keys × bn/en: txWhatForExpenseLabel, txWhatForIncomeLabel,
  txWhatForHint, txWhatForHelper, txCategoryOptional; removed txEitherHint.

## v2.2.4 (2026-09-13) — Language audit: project is now 100% Bangla/English

User request: "project er jekhane jekhane chaina vasha ase shegulo poriborton
kore bangla/english kore" — full Unicode audit of every file (App + Admin +
API + docs), conversion of all foreign/East-Asian typography.

### 🔵 Flutter App (2.2.3+2203 → 2.2.4+2204)

**FIX — foreign character in user-visible UI:** the What's-New guide showed the
receipt-scan entry as "＋ → রিসিট স্ক্যান" using a CJK FULLWIDTH PLUS (U+FF0B)
— a full-width Japanese/Chinese-style plus that renders with odd spacing on
Bengali/Latin text. Replaced with the normal "+" glyph. This was the only
non-Bangla/non-English character anywhere in the app's UI.

**Code hygiene:** 36 circled digits (①②③…⑨, East-Asian "enclosed
alphanumeric" forms) converted — Bengali digits (১২৩…) in Bengali docs and
mixed-language code comments, ASCII digits in English contexts; `§` section
signs → ":"; `‖` → "||"; `═` comment dividers → "="; corrupted doc comment
in insights.dart clarified. Verified: zero Han/Kana/Hangul/Devanagari/Arabic/
Cyrillic/fullwidth characters remain anywhere (automated Unicode audit over
all 156 text files).

## v2.2.3 (2026-09-13) — Widget actually renders · tappable today card · smart notifications · category fixes

User feedback round (real device): "widget akhono blank", "budget er category
r kono option nai", "ajker hishab jog korun button er upore chap dile kaj kore
na", "reminder kaj kore na", tx editor should accept category OR a
"what-was-it-for" box with recent suggestions.

### 🔵 Flutter App (2.2.2+2202 → 2.2.3+2203)

**FIX — home screen widget was STILL blank (root cause found):**
- The widget layout used `<Space>` views as spacers. `android.widget.Space`
  is NOT on the RemoteViews whitelist (verified: no `@RemoteView` annotation,
  not in the documented allowed-view list) — so every time the launcher
  inflated the widget layout it threw an InflateException and rendered the
  white placeholder. That is why the widget was blank since v2.1.0 while
  every re-render push (resume, boot receiver, onRestored) appeared to work:
  each push shipped the same broken layout. All `Space` views are now
  replaced with empty `TextView` spacers + layout margins (whitelist-safe);
  `previewLayout` added for Android 12+ widget pickers.

**FIX — "আজকের হিসাব যোগ করুন" pill only responded to taps on its lower half:**
- The dashboard faked the hero overlap with `Transform.translate(-46px)` —
  transforms move PAINT, but ListView routes taps by each sliver's LAYOUT
  extent, so the card's top 46px (the whole add pill) mapped to the hero and
  taps went dead. The hero now paints its backdrop 74px below its layout box
  (negative `Positioned` + `Clip.none`) and the card sits in normal flow 28px
  below the hero: pixel-identical visuals, every pixel tappable. The whole
  today card is now tappable (tapping anywhere opens the add sheet), not
  just the pill.

**FIX — budget sheet had no category options:**
- If the categories table ever ends up without a single ACTIVE expense row
  (restored backup, manual deletes), every category picker in the app went
  silently blank. A self-heal now re-seeds the default categories at boot
  (`insertOrIgnore` — user edits preserved). The budget sheet chips became a
  Wrap (was a fixed 150px ListView), a category is pre-selected smartly
  (most-used unbudgeted expense category), saving a category budget without
  picking one is now blocked (it used to silently save as a duplicate-ish
  overall budget), and an empty state with an escape hatch exists as the
  last-resort fallback.

**FIX + SMART — notifications & reminders ("reminder kaj kore na"):**
- **Smart notifications (new, ON by default, one switch to turn off):** the
  daily reminder now carries real numbers — yesterday's spend, month-to-date,
  budget head-room ("গতকাল ৳X · এ মাসে ৳Y · বাজেটে বাকি ৳Z") — refreshed on
  every app resume. Off-switch reverts to the plain static reminder.
- **Re-arm on every resume:** the schedule is re-applied each time the app
  comes to the foreground — OEM-dropped alarms self-heal, smart numbers stay
  fresh.
- **Test button:** "টেস্ট নোটিফিকেশন পাঠান" fires the live reminder instantly
  so the user can verify channels/permission in one tap.
- **Device health card:** detects (a) notification permission denied →
  one-tap deep-link into the app's system notification settings, and
  (b) battery optimization still applied → one-tap system "allow" dialog —
  the two classic OEM reasons reminders die on Walton/Symphony/MIUI-class
  phones. New `moneybag/device` method channel in MainActivity
  (+ REQUEST_IGNORE_BATTERY_OPTIMIZATIONS permission).

**FIX + SMART — transaction editor (category OR note, recency rules):**
- Saving now requires EITHER a category OR the note ("কিসের জন্য?" box) —
  exactly as requested: quick entries can skip categories if the note says
  what the money went for. Helper text under the field explains the rule;
  the hint now prompts "কিসের জন্য? যেমন: রিকশা ভাড়া, বাজার".
- **Recent notes follow the requested recency rules:** suggestions are the
  3 most recently used notes of the same kind from the last 7 days (older
  ones age out automatically — the "5-10 din por delete" behaviour), no
  category filter, newest first.

## v2.2.2 (2026-09-13) — Bengali keyboard fix + Smart quick-fill

User question: "Smart korar kono jayga ase naki app akdom perfect?" — answer:
not perfect. One real input bug found + four smart upgrades, all in the app.

### 🔵 Flutter App (2.2.1+2201 → 2.2.2+2202)

**FIX — Bengali digits silently eaten by every money field:**
- All four money inputs (transaction amount, budget limit, goal target, goal
  contribution) used an ASCII-only `FilteringTextInputFormatter` — a user
  with a Bangla keyboard (Gboard Bengali, Ridmik, Avro…) typed ৫০০ and
  nothing appeared at all, even though `MbFormat.parseAmount` fully supports
  Bengali digits on the parse side. The input regex now allows ০-৯ (and
  Bengali+ASCII mixing); parsing normalises before save.

**SMART — quick-fill chips in the transaction editor:**
- **Frequent amounts:** when adding a new entry with the amount still empty,
  the editor suggests this user's 3 most-recorded amounts from the last 90
  days (same kind; narrowed to the selected category). One tap fills the
  field — চা ৳২০ / বাস ৳৩০ stops needing the keypad. Suggestions require ≥2
  occurrences so one-offs never clutter the form.
- **Recent notes:** up to 3 notes previously used with the same kind/category
  appear under the note field while it's empty. One tap reuses them
  ("রিকশা", "বিদ্যুৎ বিল"…).

**SMART — daily "safe to spend" on the dashboard today card:**
- With an overall monthly budget set, the today card now shows
  "আজ নিরাপদে খরচ করা যায় ৳X" — (effective limit − month spend) / days left,
  rollover-aware, recalculated live. Hidden when no budget or already over
  (the red banner handles that case).

**SMART — new category-spike insight:**
- The insights engine now detects a single category running ≥50 % above its
  own trailing 3-month average ("খাবার-এ গত ৩ মাসের গড়ের চেয়ে ৭০ % বেশি")
  — catches quiet budget leaks the overall month-over-month rule misses.
  Baseline floor (৳50 avg/month) keeps tiny or new categories from
  producing noise.

## v2.2.1 (2026-09-13) — Widget recovery + Budget clarity

Real-device feedback round (Android, MIUI-class launcher). Two reported issues
fixed + widget upgraded.

### 🔵 Flutter App (2.2.0+2200 → 2.2.1+2201)

**"Budget 2tai akirokom kno?" (two identical budget cards):**
- The Budget screen's two empty states — overall monthly budget vs
  per-category budgets — shared ONE generic hint and had no icons, so both
  cards looked like a duplicated/broken card. Now: distinct icons
  (donut vs category) and specific hints explaining what each one does
  ("সব ক্যাটাগরির খরচ মিলিয়ে একটাই মাসিক সীমা…" vs "প্রতিটা ক্যাটাগরির জন্য
  আলাদা সীমা…", EN too).

**"Widget blank" (white launcher placeholder, never rendered):**
- Root cause: the widget only ever repainted when the Flutter side pushed
  data; OEM launchers (MIUI/HyperOS, ColorOS…) drop a sideloaded app's
  widget bind while the process is dead, and after a reboot nothing
  repainted it at all.
- **New `MbBootReceiver`** — BOOT_COMPLETED / MY_PACKAGE_REPLACED repaints
  the widget natively from the last persisted snapshot (no Flutter engine,
  ~1 ms). RECEIVE_BOOT_COMPLETED permission was already present.
- **`onRestored` override** — app updates hand the provider NEW widget ids;
  repaint immediately instead of waiting for the next app open.
- **Widget push on app resume** — also fixes "today's spend" going stale
  overnight while the app sits in the background (day rollover).
- Render logic extracted to a shared `MbWidgetProvider.renderAll()` used by
  all three paths (Dart push / restore / boot).

**Widget got smarter (user request "smart kora jay?"):**
- The widget now shows the **overall monthly budget progress** (spent /
  effective limit + thin progress bar) in addition to today's + this
  month's spend. Bar turns red at ≥100 %. Row is hidden entirely when no
  overall budget is set. Rollover-aware limit (same math as the budget
  screen). minHeight raised to 2×2 for the extra row.

**Fingerprint lock:** confirmed working on-device (no changes).

## v2.2.0 (2026-09-13) — Security & Reliability Hardening

Full pass over all three components (Worker API + Admin dashboard + Flutter app).
Live API (`moneybag-api.salman61902.workers.dev`, v1.1.0) was probed end-to-end;
every fix below is backward compatible with the deployed app and dashboard.

### 🔴 Cloudflare Worker (API v1.1.0 → v2.0.0)

**Security (verified live before fixing):**
- **Rate limiting added** — live probe fired 40 rapid requests with zero 429s;
  the `x-api-key` could be brute-forced unlimited. Buckets: public 240/min,
  `users/sync` 30/min (unauthenticated write endpoint!), admin 600/min per IP;
  429 + `Retry-After`, env-tunable (`RL_*_PER_MIN`), per-isolate with eviction.
- **Timing-safe admin key check** (SHA-256 digest compare, no early exit) +
  generic `unauthorized` 401 — the old error literally said *"send header
  x-api-key"*, coaching attackers. Optional `ADMIN_API_KEYS` secret for
  zero-downtime key rotation.
- **Strict payload validation** on PUT config / PUT ads / POST announcements /
  POST users-sync. The old "merge-anything" accepted ANY JSON — `latestVersion:
  2.1` (number) or junk fields could break every app client on next sync.
  Wrong types now get a precise 400; unknown fields are stripped.
- **users/sync shape validation** — 4–128 char Google-uid pattern, email sanity;
  was: write-anything into D1, unlimited.
- **LIKE wildcard escaping** in admin user search (`%`/`_`/`\` + `ESCAPE '\'`)
  — searching "100%" used to match the whole table.
- **500 handler no longer leaks internal error strings** (D1/SQL details);
  generic body + request id that matches the log line.
- **Body-size guard (64 KB)** rejected before reading — 200 KB+ was accepted.
- **CORS allowlist support** (`ALLOWED_ORIGINS` var, default `*` = old
  behaviour), tightened methods/headers, exposes rate-limit headers.
- **404 no longer echoes the request path** back into the JSON body.

**Reliability:**
- **FCM OAuth single-flight** — 40 concurrent sendFcm() calls raced
  getAccessToken() and each fetched its own OAuth token (40 sign + 40 token
  requests → wasted subrequests, Google rate limits). One shared promise now.
- **Stale-token cleanup batched** into a single `UPDATE … WHERE fcm_token IN
  (…)` — was N single-row UPDATEs AFTER 40 FCM fetches, could blow the
  free-plan 50-subrequest cap mid-broadcast.
- **Stable cursor paging for global push** (`cursor: {lastLogin, uid}`,
  SQLite row-value compare) — offset paging skipped/duplicated users when
  last_login changed mid-broadcast. Offset mode kept for the old dashboard.
- **ETag + Cache-Control** on public endpoints (304 via If-None-Match,
  max-age=30 + SWR) + 20 s state micro-cache → far fewer D1 reads per app
  launch; admin responses are `no-store`.
- **Deep health check** — `/health?deep=1` pings D1 with a 3.5 s timeout
  (503 when the DB is down); shallow `/health` stays monitor-friendly.
- **Read-side sanitising** of stored config/ads (legacy nulls/numbers →
  correct types) so the edit forms never round-trip broken values.
- **Request id + server timing + structured JSON logs** on every request;
  observability enabled in wrangler.toml.
- **Docs shipped in the worker**: `/docs` (zero-dependency HTML) and
  `/openapi.json` (OpenAPI 3.1) — the API was previously undiscoverable.
- Trailing-slash tolerance (GET `/api/v1/config/` → 308), migrations/
  0002_indexes.sql (announcements + push_log indexes), wrangler v4, hono
  4.9, 37 vitest tests, tsc 0 errors.

### 🟠 Admin Dashboard (React)

- **api.js rewritten**: 15 s AbortController timeout (saves could hang
  forever), non-JSON 200 responses now raise real errors instead of silently
  becoming `{}` (which produced fake "0 delivered" push success and infinite
  loading states), 429 carries `retryAfter`, 401 broadcasts `mb:unauthorized`
  → App auto-logout when the key is rotated server-side.
- **GlobalPushView**: batch response shape validated (malformed → abort with
  count, not silent success), 429/5xx retried on the SAME offset with backoff
  (one hiccup used to abort the whole broadcast), hard cap raised 4,000 →
  200,000 users with honest "stopped" toast, confirm dialog before an
  irreversible mass notification, prefers stable cursor paging.
- **UsersView**: stale-response race fixed (sequence guard — fast typing used
  to show "ab"-results under the "abc" search box), duplicate mount fetch
  removed, pagination UI (limit/offset — users beyond #200 were invisible),
  search shows match count vs total, unmount-safe.
- **useToast**: a previous toast's timer no longer blanks a newer toast
  (error toasts were being swallowed).
- **DashboardView**: in-flight guard (30 s poll no longer stacks requests),
  keeps last-good data with an error banner + Retry instead of blanking.
- **ConfigView**: payloads normalised before PUT (empty message → null,
  booleans coerced) and whitelisted — compatible with the Worker's new strict
  validation; version inputs marked required.
- **AnnouncementsView**: optional startsAt/endsAt scheduling (datetime-local
  → ISO) with client-side validation, busy-guards on toggle/delete
  (double-click sent two PATCHes), created-time display, retry on load error.
- **LoginView**: real URL validation (`new URL`, https-only except
  localhost); login errors distinguish wrong key (401) from unreachable
  server instead of one combined guess.
- **Modal**: Esc-to-close, backdrop click, aria labels; Toast has
  role=status/aria-live.
- **Security headers**: CSP meta + `public/_headers` for Cloudflare Pages
  (nosniff, DENY framing, no-referrer, permissions-policy).
- dist/ rebuilt from the fixed source (the committed bundle was stale).

### 🔵 Flutter App (2.1.2+12 → 2.2.0+2200)

**Build verification (real SDK):**
- **Release APK compiled & verified end-to-end with Flutter 3.24.5 / Dart
  3.5.4 / Gradle 8.7 / AGP 8.3.2 / JDK 21 (Temurin)** —
  `flutter build apk --release --target-platform android-arm64` →
  `app-release.apk` (≈21 MB, arm64-v8a, minSdk 21, targetSdk 34,
  versionCode 2200, versionName 2.2.0).
- **3 compile errors found & fixed** during the real build (the code had
  been written without a Dart SDK available): `Sha256.process()` →
  `Sha256().hash()` chained rounds (app_state.dart); banner-ad closure
  scoping → `late final BannerAd ad` declared before its listener
  (ad_banner.dart); `widget.state.bangla` → `context.read<MbAppState>()`
  (backup_screen.dart). `dart analyze lib` → 0 errors.

**Security:**
- **Backup PIN hardened**: single SHA-256 → 60,000-round chained SHA-256
  ("v2:" prefix). A 4-digit PIN is 10,000 combos — offline brute force was
  instant; now each guess costs 60 k hashes. Existing users verify via the
  legacy path once and are transparently upgraded (new salt). Comparison is
  constant-time.
- **Lock gate fail-closed when a backup PIN exists** (biometrics unavailable/
  error used to open the money data unconditionally); fail-open only when the
  lock is decorative (no PIN set) so nobody is ever permanently locked out.
- **PIN brute-force cooldown**: the pin pad's "5 attempts" limit was
  decorative — `onMaxAttempts` was never wired, guessing continued forever.
  Now 5 wrong PINs → escalating cooldown (30 s → 1 m → 2 m → 5 m → 15 m),
  reset on success.
- **resetAll()** now also clears pinSalt/pinHash/biometricLock in memory —
  prefs were wiped on disk but the old PIN still verified for the rest of
  the session.

**Data-loss / crash fixes:**
- **Auto-restore wipe**: the "device is empty" guard only checked
  transactions — a user with only budgets/goals/contributions who signed into
  Google had them silently replaced by the remote snapshot. Guard now covers
  all four tables.
- **Empty-device remote wipe**: a fresh install with a failed restore could
  auto-upload its EMPTY database over the good rolling Drive backup within
  seconds. Auto-backup now refuses to upload an all-empty snapshot.
- **Drive backup rotation**: the rolling `moneybag-auto-latest.mbbak` was
  PATCHed in place — one truncated upload destroyed the only remote copy.
  The previous good copy is now kept as `moneybag-auto-prev.mbbak`.
- **Startup white-screen**: a corrupt DB/prefs exception in `init()` left the
  splash waiting forever with zero services attached. Now: recovery screen
  with Retry; services only attach on a healthy boot.
- **Backup passphrase minimum length (≥6) enforced in
  `MbBackupService.createBackup`** — the share-fallback path allowed creating
  (and handing out) backups encrypted with an EMPTY passphrase.
- **Cancelling the Google account picker** during auto-restore is no longer
  reported as "restore failed" (silent abort instead).

**AdMob / policy:**
- **Interstitial no longer auto-shows in `onAdLoaded`** (a random moment tied
  to network latency, not a user action — policy risk). It is cached and
  shown at the next eligible save right after the editor pops (natural
  break). Show-failure/dispose callbacks wired.
- **`ads.testMode` is now enforced**: the flag was parsed but never used —
  with testMode ON and real unit IDs configured, the app served LIVE ads to
  test traffic. Test mode ON → always Google's official test IDs.
- **Banner recovery**: after one load failure the disposed ad object was
  stored back into the field, permanently blocking retries (and double-
  disposing). The ad is now stored only on success, disposed exactly once.
- **ad-free hours counter** no longer shows "24 h" with 23 h 59 m left.

**Correctness / UX:**
- **Bengali digit input**: money fields used plain `tryParse`, so typing ৫০০
  (the app's own default rendering!) failed with a silent "amount required".
  `MbFormat.parseAmount` normalises Bengali digits, commas and the ৳ prefix;
  wired into all 7 amount parsers + the OCR receipt regex now matches Bengali
  digits.
- **Weekly summary window** was 8 calendar days (`between` is [from, to));
  now a true 7-day window.
- **`catById` map cached** (rebuilt 15–30× per dashboard frame), invalidated
  on reload.
- **`weeklyBars`** no longer pads "last month" analytics with ~4 trailing
  zero-weeks (loop clamps to month end vs today, whichever first).
- **moneyCompact spacing unified** (৳1.2 কোটি / ৳3.5 লাখ / ৳1.2k).
- **Login no longer blocks up to 10 s** on the Google profile-photo download
  (fire-and-forget like the user sync).
- **Auto-sync status strings localised** ("এইমাত্র / মিনিট আগে / …" in
  Bengali mode).
- **Drive REST calls have timeouts** (30 s / 120 s download) — one stalled
  socket used to leave `_uploading` stuck ON until app restart.
- **Local .mbbak cleanup after auto-upload** — every debounce used to write a
  full snapshot into `<documents>/backups/` and never delete it (unbounded
  storage growth).
- **`RECEIVE_BOOT_COMPLETED` permission added** — the README promised
  reboot-surviving reminders, but alarms were lost at reboot.
- **Release signing**: `keystore.properties` flow added (see
  `android/keystore.properties.example`) — release builds were debug-signed,
  which Play Store rejects; version code bumped 2012 → 2200.

**Docs:** README_FIRST.md refreshed (was still describing v2.0.4), stale
Node-server references removed, CHANGELOG + SECURITY.md added.

### Notes / known limitations (documented, not silently ignored)
- The Drive backup passphrase is still stored base64-obfuscated in
  SharedPreferences (no `flutter_secure_storage` dependency was added to keep
  the dependency tree unchanged) — see SECURITY.md for the recommendation.
- `google-services.json` / Web Client ID / AdMob App ID remain placeholders by
  design — they are the deployer's credentials (README_FIRST.md step 3).
- In-memory rate limiting is per-isolate best effort; for hard guarantees add
  a Cloudflare WAF rate-limiting rule in front (documented in worker README).
