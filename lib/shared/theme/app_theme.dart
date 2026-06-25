import 'package:flutter/material.dart';

/// Centralized design tokens for the app. Keep all colors, gradients, and
/// shape constants in this file so screens stay consistent.
class AppTheme {
  // Brand
  static const Color primary = Color(0xFF1D9E75);
  static const Color primaryDark = Color(0xFF157A5B);
  static const Color accent = Color(0xFF38BDF8);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);

  // Surfaces
  static const Color lightBackground = Color(0xFFF8F9FA);
  static const Color darkBackground = Color(0xFF0F1117);
  static const Color lightSurface = Colors.white;
  static const Color darkSurface = Color(0xFF1A1D27);

  // Text
  static const Color textPrimary = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF6B7280);

  // Gradients
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1D9E75), Color(0xFF38BDF8)],
  );

  static const LinearGradient successGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1D9E75), Color(0xFF22C55E)],
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFF8F9FA), Color(0xFFE8F8F1)],
  );

  // Radii
  static const double radiusS = 8;
  static const double radiusM = 14;
  static const double radiusL = 20;
  static const double radiusXL = 28;

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: brightness,
      primary: primary,
      surface: isDark ? darkSurface : lightSurface,
      error: error,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: isDark ? darkBackground : lightBackground,
      fontFamily: 'Roboto',
      cardTheme: CardThemeData(
        color: isDark ? darkSurface : lightSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusL),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? darkSurface : lightSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusM),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusM),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusM),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: primary),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: isDark ? darkSurface : lightSurface,
        selectedItemColor: primary,
        unselectedItemColor: textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF111827),
        contentTextStyle: const TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusM),
        ),
      ),
    );
  }
}
