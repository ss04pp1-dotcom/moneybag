import 'dart:async';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/app_theme.dart';
import 'core/l10n.dart';
import 'core/palette.dart';
import 'screens/login_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/shell_screen.dart';
import 'services/ads_service.dart';
import 'services/auto_sync_service.dart';
import 'services/notification_service.dart';
import 'services/push_service.dart';
import 'services/remote_config_service.dart';
import 'services/widget_sync_service.dart';
import 'state/app_state.dart';
import 'widgets/app_logo.dart';
import 'widgets/lock_gate.dart';

/// Root widget: wires theme + language around [MaterialApp].
class MoneyBagApp extends StatelessWidget {
  const MoneyBagApp({super.key, required this.state});

  final MbAppState state;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        return L.wrapper(
          language: state.language,
          child: DynamicColorBuilder(
            // v2.1: Material You — on Android 12+ the app follows the
            // wallpaper palette; older devices keep the MoneyBag themes.
            builder: (lightDynamic, darkDynamic) {
              final lightTheme = lightDynamic != null
                  ? MbThemes.fromDynamic(lightDynamic.harmonized())
                  : MbThemes.light();
              final darkTheme = darkDynamic != null
                  ? MbThemes.fromDynamic(darkDynamic.harmonized())
                  : MbThemes.dark();
              return MaterialApp(
                title: 'মানিব্যাগ — MoneyBag',
                debugShowCheckedModeBanner: false,
                themeMode: state.themeMode,
                theme: lightTheme,
                darkTheme: darkTheme,
                home: MbLockGate(
                  state: state,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 420),
                    child: _homeFor(state),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  /// Boot order: intro splash → (onboarding → login → setup) | shell.
  Widget _homeFor(MbAppState state) {
    if (!state.ready || !state.introDone) {
      return _IntroSplash(state: state, key: const ValueKey('intro'));
    }
    if (!state.onboarded) {
      return const OnboardingScreen(key: ValueKey('onboarding'));
    }
    // One-time login offer (Google-only) — never shown again after the user
    // signs in, picks "continue without", or has already seen it once.
    if (!state.googleLinked && !state.loginSkipped && !state.loginSeen) {
      return const LoginScreen(key: ValueKey('login'));
    }
    return const ShellScreen(key: ValueKey('shell'));
  }
}

/// Animated branded splash — shown FIRST on every app open.
///
/// The native launch screen (logo on deep navy) hands over seamlessly to
/// this intro: the logo springs in, the name and tagline fade up, a glow
/// breathes. It waits for the state to boot AND a minimum of ~1.6 s before
/// revealing the app.
class _IntroSplash extends StatefulWidget {
  const _IntroSplash({super.key, required this.state});

  final MbAppState state;

  @override
  State<_IntroSplash> createState() => _IntroSplashState();
}

class _IntroSplashState extends State<_IntroSplash>
    with TickerProviderStateMixin {
  late final AnimationController _enter;
  late final AnimationController _glow;
  Timer? _timer;
  bool _timerDone = false;

  @override
  void initState() {
    super.initState();
    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    )..forward();
    _glow = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    widget.state.addListener(_onState);
    _timer = Timer(const Duration(milliseconds: 1650), () {
      _timerDone = true;
      _tryFinish();
    });
  }

  void _onState() => _tryFinish();

  void _tryFinish() {
    if (_timerDone && widget.state.ready) {
      widget.state.markIntroDone();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    widget.state.removeListener(_onState);
    _enter.dispose();
    _glow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF050914); // launch screen color — seamless handoff

    return Scaffold(
      backgroundColor: bg,
      body: Center(
        child: AnimatedBuilder(
          animation: _enter,
          builder: (context, _) {
            final t = _enter.value;
            final logoT = Curves.easeOutBack
                .transform((t.clamp(0.0, 1.0)).toDouble());
            final nameT = Curves.easeOutCubic
                .transform((((t - 0.30) / 0.45).clamp(0.0, 1.0)).toDouble());
            final tagT = Curves.easeOutCubic
                .transform((((t - 0.50) / 0.45).clamp(0.0, 1.0)).toDouble());

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── logo with breathing glow ──
                AnimatedBuilder(
                  animation: _glow,
                  builder: (context, child) => Container(
                    width: 108,
                    height: 108,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(32),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [MbPalette.green, MbPalette.greenDark],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: MbPalette.green
                              .withOpacity(0.22 + 0.18 * _glow.value),
                          blurRadius: 34 + 14 * _glow.value,
                          spreadRadius: 2 + 3 * _glow.value,
                        ),
                      ],
                    ),
                    child: child,
                  ),
                  child: Image.asset('assets/images/logo.png', width: 78, height: 78),
                )
                    .animateIn(
                      scale: 0.62 + 0.38 * logoT,
                      opacity: (t.clamp(0.0, 1.0)).toDouble(),
                    ),

                const SizedBox(height: 22),

                // ── app name ──
                Opacity(
                  opacity: nameT,
                  child: Transform.translate(
                    offset: Offset(0, 10 * (1 - nameT)),
                    child: const Text(
                      'মানিব্যাগ',
                      style: TextStyle(
                        fontFamily: 'NotoSansBengali',
                        color: MbPalette.darkText,
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),

                // ── tagline ──
                Opacity(
                  opacity: tagT,
                  child: Text(
                    L.stringsFor(widget.state.language).tagline,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'NotoSansBengali',
                      color: MbPalette.darkText.withOpacity(0.55),
                      fontSize: 12.5,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 34),

                // ── boot progress bar ──
                SizedBox(
                  width: 120,
                  height: 3,
                  child: LinearProgressIndicator(
                    value: t,
                    minHeight: 3,
                    backgroundColor: Colors.white.withOpacity(0.10),
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(MbPalette.green),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

extension _SplashFx on Widget {
  Widget animateIn({required double scale, required double opacity}) =>
      Transform.scale(
        scale: scale,
        child: Opacity(opacity: opacity, child: this),
      );
}

/// Boots [MbAppState] before showing the app.
class MoneyBagBootstrap extends StatefulWidget {
  const MoneyBagBootstrap({super.key});

  @override
  State<MoneyBagBootstrap> createState() => _MoneyBagBootstrapState();
}

class _MoneyBagBootstrapState extends State<MoneyBagBootstrap>
    with WidgetsBindingObserver {
  late final MbAppState _state;

  /// v2.2.0: a corrupt DB / prefs error inside init() used to leave the
  /// splash waiting forever (ready never flipped) and no service ever
  /// attached. Now the failure surfaces on a recovery screen instead.
  Object? _bootError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _state = MbAppState();
    unawaited(_boot());
  }

  Future<void> _boot() async {
    try {
      await _state.init();
    } catch (e) {
      if (mounted) setState(() => _bootError = e);
      return; // do NOT attach any service on a broken state
    }
    // Real system notifications: initialize, ask for permission ONCE
    // (first run after onboarding), and keep the two auto reminders
    // (daily + weekly) scheduled with current settings.
    await MbNotifications.instance.init();
    if (_state.onboarded) {
      unawaited(MbNotifications.instance.ensureAutoEnable(_state));
    }

    // Admin API (Cloudflare Worker): loads cached snapshot instantly,
    // then refreshes in the background — notices/ads appear non-blocking.
    await MbRemoteConfigService.instance.init();

    // v2: real-time FCM push + user/token registration on the Worker.
    unawaited(MbPushService.instance.init());

    // v2: auto Google Drive sync (backup listener + auto-restore).
    unawaited(MbAutoSyncService.instance.attach(_state));

    // v2: rewarded-ad ad-free state (24h grants).
    await MbAdsService.instance.loadAdFreeState();

    // Restore a previous Google session silently (if the user signed in).
    unawaited(_state.tryRestoreGoogleSession());

    // Preload AppOpenAd
    unawaited(MbAdsService.instance.loadAppOpenAd(showOnLoad: true));
  }

  Future<void> _retryBoot() async {
    setState(() => _bootError = null);
    await _boot();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) {
      // Back to foreground: missed-reminder catch-up + fresh remote state.
      unawaited(MbNotifications.instance.onAppResumed(_state));
      unawaited(MbRemoteConfigService.instance.refresh());
      // Show AppOpenAd
      MbAdsService.instance.showAppOpenAdIfAvailable();
      // v2.2.1: repaint the home screen widget. "Today's spend" goes stale
      // while the app sits in the background (day rollover), and OEM
      // launchers can drop the widget bind for sideloaded apps — one cheap
      // push on every resume keeps both problems away.
      unawaited(MbWidgetSyncService.push(_state));
    } else if (s == AppLifecycleState.paused) {
      // Leaving the app: push any pending auto-backup right now.
      unawaited(MbAutoSyncService.instance.flushOnPause());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _state.db.close();
    _state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final err = _bootError;
    if (err != null) {
      // Recovery path: retry first; reset only destroys data on purpose.
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
        home: Scaffold(
          backgroundColor: const Color(0xFF0D1F17),
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('⚠️', style: TextStyle(fontSize: 44)),
                    const SizedBox(height: 18),
                    const Text(
                      'Startup problem',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'The local database could not be opened. Retry usually '
                      'fixes a temporary file lock. Restarting the phone also '
                      'helps. Your data is not deleted.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.6), fontSize: 13),
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _retryBoot,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
    return ChangeNotifierProvider.value(
      value: _state,
      child: MoneyBagApp(state: _state),
    );
  }
}
