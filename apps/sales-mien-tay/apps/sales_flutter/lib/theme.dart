import 'package:flutter/material.dart';

/// Bộ token tạm thời - CHƯA phải UI chuẩn FBMN (source repo FBMN hiện rỗng).
/// Thay lớp này bằng token chính thức khi có nguồn hợp lệ.
class SalesTheme {
  static const brand = Color(0xFF126B59);
  static const canvas = Color(0xFFF6F8F7);
  static const caution = Color(0xFFAD6317);
  static ThemeData build() {
    final scheme = ColorScheme.fromSeed(
      seedColor: brand,
      brightness: Brightness.light,
      surface: Colors.white,
    );
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      scaffoldBackgroundColor: canvas,
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFE4EAE6)),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: canvas,
        foregroundColor: Color(0xFF143D35),
        scrolledUnderElevation: 0,
      ),
    );
  }
}