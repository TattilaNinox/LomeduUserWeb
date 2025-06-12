import 'package:flutter/material.dart';

class AppTheme {
  // Színpaletta
  static const Color primaryColor = Color(0xFF1E3A8A); // Mélykék
  static const Color backgroundColor = Color(0xFFF5F5F5); // Világosszürke
  static const Color accentColor = Color(0xFFF97316); // Narancssárga
  static const Color successColor = Color(0xFF22C55E); // Zöld
  static const Color errorColor = Color(0xFFE74C3C); // Piros
  static const Color textColor = Color(0xFF333333); // Sötétszürke szöveg

  // Alap ThemeData
  static ThemeData get lightTheme {
    return ThemeData(
      primaryColor: primaryColor,
      scaffoldBackgroundColor: backgroundColor,
      colorScheme: const ColorScheme.light(
        primary: primaryColor,
        secondary: accentColor,
        error: errorColor,
      ),
      textTheme: const TextTheme(
        displaySmall: TextStyle(
          fontFamily: 'Inter',
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
        bodyMedium: TextStyle(
          fontFamily: 'Inter',
          fontSize: 16,
          color: textColor,
        ),
        labelSmall: TextStyle(
          fontFamily: 'Inter',
          fontSize: 12,
          color: textColor,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }
}
