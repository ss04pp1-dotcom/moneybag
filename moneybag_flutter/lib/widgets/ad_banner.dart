import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../services/ads_service.dart';
import '../services/remote_config_service.dart';
import 'common.dart';

/// AdMob banner — real ads, remote-controlled.
///
/// • The google_mobile_ads SDK ships inside the app, but it stays completely
///   dormant until the Admin API turns `ads.enabled` on.
/// • Unit ids come from the Admin API at runtime (Google's official TEST ids
///   are the fallback — safe, policy-compliant).
/// • Any load failure degrades to an invisible widget: the dashboard never
///   shows a broken slot.
class MbAdBanner extends StatefulWidget {
  const MbAdBanner({super.key});

  @override
  State<MbAdBanner> createState() => _MbAdBannerState();
}

class _MbAdBannerState extends State<MbAdBanner> {
  BannerAd? _ad;
  bool _loaded = false;
  bool _loading = false;
  int _attempts = 0;
  static bool _sdkInitialized = false;

  @override
  void initState() {
    super.initState();
    _maybeLoad();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  String get _unitId {
    // v2.2.0: delegates to MbAdsService — single source of truth which now
    // ENFORCES the remote `ads.testMode` flag (test mode → Google test ids).
    return MbAdsService.instance.bannerUnitId;
  }

  Future<void> _maybeLoad() async {
    if (!mounted) return;
    final cfg = MbRemoteConfigService.instance.config;
    if (cfg == null || !cfg.adsEnabled || _loading || _ad != null) return;
    // Rewarded-ad-free period active → banner stays hidden.
    if (MbAdsService.instance.adFreeActive) return;
    if (_attempts >= 3) return; // fail safe: never spin on repeated errors
    if (!Platform.isAndroid && !Platform.isIOS) return;

    _loading = true;
    _attempts++;

    // Lazily initialize the SDK exactly once, only when ads are enabled.
    if (!_sdkInitialized) {
      try {
        await MobileAds.instance.initialize();
        _sdkInitialized = true;
      } catch (_) {
        if (mounted) setState(() => _loading = false);
        return;
      }
    }

    // Declared before initialization so the listener closures below can
    // legally reference `ad` (Dart forbids referencing a local variable
    // inside its own initializer). `late` is safe here: the listeners can
    // only fire after `ad.load()`, i.e. after the assignment below.
    late final BannerAd ad;
    ad = BannerAd(
      adUnitId: _unitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        // v5 has no BannerAd.isLoaded — the listener is the source of truth.
        //
        // v2.2.0 bugfix: the old flow assigned `_ad = ad` unconditionally
        // after `await ad.load()`, so after a LOAD FAILURE the disposed ad
        // object was stored back into `_ad` — `_ad != null` then blocked all
        // retries forever and State.dispose() disposed it a second time.
        // Now the ad is stored ONLY inside onAdLoaded and disposed ONLY in
        // onAdFailedToLoad / when the widget is already gone.
        onAdLoaded: (_) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() {
            _loaded = true;
            _loading = false;
            _ad = ad;
          });
        },
        onAdFailedToLoad: (failedAd, error) {
          failedAd.dispose();
          if (mounted) {
            setState(() {
              _loaded = false;
              _loading = false;
              _ad = null;
            });
          }
        },
      ),
    );

    await ad.load();
    // Both outcomes (success/failure) are handled by the listener above;
    // unmount during the load is covered by the `!mounted` branches.
  }

  @override
  Widget build(BuildContext context) {
    final L = context.L;
    final scheme = Theme.of(context).colorScheme;

    // React to config changes (admin flips ads on/off) and to rewarded
    // ad-free periods (30-min grants).
    return ListenableBuilder(
      listenable: Listenable.merge([
        MbRemoteConfigService.instance,
        MbAdsService.instance,
      ]),
      builder: (context, _) {
        final cfg = MbRemoteConfigService.instance.config;
        final enabled = cfg?.adsEnabled ?? false;
        final ad = _ad;

        // Config may arrive AFTER this widget was first built (admin turns
        // ads on remotely) — kick off a load as soon as that happens.
        if (enabled &&
            !MbAdsService.instance.adFreeActive &&
            ad == null &&
            !_loading) {
          scheduleMicrotask(_maybeLoad);
        }

        if (!enabled ||
            MbAdsService.instance.adFreeActive ||
            ad == null ||
            !_loaded) {
          return const SizedBox.shrink();
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              alignment: Alignment.center,
              margin: const EdgeInsets.only(bottom: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: scheme.onSurfaceVariant.withOpacity(0.08),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                L.adLabel,
                style: TextStyle(
                  fontFamily: 'NotoSansBengali',
                  fontSize: 9.5,
                  letterSpacing: 0.5,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            SizedBox(
              width: AdSize.banner.width.toDouble(),
              height: AdSize.banner.height.toDouble(),
              child: AdWidget(ad: ad),
            ),
          ],
        );
      },
    );
  }
}
