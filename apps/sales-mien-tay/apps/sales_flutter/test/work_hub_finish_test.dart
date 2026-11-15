import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:idb_shim/idb_shim.dart';
import 'package:sales_mien_tay/customers.dart';
import 'package:sales_mien_tay/offline_queue.dart';
import 'package:sales_mien_tay/planning_periods.dart';
import 'package:sales_mien_tay/session.dart';
import 'package:sales_mien_tay/work_hub.dart';
import 'package:sales_mien_tay/work_session_identity.dart';

void main(){
 testWidgets('overdue active route can be closed from card and goes to Results pending ACK',
  (tester)async{
  const id='11111111-1111-4111-8111-111111111111';
  const owner='sales-one';
  final now=DateTime.now().toUtc().add(const Duration(hours:7));
  final yesterday=DateTime(now.year,now.month,now.day).subtract(const Duration(days:1));
  final date=dayKey(yesterday);
  final session=workSessionId(owner,id);
  final item=<String,dynamic>{
   'id':id,'owner_sub':owner,'route_date':date,
   'status':'ready','plan_status':'planned',
   'purpose':'Thị Trường','scope_kind':'territory','scope_key':'Bến Tre|',
   'province':'Bến Tre','district':'',
   'work_session_id':session,'work_session_version':1,
   'work_session_state':'ongoing','stop_count':0,'visited_count':0,
   'survey_count':0,'lead_count':0,'market_visit_count':0,
   'unplanned_count':0,'unplanned_visited_count':0,
  };
  final client=MockClient((request)async{
   final path=request.url.path;
   if(path=='/api/v1/day-routes'){
    return http.Response(jsonEncode({'items':[item]}),200,
     headers:{'content-type':'application/json'});
   }
   if(path=='/api/v1/trips'){
    return http.Response('{"items":[]}',200,
     headers:{'content-type':'application/json'});
   }
   if(path=='/api/v1/day-routes/$id'){
    return http.Response(jsonEncode({'item':item,'stops':[]}),200,
     headers:{'content-type':'application/json'});
   }
   return http.Response('{"error":"Unexpected path"}',404,
    headers:{'content-type':'application/json'});
  });
  final queue=OfflineQueue(SalesSession(),owner,'1',factory:newIdbFactoryMemory());
  final service=CustomerService('https://example.test','token',client:client);
  await tester.pumpWidget(MaterialApp(home:Scaffold(
   body:WorkHubPage(queue:queue,service:service))));
  await tester.pumpAndSettle();
  expect(find.byKey(const ValueKey('overdue-work-heading')),findsOneWidget);
  expect(find.text('Quá hạn'),findsOneWidget);
  final finish=find.byKey(const ValueKey('finish-overdue-route:$id'));
  expect(finish,findsOneWidget);
  await tester.tap(finish);
  await tester.pumpAndSettle();
  expect(find.text('Chốt hoàn thành tuyến?'),findsOneWidget);
  expect(find.textContaining('Đã ghé 0'),findsOneWidget);
  await tester.tap(find.widgetWithText(FilledButton,'Chốt tuyến').last);
  await tester.pumpAndSettle();
  expect(queue.pending,hasLength(1));
  expect(queue.pending.single['path'],'/api/v1/work-sessions/$session/close');
  expect((queue.pending.single['payload'] as Map)['action'],'done');
  expect(queue.pending.single['depends_on'],isEmpty);
  expect(find.text('Kết quả công tác'),findsOneWidget);
  expect(find.text('Chờ đồng bộ'),findsOneWidget);
  expect(find.text('Hoàn thành'),findsNothing,
   reason:'Queued close cannot claim server completion');
  await tester.pumpWidget(const SizedBox.shrink());
  queue.dispose();client.close();
 });
}
