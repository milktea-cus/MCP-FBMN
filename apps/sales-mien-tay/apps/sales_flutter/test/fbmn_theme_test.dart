import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sales_mien_tay/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('FBMN common control tokens', () {
    expect(SalesTheme.brand, const Color(0xFF6D249E));
    expect(SalesTheme.tableHeader, const Color(0xFFF4EDFA));
    expect(SalesTheme.buttonHeight(390), 44);
    expect(SalesTheme.buttonHeight(1440), 36);
    expect(SalesTheme.fieldHeight, 40);
    expect(SalesTheme.controlRadius, 9);
    expect(SalesTheme.controlFontSize, 13);
    expect(SalesTheme.buttonMotion.inMilliseconds, 190);
    expect(SalesTheme.build(width: 1440).filledButtonTheme.style!.minimumSize!.resolve({})!.height, 36);
  });

  test('light and dark retain FBMN tokens and readable surface contrast', () {
    final light = SalesTheme.build(width: 390);
    final dark = SalesTheme.build(width: 390, brightness: Brightness.dark);
    expect(light.colorScheme.primary, SalesTheme.brand);
    expect(light.colorScheme.brightness, Brightness.light);
    expect(dark.colorScheme.brightness, Brightness.dark);
    expect(dark.scaffoldBackgroundColor, isNot(light.scaffoldBackgroundColor));
    expect(dark.cardTheme.color, isNot(Colors.white));
    expect(dark.dataTableTheme.headingTextStyle!.color, dark.colorScheme.onPrimaryContainer);
    expect(dark.appBarTheme.foregroundColor, dark.colorScheme.onSurface);
    expect(dark.filledButtonTheme.style!.minimumSize!.resolve({})!.height, 44);
  });

  test('prospect action colors remain visible in both themes', () {
    double contrast(Color a, Color b) {
      final aL = a.computeLuminance();
      final bL = b.computeLuminance();
      final lighter = aL > bL ? aL : bL;
      final darker = aL > bL ? bL : aL;
      return (lighter + 0.05) / (darker + 0.05);
    }

    for (final brightness in [Brightness.light, Brightness.dark]) {
      final colors = SalesTheme.build(width: 390, brightness: brightness).colorScheme;
      // MarketProspectsPage: refresh uses onSurface/surfaceContainerHighest;
      // Add uses onPrimary/primary. Both must remain readable on iOS PWA.
      expect(contrast(colors.onSurface, colors.surfaceContainerHighest),
          greaterThanOrEqualTo(4.5));
      expect(contrast(colors.onPrimary, colors.primary),
          greaterThanOrEqualTo(4.5));
      expect(contrast(colors.onSurfaceVariant, colors.surfaceContainerHighest),
          greaterThanOrEqualTo(3.0));
    }
  });

  test('theme preference survives restoration', () async {
    SharedPreferences.setMockInitialValues({});
    await SalesThemePreference.select(ThemeMode.dark);
    expect(SalesThemePreference.mode.value, ThemeMode.dark);
    SalesThemePreference.mode.value = ThemeMode.light;
    await SalesThemePreference.restore();
    expect(SalesThemePreference.mode.value, ThemeMode.dark);
    await SalesThemePreference.select(ThemeMode.light);
  });
}
