import 'package:flutter_test/flutter_test.dart';
import 'package:idb_shim/idb_shim.dart';
import 'package:sales_mien_tay/work_hub.dart';
import 'package:sales_mien_tay/offline_queue.dart';
import 'package:sales_mien_tay/session.dart';

class OfflineSession extends SalesSession {
 @override Future<Map<String,dynamic>> get(String path) async => throw const ApiFailure(503,'offline');
}
const routeId='11111111-1111-4111-8111-111111111111',
 tripId='22222222-2222-4222-8222-222222222222';
Map<String,dynamic> trip({String from='2026-11-14',String to='2026-11-17'})=> {
 'id':tripId,'day_route_id':routeId,'owner_sub':'sales-1',
 'start_date':from,'end_date':to,'purpose':'Công tác nhiều tỉnh',
 'route_status':'ready','closed_at':null,'version':1,
 'scopes':[{'scope_kind':'territory','scope_key':'Bến Tre|Bình Đại'},
           {'scope_kind':'chain','scope_key':'33333333-3333-4333-8333-333333333333'}],
 'priority_customer_ids':['44444444-4444-4444-8444-444444444444'],
};

void main(){
 test('same trip appears all four days but never creates four routes',(){
  for(final d in ['2026-11-14','2026-11-15','2026-11-16','2026-11-17']){
   final routes=mergeTripRoutes([], [trip()], [],'sales-1',d);
   expect(routes,hasLength(1));
   expect(routes.single['id'],routeId);
   expect(routes.single['trip_id'],tripId);
   expect(routes.single['work_session_state'],'ongoing');
   expect((routes.single['scopes'] as List).length,2);
  }
  expect(mergeTripRoutes([], [trip()], [],'sales-1','2026-11-13'),isEmpty);
  expect(mergeTripRoutes([], [trip()], [],'sales-1','2026-11-18'),isEmpty);
 });
 test('trip crosses calendar months even with no day route in that month',(){
  final rows=mergeTripRoutes([], [trip(from:'2026-11-30',to:'2026-12-03')],
   [],'sales-1','2026-12-02');
  expect(rows,hasLength(1));
  expect(rows.single['trip_end_date'],'2026-12-03');
 });
 test('pending offline trip and extension survive reload, account separated',(){
  final pending=<Map<String,dynamic>>[
   {'namespace':'sales-1:7','method':'POST','path':'/api/v1/trips','payload':{
    'client_ref':tripId,'day_route_id':routeId,'start_date':'2026-11-14',
    'end_date':'2026-11-17','purpose':'Công tác offline','scopes':[]}},
   {'namespace':'sales-1:7','method':'POST','path':'/api/v1/trips/$tripId/extend',
    'payload':{'client_ref':'55555555-5555-4555-8555-555555555555',
     'end_date':'2026-11-20','version':1}},
  ];
  final found=mergeTripRoutes([],[],pending,'sales-1','2026-11-20');
  expect(found,hasLength(1));
  expect(found.single['trip_end_date'],'2026-11-20');
  expect(found.single['id'],routeId);
  expect(mergeTripRoutes([],[],pending,'sales-2','2026-11-20'),isEmpty);
 });
 test('queued early close preserves the trip history without active state',(){
  final pending=<Map<String,dynamic>>[
   {'namespace':'sales-1:1','method':'POST','path':'/api/v1/trips/$tripId/close',
    'payload':{'captured_at':'2026-11-15T09:00:00Z','version':1}},
  ];
  final found=mergeTripRoutes([], [trip()], pending,'sales-1','2026-11-15');
  expect(found.single['trip_closed_at'],isNotNull);
  expect(found.single['work_session_state'],'done');
  expect(found.single['priority_customer_ids'],hasLength(1));
 });
 test('offline outbox accepts trip create, extend, close and customer work',()async{
  final queue=OfflineQueue(OfflineSession(),'sales-1','1',factory:newIdbFactoryMemory());
  await queue.enqueue('/api/v1/trips',{'client_ref':tripId},);
  await queue.enqueue('/api/v1/trips/$tripId/extend',{
   'client_ref':'66666666-6666-4666-8666-666666666666'});
  await queue.enqueue('/api/v1/trips/$tripId/close',{
   'client_ref':'77777777-7777-4777-8777-777777777777'});
  await queue.enqueue('/api/v1/day-routes/$routeId/customer-work',{
   'client_ref':'88888888-8888-4888-8888-888888888888'});
  expect(queue.pending,hasLength(4));
  queue.dispose();
 });
}

