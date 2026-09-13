import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/calc.dart';
import '../core/format.dart';
import '../core/palette.dart';
import '../core/l10n.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';
import '../screens/backup_screen.dart';
import '../screens/savings_screen.dart';
import '../screens/transaction_edit_screen.dart';
import 'animations.dart';

class _BannerSlide {
  final String title;
  final String body;
  final String cta;
  final VoidCallback onCta;
  final IconData icon;
  final List<Color> gradient;

  const _BannerSlide({
    required this.title,
    required this.body,
    required this.cta,
    required this.onCta,
    required this.icon,
    required this.gradient,
  });
}

/// Dashboard banner — auto-rotating, real-data slides.
///
/// Content is computed live from the app state (budget status, savings rate,
/// goal progress, backup age) so the banner never shows stale or fabricated
/// information. Auto-advances every 6 seconds; pauses after user swipes.
class MbTipsBanner extends StatefulWidget {
  const MbTipsBanner({super.key});

  @override
  State<MbTipsBanner> createState() => _MbTipsBannerState();
}

class _MbTipsBannerState extends State<MbTipsBanner> {
  final _page = PageController(initialPage: 0, viewportFraction: 1.0);
  int _index = 0;
  Timer? _timer;
  bool _auto = true;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!_auto || !_page.hasClients) return;
      final next = (_index + 1) % _slideCount;
      _page.animateToPage(
        next,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _page.dispose();
    super.dispose();
  }

  int get _slideCount => 4;

  void _onPageChanged(int i) {
    setState(() {
      _index = i;
      // User interacted — stop auto rotation so it never fights their swipe.
      _auto = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<MbAppState>();
    final L = context.L;
    final slides = _buildSlides(context, state, L);

    if (slides.isEmpty) return const SizedBox.shrink();

    return MbFadeSlideIn(
      index: 1,
      child: Column(
        children: [
          SizedBox(
            height: 104,
            child: PageView.builder(
              controller: _page,
              itemCount: slides.length,
              onPageChanged: _onPageChanged,
              itemBuilder: (context, i) {
                final s = slides[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: _SlideCard(slide: s),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          MbDotIndicator(
            count: slides.length,
            active: _index.clamp(0, slides.length - 1),
            activeColor: Theme.of(context).colorScheme.primary,
          ),
        ],
      ),
    );
  }

  List<_BannerSlide> _buildSlides(
      BuildContext context, MbAppState state, MbStrings L) {
    final now = DateTime.now();
    final all = state.txView;
    final monthTxs = state.txOfMonth(now.year, now.month);
    final totals = MbCalc.totals(monthTxs);
    final slides = <_BannerSlide>[];

    // 1) Backup nudge — real last-backup age.
    final lastBackup = state.lastBackupAt;
    final ageDays =
        lastBackup == null ? null : now.difference(lastBackup).inDays;
    final needsBackup =
        state.transactions.isNotEmpty && (ageDays == null || ageDays >= 7);
    if (needsBackup) {
      final when = ageDays == null
          ? L.driveLastBackupNever
          : MbFormat.relativeDays(ageDays, bangla: state.bangla);
      slides.add(_BannerSlide(
        title: L.bannerBackupTitle(when),
        body: L.bannerBackupBody,
        cta: L.bannerBackupCta,
        icon: Icons.cloud_upload_outlined,
        gradient: const [Color(0xFF123A24), Color(0xFF0E2418)],
        onCta: () => MbNav.push(context, const BackupScreen()),
      ));
    }

    // 2) Savings rate — real numbers.
    final effIncome =
        totals.income > 0 ? totals.income : (state.monthlyIncomeMinor ?? 0);
    if (effIncome > 0 && totals.net > 0) {
      final rate = (totals.net / effIncome) * 100;
      slides.add(_BannerSlide(
        title: L.bannerSavingsTitle,
        body: L.bannerSavingsBody(state.pct(rate)),
        cta: L.bannerSavingsCta,
        icon: Icons.savings_rounded,
        gradient: const [MbPalette.greenDark, MbPalette.green],
        onCta: () => _openSavings(context),
      ));
    }

    // 3) Goal progress — real numbers.
    if (state.goals.isNotEmpty) {
      final g = state.goals.first;
      final saved = state.savedForGoal(g.id);
      final frac = g.targetMinor <= 0
          ? 0.0
          : (saved / g.targetMinor).clamp(0.0, 1.0);
      final left = g.targetMinor - saved;
      slides.add(_BannerSlide(
        title: L.bannerGoalTitle,
        body: L.bannerGoalBody(
          state.pct(frac * 100),
          state.money(left < 0 ? 0 : left),
        ),
        cta: L.bannerGoalCta,
        icon: Icons.flag_rounded,
        gradient: const [Color(0xFF2C3E7A), Color(0xFF1D2A54)],
        onCta: () => _openSavings(context),
      ));
    }

    // 4) Log today's record.
    final todayTxs = MbCalc.between(
        all, DateTime(now.year, now.month, now.day), DateTime(now.year, now.month, now.day + 1));
    if (todayTxs.isEmpty) {
      slides.add(_BannerSlide(
        title: L.bannerAddTxTitle,
        body: L.bannerAddTxBody,
        cta: L.bannerAddTxCta,
        icon: Icons.edit_note_rounded,
        gradient: const [Color(0xFF7A5A2C), Color(0xFF54401E)],
        onCta: () => MbNav.push(context, const TransactionEditScreen(),
            fullscreenDialog: true),
      ));
    }

    // Always show at least one slide.
    if (slides.isEmpty) {
      slides.add(_BannerSlide(
        title: L.bannerAddTxTitle,
        body: L.bannerAddTxBody,
        cta: L.bannerAddTxCta,
        icon: Icons.edit_note_rounded,
        gradient: const [MbPalette.greenDark, MbPalette.green],
        onCta: () => MbNav.push(context, const TransactionEditScreen(),
            fullscreenDialog: true),
      ));
    }
    return slides;
  }

  void _openSavings(BuildContext context) {
    MbNav.push(context, const SavingsScreen());
  }
}

class _SlideCard extends StatelessWidget {
  final _BannerSlide slide;

  const _SlideCard({required this.slide});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: slide.gradient,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(slide.icon, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  slide.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'NotoSansBengali',
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  slide.body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'NotoSansBengali',
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 11.5,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: slide.onCta,
            style: TextButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: scheme.primary,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              minimumSize: Size.zero,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999)),
              textStyle: const TextStyle(
                fontFamily: 'NotoSansBengali',
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            child: Text(slide.cta),
          ),
        ],
      ),
    );
  }
}
