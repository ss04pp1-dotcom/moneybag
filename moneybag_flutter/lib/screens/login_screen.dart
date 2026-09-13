import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/palette.dart';
import '../services/auth_service.dart';
import '../services/auto_restore_flow.dart';
import '../state/app_state.dart';
import '../widgets/animations.dart';
import '../widgets/app_logo.dart';
import '../widgets/common.dart';
import '../widgets/google_logo.dart';
import 'profile_setup_screen.dart';

/// Login — the ONLY sign-in option is Google.
///
/// Shown once right after onboarding (and once to existing installs); the
/// "continue without signing in" escape keeps the app 100% local-first.
/// Tapping the Google button either signs in (name/photo sync + Drive
/// backup unlock) or shows the one-time Web Client ID setup guide.
class LoginScreen extends StatefulWidget {
  final bool fromOnboarding;

  const LoginScreen({super.key, this.fromOnboarding = false});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // Mark that this device has seen the login screen (shown only once).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MbAppState>().setLoginSeen();
    });
  }

  void _done() {
    if (!mounted) return;
    if (widget.fromOnboarding) {
      Navigator.of(context).pushReplacement(PageRouteBuilder(
        pageBuilder: (_, __, ___) => const ProfileSetupScreen(),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 340),
      ));
    } else {
      // Shown as home — the state change itself swaps to the shell.
      Navigator.of(context).popUntil((r) => r.isFirst);
    }
  }

  Future<void> _signIn() async {
    final state = context.read<MbAppState>();
    final L = context.L;

    if (!MbAuthService.instance.configured) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(L.loginSetupTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(L.loginSetupBody),
              const SizedBox(height: 12),
              Text('• ${L.driveSetupStep1}'),
              Text('• ${L.driveSetupStep2}'),
              Text('• ${L.driveSetupStep3}'),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(L.ok),
            ),
          ],
        ),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      final ok = await state.signInWithGoogle();
      if (!mounted) return;
      if (ok) {
        // Signed in: auto-check Drive for an existing backup and restore
        // it (fully automatic when possible — see auto_restore_flow.dart).
        await runAutoRestoreFlow(context);
        if (!mounted) return;
        _done();
      } else {
        // User cancelled the Google dialog — stay here quietly.
        setState(() => _busy = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${L.loginFailed} (${e.toString()})')),
        );
      }
    }
  }

  Future<void> _continueWithout() async {
    final state = context.read<MbAppState>();
    await state.skipLogin();
    _done();
  }

  @override
  Widget build(BuildContext context) {
    final L = context.L;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── animated logo ──
                MbFadeSlideIn(
                  duration: const Duration(milliseconds: 600),
                  child: Container(
                    width: 104,
                    height: 104,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [MbPalette.green, MbPalette.greenDark],
                      ),
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: MbPalette.green.withOpacity(0.30),
                          blurRadius: 30,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: MbAppLogo(size: 72),
                    ),
                  ),
                ),
                const SizedBox(height: 26),

                MbFadeSlideIn(
                  index: 1,
                  child: Text(
                    L.appName,
                    style: const TextStyle(
                      fontFamily: 'NotoSansBengali',
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                MbFadeSlideIn(
                  index: 2,
                  child: Text(
                    L.loginSubtitle,
                    style: TextStyle(
                      fontFamily: 'NotoSansBengali',
                      fontSize: 14,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(height: 40),

                // ── the only login method: Google ──
                MbFadeSlideIn(
                  index: 3,
                  child: MbPressable(
                    pressedScale: 0.97,
                    onTap: _busy ? null : _signIn,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.12),
                            blurRadius: 18,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_busy)
                            const SizedBox(
                              width: 22,
                              height: 22,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2.4),
                            )
                          else ...[
                            const MbGoogleG(size: 23),
                            const SizedBox(width: 12),
                          ],
                          // Overflow-safe on narrow screens / big text scale.
                          Flexible(
                            child: Text(
                              _busy ? '…' : L.loginWithGoogle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'NotoSansBengali',
                                color: Color(0xFF1F1F1F),
                                fontSize: 15.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // ── continue without signing in ──
                MbFadeSlideIn(
                  index: 4,
                  child: TextButton(
                    onPressed: _busy ? null : _continueWithout,
                    child: Text(
                      L.loginContinueWithout,
                      style: TextStyle(
                        fontFamily: 'NotoSansBengali',
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 30),

                MbFadeSlideIn(
                  index: 5,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest
                          .withOpacity(0.6),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.lock_outline_rounded,
                            size: 15, color: scheme.onSurfaceVariant),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            L.loginPrivacyNote,
                            style: TextStyle(
                              fontFamily: 'NotoSansBengali',
                              fontSize: 11.5,
                              height: 1.5,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
