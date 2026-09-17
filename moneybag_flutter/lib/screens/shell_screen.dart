import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/palette.dart';
import '../state/app_state.dart';
import '../widgets/animations.dart';
import '../widgets/common.dart';
import '../widgets/whats_new.dart';
import '../services/ads_service.dart';
import '../services/remote_config_service.dart';
import '../core/l10n.dart';
import 'analytics_screen.dart';
import 'budget_screen.dart';
import 'dashboard_screen.dart';
import 'profile_screen.dart';
import 'savings_screen.dart';
import 'transaction_edit_screen.dart';
import 'transactions_screen.dart';

// v2.2.5: tracks when the user RETURNS to the shell route from a pushed
// page (tx editor, analytics, settings…). RouteObserver only sees page
// routes — dialogs don't count — so pending popups can fire the instant
// the shell is visible again instead of idling out a retry cycle.
final RouteObserver<PageRoute> mbShellRouteObserver =
    RouteObserver<PageRoute>();

/// App shell — 5-slot bottom navigation with the center + FAB
/// (Home | Transactions | + | Budget | Profile), per the UI/UX spec.
class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen>
    with WidgetsBindingObserver, RouteAware {
  // Index of the active nav SLOT (0..4). The pages list below mirrors the
  // 5-slot layout 1:1 — the center slot (2) is the FAB placeholder and is
  // never selectable, but keeping it here makes slot→page mapping direct
  // and impossible to desynchronize (which previously caused a RangeError
  // blank screen on the Profile tab).
  int _index = 0;

  // ── v2.2.5 ads popup system (user-tuned) ──
  // ENTRY: the popup appears RIGHT AFTER the app-open ad closes (an
  //   ~800 ms beat so the shell settles) — a 12 s fallback timer covers
  //   the case where no app-open ad played at all. When the ad finished
  //   BEFORE the shell was even mounted (biometric lock gate still up,
  //   splash still playing — the hook couldn't fire), the service's
  //   appOpenAdFinishedAt timestamp lets the shell catch up with the
  //   same ~800 ms beat on mount.
  //   • the day's FIRST open  → SUPPORT popup (once per calendar day);
  //     the ad-free offer follows ~2 s after it closes
  //   • any other open        → the ad-free offer directly
  // PERIODIC: while the app stays open, every 10 minutes another ad-free
  //   offer — never while an ad-free period is already active, and never
  //   while ads are disabled entirely. A popup that would land on a busy
  //   moment (dialog up, app-open ad on screen, pushed route) fires the
  //   moment the user is back on the shell (RouteObserver didPopNext) or
  //   retries a minute later — it never silently disappears.
  static const _entryPopupDelay = Duration(seconds: 12);
  static const _adDismissPopupDelay = Duration(milliseconds: 800);
  static const _supportFollowUpDelay = Duration(seconds: 2);
  static const _periodicPopupEvery = Duration(minutes: 10);
  static const _popupRetryDelay = Duration(minutes: 1);
  static const _popupRetryWhileAdShowing = Duration(seconds: 5);
  static const _reentryThreshold = Duration(minutes: 2);
  static const _offerReposeAfterDismiss = Duration(seconds: 60);
  static const _supportPopupDayKey = 'supportPopupLastDay';

  // v2.2.5 hotfix: how long after an app-open ad finished a
  // late-mounting shell still treats it as "just closed" (lock gate,
  // splash) and plays the immediate ~800 ms entry beat.
  static const _adFinishCatchupWindow = Duration(minutes: 2);

  // v2.2.5 (user-tuned) penalty: cancel the offer or cut the rewarded ad
  // → interstitials start coming "একটু পর পর" — first after 1 minute, then
  // every 2 minutes — until the user finally watches one for 30 ad-free
  // minutes (or ads are turned off remotely).
  static const _interstitialFirstDelay = Duration(minutes: 1);
  static const _interstitialEvery = Duration(minutes: 2);
  Timer? _entryPopupTimer;
  Timer? _afterSupportTimer;
  Timer? _periodicPopupTimer;
  Timer? _offerRetryTimer;
  Timer? _penaltyInterstitialTimer;
  bool _dialogShowing = false;
  bool _entryPopupFired = false;

  /// v2.2.5 hotfix: an ad-finish beat is pending (the hook fired and the
  /// 800 ms timer is armed). The lifecycle `resumed` handler and the
  /// hook race on every ad dismiss — without this flag, `resumed` kept
  /// re-arming the slow fallback on top of the beat, and the "ad closes
  /// → popup" promise silently degraded to "…30 s later".
  bool _entryPopupAdBeat = false;
  bool _penaltyActive = false;
  bool _offerWatchPressed = false;
  DateTime? _pausedAt;
  DateTime? _lastOfferClosedAt;

  // v2.2.5 hotfix: MbAdsService is a singleton (MbAdsService.instance) and is
  // NOT registered in the provider tree — only MbAppState is. The previous
  // `context.read<MbAdsService>()` calls threw ProviderNotFoundException
  // inside the timer callback, which release builds swallow silently, so
  // the popup NEVER appeared. Always go through .instance (as profile_screen
  // and ad_banner.dart do).
  int _entryConfigRetries = 0;

  static const _pages = <Widget>[
    DashboardScreen(key: ValueKey('dashboard')),
    TransactionsScreen(key: ValueKey('transactions')),
    SizedBox.shrink(key: ValueKey('fab-slot')),
    BudgetScreen(key: ValueKey('budget')),
    ProfileScreen(key: ValueKey('profile')),
  ];

  // Analytics & Savings are reached from Dashboard shortcuts and kept alive
  // as pushed routes; bottom nav sticks to the 5 spec'd slots.

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // v2.2.5: when the app-open ad finishes, the entry popup shows RIGHT
    // THEN (a beat later) instead of waiting out the 12 s fallback.
    MbAdsService.instance.onAppOpenAdFinished = _onAppOpenAdFinished;
    // v2.1.1: greet existing users with the "What's New" guide exactly once
    // per version — AFTER the shell has rendered so the dialog can never be
    // swallowed by the splash→shell AnimatedSwitcher transition.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final state = context.read<MbAppState>();
      if (state.onboarded && state.introDone) {
        // v2.2.5 hotfix: await the dialog — the entry popup queues behind
        // What's New instead of dying in the busy-retry loop.
        await showWhatsNewIfNeeded(context, state);
      }
      if (!mounted) return;
      _scheduleEntryPopup();
      final route = ModalRoute.of(context);
      if (route is PageRoute) mbShellRouteObserver.subscribe(this, route);
    });
    _startPeriodicPopupTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    mbShellRouteObserver.unsubscribe(this);
    MbAdsService.instance.onAppOpenAdFinished = null;
    _entryPopupTimer?.cancel();
    _afterSupportTimer?.cancel();
    _periodicPopupTimer?.cancel();
    _offerRetryTimer?.cancel();
    _penaltyInterstitialTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // A real re-entry (away longer than 2 minutes) re-arms the entry
      // popup; a quick app-switch never nags twice in a row.
      final away = _pausedAt == null
          ? Duration.zero
          : DateTime.now().difference(_pausedAt!);
      if (away > _reentryThreshold) _entryPopupFired = false;
      // The ad-finish beat (800 ms) must NOT be clobbered by the fallback
      // re-arm — the hook and this handler race on every ad dismiss, and
      // the beat is the user-visible promise "ad closes → popup".
      if (!_entryPopupAdBeat) _scheduleEntryPopup();
      _startPeriodicPopupTimer();
      if (_penaltyActive) _schedulePenaltyTick();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _pausedAt = DateTime.now();
      _entryPopupTimer?.cancel();
      _afterSupportTimer?.cancel();
      _periodicPopupTimer?.cancel();
      _offerRetryTimer?.cancel();
      _penaltyInterstitialTimer?.cancel();
    }
    // `inactive` is deliberately NOT handled: it fires transiently while a
    // full-screen ad overlay is up (and for permission prompts / app
    // switcher peeks). Canceling the timers there used to kill the 800 ms
    // ad-finish beat mid-flight — every due callback re-checks busy state
    // itself, so letting the timers ride through `inactive` is safe.
  }

  /// v2.2.5 hotfix: the user just came BACK to the shell from a pushed
  /// route (tx editor, analytics, notification settings…). A popup that
  /// was waiting for exactly that moment fires right away instead of
  /// idling out its retry cycle in the background — this was the main
  /// "popup never showed" report: the entry popup came due while the
  /// user was already deep in a settings screen.
  @override
  void didPopNext() {
    if (!mounted) return;
    if (!_entryPopupFired) {
      _entryPopupTimer?.cancel();
      _entryPopupTimer = Timer(_adDismissPopupDelay, _onEntryPopupDue);
    }
    if (_offerRetryTimer != null && _offerRetryTimer!.isActive) {
      _offerRetryTimer?.cancel();
      _offerRetryTimer = Timer(const Duration(seconds: 1), () {
        if (mounted) _showAdFreeOffer();
      });
    }
  }

  // ── popup scheduling ────────────────────────────────────────────────────

  /// The app-open ad just finished (dismissed / failed to show): the
  /// entry popup fires right now — ~800 ms after the full-screen ad is
  /// gone — instead of waiting out the 12 s fallback timer.
  void _onAppOpenAdFinished() {
    if (!mounted || _entryPopupFired) return;
    _entryPopupAdBeat = true;
    _entryPopupTimer?.cancel();
    _entryPopupTimer = Timer(_adDismissPopupDelay, _onEntryPopupDue);
  }

  /// Arms the entry popup fallback (skipped when it already fired during
  /// this foreground session; replaced whenever the app-open ad finishes
  /// earlier via [_onAppOpenAdFinished]).
  ///
  /// v2.2.5 hotfix: when an app-open ad finished a moment ago while this
  /// shell was NOT mounted (biometric lock gate still up, splash still
  /// playing — the hook fires only into a live shell), the beat is caught
  /// up here: ad closed recently → popup in ~800 ms, not the slow path.
  void _scheduleEntryPopup() {
    if (_entryPopupFired) return;
    _entryPopupTimer?.cancel();
    final finishedAt = MbAdsService.instance.appOpenAdFinishedAt;
    final recentAd = finishedAt != null &&
        DateTime.now().difference(finishedAt) < _adFinishCatchupWindow;
    _entryPopupTimer = Timer(
      recentAd ? _adDismissPopupDelay : _entryPopupDelay,
      _onEntryPopupDue,
    );
  }

  /// Fires ~12 s after entry (or immediately after the app-open ad
  /// finishes). If the moment is busy (a dialog is up or the user is
  /// inside a pushed route) it retries a minute later — or fires the
  /// moment the user pops back onto the shell — so the popup still
  /// arrives — it never silently disappears.
  void _onEntryPopupDue() {
    if (!mounted || _entryPopupFired) return;
    _entryPopupAdBeat = false; // beat consumed
    final ads = MbAdsService.instance;
    // First-ever launch: the remote config fetch may still be in flight (no
    // cached snapshot yet, config == null). Retry a minute later instead of
    // dropping the popup for the whole session — capped at 3 retries so an
    // offline device doesn't spin forever (ads need network anyway).
    if (!ads.adsEnabled &&
        MbRemoteConfigService.instance.config == null &&
        _entryConfigRetries < 3) {
      _entryConfigRetries++;
      _entryPopupTimer = Timer(_popupRetryDelay, _onEntryPopupDue);
      return;
    }
    if (!ads.adsEnabled) return;
    // The app-open ad still covers the screen — re-check shortly; the
    // dismiss hook will usually beat this timer anyway.
    if (ads.isShowingFullScreenAd) {
      _entryPopupTimer = Timer(_popupRetryWhileAdShowing, _onEntryPopupDue);
      return;
    }
    if (_dialogShowing || !_shellIsVisible()) {
      _entryPopupTimer = Timer(_popupRetryDelay, _onEntryPopupDue);
      return;
    }
    _entryPopupFired = true;
    _showDailyPopup();
  }

  /// The day's first open gets the SUPPORT popup (once per calendar day —
  /// no cooldown math, no coin flip: 100% predictable). Every later open
  /// goes straight to the 30-minute ad-free offer.
  Future<void> _showDailyPopup() async {
    final ads = MbAdsService.instance;
    if (!ads.adsEnabled) return;
    final prefs = await SharedPreferences.getInstance();
    final today = _dayKey(DateTime.now());
    if (prefs.getString(_supportPopupDayKey) == today) {
      _showAdFreeOffer();
      return;
    }
    // v2.2.5 hotfix: mark the day ONLY when the dialog can actually still
    // show — the old order burned the once-a-day slot on an unmounted
    // shell, and the support popup then never came for the rest of the day.
    if (!mounted) return;
    await prefs.setString(_supportPopupDayKey, today);
    _showSupportPopup(onClosed: () {
      // v2.2.5 (user-tuned): the ad-free offer follows ~2 s after the
      // support popup closes — right away, never stacked on top of it.
      _afterSupportTimer?.cancel();
      _afterSupportTimer = Timer(_supportFollowUpDelay, () {
        if (mounted) _showAdFreeOffer();
      });
    });
  }

  void _startPeriodicPopupTimer() {
    _periodicPopupTimer?.cancel();
    _periodicPopupTimer = Timer.periodic(
      _periodicPopupEvery,
      (_) => _showAdFreeOffer(),
    );
  }

  /// True while the shell itself is the visible screen — popups must never
  /// interrupt a pushed route (tx editor, goal detail, lock screen…).
  bool _shellIsVisible() {
    final route = ModalRoute.of(context);
    return route == null || route.isCurrent;
  }

  String _dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // ── the two dialogs ─────────────────────────────────────────────────────

  /// The daily SUPPORT dialog — "support the app by watching one rewarded
  /// ad" (grant: 30 minutes ad-free, see MbAdsService._grantAdFree).
  /// Dismissal is always allowed — the popup is a request, never a wall.
  void _showSupportPopup({VoidCallback? onClosed}) {
    if (_dialogShowing) return;
    _dialogShowing = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final L = ctx.L;
        final ads = MbAdsService.instance;
        return AlertDialog(
          title: Text(L.maintenancePopupTitle),
          content: Text(L.maintenancePopupBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(L.cancel),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                final earned = await ads.showRewarded();
                _onRewardResult(earned);
              },
              child: Text(L.rewardedWatch),
            ),
          ],
        );
      },
    ).then((_) {
      _dialogShowing = false;
      onClosed?.call();
    });
  }

  /// The ad-free offer — one rewarded ad buys 30 minutes without ads.
  /// Quietly skipped while ads are off or an ad-free period is running.
  /// A busy moment (dialog up, app-open ad on screen, pushed route)
  /// retries a minute later so the offer never silently disappears; a
  /// just-dismissed offer gets a 60 s breather first.
  void _showAdFreeOffer() {
    if (!mounted) return;
    final ads = MbAdsService.instance;
    if (!ads.adsEnabled || ads.adFreeActive) return;
    if (_lastOfferClosedAt != null &&
        DateTime.now().difference(_lastOfferClosedAt!) <
            _offerReposeAfterDismiss) {
      return;
    }
    if (_dialogShowing || ads.isShowingFullScreenAd || !_shellIsVisible()) {
      _offerRetryTimer?.cancel();
      _offerRetryTimer = Timer(_popupRetryDelay, _showAdFreeOffer);
      return;
    }
    _offerRetryTimer?.cancel();
    _dialogShowing = true;
    _offerWatchPressed = false;
    showDialog(
      context: context,
      // v2.2.5 (user request): the offer is always dismissible — tapping
      // outside cancels it too, never a wall.
      barrierDismissible: true,
      builder: (ctx) {
        final L = ctx.L;
        final ads = MbAdsService.instance;
        return AlertDialog(
          title: Text(L.rewardedTitle),
          content: Text(L.rewardedBody),
          actions: [
            // Prominent, bordered cancel — impossible to miss.
            OutlinedButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(L.cancel),
            ),
            FilledButton(
              onPressed: () async {
                _offerWatchPressed = true;
                Navigator.of(ctx).pop();
                final earned = await ads.showRewarded();
                _onRewardResult(earned);
                // Cut the rewarded ad midway (earned == false) — same
                // stubborn behaviour as cancelling: interstitials begin.
                if (mounted && !earned) _startPenaltyInterstitials();
              },
              child: Text(L.rewardedWatch),
            ),
          ],
        );
      },
    ).then((_) {
      _dialogShowing = false;
      _lastOfferClosedAt = DateTime.now();
      // Cancelled without even trying (button or outside tap) → the
      // penalty interstitials start coming "একটু পর পর".
      if (mounted && !_offerWatchPressed) _startPenaltyInterstitials();
    });
  }

  // ── penalty interstitials ("ঘাড়া" users) ──────────────────────────────

  /// Starts the penalty cadence — an interstitial ~1 minute after the
  /// refusal, then every 2 minutes. Stops itself when the user finally
  /// earns an ad-free period or ads are turned off.
  void _startPenaltyInterstitials() {
    if (_penaltyActive) return;
    _penaltyActive = true;
    _schedulePenaltyTick(first: true);
  }

  void _schedulePenaltyTick({bool first = false}) {
    _penaltyInterstitialTimer?.cancel();
    _penaltyInterstitialTimer = Timer(
      first ? _interstitialFirstDelay : _interstitialEvery,
      () {
        if (!_penaltyActive) return;
        unawaited(_tryShowPenaltyInterstitial());
        if (_penaltyActive) _schedulePenaltyTick();
      },
    );
  }

  void _stopPenaltyInterstitials() {
    _penaltyActive = false;
    _penaltyInterstitialTimer?.cancel();
    _penaltyInterstitialTimer = null;
  }

  Future<void> _tryShowPenaltyInterstitial() async {
    if (!mounted || !_penaltyActive) return;
    final ads = MbAdsService.instance;
    // The user finally watched an ad (ad-free running) or ads are off —
    // the penalty has done its job.
    if (!ads.adsEnabled || ads.adFreeActive) {
      _stopPenaltyInterstitials();
      return;
    }
    // Busy right now (dialog, full-screen ad, pushed route) — the next
    // tick retries; the interstitial never interrupts the tx editor etc.
    if (_dialogShowing || ads.isShowingFullScreenAd || !_shellIsVisible()) {
      return;
    }
    await ads.showInterstitial();
  }

  void _onRewardResult(bool earned) {
    // Watching one ad for 30 ad-free minutes also ends the penalty —
    // that was the whole deal.
    if (earned) _stopPenaltyInterstitials();
    if (!mounted) return;
    final L = context.L;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(earned ? L.rewardedGranted : L.rewardedFailed)),
    );
  }

  void _openAdd() {
    MbNav.push(context, const TransactionEditScreen(), fullscreenDialog: true);
  }

  @override
  Widget build(BuildContext context) {
    final L = context.L;
    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _index != 0) {
          setState(() => _index = 0);
        }
      },
      child: Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: _pages[_index],
      ),
      floatingActionButton: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 480),
        curve: Curves.easeOutBack,
        builder: (context, v, child) => Transform.scale(
          scale: 0.55 + 0.45 * v,
          alignment: Alignment.bottomCenter,
          child: child,
        ),
        child: MbPressable(
          pressedScale: 0.92,
          onTap: _openAdd,
          child: Container(
            key: const ValueKey('mb-fab'),
            width: 62,
            height: 62,
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [MbPalette.green, MbPalette.greenDark],
              ),
              boxShadow: [
                BoxShadow(
                  color: MbPalette.green.withOpacity(0.35),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Material(
              color: Colors.transparent,
              child: Icon(Icons.add_rounded, color: Color(0xFF06130C), size: 32),
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _MbNavBar(
        index: _index,
        onChanged: (i) => setState(() => _index = i),
        onAdd: _openAdd,
        items: [
          _MbNavItem(icon: Icons.home_rounded, label: L.navHome),
          _MbNavItem(
              icon: Icons.receipt_long_rounded, label: L.navTransactions),
          const _MbNavItem(icon: null, label: ''),
          _MbNavItem(icon: Icons.savings_rounded, label: L.navBudget),
          _MbNavItem(icon: Icons.person_rounded, label: L.navProfile),
        ],
      ),
    ),
    );
  }
}

/// Navigates to Analytics (reachable from dashboard insights card).
void openAnalytics(BuildContext context) {
  MbNav.push(context, const AnalyticsScreen());
}

/// Navigates to Savings/Goals.
void openSavings(BuildContext context) {
  MbNav.push(context, const SavingsScreen());
}

class _MbNavItem {
  final IconData? icon;
  final String label;
  const _MbNavItem({required this.icon, required this.label});
}

class _MbNavBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;
  final VoidCallback onAdd;
  final List<_MbNavItem> items;

  const _MbNavBar({
    required this.index,
    required this.onChanged,
    required this.onAdd,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bottom = MediaQuery.of(context).padding.bottom;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 68 + bottom,
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: items[i].icon == null
                      ? const SizedBox.shrink()
                      : _navItem(context, items[i], i),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(BuildContext context, _MbNavItem item, int i) {
    final scheme = Theme.of(context).colorScheme;
    final selected = i == index;
    final color = selected ? MbPalette.green : scheme.onSurfaceVariant;
    return InkWell(
      onTap: () => onChanged(i),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon sits on a soft highlight pill that fades/scales in when
          // selected (restored 1.3.x detail); the icon itself springs up.
          TweenAnimationBuilder<double>(
            tween: Tween(begin: selected ? 0.7 : 1, end: selected ? 1.12 : 1),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutBack,
            builder: (context, v, _) => Transform.scale(
              scale: v,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // highlight pill
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 320),
                    curve: Curves.easeOutCubic,
                    width: 44,
                    height: 30,
                    decoration: BoxDecoration(
                      color: selected
                          ? MbPalette.green.withOpacity(0.16)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  SizedBox(
                    height: 26,
                    child: Icon(item.icon, color: color, size: 26),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 3),
          // FittedBox keeps the label inside the nav slot at any text scale.
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              item.label,
              style: TextStyle(
                fontFamily: 'NotoSansBengali',
                fontSize: 11.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
