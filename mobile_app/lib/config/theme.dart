import 'package:flutter/material.dart';

/// Colours taken from the Figma screens.
class AppColors {
  static const bg = Color(0xFFFCF8F5);
  static const ink = Color(0xFF201C24);
  static const red = Color(0xFFC81E2D);
  static const teal = Color(0xFF0E7C6B);
  static const orange = Color(0xFFB4510B);
  static const border = Color(0xFFDCD6DD);
  static const muted = Color(0xFF6B6570);
}

ThemeData buildTheme() {
  final pill = RoundedRectangleBorder(borderRadius: BorderRadius.circular(26));
  OutlineInputBorder field(Color c) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: c));
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: AppColors.red),
    scaffoldBackgroundColor: AppColors.bg,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.bg,
      foregroundColor: AppColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
          fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.ink),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.ink,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(54),
        shape: pill,
        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.ink,
        minimumSize: const Size.fromHeight(54),
        shape: pill,
        side: const BorderSide(color: AppColors.ink, width: 1.2),
        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.red,
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: field(AppColors.border),
      enabledBorder: field(AppColors.border),
      focusedBorder: field(AppColors.ink),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.all(Colors.white),
      trackColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected) ? AppColors.teal : AppColors.border),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    ),
  );
}
