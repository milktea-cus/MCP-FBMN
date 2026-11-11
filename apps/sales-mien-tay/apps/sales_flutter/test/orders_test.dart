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
  expect(find.text('Lưu nháp trên máy'),findsOneWidget);
  expect(find.text('Kiểm tồn và xuất'),findsOneWidget);
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
}
