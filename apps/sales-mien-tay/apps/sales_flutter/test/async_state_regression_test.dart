import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sales_mien_tay/actuals.dart';
import 'package:sales_mien_tay/customer_assortment.dart';
import 'package:sales_mien_tay/customers.dart';
import 'package:sales_mien_tay/models.dart';
import 'package:sales_mien_tay/offline_queue.dart';
import 'package:sales_mien_tay/performance.dart';
import 'package:sales_mien_tay/session.dart';
import 'package:sales_mien_tay/stock.dart';

class MemoryQueue extends OfflineQueue {
 MemoryQueue():super(SalesSession(),'owner','1');
 final saved=<String,List<Map<String,dynamic>>>{};
 Completer<List<Map<String,dynamic>>>? delayedRead;
 bool failWrites=false;
 @override Future<void> cache(String key,List<Map<String,dynamic>> items)async {
  if(failWrites)throw StateError('disk unavailable');
  saved[key]=items;
 }
 @override Future<List<Map<String,dynamic>>> cached(String key)async =>
  delayedRead==null?(saved[key]??[]):await delayedRead!.future;
}
http.Response reply(Map<String,dynamic> data,[int status=200])=>
 http.Response.bytes(utf8.encode(jsonEncode(data)),status,headers:{'content-type':'application/json; charset=utf-8'});
Map<String,dynamic> stock(String name)=>{'name':name,'company_code':name,'quantity':'1'};
Map<String,dynamic> stockPage(List<Map<String,dynamic>> rows,{String? next})=>
 {'items':rows,'snapshot':'snap','synced_at':'2026-11-24T00:00:00Z','next_cursor':next};
Map<String,dynamic> sku(String name)=>{'name':name,'company_code':name,'status':'trading','product_id':name};
const service=CustomerService('https://example.test','token');
void main(){
 testWidgets('stock latest query wins even while prior query is pending',(tester)async{
  final q=MemoryQueue();
  final old=Completer<http.Response>(),latest=Completer<http.Response>();
  final calls=<String>[];
  final mock=MockClient((req)async{
   final term=req.url.queryParameters['q']??'';
   calls.add(term);
   if(term=='old')return old.future;
   if(term=='new')return latest.future;
   // Force a partial snapshot with a next cursor.
   return reply(stockPage(List.generate(10000,(i)=>stock('cached $i')),next:'more'));
  });
  await tester.pumpWidget(MaterialApp(home:Scaffold(body:StockPage(queue:q,service:service,client:mock))));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField),'old');
  await tester.pump(const Duration(milliseconds:401));await tester.pump();
  expect(calls,contains('old'));
  await tester.enterText(find.byType(TextField),'new');
  await tester.pump(const Duration(milliseconds:401));await tester.pump();
  expect(calls,contains('new'));
  latest.complete(reply(stockPage([stock('new result')])));
  await tester.pump();await tester.pump();
  old.complete(reply({'error':'stale failure'},503));
  await tester.pumpAndSettle();
  expect(find.text('new result'),findsOneWidget);
  expect(find.textContaining('Tìm trên server chưa thành công'),findsNothing);
  await tester.pumpWidget(const SizedBox.shrink());q.dispose();mock.close();
 });
 testWidgets('actuals late offline read cannot change newer online state',(tester)async{
  final q=MemoryQueue()..delayedRead=Completer<List<Map<String,dynamic>>>();
  var calls=0;
  final mock=MockClient((req)async{
   if(req.url.path.endsWith('/options'))return reply({'items':[{'id':'owner','code':'A','name':'A'}]});
   if(++calls==1)return reply({'error':'offline'},503);
   return reply({'items':[],'summary':{},'can_import':true});
  });
  await tester.pumpWidget(MaterialApp(home:ActualsPage(queue:q,client:ActualClient(q,client:mock))));
  await tester.pump();await tester.pump();
  expect(calls,1);
  final dynamic state=tester.state(find.byType(ActualsPage));
  unawaited(state.load() as Future<void>);
  await tester.pump();await tester.pump();
  q.delayedRead!.complete([{'items':[],'summary':{}}]);
  await tester.pumpAndSettle();
  expect(find.textContaining('Đang xem bản lưu trên máy'),findsNothing);
  expect(find.text('Nhập file'),findsOneWidget);
  // Rebuild after stale completion, to expose an out-of-setState mutation.
  await tester.pumpWidget(MaterialApp(home:ActualsPage(queue:q,client:ActualClient(q,client:mock))));
  await tester.pump();
  expect(find.textContaining('Đang xem bản lưu trên máy'),findsNothing);
  await tester.pumpWidget(const SizedBox.shrink());q.dispose();mock.close();
 });
 testWidgets('clearing assortment search does not cache the old subset',(tester)async{
  final q=MemoryQueue();
  final filtered=Completer<http.Response>(),full=Completer<http.Response>();
  var fullCalls=0;
  final mock=MockClient((req)async{
   if(req.url.queryParameters['q']=='old')return filtered.future;
   if(++fullCalls==1)return reply({'items':[sku('full initial')],'next_cursor':null});
   return full.future;
  });
  await tester.pumpWidget(MaterialApp(home:Scaffold(body:SingleChildScrollView(child:CustomerAssortmentSection(customerId:'c',ownerSub:'owner',queue:q,api:CustomerAssortmentApi('https://example.test','',client:mock))))));
  await tester.pumpAndSettle();
  final key='customer-products:c';
  expect(q.saved[key]!.single['name'],'full initial');
  await tester.enterText(find.byType(TextField),'old');
  await tester.pump(const Duration(milliseconds:301));await tester.pump();
  await tester.enterText(find.byType(TextField),'');
  filtered.complete(reply({'items':[sku('old subset')],'next_cursor':null}));
  await tester.pump();await tester.pump();
  expect(q.saved[key]!.single['name'],'full initial');
  await tester.pump(const Duration(milliseconds:301));await tester.pump();
  full.complete(reply({'items':[sku('full final')],'next_cursor':null}));
  await tester.pumpAndSettle();
  expect(q.saved[key]!.single['name'],'full final');
  await tester.pumpWidget(const SizedBox.shrink());q.dispose();mock.close();
 });
 testWidgets('performance reloads when staff options invalidate initial owner',(tester)async{
  final q=MemoryQueue();
  final staff=Completer<http.Response>();
  final owners=<String>[];
  final mock=MockClient((req)async{
   if(req.url.path.endsWith('/options'))return staff.future;
   owners.add(req.url.queryParameters['owner']!);
   return reply({'rows':[],'metric':{},'target_note':'test'});
  });
  await tester.pumpWidget(MaterialApp(home:Scaffold(body:PerformancePage(queue:q,regions:const RegionCatalog({}),service:service,client:ActualClient(q,client:mock)))));
  await tester.pump();await tester.pump();
  expect(owners,['owner']);
  staff.complete(reply({'items':[{'id':'other','code':'NV2','name':'Sales B'}],'can_view_team':true}));
  await tester.pumpAndSettle();
  expect(owners,['owner','other']);
  expect(tester.takeException(),isNull);
  await tester.pumpWidget(const SizedBox.shrink());q.dispose();mock.close();
 });
}
