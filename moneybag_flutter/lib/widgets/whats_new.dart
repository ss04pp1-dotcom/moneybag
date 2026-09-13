import 'package:flutter/material.dart';

import '../core/config.dart';
import '../core/l10n.dart';
import '../core/palette.dart';
import '../state/app_state.dart';
import 'app_logo.dart';
import 'common.dart';

/// v2.1.1 — "What's New" upgrade guide.
///
/// The v2.1.0 build shipped 8 features but existing users (who upgraded
/// from v2.0.x) had `onboarded = true` already stored, so the onboarding
/// never re-appeared and nobody could find the new features. This dialog
/// is the fix: it greets every EXISTING user once per app version, right
/// after the shell renders, and walks them through where each feature
/// lives.
///
/// * Fresh installs never see it (the flag is pre-set during init when
///   the user still has to go through onboarding).
/// * Shows once per version — reopening the app won't repeat it.
/// * Fully bilingual — every string comes from [MbStrings].
Future<void> showWhatsNewIfNeeded(BuildContext context, MbAppState state) async {
  // Already-in-flight guard (post-frame can fire twice on fast rebuilds).
  if (_WhatsNewMarker.showing) return;

  final prefs = state.prefs;
  final seen = prefs.getString(_WhatsNewMarker.flag) ?? '';
  if (seen == MbConfig.appVersion) return; // already greeted for this version

  // Mark BEFORE showing — a dismissed dialog must never re-appear.
  _WhatsNewMarker.showing = true;
  await prefs.setString(_WhatsNewMarker.flag, MbConfig.appVersion);

  if (!context.mounted) {
    _WhatsNewMarker.showing = false;
    return;
  }
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withOpacity(0.55),
    builder: (_) => const _WhatsNewDialog(),
  );
  _WhatsNewMarker.showing = false;
}

class _WhatsNewMarker {
  static const String flag = 'whatsNewSeen';
  static bool showing = false;
}

class _WhatsNewDialog extends StatelessWidget {
  const _WhatsNewDialog();

  @override
  Widget build(BuildContext context) {
    final L = context.L;
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final rows = _rows(L);

    return Dialog(
      backgroundColor: isDark ? MbPalette.darkSurface : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── gradient header ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 26, 24, 22),
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [MbPalette.green, MbPalette.greenDark],
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.16),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Center(child: MbAppLogo(size: 40)),
                ),
                const SizedBox(height: 12),
                Text(
                  L.guideTitle,
                  style: const TextStyle(
                    fontFamily: 'NotoSansBengali',
                    color: Color(0xFF06130C),
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${L.guideSubtitle} · v${MbConfig.appVersion}',
                  style: TextStyle(
                    fontFamily: 'NotoSansBengali',
                    color: const Color(0xFF06130C).withOpacity(0.7),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          // ── feature list ──
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Column(
                children: [
                  for (var i = 0; i < rows.length; i++) ...[
                    _row(context, scheme, rows[i]),
                    if (i != rows.length - 1) const SizedBox(height: 4),
                  ],
                ],
              ),
            ),
          ),

          // ── start button ──
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: MbPalette.green,
                  foregroundColor: const Color(0xFF06130C),
                  minimumSize: const Size(0, 50),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
                child: Text(
                  L.guideStart,
                  style: const TextStyle(
                      fontSize: 15.5, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<({IconData icon, String title, String body})> _rows(MbStrings L) {
    return [
      // ── v2.2.5 fixes first: these are what the user is waiting on ──
      (
        icon: Icons.category_rounded,
        title: L.guideCatBudgetTitle,
        body: L.guideCatBudgetBody,
      ),
      (
        icon: Icons.edit_note_rounded,
        title: L.guideFreeCatTitle,
        body: L.guideFreeCatBody,
      ),
      // ── v2.1.2 fixes: the classics ──
      (
        icon: Icons.verified_rounded,
        title: L.guideFixLockTitle,
        body: L.guideFixLockBody,
      ),
      (
        icon: Icons.build_circle_rounded,
        title: L.guideFixWidgetTitle,
        body: L.guideFixWidgetBody,
      ),
      // ── the v2.1 feature recap (where everything lives) ──
      (
        icon: Icons.fingerprint_rounded,
        title: L.guideFpTitle,
        body: L.guideFpBody('${L.profileTitle} → ${L.settingsSectionGeneral}'),
      ),
      (
        icon: Icons.document_scanner_rounded,
        title: L.guideOcrTitle,
        body: L.guideOcrBody('+ → ${L.scanReceipt}'),
      ),
      (
        icon: Icons.auto_awesome_rounded,
        title: L.guideBudgetTitle,
        body: L.guideBudgetBody(L.navBudget),
      ),
      (
        icon: Icons.insights_rounded,
        title: L.guideInsightTitle,
        body: L.guideInsightBody(L.navHome),
      ),
      (
        icon: Icons.flag_rounded,
        title: L.guideEtaTitle,
        body: L.guideEtaBody(L.savingsTitle),
      ),
      (
        icon: Icons.widgets_rounded,
        title: L.guideWidgetTitle,
        body: L.guideWidgetBody(L.guideWidgetWhere),
      ),
      (
        icon: Icons.palette_rounded,
        title: L.guideMyTitle,
        body: L.guideMyBody(''),
      ),
      (
        icon: Icons.copy_rounded,
        title: L.guideDupTitle,
        body: L.guideDupBody(''),
      ),
    ];
  }

  Widget _row(BuildContext context, ColorScheme scheme,
      ({IconData icon, String title, String body}) r) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: scheme.primaryContainer.withOpacity(0.65),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(r.icon, size: 21, color: scheme.primary),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r.title,
                  style: TextStyle(
                    fontFamily: 'NotoSansBengali',
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  r.body.trim(),
                  style: TextStyle(
                    fontFamily: 'NotoSansBengali',
                    fontSize: 12.5,
                    height: 1.45,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
