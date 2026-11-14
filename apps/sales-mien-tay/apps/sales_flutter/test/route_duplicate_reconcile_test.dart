import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:idb_shim/idb_shim.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sales_mien_tay/offline_queue.dart';
import 'package:sales_mien_tay/session.dart';

const oldRoute='11111111-1111-4111-8111-111111111111';
const serverRoute='22222222-2222-4222-8222-222222222222';
const plan='33333333-3333-4333-8333-333333333333';
const stop='44444444-4444-4444-8444-444444444444';
const existingStop='55555555-5555-4555-8555-555555555555';
const owner='retry-user';
const draftRoute=<String,dynamic>{
 'client_ref':oldRoute,'monthly_plan_id':plan,
 'route_date':'2026-11-12','purpose':'Khảo sát thị trường',
 'note':'','status':'ready',
};
Map<String,dynamic> existingRoute({String purpose='Khảo sát thị trường',
 String ownerSub=owner})=> {
 'id':serverRoute,'owner_sub':ownerSub,
 'monthly_plan_id':plan,'route_date':'2026-11-12T00:00:00.000Z',
 'purpose':purpose,'note':'','status':'ready',
};
http.Response send(Object body,int code)=>http.Response(jsonEncode(body),code,
 headers:{'content-type':'application/json'});
class Authorized extends SalesSession{
 @override Future<Map<String,dynamic>> get(String path)async=>
  {'identity':owner,'scope_revision':'8'};
}
Future<void> blockRoute(OfflineQueue q)async{
 await q.enqueue('/api/v1/day-routes',draftRoute);
 final d=await q.db,t=d.transaction('outbox',idbModeReadWrite);
 final row=q.pending.single;
 await t.objectStore('outbox').put({...row,
  'status':'blocked','error':'HTTP 409: Tuyến hoặc điểm ghé bị trùng'});
 await t.completed;await q.reload();
}

void main(){
 test('409 exact route already saved remaps dependent stops with GET only',()async{
  final factory=newIdbFactoryMemory();
  var gets=0,posts=0;
  final net=MockClient((req)async{
   if(req.method=='GET'&&req.url.path=='/api/v1/day-routes'){
    gets++;expect(req.url.queryParameters['month'],'2026-11');
    return send({'items':[existingRoute()]},200);
   }
   if(req.method=='POST'&&req.url.path=='/api/v1/day-routes/'+serverRoute+'/stops'){
    posts++;return send({'item':{'id':existingStop}},201);
   }
   fail('Unexpected request '+req.method+' '+req.url.toString());
  });
  final q=OfflineQueue(Authorized(),owner,'8',factory:factory,networkClient:net);
  await blockRoute(q);
  await q.enqueue('/api/v1/day-routes/'+oldRoute+'/stops',{
   'client_ref':stop,'stop_kind':'area','province':'Bến Tre',
   'district':'Huyện Bình Đại','sequence':1,'purpose':'Tìm điểm bán mới',
  },dependsOn:[oldRoute]);
  expect(q.pending.length,2);
  await q.reconcileBlockedRoutes();
  expect(gets,1);expect(posts,0);
  expect(q.pending.length,1);
  expect(q.blockedCount,0);
  expect(q.pending.single['path'],'/api/v1/day-routes/'+serverRoute+'/stops');
  expect(q.pending.single['depends_on'],isEmpty);
  await q.sync();
  expect(q.pending,isEmpty);expect(posts,1);
  final reopened=OfflineQueue(Authorized(),owner,'8',factory:factory,networkClient:net);
  await reopened.reload();expect(reopened.pending,isEmpty);
  q.dispose();reopened.dispose();net.close();
 });

 test('different-purpose duplicate remains blocked and never re-POSTs on retry',()async{
  final factory=newIdbFactoryMemory();
  var gets=0,posts=0;
  final net=MockClient((req)async{
   if(req.method=='GET'){
    gets++;return send({'items':[existingRoute(purpose:'Bán hàng')]},200);
   }
   posts++;return send({'error':'Tuyến bị trùng'},409);
  });
  final q=OfflineQueue(Authorized(),owner,'8',factory:factory,networkClient:net);
  await blockRoute(q);
  final key=q.pending.single['key'].toString();
  await q.reconcileBlockedRoutes();
  expect(q.pending.single['status'],'blocked');
  await q.retryBlocked(key);
  expect(q.pending.single['status'],'blocked');
  expect(q.error,contains('nội dung không khớp'));
  expect(gets,2);expect(posts,0);
  q.dispose();net.close();
 });

 test('another owner or denied scope cannot acknowledge route',()async{
  final factory=newIdbFactoryMemory();
  final net=MockClient((req)async=>send({
   'items':[existingRoute(ownerSub:'other-user')]},200));
  final q=OfflineQueue(Authorized(),owner,'8',factory:factory,networkClient:net);
  await blockRoute(q);await q.reconcileBlockedRoutes();
  expect(q.pending.length,1);
  expect(q.pending.single['status'],'blocked');
  q.dispose();net.close();
 });

 test('409 identical route stop is acknowledged without duplicate write',()async{
  final factory=newIdbFactoryMemory();
  const path='/api/v1/day-routes/'+serverRoute+'/stops';
  final payload=<String,dynamic>{'client_ref':stop,'stop_kind':'area',
   'province':'Bến Tre','district':'Huyện Bình Đại','sequence':1,
   'purpose':'Tìm điểm bán mới'};
  var posts=0,gets=0;
  final net=MockClient((req)async{
   if(req.method=='POST'){
    posts++;return send({'error':'Tuyến bị trùng'},409);
   }
   if(req.method=='GET'){
    gets++;
    expect(req.url.path,'/api/v1/day-routes/'+serverRoute);
    return send({'item':{'id':serverRoute,'owner_sub':owner},'stops':[{
     'id':existingStop,'day_route_id':serverRoute,'owner_sub':owner,
     'stop_kind':'area','province':'Bến Tre','district':'Huyện Bình Đại',
     'sequence':1,'purpose':'Tìm điểm bán mới','is_unplanned':false,
    }]},200);
   }
   fail('Unexpected HTTP method');
  });
  final q=OfflineQueue(Authorized(),owner,'8',factory:factory,networkClient:net);
  await q.enqueue(path,payload);
  await q.sync();
  expect(posts,1);expect(gets,1);
  expect(q.pending,isEmpty);
  q.dispose();net.close();
 });

 test('409 with GET permission denied keeps full local payload',()async{
  final factory=newIdbFactoryMemory();
  var posts=0;
  final net=MockClient((req)async{
   if(req.method=='POST'){posts++;return send({'error':'Tuyến bị trùng'},409);}
   return send({'error':'Không được phép xem tuyến'},403);
  });
  final q=OfflineQueue(Authorized(),owner,'8',factory:factory,networkClient:net);
  await q.enqueue('/api/v1/day-routes',draftRoute);
  await q.sync();
  expect(posts,1);expect(q.pending.single['status'],'blocked');
  expect((q.pending.single['payload'] as Map)['client_ref'],oldRoute);
  await q.reconcileBlockedRoutes();
  expect(q.pending.length,1);expect(posts,1);
  q.dispose();net.close();
 });
}
