import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sales_mien_tay/actuals.dart';
import 'package:sales_mien_tay/offline_queue.dart';
import 'package:sales_mien_tay/orders.dart';
import 'package:sales_mien_tay/session.dart';

class LifecycleQueue extends OfflineQueue {
 final saved=<String,List<Map<String,dynamic>>>{};
 LifecycleQueue():super(SalesSession(),'sales-owner','scope-a');
 @override Future<List<Map<String,dynamic>>> cached(String key)async=>saved[key]??[];
 @override Future<void> cache(String key,List<Map<String,dynamic>> rows)async{
  saved[key]=[for(final row in rows)Map<String,dynamic>.from(row)];
 }
}
const originalId='11111111-1111-4111-8111-111111111111';
const adjustmentId='22222222-2222-4222-8222-222222222222';
const customerId='33333333-3333-4333-8333-333333333333';
Map<String,dynamic> original(String status)=>{
 'id':originalId,'owner_sub':'sales-owner',
 'customer_id':customerId,'customer_name':'Nhà sách Long Xuyên',
 'customer_code':'CTY01','status':status,
 'version':3,'note':'Giao buổi sáng',
 'lines':[{
  'line_id':'44444444-4444-4444-8444-444444444444',
  'product_id':'55555555-5555-4555-8555-555555555555',
  'company_code':'00999','name':'Bút chì','unit':'Hộp',
  'quantity':2,'available':'30',
  'snapshot_at':DateTime.now().toUtc().toIso8601String(),
 }],
 'created_at':'2026-11-11T08:30:00Z',
};
http.Response response(Map<String,dynamic> data,{int status=200})=>
 http.Response.bytes(utf8.encode(jsonEncode(data)),status,headers:const{
 'content-type':'application/json; charset=utf-8',
});
Widget app(LifecycleQueue queue,MockClient mock,{bool admin=false})=>
 MaterialApp(home:Scaffold(body:OrdersPage(
  queue:queue,admin:admin,client:ActualClient(queue,client:mock))));

void main(){
 test('P0-C state policy is fail-closed for imported and exported',(){
  expect(orderCanEdit('draft'),isTrue);
  expect(orderCanEdit('local'),isTrue);
  for(final status in ['imported','exported','cancelled','superseded']){
   expect(orderCanEdit(status),isFalse);
  }
  expect(orderCanCancel('draft',admin:false),isTrue);
  expect(orderCanCancel('exported',admin:false),isFalse);
  expect(orderCanCancel('exported',admin:true),isTrue);
  expect(orderCanCancel('imported',admin:true),isFalse);
  expect(orderCanReplace('imported',admin:false),isFalse);
  expect(orderCanReplace('imported',admin:true),isTrue);
  expect(orderCanReplace('imported',admin:true,alreadyReplaced:true),isFalse);
  expect(orderCanReplace('cancelled',admin:true),isFalse);
  expect(orderStatus('cancelled'),contains('hủy'));
  expect(orderStatus('superseded'),contains('thay thế'));
 });
 test('P0-C search, status and date filters preserve company code and account scope',(){
  final row=original('exported');
  expect(orderFilterRow(row,query:'Long Xuyên'),isTrue);
  expect(orderFilterRow(row,query:'CTY01'),isTrue);
  expect(orderFilterRow(row,query:'11111111'),isTrue);
  expect(orderFilterRow(row,query:'Không có'),isFalse);
  expect(orderFilterRow(row,status:'imported'),isFalse);
  expect(orderFilterRow(row,status:'exported'),isTrue);
  expect(orderFilterRow(row,range:DateTimeRange(
    start:DateTime(2026,11,10),end:DateTime(2026,11,11))),isTrue);
  expect(orderFilterRow(row,range:DateTimeRange(
    start:DateTime(2026,11,1),end:DateTime(2026,11,10))),isFalse);
  expect(orderEventStatus({'item':{'status':'cancelled'}}),contains('hủy'));
  expect(orderEventStatus({'status':'imported'}),contains('nhập'));
 });

 for(final width in [360.0,390.0]){
 testWidgets('P0-C sales cannot cancel or replace imported order on $width',
  (tester)async{
  tester.view.devicePixelRatio=1;
  tester.view.physicalSize=Size(width,850);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final queue=LifecycleQueue();
  final mock=MockClient((req)async=>response({'items':[original('imported')]}));
  await tester.pumpWidget(app(queue,mock));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Nhà sách Long Xuyên'));
  await tester.pumpAndSettle();
  expect(find.text('Tạo điều chỉnh'),findsNothing);
  expect(find.text('Thay thế đơn'),findsNothing);
  expect(find.text('Hủy đơn'),findsNothing);
  expect(find.text('Lưu đơn'),findsNothing);
  expect(find.text('Nhật ký'),findsOneWidget);
  expect(tester.takeException(),isNull);
  await tester.pumpWidget(const SizedBox());
  queue.dispose();mock.close();
 });
 }

 testWidgets('P0-C exported cancel asks reason and records exact version',
  (tester)async{
  tester.view.devicePixelRatio=1;
  tester.view.physicalSize=const Size(390,850);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final queue=LifecycleQueue();
  var serverOrder=original('exported');
  final calls=<Map<String,dynamic>>[];
  final mock=MockClient((req)async{
   if(req.method=='GET'&&req.url.path=='/api/v1/orders'){
    return response({'items':[serverOrder]});
   }
   if(req.method=='POST'&&req.url.path=='/api/v1/orders/lifecycle'){
    final data=Map<String,dynamic>.from(jsonDecode(req.body) as Map);
    calls.add(data);
    serverOrder={...serverOrder,'version':4,'status':'cancelled',
      'cancel_reason':data['reason']};
    return response({'item':serverOrder});
   }
   return response({'error':'not found'},status:404);
  });
  await tester.pumpWidget(app(queue,mock,admin:true));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Nhà sách Long Xuyên'));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('Hủy đơn'));
  await tester.tap(find.text('Hủy đơn'));
  await tester.pumpAndSettle();
  expect(find.text('Xác nhận hủy'),findsOneWidget);
  expect(tester.widget<FilledButton>(
    find.widgetWithText(FilledButton,'Xác nhận hủy')).onPressed,isNull);
  await tester.enterText(find.widgetWithText(TextField,'Lý do bắt buộc'),
    'Khách yêu cầu hủy đơn xuất');
  await tester.pump();
  await tester.tap(find.text('Xác nhận hủy'));
  await tester.pumpAndSettle();
  expect(calls.length,1);
  expect(calls.single['action'],'cancel');
  expect(calls.single['expected_version'],3);
  expect(calls.single['order_id'],originalId);
  expect(calls.single['reason'],'Khách yêu cầu hủy đơn xuất');
  expect(find.textContaining('Lý do hủy:'),findsOneWidget);
  expect(find.text('Lưu đơn'),findsNothing);
  await tester.pumpWidget(const SizedBox());
  queue.dispose();mock.close();
 });

 testWidgets('P0-C imported company receipt stays immutable; admin creates linked draft',
  (tester)async{
  tester.view.devicePixelRatio=1;
  tester.view.physicalSize=const Size(390,850);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final queue=LifecycleQueue();
  var source=original('imported');
  Map<String,dynamic>? successor;
  final calls=<Map<String,dynamic>>[];
  final mock=MockClient((req)async{
   if(req.method=='GET'&&req.url.path=='/api/v1/orders'){
    return response({'items':[source,if(successor!=null)successor]});
   }
   if(req.method=='GET'&&req.url.path=='/api/v1/orders/$adjustmentId'){
    return response({'item':successor});
   }
   if(req.method=='POST'&&req.url.path=='/api/v1/orders/lifecycle'){
    final data=Map<String,dynamic>.from(jsonDecode(req.body) as Map);
    calls.add(data);
    successor={...original('draft'),'id':adjustmentId,
      'version':1,'replaces_order_id':originalId,
      'replacement_reason':data['reason']};
    source={...source,'version':4,'replaced_by_id':adjustmentId};
    return response({'item':source,'replacement':successor});
   }
   return response({'error':'Not found'},status:404);
  });
  await tester.pumpWidget(app(queue,mock,admin:true));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Nhà sách Long Xuyên'));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('Tạo điều chỉnh'));
  await tester.tap(find.text('Tạo điều chỉnh'));
  await tester.pumpAndSettle();
  expect(find.textContaining('không tự sửa chứng từ'),findsOneWidget);
  await tester.enterText(find.widgetWithText(TextField,'Lý do bắt buộc'),
    'Cần bổ sung số lượng sau khi nhập công ty');
  await tester.pump();
  await tester.tap(find.text('Tạo nháp điều chỉnh'));
  await tester.pumpAndSettle();
  expect(calls.length,1);
  expect(calls.single['action'],'replace');
  expect(calls.single['expected_version'],3);
  expect(calls.single['replacement_id'],isNot(originalId));
  expect(source['status'],'imported');
  expect(find.textContaining('Điều chỉnh từ đơn'),findsOneWidget);
  expect(find.text('Lưu đơn'),findsOneWidget);
  expect(tester.takeException(),isNull);
  await tester.pumpWidget(const SizedBox());
  queue.dispose();mock.close();
 });
}
