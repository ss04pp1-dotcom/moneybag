import 'dart:async' show unawaited;
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/palette.dart';
import 'common.dart';

/// v2.1.1 — Shared 4-digit PIN keypad (MoneyBag dark style).
///
/// Used by BOTH the app-lock gate (unlock with backup PIN) and the
/// settings flow (set / change the PIN). Auto-submits at four digits:
/// [onSubmit] must return whether the PIN was correct — on `false` the
/// pad shakes, clears and counts the attempt.
class MbPinPad extends StatefulWidget {
  const MbPinPad({
    super.key,
    required this.title,
    required this.hint,
    required this.onSubmit,
    this.maxAttempts = 5,
    this.onMaxAttempts,
    this.footerLabel,
    this.onFooter,
    this.centerIcon = Icons.dialpad_rounded,
  });

  final String title;
  final String hint;
  final Future<bool> Function(String pin) onSubmit;
  final int maxAttempts;
  final VoidCallback? onMaxAttempts;
  final String? footerLabel;
  final VoidCallback? onFooter;
  final IconData centerIcon;

  @override
  State<MbPinPad> createState() => _MbPinPadState();
}

class _MbPinPadState extends State<MbPinPad>
    with SingleTickerProviderStateMixin {
  String _pin = '';
  int _fails = 0;
  bool _wrong = false;
  bool _busy = false;
  bool _done = false; // suppress pad after success

  late final AnimationController _shake;

  @override
  void initState() {
    super.initState();
    _shake = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
  }

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  Future<void> _digit(String d) async {
    if (_pin.length >= 4 || _busy || _done) return;
    setState(() {
      _pin += d;
      _wrong = false;
    });
    if (_pin.length == 4) {
      // Let the 4th dot paint before verifying.
      await Future<void>.delayed(const Duration(milliseconds: 150));
      if (!mounted) return;
      setState(() => _busy = true);
      final ok = await widget.onSubmit(_pin);
      if (!mounted) return;
      setState(() => _busy = false);
      if (ok) {
        setState(() => _done = true);
        return;
      }
      setState(() {
        _wrong = true;
        _fails++;
        _pin = '';
      });
      unawaited(_shake.forward(from: 0));
      if (_fails >= widget.maxAttempts) widget.onMaxAttempts?.call();
    }
  }

  void _backspace() {
    if (_pin.isEmpty || _busy) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final L = context.L;
    final scheme = Theme.of(context).colorScheme;
    const keyColor = MbPalette.darkText;
    final attemptsLeft = widget.maxAttempts - _fails;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 34),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(widget.centerIcon, size: 26, color: keyColor),
          ),
          const SizedBox(height: 18),
          Text(
            widget.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: MbThemes.fontFamily,
              color: keyColor,
              fontSize: 19,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 20),

          // ── PIN dots (shake when wrong) ──
          AnimatedBuilder(
            animation: _shake,
            builder: (context, child) {
              final t = _shake.value;
              final dx = 10 * math.sin(t * math.pi * 3) * (1 - t);
              return Transform.translate(offset: Offset(dx, 0), child: child!);
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < 4; i++) ...[
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i < _pin.length
                          ? MbPalette.green
                          : Colors.white.withOpacity(0.22),
                    ),
                  ),
                  if (i != 3) const SizedBox(width: 18),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── status line ──
          SizedBox(
            height: 18,
            child: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Text(
                    _wrong
                        ? (attemptsLeft > 0
                            ? '${L.pinWrong} · ${L.pinAttemptsLeft(attemptsLeft)}'
                            : L.pinWrong)
                        : widget.hint,
                    style: TextStyle(
                      fontFamily: MbThemes.fontFamily,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: _wrong
                          ? const Color(0xFFFFB4AB)
                          : MbPalette.darkText.withOpacity(0.55),
                    ),
                  ),
          ),
          const SizedBox(height: 22),

          // ── keypad 3×4 ──
          SizedBox(
            width: 252,
            child: Column(
              children: [
                for (final row in const [
                  ['1', '2', '3'],
                  ['4', '5', '6'],
                  ['7', '8', '9'],
                ]) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      for (final d in row) _key(d, keyColor),
                    ],
                  ),
                  const SizedBox(height: 14),
                ],
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    SizedBox(
                      width: 72,
                      height: 56,
                      child: widget.footerLabel != null
                          ? IconButton(
                              tooltip: widget.footerLabel,
                              onPressed: widget.onFooter,
                              icon: const Icon(Icons.fingerprint_rounded,
                                  size: 28, color: keyColor),
                            )
                          : null,
                    ),
                    _key('0', keyColor),
                    SizedBox(
                      width: 72,
                      height: 56,
                      child: IconButton(
                        onPressed: _backspace,
                        icon: const Icon(Icons.backspace_outlined,
                            size: 24, color: keyColor),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          if (widget.footerLabel != null) ...[
            const SizedBox(height: 18),
            TextButton(
              onPressed: widget.onFooter,
              child: Text(
                widget.footerLabel!,
                style: TextStyle(
                  fontFamily: MbThemes.fontFamily,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: MbPalette.darkText.withOpacity(0.75),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _key(String digit, Color color) {
    return SizedBox(
      width: 72,
      height: 56,
      child: Material(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _digit(digit),
          child: Center(
            child: Text(
              digit,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
