import 'package:flutter/material.dart';

/// Google "G" mark, drawn as a CustomPainter (no asset needed).
class MbGoogleG extends StatelessWidget {
  final double size;
  const MbGoogleG({super.key, this.size = 22});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: const _GoogleGPainter(),
    );
  }
}

class _GoogleGPainter extends CustomPainter {
  const _GoogleGPainter();

  static const _blue = Color(0xFF4285F4);
  static const _red = Color(0xFFEA4335);
  static const _yellow = Color(0xFFFBBC05);
  static const _green = Color(0xFF34A853);

  static double _rad(double deg) => deg * 3.141592653589793 / 180.0;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final stroke = s * 0.30;
    final radius = (s - stroke) / 2;
    final center = Offset(s / 2, s / 2);
    final rect = Rect.fromCircle(center: center, radius: radius);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;

    // Ring quadrants (screen angles: 0=E, 90=S, 180=W, 270=N).
    canvas.drawArc(rect, _rad(200), _rad(115), false, paint..color = _red);
    canvas.drawArc(rect, _rad(315), _rad(90), false, paint..color = _blue);
    canvas.drawArc(rect, _rad(45), _rad(90), false, paint..color = _green);
    canvas.drawArc(rect, _rad(135), _rad(65), false, paint..color = _yellow);

    // Horizontal bar into the center (blue).
    canvas.drawRect(
      Rect.fromLTWH(
          center.dx, center.dy - stroke / 2, radius + stroke * 0.6, stroke),
      Paint()..color = _blue,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
