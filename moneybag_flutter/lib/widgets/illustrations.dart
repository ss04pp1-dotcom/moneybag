import 'package:flutter/material.dart';

import '../core/palette.dart';

/// Flat on-brand illustrations painted with CustomPainter —
/// no image assets, crisp on every density.

class PiggyIllustration extends StatelessWidget {
  final double size;
  final Color? coin;
  const PiggyIllustration({super.key, this.size = 180, this.coin});

  @override
  Widget build(BuildContext context) {
    final c = coin ?? MbPalette.green;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _PiggyPainter(c),
        size: Size.square(size),
      ),
    );
  }
}

class _PiggyPainter extends CustomPainter {
  final Color coinColor;
  _PiggyPainter(this.coinColor);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final body = Paint()..color = coinColor;
    final dark = Paint()..color = const Color(0x33000000);
    final white = Paint()..color = Colors.white;

    // Body
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(s * 0.5, s * 0.56), width: s * 0.62, height: s * 0.5),
        Radius.circular(s * 0.25),
      ),
      body,
    );
    // Ears
    for (final dx in [0.32, 0.68]) {
      canvas.drawCircle(Offset(s * dx, s * 0.32), s * 0.07, body);
    }
    // Snout
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(s * 0.62, s * 0.58),
          width: s * 0.22,
          height: s * 0.16),
      white,
    );
    // Nostrils
    canvas.drawCircle(Offset(s * 0.58, s * 0.58), s * 0.016, dark);
    canvas.drawCircle(Offset(s * 0.66, s * 0.58), s * 0.016, dark);
    // Eyes
    canvas.drawCircle(Offset(s * 0.42, s * 0.5), s * 0.028, dark);
    // Legs
    for (final dx in [0.32, 0.5, 0.68]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: Offset(s * dx, s * 0.83), width: s * 0.08, height: s * 0.12),
          Radius.circular(s * 0.04),
        ),
        body,
      );
    }
    // Slot
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(s * 0.42, s * 0.33), width: s * 0.2, height: s * 0.045),
        Radius.circular(s * 0.022),
      ),
      dark,
    );
    // Coin above slot
    final coin = Paint()..color = const Color(0xFFFFD43B);
    canvas.drawCircle(Offset(s * 0.5, s * 0.2), s * 0.11, coin);
    final coinText = TextPainter(
      text: const TextSpan(
        text: '৳',
        style: TextStyle(
          color: Color(0xFF7A5A00),
          fontSize: 32,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    coinText.paint(canvas, Offset(s * 0.5 - coinText.width / 2, s * 0.2 - coinText.height / 2));
  }

  @override
  bool shouldRepaint(covariant _PiggyPainter old) => old.coinColor != coinColor;
}

class WalletIllustration extends StatelessWidget {
  final double size;
  const WalletIllustration({super.key, this.size = 180});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _WalletPainter(), size: Size.square(size)),
    );
  }
}

class _WalletPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final base = Paint()..color = MbPalette.green;
    final flap = Paint()..color = const Color(0xFF1B7A4A);
    final white = Paint()..color = Colors.white;
    final taka = Paint()..color = const Color(0xFFFFD43B);

    // Wallet body
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(s * 0.12, s * 0.34, s * 0.76, s * 0.42),
        Radius.circular(s * 0.09),
      ),
      base,
    );
    // Flap
    Path flapPath() => Path()
      ..moveTo(s * 0.12, s * 0.42)
      ..lineTo(s * 0.12, s * 0.30)
      ..lineTo(s * 0.7, s * 0.22)
      ..lineTo(s * 0.76, s * 0.34)
      ..close();
    canvas.drawPath(flapPath(), flap);
    // Pocket
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(s * 0.6, s * 0.44, s * 0.28, s * 0.22),
        Radius.circular(s * 0.07),
      ),
      white,
    );
    // Button
    canvas.drawCircle(Offset(s * 0.74, s * 0.55), s * 0.045, taka);
    // Notes peeking
    final note = Paint()..color = const Color(0xFF63E6BE);
    for (var i = 0; i < 2; i++) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(s * (0.24 + i * 0.12), s * (0.2 - i * 0.02),
              s * 0.34, s * 0.14),
          Radius.circular(s * 0.03),
        ),
        note,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class BudgetIllustration extends StatelessWidget {
  final double size;
  const BudgetIllustration({super.key, this.size = 180});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _BudgetPainter(), size: Size.square(size)),
    );
  }
}

class _BudgetPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final bars = <(double, double, Color)>[
      (0.18, 0.22, MbPalette.green.withOpacity(0.55)),
      (0.34, 0.34, MbPalette.green.withOpacity(0.75)),
      (0.50, 0.48, MbPalette.green),
      (0.66, 0.30, MbPalette.green.withOpacity(0.75)),
      (0.82, 0.40, MbPalette.green.withOpacity(0.55)),
    ];
    for (final (x, h, c) in bars) {
      final paint = Paint()..color = c;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(s * x, s * (0.78 - h), s * 0.11, s * h),
          Radius.circular(s * 0.05),
        ),
        paint,
      );
    }
    // Limit line
    final line = Paint()
      ..color = const Color(0xFFFF6B6B)
      ..strokeWidth = s * 0.022
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
        Offset(s * 0.12, s * 0.32), Offset(s * 0.9, s * 0.32), line);
    // Flag dot on the line
    canvas.drawCircle(Offset(s * 0.88, s * 0.32), s * 0.035, line..color = const Color(0xFFFF6B6B));
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class DonutIllustration extends StatelessWidget {
  final double size;
  const DonutIllustration({super.key, this.size = 180});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _DonutIllusPainter(), size: Size.square(size)),
    );
  }
}

class _DonutIllusPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final center = Offset(s * 0.5, s * 0.5);
    final radius = s * 0.3;
    const segments = <(double, double, Color)>[
      (0.0, 140, Color(0xFFFFA94D)),
      (140, 90, Color(0xFF4DABF7)),
      (230, 70, Color(0xFFB197FC)),
      (300, 60, Color(0xFF63E6BE)),
    ];
    for (final (start, sweep, color) in segments) {
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.13
        ..strokeCap = StrokeCap.butt
        ..color = color;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start * 3.14159 / 180,
        (sweep - 8) * 3.14159 / 180,
        false,
        paint,
      );
    }
    // Sparkle
    final sparkle = Paint()..color = MbPalette.green;
    canvas.drawCircle(Offset(s * 0.78, s * 0.2), s * 0.045, sparkle);
    final sparkleSoft = Paint()..color = MbPalette.green.withOpacity(0.6);
    canvas.drawCircle(Offset(s * 0.24, s * 0.22), s * 0.03, sparkleSoft);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class ShieldIllustration extends StatelessWidget {
  final double size;
  const ShieldIllustration({super.key, this.size = 180});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _ShieldPainter(), size: Size.square(size)),
    );
  }
}

class _ShieldPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final shield = Paint()..color = MbPalette.green;
    final path = Path()
      ..moveTo(s * 0.5, s * 0.12)
      ..lineTo(s * 0.84, s * 0.24)
      ..lineTo(s * 0.84, s * 0.52)
      ..quadraticBezierTo(s * 0.84, s * 0.74, s * 0.5, s * 0.9)
      ..quadraticBezierTo(s * 0.16, s * 0.74, s * 0.16, s * 0.52)
      ..lineTo(s * 0.16, s * 0.24)
      ..close();
    canvas.drawPath(path, shield);
    // Lock body
    final lock = Paint()..color = const Color(0xFF0D1F17);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(s * 0.5, s * 0.55), width: s * 0.22, height: s * 0.18),
        Radius.circular(s * 0.04),
      ),
      lock,
    );
    // Lock shackle
    final shackle = Paint()
      ..color = const Color(0xFF0D1F17)
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.045;
    canvas.drawArc(
      Rect.fromCenter(
          center: Offset(s * 0.5, s * 0.44), width: s * 0.14, height: s * 0.14),
      3.14159,
      3.14159,
      false,
      shackle,
    );
    // Keyhole
    final hole = Paint()..color = MbPalette.green;
    canvas.drawCircle(Offset(s * 0.5, s * 0.54), s * 0.025, hole);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
