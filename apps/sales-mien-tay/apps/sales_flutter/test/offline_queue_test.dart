import 'dart:typed_data';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idb_shim/idb_shim.dart';
import 'package:sales_mien_tay/offline_queue.dart';
import 'package:sales_mien_tay/session.dart';

class Disconnected extends SalesSession {
 @override Future<Map<String,dynamic>> get(String path) async => throw const ApiFailure(503,'offline');
}
class ReadyForSync extends SalesSession{
 int meChecks=0;
 @override Future<Map<String,dynamic>> get(String path)async{
  meChecks++;
  return {'identity':'retry-user','scope_revision':'8'};
 }
}
class CountedFailure extends SalesSession{
 int meChecks=0;
 @override Future<Map<String,dynamic>> get(String path)async{
  meChecks++;
  throw const ApiFailure(503,'Máy chủ không phản hồi');
 }
}
void main(){
 test('server success without item clears outbox once, never replays receipt',()async{
  final factory=newIdbFactoryMemory(),session=ReadyForSync();
  var sends=0;
  final network=MockClient((req)async{
   sends++;
   expect(req.headers['X-Sync-Identity'],'retry-user');
   expect(req.headers['X-Sync-Revision'],'8');
   return http.Response(jsonEncode({'ok':true}),200,
    headers:{'content-type':'application/json'});
  });
  final queue=OfflineQueue(session,'retry-user','8',
   factory:factory,networkClient:network);
  await queue.enqueue('/api/v1/notifications/42/read',{});
  await queue.sync();
  expect(queue.pending,isEmpty);
  expect(sends,1);
  expect(queue.syncing,isFalse);
  await queue.sync();
  expect(sends,1);
  queue.dispose();network.close();
 });
 test('repeated server 503 is throttled but pending survives restart',()async{
  final factory=newIdbFactoryMemory(),session=CountedFailure();
  final queue=OfflineQueue(session,'retry-user','8',factory:factory);
  await queue.enqueue('/api/v1/notifications/42/read',{});
  await queue.sync();
  expect(queue.pending.length,1);
  expect(queue.error,contains('503'));
  expect(queue.nextRetryAt,isNotNull);
  expect(queue.syncing,isFalse);
  await queue.sync();await queue.sync();
  expect(session.meChecks,1);
  final restart=OfflineQueue(session,'retry-user','8',factory:factory);
  await restart.reload();
  expect(restart.pending.length,1);
  queue.dispose();restart.dispose();
 });
 test('HTTP 409 becomes blocked, user can retry without dropping operation',()async{
  final factory=newIdbFactoryMemory(),session=ReadyForSync();
  var sends=0;
  final network=MockClient((req)async{
   sends++;
   return http.Response(jsonEncode({'error':'Phiên đã thay đổi'}),409,
    headers:{'content-type':'application/json'});
  });
  final queue=OfflineQueue(session,'retry-user','8',
   factory:factory,networkClient:network);
  await queue.enqueue('/api/v1/notifications/42/read',{});
  await queue.sync();
  expect(queue.pending.single['status'],'blocked');
  expect(queue.blockedCount,1);
  expect(queue.describe(queue.pending.single),'Đánh dấu thông báo');
  expect(queue.pending.single['error'],contains('Phiên đã thay đổi'));
  await queue.sync();
  expect(sends,1);
  await queue.retryBlocked(queue.pending.single['key'].toString());
  expect(sends,2);
  expect(queue.pending.single['status'],'blocked');
  queue.dispose();network.close();
 });

 test('unplanned and missed visits are accepted by account-scoped offline outbox',() async{
  const route='11111111-1111-4111-8111-111111111111';
  const stop='22222222-2222-4222-8222-222222222222';
  final unplanned='/api/v1/day-routes/$route/unplanned-stops';
  final missed='/api/v1/day-routes/$route/stops/$stop/missed';
  expect(isWorkVisitOfflineOperation(unplanned),isTrue);
  expect(isWorkVisitOfflineOperation(missed),isTrue);
  expect(isWorkVisitOfflineOperation('/api/v1/day-routes/not-a-uuid/unplanned-stops'),isFalse);
  final factory=newIdbFactoryMemory();
  final q=OfflineQueue(Disconnected(),'field-owner','9',factory:factory);
  await q.enqueue(unplanned,{'client_ref':'33333333-3333-4333-8333-333333333333','stop_kind':'area'});
  await q.enqueue(missed,{'client_ref':'44444444-4444-4444-8444-444444444444','reason_code':'closed'});
  final reopened=OfflineQueue(Disconnected(),'field-owner','9',factory:factory);
  await reopened.reload();
  expect(reopened.pending.map((v)=>v['path']).toList(),[unplanned,missed]);
  final revoked=OfflineQueue(Disconnected(),'field-owner','10',factory:factory);
  await revoked.reload();
  expect(revoked.pending,isEmpty);
  q.dispose();reopened.dispose();revoked.dispose();
 });

 test('session draft and dependent operations survive restart and isolate accounts',() async{
  final factory=newIdbFactoryMemory();final a=OfflineQueue(Disconnected(),'survey-owner','1',factory:factory);
  final draft=<String,dynamic>{'id':'11111111-1111-4111-8111-111111111111','status':'in_progress','answers':{'present':true},'photos':[]};
  await a.saveSurveyDraft(draft,path:'/api/v1/sessions',payload:{'client_ref':draft['id']});
  await a.saveSurveyDraft({...draft,'status':'completed_pending'},path:'/api/v1/sessions/${draft['id']}',method:'PATCH',payload:{'client_ref':'22222222-2222-4222-8222-222222222222'},dependsOn:[draft['id'] as String]);
  final b=OfflineQueue(Disconnected(),'survey-owner','1',factory:factory);await b.reload();expect(b.pending.length,2);expect((await b.cached('survey-drafts')).single['status'],'completed_pending');expect(b.pending.last['depends_on'],[draft['id']]);
  final other=OfflineQueue(Disconnected(),'other','1',factory:factory);expect(await other.cached('survey-drafts'),isEmpty);await other.reload();expect(other.pending,isEmpty);
  a.dispose();b.dispose();other.dispose();
 });
 test('explicit retry preserves failed draft until authorized sync succeeds',()async{
  final factory=newIdbFactoryMemory();
  final q=OfflineQueue(Disconnected(),'retry-user','8',factory:factory);
  await q.enqueue('/api/v1/notifications/42/read',{});
  await q.reload();
  final key=q.pending.single['key'] as String;
  final db=await q.db,t=db.transaction('outbox',idbModeReadWrite);
  await t.objectStore('outbox').put({...q.pending.single,'status':'blocked','error':'409 conflict'});
  await t.completed;
  await q.reload();
  expect(q.pending.single['status'],'blocked');
  await q.retryBlocked(key);
  expect(q.pending.single['key'],key);
  expect(q.pending.single['status'],'pending');
  expect(q.error,isNotNull); // Offline, so server has not acknowledged the receipt.
  q.dispose();
 });
 test('durable outbox separates identities and scope revisions',() async {
  final factory=newIdbFactoryMemory();
  final a=OfflineQueue(Disconnected(),'a','1',factory:factory);
  await a.enqueue('/api/v1/records',{'kind':'survey','client_ref':'11111111-1111-4111-8111-111111111111'});
  await a.sync();
  await a.reload();expect(a.pending.length,1);
  final b=OfflineQueue(Disconnected(),'b','1',factory:factory);await b.reload();expect(b.pending,isEmpty);
  final revised=OfflineQueue(Disconnected(),'a','2',factory:factory);await revised.reload();expect(revised.pending,isEmpty);expect(revised.quarantined,1);
  final reopened=OfflineQueue(Disconnected(),'a','1',factory:factory);await reopened.reload();expect(reopened.pending.single['payload']['kind'],'survey');
  a.dispose();b.dispose();revised.dispose();reopened.dispose();
 });

  test('customer media survives restart and stays scoped to user and revision',()async{
    final factory=newIdbFactoryMemory();
    final first=OfflineQueue(Disconnected(),'photo-owner','7',factory:factory);
    final image=Uint8List.fromList([255,216,1,2,255,217]);
    final thumbnail=Uint8List.fromList([255,216,3,4,255,217]);
    const customerId='33333333-3333-4333-8333-333333333333';
    final sha=List.filled(64,'a').join(),thumbSha=List.filled(64,'b').join();
    await first.enqueue('/api/v1/customers/$customerId/photos',{},
      photo:image,thumbnail:thumbnail,sha256:sha,thumbnailSha256:thumbSha,mime:'image/jpeg');
    final reopened=OfflineQueue(Disconnected(),'photo-owner','7',factory:factory);
    await reopened.reload();
    final entry=reopened.pending.single;
    expect((entry['photo'] as List).cast<int>(),image);
    expect((entry['thumbnail'] as List).cast<int>(),thumbnail);
    expect(entry['sha256'],sha);
    expect(entry['thumbnail_sha256'],thumbSha);
    expect(entry['upload_id'],isNotEmpty);
    await reopened.cache('customer-image:$customerId:customer:photo:thumb',[{'bytes':thumbnail}]);
    final another=OfflineQueue(Disconnected(),'other-owner','7',factory:factory);
    expect(await another.cached('customer-image:$customerId:customer:photo:thumb'),isEmpty);
    await another.reload();expect(another.pending,isEmpty);
    final revised=OfflineQueue(Disconnected(),'photo-owner','8',factory:factory);
    await revised.reload();expect(revised.pending,isEmpty);
    expect(await revised.cached('customer-image:$customerId:customer:photo:thumb'),isEmpty);
    final reread=OfflineQueue(Disconnected(),'photo-owner','7',factory:factory);
    final cached=await reread.cached('customer-image:$customerId:customer:photo:thumb');
    expect((cached.single['bytes'] as List).cast<int>(),thumbnail);
    first.dispose();reopened.dispose();another.dispose();revised.dispose();reread.dispose();
  });

 test('P0 atomic plan-route-trip graph persists all three or none, with stable UUID',()async{
  const p='11111111-1111-4111-8111-111111111111',
    r='22222222-2222-4222-8222-222222222222',
    t='33333333-3333-4333-8333-333333333333';
  final factory=newIdbFactoryMemory();
  final q=OfflineQueue(Disconnected(),'sales-atomic','1',factory:factory);
  final plan=<String,dynamic>{'client_ref':p,'work_date':'2026-11-14','period_ym':'2026-11',
   'purpose':'Tìm khách mới','status':'planned'};
  final route=<String,dynamic>{'client_ref':r,'monthly_plan_id':p,
   'route_date':'2026-11-14','status':'ready'};
  final trip=<String,dynamic>{'client_ref':t,'day_route_id':r,
   'start_date':'2026-11-14','end_date':'2026-11-17',
   'scopes':[{'scope_kind':'territory','scope_key':'Bến Tre|'}]};
  await q.enqueueTripGraph(plan:plan,route:route,trip:trip);
  expect(q.pending.map((x)=>x['path']).toList(),
   ['/api/v1/monthly-plans','/api/v1/day-routes','/api/v1/trips']);
  expect(q.pending[0]['depends_on'],isEmpty);
  expect(q.pending[1]['depends_on'],[p]);
  expect(q.pending[2]['depends_on'],[r]);
  await q.enqueueTripGraph(plan:plan,route:route,trip:trip);
  expect(q.pending,hasLength(3));
  await expectLater(q.enqueueTripGraph(plan:plan,route:{...route,'monthly_plan_id':t},trip:trip),
   throwsStateError);
  expect(q.pending,hasLength(3));
  final restart=OfflineQueue(Disconnected(),'sales-atomic','1',factory:factory);
  await restart.reload();
  expect(restart.pending,hasLength(3));
  final other=OfflineQueue(Disconnected(),'other','1',factory:factory);
  await other.reload();expect(other.pending,isEmpty);
  q.dispose();restart.dispose();other.dispose();
 });

 test('P0 cancel blocked safely keeps byte-exact payload in recovery cache and restores',()async{
  const id='44444444-4444-4444-8444-444444444444';
  final factory=newIdbFactoryMemory();
  final q=OfflineQueue(Disconnected(),'sales-archive','5',factory:factory);
  await q.enqueue('/api/v1/day-routes/$id/customer-work',{
   'client_ref':id,'answers':{'old_question':'Giữ nguyên chữ gốc'}});
  final key=q.pending.single['key'] as String;
  final db=await q.db,tx=db.transaction('outbox',idbModeReadWrite);
  await tx.objectStore('outbox').put({...q.pending.single,
   'status':'blocked','error':'HTTP 400: Mẫu không hợp lệ'});
  await tx.completed;await q.reload();
  expect(q.canRescue(q.pending.single),isTrue);
  await q.rescueBlocked(key);
  expect(q.pending,isEmpty);expect(q.rescued,hasLength(1));
  expect((q.rescued.single['payload'] as Map)['answers'],
   {'old_question':'Giữ nguyên chữ gốc'});
  final restart=OfflineQueue(Disconnected(),'sales-archive','5',factory:factory);
  await restart.reload();
  expect(restart.rescued,hasLength(1));
  await restart.restoreRescued(key);
  expect(restart.rescued,isEmpty);
  expect(restart.pending.single['status'],'blocked');
  expect((restart.pending.single['payload'] as Map)['answers'],
   {'old_question':'Giữ nguyên chữ gốc'});
  final other=OfflineQueue(Disconnected(),'other','5',factory:factory);
  await other.reload();expect(other.pending,isEmpty);expect(other.rescued,isEmpty);
  q.dispose();restart.dispose();other.dispose();
 });

 test('P0 cannot cancel a blocked parent while dependent trip survives',()async{
  const p='55555555-5555-4555-8555-555555555555',
   r='66666666-6666-4666-8666-666666666666',
   t='77777777-7777-4777-8777-777777777777';
  final q=OfflineQueue(Disconnected(),'sales-safe','1',factory:newIdbFactoryMemory());
  await q.enqueueTripGraph(
   plan:{'client_ref':p,'work_date':'2026-11-14','period_ym':'2026-11'},
   route:{'client_ref':r,'monthly_plan_id':p,'route_date':'2026-11-14'},
   trip:{'client_ref':t,'day_route_id':r,'start_date':'2026-11-14',
    'end_date':'2026-11-16','scopes':[{'scope_kind':'territory','scope_key':'Bến Tre|'}]});
  final first=q.pending.first,key=first['key'] as String;
  final db=await q.db,tx=db.transaction('outbox',idbModeReadWrite);
  await tx.objectStore('outbox').put({...first,'status':'blocked','error':'HTTP 409'});
  await tx.completed;await q.reload();
  expect(q.canRescue(q.pending.first),isFalse);
  await expectLater(q.rescueBlocked(key),throwsStateError);
  expect(q.pending,hasLength(3));
  q.dispose();
 });

 test('P0 read-only plan 409 reconciliation rewrites child route dependency',()async{
  const old='11111111-1111-4111-8111-111111111111',
    canonical='99999999-9999-4999-8999-999999999999',
    child='22222222-2222-4222-8222-222222222222';
  final network=MockClient((req)async{
   expect(req.method,'GET',reason:'Reconciliation never POSTs the same plan');
   return http.Response(jsonEncode({'items':[{
    'id':canonical,'owner_sub':'sales-409','period_ym':'2026-11',
    'work_date':'2026-11-14','scope_kind':'territory',
    'scope_key':'Bến Tre|','province':'Bến Tre','district':'',
    'purpose':'Tìm khách mới','note':'','status':'planned',
    'target_new_customers':0}]}),200,
    headers:{'content-type':'application/json'});
  });
  final q=OfflineQueue(Disconnected(),'sales-409','1',
   factory:newIdbFactoryMemory(),networkClient:network);
  await q.enqueue('/api/v1/monthly-plans',{
   'client_ref':old,'period_ym':'2026-11','work_date':'2026-11-14',
   'scope_kind':'territory','scope_key':'Bến Tre|',
   'province':'Bến Tre','district':'','purpose':'Tìm khách mới',
   'note':'','status':'planned','target_new_customers':0});
  await q.enqueue('/api/v1/day-routes',{
   'client_ref':child,'monthly_plan_id':old,
   'route_date':'2026-11-14'},dependsOn:[old]);
  final original=q.pending.first;
  final d=await q.db,t=d.transaction('outbox',idbModeReadWrite);
  await t.objectStore('outbox').put({...original,'status':'blocked',
   'error':'HTTP 409: Trùng lịch'});await t.completed;await q.reload();
  await q.reconcileBlockedRoutes();
  expect(q.pending,hasLength(1));
  expect((q.pending.single['payload'] as Map)['monthly_plan_id'],canonical);
  expect(q.pending.single['depends_on'],isEmpty);
  q.dispose();network.close();
 });

 test('P0 trip 409 match preserves mutation and rebinds extend to canonical trip',()async{
  const old='33333333-3333-4333-8333-333333333333',
    canonical='88888888-8888-4888-8888-888888888888',
    route='22222222-2222-4222-8222-222222222222',
    extension='77777777-7777-4777-8777-777777777777';
  final scope={'scope_kind':'territory','scope_key':'Bến Tre|',
   'province':'Bến Tre','district':''};
  final network=MockClient((req)async{
   expect(req.method,'GET',reason:'Only read canonical trip');
   return http.Response(jsonEncode({'items':[{
    'id':canonical,'day_route_id':route,'owner_sub':'sales-trip',
    'start_date':'2026-11-14','end_date':'2026-11-16',
    'purpose':'Đi thị trường','note':'','scopes':[scope],
    'priority_customer_ids':[]}]}),200,headers:{'content-type':'application/json'});
  });
  final q=OfflineQueue(Disconnected(),'sales-trip','1',
   factory:newIdbFactoryMemory(),networkClient:network);
  await q.enqueue('/api/v1/trips',{
   'client_ref':old,'mutation_ref':old,'day_route_id':route,
   'start_date':'2026-11-14','end_date':'2026-11-16',
   'purpose':'Đi thị trường','note':'',
   'scopes':[scope],'priorities':<String>[]});
  await q.enqueue('/api/v1/trips/$old/extend',{
   'client_ref':extension,'version':1,'end_date':'2026-11-18'},dependsOn:[old]);
  final first=q.pending.first,d=await q.db;
  final t=d.transaction('outbox',idbModeReadWrite);
  await t.objectStore('outbox').put({...first,'status':'blocked','error':'HTTP 409'});
  await t.completed;await q.reload();
  await q.reconcileBlockedRoutes();
  expect(q.pending,hasLength(1));
  expect(q.pending.single['path'],'/api/v1/trips/$canonical/extend');
  expect(q.pending.single['depends_on'],isEmpty);
  q.dispose();network.close();
 });

}
