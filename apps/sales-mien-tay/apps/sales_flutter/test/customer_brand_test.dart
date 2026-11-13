import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:idb_shim/idb_shim.dart';
import 'package:sales_mien_tay/customer_assortment.dart';
import 'package:sales_mien_tay/offline_queue.dart';
import 'package:sales_mien_tay/session.dart';

const cid='11111111-1111-4111-8111-111111111111';
const bid='22222222-2222-4222-8222-222222222222';
const ref='33333333-3333-4333-8333-333333333333';

http.Response reply(Map<String,dynamic> data,{int status=200})=>
 http.Response(jsonEncode(data),status,headers:const {
  'content-type':'application/json; charset=utf-8',
 });
class Offline extends SalesSession{
 @override Future<Map<String,dynamic>> get(String path)async=>
  throw const ApiFailure(503,'offline');
}
Map<String,dynamic> brand(String status)=> {
 'brand_id':bid,'name':'FBMN','active':true,'status':status,
 'is_trading':status=='trading','manual_trading':status=='trading',
 'sku_trading':false,'manual_version':status=='trading'?2:0,
 'ordered':status=='ordered','imported':status=='imported',
};
void main(){
 test('P0-3 status labels never collapse ordered/imported/trading',(){
  expect(brandStatusLabel('ordered'),'Đã đặt');
  expect(brandStatusLabel('imported'),'Đã nhập');
  expect(brandStatusLabel('trading'),'Đang bán');
  expect(brandStatusLabel(null),'Chưa xác minh');
 });
 test('P0-3 customer brand GET, write and audit bind the same identity and scope',()async{
  final seen=<http.Request>[];
  final client=MockClient((req)async{
   seen.add(req);
   if(req.method=='POST')return reply({'item':{'brand_id':bid,'version':3}});
   if(req.url.path.endsWith('/audit'))return reply({'items':[]});
   return reply({'items':[brand('ordered')]});
  });
  final api=CustomerAssortmentApi('https://example.test','',
   identity:'seller-a',revision:'scope-1',client:client);
  final list=await api.brands(cid);
  expect(list.single['status'],'ordered');
  final audit=await api.brandAudit(cid);
  expect(audit['items'],isEmpty);
  final result=await api.updateBrand(cid,{
   'client_ref':ref,'brand_id':bid,'expected_version':2,
   'action':'verify','reason':'Đã kiểm tra bán hàng tại điểm',
  });
  expect((result['item'] as Map)['version'],3);
  expect(seen.map((r)=>r.url.path).toList(),[
   '/api/v1/customers/$cid/brands',
   '/api/v1/customers/$cid/brands/audit',
   '/api/v1/customers/$cid/brands',
  ]);
  expect(seen.last.method,'POST');
  expect(seen.last.headers['X-Sync-Identity'],'seller-a');
  expect(seen.last.headers['X-Sync-Revision'],'scope-1');
  expect(jsonDecode(seen.last.body)['action'],'verify');
  client.close();
 });
 test('P0-3 brand verification outbox survives restart but never crosses scope',()async{
  final factory=newIdbFactoryMemory();
  final seller=OfflineQueue(Offline(),'seller-a','scope-1',factory:factory);
  await seller.enqueue('/api/v1/customers/$cid/brands',{
   'client_ref':ref,'brand_id':bid,'expected_version':0,
   'action':'verify','reason':'Xác minh trực tiếp tại điểm bán',
  });
  final restarted=OfflineQueue(Offline(),'seller-a','scope-1',factory:factory);
  await restarted.reload();
  expect(restarted.pending.single['payload']['brand_id'],bid);
  final other=OfflineQueue(Offline(),'seller-b','scope-1',factory:factory);
  final revoked=OfflineQueue(Offline(),'seller-a','scope-2',factory:factory);
  await other.reload();
  await revoked.reload();
  expect(other.pending,isEmpty);
  expect(revoked.pending,isEmpty);
  expect(revoked.quarantined,1);
  seller.dispose();restarted.dispose();other.dispose();revoked.dispose();
 });
 testWidgets('market survey sightings appear in customer profile at 360px',(tester)async{
  tester.view.devicePixelRatio=1;
  tester.view.physicalSize=const Size(360,844);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final client=MockClient((req)async{
   if(req.url.path=='/api/v1/market/customers'){
    expect(req.url.queryParameters['customer_id'],cid);
    return reply({'items':[
     {'customer_id':cid,'brand':'MGP','last_seen_at':'2026-11-11T10:00:00Z'},
     {'customer_id':cid,'brand':'Thành Đạt','last_seen_at':'2026-11-12T10:00:00Z'},
    ]});
   }
   return reply({'items':[],'next_cursor':null});
  });
  final api=CustomerAssortmentApi('https://example.test','',client:client);
  await tester.pumpWidget(MaterialApp(home:Scaffold(body:SingleChildScrollView(
   child:CustomerAssortmentSection(customerId:cid,ownerSub:'seller-a',
    api:api,editable:true),
  ))));
  await tester.pump();
  await tester.tap(find.text('Nhãn hàng thị trường tại điểm bán'));
  await tester.pump();
  await tester.pump();
  expect(find.text('MGP'),findsOneWidget);
  expect(find.text('Thành Đạt'),findsOneWidget);
  expect(find.text('Sản phẩm của điểm bán'),findsOneWidget);
  expect(tester.takeException(),isNull);
  await tester.pumpWidget(const SizedBox.shrink());
  client.close();
 });
}
