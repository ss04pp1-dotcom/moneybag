/// Central build/runtime configuration for MoneyBag.
///
/// Keep user-tunable constants here so they are easy to find and patch.
/// >>> THE PRODUCTION CHECKLIST (see DEPLOY.md for the full guide) <<<
///   1. googleWebClientId   — Google OAuth Web Client ID (login + Drive)
///   2. adminApiBaseUrl     — Cloudflare Worker API URL (deployed in step 1)
///   3. google-services.json / GoogleService-Info.plist — Firebase files
///   4. AdMob App ID        — AndroidManifest.xml + iOS Info.plist
abstract final class MbConfig {
  /// Human-readable app version (keep in sync with pubspec `version`).
  static const String appVersion = '2.2.5';

  // ── 1. Google OAuth (login + Drive backup) ───────────────────────────────
  ///
  /// Create an OAuth client ID of type "Web application" at
  /// https://console.cloud.google.com/apis/credentials, add your Android
  /// app's SHA-1 under "Your Android apps", then paste the client ID below
  /// (ends with .apps.googleusercontent.com) and rebuild.
  /// Until replaced, the login/Drive screens show their setup guides and
  /// everything else works offline.
  static const String googleWebClientId =
      '702659070321-ddl72tj76hic3v9kquv8g9d0fjmra7k7.apps.googleusercontent.com';

  /// True until the placeholder client ID above is replaced.
  static bool get driveConfigured =>
      !googleWebClientId.startsWith('PASTE_YOUR');

  // ── 2. Admin API (Cloudflare Worker) ─────────────────────────────────────
  ///
  /// THE single hardcoded API URL — every network call in the app (remote
  /// config, ads, announcements, user sync, push registration) goes through
  /// this one constant. There is NO in-app setting for it by design.
  ///
  /// Deploy moneybag-cloudflare/worker first (see moneybag-cloudflare/worker/
  /// README.md), then paste your Worker URL here, e.g.:
  ///   'https://moneybag-api.your-name.workers.dev'
  ///
  /// The app is offline-first: while this points at an unreachable URL (or
  /// the placeholder below), every local feature keeps working and cached
  /// remote values (ads/announcements) keep applying.
  static const String adminApiBaseUrl =
      'https://moneybag-api.salman61902.workers.dev';

  /// True while the URL is still the placeholder.
  static bool get adminApiConfigured =>
      !adminApiBaseUrl.contains('YOUR-SUBDOMAIN');

  // ── 4. AdMob defaults (used until the Admin API overrides them) ──────────
  ///
  /// Google's OFFICIAL TEST ids — safe to ship. Replace the app id in
  /// android/app/src/main/AndroidManifest.xml (com.google.android.gms.ads
  /// .APPLICATION_ID) and ios/Runner/Info.plist (GADApplicationIdentifier)
  /// with your real AdMob App ID, then enable ads from the admin panel.
  static const String admobTestAppId =
      'ca-app-pub-3940256099942544~3347511713';
  static const String admobTestBannerUnitId =
      'ca-app-pub-3940256099942544/6300978111';
  static const String admobTestInterstitialUnitId =
      'ca-app-pub-3940256099942544/1033173712';
  static const String admobTestRewardedUnitId =
      'ca-app-pub-3940256099942544/5224354917';
}
