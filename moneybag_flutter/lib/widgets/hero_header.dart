import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/palette.dart';
import 'app_logo.dart';
import 'avatar.dart';

/// Full-width HERO greeting background — NOT a card.
///
/// A layered atmospheric backdrop (deep navy gradient, blue/cyan/purple glows,
/// bokeh circles, a starfield of dots and the MoneyBag watermark) that sits
/// directly on the screen background and *blends* into it at the bottom.
/// The greeting text, the profile avatar (left) and the notification bell
/// (right) live on top of this background. The “আজকের হিসাব” floating card
/// is NOT part of the hero — its top 46px ride over the hero's extended
/// background band (see [overlapBand]).
///
/// v2.2.3 hit-test fix: the dashboard used to fake the overlap with
/// `Transform.translate(-46px)`. A transform moves PAINT but the ListView
/// routes taps by each sliver's LAYOUT extent — so the top 46px of the
/// floating card (the whole “যোগ করুন” pill, top edge) mapped to the hero
/// sliver and taps there went dead. Now the hero PAINTS 74px beyond its
/// layout box ([overlapBand], via a negative Positioned + Clip.none) and the
/// card sits in normal layout 28px below the hero — visually identical,
/// hit-test correct.
class MbHeroHeader extends StatefulWidget {
  final String greeting;
  final String tagline;
  final VoidCallback? onNotificationTap;
  final bool showNotificationDot;

  /// How far the backdrop paints BELOW the hero's layout box. The floating
  /// “আজকের হিসাব” card overlaps the last 46px of this band; the first 28px
  /// stay visible as the gap between the tagline and the card.
  static const double overlapBand = 74;

  const MbHeroHeader({
    super.key,
    required this.greeting,
    required this.tagline,
    this.onNotificationTap,
    this.showNotificationDot = false,
  });

  @override
  State<MbHeroHeader> createState() => _MbHeroHeaderState();
}

class _MbHeroHeaderState extends State<MbHeroHeader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  Timer? _pulseTimer;

  @override
  void initState() {
    super.initState();
    // Glow "breathing": a slow one-shot pulse every ~9 s. One-shot pulses
    // (instead of a forever-repeating controller) keep frame scheduling
    // quiet in between, so widget tests can still settle.
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );
    _pulseTimer = Timer.periodic(const Duration(seconds: 9), (_) {
      if (mounted) _pulse.forward(from: 0);
    });
  }

  @override
  void dispose() {
    _pulseTimer?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final c = _HeroColors.of(dark);
    final statusTop = MediaQuery.of(context).padding.top;

    return SizedBox(
      width: double.infinity,
      child: Stack(
        // Clip.none: the backdrop + watermark paint into [overlapBand] of
        // space that belongs (layout-wise) to the widgets BELOW the hero.
        clipBehavior: Clip.none,
        children: [
          // ── layered backdrop — extended 74px below the hero's layout box
          // so the floating card overlaps the gradient (same visual as the
          // old Transform.translate, but the card's own box is fully
          // tappable now). ──
          Positioned(
            left: 0,
            top: 0,
            right: 0,
            bottom: -MbHeroHeader.overlapBand,
            child: AnimatedBuilder(
              animation: _pulse,
              builder: (context, _) => CustomPaint(
                painter: _HeroBackdropPainter(c, pulse: _pulse.value),
                size: Size.infinite,
              ),
            ),
          ),
          // MoneyBag watermark — brand, half-cropped at the right edge.
          // (bottom: 10 − 74 keeps the exact pre-v2.2.3 visual position.)
          Positioned(
            right: -16,
            bottom: 10 - MbHeroHeader.overlapBand,
            child: Opacity(
              opacity: dark ? 0.20 : 0.16,
              child: MbAppLogo(size: 132, white: dark),
            ),
          ),

          // ── content on the background ──
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: statusTop + 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Row(
                  children: [
                    // profile — LEFT side (per design note)
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 520),
                      curve: Curves.easeOutBack,
                      builder: (context, t, child) => Transform.scale(
                        scale: 0.55 + 0.45 * t,
                        child: Opacity(
                            opacity: t.clamp(0.0, 1.0), child: child),
                      ),
                      child: const MbAvatar(size: 46),
                    ),
                    const Spacer(),
                    // notification bell — RIGHT side
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 460),
                      curve: Curves.easeOutBack,
                      builder: (context, t, child) => Transform.scale(
                        scale: 0.6 + 0.4 * t,
                        child: Opacity(
                            opacity: t.clamp(0.0, 1.0), child: child),
                      ),
                      child: _HeroBellButton(
                        color: c,
                        onTap: widget.onNotificationTap,
                        showDot: widget.showNotificationDot,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // greeting
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 560),
                  curve: Curves.easeOutCubic,
                  builder: (context, t, child) => Opacity(
                    opacity: t.clamp(0.0, 1.0),
                    child: Transform.translate(
                      offset: Offset(0, 14 * (1 - t)),
                      child: child,
                    ),
                  ),
                  child: Text(
                    widget.greeting,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'NotoSansBengali',
                      color: c.text,
                      fontSize: 25,
                      fontWeight: FontWeight.w700,
                      height: 1.15,
                      shadows: dark
                          ? [
                              Shadow(
                                color: Colors.black.withOpacity(0.35),
                                blurRadius: 14,
                              ),
                            ]
                          : null,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 7),
              // tagline
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 620),
                  curve: Curves.easeOutCubic,
                  builder: (context, t, child) => Opacity(
                    opacity: t.clamp(0.0, 1.0),
                    child: Transform.translate(
                      offset: Offset(0, 10 * (1 - t)),
                      child: child,
                    ),
                  ),
                  child: Text(
                    widget.tagline,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'NotoSansBengali',
                      color: c.textDim,
                      fontSize: 13.5,
                      height: 1.4,
                    ),
                  ),
                ),
              ),
              // (No reserved band: the card that follows in the dashboard
              // column overlaps the EXTENDED backdrop painted above.)
            ],
          ),
        ],
      ),
    );
  }
}

/// Circular translucent bell with an unread dot.
class _HeroBellButton extends StatelessWidget {
  final _HeroColors color;
  final VoidCallback? onTap;
  final bool showDot;

  const _HeroBellButton({
    required this.color,
    this.onTap,
    this.showDot = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.iconBg,
            border: Border.all(color: color.iconBorder),
          ),
          child: Stack(
            children: [
              Center(
                child: Icon(
                  Icons.notifications_none_rounded,
                  color: color.icon,
                  size: 24,
                ),
              ),
              if (showDot)
                Positioned(
                  top: 9,
                  right: 10,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: MbPalette.green,
                      shape: BoxShape.circle,
                      border: Border.all(color: color.iconBg, width: 1.5),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Theme-aware hero color set.
class _HeroColors {
  final Color baseTop;
  final Color baseMid;
  final Color baseBottom;
  final Color glowBlue;
  final Color glowCyan;
  final Color glowPurple;
  final Color glowGreen;
  final Color text;
  final Color textDim;
  final Color iconBg;
  final Color iconBorder;
  final Color icon;

  const _HeroColors({
    required this.baseTop,
    required this.baseMid,
    required this.baseBottom,
    required this.glowBlue,
    required this.glowCyan,
    required this.glowPurple,
    required this.glowGreen,
    required this.text,
    required this.textDim,
    required this.iconBg,
    required this.iconBorder,
    required this.icon,
  });

  static _HeroColors of(bool dark) => dark ? _dark : _light;

  static const _dark = _HeroColors(
    baseTop: Color(0xFF101E3C),
    baseMid: Color(0xFF0A1226),
    baseBottom: MbPalette.darkBg,
    glowBlue: Color(0x593B82F6), // 35% blue
    glowCyan: Color(0x3822D3EE), // 22% cyan
    glowPurple: Color(0x4D8B5CF6), // 30% purple
    glowGreen: Color(0x1F2ED573), // 12% green
    text: Colors.white,
    textDim: Color(0xFFB9C4DC),
    iconBg: Color(0x1AFFFFFF), // 10% white
    iconBorder: Color(0x24FFFFFF), // 14% white
    icon: Colors.white,
  );

  static const _light = _HeroColors(
    baseTop: Color(0xFFD8E4FA),
    baseMid: Color(0xFFE7E4FA),
    baseBottom: MbPalette.lightBg,
    glowBlue: Color(0x467AABF7),
    glowCyan: Color(0x3366D9E8),
    glowPurple: Color(0x3FA78BFA),
    glowGreen: Color(0x2E2ECC71),
    text: Color(0xFF0F1E3D),
    textDim: Color(0xFF46587A),
    iconBg: Color(0x1A0F1E3D),
    iconBorder: Color(0x240F1E3D),
    icon: Color(0xFF0F1E3D),
  );
}

/// Paints the atmosphere: base gradient + radial glows + bokeh rings +
/// star dots. `pulse` (0→1→0) gently breathes the glows.
class _HeroBackdropPainter extends CustomPainter {
  final _HeroColors c;
  final double pulse;

  _HeroBackdropPainter(this.c, {this.pulse = 0});

  static const _dots = <Offset>[
    Offset(0.52, 0.06), Offset(0.64, 0.14), Offset(0.78, 0.08),
    Offset(0.88, 0.18), Offset(0.71, 0.28), Offset(0.93, 0.30),
    Offset(0.58, 0.22), Offset(0.83, 0.40), Offset(0.47, 0.14),
    Offset(0.36, 0.07), Offset(0.24, 0.16), Offset(0.15, 0.10),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final breath = 0.85 + 0.30 * math.sin(pulse * math.pi); // 0.85→1.15→0.85

    // ── base gradient, blending into the scaffold background at bottom ──
    final base = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        stops: const [0.0, 0.55, 1.0],
        colors: [c.baseTop, c.baseMid, c.baseBottom],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, base);

    // ── radial glows ──
    void glow(Offset center, double radius, Color color) {
      final p = Paint()
        ..shader = RadialGradient(
          colors: [color, color.withOpacity(0)],
          radius: 1.0,
        ).createShader(Rect.fromCircle(center: center, radius: radius));
      canvas.drawCircle(center, radius, p);
    }

    glow(Offset(w * -0.08, h * 0.18), w * 0.62 * breath, c.glowBlue);
    glow(Offset(w * 0.92, h * 0.42), w * 0.55 * breath, c.glowPurple);
    glow(Offset(w * 0.55, h * 0.30), w * 0.42 * (2 - breath), c.glowCyan);
    glow(Offset(w * 0.12, h * 0.88), w * 0.40, c.glowGreen);

    // ── bokeh rings (thin strokes) ──
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = Colors.white.withOpacity(0.05);
    canvas.drawCircle(Offset(w * 0.86, h * 0.16), 34, ring);
    canvas.drawCircle(Offset(w * 0.80, h * 0.16), 52, ring);
    canvas.drawCircle(Offset(w * 0.06, h * 0.62), 44, ring);
    canvas.drawCircle(Offset(w * 0.30, h * 0.20), 22, ring);

    // ── star dots ──
    final dot = Paint()..color = Colors.white.withOpacity(0.10);
    for (final d in _dots) {
      canvas.drawCircle(Offset(w * d.dx, h * d.dy), 1.6, dot);
    }

    // ── subtle sweep highlight (very soft diagonal light) ──
    final sweep = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        stops: const [0.0, 0.45, 0.7],
        colors: [
          Colors.white.withOpacity(0.045),
          Colors.white.withOpacity(0.0),
          Colors.white.withOpacity(0.0),
        ],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, sweep);
  }

  @override
  bool shouldRepaint(_HeroBackdropPainter old) => old.pulse != pulse;
}
