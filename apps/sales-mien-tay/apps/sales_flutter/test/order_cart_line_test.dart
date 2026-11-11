import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sales_mien_tay/order_cart_line.dart';

void main() {
  for (final width in [360.0, 390.0, 430.0]) {
    testWidgets('cart row keeps STT, editable qty and compact controls at $width',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 790);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final row = <String, dynamic>{
        'line_id': 'line-one',
        'company_code': '000123',
        'name': 'Bút bi học sinh Futurebook loại hộp lớn',
        'quantity': 1,
        'unit': 'Thùng',
      };
      var removed = false;
      await tester.pumpWidget(MaterialApp(home: Scaffold(
        body: StatefulBuilder(builder: (context, setState) => OrderCartLine(
          key: const ValueKey('line-one'),
          number: 2,
          line: row,
          stockMessage: 'Tồn: 90 Thùng',
          editable: true,
          onQuantity: (qty) => setState(() => row['quantity'] = qty),
          onRemove: () => removed = true,
        )),
      )));
      expect(find.text('02'), findsOneWidget);
      expect(find.textContaining('000123'), findsOneWidget);
      expect(find.text('Tồn: 90 Thùng'), findsOneWidget);
      expect(find.byKey(const ValueKey('cart-minus-line-one')), findsOneWidget);
      expect(find.byKey(const ValueKey('cart-plus-line-one')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('cart-plus-line-one')));
      await tester.pump();
      expect(row['quantity'], 2);
      await tester.tap(find.byKey(const ValueKey('cart-minus-line-one')));
      await tester.pump();
      expect(row['quantity'], 1);
      await tester.enterText(find.byKey(const ValueKey('cart-quantity-line-one')), '25');
      await tester.pump();
      expect(row['quantity'], 25);
      await tester.enterText(find.byKey(const ValueKey('cart-quantity-line-one')), '0');
      await tester.pump();
      expect(row['quantity'], 25);
      expect(find.text('1–100M'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('cart-delete-line-one')));
      await tester.pump();
      expect(removed, true);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('read-only line shows the saved qty and no mutation buttons',
      (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: OrderCartLine(
      number: 1,
      line: const {'line_id': 'line-two', 'quantity': 100000000,
        'company_code': '000007', 'name': 'Tập', 'unit': 'Thùng'},
      stockMessage: 'Chưa có số tồn',
      editable: false,
      onQuantity: (_) => fail('read-only quantity changed'),
      onRemove: () => fail('read-only row removed'),
    ))));
    expect(find.text('SL 100000000'), findsOneWidget);
    expect(find.byKey(const ValueKey('cart-plus-line-two')), findsNothing);
    expect(find.byKey(const ValueKey('cart-delete-line-two')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
