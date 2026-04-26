import 'package:flutter/material.dart';

/// Rita uses a bright, friendly kid-facing palette. Big rounded corners,
/// chunky typography, high-contrast colors safe for 3–8-year-olds.
class AppTheme {
  static const Color sunny = Color(0xFFFFC857);
  static const Color sky = Color(0xFF63B4D1);
  static const Color berry = Color(0xFFFF6B9D);
  static const Color leaf = Color(0xFF8AC926);
  static const Color cream = Color(0xFFFFF7E8);
  static const Color ink = Color(0xFF2B2D42);

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: sunny,
          brightness: Brightness.light,
          primary: sunny,
          secondary: berry,
          tertiary: sky,
        ),
        scaffoldBackgroundColor: cream,
        textTheme: const TextTheme(
          displayLarge: TextStyle(
            fontWeight: FontWeight.w900,
            color: ink,
            letterSpacing: -0.5,
          ),
          headlineLarge: TextStyle(
            fontWeight: FontWeight.w800,
            color: ink,
            fontSize: 32,
          ),
          headlineMedium: TextStyle(
            fontWeight: FontWeight.w700,
            color: ink,
            fontSize: 24,
          ),
          titleLarge: TextStyle(
            fontWeight: FontWeight.w700,
            color: ink,
            fontSize: 20,
          ),
          bodyLarge: TextStyle(color: ink, fontSize: 16),
          bodyMedium: TextStyle(color: ink, fontSize: 14),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
            textStyle: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
}
