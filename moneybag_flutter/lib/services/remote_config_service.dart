import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/config.dart';

/// Announcement pushed from the admin panel.
class MbAnnouncement {
  final String id;
  final String title;
  final String body;
  final String kind; // info | update | promo

  const MbAnnouncement({
    required this.id,
    required this.title,
    required this.body,
    required this.kind,
  });

  factory MbAnnouncement.fromJson(Map<String, dynamic> j) => MbAnnouncement(
        id: '${j['id'] ?? ''}',
        title: '${j['title'] ?? ''}',
        body: '${j['body'] ?? ''}',
        kind: '${j['kind'] ?? 'info'}',
      );
}

/// Snapshot of everything the admin panel controls.
class MbRemoteConfig {
  final bool adsEnabled;
  final bool adsTestMode;
  final String bannerUnitId;
  final String interstitialUnitId;
  final String rewardedUnitId;
  final List<MbAnnouncement> announcements;
  final MbAnnouncement? announcement; // first active — dashboard card
  final String? minVersion;
  final bool forceUpdate;
  final bool maintenance;
  final String? messageTitle;
  final String? messageBody;

  const MbRemoteConfig({
    this.adsEnabled = false,
    this.adsTestMode = true,
    this.bannerUnitId = '',
    this.interstitialUnitId = '',
    this.rewardedUnitId = '',
    this.announcements = const [],
    this.announcement,
    this.minVersion,
    this.forceUpdate = false,
    this.maintenance = false,
    this.messageTitle,
    this.messageBody,
  });

  factory MbRemoteConfig.fromJson(Map<String, dynamic> j) {
    final ads = (j['ads'] is Map) ? j['ads'] as Map<String, dynamic> : const {};
    final cfg = (j['config'] is Map) ? j['config'] as Map<String, dynamic> : const {};
    final annsRaw =
        (j['announcements'] is List) ? j['announcements'] as List : const [];
    final anns = [
      for (final a in annsRaw)
        if (a is Map<String, dynamic>) MbAnnouncement.fromJson(a),
    ];
    final msg = (cfg['message'] is Map) ? cfg['message'] as Map<String, dynamic> : null;
    return MbRemoteConfig(
      adsEnabled: ads['enabled'] == true,
      adsTestMode: ads['testMode'] != false,
      bannerUnitId: '${ads['bannerUnitId'] ?? ''}',
      interstitialUnitId: '${ads['interstitialUnitId'] ?? ''}',
      rewardedUnitId: '${ads['rewardedUnitId'] ?? ''}',
      announcements: anns,
      announcement: anns.isEmpty ? null : anns.first,
      minVersion: cfg['minVersion'] == null ? null : '${cfg['minVersion']}',
      forceUpdate: cfg['forceUpdate'] == true,
      maintenance: cfg['maintenance'] == true,
      messageTitle: msg == null ? null : '${msg['title'] ?? ''}',
      messageBody: msg == null ? null : '${msg['body'] ?? ''}',
    );
  }
}

/// Talks to the MoneyBag Admin API — the Cloudflare Worker
/// (moneybag-cloudflare/worker).
///
/// The API base URL is ONE hardcoded constant: [MbConfig.adminApiBaseUrl].
/// There is deliberately NO in-app setting for it.
///
/// Offline-first: the app works 100% without a server. It fetches
/// `/api/v1/app` once per launch (plus whenever an FCM push arrives), caches
/// the result, and uses it to control announcements, AdMob ads and update
/// notices. If the server is unreachable, the last cached snapshot keeps
/// working.
class MbRemoteConfigService extends ChangeNotifier {
  MbRemoteConfigService._();
  static final MbRemoteConfigService instance = MbRemoteConfigService._();

  SharedPreferences? _prefs;

  /// The one and only API base URL (normalized, no trailing slash).
  late final String baseUrl = _normalize(MbConfig.adminApiBaseUrl);

  MbRemoteConfig? _config;
  String? _dismissedId;
  DateTime? lastFetchAt;
  bool get connected => lastFetchAt != null && _lastFetchOk;

  bool _lastFetchOk = false;
  bool _fetching = false;

  MbRemoteConfig? get config => _config;

  /// Announcement currently visible (not dismissed).
  MbAnnouncement? get activeAnnouncement {
    final a = _config?.announcement;
    if (a == null || a.id.isEmpty || a.id == _dismissedId) return null;
    return a;
  }

  /// All active announcements (notification center list).
  List<MbAnnouncement> get announcements => _config?.announcements ?? const [];

  /// Loads the cached config, then refreshes from the server
  /// (fire-and-forget — never blocks the app).
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _dismissedId = _prefs!.getString('dismissedAnnouncementId');
    final cached = _prefs!.getString('remoteConfigCache');
    if (cached != null) {
      try {
        _config = MbRemoteConfig.fromJson(
            jsonDecode(cached) as Map<String, dynamic>);
      } catch (_) {}
    }
    notifyListeners();
    if (MbConfig.adminApiConfigured) unawaited(refresh());
  }

  String _normalize(String url) {
    var u = url.trim();
    if (!u.startsWith('http://') && !u.startsWith('https://')) {
      u = 'https://$u';
    }
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    return u;
  }

  /// Fetches the latest config. Returns true on success.
  Future<bool> refresh() async {
    if (!MbConfig.adminApiConfigured || _fetching) return false;
    _fetching = true;
    try {
      final res = await http
          .get(
            Uri.parse('$baseUrl/api/v1/app'),
            headers: {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        if (data is Map<String, dynamic>) {
          _config = MbRemoteConfig.fromJson(data);
          lastFetchAt = DateTime.now();
          _lastFetchOk = true;
          await _prefs?.setString('remoteConfigCache', jsonEncode(data));
          _fetching = false;
          notifyListeners();
          return true;
        }
      }
    } catch (e) {
      debugPrint('MbRemoteConfigService.refresh: $e');
    }
    _lastFetchOk = false;
    _fetching = false;
    notifyListeners();
    return false;
  }

  void dismissCurrentAnnouncement() {
    final a = _config?.announcement;
    if (a == null || a.id.isEmpty) return;
    _dismissedId = a.id;
    _prefs?.setString('dismissedAnnouncementId', a.id);
    notifyListeners();
  }
}
