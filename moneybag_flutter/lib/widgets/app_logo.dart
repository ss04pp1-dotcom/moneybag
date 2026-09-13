import 'package:flutter/material.dart';

import '../core/palette.dart';

/// Vector MoneyBag logo — bag body + neck + rope tie + ৳ mark + coin.
///
/// Painted with CustomPainter so it stays crisp at every size and can be
/// recoloured (white watermark variant for the greeting banner). Matches the
/// launcher icon design 1:1.
class MbAppLogo extends StatelessWidget {
  final double size;

  /// White "watermark" variant (bag in white, ৳ in deep green) — used on
  /// green gradient backgrounds.
  final bool white;

  const MbAppLogo({super.key, this.size = 96, this.white = false});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _MoneyBagLogoPainter(white: white),
    );
  }
}

class _MoneyBagLogoPainter extends CustomPainter {
  final bool white;
  const _MoneyBagLogoPainter({required this.white});

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;

    final bag = white ? Colors.white : MbPalette.green;
    final ink = white
        ? const Color(0xFF0D2B1C).withOpacity(0.85)
        : const Color(0xFF06130C);
    final rope = white
        ? Colors.white.withOpacity(0.55)
        : MbPalette.greenDark;

    // ── bag body ──
    final bodyPaint = Paint()..color = bag;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(s * 0.14, s * 0.30, s * 0.72, s * 0.62),
        Radius.circular(s * 0.26),
      ),
      bodyPaint,
    );

    // ── neck ──
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(s * 0.38, s * 0.16, s * 0.24, s * 0.18),
        Radius.circular(s * 0.06),
      ),
      bodyPaint,
    );

    // ── rope tie ──
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(s * 0.33, s * 0.27, s * 0.34, s * 0.06),
        Radius.circular(s * 0.03),
      ),
      Paint()..color = rope,
    );

    // ── coin slot ──
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(s * 0.42, s * 0.185, s * 0.16, s * 0.04),
        Radius.circular(s * 0.02),
      ),
      Paint()..color = ink,
    );

    // ── ৳ mark on the body ──
    final tp = TextPainter(
      text: TextSpan(
        text: '৳',
        style: TextStyle(
          color: ink,
          fontSize: s * 0.38,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(s * 0.5 - tp.width / 2, s * 0.60 - tp.height / 2));

    // ── coin (amber) ──
    final coinC = Offset(s * 0.80, s * 0.14);
    canvas.drawCircle(
        coinC, s * 0.115, Paint()..color = const Color(0xFFFFD43B));
    final tp2 = TextPainter(
      text: TextSpan(
        text: '৳',
        style: TextStyle(
          color: const Color(0xFF7A5A00),
          fontSize: s * 0.13,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp2.paint(
        canvas, coinC - Offset(tp2.width / 2, tp2.height / 2));
  }

  @override
  bool shouldRepaint(covariant _MoneyBagLogoPainter old) =>
      old.white != white;
}
