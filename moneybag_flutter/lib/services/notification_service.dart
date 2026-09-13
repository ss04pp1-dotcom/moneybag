import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../core/calc.dart';
import '../core/l10n.dart';
import '../state/app_state.dart';

/// Real system notifications.
///
/// * budget alerts      — fired immediately when a budget crosses 85%/100%
/// * daily reminder     — auto, every day at the user's chosen time
/// * weekly summary     — auto, every Friday with last week's real spend
/// * FCM push           — shown locally when a push arrives in the foreground
///
/// v2.2.3 — "smart notifications": when [MbAppState.smartNotifications] is
/// on (default) the daily reminder carries REAL numbers — yesterday's
/// spend, month-to-date and budget-left — refreshed on every app open.
/// One switch in the notification center reverts to the plain reminder.
/// Also new: [sendTest] (one-tap sanity check for the user),
/// [isPermissionGranted] (non-interactive), and the device channel
/// helpers for battery-optimization + notification settings (the two
/// classic OEM reasons reminders "don't work" on BD-market phones).
///
/// Scheduling strategy (v2 fix — reminders now fire on aggressive OEM ROMs):
/// 1. `alarmClock` — Android's stock-clock mechanism (AlarmManagerCompat
///    .setAlarmClock). OEM battery managers (MIUI/Walton/Symphony-style ROMs)
///    never kill it and it needs NO special permission. One alarm icon may
///    show in the status bar — that's the reliability trade-off.
/// 2. `exactAllowWhileIdle` — if alarmClock is unavailable.
/// 3. `inexactAllowWhileIdle` — last resort, still fires (just maybe late).
///
/// Every outcome is PERSISTED as plain strings into `notifScheduleStatus`
/// (never a closure/function — that caused the raw `Closure: … PlatformException`
/// leak on the notification screen), so the notification center can show the
/// real reason if something ever fails again.
class MbNotifications {
  MbNotifications._();
  static final MbNotifications instance = MbNotifications._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// Native helpers: battery-optimization state + OS settings screens.
  static const MethodChannel _device = MethodChannel('moneybag/device');

  static const String _channelId = 'moneybag_reminders';
  static const String _channelName = 'MoneyBag reminders';
  static const String _channelDesc =
      'Budget alerts, daily reminder and weekly summary';
  static const String _pushChannelId = 'moneybag_push';
  static const String _pushChannelName = 'MoneyBag push';

  static const int _dailyId = 1001;
  static const int _weeklyId = 1002;
  static const int _catchUpId = 1003;

  bool _initialized = false;
  bool? _granted;

  /// LAST scheduling failure, stored as a plain string (safe to render).
  String? _lastScheduleError;
  String? get lastScheduleError => _lastScheduleError;

  /// Notification ids for budget alerts are derived from a stable seed so
  /// repeated crossings replace (not stack) older ones.
  int _budgetId(String key) => 2000 + (key.hashCode & 0x7FFFFFFF) % 100000;

  // ── init ────────────────────────────────────────────────────────────────
  Future<void> init() async {
    if (_initialized || !Platform.isAndroid && !Platform.isIOS) return;
    try {
      tzdata.initializeTimeZones();
      await _initLocalTimeZone();
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const ios = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      await _plugin.initialize(
        const InitializationSettings(android: android, iOS: ios),
        onDidReceiveNotificationResponse: (_) {},
      );
      _initialized = true;
    } catch (e) {
      debugPrint('MbNotifications.init failed: $e');
    }
  }

  /// Reliable IANA timezone detection.
  ///
  /// `DateTime.now().timeZoneName` returns garbage like "BDT"/"GMT+06:00" on
  /// many Android ROMs — which silently breaks `zonedSchedule`. The
  /// flutter_timezone plugin returns the real IANA name ("Asia/Dhaka").
  Future<void> _initLocalTimeZone() async {
    var iana = '';
    try {
      iana = await FlutterTimezone.getLocalTimezone();
    } catch (e) {
      debugPrint('FlutterTimezone.getLocalTimezone failed: $e');
    }
    try {
      if (iana.isNotEmpty) {
        tz.setLocalLocation(tz.getLocation(iana));
        return;
      }
    } catch (_) {
      // Unknown IANA name → fall through to the offset guess below.
    }
    try {
      tz.setLocalLocation(tz.getLocation(_tzDatabaseName(DateTime.now().timeZoneName)));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('Asia/Dhaka'));
    }
  }

  String _tzDatabaseName(String raw) {
    // Windows/Java-style names can't be mapped reliably; use offset guess.
    final utc = DateTime.now().timeZoneOffset;
    if (utc.inMinutes == 360) return 'Asia/Dhaka';
    return raw.isEmpty ? 'Asia/Dhaka' : raw;
  }

  /// Requests permission (Android 13+ / iOS). Returns true when granted.
  Future<bool> requestPermission() async {
    if (!_initialized) await init();
    if (!_initialized) return false;
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        final granted = await android.requestNotificationsPermission();
        _granted = granted ?? false;
        return _granted!;
      }
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      if (ios != null) {
        _granted = await ios.requestPermissions(
            alert: true, badge: true, sound: true);
        return _granted ?? false;
      }
    } catch (e) {
      debugPrint('requestPermission failed: $e');
    }
    return false;
  }

  Future<bool> get granted async {
    _granted ??= await requestPermission();
    return _granted!;
  }

  /// Non-interactive permission check (no dialog, no request): reads
  /// `areNotificationsEnabled()`. Used by the notification center to warn
  /// when reminders can't possibly show.
  Future<bool> isPermissionGranted() async {
    if (!_initialized) await init();
    if (!_initialized) return false;
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        return await android.areNotificationsEnabled() ?? false;
      }
    } catch (e) {
      debugPrint('areNotificationsEnabled failed: $e');
    }
    return _granted ?? false;
  }

  // ── device helpers (method channel → MainActivity) ──────────────────
  /// True when the app is exempt from battery optimization — the #1 reason
  /// alarms silently die on Walton/Symphony/MIUI-class ROMs.
  Future<bool> isBatteryIgnored() async {
    if (!Platform.isAndroid) return true;
    try {
      return await _device.invokeMethod<bool>('isIgnoringBatteryOptimizations') ??
          true;
    } catch (_) {
      return true; // channel missing/failed → don't scare the user
    }
  }

  /// Shows the system "allow ignoring battery optimizations" dialog.
  Future<void> requestIgnoreBatteryOptimizations() async {
    if (!Platform.isAndroid) return;
    try {
      await _device.invokeMethod<void>('requestIgnoreBatteryOptimizations');
    } catch (_) {}
  }

  /// Opens this app's screen in system notification settings (the place
  /// where a denied POST_NOTIFICATIONS can be re-allowed).
  Future<void> openNotificationSettings() async {
    if (!Platform.isAndroid) return;
    try {
      await _device.invokeMethod<void>('openNotificationSettings');
    } catch (_) {}
  }

  // ── immediate notifications ─────────────────────────────────────────────
  Future<void> show({
    required int id,
    required String title,
    required String body,
  }) =>
      _show(
        id: id,
        title: title,
        body: body,
        channelId: _channelId,
        channelName: _channelName,
        channelDesc: _channelDesc,
      );

  /// FCM push shown locally (foreground messages).
  Future<void> showPush({
    required int id,
    required String title,
    required String body,
  }) =>
      _show(
        id: id,
        title: title,
        body: body,
        channelId: _pushChannelId,
        channelName: _pushChannelName,
        channelDesc: 'Notices from the MoneyBag admin panel',
      );

  Future<void> _show({
    required int id,
    required String title,
    required String body,
    required String channelId,
    required String channelName,
    required String channelDesc,
  }) async {
    if (!_initialized) return;
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDesc,
        importance: Importance.high,
        priority: Priority.high,
        category: AndroidNotificationCategory.reminder,
      ),
      iOS: const DarwinNotificationDetails(),
    );
    try {
      await _plugin.show(id, title, body, details);
    } catch (e) {
      debugPrint('MbNotifications.show failed: $e');
    }
  }

  // ── scheduled reminders ─────────────────────────────────────────────────
  /// The daily reminder body. Smart mode (default) packs real numbers —
  /// refreshed every time the schedule is re-applied (boot, settings change,
  /// and now every app resume, so the numbers stay honest).
  String _dailyBody(MbAppState state) {
    final loc = L.stringsFor(state.language);
    if (!state.smartNotifications) return loc.notifDailyBody;

    final now = DateTime.now();
    final all = state.txView;
    final parts = <String>[];

    // Yesterday's spend — only when there was any.
    final y = DateTime(now.year, now.month, now.day)
        .subtract(const Duration(days: 1));
    final yesterday = MbCalc.totals(
            MbCalc.between(all, y, DateTime(y.year, y.month, y.day + 1)))
        .expense;
    if (yesterday > 0) {
      parts.add(loc.notifSmartYesterday(state.money(yesterday)));
    }

    // Month-to-date spend.
    final month =
        MbCalc.totals(MbCalc.forMonth(all, now.year, now.month)).expense;
    if (month > 0) {
      parts.add(loc.notifSmartMonth(state.money(month)));
    }

    // Budget head-room — only with an overall budget that isn't blown.
    for (final b in state.budgets) {
      if (b.categoryId != null) continue;
      final st = MbCalc.budgetStatus(all, now.year, now.month,
          limitMinor: b.amountMinor, rollover: b.rollover);
      final left = st.effectiveLimit - st.spentMinor;
      if (left > 0) {
        parts.add(loc.notifSmartLeft(state.money(left)));
      }
      break; // first overall budget only
    }

    if (parts.isEmpty) return loc.notifDailyBody;
    return parts.join(' · ');
  }

  /// v2.2.3: fires the daily reminder RIGHT NOW with the current smart
  /// body — a one-tap "is this thing alive?" check for the user (and for
  /// us: if the test shows, channels + permission are fine and any missed
  /// reminder is an OEM/battery issue, not a silent app bug).
  Future<void> sendTest(MbAppState state) async {
    if (!_initialized) await init();
    if (!_initialized) return;
    final loc = L.stringsFor(state.language);
    await show(
      id: _catchUpId,
      title: loc.appName,
      body: _dailyBody(state),
    );
  }

  /// Schedules one repeating reminder. Returns the mode name that worked
  /// ('alarmClock' / 'exactAllowWhileIdle' / 'inexactAllowWhileIdle') or
  /// null when every mode failed — with the exception text captured into
  /// [lastScheduleError] as a plain string.
  ///
  /// v2.2.5 CRITICAL FIX: [repeat] used to be hardcoded
  /// `DateTimeComponents.time` (= repeat EVERY DAY) for BOTH reminders —
  /// so the "weekly" summary actually fired daily, on top of the daily
  /// reminder (two notifications a day). Now the daily reminder passes
  /// `time` and the weekly summary `dayOfWeekAndTime` (same weekday+time
  /// every week), which is what the plugin docs specify for weekly repeats.
  Future<String?> _zonedSchedule({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime when,
    required DateTimeComponents repeat,
  }) async {
    if (!_initialized) return null;
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDesc,
        importance: Importance.high,
        priority: Priority.high,
        category: AndroidNotificationCategory.reminder,
      ),
      iOS: DarwinNotificationDetails(),
    );

    // Preference order = reliability order. alarmClock is what stock clock
    // apps use — OEM battery savers do not touch it.
    const modes = [
      AndroidScheduleMode.alarmClock,
      AndroidScheduleMode.exactAllowWhileIdle,
      AndroidScheduleMode.inexactAllowWhileIdle,
    ];

    String? lastErr;
    for (final mode in modes) {
      try {
        await _plugin.zonedSchedule(
          id,
          title,
          body,
          when,
          details,
          androidScheduleMode: mode,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: repeat,
        );
        return mode.name;
      } on PlatformException catch (e) {
        // Full exception (often a Java stack trace) → console only.
        debugPrint('zonedSchedule($mode) failed: $e');
        lastErr = _briefError(e);
        continue;
      } catch (e) {
        debugPrint('zonedSchedule($mode) failed: $e');
        lastErr = _briefError(e);
        break;
      }
    }
    _lastScheduleError = lastErr; // one short line — safe to render anywhere
    return null;
  }

  /// One-line, user-safe error summary. The FULL exception text (which can
  /// include a long Java stack trace) must NEVER be persisted or rendered —
  /// it once turned the notification screen into a wall of technical noise.
  String _briefError(Object e) {
    if (e is PlatformException) {
      final msg = (e.message ?? '').trim();
      return msg.isEmpty ? 'PlatformException(${e.code})' : msg;
    }
    var s = e.toString();
    final nl = s.indexOf('\n');
    if (nl > 0) s = s.substring(0, nl);
    s = s.trim();
    return s.length > 120 ? '${s.substring(0, 117)}…' : s;
  }

  /// One-time permission ask + scheduling of the two AUTO notifications.
  ///
  /// Called on app start (for already-onboarded users) and right after
  /// profile setup — the daily reminder and weekly summary are ON by
  /// default, so notifications "just work" without digging into settings.
  Future<void> ensureAutoEnable(MbAppState state) async {
    if (!_initialized) await init();
    if (!_initialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final asked = prefs.getBool('notifPermAsked') ?? false;
      if (!asked) {
        await prefs.setBool('notifPermAsked', true);
        // System dialog (Android 13+ / iOS) — asked exactly once.
        await requestPermission();
      }
      if (await granted) {
        await applySchedule(state);
      }
    } catch (e) {
      debugPrint('MbNotifications.ensureAutoEnable: $e');
    }
  }

  /// Schedules (or reschedules) all recurring reminders from settings and
  /// PERSISTS the outcome for the notification center diagnostics card.
  Future<void> applySchedule(MbAppState state) async {
    if (!_initialized) return;
    final loc = L.stringsFor(state.language);
    _lastScheduleError = null;
    try {
      await _plugin.cancel(_dailyId);
      await _plugin.cancel(_weeklyId);
    } catch (_) {}

    String? dailyMode;
    String? weeklyMode;

    if (state.dailyReminder) {
      final now = tz.TZDateTime.now(tz.local);
      var when = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        state.dailyReminderHour,
        state.dailyReminderMinute,
      );
      if (!when.isAfter(now)) when = when.add(const Duration(days: 1));
      dailyMode = await _zonedSchedule(
        id: _dailyId,
        title: loc.appName,
        body: _dailyBody(state),
        when: when,
        repeat: DateTimeComponents.time, // every day at the chosen time
      );
    }

    if (state.weeklySummary) {
      // Weekly summary every Friday at the daily-reminder time, with the
      // REAL last-7-day spend baked into the body (refreshed on each open).
      // v2.2.0: `between` is [from, to) over date-normalised entries, so
      // subtracting 7 days + adding 1 actually spanned EIGHT calendar days.
      // Today + the 6 previous days = a true 7-day window.
      final spend = MbCalc.totals(MbCalc.between(
        state.txView,
        DateTime.now().subtract(const Duration(days: 6)),
        DateTime.now().add(const Duration(days: 1)),
      )).expense;
      final body = loc.notifWeeklyBodyLive(state.money(spend));
      final now = tz.TZDateTime.now(tz.local);
      var when = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        state.dailyReminderHour,
        state.dailyReminderMinute,
      );
      var daysUntilFriday = (DateTime.friday - now.weekday + 7) % 7;
      if (daysUntilFriday == 0 && !when.isAfter(now)) daysUntilFriday = 7;
      when = when.add(Duration(days: daysUntilFriday));
      weeklyMode = await _zonedSchedule(
        id: _weeklyId,
        title: loc.notifWeeklyTitle,
        body: body,
        when: when,
        // v2.2.5: weekly repeat — was DateTimeComponents.time (daily!),
        // which made the weekly summary fire EVERY day.
        repeat: DateTimeComponents.dayOfWeekAndTime,
      );
    }

    final pending = await pendingAlarmCount();
    final status = MbNotifScheduleStatus(
      dailyScheduled: dailyMode != null,
      dailyMode: dailyMode,
      weeklyScheduled: weeklyMode != null,
      weeklyMode: weeklyMode,
      lastError: _lastScheduleError,
      pendingCount: pending,
      updatedAt: DateTime.now(),
    );
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'notifScheduleStatus', jsonEncode(status.toMap()));
    } catch (e) {
      debugPrint('persist schedule status failed: $e');
    }
  }

  /// How many of our reminder alarms the plugin actually holds (1001/1002).
  /// On Android this reads the plugin's own alarm registry — if this says 0
  /// while the toggles say on, scheduling genuinely failed.
  Future<int> pendingAlarmCount() async {
    if (!_initialized) return 0;
    try {
      final list = await _plugin.pendingNotificationRequests();
      return list
          .where((r) => r.id == _dailyId || r.id == _weeklyId)
          .length;
    } catch (_) {
      return 0;
    }
  }

  /// Latest persisted schedule status (for the notification center).
  Future<MbNotifScheduleStatus?> loadStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('notifScheduleStatus');
      if (raw == null) return null;
      return MbNotifScheduleStatus.fromMap(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  // ── missed-reminder catch-up ────────────────────────────────────────────
  /// OEM alarms can still be dropped (device off, force-stopped, Doze edge
  /// cases). When the user opens the app AFTER the reminder time passed and
  /// no transaction was logged that day, we show the reminder right away.
  /// Runs at most once per day.
  Future<void> catchUpMissedReminder(MbAppState state) async {
    if (!_initialized || !state.dailyReminder) return;
    if (!(await granted)) return;

    final now = DateTime.now();
    final dueAt = DateTime(
      now.year, now.month, now.day,
      state.dailyReminderHour, state.dailyReminderMinute,
    );
    if (now.isBefore(dueAt)) return; // not due yet today

    final todayKey =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString('notifCatchUpDate') == todayKey) return;

    // Mark FIRST — never loop this on every resume.
    await prefs.setString('notifCatchUpDate', todayKey);

    final hasTxToday = state.txView.any((t) =>
        t.date.year == now.year &&
        t.date.month == now.month &&
        t.date.day == now.day);
    if (hasTxToday) return; // user already logged — reminder unnecessary

    // v2.2.5: was `loc.notifDailyTitle('')` — the TITLE string with an
    // empty time argument as the body. Now it carries the same live smart
    // numbers as the scheduled reminder.
    final loc = L.stringsFor(state.language);
    await show(
      id: _catchUpId,
      title: loc.appName,
      body: _dailyBody(state),
    );
  }

  /// Called every time the app comes to the foreground.
  Future<void> onAppResumed(MbAppState state) async {
    if (!_initialized) return;
    try {
      await catchUpMissedReminder(state);
    } catch (e) {
      debugPrint('catchUpMissedReminder: $e');
    }
    // v2.2.3: re-apply the schedule on every resume — (a) refreshes the
    // smart body numbers, (b) re-arms alarms the OEM dropped while the app
    // was dead. Cheap (2 cancel + 2 schedule calls) and idempotent.
    if (state.dailyReminder || state.weeklySummary) {
      try {
        await applySchedule(state);
      } catch (e) {
        debugPrint('applySchedule on resume: $e');
      }
    }
  }

  Future<void> cancelAll() async {
    if (!_initialized) return;
    try {
      await _plugin.cancelAll();
    } catch (_) {}
  }

  // ── budget alerts ───────────────────────────────────────────────────────
  /// Checks every budget against live data and fires a notification the
  /// FIRST time a threshold (85% / 100%) is crossed. Alert state is stored
  /// in SharedPreferences keyed by budget id + month, so it never repeats
  /// for the same crossing.
  Future<void> evaluateBudgetAlerts(MbAppState state) async {
    if (!_initialized || !state.budgetAlerts) return;
    if (!(await granted)) return;
    if (state.budgets.isEmpty) return;

    final loc = L.stringsFor(state.language);
    final now = DateTime.now();
    final all = state.txView;
    final prefs = await SharedPreferences.getInstance();

    for (final b in state.budgetLines()) {
      final st = MbCalc.budgetStatus(
        all,
        now.year,
        now.month,
        categoryId: b.categoryId,
        limitMinor: b.limitMinor,
        rollover: b.rollover,
      );
      if (st.state == MbBudgetState.safe || st.state == MbBudgetState.none) {
        continue;
      }

      final cat = b.categoryId == null
          ? loc.budgetOverallCard
          : state.categoryName(b.categoryId);
      final key =
          'notif_b_${b.categoryId ?? 'all'}_${now.year}_${now.month}';
      final stage = st.state == MbBudgetState.over ? 2 : 1; // 1=warn 2=over
      final prev = prefs.getInt(key) ?? 0;
      if (stage <= prev) continue; // already notified at this level

      final body = st.state == MbBudgetState.over
          ? loc.notifBudgetOverBodyLive(cat,
              '${state.money(st.spentMinor)} / ${state.money(st.effectiveLimit)}')
          : loc.notifBudgetNearBodyLive(cat, state.pct(st.usedPct));

      await show(
        id: _budgetId(key),
        title: loc.notifBudgetTitle,
        body: body,
      );
      await prefs.setInt(key, stage);
    }
  }
}

/// Persisted diagnostics for the notification center — everything is a
/// plain serializable value (strings/ints/ISO dates), never a function.
class MbNotifScheduleStatus {
  final bool dailyScheduled;
  final String? dailyMode; // alarmClock | exactAllowWhileIdle | inexact…
  final bool weeklyScheduled;
  final String? weeklyMode;
  final String? lastError; // plain exception text, or null when all is well
  final int? pendingCount;
  final DateTime? updatedAt;

  const MbNotifScheduleStatus({
    this.dailyScheduled = false,
    this.dailyMode,
    this.weeklyScheduled = false,
    this.weeklyMode,
    this.lastError,
    this.pendingCount,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
        'daily': dailyScheduled,
        'dailyMode': dailyMode,
        'weekly': weeklyScheduled,
        'weeklyMode': weeklyMode,
        'lastError': lastError,
        'pending': pendingCount,
        'updatedAt': updatedAt?.toIso8601String(),
      };

  factory MbNotifScheduleStatus.fromMap(Map<String, dynamic> m) =>
      MbNotifScheduleStatus(
        dailyScheduled: m['daily'] == true,
        dailyMode: m['dailyMode'] == null ? null : '${m['dailyMode']}',
        weeklyScheduled: m['weekly'] == true,
        weeklyMode: m['weeklyMode'] == null ? null : '${m['weeklyMode']}',
        lastError: m['lastError'] == null || m['lastError'] == ''
            ? null
            : '${m['lastError']}',
        pendingCount:
            m['pending'] == null ? null : int.tryParse('${m['pending']}'),
        updatedAt: m['updatedAt'] == null
            ? null
            : DateTime.tryParse('${m['updatedAt']}'),
      );
}
