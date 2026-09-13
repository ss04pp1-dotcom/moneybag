import 'dart:math';

/// Small utilities shared across the app.
abstract final class MbUtils {
  static final Random _rng = Random.secure();

  /// UUID v4 — used for portable row ids (stable across backup/restore).
  static String uuid() {
    final b = List<int>.generate(16, (_) => _rng.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40; // version 4
    b[8] = (b[8] & 0x3f) | 0x80; // variant 10
    String hex(int v) => v.toRadixString(16).padLeft(2, '0');
    final h = b.map(hex).join();
    return '${h.substring(0, 8)}-'
        '${h.substring(8, 12)}-'
        '${h.substring(12, 16)}-'
        '${h.substring(16, 20)}-'
        '${h.substring(20, 32)}';
  }

  static int clampInt(int v, int min, int max) =>
      v < min ? min : (v > max ? max : v);
}
