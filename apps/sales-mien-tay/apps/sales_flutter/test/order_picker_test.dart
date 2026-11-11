import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sales_mien_tay/actuals.dart';
import 'package:sales_mien_tay/offline_queue.dart';
import 'package:sales_mien_tay/order_picker.dart';
import 'package:sales_mien_tay/session.dart';

class PickerQueue extends OfflineQueue {
  final saved = <String, List<Map<String, dynamic>>>{};
  PickerQueue(): super(SalesSession(), 'sales-a', 'scope-7');
  @override
  Future<List<Map<String, dynamic>>> cached(String key) async => saved[key] ?? [];
  @override
  Future<void> cache(String key, List<Map<String, dynamic>> rows) async {
    saved[key] = [for (final row in rows) Map<String, dynamic>.from(row)];
  }
}

Map<String, dynamic> product(String code, String name, {String? quantity = '24'}) => {
  'id': '11111111-1111-4111-8111-111111111111',
  'company_code': code, 'sku': 'S-$code', 'name': name,
  'brand': 'Futurebook', 'unit': 'Thùng', 'quantity': quantity,
  'snapshot_at': DateTime.now().toUtc().toIso8601String(),
};

Widget pickerHarness(PickerQueue queue, http.Client mock, {
  String type = 'products',
  void Function(Map<String, dynamic>?)? selected,
}) => MaterialApp(home: Scaffold(
  body: Builder(builder: (context) => Center(child: FilledButton(
    onPressed: () async {
      final row = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (_) => OrderPicker(
          client: ActualClient(queue, client: mock),
          queue: queue,
          type: type,
        ),
      );
      selected?.call(row);
    },
    child: const Text('Mở chọn hàng'),
  ))),
));

Future<void> openPicker(WidgetTester tester) async {
  await tester.tap(find.text('Mở chọn hàng'));
  await tester.pumpAndSettle();
}

void main() {
  test('picker search checks code, SKU, name, brand and preserves zero codes', () {
    expect(orderPickerMatches(product('000123','Bút bi'), '0001', products: true), true);
    expect(orderPickerMatches(product('000123','Bút bi'), 'BÚT', products: true), true);
    expect(orderPickerMatches(product('000123','Bút bi'), 'future', products: true), true);
    expect(orderPickerMatches(product('000123','Bút bi'), 'S-000', products: true), true);
    expect(orderPickerMatches(product('000123','Bút bi'), 'không có', products: true), false);
  });

  for (final width in [360.0, 390.0, 430.0]) {
    testWidgets('mobile picker live-searches 1, 2, 3 characters at $width', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 800);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final queue = PickerQueue();
      final all = [
        product('000123', 'Bút bi xanh'),
        product('001024', 'Tập học sinh'),
        product('012999', 'Bìa hồ sơ', quantity: null),
      ];
      final requested = <String>[];
      Map<String, dynamic>? picked;
      final mock = MockClient((request) async {
        final term = request.url.queryParameters['q'] ?? '';
        requested.add(term);
        final filtered = all.where((row) =>
          orderPickerMatches(row, term, products: true)).toList();
        return http.Response.bytes(utf8.encode(jsonEncode({
          'items': filtered, 'next_cursor': null,
        })), 200);
      });
      await tester.pumpWidget(pickerHarness(queue, mock, selected: (row) => picked = row));
      await openPicker(tester);
      expect(find.byType(Dialog), findsOneWidget);
      expect(find.text('Chọn sản phẩm'), findsOneWidget);
      expect(find.text('Tồn 24'), findsNothing);
      expect(find.text('Chưa có tồn'), findsNothing);
      expect(find.textContaining('Thùng'), findsNWidgets(3));
      final input = find.byKey(const Key('order-picker-search'));
      await tester.enterText(input, '0');
      await tester.pump(const Duration(milliseconds: 260));
      await tester.pumpAndSettle();
      expect(requested, contains('0'));
      await tester.enterText(input, '00');
      await tester.pump(const Duration(milliseconds: 260));
      await tester.pumpAndSettle();
      expect(requested, contains('00'));
      await tester.enterText(input, '000');
      await tester.pump(const Duration(milliseconds: 260));
      await tester.pumpAndSettle();
      expect(requested, contains('000'));
      expect(find.byKey(const ValueKey('order-product-000123')), findsOneWidget);
      expect(find.byKey(const ValueKey('order-product-001024')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('order-product-000123')));
      await tester.pumpAndSettle();
      expect(picked?['company_code'], '000123');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      queue.dispose();
      mock.close();
    });
  }

  testWidgets('pagination shows more button, preserves full catalogue in offline cache',
      (tester) async {
    final queue = PickerQueue();
    final first = [product('000001','Tập 1'), product('000002','Tập 2')];
    final last = [product('000003','Tập 3')];
    final mock = MockClient((request) async {
      final after = request.url.queryParameters['after'];
      final rows = after == null ? first : last;
      return http.Response.bytes(utf8.encode(jsonEncode({
        'items': rows,
        'next_cursor': after == null ? '000002' : null,
      })), 200);
    });
    await tester.pumpWidget(pickerHarness(queue, mock));
    await openPicker(tester);
    expect(find.byKey(const ValueKey('order-product-000001')), findsOneWidget);
    expect(find.byKey(const ValueKey('order-product-000003')), findsNothing);
    expect(find.byKey(const Key('order-picker-load-more')), findsOneWidget);
    await tester.tap(find.byKey(const Key('order-picker-load-more')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('order-product-000003')), findsOneWidget);
    final offline = queue.saved['order-picker-products-full-v2'];
    expect(offline, isNotNull);
    expect((offline!.first['items'] as List).length, 3);
    expect(offline.first['complete'], true);
    await tester.pumpWidget(const SizedBox());
    queue.dispose();
    mock.close();
  });

  testWidgets('offline search uses complete cache, never replaces it with partial query',
      (tester) async {
    final queue = PickerQueue();
    await queue.cache('order-picker-products-full-v2', [
      {'items': [
        product('000123', 'Bút bi'),
        product('000456', 'Bìa còng'),
      ], 'complete': true},
    ]);
    final mock = MockClient((request) async => http.Response('{"error":"Mất mạng"}', 503));
    await tester.pumpWidget(pickerHarness(queue, mock));
    await openPicker(tester);
    expect(find.textContaining('danh mục lưu máy'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('order-picker-search')), '00012');
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('order-product-000123')), findsOneWidget);
    expect(find.byKey(const ValueKey('order-product-000456')), findsNothing);
    expect((queue.saved['order-picker-products-full-v2']!.first['items'] as List).length, 2);
    await tester.pumpWidget(const SizedBox());
    queue.dispose();
    mock.close();
  });

  testWidgets('stale search response cannot replace newer query', (tester) async {
    final queue = PickerQueue();
    final slow = Completer<http.Response>();
    final mock = MockClient((request) async {
      final q = request.url.queryParameters['q'] ?? '';
      if (q == '1') return slow.future;
      final items = q == '12' ? [product('120001','Bút màu')] : [];
      return http.Response.bytes(utf8.encode(jsonEncode({'items': items, 'next_cursor': null})), 200);
    });
    await tester.pumpWidget(pickerHarness(queue, mock));
    await openPicker(tester);
    final input = find.byKey(const Key('order-picker-search'));
    await tester.enterText(input, '1');
    await tester.pump(const Duration(milliseconds: 250));
    await tester.enterText(input, '12');
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('order-product-120001')), findsOneWidget);
    slow.complete(http.Response.bytes(utf8.encode(jsonEncode({
      'items': [product('100000','Kết quả cũ')], 'next_cursor': null,
    })), 200));
    await tester.pump();
    expect(find.byKey(const ValueKey('order-product-120001')), findsOneWidget);
    expect(find.byKey(const ValueKey('order-product-100000')), findsNothing);
    await tester.pumpWidget(const SizedBox());
    queue.dispose();
    mock.close();
  });

  testWidgets('401/403 revocation blocks cached data instead of displaying it', (tester) async {
    final queue = PickerQueue();
    await queue.cache('order-picker-products-full-v2', [
      {'items': [product('000123','Bút bi')], 'complete': true},
    ]);
    final mock = MockClient((_) async => http.Response('{"error":"Forbidden"}', 403));
    await tester.pumpWidget(pickerHarness(queue, mock));
    await openPicker(tester);
    expect(find.text('Không còn quyền truy cập.'), findsOneWidget);
    expect(find.byKey(const ValueKey('order-product-000123')), findsNothing);
    expect(queue.saved['order-picker-products-full-v2'], isEmpty);
    await tester.pumpWidget(const SizedBox());
    queue.dispose();
    mock.close();
  });
}
