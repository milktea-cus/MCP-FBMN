import 'package:flutter/material.dart';

/// FBMN common UI contract 2026-11-03; source archived in standards/ui-fbmn.
class SalesTheme {
  static const brand = Color(0xFF6D249E);
  static const brandHover = Color(0xFF572080);
  static const canvas = Color(0xFFF7F8FC);
  static const ink = Color(0xFF20223B);
  static const border = Color(0xFFE4E7EF);
  static const tableHeader = Color(0xFFF4EDFA);
  static const tableInk = Color(0xFF43215F);
  static const caution = Color(0xFFAD6317);
  static const controlRadius = 9.0;
  static const fieldHeight = 40.0;
  static const controlFontSize = 13.0;
  static const mobileBreakpoint = 780.0;
  static const buttonMotion = Duration(milliseconds: 190);

  static double buttonHeight(double width) => width <= mobileBreakpoint ? 44 : 36;

  static ThemeData build({double width = 390}) {
    final scheme = ColorScheme.fromSeed(
      seedColor: brand, brightness: Brightness.light, surface: Colors.white,
    ).copyWith(primary: brand, onPrimary: Colors.white, error: const Color(0xFFB42318));
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(controlRadius));
    final control = ButtonStyle(
      minimumSize: WidgetStatePropertyAll(Size(0, buttonHeight(width))),
      padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 12)),
      textStyle: const WidgetStatePropertyAll(TextStyle(fontSize: controlFontSize, fontWeight: FontWeight.w600)),
      shape: WidgetStatePropertyAll(shape),
      animationDuration: buttonMotion,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
    return ThemeData(
      colorScheme: scheme, useMaterial3: true, scaffoldBackgroundColor: canvas,
      filledButtonTheme: FilledButtonThemeData(style: control),
      outlinedButtonTheme: OutlinedButtonThemeData(style: control),
      textButtonTheme: TextButtonThemeData(style: control),
      elevatedButtonTheme: ElevatedButtonThemeData(style: control),
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        constraints: const BoxConstraints(minHeight: fieldHeight),
        labelStyle: const TextStyle(fontSize: controlFontSize),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(controlRadius)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(controlRadius), borderSide: const BorderSide(color: border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(controlRadius), borderSide: const BorderSide(color: brand, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      cardTheme: CardThemeData(
        elevation: 0, color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: border)),
      ),
      dataTableTheme: const DataTableThemeData(
        headingRowColor: WidgetStatePropertyAll(tableHeader),
        headingTextStyle: TextStyle(color: tableInk, fontWeight: FontWeight.w700, fontSize: 13),
      ),
      appBarTheme: const AppBarTheme(backgroundColor: tableHeader, foregroundColor: tableInk, scrolledUnderElevation: 0),
      navigationBarTheme: const NavigationBarThemeData(backgroundColor: Colors.white,indicatorColor: tableHeader, labelTextStyle: WidgetStatePropertyAll(TextStyle(fontSize:12,fontWeight:FontWeight.w600))),
    );
  }
}
