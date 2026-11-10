import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sales_mien_tay/theme.dart';

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
}
