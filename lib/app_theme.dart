import 'package:flutter/material.dart';

class AppTheme {
  static final ThemeData lightTheme = ThemeData(
    primarySwatch: Colors.blue,
    colorScheme: ColorScheme.fromSwatch(
      primarySwatch: Colors.blue,
    ).copyWith(
      surface: const Color(0xFFF9FAFB),
    ),
  );
} 