import 'package:flutter/material.dart';

/// XploreMY design system.
///
/// Palette is drawn from Malaysian transit line colours: a deep "track" navy,
/// a hibiscus red accent and a warm sand background. Everything else in the
/// app reads from this theme — no ad-hoc colours in widgets.
class AppTheme {
  static const Color trackNavy = Color(0xFF0B2545);
  static const Color signalTeal = Color(0xFF00857C);
  static const Color hibiscus = Color(0xFFD62839);
  static const Color sand = Color(0xFFF7F4EE);
  static const Color slate = Color(0xFF5A6472);
  static const Color onTime = Color(0xFF1B8A5A);
  static const Color delayed = Color(0xFFE07A00);

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: trackNavy,
      primary: trackNavy,
      secondary: signalTeal,
      tertiary: hibiscus,
      surface: Colors.white,
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: sand,
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        backgroundColor: trackNavy,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          letterSpacing: -0.2,
        ),
      ),
      cardTheme: CardTheme(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0x14000000)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0x22000000)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0x22000000)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: signalTeal, width: 1.6),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: trackNavy,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: trackNavy,
          minimumSize: const Size.fromHeight(52),
          side: const BorderSide(color: Color(0x330B2545)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      chipTheme: const ChipThemeData(
        side: BorderSide(color: Color(0x1A000000)),
        backgroundColor: Colors.white,
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: slate,
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
