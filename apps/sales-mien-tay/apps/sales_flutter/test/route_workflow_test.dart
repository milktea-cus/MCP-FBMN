import 'package:flutter_test/flutter_test.dart';
import 'package:sales_mien_tay/route_workflow.dart';

void main(){
 test('legacy area scope stays in history, never in customer route template',(){
  final stops=<Map<String,dynamic>>[
   {'stop_kind':'area','province':'An Giang','district':'','sequence':3,
    'purpose':'Phát triển đại lý','id':'server-1','visit_count':0},
  ];
  final items=routeTemplateStops(stops,[]);
  expect(items,isEmpty);
  // The original stop is not removed: it is only excluded from new templates.
  expect(stops.single['stop_kind'],'area');
 });
 test('route template keeps real customer and unsynced stops in order',(){
  final saved=<Map<String,dynamic>>[
   {'stop_kind':'customer','customer_id':'c-1','sequence':2,'purpose':'Khảo sát'},
  ];
  final pending=<Map<String,dynamic>>[
   {'path':'/api/v1/day-routes/route/stops','method':'POST',
    'payload':{'stop_kind':'chain','chain_id':'chain-1','sequence':1,'purpose':'Chuỗi'}},
   {'path':'/api/v1/day-routes/route/stops/x','method':'PATCH',
    'payload':{'stop_kind':'customer','customer_id':'c-1','sequence':99}},
  ];
  final result=routeTemplateStops(saved,pending);
  expect(result.map((x)=>x['stop_kind']).toList(),['customer']);
  expect(result.single['sequence'],2);
 });
 test('duplicate stop identity identifies area, chain and customer separately',(){
  expect(routeStopIdentity({'stop_kind':'area','province':'An Giang','district':''}),
   'area:An Giang:');
  expect(routeStopIdentity({'stop_kind':'chain','chain_id':'abc'}),'chain:abc');
  expect(routeStopIdentity({'stop_kind':'customer','customer_id':'abc'}),'customer:abc');
 });
}
