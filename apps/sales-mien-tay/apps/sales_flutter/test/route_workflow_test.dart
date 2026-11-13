import 'package:flutter_test/flutter_test.dart';
import 'package:sales_mien_tay/route_workflow.dart';

void main(){
 test('route template serializes area without fake customer IDs',(){
  final stops=<Map<String,dynamic>>[
   {'stop_kind':'area','province':'An Giang','district':'','sequence':3,
    'purpose':'Phát triển đại lý','id':'server-1','visit_count':0},
  ];
  final items=routeTemplateStops(stops,[]);
  expect(items,singleton);
  expect(items.single['stop_kind'],'area');
  expect(items.single.containsKey('customer_id'),false);
  expect(items.single.containsKey('id'),false);
  expect(items.single['sequence'],3);
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
  expect(result.map((x)=>x['stop_kind']).toList(),['chain','customer']);
  expect(result.first['sequence'],1);
  expect(result.last['sequence'],2);
 });
 test('duplicate stop identity identifies area, chain and customer separately',(){
  expect(routeStopIdentity({'stop_kind':'area','province':'An Giang','district':''}),
   'area:An Giang:');
  expect(routeStopIdentity({'stop_kind':'chain','chain_id':'abc'}),'chain:abc');
  expect(routeStopIdentity({'stop_kind':'customer','customer_id':'abc'}),'customer:abc');
 });
}
