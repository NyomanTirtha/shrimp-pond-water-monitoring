// ============================================================
// Theme: AppTheme
// Aquatic blue/white design system
// ============================================================

import 'package:flutter/material.dart';

class AppTheme {
  // ── Brand colours ─────────────────────────────────────────
  static const Color primaryBlue = Color(0xFF0077B6);
  static const Color lightBlue = Color(0xFF00B4D8);
  static const Color accentTeal = Color(0xFF48CAE4);
  static const Color surfaceBlue = Color(0xFFE8F4F8);
  static const Color backgroundLight = Color(0xFFF0F8FF);
  static const Color cardWhite = Color(0xFFFFFFFF);
  static const Color textDark = Color(0xFF023E8A);
  static const Color textGray = Color(0xFF6B7C93);

  // ── Status colours ────────────────────────────────────────
  static const Color statusSafe = Color(0xFF2ECC71);
  static const Color statusWarning = Color(0xFFF39C12);
  static const Color statusDanger = Color(0xFFE74C3C);

  // ── Gradient ─────────────────────────────────────────────
  static const LinearGradient headerGradient = LinearGradient(
    colors: [primaryBlue, lightBlue],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ── ThemeData ─────────────────────────────────────────────
  static ThemeData get theme => ThemeData(
        useMaterial3: true,
        fontFamily: 'Poppins',
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryBlue,
          primary: primaryBlue,
          secondary: lightBlue,
          surface: backgroundLight,
        ),
        scaffoldBackgroundColor: backgroundLight,
        appBarTheme: const AppBarTheme(
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          titleTextStyle: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        cardTheme: CardThemeData(
          color: cardWhite,
          elevation: 4,
          shadowColor: primaryBlue.withOpacity(0.15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: cardWhite,
          selectedItemColor: primaryBlue,
          unselectedItemColor: textGray,
          selectedLabelStyle: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
          unselectedLabelStyle: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 11,
          ),
          showUnselectedLabels: true,
          elevation: 12,
        ),
      );
}
