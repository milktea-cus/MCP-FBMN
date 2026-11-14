import 'package:flutter_test/flutter_test.dart';
import 'package:idb_shim/idb_shim.dart';
import 'package:sales_mien_tay/offline_queue.dart';
import 'package:sales_mien_tay/session.dart';
import 'package:sales_mien_tay/work_session_identity.dart';

const owner='sales-account-1';
const route='af63dbf2-ff5d-4279-95be-6a46646c2e94';

void main(){
 test('route session start/close survive reopening durable offline queue',()async{
  final f=newIdbFactoryMemory(),id=workSessionId(owner,route);
  final queue=OfflineQueue(SalesSession(),owner,'1',factory:f);
  final start={'client_ref':id,'captured_at':'2026-11-14T03:00:00Z'};
  await queue.enqueue('/api/v1/day-routes/$route/work-session',start);
  final closer='77777777-7777-4777-8777-777777777777';
  await queue.enqueue('/api/v1/work-sessions/$id/close',{
   'client_ref':closer,'version':1,'action':'done',
   'note':'Đã đi thực địa','captured_at':'2026-11-14T04:00:00Z',
  },dependsOn:[id]);
  expect(queue.pending.length,2);
  final reopened=OfflineQueue(SalesSession(),owner,'1',factory:f);
  await reopened.reload();
  expect(reopened.pending.length,2);
  expect(reopened.pending.last['depends_on'],[id]);
  expect(workSessionState({'id':route,'owner_sub':owner,'work_session_state':'open'},
    reopened.pending),'done');
  // Cannot replace an already persisted start with a different timestamp.
  await expectLater(queue.enqueue('/api/v1/day-routes/$route/work-session',{
   'client_ref':id,'captured_at':'2026-11-14T03:01:00Z',
  }),throwsStateError);
  expect(reopened.pending.length,2);
  queue.dispose();reopened.dispose();
 });

 test('one stable work-session ID per owner/route across PWA restarts',(){
  final ref=workSessionId(owner,route);
  expect(ref,workSessionId(owner,route));
  expect(ref,isNot(workSessionId('sales-account-2',route)));
  expect(ref,isNot(workSessionId(owner,'55e68f09-ad53-4c87-a73b-97c1c29c7cc5')));
  expect(RegExp(r'^[0-9a-f-]{36}$').hasMatch(ref),true);
 });
 test('month plan route without session is open, never a fake area stop',(){
  final row=<String,dynamic>{'id':route,'owner_sub':owner,'work_session_state':'open'};
  expect(workSessionState(row,[]),'open');
 });
 test('offline start is ongoing until server confirms same UUID',(){
  final row=<String,dynamic>{'id':route,'owner_sub':owner,'work_session_state':'open'};
  final op=<String,dynamic>{
   'method':'POST','path':'/api/v1/day-routes/$route/work-session',
   'payload':{'client_ref':workSessionId(owner,route)},
  };
  expect(workSessionState(row,[op]),'ongoing');
  expect(workSessionRouteId(row,owner),workSessionId(owner,route));
 });
 test('queued close blocks new GPS immediately, retaining all drafts',(){
  final session=workSessionId(owner,route);
  final row=<String,dynamic>{'id':route,'owner_sub':owner,
   'work_session_state':'ongoing','work_session_id':session};
  final op=<String,dynamic>{
   'method':'POST','path':'/api/v1/work-sessions/$session/close',
   'payload':{'action':'done'},
  };
  expect(workSessionState(row,[op]),'done');
  final cancel=Map<String,dynamic>.from(op);
  cancel['payload']={'action':'cancelled'};
  expect(workSessionState(row,[cancel]),'cancelled');
  expect(workSessionState(row,[]),'ongoing');
 });
 test('a different route pending start cannot open this route',(){
  final row=<String,dynamic>{'id':route,'owner_sub':owner};
  final other=<String,dynamic>{
   'method':'POST',
   'path':'/api/v1/day-routes/55e68f09-ad53-4c87-a73b-97c1c29c7cc5/work-session',
   'payload':{'client_ref':workSessionId(owner,route)},
  };
  expect(workSessionState(row,[other]),'open');
 });
}
