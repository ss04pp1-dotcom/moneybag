import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/config.dart';

/// Syncs the app user (Name, Email, UID + FCM token) to the Cloudflare
/// Worker (`POST /api/v1/users/sync`) so the admin panel can list the user
/// and send them targeted push notifications.
///
/// Identity resolution:
///  * signed in with Google → the stable Google account UID
///  * guest users           → a random per-install device id
///
/// Silent by design: failures are logged, never surfaced — push is a bonus
/// feature and must never disturb the offline-first core.
class MbUserSyncService {
  MbUserSyncService._();
  static final MbUserSyncService instance = MbUserSyncService._();

  static const String _deviceUidKey = 'mbDeviceUid';

  SharedPreferences? _prefs;

  Future<SharedPreferences> _prefs_() async =>
      _prefs ??= await SharedPreferences.getInstance();

  /// Stable per-install id for guest users (prefixed so the admin panel can
  /// tell guests and Google accounts apart).
  Future<String> deviceUid() async {
    final prefs = await _prefs_();
    var uid = prefs.getString(_deviceUidKey);
    if (uid == null || uid.isEmpty) {
      uid = 'device-${DateTime.now().millisecondsSinceEpoch}-'
          '${_rand4()}${_rand4()}';
      await prefs.setString(_deviceUidKey, uid);
    }
    return uid;
  }

  String _rand4() =>
      (1000 + (DateTime.now().microsecondsSinceEpoch % 9000)).toString();

  bool get configured => MbConfig.adminApiConfigured;

  /// Push the user profile (+ current FCM token) to the worker.
  /// Fire-and-forget: returns true on success, false silently on failure.
  Future<bool> sync({
    String? uid,
    String? email,
    String? name,
    String? photoUrl,
    String? fcmToken,
  }) async {
    if (!configured) return false;
    try {
      final deviceUid_ = uid ?? await deviceUid();
      final body = jsonEncode({
        'uid': deviceUid_,
        'email': email ?? '',
        'name': name ?? '',
        if (photoUrl != null && photoUrl.isNotEmpty) 'photoUrl': photoUrl,
        'fcmToken': fcmToken ?? '',
        'platform': Platform.isIOS ? 'ios' : 'android',
        'appVersion': MbConfig.appVersion,
      });
      final res = await http
          .post(
            Uri.parse('${MbConfig.adminApiBaseUrl}/api/v1/users/sync'),
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 8));
      final ok = res.statusCode == 200;
      if (ok) {
        final prefs = await _prefs_();
        await prefs.setInt(
            'userSyncedAt', DateTime.now().millisecondsSinceEpoch);
      }
      return ok;
    } catch (e) {
      debugPrint('MbUserSyncService.sync: $e');
      return false;
    }
  }

  /// Convenience: reads the locally stored Google profile (or falls back to
  /// the guest device id) and syncs with the given FCM token.
  Future<bool> syncFromPrefs({String? fcmToken}) async {
    final prefs = await _prefs_();
    final googleUid = prefs.getString('googleUid');
    return sync(
      uid: googleUid,
      email: googleUid == null ? null : prefs.getString('googleEmail'),
      name: prefs.getString('googleName') ?? prefs.getString('userName'),
      photoUrl: prefs.getString('googlePhotoUrl'),
      fcmToken: fcmToken ?? prefs.getString('fcmToken'),
    );
  }
}
