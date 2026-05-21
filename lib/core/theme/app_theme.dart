// lib/core/theme/app_theme.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Brand
  static const brand = Color(0xFF1A5C38);
  static const brandLight = Color(0xFFE8F5EE);
  static const brandMid = Color(0xFF2D7A4F);

  static const gold = Color(0xFFC9962A);
  static const goldLight = Color(0xFFFDF3DC);

  static const danger = Color(0xFFC0392B);
  static const dangerLight = Color(0xFFFDECEA);

  static const info = Color(0xFF1A6FA3);
  static const infoLight = Color(0xFFE6F2FB);

  static const warn = Color(0xFFB56B00);
  static const warnLight = Color(0xFFFFF4E0);

  // Neutrals
  static const bg = Color(0xFFFFFFFF);
  static const bg2 = Color(0xFFF6F7F9);
  static const bg3 = Color(0xFFFAFBFC);
  static const text = Color(0xFF1A1F2C);
  static const muted = Color(0xFF6B7280);
  static const border = Color(0xFFE5E7EB);
}

class AppTheme {
  static ThemeData light() {
    final textTheme = GoogleFonts.interTextTheme(
      const TextTheme(
        displayLarge: TextStyle(color: AppColors.text),
        bodyMedium: TextStyle(color: AppColors.text),
      ),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.bg3,
      colorScheme: const ColorScheme.light(
        primary: AppColors.brand,
        secondary: AppColors.gold,
        error: AppColors.danger,
        surface: AppColors.bg,
      ),
      textTheme: textTheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.bg,
        foregroundColor: AppColors.text,
        elevation: 0,
        scrolledUnderElevation: 0.5,
      ),
      cardTheme: CardTheme(
        color: AppColors.bg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.border, width: 0.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.brand,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.bg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.brand, width: 1.5),
        ),
      ),
    );
  }
}