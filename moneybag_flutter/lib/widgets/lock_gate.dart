import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

import '../core/app_theme.dart';
import '../core/palette.dart';
import '../state/app_state.dart';
import 'pin_pad.dart';

/// v2.2.0 — Biometric app lock with a guaranteed PIN fallback.
///
/// v2.1.0 shipped `biometricOnly: false` and trusted the system to offer
/// the device credential — but on many OEM devices (Xiaomi/Samsung/Oppo)
/// the BiometricPrompt NEVER shows a PIN option, so users were stuck with
/// fingerprint-only. This gate fixes that with three paths:
///
/// * fingerprint (primary, auto-prompted on cold start & resume);
/// * a 4-digit in-app backup PIN (set when the lock is enabled) — this
///   ALWAYS works, on every device, because it never leaves the app;
/// * the system credential prompt (kept via `biometricOnly: false`) for
///   devices that do support it.
///
/// v2.2.0 fail-closed rules: if the user has a backup PIN, ANY error or
/// missing-biometrics keeps the gate CLOSED (the PIN always unlocks it —
/// the user can never be locked out). The gate only fails OPEN when no
/// backup PIN exists, i.e. the lock is purely decorative biometrics on a
/// device that cannot even do biometrics — data access must survive over
/// a cosmetic lock. Brute force on the PIN pad is throttled with an
/// escalating cooldown (see [_onPinMaxAttempts]).
class MbLockGate extends StatefulWidget {
  const MbLockGate({super.key, required this.state, required this.child});

  final MbAppState state;
  final Widget child;

  @override
  State<MbLockGate> createState() => _MbLockGateState();
}

/// v2.1.2 — cold-start race fix.
///
/// v2.1.1 armed the gate in initState by reading `state.biometricLock` —
/// but the state object boots asynchronously (SharedPreferences + DB), so
/// on EVERY cold start the flag was still `false` at that instant. The
/// gate stayed open and killing/reopening the app skipped the lock
/// entirely. The fix: listen for boot completion and evaluate the
/// persisted flag exactly once, when `state.ready` flips true.
class _MbLockGateState extends State<MbLockGate>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  final LocalAuthentication _auth = LocalAuthentication();
  bool _checking = false;
  bool _available = true;
  bool _gateOpen = true;

  // v2.1.1: PIN keypad state.
  bool _pinSheetOpen = false;
  String? _inlineError; // e.g. biometric lockout notice

  /// v2.2.0: PIN brute-force throttle. The pin pad's own "5 attempts" was
  /// decorative when [MbPinPad.onMaxAttempts] was not wired — guessing could
  /// continue forever. Each exhaustion now adds an escalating cooldown.
  DateTime? _pinCooldownUntil;
  int _pinCooldownLevel = 0;

  /// v2.1.2: boot-phase lock evaluation runs exactly once.
  bool _bootLockEvaluated = false;

  late final AnimationController _enter;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    )..forward();
    // v2.1.2: re-evaluate when the async boot finishes — see
    // [_evaluateBootLock]. Also covers the rare case where the state had
    // already booted before this gate mounted.
    widget.state.addListener(_onStateChange);
    if (widget.state.ready) _evaluateBootLock();
  }

  @override
  void dispose() {
    widget.state.removeListener(_onStateChange);
    WidgetsBinding.instance.removeObserver(this);
    _enter.dispose();
    super.dispose();
  }

  /// Arms the lock exactly once, when the persisted flag has actually
  /// arrived from disk (boot finished).
  ///
  /// A flag that flips LATER — `ready == true` already — is the user
  /// toggling the switch inside settings; that must NOT lock them
  /// mid-session. It takes effect from the next backgrounding instead
  /// (see [didChangeAppLifecycleState]).
  void _evaluateBootLock() {
    if (_bootLockEvaluated) return;
    _bootLockEvaluated = true;
    if (widget.state.biometricLock) {
      _gateOpen = false;
      _verifyAvailable();
    }
  }

  void _onStateChange() {
    if (widget.state.ready) _evaluateBootLock();
  }

  Future<void> _verifyAvailable() async {
    var can = false;
    try {
      // The gate is meaningful when the device has ANY lock (biometric or
      // PIN/pattern) — either satisfies local_auth with biometricOnly:false.
      can = await _auth.isDeviceSupported() ||
          await _auth.canCheckBiometrics;
    } catch (_) {
      can = false;
    }
    if (!mounted) return;
    setState(() {
      if (can) {
        _available = true;
      } else if (widget.state.hasBackupPin) {
        // v2.2.0 fail-CLOSED: biometrics unavailable but the backup PIN is
        // set — the PIN path always unlocks, so the user is never locked out.
        _available = true;
        _gateOpen = false;
        _inlineError = widget.state.strings.lockFailed;
      } else {
        // No backup PIN and no device lock — a decorative lock must never
        // lock the user out of their money data.
        _available = false;
        _gateOpen = true;
      }
    });
    if (can && _gateOpen == false) {
      // Auto-prompt the fingerprint once the gate has rendered — banking
      // app behaviour. Small delay so the entry animation finishes and
      // the activity is fully resumed on cold start.
      Future.delayed(const Duration(milliseconds: 450), _tryAutoUnlock);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (!widget.state.biometricLock) return;
    if (s == AppLifecycleState.paused || s == AppLifecycleState.hidden) {
      // Leaving the app → arm the lock for the next resume.
      _gateOpen = false;
      _pinSheetOpen = false; // the keypad never survives a backgrounding
    } else if (s == AppLifecycleState.resumed && !_gateOpen) {
      // (Re)check device support in case biometrics were unenrolled.
      _verifyAvailable();
    }
  }

  /// Auto path (cold start / resume): silent when the user simply cancels —
  /// no SnackBar spam; both buttons remain available.
  Future<void> _tryAutoUnlock() async {
    if (!mounted || _gateOpen || _pinSheetOpen || _checking) return;
    await _tryUnlock(auto: true);
  }

  Future<void> _tryUnlock({bool auto = false}) async {
    if (_checking) return;
    setState(() {
      _checking = true;
      _inlineError = null;
    });
    try {
      final ok = await _auth.authenticate(
        localizedReason: widget.state.strings.lockSubtitle,
        options: const AuthenticationOptions(
          biometricOnly: false, // allow device PIN/pattern where supported
          stickyAuth: true, // resume if the app pauses mid-auth
          useErrorDialogs: true,
        ),
      );
      if (ok && mounted) {
        setState(() => _gateOpen = true);
      } else if (mounted && !auto) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.state.strings.lockFailed)),
        );
      }
    } catch (e) {
      // Hardware/OS refused (lockout, no lock screen, …).
      if (mounted) {
        if (auto) {
          setState(() => _inlineError = widget.state.strings.lockFailed);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(widget.state.strings.lockFailed)),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  // ── v2.1.1: backup PIN keypad ───────────────────────────────────────────

  void _openPinSheet() {
    final until = _pinCooldownUntil;
    if (until != null && DateTime.now().isBefore(until)) {
      // Cooldown still active — show the remaining seconds on the gate.
      final secs = until.difference(DateTime.now()).inSeconds;
      setState(
          () => _inlineError = '${widget.state.strings.pinWrong} · ${secs}s');
      return;
    }
    setState(() {
      _pinSheetOpen = true;
      _inlineError = null;
    });
  }

  void _closePinSheet() {
    setState(() => _pinSheetOpen = false);
  }

  /// v2.2.0: 5 wrong PINs → escalating cooldown (30s → 1m → 2m → 5m → 15m).
  /// Without this the pin pad's "5 attempts" limit was decorative — guessing
  /// could simply continue forever (10,000 combos, no throttle).
  void _onPinMaxAttempts() {
    _pinCooldownLevel = (_pinCooldownLevel + 1).clamp(1, 5);
    const steps = [30, 60, 120, 300, 900];
    final secs = steps[_pinCooldownLevel - 1];
    _pinCooldownUntil = DateTime.now().add(Duration(seconds: secs));
    setState(() {
      _pinSheetOpen = false;
      _inlineError = '${widget.state.strings.pinWrong} · ${secs}s';
    });
  }

  @override
  Widget build(BuildContext context) {
    // Gate disabled (or device cannot lock) → pass straight through.
    if (!widget.state.biometricLock || _gateOpen || !_available) {
      return widget.child;
    }

    return Scaffold(
      key: const ValueKey('mb-lock-gate'),
      backgroundColor: MbPalette.darkBg,
      body: SafeArea(
        child: Center(
          child: FadeTransition(
            opacity: CurvedAnimation(parent: _enter, curve: Curves.easeOut),
            child: _pinSheetOpen ? _buildPinPad(context) : _buildGate(context),
          ),
        ),
      ),
    );
  }

  // ── the fingerprint gate ──
  Widget _buildGate(BuildContext context) {
    final L = widget.state.strings;
    final scheme = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── lock badge with breathing glow ──
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.94, end: 1.06),
          duration: const Duration(milliseconds: 1600),
          curve: Curves.easeInOut,
          builder: (context, s, child) => Container(
            width: 104,
            height: 104,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: MbPalette.green.withOpacity(0.25),
                  blurRadius: 30,
                  spreadRadius: 2 + 6 * (s - 0.94),
                ),
              ],
            ),
            child: child,
          ),
          child: const Center(
            child: Text('🔒', style: TextStyle(fontSize: 42)),
          ),
        ),
        const SizedBox(height: 26),

        Text(
          L.lockTitle,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: MbThemes.fontFamily,
            color: MbPalette.darkText,
            fontSize: 21,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          L.lockSubtitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: MbThemes.fontFamily,
            color: MbPalette.darkText.withOpacity(0.55),
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 30),

        // ── unlock with fingerprint ──
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: MbPalette.green,
            foregroundColor: const Color(0xFF06130C),
            minimumSize: const Size(220, 52),
          ),
          onPressed: _checking ? null : _tryUnlock,
          icon: _checking
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                )
              : const Icon(Icons.fingerprint_rounded, size: 26),
          label: Text(L.lockUnlock),
        ),

        // ── unlock with backup PIN (always available when set) ──
        if (widget.state.hasBackupPin) ...[
          const SizedBox(height: 10),
          TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: MbPalette.darkText.withOpacity(0.75),
              minimumSize: const Size(220, 44),
            ),
            onPressed: _openPinSheet,
            icon: const Icon(Icons.dialpad_rounded, size: 20),
            label: Text(
              L.pinUsePin,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ] else ...[
          const SizedBox(height: 10),
        ],

        if (_inlineError != null) ...[
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _inlineError!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: MbThemes.fontFamily,
                color: Color(0xFFFFB4AB),
                fontSize: 12.5,
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ── the backup PIN keypad ──
  Widget _buildPinPad(BuildContext context) {
    final L = widget.state.strings;
    return MbPinPad(
      title: L.pinSheetTitle,
      hint: L.pinSheetHint,
      onSubmit: (pin) async {
        final ok = await widget.state.verifyBackupPin(pin);
        if (ok && mounted) {
          setState(() {
            _gateOpen = true;
            _pinCooldownLevel = 0; // successful unlock resets the throttle
            _pinCooldownUntil = null;
          });
        }
        return ok;
      },
      onMaxAttempts: _onPinMaxAttempts,
      footerLabel: L.pinTryFingerprint,
      onFooter: _closePinSheet,
    );
  }
}
