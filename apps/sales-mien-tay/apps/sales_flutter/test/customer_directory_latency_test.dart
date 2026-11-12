import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sales_mien_tay/customers.dart';
import 'package:sales_mien_tay/models.dart';
import 'package:sales_mien_tay/offline_queue.dart';
import 'package:sales_mien_tay/session.dart';

// Widget tests use an in-memory storage double; real IndexedDB is tested
// separately in offline_queue_test and the Chrome PWA CI job.
class DirectoryQueue extends OfflineQueue {
  final saved = <String, List<Map<String, dynamic>>>{};
  DirectoryQueue() : super(SalesSession(), 'seller-a', 'rev-1');

  @override
  Future<List<Map<String, dynamic>>> cached(String key) async => saved[key] ?? [];

  @override
  Future<void> cache(String key, List<Map<String, dynamic>> items) async {
    saved[key] = [for(final row in items) Map<String, dynamic>.from(row)];
  }
}

Map<String, dynamic> customer(String id, String name) => {
  'id': id,
  'owner_sub': 'seller-a',
  'name': name,
  'code': '00001',
  'address_line': 'Mỹ Tho',
  'province': 'Tiền Giang',
  'district': 'Thành phố Mỹ Tho',
  'category': 'dai_ly',
  'status': 'active',
  'version': 1,
};

http.Response jsonResponse(List<Map<String, dynamic>> items, {int status = 200}) =>
  http.Response.bytes(
    utf8.encode(jsonEncode({'items': items})),
    status, headers: {'content-type': 'application/json; charset=utf-8'},
  );

Widget directoryHarness(OfflineQueue queue, CustomerService service) =>
  MaterialApp(home: Scaffold(body: CustomerDirectoryPage(
    service: service, queue: queue, regions: RegionCatalog(const {}),
  )));

void main() {
  for(final width in [360.0,390.0,430.0]){
    testWidgets('customer action row has no overflow at ${width.toInt()}px',(tester)async{
      tester.view.devicePixelRatio=1;
      tester.view.physicalSize=Size(width,844);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final q=DirectoryQueue();
      final c=customer('1','Khách lẻ Miền Tây')
        ..['category']='khach_le'
        ..['phone']='0901234567';
      await q.cache('customers:',[c]);
      final client=MockClient((_)async=>jsonResponse([c]));
      await tester.pumpWidget(directoryHarness(q,CustomerService(
        'https://example.test','',identity:'seller-a',client:client)));
      await tester.pump();await tester.pump();
      expect(find.byTooltip('Gọi điện'),findsOneWidget);
      expect(find.byTooltip('Mở Zalo'),findsOneWidget);
      expect(find.text('Chỉ đường'),findsOneWidget);
      expect(find.byIcon(Icons.person_outline),findsOneWidget);
      expect(tester.takeException(),isNull);
      await tester.pumpWidget(const SizedBox());
      client.close();q.dispose();
    });
  }
  testWidgets('quick actions disable invalid and unavailable contact links',(tester)async{
    final q=DirectoryQueue();
    final c=customer('1','Không có số')..['phone']='invalid';
    await q.cache('customers:',[c]);
    final client=MockClient((_)async=>jsonResponse([c]));
    await tester.pumpWidget(directoryHarness(q,CustomerService(
      'https://example.test','',identity:'seller-a',client:client)));
    await tester.pump();await tester.pump();
    expect(tester.widget<IconButton>(find.byTooltip('Gọi điện')).onPressed,isNull);
    expect(tester.widget<IconButton>(find.byTooltip('Mở Zalo')).onPressed,isNull);
    expect(find.text('Chỉ đường'),findsOneWidget);
    expect(tester.takeException(),isNull);
    await tester.pumpWidget(const SizedBox());
    client.close();q.dispose();
  });

  testWidgets('cached customers render before a slow API resolves (mobile 390px)',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final queue = DirectoryQueue();
    await queue.cache('customers:', [customer('1', 'Đại lý Lê Phương')]);
    final request = Completer<http.Response>();
    final client = MockClient((_) => request.future);
    final service = CustomerService('https://example.test', '',
      identity: 'seller-a', revision: 'rev-1', client: client);
    await tester.pumpWidget(directoryHarness(queue, service));
    await tester.pump();
    await tester.pump();
    expect(find.text('Đại lý Lê Phương'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    request.complete(jsonResponse([customer('2', 'Nhà sách Hữu Văn Trung')]));
    await tester.pump();
    await tester.pump();
    expect(find.text('Nhà sách Hữu Văn Trung'), findsOneWidget);
    expect(find.text('Đại lý Lê Phương'), findsNothing);
    expect((await queue.cached('customers:')).single['name'],
      'Nhà sách Hữu Văn Trung');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    client.close();
    queue.dispose();
  });

  testWidgets('offline failure keeps scoped data with compact Vietnamese status',
      (tester) async {
    final queue = DirectoryQueue();
    await queue.cache('customers:', [customer('1', 'Đại lý Lê Phương')]);
    final client = MockClient((_) async =>
      http.Response.bytes(utf8.encode('{"error":"Offline"}'), 503));
    final service = CustomerService('https://example.test', '',
      identity: 'seller-a', revision: 'rev-1', client: client);
    await tester.pumpWidget(directoryHarness(queue, service));
    await tester.pump();
    await tester.pump();
    await tester.pump();
    expect(find.text('Đại lý Lê Phương'), findsOneWidget);
    expect(find.text('Đang xem dữ liệu lưu máy · chưa làm mới.'),
      findsOneWidget);
    expect(find.textContaining('TimeoutException'), findsNothing);
    expect(find.text('Thử lại'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    client.close();
    queue.dispose();
  });

  testWidgets('403 access revocation cannot expose the cached directory',
      (tester) async {
    final queue = DirectoryQueue();
    await queue.cache('customers:', [customer('1', 'Khách cần ẩn')]);
    final response = Completer<http.Response>();
    final client = MockClient((_) => response.future);
    final service = CustomerService('https://example.test', '',
      identity: 'seller-a', revision: 'rev-1', client: client);
    await tester.pumpWidget(directoryHarness(queue, service));
    await tester.pump();
    await tester.pump();
    expect(find.text('Khách cần ẩn'), findsOneWidget);
    response.complete(http.Response.bytes(
      utf8.encode('{"error":"Không có quyền"}'), 403));
    await tester.pump();
    await tester.pump();
    expect(find.text('Khách cần ẩn'), findsNothing);
    expect(find.text('Phiên hoặc quyền truy cập đã thay đổi.'),
      findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    client.close();
    queue.dispose();
  });

  test('server paging publishes first page before full sync and preserves order',
      () async {
    final seen = <int>[];
    final client = MockClient((request) async {
      final offset = int.parse(request.url.queryParameters['offset']!);
      seen.add(offset);
      final rows = offset == 0
        ? [for (var i = 0; i < 100; i++)
            customer('$i', 'Điểm bán $i')]
        : [customer('100', 'Điểm bán cuối')];
      return jsonResponse(rows);
    });
    final service = CustomerService('https://example.test', '',
      client: client);
    final snapshots = <int>[];
    final all = await service.list(onPage: (partial) =>
      snapshots.add(partial.length));
    expect(seen, [0, 100]);
    expect(snapshots, [100, 101]);
    expect(all.length, 101);
    expect(all.first.name, 'Điểm bán 0');
    client.close();
  });

  test('slow customer API is bounded and does not wait twenty seconds', () async {
    final never = Completer<http.Response>();
    final client = MockClient((_) => never.future);
    final service = CustomerService('https://example.test', '',
      client: client, listTimeout: const Duration(milliseconds: 40));
    final started = DateTime.now();
    await expectLater(service.list(), throwsA(isA<TimeoutException>()));
    expect(DateTime.now().difference(started).inSeconds, lessThan(2));
    client.close();
  });
}
