import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:idb_shim/idb_shim.dart';
import 'package:sales_mien_tay/customers.dart';
import 'package:sales_mien_tay/monthly_plan.dart';
import 'package:sales_mien_tay/offline_queue.dart';
import 'package:sales_mien_tay/planning_periods.dart';
import 'package:sales_mien_tay/schedule_archive.dart';
import 'package:sales_mien_tay/session.dart';

const planId='33333333-3333-4333-8333-333333333333';
const owner='sales-delete-test';
const scope='Bến Tre|';
Map<String,dynamic> plan(String month,{bool deleted=false}){
 final date='$month-12';
 return <String,dynamic>{
  'id':planId,'owner_sub':owner,'version':deleted?2:1,
  'period_ym':month,'work_date':date,'status':deleted?'cancelled':'planned',
  'purpose':'Khảo sát thị trường','scope_kind':'territory','scope_key':scope,
  'province':'Bến Tre','district':'','target_new_customers':0,
  'note':'',
 };
}
http.Response ok(Object value,[int status=200])=>http.Response(
 jsonEncode(value),status,headers:{'content-type':'application/json'});

void main(){
 for(final width in [320.0,360.0,390.0]){
  testWidgets('Xóa lịch visible, confirms through API and shows Đã xóa at $width px',(tester)async{
   tester.view.devicePixelRatio=1;
   tester.view.physicalSize=Size(width,850);
   addTearDown(tester.view.resetPhysicalSize);
   addTearDown(tester.view.resetDevicePixelRatio);
   final month=monthKey(DateTime.now());
   var deleted=false,deleteCalls=0;
   final net=MockClient((req)async{
    if(req.method=='DELETE'){
     deleteCalls++;
     expect(req.url.path,'/api/v1/monthly-plans/$planId');
     expect(req.url.queryParameters['version'],'1');
     deleted=true;
     return ok({'item':plan(month,deleted:true),'has_activity':false});
    }
    if(req.method=='GET'&&req.url.path=='/api/v1/monthly-plans'){
     expect(req.url.queryParameters['month'],month);
     return ok({'items':[plan(month,deleted:deleted)]});
    }
    if(req.method=='GET'&&req.url.path=='/api/v1/monthly-plans/options'){
     return ok({'scopes':[{
      'scope_kind':'territory','scope_key':scope,'province':'Bến Tre',
      'district':'','label':'Toàn tỉnh · Bến Tre',
     }]});
    }
    if(req.method=='GET'&&req.url.path=='/api/v1/day-routes'){
     return ok({'items':[]});
    }
    fail('Unexpected request '+req.method+' '+req.url.toString());
   });
   final service=CustomerService('https://example.test','',
    identity:owner,revision:'1',client:net);
   final queue=OfflineQueue(SalesSession(),owner,'1',
    factory:newIdbFactoryMemory());
   await tester.pumpWidget(MaterialApp(home:MonthlyPlanPage(
    queue:queue,service:service)));
   await tester.pumpAndSettle();
   expect(find.byKey(const ValueKey('delete-plan:$planId')),findsOneWidget);
   expect(tester.takeException(),isNull);
   await tester.tap(find.byKey(const ValueKey('delete-plan:$planId')));
   await tester.pumpAndSettle();
   expect(find.text('Xóa lịch công tác?'),findsOneWidget);
   expect(deleteCalls,0,reason:'No server action before confirmation');
   expect(find.text('Giữ lịch'),findsOneWidget);
   await tester.tap(find.byKey(const ValueKey('confirm-delete-schedule')));
   await tester.pumpAndSettle();
   expect(deleteCalls,1);
   expect(find.byKey(const ValueKey('delete-plan:$planId')),findsNothing);
   await tester.tap(find.byKey(const ValueKey('monthly-archived-toggle')));
   await tester.pumpAndSettle();
   expect(find.textContaining('Đã xóa · chỉ xem lịch sử'),findsOneWidget);
   expect(find.text('Khảo sát thị trường'),findsOneWidget);
   expect(tester.takeException(),isNull);
   await tester.pumpWidget(const SizedBox.shrink());
   queue.dispose();net.close();
  });
 }
 test('409 stale schedule cannot be archived or acknowledged',()async{
  final net=MockClient((req)async=>ok({'error':'Lịch đã thay đổi'},409));
  final service=CustomerService('https://example.test','',client:net);
  final month=monthKey(DateTime.now());
  await expectLater(
   archiveWorkScheduleRequest(service,plan(month)),
   throwsA(isA<ApiFailure>().having((e)=>e.status,'status',409)),
  );
  net.close();
 });
 testWidgets('Giữ lịch leaves server untouched',(tester)async{
  var calls=0;
  final net=MockClient((req)async{
   calls++;return ok({'item':plan(monthKey(DateTime.now()),deleted:true)});
  });
  final service=CustomerService('https://example.test','',client:net);
  final queue=OfflineQueue(SalesSession(),owner,'1',
   factory:newIdbFactoryMemory());
  var result=true;
  await tester.pumpWidget(MaterialApp(home:Scaffold(body:Builder(
   builder:(context)=>TextButton(onPressed:()async{
    result=await confirmArchiveWorkSchedule(context,service:service,
     queue:queue,plan:plan(monthKey(DateTime.now())));
   },child:const Text('Open')),
  ))));
  await tester.tap(find.text('Open'));await tester.pumpAndSettle();
  await tester.tap(find.text('Giữ lịch'));await tester.pumpAndSettle();
  expect(result,isFalse);expect(calls,0);
  await tester.pumpWidget(const SizedBox.shrink());
  queue.dispose();net.close();
 });
}
