import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:idb_shim/idb_shim.dart';
import 'package:sales_mien_tay/actuals.dart';
import 'package:sales_mien_tay/offline_queue.dart';
import 'package:sales_mien_tay/session.dart';

void main(){
 testWidgets('4B list and manual editing on 390px, no fake target revenue',(tester)async{
  tester.view.devicePixelRatio=1;tester.view.physicalSize=const Size(390,844);
  addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
  final queue=OfflineQueue(SalesSession(),'owner','1',factory:newIdbFactoryMemory());
  final now=DateTime.now(),date='${now.year}-${now.month.toString().padLeft(2,'0')}-05';
  final records=<Map<String,dynamic>>[
   {'id':'11111111-1111-4111-8111-111111111111','version':1,'owner_sub':'owner',
    'customer_id':'22222222-2222-4222-8222-222222222222','product_id':'33333333-3333-4333-8333-333333333333',
    'sale_date':date,'quantity':2,'amount':'150000','source':'company','status':'active',
    'external_ref':'INV-1','line_ref':'1','employee_code':'TEST','customer_name':'Cửa hàng A',
    'product_name':'Vở học sinh','company_code':'000123'}];
  final client=MockClient((r)async{
   if(r.url.path.endsWith('/options'))return http.Response.bytes(utf8.encode(jsonEncode({'items':[
    {'id':'owner','code':'TEST','name':'Admin'}]})),200,headers:{'content-type':'application/json; charset=utf-8'});
   if(r.url.path.endsWith('/history'))return http.Response('{"items":[]}',200);
   return http.Response.bytes(utf8.encode(jsonEncode({'month':date.substring(0,7),'items':records,'can_import':true})),200,headers:{'content-type':'application/json; charset=utf-8'});
  });
  await tester.pumpWidget(MaterialApp(home:ActualsPage(queue:queue,client:ActualClient(queue,client:client))));
  await tester.pumpAndSettle();
  expect(tester.takeException(),isNull);
  expect(find.text('Doanh số thực tế'),findsOneWidget);
  expect(saleMoney(150000),'150.000 đ');
  expect(find.text('150.000 đ'),findsWidgets,reason:tester.widgetList<Text>(find.byType(Text)).map((x)=>x.data).toList().toString());
  expect(find.text('Nhập Excel'),findsOneWidget);
  expect(find.text('Nhập tay'),findsOneWidget);
  expect(find.textContaining('không cộng dữ liệu dự kiến'),findsOneWidget);
  await tester.pumpWidget(const SizedBox());queue.dispose();client.close();
 });
}
