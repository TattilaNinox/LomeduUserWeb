import 'package:flutter/material.dart';

class AppTheme {
  // Brand colors
  static const _primaryColor = Color(0xFF1E3A8A); // blue
  static const _accentColor = Color(0xFFF97316); // orange
  static const _bgColor = Color(0xFFF5F5F5);
  static const _textColor = Color(0xFF333333);
  static const _borderColor = Color(0xFFD1D5DB);
  static const _error = Color(0xFFE74C3C);

  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    fontFamily: 'Inter',
    scaffoldBackgroundColor: _bgColor,
    colorScheme: const ColorScheme(
      brightness: Brightness.light,
      primary: _primaryColor,
      onPrimary: Colors.white,
      secondary: _accentColor,
      onSecondary: Colors.white,
      error: _error,
      onError: Colors.white,
      surface: _bgColor,
      onSurface: _textColor,
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(fontSize: 16, color: _textColor),
      bodyMedium: TextStyle(fontSize: 14, color: _textColor),
      labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _borderColor, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _borderColor, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _primaryColor, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _error, width: 2),
      ),
    ),
    appBarTheme: const AppBarTheme(
      elevation: 0,
      backgroundColor: _primaryColor,
      foregroundColor: Colors.white,
      surfaceTintColor: _primaryColor,
    ),
    chipTheme: ChipThemeData(
      selectedColor: _primaryColor.withValues(alpha: .1),
      disabledColor: _borderColor,
      backgroundColor: Colors.white,
      labelStyle: const TextStyle(color: _textColor, fontSize: 12),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    iconTheme: const IconThemeData(color: Color(0xFF6B7280)),
    dividerTheme: const DividerThemeData(color: _borderColor, thickness: 1),
  );
}
