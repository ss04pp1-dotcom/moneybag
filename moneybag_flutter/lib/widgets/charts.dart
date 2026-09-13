import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Donut chart segment.
class MbDonutSegment {
  final double fraction; // 0..1 of the whole
  final Color color;
  final String label;

  const MbDonutSegment({
    required this.fraction,
    required this.color,
    required this.label,
  });
}

/// MoneyBag donut chart — custom painted, no external chart package.
///
/// Shows a center hole with optional [centerLabel]/[centerValue].
/// Entrance: the ring sweeps in from zero over ~900ms.
class MbDonut extends StatelessWidget {
  final List<MbDonutSegment> segments;
  final double size;
  final String? centerValue;
  final String? centerLabel;
  final double strokeWidth;

  const MbDonut({
    super.key,
    required this.segments,
    this.size = 180,
    this.centerValue,
    this.centerLabel,
    this.strokeWidth = 20,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (context, progress, _) => CustomPaint(
          painter: _DonutPainter(
            segments: segments,
            strokeWidth: strokeWidth,
            track:
                Theme.of(context).colorScheme.surfaceContainerHighest,
            progress: progress,
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (centerValue != null)
                  Text(
                    centerValue!,
                    style: TextStyle(
                      fontFamily: 'NotoSansBengali',
                      fontSize: size * 0.09,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                if (centerLabel != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      centerLabel!,
                      style: TextStyle(
                        fontFamily: 'NotoSansBengali',
                        fontSize: size * 0.05,
                        color:
                            Theme.of(context).colorScheme.onSurfaceVariant,
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

class _DonutPainter extends CustomPainter {
  final List<MbDonutSegment> segments;
  final double strokeWidth;
  final Color track;
  final double progress; // entrance animation 0..1

  _DonutPainter({
    required this.segments,
    required this.strokeWidth,
    required this.track,
    this.progress = 1,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final total = segments.fold<double>(
        0, (a, s) => a + s.fraction.clamp(0.0, 1.0));
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = size.shortestSide / 2 - strokeWidth / 2 - 2;

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt
      ..color = track;
    canvas.drawCircle(center, radius, trackPaint);

    if (total <= 0 || segments.isEmpty) return;

    var start = -math.pi / 2;
    final gap = segments.length > 1 ? 0.03 : 0.0;
    for (final s in segments) {
      final f = s.fraction.clamp(0.0, 1.0);
      final sweep = (f / total) * 2 * math.pi * progress;
      if (sweep <= 0) continue;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..color = s.color;
      final effective = sweep - gap > 0.05 ? sweep - gap : sweep;
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius), start,
          effective, false, paint);
      start += (f / total) * 2 * math.pi;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.segments != segments ||
      old.track != track ||
      old.progress != progress;
}

/// Vertical bar chart with compact value labels.
class MbBarChart extends StatelessWidget {
  final List<double> values;
  final List<String> labels;
  final List<Color>? colors;
  final double height;
  final String Function(int index)? valueFormatter;

  const MbBarChart({
    super.key,
    required this.values,
    required this.labels,
    this.colors,
    this.height = 160,
    this.valueFormatter,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final maxV = values.fold<double>(0, (a, v) => v > a ? v : a);
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < values.length; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (valueFormatter != null && values[i] > 0)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          valueFormatter!(i),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'NotoSansBengali',
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    LayoutBuilder(
                      builder: (context, c) {
                        final h = maxV <= 0
                            ? 4.0
                            : (values[i] / maxV) * (height - 46);
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 350),
                          curve: Curves.easeOutCubic,
                          height: h.clamp(4.0, height - 46),
                          decoration: BoxDecoration(
                            color: colors != null && i < colors!.length
                                ? colors![i]
                                : scheme.primary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 6),
                    Text(
                      labels[i],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'NotoSansBengali',
                        fontSize: 10.5,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Multi-series month bars (income vs expense) for trend charts.
class MbMonthBars extends StatelessWidget {
  final List<({String label, int income, int expense})> months;
  final double height;
  final String Function(int v)? formatValue;

  const MbMonthBars({
    super.key,
    required this.months,
    this.height = 170,
    this.formatValue,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final maxV = months.fold<int>(0, (a, m) {
      final v = m.income > m.expense ? m.income : m.expense;
      return v > a ? v : a;
    });
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final m in months)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (formatValue != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          formatValue!(m.expense),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'NotoSansBengali',
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    SizedBox(
                      height: height - 42,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _bar(
                            context,
                            value: m.income,
                            max: maxV,
                            color: scheme.secondary,
                            width: 10,
                          ),
                          const SizedBox(width: 4),
                          _bar(
                            context,
                            value: m.expense,
                            max: maxV,
                            color: scheme.error,
                            width: 10,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      m.label,
                      style: TextStyle(
                        fontFamily: 'NotoSansBengali',
                        fontSize: 10.5,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _bar(BuildContext context,
      {required int value, required int max, required Color color, required double width}) {
    final h = max <= 0 ? 3.0 : (value / max) * (height - 42);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      width: width,
      height: h.clamp(3.0, height - 42),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(5),
      ),
    );
  }
}

/// Circular progress ring used on goal cards (piggy-bank style).
class MbProgressRing extends StatelessWidget {
  final double progress; // 0..1
  final double size;
  final double strokeWidth;
  final Widget child;

  const MbProgressRing({
    super.key,
    required this.progress,
    required this.child,
    this.size = 72,
    this.strokeWidth = 7,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: progress.clamp(0.0, 1.0)),
        duration: const Duration(milliseconds: 750),
        curve: Curves.easeOutCubic,
        builder: (context, v, _) => Stack(
          alignment: Alignment.center,
          children: [
            CircularProgressIndicator(
              value: v,
              strokeWidth: strokeWidth,
              strokeAlign: CircularProgressIndicator.strokeAlignCenter,
              backgroundColor: scheme.surfaceContainerHighest,
            ),
            child,
          ],
        ),
      ),
    );
  }
}
