import 'package:flutter/material.dart';

import '../core/palette.dart';
import '../widgets/common.dart';
import '../widgets/illustrations.dart';
import 'login_screen.dart';

/// 6-slide onboarding — alternating dark / light backgrounds per the
/// reference design, ending in the profile-setup hand-off.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _page = 0;

  static const _pageCount = 6;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_page == _pageCount - 1) {
      _goSetup();
    } else {
      _controller.nextPage(
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _goSetup() {
    // Onboarding hands off to LOGIN (Google-only), which then leads to the
    // profile setup — sign-in first so the name/photo can be pre-filled.
    Navigator.of(context).push(PageRouteBuilder(
      pageBuilder: (_, __, ___) => const LoginScreen(fromOnboarding: true),
      transitionsBuilder: (_, animation, __, child) => FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: child,
      ),
      transitionDuration: const Duration(milliseconds: 340),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final L = context.L;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Even slides dark bg, odd slides light mint bg — matching reference.
    final darkSlide = _page % 2 == 0;
    final slideBg = darkSlide
        ? MbPalette.darkBg
        : (isDark ? MbPalette.darkSurface : MbPalette.lightMint);
    final slideFg = darkSlide || isDark ? MbPalette.darkText : MbPalette.lightText;
    final slideMuted = darkSlide || isDark ? MbPalette.darkMuted : MbPalette.lightMuted;

    final titles = [L.ob1Title, L.ob2Title, L.ob3Title, L.ob4Title, L.ob5Title, L.ob6Title];
    final bodies = [L.ob1Body, L.ob2Body, L.ob3Body, L.ob4Body, L.ob5Body, L.ob6Body];

    return Scaffold(
      backgroundColor: slideBg,
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 350),
        color: slideBg,
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8, right: 16),
                  child: TextButton(
                    onPressed: _goSetup,
                    child: Text(
                      L.skip,
                      style: TextStyle(color: slideMuted),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _pageCount,
                  onPageChanged: (i) => setState(() => _page = i),
                  itemBuilder: (context, i) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(child: _illustration(i)),
                          const SizedBox(height: 36),
                          Text(
                            titles[i],
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'NotoSansBengali',
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                              color: slideFg,
                              height: 1.25,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            bodies[i],
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'NotoSansBengali',
                              fontSize: 15,
                              color: slideMuted,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              // Dots
              Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < _pageCount; i++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: i == _page ? 26 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: i == _page
                              ? MbPalette.green
                              : MbPalette.green.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(32, 0, 32, 28),
                child: Row(
                  children: [
                    if (_page > 0)
                      TextButton(
                        onPressed: () => _controller.previousPage(
                          duration: const Duration(milliseconds: 380),
                          curve: Curves.easeOutCubic,
                        ),
                        child: Text(L.back, style: TextStyle(color: slideMuted)),
                      ),
                    const Spacer(),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: MbPalette.green,
                        foregroundColor: const Color(0xFF06130C),
                      ),
                      onPressed: _next,
                      child: Text(
                        _page == _pageCount - 1 ? L.start : L.next,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _illustration(int i) {
    switch (i) {
      case 0:
        return const PiggyIllustration(size: 190);
      case 1:
        return const WalletIllustration(size: 190);
      case 2:
        return const BudgetIllustration(size: 190);
      case 3:
        return const PiggyIllustration(size: 190, coin: Color(0xFFFFD43B));
      case 4:
        return const DonutIllustration(size: 190);
      default:
        return const ShieldIllustration(size: 190);
    }
  }
}
