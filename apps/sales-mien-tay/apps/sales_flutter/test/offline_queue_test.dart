import 'package:flutter_test/flutter_test.dart';
import 'package:idb_shim/idb_shim.dart';
import 'package:sales_mien_tay/offline_queue.dart';
import 'package:sales_mien_tay/session.dart';

class Disconnected extends SalesSession {
 @override Future<Map<String,dynamic>> get(String path) async => throw const ApiFailure(503,'offline');
}
void main(){
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
}
