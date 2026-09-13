import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/config.dart';
import 'remote_config_service.dart';

/// AdMob ads — banner (dashboard) + interstitial + REWARDED.
///
/// • The google_mobile_ads SDK stays dormant until the Admin API turns
///   `ads.enabled` on (lazy init happens on the first ad request).
/// • Unit ids come from the Admin API at runtime; Google's official TEST
///   ids are the fallback — safe and policy-compliant.
/// • Rewarded: watching a full ad grants 24 hours of ad-free usage
///   (`adFreeUntil` persisted locally, banners suppressed while active).
class MbAdsService extends ChangeNotifier {
  MbAdsService._();
  static final MbAdsService instance = MbAdsService._();

  static bool _sdkInitialized = false;
  static const String _adFreeKey = 'adFreeUntil';

  RewardedAd? _rewardedAd;
  bool _rewardedBusy = false;


  DateTime? _adFreeUntil;

  AppOpenAd? _appOpenAd;
  bool _isShowingAd = false;
  DateTime? _appOpenLoadTime;

  bool get adsEnabled => MbRemoteConfigService.instance.config?.adsEnabled ?? false;

  DateTime? get adFreeUntil => _adFreeUntil;
  bool get adFreeActive {
    if (_adFreeUntil == null) return false;
    // Check if there is actually time remaining (minutes > 0)
    final mins = _adFreeUntil!.difference(DateTime.now()).inMinutes;
    return mins > 0;
  }

  /// Minutes of ad-free time remaining (0 when none).
  int get adFreeRemainingMins {
    if (!adFreeActive) return 0;
    final mins = _adFreeUntil!.difference(DateTime.now()).inMinutes;
    return mins <= 0 ? 0 : mins;
  }

  /// Whether the dashboard banner should be visible right now.
  bool get bannerVisible => adsEnabled && !adFreeActive;

  // ── unit ids (remote config → Google test fallback) ──────────────────────

  /// v2.2.0: `ads.testMode` from the Admin API is now ENFORCED. Previously
  /// the flag was parsed but ignored — with testMode ON and real unit IDs
  /// configured, the app served LIVE ads to test traffic (invalid traffic
  /// risk / AdMob policy). Test mode ON → always Google's official test ids.
  String _resolveUnit(String remoteId, String testId) {
    final cfg = MbRemoteConfigService.instance.config;
    final testMode = cfg?.adsTestMode ?? true;
    if (testMode) return testId;
    if (remoteId.startsWith('ca-app-pub-') && remoteId != testId) {
      return remoteId;
    }
    return testId;
  }

  String get appOpenUnitId => _resolveUnit(
        '', // We can add it to Remote Config later if needed, fallback to test for now
        MbConfig.admobTestAppOpenUnitId,
      );

  String get bannerUnitId => _resolveUnit(
        MbRemoteConfigService.instance.config?.bannerUnitId ?? '',
        MbConfig.admobTestBannerUnitId,
      );



  String get rewardedUnitId => _resolveUnit(
        MbRemoteConfigService.instance.config?.rewardedUnitId ?? '',
        MbConfig.admobTestRewardedUnitId,
      );

  // ── SDK init ─────────────────────────────────────────────────────────────

  Future<bool> ensureSdk() async {
    if (_sdkInitialized) return true;
    if (!Platform.isAndroid && !Platform.isIOS) return false;
    try {
      await MobileAds.instance.initialize();
      _sdkInitialized = true;
      return true;
    } catch (e) {
      debugPrint('MobileAds.initialize failed: $e');
      return false;
    }
  }

  Future<void> loadAdFreeState() async {
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt(_adFreeKey);
    _adFreeUntil = ms == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(ms);
    notifyListeners();
  }

  // ── rewarded: watch an ad → 24h ad-free ──────────────────────────────────

  /// Loads a rewarded ad if one isn't ready yet.
  Future<bool> _ensureRewardedLoaded() async {
    if (!adsEnabled) return false;
    if (_rewardedAd != null) return true;
    if (_rewardedBusy) return false;
    if (!await ensureSdk()) return false;

    _rewardedBusy = true;
    final completer = Completer<bool>();
    try {
      await RewardedAd.load(
        adUnitId: rewardedUnitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            _rewardedAd = ad;
            _rewardedBusy = false;
            if (!completer.isCompleted) completer.complete(true);
          },
          onAdFailedToLoad: (error) {
            debugPrint('RewardedAd failed: $error');
            _rewardedBusy = false;
            if (!completer.isCompleted) completer.complete(false);
          },
        ),
      );
    } catch (e) {
      debugPrint('RewardedAd.load threw: $e');
      _rewardedBusy = false;
      return false;
    }
    return completer.future;
  }

  /// Shows the rewarded ad. Returns true when the user EARNED the reward
  /// (watched it fully / tapped "মিস করেছি" at the end).
  Future<bool> showRewarded() async {
    if (!adsEnabled) return false;
    final loaded = await _ensureRewardedLoaded();
    final ad = _rewardedAd;
    if (!loaded || ad == null) return false;

    var earned = false;
    final done = Completer<bool>();

    ad.fullScreenContentCallback = FullScreenContentCallback<RewardedAd>(
      onAdDismissedFullScreenContent: (dismissedAd) {
        dismissedAd.dispose();
        _rewardedAd = null;
        if (earned) _grantAdFree();
        if (!done.isCompleted) done.complete(earned);
      },
      onAdFailedToShowFullScreenContent: (failedAd, error) {
        debugPrint('RewardedAd show failed: $error');
        failedAd.dispose();
        _rewardedAd = null;
        if (!done.isCompleted) done.complete(false);
      },
    );

    try {
      await ad.show(
        onUserEarnedReward: (shownAd, reward) {
          earned = true;
        },
      );
    } catch (e) {
      debugPrint('RewardedAd.show threw: $e');
      _rewardedAd = null;
      return false;
    }
    return done.future;
  }

  Future<void> _grantAdFree() async {
    _adFreeUntil = DateTime.now().add(const Duration(hours: 1));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
        _adFreeKey, _adFreeUntil!.millisecondsSinceEpoch);
    notifyListeners();
  }



  // ── app open ad ──────────────────────────────────────────────────────────

  Future<void> loadAppOpenAd({bool showOnLoad = false}) async {
    if (!adsEnabled || adFreeActive) return;
    if (!await ensureSdk()) return;
    AppOpenAd.load(
      adUnitId: appOpenUnitId,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          _appOpenLoadTime = DateTime.now();
          _appOpenAd = ad;
          if (showOnLoad) showAppOpenAdIfAvailable();
        },
        onAdFailedToLoad: (error) {
          debugPrint('AppOpenAd failed to load: $error');
        },
      ),
    );
  }

  bool get _isAdAvailable {
    return _appOpenAd != null && _appOpenLoadTime != null && 
        DateTime.now().subtract(const Duration(hours: 4)).isBefore(_appOpenLoadTime!);
  }

  void showAppOpenAdIfAvailable() {
    if (!adsEnabled || adFreeActive) {
      debugPrint('AppOpenAd not shown: Ads disabled or Ad-Free active');
      return;
    }
    if (!_isAdAvailable) {
      debugPrint('AppOpenAd not available, loading...');
      loadAppOpenAd();
      return;
    }
    if (_isShowingAd) {
      debugPrint('AppOpenAd already showing.');
      return;
    }

    _appOpenAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        _isShowingAd = true;
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        _isShowingAd = false;
        ad.dispose();
        _appOpenAd = null;
      },
      onAdDismissedFullScreenContent: (ad) {
        _isShowingAd = false;
        ad.dispose();
        _appOpenAd = null;
        loadAppOpenAd();
      },
    );

    _appOpenAd!.show();
  }

  @override
  void dispose() {
    _rewardedAd?.dispose();
    super.dispose();
  }
}
