import 'package:flutter/material.dart';

/// MoneyBag animation toolkit — tasteful, reusable motion.
///
/// Everything here uses Flutter's built-in animation framework only
/// (no external packages):
///  * [MbFadeSlideIn]   — staggered entrance for lists/cards
///  * [MbCountUp]       — number roll-up for money values
///  * [MbPressable]     — press-scale feedback for any tappable
///  * [MbFadeRoute]     — fade + slide page transition
///  * [MbNav]           — one-line navigation helper using [MbFadeRoute]
///  * [MbDotIndicator]  — animated dots for banners/carousels
///  * [MbScaleIn]       — pop-in entrance for emojis/avatars/heroes

/// Entrance animation: fade + slide-up with an optional stagger index.
class MbFadeSlideIn extends StatefulWidget {
  final Widget child;
  final int index; // stagger position (delay = index * 55ms)
  final Duration duration;
  final double offsetY;

  const MbFadeSlideIn({
    super.key,
    required this.child,
    this.index = 0,
    this.duration = const Duration(milliseconds: 420),
    this.offsetY = 22,
  });

  @override
  State<MbFadeSlideIn> createState() => _MbFadeSlideInState();
}

class _MbFadeSlideInState extends State<MbFadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    final delay = Duration(milliseconds: 55 * widget.index.clamp(0, 12));
    _anim = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    Future.delayed(delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, child) {
        return Opacity(
          opacity: _anim.value,
          child: Transform.translate(
            offset: Offset(0, widget.offsetY * (1 - _anim.value)),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// Rolls a value from 0 up to [value], re-formatting on every frame.
class MbCountUp extends StatelessWidget {
  final int value; // minor units
  final String Function(int) formatter;
  final Duration duration;
  final TextStyle? style;

  const MbCountUp({
    super.key,
    required this.value,
    required this.formatter,
    this.duration = const Duration(milliseconds: 850),
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Text(
        formatter(v.round()),
        style: style,
      ),
    );
  }
}

/// Press feedback: scales down slightly while pressed, springs back.
class MbPressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final void Function()? onLongPress;
  final double pressedScale;
  final BorderRadius? borderRadius;

  const MbPressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.pressedScale = 0.97,
    this.borderRadius,
  });

  @override
  State<MbPressable> createState() => _MbPressableState();
}

class _MbPressableState extends State<MbPressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onLongPress: widget.onLongPress,
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? widget.pressedScale : 1.0,
        duration: const Duration(milliseconds: 130),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Page route with a fade + subtle rise transition.
class MbFadeRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  MbFadeRoute({required this.page, super.fullscreenDialog})
      : super(
          transitionDuration: const Duration(milliseconds: 320),
          reverseTransitionDuration: const Duration(milliseconds: 240),
          pageBuilder: (_, __, ___) => page,
          transitionsBuilder: (_, animation, __, child) {
            final curved =
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
            return FadeTransition(
              opacity: curved,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.025),
                  end: Offset.zero,
                ).animate(curved),
                child: child,
              ),
            );
          },
        );
}

/// One-line navigation with the MoneyBag fade transition.
abstract final class MbNav {
  static Future<T?> push<T extends Object?>(BuildContext context, Widget page,
      {bool fullscreenDialog = false}) {
    return Navigator.of(context).push(MbFadeRoute<T>(
      page: page,
      fullscreenDialog: fullscreenDialog,
    ));
  }
}

/// Animated dots page indicator for banners/carousels.
class MbDotIndicator extends StatelessWidget {
  final int count;
  final int active;
  final Color? activeColor;
  final Color? inactiveColor;

  const MbDotIndicator({
    super.key,
    required this.count,
    required this.active,
    this.activeColor,
    this.inactiveColor,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == active ? 18 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: i == active
                  ? (activeColor ?? scheme.primary)
                  : (inactiveColor ??
                      scheme.onSurfaceVariant.withOpacity(0.35)),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
      ],
    );
  }
}

/// Pop-in entrance: scales up from [beginScale] with a soft overshoot
/// (easeOutBack). Playful but restrained — for empty-state emojis,
/// avatars and small hero moments. One-shot on first build.
class MbScaleIn extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final double beginScale;

  const MbScaleIn({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 420),
    this.beginScale = 0.55,
  });

  @override
  State<MbScaleIn> createState() => _MbScaleInState();
}

class _MbScaleInState extends State<MbScaleIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _anim = CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, child) => Transform.scale(
        scale: widget.beginScale + (1 - widget.beginScale) * _anim.value,
        child: child,
      ),
      child: widget.child,
    );
  }
}
