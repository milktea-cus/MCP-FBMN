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
  'status':'blocked','error':'Tuyến hoặc điểm ghé bị trùng'});
 await t.completed;await q.reload();
}

void main(){
 test('unplanned stop identity matches only actual unplanned customer',(){
  final row={'owner_sub':owner,'day_route_id':serverRoute,
   'stop_kind':'customer','is_unplanned':true,'customer_id':plan,
   'sequence':1,'purpose':'Ghé khách phát sinh'};
  final draft={'stop_kind':'customer','customer_id':plan,
   'sequence':1,'purpose':'Ghé khách phát sinh'};
  expect(sameSavedStop(row,draft,owner,serverRoute),false);
  expect(sameSavedStop(row,draft,owner,serverRoute,isUnplanned:true),true);
 });

 test('old blocked unplanned customer stop reconciles without another POST',()async{
  final factory=newIdbFactoryMemory();
  var gets=0,posts=0;
  final net=MockClient((req)async{
   if(req.method=='GET'){
    gets++;
    expect(req.url.path,'/api/v1/day-routes/'+serverRoute);
    return send({'item':{'id':serverRoute,'owner_sub':owner},'stops':[{
     'id':existingStop,'owner_sub':owner,'day_route_id':serverRoute,
     'stop_kind':'customer','is_unplanned':true,'customer_id':plan,
     'sequence':1,'purpose':'Ghé khách phát sinh'}]},200);
   }
   posts++;
   return send({'error':'route conflict'},409);
  });
  final q=OfflineQueue(Authorized(),owner,'8',factory:factory,networkClient:net);
  await q.enqueue('/api/v1/day-routes/'+serverRoute+'/unplanned-stops',{
   'client_ref':stop,'stop_kind':'customer','customer_id':plan,
   'sequence':1,'purpose':'Ghé khách phát sinh',
   'captured_at':'2026-11-12T10:00:00Z'});
  final d=await q.db,t=d.transaction('outbox',idbModeReadWrite);
  await t.objectStore('outbox').put({...q.pending.single,
   'status':'blocked','error':'HTTP 409'});
  await t.completed;await q.reload();
  await q.reconcileBlockedRoutes();
  expect(gets,1);expect(posts,0);expect(q.pending,isEmpty);
  q.dispose();net.close();
 });

 test('conflicting unplanned customer keeps durable outbox',()async{
  final factory=newIdbFactoryMemory();
  var posts=0;
  final net=MockClient((req)async{
   if(req.method=='GET')return send({'item':{
    'id':serverRoute,'owner_sub':owner},'stops':[{
     'id':existingStop,'owner_sub':owner,'day_route_id':serverRoute,
     'stop_kind':'customer','is_unplanned':true,'customer_id':plan,
     'sequence':2,'purpose':'Khác nội dung'}]},200);
   posts++;return send({'error':'conflict'},409);
  });
  final q=OfflineQueue(Authorized(),owner,'8',factory:factory,networkClient:net);
  await q.enqueue('/api/v1/day-routes/'+serverRoute+'/unplanned-stops',{
   'client_ref':stop,'stop_kind':'customer','customer_id':plan,
   'sequence':1,'purpose':'Ghé khách phát sinh',
   'captured_at':'2026-11-12T10:00:00Z'});
  final d=await q.db,t=d.transaction('outbox',idbModeReadWrite);
  await t.objectStore('outbox').put({...q.pending.single,
   'status':'blocked','error':'HTTP 409'});
  await t.completed;await q.reload();
  await q.reconcileBlockedRoutes();
  expect(posts,0);expect(q.pending.single['status'],'blocked');
  q.dispose();net.close();
 });

 test('reusing client_ref cannot overwrite a blocked draft',()async{
  final q=OfflineQueue(Authorized(),owner,'8',factory:newIdbFactoryMemory());
  await q.enqueue('/api/v1/day-routes/'+serverRoute+'/unplanned-stops',{
   'client_ref':stop,'stop_kind':'customer','customer_id':plan,
   'sequence':1,'purpose':'Ghé khách phát sinh'});
  final first=Map<String,dynamic>.from(q.pending.single);
  await q.enqueue('/api/v1/day-routes/'+serverRoute+'/unplanned-stops',{
   'client_ref':stop,'stop_kind':'customer','customer_id':plan,
   'sequence':1,'purpose':'Ghé khách phát sinh'});
  expect(q.pending.length,1);
  await expectLater(q.enqueue('/api/v1/day-routes/'+serverRoute+'/unplanned-stops',{
   'client_ref':stop,'stop_kind':'customer','customer_id':plan,
   'sequence':2,'purpose':'Khác'}),throwsStateError);
  expect(q.pending.single['payload'],first['payload']);
  q.dispose();
 });

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

 test('blocked 409 stop maps dependent area visit and survey draft atomically',()async{
  final factory=newIdbFactoryMemory();
  var posts=0;
  final net=MockClient((req)async{
   if(req.method!='GET'){posts++;return send({'error':'Unexpected write'},500);}
   expect(req.url.path,'/api/v1/day-routes/'+serverRoute);
   return send({'item':{'id':serverRoute,'owner_sub':owner},'stops':[{
    'id':existingStop,'day_route_id':serverRoute,'owner_sub':owner,
    'stop_kind':'area','province':'Bến Tre','district':'Huyện Bình Đại',
    'sequence':1,'purpose':'Tìm điểm bán mới','is_unplanned':false,
   }]},200);
  });
  final q=OfflineQueue(Authorized(),owner,'8',factory:factory,networkClient:net);
  await q.enqueue('/api/v1/day-routes/'+serverRoute+'/stops',{
   'client_ref':stop,'stop_kind':'area','province':'Bến Tre',
   'district':'Huyện Bình Đại','sequence':1,'purpose':'Tìm điểm bán mới'});
  await q.enqueue('/api/v1/area-visits',{
   'client_ref':'66666666-6666-4666-8666-666666666666',
   'day_route_stop_id':stop,
  },dependsOn:[stop]);
  await q.saveSurveyDraft({
   'id':'77777777-7777-4777-8777-777777777777',
   'day_route_stop_id':stop,'status':'in_progress',
   'answers':{'verified':true},'photos':[],
  });
  final d=await q.db,t=d.transaction('outbox',idbModeReadWrite);
  final raw=q.pending.first;
  await t.objectStore('outbox').put({...raw,'status':'blocked',
   'error':'HTTP 409: Tuyến hoặc điểm ghé bị trùng'});
  await t.completed;await q.reload();
  await q.reconcileBlockedRoutes();
  expect(posts,0);
  expect(q.pending.length,1);
  final child=q.pending.single;
  expect((child['payload'] as Map)['day_route_stop_id'],existingStop);
  expect(child['depends_on'],isEmpty);
  expect((await q.cached('survey-drafts')).single['day_route_stop_id'],
   existingStop);
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
 test('archiving server schedule removes only orphaned planned route/stops from outbox',()async{
  final factory=newIdbFactoryMemory();
  final q=OfflineQueue(Authorized(),owner,'8',factory:factory);
  await q.enqueue('/api/v1/day-routes',draftRoute);
  await q.enqueue('/api/v1/day-routes/'+oldRoute+'/stops',{
   'client_ref':stop,'stop_kind':'area','sequence':1,'purpose':'Tìm điểm bán mới',
  },dependsOn:[oldRoute]);
  expect(q.pending.length,2);
  final cleared=await q.discardPendingForArchivedPlan(plan);
  expect(cleared,2);
  expect(q.pending,isEmpty);
  final reopened=OfflineQueue(Authorized(),owner,'8',factory:factory);
  await reopened.reload();expect(reopened.pending,isEmpty);
  q.dispose();reopened.dispose();
 });

 test('archived plan retains queued area visit and its route graph for safety',()async{
  final factory=newIdbFactoryMemory();
  final q=OfflineQueue(Authorized(),owner,'8',factory:factory);
  await q.enqueue('/api/v1/day-routes',draftRoute);
  await q.enqueue('/api/v1/day-routes/'+oldRoute+'/stops',{
   'client_ref':stop,'stop_kind':'area','sequence':1,'purpose':'Tìm điểm bán mới',
  },dependsOn:[oldRoute]);
  await q.enqueue('/api/v1/area-visits',{
   'client_ref':'66666666-6666-4666-8666-666666666666',
   'day_route_stop_id':stop,
  },dependsOn:[stop]);
  expect(await q.discardPendingForArchivedPlan(plan),0);
  expect(q.pending.length,3);
  q.dispose();
 });

 test('old iPhone blocked route disappears only after server confirms plan archived',()async{
  final factory=newIdbFactoryMemory();
  var checks=0,writes=0;
  final net=MockClient((req)async{
   if(req.method!='GET'){writes++;return send({'error':'No writes permitted'},500);}
   checks++;
   if(req.url.path=='/api/v1/day-routes'){
    return send({'items':[{...existingRoute(),'status':'cancelled'}]},200);
   }
   if(req.url.path=='/api/v1/monthly-plans'){
    return send({'items':[{'id':plan,'owner_sub':owner,'status':'cancelled'}]},200);
   }
   fail('Unexpected read');
  });
  final q=OfflineQueue(Authorized(),owner,'8',factory:factory,networkClient:net);
  await blockRoute(q);
  await q.reconcileBlockedRoutes();
  expect(checks,2);expect(writes,0);
  expect(q.pending,isEmpty);
  q.dispose();net.close();
 });

 test('archived unstarted route clears orphan blocked stop after GET only',()async{
  final factory=newIdbFactoryMemory();
  var gets=0,writes=0;
  final client=MockClient((req)async{
   if(req.method!='GET'){writes++;return send({'error':'unexpected write'},500);}
   gets++;
   return send({'item':{'owner_sub':owner,'id':serverRoute,
    'status':'cancelled','plan_status':'cancelled'},'stops':[]},200);
  });
  final q=OfflineQueue(Authorized(),owner,'8',factory:factory,networkClient:client);
  final path='/api/v1/day-routes/'+serverRoute+'/stops';
  await q.enqueue(path,{
   'client_ref':stop,'stop_kind':'area','province':'Bến Tre',
   'district':'Huyện Bình Đại','sequence':2,'purpose':'Tìm điểm bán mới'});
  final d=await q.db,t=d.transaction('outbox',idbModeReadWrite);
  await t.objectStore('outbox').put({...q.pending.single,
   'status':'blocked','error':'Tuyến hoặc điểm ghé bị trùng'});
  await t.completed;await q.reload();
  await q.reconcileBlockedRoutes();
  expect(gets,1);expect(writes,0);expect(q.pending,isEmpty);
  q.dispose();client.close();
 });

 test('archived unstarted route preserves blocked stop with offline survey evidence',()async{
  final factory=newIdbFactoryMemory();
  final client=MockClient((req)async=>send({
   'item':{'owner_sub':owner,'id':serverRoute,
    'status':'cancelled','plan_status':'cancelled'},'stops':[]},200));
  final q=OfflineQueue(Authorized(),owner,'8',factory:factory,networkClient:client);
  final path='/api/v1/day-routes/'+serverRoute+'/stops';
  await q.enqueue(path,{
   'client_ref':stop,'stop_kind':'area','province':'Bến Tre',
   'district':'Huyện Bình Đại','sequence':2,'purpose':'Tìm điểm bán mới'});
  await q.saveSurveyDraft({
   'id':'88888888-8888-4888-8888-888888888888',
   'day_route_stop_id':stop,'answers':{'notes':'Not sent yet'},
  });
  final d=await q.db,t=d.transaction('outbox',idbModeReadWrite);
  await t.objectStore('outbox').put({...q.pending.single,
   'status':'blocked','error':'HTTP 409'});
  await t.completed;await q.reload();
  await q.reconcileBlockedRoutes();
  expect(q.pending.length,1);
  expect((await q.cached('survey-drafts')).single['day_route_stop_id'],stop);
  q.dispose();client.close();
 });

 test('200 already_saved remaps route reference rather than POSTing stale child ID',()async{
  final factory=newIdbFactoryMemory();
  var routePosts=0;
  final stopPaths=<String>[];
  final client=MockClient((req)async{
   if(req.method!='POST')return send({'error':'unexpected read'},500);
   if(req.url.path=='/api/v1/day-routes'){
    routePosts++;
    return send({'item':existingRoute(),'already_saved':true},200);
   }
   if(req.url.path.endsWith('/stops')){
    stopPaths.add(req.url.path);
    return send({'item':{'id':stop}},201);
   }
   return send({'error':'Unknown'},404);
  });
  final q=OfflineQueue(Authorized(),owner,'8',factory:factory,networkClient:client);
  await q.enqueue('/api/v1/day-routes',draftRoute);
  await q.enqueue('/api/v1/day-routes/'+oldRoute+'/stops',{
   'client_ref':stop,'stop_kind':'area','province':'Bến Tre',
   'district':'Huyện Bình Đại','sequence':1,'purpose':'Tìm điểm bán mới'
  },dependsOn:[oldRoute]);
  await q.sync();
  for(var i=0;i<20&&q.pending.isNotEmpty;i++){
   await Future<void>.delayed(const Duration(milliseconds:10));
  }
  expect(routePosts,1);
  expect(stopPaths,['/api/v1/day-routes/'+serverRoute+'/stops']);
  expect(q.pending,isEmpty);
  q.dispose();client.close();
 });

}
