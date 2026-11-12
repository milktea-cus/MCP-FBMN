import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import '../lib/targets.dart';
import '../lib/session.dart';
import '../lib/offline_queue.dart';

class TestTargetQueue extends OfflineQueue {
 final Map<String,List<Map<String,dynamic>>> memory={};
 TestTargetQueue():super(SalesSession(),'owner','7');
 @override Future<void> cache(String key,List<Map<String,dynamic>> items)async{memory[key]=items;}
 @override Future<List<Map<String,dynamic>>> cached(String key)async=>memory[key]??[];
}
void main(){
 testWidgets('mobile target editor saves month and keeps actual unavailable; offline snapshot read-only',(tester)async{
  tester.view.devicePixelRatio=1;tester.view.physicalSize=const Size(390,844);
  addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
  final q=TestTargetQueue();final month=DateTime.now().month;
  bool offline=false;final rows=<Map<String,dynamic>>[];
  final requests=<Map<String,dynamic>>[];
  final client=MockClient((r)async{
   expect(r.headers['x-sync-identity'],'owner');expect(r.headers['x-sync-revision'],'7');
   if(offline)return http.Response('{"error":"offline"}',503);
   if(r.method=='POST'){
    final b=jsonDecode(r.body) as Map<String,dynamic>;requests.add(b);
    for(final m in b['months'] as List){rows.add({'owner_sub':'owner','dimension':b['dimension'],'entity_id':b['entity_id'],'month':m['month'],'amount':m['amount'].toString(),'version':1});}
    return http.Response('{"items":[]}',200);
   }
   return http.Response(jsonEncode({'staff':[{'user_sub':'owner','employee_code':'A','full_name':'Admin'}],'owner':'owner','items':rows,'allocations':[],'can_edit':true,'actual_available':false}),200);
  });
  await tester.pumpWidget(MaterialApp(home:Scaffold(body:TargetPage(queue:q,client:TargetClient(q,client:client)))));
  await tester.pumpAndSettle();
  expect(find.text('Giao / sửa'),findsOneWidget);
  await tester.tap(find.text('Giao / sửa'));await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField),'1000000');
  await tester.tap(find.text('Lưu chỉ tiêu'));await tester.pumpAndSettle();
  expect(requests.single['months'],[{'month':month,'amount':1000000,'version':0}]);
  expect(find.text('1.000.000 đ'),findsWidgets);
  expect(find.text('Hoàn thành: —     Còn thiếu: —'),findsOneWidget);
  offline=true;
  await tester.tap(find.byTooltip('Tải lại Target'));await tester.pumpAndSettle();
  expect(find.text('Giao / sửa'),findsNothing);
  expect(find.textContaining('Dữ liệu lưu máy'),findsOneWidget);
  expect(find.text('1.000.000 đ'),findsWidgets);
  expect(tester.takeException(),isNull);
  await tester.pumpWidget(const SizedBox());q.dispose();client.close();
 });
}
