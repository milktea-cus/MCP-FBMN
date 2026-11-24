import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sales_mien_tay/catalog.dart';
import 'package:sales_mien_tay/customers.dart';
import 'package:sales_mien_tay/field_work.dart';
import 'package:sales_mien_tay/models.dart';
import 'package:sales_mien_tay/offline_queue.dart';
import 'package:sales_mien_tay/org_scope_page.dart';
import 'package:sales_mien_tay/session.dart';
import 'package:sales_mien_tay/staff_page.dart';
import 'package:sales_mien_tay/theme.dart';

class LocalQueue extends OfflineQueue {
 LocalQueue():super(SalesSession(),'owner','1');
 bool failWrite=false;
 final saved=<String,List<Map<String,dynamic>>>{};
 @override Future<void> cache(String key,List<Map<String,dynamic>> items)async{
  if(failWrite)throw StateError('storage failure');
  saved[key]=items;
 }
 @override Future<List<Map<String,dynamic>>> cached(String key)async=>saved[key]??[];
}
http.Response reply(Map<String,dynamic> data)=>http.Response.bytes(
 utf8.encode(jsonEncode(data)),200,headers:{'content-type':'application/json; charset=utf-8'});
Map<String,dynamic> product(String name)=>{'name':name,'company_code':name,'id':name};
class OrgSession extends SalesSession{
 final old=Completer<Map<String,dynamic>>();
 final latest=Completer<Map<String,dynamic>>();
 final queries=<String>[];
 bool initial=true;
 @override Future<Map<String,dynamic>> get(String path)async{
  if(path=='/api/v1/admin/org')return {'staff':[{'user_sub':'s','active':true,'role':'sales','full_name':'Sales'}],
   'chains':initial?[{'id':'chain','name':'Old chain'}]:[]};
  final q=Uri.parse(path).queryParameters['q']??'';
  queries.add(q);
  if(q=='old')return old.future;
  if(q=='new')return latest.future;
  return {'items':[{'id':'c','name':'Old customer'}]};
 }
}
class StaffSession extends SalesSession{
 final territories=Completer<Map<String,dynamic>>();
 int loads=0;
 @override Future<Map<String,dynamic>> get(String path)async{
  if(path=='/api/v1/admin/staff')return {'items':[]};
  loads++;
  return territories.future;
 }
}
Future<void> flush(WidgetTester t)async{await t.pump();await t.pump();await t.pump();}
void main(){
 for(final width in [360.0,390.0,430.0,1280.0,1440.0]){
  testWidgets('catalog latest result and responsive controls at $width',(t)async{
   t.view.devicePixelRatio=1;t.view.physicalSize=Size(width,844);
   addTearDown(t.view.resetPhysicalSize);addTearDown(t.view.resetDevicePixelRatio);
   final queue=LocalQueue(),old=Completer<http.Response>(),latest=Completer<http.Response>();
   final calls=<String>[];
   final mock=MockClient((r)async{
    final q=r.url.queryParameters['q']??'';calls.add(q);
    if(q=='old')return old.future;
    if(q=='new')return latest.future;
    return reply({'items':[product('Initial product')],'next_cursor':null});
   });
   await t.pumpWidget(MaterialApp(theme:SalesTheme.build(width:width),
    home:Scaffold(body:CatalogPage(queue:queue,admin:true,
     service:CustomerService('https://example.test','',client:mock)))));
   await t.pumpAndSettle();
   expect(find.text('Initial product'),findsOneWidget);
   await t.enterText(find.byType(TextField),'old');
   await t.pump(const Duration(milliseconds:351));await flush(t);
   expect(calls,contains('old'));
   await t.enterText(find.byType(TextField),'new');
   old.complete(reply({'items':[product('Stale product')],'next_cursor':null}));
   await flush(t);
   expect(find.text('Stale product'),findsNothing);
   expect(queue.saved.containsKey('catalog-v1:admin:old'),isFalse);
   await t.pump(const Duration(milliseconds:351));await flush(t);
   latest.complete(reply({'items':[product('New product')],'next_cursor':null}));
   await t.pumpAndSettle();
   expect(find.text('New product'),findsOneWidget);
   expect(t.takeException(),isNull);
   await t.pumpWidget(const SizedBox());queue.dispose();mock.close();
  });
  testWidgets('route report remains fresh despite failed cache at $width',(t)async{
   t.view.devicePixelRatio=1;t.view.physicalSize=Size(width,844);
   addTearDown(t.view.resetPhysicalSize);addTearDown(t.view.resetDevicePixelRatio);
   final queue=LocalQueue()..failWrite=true;
   final mock=MockClient((r)async=>reply({'items':[{'full_name':'Sales New',
    'province':'Bến Tre','target':100,'forecast':20,'checkins':1,'forecasts':2}]}));
   await t.pumpWidget(MaterialApp(theme:SalesTheme.build(width:width),
    home:Scaffold(body:FieldWorkPage(queue:queue,regions:const RegionCatalog({}),
     service:CustomerService('https://example.test','',client:mock),report:true))));
   await t.pumpAndSettle();
   expect(find.text('Sales New · Bến Tre'),findsOneWidget);
   expect(find.textContaining('Dữ liệu lưu máy'),findsNothing);
   expect(find.textContaining('storage failure'),findsNothing);
   expect(t.takeException(),isNull);
   await t.pumpWidget(const SizedBox());queue.dispose();mock.close();
  });
 }
 testWidgets('org requests ignore stale results and reset missing keys',(t)async{
  final session=OrgSession();
  await t.pumpWidget(MaterialApp(home:OrgScopePage(session:session)));
  await t.pumpAndSettle();
  final dynamic state=t.state(find.byType(OrgScopePage));
  state.selectedCustomer='c';state.bindingKey='chain';state.assignmentKey='chain';
  state.kind='chain';state.key='chain';
  state.search.text='old';
  unawaited(state.refresh() as Future<void>);await flush(t);
  session.initial=false;
  state.search.text='new';
  unawaited(state.refresh() as Future<void>);await flush(t);
  expect(session.queries,containsAllInOrder(['','old','new']));
  session.latest.complete({'items':[{'id':'new','name':'New customer'}]});
  await t.pumpAndSettle();
  session.old.complete({'items':[{'id':'c','name':'Old customer'}]});
  await flush(t);
  expect((state.customers as List).single['id'],'new');
  expect(state.selectedCustomer,isNull);expect(state.bindingKey,isNull);
  expect(state.assignmentKey,isNull);expect(state.key,isNull);
  expect(t.takeException(),isNull);
  await t.pumpWidget(const SizedBox());
 });
 testWidgets('staff editor opens once and recovers from territory failure',(t)async{
  final session=StaffSession();
  await t.pumpWidget(MaterialApp(home:StaffPage(session:session)));
  await t.pumpAndSettle();
  final dynamic state=t.state(find.byType(StaffPage));
  unawaited(state.edit() as Future<void>);
  unawaited(state.edit() as Future<void>);
  await flush(t);
  expect(state.openingEditor,true);
  // Complete the async asset read before releasing the simulated network.
  await t.runAsync(()async{await Future<void>.delayed(const Duration(milliseconds:50));});
  await flush(t);
  expect(session.loads,1);
  session.territories.completeError(const ApiFailure(503,'territory offline'));
  await t.pumpAndSettle();
  expect(state.openingEditor,false);
  expect(find.textContaining('Không mở được hồ sơ nhân viên'),findsOneWidget);
  expect(t.takeException(),isNull);
  await t.pumpWidget(const SizedBox());
 });
}
