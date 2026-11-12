import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sales_mien_tay/customers.dart';
import 'package:sales_mien_tay/inventory_import.dart';

void main() {
  testWidgets('SKU import opens the product or stock workflow explicitly',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final service = CustomerService('https://example.test', '');
    await tester.pumpWidget(MaterialApp(home: InventoryImportHubPage(
      service: service,
    )));
    expect(find.byKey(const Key('import-products')), findsOneWidget);
    expect(find.byKey(const Key('import-stock')), findsOneWidget);

    await tester.tap(find.byKey(const Key('import-products')));
    await tester.pumpAndSettle();
    expect(find.byType(InventoryImportPage), findsOneWidget);
    expect(tester.widget<SegmentedButton<bool>>(
      find.byType(SegmentedButton<bool>)).selected, {true});
    expect(find.text('Chọn file'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('import-stock')));
    await tester.pumpAndSettle();
    expect(tester.widget<SegmentedButton<bool>>(
      find.byType(SegmentedButton<bool>)).selected, {false});
    expect(find.text('Chọn file'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
