import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'notification_service.dart';
import 'remote_config_service.dart';
import 'user_sync_service.dart';

/// Real-time FCM push (replaces the old polling model).
///
/// * Foreground messages  → shown instantly as a local notification
/// * Background/terminated→ shown by the Android system tray automatically
/// * Token changes        → re-synced to the worker (users/sync)
/// * data.type == 'refresh' / 'announcement' → remote config re-fetch, so
///   announcements/ads update the moment the admin panel changes them.
///
/// The app stays fully usable when Firebase is not configured yet (the
/// placeholder google-services.json): every Firebase call is guarded and
/// `enabled` simply stays false.
class MbPushService extends ChangeNotifier {
  MbPushService._();
  static final MbPushService instance = MbPushService._();

  bool _initialized = false;
  bool _available = false; // Firebase initialized + messaging usable
  String? _token;

  bool get available => _available;
  String? get token => _token;

  int _nextLocalId = 3000;
  static const String _historyKey = 'pushHistory';

  /// Received pushes (newest first) for the notification center.
  List<Map<String, dynamic>> _history = [];
  List<Map<String, dynamic>> get history => List.unmodifiable(_history);

  // ── background message handler (must stay top-level + entry-point) ───────
  @pragma('vm:entry-point')
  static Future<void> backgroundHandler(RemoteMessage message) async {
    // Data-only "refresh" pings: nothing to show, just wake-up. Showing from
    // here is unreliable — the system tray already displays notification
    // messages, so we only record lightweight work.
    debugPrint('FCM background: ${message.messageId}');
  }

  /// Boots Firebase + registers all listeners. Never throws.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      await Firebase.initializeApp();
    } catch (e) {
      // google-services.json still the placeholder (or Firebase missing) —
      // push stays off; everything else works.
      debugPrint('MbPushService: Firebase not configured ($e)');
      return;
    }

    try {
      final messaging = FirebaseMessaging.instance;

      // Permission — on Android this is a no-op if already granted by the
      // local-notifications flow; on iOS it shows the system dialog once.
      await messaging.requestPermission(alert: true, badge: true, sound: true);

      // iOS: let the system present notifications while the app is open.
      // Android has no such option — we show local notifications instead.
      if (Platform.isIOS) {
        await messaging.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
      }

      await _loadHistory();

      // Token + refresh → keep the worker's copy current.
      final token = await messaging.getToken();
      if (token != null && token.isNotEmpty) {
        await _onToken(token);
      }
      messaging.onTokenRefresh.listen((t) => _onToken(t));

      // Foreground: show immediately (Android) / iOS presents it itself.
      FirebaseMessaging.onMessage.listen((message) {
        _handleForeground(message);
      });

      // Tapped while in background → refresh remote state.
      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        unawaited(refreshRemoteState(message));
      });

      // Tapped while the app was terminated.
      messaging.getInitialMessage().then((message) {
        if (message != null) {
          unawaited(refreshRemoteState(message));
        }
      });

      // Background/terminated message handling (static registration).
      FirebaseMessaging.onBackgroundMessage(backgroundHandler);

      _available = true;
      notifyListeners();
    } catch (e) {
      debugPrint('MbPushService.init: $e');
    }
  }

  Future<void> _onToken(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fcmToken', token);
    notifyListeners();
    // Keep the worker's user record bound to this token.
    unawaited(MbUserSyncService.instance.syncFromPrefs(fcmToken: token));
  }

  void _handleForeground(RemoteMessage message) {
    final notification = message.notification;
    final title = notification?.title ?? message.data['title'] ?? '';
    final body = notification?.body ?? message.data['body'] ?? '';
    unawaited(_remember(title: '$title', body: '$body'));

    if (Platform.isIOS) {
      // iOS presents the message itself (options above).
    } else if ('$title'.isNotEmpty || '$body'.isNotEmpty) {
      final id = _nextLocalId++;
      unawaited(MbNotifications.instance.showPush(
        id: id,
        title: '$title',
        body: '$body',
      ));
    }

    final type = '${message.data['type'] ?? ''}';
    if (type == 'refresh' || type == 'announcement') {
      unawaited(MbRemoteConfigService.instance.refresh());
    }
  }

  /// Called from onMessageOpenedApp / getInitialMessage — a push was tapped,
  /// so announcements/ads may have changed server-side.
  Future<void> refreshRemoteState(RemoteMessage message) async {
    final type = '${message.data['type'] ?? ''}';
    if (type == 'refresh' || type == 'announcement' || type.isEmpty) {
      await MbRemoteConfigService.instance.refresh();
    }
  }

  // ── push history (notification center) ──────────────────────────────────
  Future<void> _loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_historyKey);
      if (raw != null) {
        final list = jsonDecode(raw);
        if (list is List) {
          _history = [
            for (final e in list)
              if (e is Map<String, dynamic>) e,
          ];
        }
      }
    } catch (_) {}
  }

  Future<void> _remember({required String title, required String body}) async {
    if (title.isEmpty && body.isEmpty) return;
    _history.insert(0, {
      'title': title,
      'body': body,
      'at': DateTime.now().toIso8601String(),
    });
    if (_history.length > 50) {
      _history = _history.sublist(0, 50);
    }
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_historyKey, jsonEncode(_history));
    } catch (_) {}
  }

  /// Manual re-sync (used from the notification center diagnostics card).
  Future<bool> resync() async {
    if (!_available) return false;
    return MbUserSyncService.instance.syncFromPrefs(fcmToken: _token);
  }
}
