import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sales_mien_tay/actuals.dart';
import 'package:sales_mien_tay/offline_queue.dart';
import 'package:sales_mien_tay/orders.dart';
import 'package:sales_mien_tay/session.dart';

class DraftQueue extends OfflineQueue{
 final Map<String,List<Map<String,dynamic>>> store={};
 DraftQueue():super(SalesSession(),'owner','3');
 @override Future<List<Map<String,dynamic>>> cached(String k) async=>store[k]??[];
 @override Future<void> cache(String k,List<Map<String,dynamic>> rows)async{
  store[k]=[for(final row in rows)Map<String,dynamic>.from(row)];
 }
}
void main(){
 test('order totals group quantities by unit, never mixing boxes and pieces',(){
  expect(orderTotalByUnit([
   {'quantity':2,'unit':'Thùng'},
   {'quantity':5,'unit':'Quyển'},
   {'quantity':3,'unit':'Thùng'},
  ]),'5 Thùng · 5 Quyển');
 });

 test('stock refuses unknown/short, flags stale and accepts recent snapshot',(){
  final now=DateTime.utc(2026,11,11,5);
  expect(orderStockStale('2026-11-10T04:00:00Z',now:now),isTrue);
  expect(orderStockStale('2026-11-11T04:00:00Z',now:now),isFalse);
  expect(orderStockMessage({'quantity':3,'unit':'Thùng'},now:now),'Chưa có số tồn');
  expect(orderStockMessage({'quantity':5,'unit':'Thùng','available':'3','snapshot_at':'2026-11-11T04:00:00Z'},now:now),contains('Thiếu tồn'));
  expect(orderStockMessage({'quantity':2,'unit':'Thùng','available':'3','snapshot_at':'2026-11-11T04:00:00Z'},now:now),'Tồn: 3 Thùng');
 });
 for(final w in [360.0,390.0]){
 testWidgets('Retail order draft persists offline under account, no price at $w',(tester)async{
  tester.view.devicePixelRatio=1;tester.view.physicalSize=Size(w,850);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final queue=DraftQueue();var online=true;
  final client=MockClient((req)async{
   expect(req.headers['x-sync-identity'],'owner');
   expect(req.headers['x-sync-revision'],'3');
   if(!online)return http.Response('{"error":"offline"}',503);
   if(req.url.path=='/api/v1/orders')return http.Response.bytes(utf8.encode('{"items":[],"can_mark_imported":true}'),200);
   return http.Response.bytes(utf8.encode('{"items":[]}'),200);
  });
  Widget app()=>MaterialApp(home:Scaffold(body:OrdersPage(queue:queue,admin:true,client:ActualClient(queue,client:client))));
  await tester.pumpWidget(app());await tester.pumpAndSettle();
  expect(find.text('Ra đơn'),findsOneWidget);
  expect(find.text('Tạo đơn mới'),findsOneWidget);
  await tester.tap(find.text('Tạo đơn mới'));await tester.pumpAndSettle();
  expect(find.text('Lưu đơn'),findsOneWidget);
  expect(find.text('Lưu nháp trên máy'),findsNothing);
  expect(find.text('Xuất'),findsOneWidget);
  expect(find.textContaining('Đã lưu trên máy'),findsOneWidget);
  expect(find.textContaining('Không nhập giá'),findsOneWidget);
  await tester.tap(find.byTooltip('Đóng giỏ'));await tester.pumpAndSettle();
  expect(find.textContaining('Nháp trên máy'),findsOneWidget);
  online=false;
  await tester.pumpWidget(const SizedBox());await tester.pump();
  await tester.pumpWidget(app());await tester.pumpAndSettle();
  expect(find.textContaining('Ngoại tuyến'),findsOneWidget);
  expect(find.textContaining('Nháp trên máy'),findsOneWidget);
  expect(tester.takeException(),isNull);
  await tester.pumpWidget(const SizedBox());queue.dispose();client.close();
 });
 }

 testWidgets('P0-B: save order retains numbered lines and idempotent retry after network failure',
  (tester)async{
  tester.view.devicePixelRatio=1;
  tester.view.physicalSize=const Size(390,850);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final queue=DraftQueue();
  const customerId='33333333-3333-4333-8333-333333333333';
  const firstId='11111111-1111-4111-8111-111111111111';
  const secondId='22222222-2222-4222-8222-222222222222';
  final products=[
   {'id':firstId,'company_code':'000123','name':'Bút bi xanh',
    'sku':'SKU-1','unit':'Thùng','quantity':'10',
    'snapshot_at':DateTime.now().toUtc().toIso8601String()},
   {'id':secondId,'company_code':'000456','name':'Tập học sinh',
    'sku':'SKU-2','unit':'Thùng','quantity':'20',
    'snapshot_at':DateTime.now().toUtc().toIso8601String()},
  ];
  final saves=<Map<String,dynamic>>[];
  Map<String,dynamic>? serverOrder;
  var failFirst=true;
  final mock=MockClient((request)async{
   if(request.method=='GET'&&request.url.path=='/api/v1/orders'){
    return http.Response.bytes(utf8.encode(jsonEncode({'items':[
      if(serverOrder!=null)serverOrder
    ]})),200);
   }
   if(request.url.path=='/api/v1/orders/customers'){
    return http.Response.bytes(utf8.encode(jsonEncode({'items':[
      {'id':customerId,'owner_sub':'owner','name':'Nhà sách Demo','export_code':'CTY-01'}
    ]})),200);
   }
   if(request.url.path=='/api/v1/orders/products'){
    return http.Response.bytes(utf8.encode(jsonEncode({'items':products,'next_cursor':null})),200);
   }
   if(request.method=='POST'&&request.url.path=='/api/v1/orders'){
    final payload=Map<String,dynamic>.from(jsonDecode(request.body) as Map);
    saves.add(payload);
    if(failFirst){failFirst=false;return http.Response('{"error":"Kết nối đứt"}',503);}
    serverOrder={
      'id':payload['id'],'owner_sub':'owner','customer_id':customerId,
      'customer_name':'Nhà sách Demo','customer_code':'CTY-01',
      'status':'draft','version':1,'note':payload['note'],
      'lines':[for(final l in payload['lines'] as List)
       {'line_id':(l as Map)['line_id'],'product_id':l['product_id'],
        'quantity':l['quantity'],'unit':l['unit'],
        'company_code':l['product_id']==firstId?'000123':'000456',
        'name':l['product_id']==firstId?'Bút bi xanh':'Tập học sinh'}],
    };
    return http.Response.bytes(utf8.encode(jsonEncode({'item':{
      'id':payload['id'],'owner_sub':'owner','customer_id':customerId,
      'status':'draft','version':1,'note':payload['note'],
    }})),201);
   }
   return http.Response('{"error":"Unexpected endpoint"}',404);
  });
  Widget app()=>MaterialApp(home:Scaffold(body:OrdersPage(queue:queue,admin:true,client:ActualClient(queue,client:mock))));
  await tester.pumpWidget(app());await tester.pumpAndSettle();
  await tester.tap(find.text('Tạo đơn mới'));await tester.pumpAndSettle();
  await tester.tap(find.text('Chọn khách hàng'));await tester.pumpAndSettle();
  await tester.tap(find.text('Nhà sách Demo'));await tester.pumpAndSettle();
  await tester.tap(find.text('Thêm sản phẩm'));await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('order-product-000456')));await tester.pumpAndSettle();
  await tester.tap(find.text('Thêm sản phẩm'));await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('order-product-000123')));await tester.pumpAndSettle();
  // Insertion order is different from company-code sort.
  expect(find.text('01'),findsOneWidget);
  expect(find.text('02'),findsOneWidget);
  final row1=queue.store['order-drafts-v1']!.last['lines'] as List;
  final firstLineId=(row1.first as Map)['line_id'] as String;
  await tester.tap(find.byKey(ValueKey('cart-plus-$firstLineId')));
  await tester.pumpAndSettle();
  expect(((queue.store['order-drafts-v1']!.last['lines'] as List).first as Map)['quantity'],2);
  await tester.tap(find.byKey(ValueKey('cart-delete-$firstLineId')));
  await tester.pump();
  expect(find.text('Hoàn tác'),findsOneWidget);
  await tester.tap(find.text('Hoàn tác'));await tester.pumpAndSettle();
  expect(find.byKey(ValueKey('cart-quantity-$firstLineId')),findsOneWidget);
  final lines=queue.store['order-drafts-v1']!.last['lines'] as List;
  expect((lines[0] as Map)['product_id'],secondId);
  expect((lines[1] as Map)['product_id'],firstId);
  await tester.ensureVisible(find.text('Lưu đơn'));
  await tester.tap(find.text('Lưu đơn'));await tester.pumpAndSettle();
  expect(saves.length,1);
  expect(saves.first['action'],'save');
  expect(saves.first['version'],0);
  expect((saves.first['lines'] as List).map((l)=>(l as Map)['product_id']).toList(),[secondId,firstId]);
  expect(queue.store['order-drafts-v1'],isNotEmpty);
  expect(find.text('Đã lưu trên máy · chưa đồng bộ'),findsOneWidget);
  await tester.tap(find.text('Lưu đơn'));await tester.pumpAndSettle();
  expect(saves.length,2);
  expect(saves[0]['client_ref'],saves[1]['client_ref']);
  expect(find.text('Đã lưu trên hệ thống'),findsOneWidget);
  expect(queue.store['order-drafts-v1'],isEmpty);
  expect(find.text('Xuất'),findsOneWidget);
  final saveButton=tester.widget<FilledButton>(find.widgetWithText(FilledButton,'Lưu đơn'));
  expect(saveButton.onPressed,isNull);
  await tester.tap(find.byTooltip('Đóng giỏ'));await tester.pumpAndSettle();
  expect(find.text('Nhà sách Demo'),findsOneWidget);
  await tester.tap(find.text('Nhà sách Demo'));await tester.pumpAndSettle();
  expect(find.text('01'),findsOneWidget);
  expect(find.byKey(ValueKey('cart-quantity-$firstLineId')),findsOneWidget);
  expect(tester.takeException(),isNull);
  await tester.pumpWidget(const SizedBox());queue.dispose();mock.close();
 });

 testWidgets('P0-B offline autosave survives restart without second save button',(tester)async{
  tester.view.devicePixelRatio=1;
  tester.view.physicalSize=const Size(360,800);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final queue=DraftQueue();
  var offline=false;
  final mock=MockClient((request)async{
   if(offline)return http.Response('{"error":"Offline"}',503);
   return http.Response.bytes(utf8.encode('{"items":[]}'),200);
  });
  Widget app()=>MaterialApp(home:Scaffold(body:OrdersPage(queue:queue,admin:false,client:ActualClient(queue,client:mock))));
  await tester.pumpWidget(app());await tester.pumpAndSettle();
  await tester.tap(find.text('Tạo đơn mới'));await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField),'Giao buổi chiều');
  await tester.pumpAndSettle();
  expect(queue.store['order-drafts-v1']!.last['note'],'Giao buổi chiều');
  expect(find.text('Lưu đơn'),findsOneWidget);
  expect(find.text('Lưu nháp trên máy'),findsNothing);
  await tester.pumpWidget(const SizedBox());await tester.pump();
  offline=true;
  await tester.pumpWidget(app());await tester.pumpAndSettle();
  expect(find.textContaining('Ngoại tuyến'),findsOneWidget);
  expect(find.textContaining('Nháp trên máy'),findsOneWidget);
  await tester.tap(find.textContaining('Nháp trên máy').last);await tester.pumpAndSettle();
  expect(find.text('Giao buổi chiều'),findsOneWidget);
  expect(find.text('Đã lưu trên máy · chờ kết nối'),findsOneWidget);
  expect(find.text('Lưu đơn'),findsOneWidget);
  expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton,'Lưu đơn')).onPressed,isNull);
  await tester.pumpWidget(const SizedBox());queue.dispose();mock.close();
 });

}
