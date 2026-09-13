import 'package:flutter/material.dart';

import '../core/l10n.dart';
import '../core/palette.dart';
import '../core/insights.dart';
import '../state/app_state.dart';
import 'animations.dart';

/// Shared MoneyBag widgets — cards, headers, empty states, progress bars,
/// transaction tiles, insight cards.

class MbCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final VoidCallback? onTap;

  const MbCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final body = Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: child,
    );
    if (onTap == null) return body;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: body,
      ),
    );
  }
}

class MbSectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const MbSectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontFamily: 'NotoSansBengali',
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          if (actionLabel != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(actionLabel!),
            ),
        ],
      ),
    );
  }
}

class MbEmptyState extends StatelessWidget {
  final String emoji;
  final String title;
  final String? body;
  final Widget? action;

  const MbEmptyState({
    super.key,
    required this.emoji,
    required this.title,
    this.body,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            MbScaleIn(
              child: Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(emoji, style: const TextStyle(fontSize: 38)),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'NotoSansBengali',
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
            if (body != null) ...[
              const SizedBox(height: 6),
              Text(
                body!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'NotoSansBengali',
                  fontSize: 13.5,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
            if (action != null) ...[const SizedBox(height: 18), action!],
          ],
        ),
      ),
    );
  }
}

/// Budget/progress bar with 85% warning zone coloring.
/// The fill animates smoothly whenever the value changes.
class MbProgressBar extends StatelessWidget {
  final double value; // 0..1 (may exceed 1)
  final double height;

  const MbProgressBar({super.key, required this.value, this.height = 10});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final clamped = value.clamp(0.0, 1.0);
    final over = value > 1.0;
    final warn = value >= 0.85 && !over;
    final color = over
        ? MbPalette.danger
        : (warn ? MbPalette.warning : scheme.primary);
    return LayoutBuilder(
      builder: (context, c) {
        return SizedBox(
          height: height,
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: clamped),
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeOutCubic,
                builder: (context, v, _) => FractionallySizedBox(
                  widthFactor: v,
                  child: Container(
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// One transaction row — icon bubble, category/note, amount.
class MbTransactionTile extends StatelessWidget {
  final String emoji;
  final Color accent;
  final String title;
  final String? subtitle;
  final bool isExpense;
  final String amountText;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const MbTransactionTile({
    super.key,
    required this.emoji,
    required this.accent,
    required this.title,
    this.subtitle,
    required this.isExpense,
    required this.amountText,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Text(emoji, style: const TextStyle(fontSize: 20)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'NotoSansBengali',
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty)
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'NotoSansBengali',
                          fontSize: 12.5,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                amountText,
                style: TextStyle(
                  fontFamily: 'NotoSansBengali',
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: isExpense ? scheme.error : scheme.secondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Insight card from the rule engine.
class MbInsightCard extends StatelessWidget {
  final MbInsight insight;

  const MbInsightCard({super.key, required this.insight});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (fg, bg) = switch (insight.tone) {
      MbInsightTone.positive => (scheme.secondary, scheme.secondaryContainer),
      MbInsightTone.warning => (MbPalette.warning, MbPalette.warning.withOpacity(0.12)),
      MbInsightTone.danger => (scheme.error, scheme.errorContainer),
      MbInsightTone.neutral => (scheme.primary, scheme.primaryContainer),
    };
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(insight.icon, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  insight.title,
                  style: TextStyle(
                    fontFamily: 'NotoSansBengali',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  insight.body,
                  style: TextStyle(
                    fontFamily: 'NotoSansBengali',
                    fontSize: 12.5,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
          ),
        ],
      ),
    );
  }
}

/// Month selector chip row (◀ সেপ্টেম্বর ২০২৫ ▶).
class MbMonthSelector extends StatelessWidget {
  final int year;
  final int month;
  final String label;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final bool nextEnabled;

  const MbMonthSelector({
    super.key,
    required this.year,
    required this.month,
    required this.label,
    required this.onPrev,
    required this.onNext,
    this.nextEnabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: onPrev,
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          // Flexible so the label ellipsizes instead of overflowing the
          // pill when the month label is long (large Bengali text scale).
          Flexible(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'NotoSansBengali',
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: scheme.onSurface,
                ),
              ),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: nextEnabled ? onNext : null,
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    );
  }
}

/// Helper: category lookup → (emoji, accent color).
(Color, String) categoryAccentOf(MbAppState state, String? categoryId) {
  if (categoryId == null) return (const Color(MbPalette.other), '💸');
  final c = state.catById[categoryId];
  if (c == null) return (const Color(MbPalette.other), '💸');
  return (Color(c.color), c.icon);
}

/// context.L extension.
extension MbL10nX on BuildContext {
  MbStrings get L => MbInherited.of(this);
}
