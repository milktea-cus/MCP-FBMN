import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:idb_shim/idb_shim.dart';
import 'package:sales_mien_tay/customer_assortment.dart';
import 'package:sales_mien_tay/offline_queue.dart';
import 'package:sales_mien_tay/session.dart';

const customerId='11111111-1111-4111-8111-111111111111';
const productId='22222222-2222-4222-8222-222222222222';
const opId='33333333-3333-4333-8333-333333333333';
http.Response reply(Map<String,dynamic> data,{int status=200})=>
 http.Response.bytes(utf8.encode(jsonEncode(data)),status,headers:const {
  'content-type':'application/json; charset=utf-8',
 });
Map<String,dynamic> assortment(String status)=>{
 'product_id':productId,'company_code':'0009','sku':'B001',
 'name':'Bút bi xanh','brand':'FBMN','unit':'Hộp',
 'status':status,'is_trading':status=='trading',
 'manual_version':status=='trading'?2:null,
 'ordered_orders':status=='ordered'?1:0,
 'imported_orders':status=='imported'?1:0,
 'evidence_at':'2026-11-11T09:00:00Z',
};
class Disconnected extends SalesSession{
 @override Future<Map<String,dynamic>> get(String path) async=>
  throw const ApiFailure(503,'offline');
}
void main(){
 test('P0-D statuses never confuse order, company import and verified trading',(){
  expect(assortmentLabel('ordered'),'Đã đặt');
  expect(assortmentLabel('imported'),'Đã nhập hàng');
  expect(assortmentLabel('trading'),'Đang kinh doanh');
  expect(assortmentLabel(null),'Chưa xác minh');
  expect(assortmentDate('bad'),'Chưa ghi ngày');
 });
 test('P0-D GET keeps per-user sync revision and queries correct customer',()async{
  final seen=<http.Request>[];
  final mock=MockClient((req)async{
   seen.add(req);
   return reply({'items':[assortment('ordered')],'next_cursor':null});
  });
  final api=CustomerAssortmentApi('https://example.test','',
   identity:'seller-a',revision:'scope-1',client:mock);
  final list=await api.products(customerId,search:'0009');
  expect(list.single['status'],'ordered');
  expect(seen.single.url.path,'/api/v1/customers/$customerId/products');
  expect(seen.single.url.queryParameters['q'],'0009');
  expect(seen.single.headers['X-Sync-Identity'],'seller-a');
  expect(seen.single.headers['X-Sync-Revision'],'scope-1');
  mock.close();
 });
 test('P0-D pagination returns all unique SKU pages, not just first 60',()async{
  final cursors=<String>[];
  final client=MockClient((req)async{
   final after=req.url.queryParameters['after']??'';
   cursors.add(after);
   if(after.isEmpty)return reply({'items':[
    {...assortment('ordered'),'company_code':'0009'},
   ],'next_cursor':'0009'});
   return reply({'items':[
    {...assortment('imported'),'company_code':'0010',
     'product_id':'44444444-4444-4444-8444-444444444444'},
   ],'next_cursor':null});
  });
  final snapshots=<int>[];
  final api=CustomerAssortmentApi('https://example.test','',client:client);
  final rows=await api.products(customerId,onPage:(page)=>snapshots.add(page.length));
  expect(rows.length,2);
  expect(cursors,['','0009']);
  expect(snapshots,[1,2]);
  expect(rows.last['status'],'imported');
  client.close();
 });
 test('P0-D manual audit and catalog version support re-verification',()async{
  final seen=<Uri>[];
  final mock=MockClient((req)async{
   seen.add(req.url);
   if(req.url.path.endsWith('/catalog'))return reply({'items':[{
    ...assortment('ordered'),'manual_version':5,'manual_verified':false,
   }],'next_cursor':null});
   if(req.url.path.endsWith('/audit'))return reply({'items':[{
    'action':'unverify','reason':'Đã kiểm tra lại thực tế',
    'actor_sub':'seller-a',
   }]});
   return reply({'item':{'product_id':productId,'version':6}});
  });
  final api=CustomerAssortmentApi('https://example.test','',client:mock);
  final rows=await api.catalog(customerId,search:'Bút');
  expect(rows.single['manual_version'],5);
  expect(rows.single['manual_verified'],false);
  expect((await api.audit(customerId)).single['action'],'unverify');
  final result=await api.update(customerId,{
   'client_ref':opId,'product_id':productId,'expected_version':5,
   'action':'verify','reason':'Xác minh trực tiếp tại điểm bán',
  });
  expect((result['item'] as Map)['version'],6);
  expect(seen[0].path,'/api/v1/customers/$customerId/products/catalog');
  expect(seen[1].path,'/api/v1/customers/$customerId/products/audit');
  expect(seen[2].path,'/api/v1/customers/$customerId/products');
  mock.close();
 });
 test('P0-D offline queue is durable, per account and sync revision',()async{
  final factory=newIdbFactoryMemory();
  final seller=OfflineQueue(Disconnected(),'seller-a','scope-1',factory:factory);
  await seller.enqueue('/api/v1/customers/$customerId/products',{
   'client_ref':opId,'product_id':productId,
   'expected_version':0,'action':'verify',
   'reason':'Xác minh trực tiếp tại điểm bán',
  });
  final restarted=OfflineQueue(Disconnected(),'seller-a','scope-1',factory:factory);
  await restarted.reload();
  expect(restarted.pending.single['payload']['client_ref'],opId);
  expect(restarted.pending.single['payload']['product_id'],productId);
  final other=OfflineQueue(Disconnected(),'seller-b','scope-1',factory:factory);
  final revoked=OfflineQueue(Disconnected(),'seller-a','scope-2',factory:factory);
  await other.reload();await revoked.reload();
  expect(other.pending,isEmpty);
  expect(revoked.pending,isEmpty);
  expect(revoked.quarantined,1);
  seller.dispose();restarted.dispose();other.dispose();revoked.dispose();
 });
 for(final width in [360.0,390.0,430.0]){
  testWidgets('P0-D mobile shop card distinguishes source and opens audit at $width',
   (tester)async{
   tester.view.devicePixelRatio=1;
   tester.view.physicalSize=Size(width,844);
   addTearDown(tester.view.resetPhysicalSize);
   addTearDown(tester.view.resetDevicePixelRatio);
   final mock=MockClient((req)async{
    if(req.url.path.endsWith('/audit'))return reply({'items':[]});
    return reply({'items':[assortment('imported')],'next_cursor':null});
   });
   await tester.pumpWidget(MaterialApp(home:Scaffold(body:SingleChildScrollView(
    child:CustomerAssortmentSection(customerId:customerId,ownerSub:'seller-a',
     api:CustomerAssortmentApi('https://example.test','',client:mock)),
   ))));
   await tester.pump();
   await tester.pump();
   expect(find.text('Sản phẩm của điểm bán'),findsOneWidget);
   expect(find.textContaining('Đã nhập hàng'),findsWidgets);
   expect(find.textContaining('Bút bi xanh'),findsOneWidget);
   expect(find.text('Xác minh SKU'),findsNothing);
   expect(tester.takeException(),isNull);
   await tester.pumpWidget(const SizedBox.shrink());
   mock.close();
  });
 }
 testWidgets('P0-D permission revocation hides local evidence', (tester)async{
  final response=Completer<http.Response>();
  final client=MockClient((_)=>response.future);
  await tester.pumpWidget(MaterialApp(home:Scaffold(body:
   CustomerAssortmentSection(customerId:customerId,ownerSub:'seller-a',
    api:CustomerAssortmentApi('https://example.test','',client:client)))));
  await tester.pump();
  response.complete(reply({'error':'Phạm vi không hợp lệ'},status:403));
  await tester.pump();await tester.pump();
  expect(find.textContaining('quyền xem sản phẩm'),findsOneWidget);
  expect(find.textContaining('Bút bi xanh'),findsNothing);
  await tester.pumpWidget(const SizedBox.shrink());
  client.close();
 });
}
