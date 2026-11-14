import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local visual preference only; business records remain in IndexedDB/SQLite.
class SalesThemePreference {
  static const storageKey = 'field-work-theme-mode';
  static final ValueNotifier<ThemeMode> mode = ValueNotifier(ThemeMode.light);

  static Future<void> restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(storageKey);
      mode.value = saved == 'dark' ? ThemeMode.dark : ThemeMode.light;
    } catch (_) {
      // A blocked preference store must never block sign-in or offline data.
    }
  }

  static Future<void> select(ThemeMode selection) async {
    final chosen = selection == ThemeMode.dark ? ThemeMode.dark : ThemeMode.light;
    mode.value = chosen;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(storageKey, chosen == ThemeMode.dark ? 'dark' : 'light');
    } catch (_) {
      // The visible setting still works for the current app session.
    }
  }
}

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

  static ThemeData build({double width = 390, Brightness brightness = Brightness.light}) {
    final dark = brightness == Brightness.dark;
    // Dark surfaces are derived from the same FBMN purple seed, not a second palette.
    final generated = ColorScheme.fromSeed(seedColor: brand, brightness: brightness);
    final scheme = generated.copyWith(
      primary: dark ? const Color(0xFFB699D1) : brand,
      onPrimary: dark ? const Color(0xFF24132D) : Colors.white,
      surface: dark ? const Color(0xFF16171D) : Colors.white,
      surfaceContainer: dark ? const Color(0xFF202129) : generated.surfaceContainer,
      surfaceContainerLow: dark ? const Color(0xFF1D1E25) : generated.surfaceContainerLow,
      primaryContainer: dark ? const Color(0xFF302538) : generated.primaryContainer,
      onPrimaryContainer: dark ? const Color(0xFFE5D4F1) : generated.onPrimaryContainer,
      outlineVariant: dark ? const Color(0xFF41404A) : generated.outlineVariant,
      error: dark ? const Color(0xFFFFB4AB) : const Color(0xFFB42318),
    );
    final surface = dark ? scheme.surfaceContainerLow : Colors.white;
    final outline = dark ? scheme.outlineVariant : border;
    final heading = dark ? scheme.primaryContainer : tableHeader;
    final headingInk = dark ? scheme.onPrimaryContainer : tableInk;
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
      colorScheme: scheme,
      useMaterial3: true,
      scaffoldBackgroundColor: dark ? scheme.surface : canvas,
      filledButtonTheme: FilledButtonThemeData(style: control),
      outlinedButtonTheme: OutlinedButtonThemeData(style: control),
      textButtonTheme: TextButtonThemeData(style: control),
      elevatedButtonTheme: ElevatedButtonThemeData(style: control),
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        constraints: const BoxConstraints(minHeight: fieldHeight),
        labelStyle: TextStyle(fontSize: controlFontSize, color: scheme.onSurfaceVariant),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(controlRadius)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(controlRadius),
          borderSide: BorderSide(color: outline)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(controlRadius),
          borderSide: BorderSide(color: scheme.primary, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      cardTheme: CardThemeData(
        elevation: 0, color: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: outline)),
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStatePropertyAll(heading),
        headingTextStyle: TextStyle(color: headingInk,
          fontWeight: FontWeight.w700, fontSize: 13),
        dataTextStyle: TextStyle(color: scheme.onSurface),
        dividerThickness: 1,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: dark ? scheme.surfaceContainer : heading,
        foregroundColor: dark ? scheme.onSurface : headingInk,
        scrolledUnderElevation: 0,
      ),
      // Shared FBMN tab style: same 13px controls, lavender active surface and 9px radius.
      tabBarTheme: TabBarThemeData(
        labelColor:scheme.primary,
        unselectedLabelColor:scheme.onSurfaceVariant,
        labelStyle:const TextStyle(fontSize:controlFontSize,fontWeight:FontWeight.w700),
        unselectedLabelStyle:const TextStyle(fontSize:controlFontSize),
        indicator:BoxDecoration(color:heading,borderRadius:BorderRadius.circular(controlRadius)),
        indicatorSize:TabBarIndicatorSize.tab,
        dividerColor:Colors.transparent,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: heading,
        labelTextStyle: const WidgetStatePropertyAll(
          TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      ),
      dividerTheme: DividerThemeData(color: outline),
    );
  }
}
