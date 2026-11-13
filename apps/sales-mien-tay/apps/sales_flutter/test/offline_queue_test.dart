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

}
