import 'dart:async' show unawaited;
import 'dart:convert' show utf8;
import 'dart:io';
import 'dart:math' as math;

import 'package:cryptography/cryptography.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter/material.dart' show ThemeMode;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/calc.dart';
import '../core/config.dart';
import '../core/format.dart';
import '../core/insights.dart';
import '../core/l10n.dart';
import '../core/utils.dart';
import '../data/database.dart';
import '../data/defaults.dart';
import '../services/auth_service.dart';
import '../services/user_sync_service.dart';
import '../services/widget_sync_service.dart';

/// Root application state: settings + cached DB rows + all mutations.
///
/// Every write goes through here so listeners always see a consistent
/// snapshot; all money math is delegated to [MbCalc].
class MbAppState extends ChangeNotifier {
  MbAppState({MbDatabase? database}) : db = database ?? MbDatabase();

  final MbDatabase db;
  late SharedPreferences prefs;

  // ── settings ────────────────────────────────────────────────────────────
  bool onboarded = false;
  MbLanguage language = MbLanguage.bangla;
  ThemeMode themeMode = ThemeMode.dark;
  bool bengaliDigits = true;
  bool budgetAlerts = true;
  bool weeklySummary = true;
  String userName = '';
  int? monthlyIncomeMinor;

  // ── notifications ─────────────────────────────────────────────
  // Default ON: the two auto push notifications (daily reminder + weekly
  // summary) work out of the box; the permission is requested once after
  // first setup. Users who turn them off explicitly keep their choice.
  bool dailyReminder = true;
  int dailyReminderHour = 20; // 8 PM
  int dailyReminderMinute = 0;

  /// v2.2.3: daily reminder carries live numbers (yesterday/month spend,
  /// budget left). Switchable from the notification center.
  bool smartNotifications = true;

  // ── security (v2.1) ─────────────────────────────
  /// Biometric / device-PIN app lock. Off until the user turns it on in
  /// Settings (the toggle only appears on devices that support it).
  bool biometricLock = false;

  // ── Google account (login) ─────────────────────────────────
  String? googleEmail;
  String? googleName;
  String? googlePhotoUrl;
  String? googleUid; // stable Google id — used for /api/users/sync
  bool loginSkipped = false; // user chose "continue without signing in"
  bool loginSeen = false; // login screen shown at least once

  /// Splash intro finished — drives the intro → app transition.
  bool _introDone = false;
  bool get introDone => _introDone;

  bool get googleLinked => googleEmail != null && googleEmail!.isNotEmpty;

  // ── profile photo ──────────────────────────────────────────────
  String? avatarPath;

  // ── backup bookkeeping ──────────────────────────────────────────
  DateTime? lastBackupAt;

  // ── cached data ─────────────────────────────────────────────────────────
  List<Category> categories = const [];
  List<Transaction> transactions = const [];
  List<Budget> budgets = const [];
  List<Goal> goals = const [];
  List<Contribution> contributions = const [];

  bool _ready = false;
  bool get ready => _ready;

  // ── lifecycle ───────────────────────────────────────────────────────────
  Future<void> init() async {
    prefs = await SharedPreferences.getInstance();
    onboarded = prefs.getBool('onboarded') ?? false;
    final lang = prefs.getString('lang');
    language = lang == 'en'
        ? MbLanguage.english
        : (lang == 'bn' ? MbLanguage.bangla : MbLanguage.bangla);
    final theme = prefs.getString('theme');
    themeMode = theme == 'light'
        ? ThemeMode.light
        : (theme == 'system'
            ? ThemeMode.system
            : ThemeMode.dark);
    bengaliDigits = prefs.getBool('bnDigits') ?? true;
    budgetAlerts = prefs.getBool('budgetAlerts') ?? true;
    weeklySummary = prefs.getBool('weeklySummary') ?? true;
    userName = prefs.getString('userName') ?? '';
    final inc = prefs.getInt('incomeMinor');
    monthlyIncomeMinor = inc == null || inc <= 0 ? null : inc;

    dailyReminder = prefs.getBool('dailyReminder') ?? true;
    dailyReminderHour = prefs.getInt('dailyReminderHour') ?? 20;
    dailyReminderMinute = prefs.getInt('dailyReminderMinute') ?? 0;
    // v2.2.3: smart notifications ON by default — the daily reminder carries
    // real numbers (yesterday/month spend, budget left). One switch in the
    // notification center turns it back into the plain reminder.
    smartNotifications = prefs.getBool('smartNotif') ?? true;
    avatarPath = prefs.getString('avatarPath');
    biometricLock = prefs.getBool('biometricLock') ?? false;

    googleEmail = _nonEmpty(prefs.getString('googleEmail'));
    googleName = _nonEmpty(prefs.getString('googleName'));
    googlePhotoUrl = _nonEmpty(prefs.getString('googlePhotoUrl'));
    googleUid = _nonEmpty(prefs.getString('googleUid'));
    loginSkipped = prefs.getBool('loginSkipped') ?? false;
    loginSeen = prefs.getBool('loginSeen') ?? false;
    pinSalt = _nonEmpty(prefs.getString('pinSalt'));
    pinHash = _nonEmpty(prefs.getString('pinHash'));

    // v2.1.1: fresh installs pre-mark the "What's New" guide as seen — brand
    // new users go through onboarding and should not ALSO get the upgrade
    // guide later. Upgraders (onboarded already) keep it unseen → the shell
    // greets them once with everything that's new in this version.
    if (!onboarded) {
      await prefs.setString('whatsNewSeen', MbConfig.appVersion);
    }

    final lb = prefs.getInt('lastBackupAt');
    lastBackupAt = lb == null ? null : DateTime.fromMillisecondsSinceEpoch(lb);

    await _reload();
    _ready = true;
    notifyListeners();

    // v2.1.2: refresh the home screen widget on every app open. After an
    // app update (or a launcher rebind) the widget can fall back to its
    // placeholder layout — one push right after boot repaints it with the
    // real numbers, even if nothing changed since last session.
    unawaited(MbWidgetSyncService.push(this));
  }

  Future<void> _reload() async {
    final results = await Future.wait([
      db.allCategories(),
      db.allTransactions(),
      db.activeBudgets(),
      db.allGoals(),
      db.allContributions(),
    ]);
    categories = results[0] as List<Category>;
    transactions = results[1] as List<Transaction>;
    budgets = results[2] as List<Budget>;
    goals = results[3] as List<Goal>;
    contributions = results[4] as List<Contribution>;
    _catByIdCache = null; // categories may have changed — rebuild lazily

    // v2.2.3 self-heal: with no ACTIVE expense category every category
    // picker in the app (budget sheet, tx editor) renders empty — re-seed
    // the defaults instead of leaving the user with nothing to pick.
    if (!categories.any((c) => c.kind == 'expense' && c.isActive)) {
      await db.ensureDefaultCategories();
      categories = await db.allCategories();
      _catByIdCache = null;
    }
  }

  Future<void> _refresh() async {
    await _reload();
    // v2.1: keep the home screen widget in sync after every data change.
    unawaited(MbWidgetSyncService.push(this));
    notifyListeners();
  }

  // ── derived helpers ─────────────────────────────────────────────────────
  bool get bangla => language == MbLanguage.bangla;
  MbStrings get strings => L.stringsFor(language);

  Map<String, Category>? _catByIdCache;

  /// v2.2.0: cached — this getter used to rebuild the whole map on EVERY
  /// call (dashboard rebuilds triggered it 15–30× per frame). Invalidated
  /// by [_reload] whenever the category list changes.
  Map<String, Category> get catById =>
      _catByIdCache ??= {
        for (final c in categories) c.id: c,
      };

  String categoryName(String? id) {
    if (id == null) return strings.none;
    final c = catById[id];
    if (c != null) return c.name;
    return defaultCategoryName(id, bangla: bangla);
  }

  List<Category> activeCategoriesOfKind(String kind) => categories
      .where((c) => c.isActive && c.kind == kind)
      .toList(growable: false);

  List<MbTx> get txView => [
        for (final t in transactions)
          MbTx(
            id: t.id,
            kind: t.kind,
            amountMinor: t.amountMinor,
            categoryId: t.categoryId,
            note: t.note,
            date: t.date,
          ),
      ];

  List<MbTx> txOfMonth(int year, int month) =>
      MbCalc.forMonth(txView, year, month);

  // Money formatting with current settings.
  String money(int minor, {bool sign = false}) =>
      MbFormat.money(minor, bengaliDigits: bengaliDigits, sign: sign);

  String moneyCompact(int minor) =>
      MbFormat.moneyCompact(minor, bengaliDigits: bengaliDigits);

  String pct(num v) => MbFormat.percent(v, bengaliDigits: bengaliDigits);

  // ── onboarding / profile setup ──────────────────────────────────────────
  Future<void> completeSetup({
    required String name,
    int? incomeMinor,
    required MbLanguage lang,
    required ThemeMode mode,
  }) async {
    userName = name.trim();
    monthlyIncomeMinor = incomeMinor;
    language = lang;
    themeMode = mode;
    onboarded = true;
    await _saveSettings();
    notifyListeners();
  }

  // ── settings setters ────────────────────────────────────────────────────
  Future<void> setLanguage(MbLanguage lang) async {
    language = lang;
    await prefs.setString('lang', lang == MbLanguage.english ? 'en' : 'bn');
    // Widget labels are localized on the Dart side — push them again.
    unawaited(MbWidgetSyncService.push(this));
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    themeMode = mode;
    final v = mode == ThemeMode.light
        ? 'light'
        : (mode == ThemeMode.system ? 'system' : 'dark');
    await prefs.setString('theme', v);
    notifyListeners();
  }

  Future<void> setBengaliDigits(bool v) async {
    bengaliDigits = v;
    await prefs.setBool('bnDigits', v);
    notifyListeners();
  }

  Future<void> setBudgetAlerts(bool v) async {
    budgetAlerts = v;
    await prefs.setBool('budgetAlerts', v);
    notifyListeners();
  }

  Future<void> setWeeklySummary(bool v) async {
    weeklySummary = v;
    await prefs.setBool('weeklySummary', v);
    notifyListeners();
  }

  // ── notifications settings ─────────────────────────────
  Future<void> setDailyReminder(bool v, {int? hour, int? minute}) async {
    dailyReminder = v;
    if (hour != null) dailyReminderHour = hour;
    if (minute != null) dailyReminderMinute = minute;
    await prefs.setBool('dailyReminder', dailyReminder);
    await prefs.setInt('dailyReminderHour', dailyReminderHour);
    await prefs.setInt('dailyReminderMinute', dailyReminderMinute);
    notifyListeners();
  }

  /// v2.2.3: smart reminder bodies (real spend numbers). The notification
  /// center re-applies the schedule after this flips.
  Future<void> setSmartNotifications(bool v) async {
    smartNotifications = v;
    await prefs.setBool('smartNotif', v);
    notifyListeners();
  }

  static String? _nonEmpty(String? v) => (v == null || v.isEmpty) ? null : v;

  // ── Google account (login) ─────────────────────────────────
  /// True after a successful sign-in, false when the user cancelled the
  /// Google dialog. Throws on failure (network / not configured).
  Future<bool> signInWithGoogle() async {
    final profile = await MbAuthService.instance.signIn();
    if (profile == null) return false;

    googleEmail = profile.email;
    googleName = profile.displayName.isEmpty ? null : profile.displayName;
    googlePhotoUrl = profile.photoUrl;
    googleUid = profile.id;
    loginSkipped = false;
    await prefs.setString('googleEmail', profile.email);
    await prefs.setString('googleUid', profile.id);
    if (googleName == null) {
      await prefs.remove('googleName');
    } else {
      await prefs.setString('googleName', googleName!);
    }
    if (googlePhotoUrl == null) {
      await prefs.remove('googlePhotoUrl');
    } else {
      await prefs.setString('googlePhotoUrl', googlePhotoUrl!);
    }

    // Sync profile: fill the name when empty, adopt the Google photo when
    // no local photo has been picked yet.
    if (userName.isEmpty && profile.displayName.isNotEmpty) {
      userName = profile.displayName;
      await prefs.setString('userName', userName);
    }
    if (avatarPath == null && profile.photoUrl != null) {
      // v2.2.0: the photo download (up to a 10 s timeout inside
      // fetchPhotoBytes) used to be awaited INSIDE the sign-in chain while
      // the login spinner was up. Fire-and-forget like the user sync below —
      // the avatar pops in via notifyListeners when it lands.
      unawaited(() async {
        final bytes =
            await MbAuthService.instance.fetchPhotoBytes(profile.photoUrl!);
        if (bytes != null) {
          try {
            await setAvatarBytes(bytes);
          } catch (_) {
            // Photo is optional — never fail sign-in because of it.
          }
        }
      }());
    }
    notifyListeners();

    // Register this user + FCM token on the Cloudflare Worker so the admin
    // panel can send them targeted pushes (silent, never blocks login).
    unawaited(MbUserSyncService.instance.syncFromPrefs());
    return true;
  }

  Future<void> unlinkGoogle() async {
    await MbAuthService.instance.signOut();
    googleEmail = null;
    googleName = null;
    googlePhotoUrl = null;
    googleUid = null;
    await prefs.remove('googleEmail');
    await prefs.remove('googleName');
    await prefs.remove('googlePhotoUrl');
    await prefs.remove('googleUid');
    notifyListeners();
  }

  Future<void> skipLogin() async {
    loginSkipped = true;
    await prefs.setBool('loginSkipped', true);
    notifyListeners();
  }

  Future<void> setLoginSeen() async {
    if (loginSeen) return;
    loginSeen = true;
    await prefs.setBool('loginSeen', true);
  }

  /// Restores a previous Google session silently (Drive-ready token).
  Future<void> tryRestoreGoogleSession() async {
    if (!googleLinked) return;
    final profile = await MbAuthService.instance.tryRestoreSession();
    if (profile != null) {
      googleEmail = profile.email;
      googleName =
          profile.displayName.isEmpty ? googleName : profile.displayName;
      googlePhotoUrl = profile.photoUrl ?? googlePhotoUrl;
      
      await prefs.setString('googleEmail', profile.email);
      if (googleName != null) {
        await prefs.setString('googleName', googleName!);
      }
      if (googlePhotoUrl != null) {
        await prefs.setString('googlePhotoUrl', googlePhotoUrl!);
      }

      if (profile.id.isNotEmpty) {
        googleUid = profile.id;
        await prefs.setString('googleUid', profile.id);
      }
      
      unawaited(MbUserSyncService.instance.syncFromPrefs());
    }
  }

  void markIntroDone() {
    if (_introDone) return;
    _introDone = true;
    notifyListeners();
  }

  // ── profile photo ──────────────────────────────────────
  /// Persists [bytes] as the profile photo and returns its path.
  Future<String> setAvatarBytes(List<int> bytes) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'profile_photo.jpg'));
    await file.writeAsBytes(bytes, flush: true);
    avatarPath = file.path;
    await prefs.setString('avatarPath', avatarPath!);
    notifyListeners();
    return avatarPath!;
  }

  Future<void> clearAvatar() async {
    final path = avatarPath;
    if (path != null) {
      try {
        await File(path).delete();
      } catch (_) {}
    }
    avatarPath = null;
    await prefs.remove('avatarPath');
    notifyListeners();
  }

  // ── backup bookkeeping ─────────────────────────────────
  Future<void> markBackupDone() async {
    lastBackupAt = DateTime.now();
    await prefs.setInt(
        'lastBackupAt', lastBackupAt!.millisecondsSinceEpoch);
    notifyListeners();
  }

  Future<void> setUserName(String name) async {
    userName = name.trim();
    await prefs.setString('userName', userName);
    notifyListeners();
  }

  Future<void> setMonthlyIncome(int? minor) async {
    monthlyIncomeMinor = minor == null || minor <= 0 ? null : minor;
    if (monthlyIncomeMinor == null) {
      await prefs.remove('incomeMinor');
    } else {
      await prefs.setInt('incomeMinor', monthlyIncomeMinor!);
    }
    notifyListeners();
  }

  Future<void> _saveSettings() async {
    await prefs.setBool('onboarded', onboarded);
    await prefs.setString('lang', language == MbLanguage.english ? 'en' : 'bn');
    await prefs.setString('theme', themeMode == ThemeMode.light
        ? 'light'
        : (themeMode == ThemeMode.system ? 'system' : 'dark'));
    await prefs.setBool('bnDigits', bengaliDigits);
    await prefs.setString('userName', userName);
    if (monthlyIncomeMinor == null) {
      await prefs.remove('incomeMinor');
    } else {
      await prefs.setInt('incomeMinor', monthlyIncomeMinor!);
    }
  }

  // ── transactions ────────────────────────────────────────────────────────
  // ── security (v2.1) ─────────────────────────────
  /// v2.1.1: backup PIN for the app lock (salted SHA-256 in prefs).
  /// local_auth alone does NOT offer a working PIN path on many OEM
  /// devices (BIOMETRIC|DEVICE_CREDENTIAL prompts simply never show the
  /// credential option) — this in-app PIN guarantees the user can always
  /// unlock when fingerprint fails.
  String? pinSalt;
  String? pinHash;
  bool get hasBackupPin => pinHash != null && pinHash!.isNotEmpty;

  Future<void> setBiometricLock(bool v) async {
    biometricLock = v;
    await prefs.setBool('biometricLock', v);
    notifyListeners();
  }

  /// Stores a 4-digit backup PIN as salt + iterated SHA-256 (v2 scheme).
  ///
  /// v2.2.0 hardening: the old single SHA-256 pass meant an offline brute
  /// force over all 10,000 4-digit PINs was instant. The v2 scheme chains
  /// SHA-256 60,000 times (key stretching) and prefixes the stored value
  /// with "v2:" so legacy hashes are recognised and upgraded on the next
  /// successful verification (see [verifyBackupPin]).
  Future<void> setBackupPin(String pin) async {
    final salt = _randomHex(16);
    final hash = await _hashPin(salt, pin);
    pinSalt = salt;
    pinHash = hash;
    await prefs.setString('pinSalt', salt);
    await prefs.setString('pinHash', hash);
    notifyListeners();
  }

  Future<void> clearBackupPin() async {
    pinSalt = null;
    pinHash = null;
    await prefs.remove('pinSalt');
    await prefs.remove('pinHash');
    notifyListeners();
  }

  /// Verification path used by the lock gate (async — iterated SHA-256).
  ///
  /// Legacy (v1) single-hash values are still accepted; a successful legacy
  /// verification transparently re-stores the PIN with the v2 scheme.
  Future<bool> verifyBackupPin(String pin) async {
    if (!hasBackupPin || pinSalt == null || pin.length != 4) return false;
    final stored = pinHash!;
    if (stored.startsWith('v2:')) {
      final h = await _hashPin(pinSalt!, pin);
      // Constant-time-ish compare — no early exit on the first difference.
      return _fixedTimeEquals(h.substring(3), stored.substring(3));
    }
    // ── legacy v1 path ──
    final d = await Sha256().hash(utf8.encode('$pinSalt·$pin·moneybag'));
    final legacy = d.bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    if (!_fixedTimeEquals(legacy, stored)) return false;
    // Correct legacy PIN → upgrade to the hardened scheme with a new salt.
    await setBackupPin(pin);
    return true;
  }

  /// XOR-accumulating string compare (no early exit). Leaks length only.
  static bool _fixedTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }

  static const int _kPinIterations = 60000;

  /// v2: salt + pin → 60,000 chained SHA-256 rounds → "v2:" + hex digest.
  Future<String> _hashPin(String salt, String pin) async {
    final sha = Sha256();
    List<int> data = utf8.encode('$salt·$pin·moneybag');
    for (var i = 0; i < _kPinIterations; i++) {
      data = (await sha.hash(data)).bytes;
    }
    return 'v2:' +
        data.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  static String _randomHex(int bytes) {
    final r = math.Random.secure();
    return List.generate(bytes, (_) => r.nextInt(256))
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
  }

  // ── v2.1: duplicate-entry guard ─────────────────
  /// Same amount, same category, same day (expenses only). Returns true
  /// when such an entry already exists — the editor shows a soft warning.
  bool hasSameDayExpense({
    required int amountMinor,
    required String? categoryId,
    required DateTime date,
    String? exceptId,
  }) {
    for (final t in transactions) {
      if (t.id == exceptId) continue;
      if (t.kind != 'expense') continue;
      if (t.amountMinor != amountMinor) continue;
      if (t.categoryId != categoryId) continue;
      if (t.date.year != date.year ||
          t.date.month != date.month ||
          t.date.day != date.day) {
        continue;
      }
      return true;
    }
    return false;
  }

  Future<void> saveTransaction({
    String? id,
    required String kind,
    required int amountMinor,
    String? categoryId,
    String? note,
    required DateTime date,
  }) async {
    final now = DateTime.now();
    await db.upsertTransaction(TransactionsCompanion(
      id: Value(id ?? MbUtils.uuid()),
      kind: Value(kind),
      amountMinor: Value(amountMinor),
      categoryId: Value(categoryId),
      note: Value(note?.trim().isEmpty == true ? null : note?.trim()),
      date: Value(DateTime(date.year, date.month, date.day, 12)),
      createdAt: id == null ? Value(now) : const Value.absent(),
      updatedAt: Value(now),
    ));
    await _refresh();
  }

  Future<void> deleteTransaction(String id) async {
    await db.deleteTransaction(id);
    await _refresh();
  }

  // ── budgets ─────────────────────────────────────────────────────────────
  Future<void> saveBudget({
    String? id,
    String? categoryId,
    required int amountMinor,
    bool rollover = false,
  }) async {
    // One budget per target: replace existing row for the same category.
    if (id == null) {
      for (final b in budgets) {
        if (b.categoryId == categoryId) {
          id = b.id;
          break;
        }
      }
    }
    await db.upsertBudget(BudgetsCompanion(
      id: Value(id ?? MbUtils.uuid()),
      categoryId: Value(categoryId),
      amountMinor: Value(amountMinor),
      rollover: Value(rollover),
      active: const Value(true),
    ));
    await _refresh();
  }

  Future<void> deleteBudget(String id) async {
    await db.deleteBudget(id);
    await _refresh();
  }

  /// Budget lines resolved for the calc/insights engines.
  List<MbBudgetLine> budgetLines() => [
        for (final b in budgets)
          MbBudgetLine(
            categoryId: b.categoryId,
            limitMinor: b.amountMinor,
            rollover: b.rollover,
          ),
      ];

  // ── goals ───────────────────────────────────────────────────────────────
  int savedForGoal(String goalId) {
    var sum = 0;
    for (final c in contributions) {
      if (c.goalId == goalId) sum += c.amountMinor;
    }
    return sum;
  }

  /// v2.1: average monthly deposit rate for a goal (last 90 days ÷ 3),
  /// in poisha. Used for the "at this pace" ETA prediction.
  double goalMonthlyRate(String goalId) {
    final cutoff = DateTime.now().subtract(const Duration(days: 90));
    var sum = 0;
    for (final c in contributions) {
      if (c.goalId == goalId && !c.date.isBefore(cutoff)) {
        sum += c.amountMinor;
      }
    }
    return sum / 3;
  }

  int get totalSaved {
    var sum = 0;
    for (final c in contributions) {
      sum += c.amountMinor;
    }
    return sum;
  }

  Future<void> saveGoal({
    String? id,
    required String name,
    required int targetMinor,
    required String icon,
    DateTime? targetDate,
  }) async {
    await db.upsertGoal(GoalsCompanion(
      id: Value(id ?? MbUtils.uuid()),
      name: Value(name.trim()),
      targetMinor: Value(targetMinor),
      icon: Value(icon),
      targetDate: Value(targetDate),
    ));
    await _refresh();
  }

  Future<void> deleteGoal(String id) async {
    await db.deleteGoal(id);
    await _refresh();
  }

  Future<void> contribute(String goalId, int amountMinor, {String? note}) async {
    await db.insertContribution(ContributionsCompanion.insert(
      id: MbUtils.uuid(),
      goalId: goalId,
      amountMinor: amountMinor,
      date: DateTime.now(),
      note: Value(note),
    ));
    await _refresh();
  }

  Future<void> deleteContribution(String id) async {
    await db.deleteContribution(id);
    await _refresh();
  }

  // ── categories ──────────────────────────────────────────────────────────
  /// v2.2.5: the tx editor's top box ("কিসে খরচ হলো?") is a FREE-TEXT
  /// category — the user writes what the money went for and it IS the
  /// category (no chip needed). Resolves the typed name to an existing
  /// ACTIVE category of the same kind (case-insensitive match) or creates
  /// a custom one. Returns the category id to store on the transaction.
  Future<String> findOrCreateCategoryByName(
      String name, String kind) async {
    final key = name.trim().toLowerCase();
    for (final c in categories) {
      if (c.isActive &&
          c.kind == kind &&
          c.name.trim().toLowerCase() == key) {
        return c.id;
      }
    }
    final id = MbUtils.uuid();
    await db.upsertCategory(CategoriesCompanion(
      id: Value(id),
      name: Value(name.trim()),
      icon: const Value('🏷️'),
      color: const Value(0xFF9AA8A0),
      kind: Value(kind),
      isDefault: const Value(false),
      sortOrder: Value(categories.length),
    ));
    await _refresh();
    return id;
  }

  Future<String> saveCategory({
    String? id,
    required String name,
    required String icon,
    required int color,
    required String kind,
  }) async {
    final newId = id ?? MbUtils.uuid();
    await db.upsertCategory(CategoriesCompanion(
      id: Value(newId),
      name: Value(name.trim()),
      icon: Value(icon),
      color: Value(color),
      kind: Value(kind),
      sortOrder: Value(categories.length),
    ));
    await _refresh();
    return newId;
  }

  /// Returns false when deletion is blocked (default or still in use).
  Future<bool> tryDeleteCategory(String id) async {
    final cat = catById[id];
    if (cat == null || cat.isDefault) return false;
    final count = await db.transactionCountForCategory(id);
    if (count > 0) return false;
    await db.deleteCategory(id);
    await _refresh();
    return true;
  }

  Future<void> resetAll() async {
    await db.wipeAll();
    await prefs.clear();
    onboarded = false;
    userName = '';
    monthlyIncomeMinor = null;
    language = MbLanguage.bangla;
    themeMode = ThemeMode.dark;
    bengaliDigits = true;
    budgetAlerts = true;
    weeklySummary = true;
    dailyReminder = true;
    dailyReminderHour = 20;
    dailyReminderMinute = 0;
    avatarPath = null;
    lastBackupAt = null;
    googleEmail = null;
    googleName = null;
    googlePhotoUrl = null;
    googleUid = null;
    loginSkipped = false;
    loginSeen = false;
    // v2.2.0: prefs.clear() wipes the persisted values, but the in-memory
    // fields kept the OLD PIN/lock armed for the rest of the session.
    pinSalt = null;
    pinHash = null;
    biometricLock = false;
    await _reload();
    notifyListeners();
  }
}
