import 'package:flutter/material.dart';

/// MoneyBag design tokens — from UI/UX spec v1.0.
///
/// Dark premium: deep NAVY background with blue/cyan/purple glows and
/// MoneyBag Green accents (the 1.3.x “night sky” look). Light: soft mist
/// background with pale mint cards.
abstract final class MbPalette {
  // ── Brand ────────────────────────────────────────────────────────────────
  static const Color green = Color(0xFF2ED573); // MoneyBag Green (dark theme)
  static const Color greenDeep = Color(0xFF2ECC71); // Light theme primary
  static const Color greenDark = Color(0xFF1B7A4A);

  // ── Brand accents (hero atmosphere, floating cards, charts) ───────────
  static const Color cyan = Color(0xFF22D3EE);
  static const Color blue = Color(0xFF3B82F6);
  static const Color purple = Color(0xFF8B5CF6);
  static const Color violet = Color(0xFFA78BFA);

  // ── Dark theme (deep navy — the 1.3.x look) ───────────────────────────
  static const Color darkBg = Color(0xFF050914);
  static const Color darkSurface = Color(0xFF0C1424);
  static const Color darkSurfaceHi = Color(0xFF141F36);
  static const Color darkText = Color(0xFFF2F5FA);
  static const Color darkMuted = Color(0xFF8D99B0);
  static const Color darkOutline = Color(0x14FFFFFF); // 8% white

  // ── Light theme ──────────────────────────────────────────────────────────
  static const Color lightBg = Color(0xFFF8FAF9);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightMint = Color(0xFFE8F5E9);
  static const Color lightText = Color(0xFF14261C);
  static const Color lightMuted = Color(0xFF5B6E62);
  static const Color lightOutline = Color(0x14262624); // 8% ink

  // ── Semantic ─────────────────────────────────────────────────────────────
  static const Color expense = Color(0xFFFF6B6B); // soft coral red
  static const Color income = Color(0xFF4DD598); // fresh green
  static const Color warning = Color(0xFFFFC046); // amber
  static const Color danger = Color(0xFFE85B5B);

  // ── Category accent values (stored as ARGB ints) ─────────────────────────
  static const int food = 0xFFFFA94D; // orange
  static const int transport = 0xFF4DABF7; // blue
  static const int entertainment = 0xFFB197FC; // purple
  static const int bills = 0xFF74C0FC; // sky
  static const int shopping = 0xFFF783AC; // pink
  static const int health = 0xFF63E6BE; // mint
  static const int education = 0xFFFFD43B; // yellow
  static const int groceries = 0xFFA9E34B; // lime
  static const int personal = 0xFFCED4DA; // silver
  static const int salary = 0xFF2ECC71; // green
  static const int freelance = 0xFF66D9E8; // cyan
  static const int other = 0xFF9AA8A0; // grey-green

  /// Fixed palette offered in the category color picker.
  static const List<int> pickerColors = <int>[
    food,
    transport,
    entertainment,
    bills,
    shopping,
    health,
    education,
    groceries,
    0xFFF4978E, // peach
    0xFF8CE99A, // pale green
    0xFF66D9E8, // cyan
    0xFFFAB005, // amber
    salary,
    other,
  ];

  /// Emoji set offered in the category icon picker.
  static const List<String> pickerIcons = <String>[
    '🍛', '🍔', '☕', '🚌', '🚗', '🛺', '🎬', '🎮', '🎵', '📱',
    '💡', '🏠', '🧾', '🛍️', '👕', '💊', '🏥', '📚', '✏️', '🎓',
    '🥬', '🛒', '✈️', '🏝️', '🎁', '💰', '💵', '🏦', '📈', '💼',
    '🐷', '🎯', '❤️', '🐾', '🧹', '🧴', '⚽', '🚲', '⛽', '🔧',
  ];
}
