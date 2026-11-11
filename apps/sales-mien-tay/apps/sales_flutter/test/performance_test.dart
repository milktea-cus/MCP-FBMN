import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sales_mien_tay/actuals.dart';
import 'package:sales_mien_tay/customers.dart';
import 'package:sales_mien_tay/models.dart';
import 'package:sales_mien_tay/offline_queue.dart';
import 'package:sales_mien_tay/performance.dart';
import 'package:sales_mien_tay/session.dart';

class CacheQueue extends OfflineQueue{
 final Map<String,List<Map<String,dynamic>>> saved={};
 CacheQueue():super(SalesSession(),'owner','1');
 @override Future<void> cache(String k,List<Map<String,dynamic>> v)async{saved[k]=v;}
 @override Future<List<Map<String,dynamic>>> cached(String k)async=>saved[k]??[];
}
void main(){
 for(final width in [360.0,390.0]){
  testWidgets('4C scoped report, KPIs and offline readonly at $width',(tester)async{
   tester.view.devicePixelRatio=1;
   tester.view.physicalSize=Size(width,844);
   addTearDown(tester.view.resetPhysicalSize);
   addTearDown(tester.view.resetDevicePixelRatio);
   final q=CacheQueue();bool offline=false;final paths=<String>[];
   final month=DateTime.now().month;
   final mock=MockClient((r)async{
    paths.add(r.url.path);
    expect(r.headers['x-sync-identity'],'owner');
    expect(r.headers['x-sync-revision'],'1');
    if(offline)return http.Response('{"error":"offline"}',503);
    if(r.url.path.endsWith('/options'))return http.Response.bytes(utf8.encode(jsonEncode({
     'items':[{'id':'owner','name':'Sales A','code':'NV001'}],'can_view_team':false,
    })),200,headers:{'content-type':'application/json; charset=utf-8'});
    return http.Response.bytes(utf8.encode(jsonEncode({
     'filters':{'year':DateTime.now().year,'period':'month','month':month,'quarter':1,
      'group':'employee','owner':'owner','province':'','customer':'','product':''},
     'metric':{'target':'2000000','actual':'1500000','records':2,'quantity':'8',
      'remaining':'500000','progress_percent':75.0},
     'rows':[{'id':'owner','label':'Sales A','code':'NV001','actual':'1500000',
      'target':'2000000','records':2,'quantity':'8','remaining':'500000','progress_percent':75.0}],
     'target_dimension':'employee','target_note':'Target tổng của nhân viên; không cộng phân bổ khách/SKU.',
     'can_view_team':false,'group':'employee','has_data':true,
    })),200,headers:{'content-type':'application/json; charset=utf-8'});
   });
   await tester.pumpWidget(MaterialApp(home:Scaffold(body:PerformancePage(
    queue:q,regions:const RegionCatalog({}),service:const CustomerService('https://example.test','token'),
    client:ActualClient(q,client:mock)))));
   await tester.pumpAndSettle();
   expect(tester.takeException(),isNull);
   expect(find.text('Báo cáo kinh doanh'),findsOneWidget);
   expect(find.text('2.000.000 đ'),findsOneWidget);
   expect(find.text('1.500.000 đ'),findsWidgets);
   expect(find.text('75.0%'),findsWidgets);
   expect(find.textContaining('Target tổng của nhân viên'),findsWidgets);
   expect(paths,contains('/api/v1/reports/performance'));
   offline=true;
   await tester.tap(find.byTooltip('Làm mới báo cáo'));await tester.pumpAndSettle();
   expect(find.textContaining('Đang xem báo cáo lưu trên máy'),findsOneWidget);
   await tester.scrollUntilVisible(find.text('Xuất Excel (.xlsx)'),180,scrollable:find.byType(Scrollable).first);
   final button=tester.widget<FilledButton>(find.ancestor(of:find.text('Xuất Excel (.xlsx)'),matching:find.byWidgetPredicate((w)=>w is FilledButton)).first);
   expect(button.onPressed,isNull);
   expect(tester.takeException(),isNull);
   await tester.pumpWidget(const SizedBox());q.dispose();mock.close();
  });
 }
}
