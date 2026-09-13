import 'package:flutter/material.dart';

import 'palette.dart';

/// MoneyBag Material 3 themes.
///
/// Dark (default) — premium deep navy-black, MoneyBag Green accent.
/// Light — mist background, mint cards.
///
/// v2.1: [fromDynamic] builds a theme from a Material You (Android 12+)
/// wallpaper scheme, keeping the MoneyBag typography & shapes; on older
/// Android the fixed brand themes above are used as before.
class MbThemes {
  static const String fontFamily = 'NotoSansBengali';

  /// Material You variant — surfaces follow the user's wallpaper colors,
  /// while fonts, radii and component shapes stay MoneyBag. The incoming
  /// scheme already carries the correct brightness (light/dark).
  static ThemeData fromDynamic(ColorScheme scheme) {
    final bg = scheme.surface;
    final fg = scheme.onSurface;
    return _base(scheme).copyWith(
      scaffoldBackgroundColor: bg,
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        foregroundColor: fg,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
      dividerColor: scheme.outlineVariant,
    );
  }

  static ThemeData dark() {
    const scheme = ColorScheme.dark(
      primary: MbPalette.green,
      onPrimary: Color(0xFF06130C),
      primaryContainer: Color(0xFF123649), // deep teal-navy
      onPrimaryContainer: Color(0xFFC9F0FF),
      secondary: MbPalette.income,
      onSecondary: Color(0xFF06130C),
      secondaryContainer: Color(0xFF1A2742), // navy
      onSecondaryContainer: Color(0xFFC9D6F2),
      tertiary: MbPalette.violet,
      onTertiary: Color(0xFF150E2E),
      error: MbPalette.expense,
      onError: Color(0xFF2B0A0A),
      errorContainer: Color(0xFF54201F),
      onErrorContainer: Color(0xFFFFD5D2),
      surface: MbPalette.darkSurface,
      onSurface: MbPalette.darkText,
      surfaceContainerHighest: MbPalette.darkSurfaceHi,
      onSurfaceVariant: MbPalette.darkMuted,
      outline: MbPalette.darkMuted,
      outlineVariant: MbPalette.darkOutline,
      inverseSurface: MbPalette.lightText,
      onInverseSurface: MbPalette.lightBg,
      scrim: Colors.black,
    );

    return _base(scheme).copyWith(
      scaffoldBackgroundColor: MbPalette.darkBg,
      appBarTheme: const AppBarTheme(
        backgroundColor: MbPalette.darkBg,
        foregroundColor: MbPalette.darkText,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: MbPalette.darkText,
        ),
      ),
      dividerColor: MbPalette.darkOutline,
    );
  }

  static ThemeData light() {
    const scheme = ColorScheme.light(
      primary: MbPalette.greenDeep,
      onPrimary: Colors.white,
      primaryContainer: MbPalette.lightMint,
      onPrimaryContainer: Color(0xFF0F3D24),
      secondary: Color(0xFF148F62),
      onSecondary: Colors.white,
      secondaryContainer: Color(0xFFD8F3E3),
      onSecondaryContainer: Color(0xFF0F3D2C),
      tertiary: Color(0xFF7C5CD6),
      onTertiary: Colors.white,
      error: Color(0xFFC94040),
      onError: Colors.white,
      errorContainer: Color(0xFFFFE3E0),
      onErrorContainer: Color(0xFF4A1512),
      surface: MbPalette.lightSurface,
      onSurface: MbPalette.lightText,
      surfaceContainerHighest: MbPalette.lightMint,
      onSurfaceVariant: MbPalette.lightMuted,
      outline: MbPalette.lightMuted,
      outlineVariant: MbPalette.lightOutline,
      inverseSurface: MbPalette.lightText,
      onInverseSurface: MbPalette.lightBg,
    );

    return _base(scheme).copyWith(
      scaffoldBackgroundColor: MbPalette.lightBg,
      appBarTheme: const AppBarTheme(
        backgroundColor: MbPalette.lightBg,
        foregroundColor: MbPalette.lightText,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: MbPalette.lightText,
        ),
      ),
      dividerColor: MbPalette.lightOutline,
    );
  }

  static ThemeData _base(ColorScheme scheme) {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: fontFamily,
      visualDensity: VisualDensity.standard,
    );

    final radius = BorderRadius.circular(16);
    final pill = BorderRadius.circular(999);

    return base.copyWith(
      textTheme: base.textTheme.apply(
        fontFamily: fontFamily,
        bodyColor: scheme.onSurface,
        displayColor: scheme.onSurface,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          minimumSize: const Size(64, 52),
          shape: RoundedRectangleBorder(borderRadius: pill),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.primary,
          minimumSize: const Size(64, 52),
          shape: RoundedRectangleBorder(borderRadius: pill),
          side: BorderSide(color: scheme.primary),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          elevation: 0,
          minimumSize: const Size(64, 52),
          shape: RoundedRectangleBorder(borderRadius: pill),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest,
        hintStyle: TextStyle(color: scheme.onSurfaceVariant),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: scheme.error, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: scheme.error, width: 1.8),
        ),
      ),
      cardTheme: CardTheme(
        color: scheme.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: scheme.outlineVariant),
        ),
        margin: EdgeInsets.zero,
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: scheme.surfaceContainerHighest,
        selectedColor: scheme.primary,
        labelStyle: TextStyle(
          fontFamily: fontFamily,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
        secondaryLabelStyle: TextStyle(
          fontFamily: fontFamily,
          fontWeight: FontWeight.w600,
          color: scheme.onPrimaryContainer,
        ),
        side: BorderSide(color: scheme.outlineVariant),
        shape: RoundedRectangleBorder(borderRadius: pill),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        modalBackgroundColor: scheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        showDragHandle: true,
      ),
      dialogTheme: DialogTheme(
        backgroundColor: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
        contentTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 14.5,
          color: scheme.onSurfaceVariant,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: TextStyle(
          fontFamily: fontFamily,
          color: scheme.onInverseSurface,
          fontWeight: FontWeight.w600,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return scheme.onPrimary;
          return scheme.outline;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return scheme.primary;
          return scheme.surfaceContainerHighest;
        }),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: pill)),
          side: const WidgetStatePropertyAll(BorderSide(style: BorderStyle.none)),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return scheme.primary;
            return scheme.surfaceContainerHighest;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return scheme.onPrimary;
            return scheme.onSurfaceVariant;
          }),
          textStyle: const WidgetStatePropertyAll(
            TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w700),
          ),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.surfaceContainerHighest,
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: scheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        headerBackgroundColor: scheme.primary,
        headerForegroundColor: scheme.onPrimary,
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      tabBarTheme: base.tabBarTheme.copyWith(
        labelColor: scheme.primary,
        unselectedLabelColor: scheme.onSurfaceVariant,
        indicatorColor: scheme.primary,
        dividerColor: scheme.outlineVariant,
        labelStyle: const TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w700),
        unselectedLabelStyle: const TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w500),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: null,
      ),
    );
  }
}
