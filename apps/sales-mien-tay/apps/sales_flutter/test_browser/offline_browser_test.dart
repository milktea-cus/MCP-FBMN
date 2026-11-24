import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';
import 'package:sales_mien_tay/offline_queue.dart';
import 'package:sales_mien_tay/offline_factory.dart';
import 'package:sales_mien_tay/session.dart';

import '../test/bulk_replay_fixture.dart';

void main(){
 test('L5 real Chrome IndexedDB bulk offline recovery',
  ()=>exerciseBulkReplay(offlineFactory()));

 test('L3 real IndexedDB retains empty page metadata without deleting outbox on revocation',()async{
  final owner=const Uuid().v4(),factory=offlineFactory();
  final a=OfflineQueue(SalesSession(),owner,'1',factory:factory);
  const key='schools:page:v2:_:_:_:1';
  await a.enqueue('/api/v1/customers',{'name':'Draft'});
  await a.cacheDirectoryPage(key,[],total:0,hasMore:false);
  (await a.db).close();a.dispose();
  final reopened=OfflineQueue(SalesSession(),owner,'1',factory:factory);
  final saved=await reopened.directoryPage(key);
  expect(saved!['items'],isEmpty);expect(saved['total'],0);
  await reopened.revokeDirectory('schools');await reopened.reload();
  expect(await reopened.directoryPage(key),isNull);expect(reopened.pending.length,1);
  (await reopened.db).close();reopened.dispose();
 });

 test('stock snapshot persists across reopen and is scoped to account and revision',()async{
  final owner=const Uuid().v4(),factory=offlineFactory(),a=OfflineQueue(SalesSession(),owner,'1',factory:factory);
  await a.cache('stock-snapshot-v1',[{'items':[{'company_code':'000123','quantity':0},{'company_code':'000124','quantity':null}],'synced_at':'2026-11-10T00:00:00Z'}]);
  (await a.db).close();a.dispose();
  final b=OfflineQueue(SalesSession(),owner,'1',factory:factory);
  final rows=(await b.cached('stock-snapshot-v1')).single['items'] as List;
  expect(rows[0]['quantity'],0);expect(rows[1]['quantity'],isNull);
  final other=OfflineQueue(SalesSession(),const Uuid().v4(),'1',factory:factory),revised=OfflineQueue(SalesSession(),owner,'2',factory:factory);
  expect(await other.cached('stock-snapshot-v1'),isEmpty);expect(await revised.cached('stock-snapshot-v1'),isEmpty);
  (await b.db).close();(await other.db).close();(await revised.db).close();b.dispose();other.dispose();revised.dispose();
 });
 test('real IndexedDB persists unified survey draft and outbox atomically',()async{
  final owner=const Uuid().v4(),id=const Uuid().v4(),factory=offlineFactory();final a=OfflineQueue(SalesSession(),owner,'1',factory:factory);
  await a.saveSurveyDraft({'id':id,'status':'in_progress','answers':{'npp':'test'},'photos':[]},path:'/api/v1/sessions',payload:{'client_ref':id});
  (await a.db).close();a.dispose();final b=OfflineQueue(SalesSession(),owner,'1',factory:factory);await b.reload();expect(b.pending.single['session_id'],id);expect((await b.cached('survey-drafts')).single['answers']['npp'],'test');
  final revised=OfflineQueue(SalesSession(),owner,'2',factory:factory);await revised.reload();expect(revised.pending,isEmpty);expect(await revised.cached('survey-drafts'),isEmpty);expect(revised.quarantined,1);
  (await b.db).close();(await revised.db).close();b.dispose();revised.dispose();
 });
 test('real browser IndexedDB persists draft after reopening and isolates accounts',() async{
  final id=const Uuid().v4();
  final factory=offlineFactory();
  final a=OfflineQueue(SalesSession(),id,'1',factory:factory);
  await a.enqueue('/api/v1/customers',{'name':'IndexedDB test'});
  await a.cache('customers:',[{'name':'Cached'}]);
  (await a.db).close();a.dispose();
  final b=OfflineQueue(SalesSession(),id,'1',factory:factory);
  await b.reload();expect(b.pending.single['payload']['name'],'IndexedDB test');
  expect((await b.cached('customers:')).single['name'],'Cached');
  final other=OfflineQueue(SalesSession(),const Uuid().v4(),'1',factory:factory);
  await other.reload();expect(other.pending,isEmpty);expect(await other.cached('customers:'),isEmpty);
  final revised=OfflineQueue(SalesSession(),id,'2',factory:factory);
  await revised.reload();expect(revised.pending,isEmpty);expect(revised.quarantined,1);
  (await b.db).close();(await other.db).close();(await revised.db).close();
  b.dispose();other.dispose();revised.dispose();
 });
}
