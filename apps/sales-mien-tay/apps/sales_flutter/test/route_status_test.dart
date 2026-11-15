import 'package:flutter_test/flutter_test.dart';
import 'package:sales_mien_tay/route_status.dart';
import 'package:sales_mien_tay/work_session_identity.dart';
import 'package:sales_mien_tay/work_hub.dart';

void main(){
 const route='11111111-1111-4111-8111-111111111111';
 const owner='sales-one';
 final session=workSessionId(owner,route);
 final base=<String,dynamic>{
  'id':route,'owner_sub':owner,'route_date':'2026-11-14',
  'status':'ready','plan_status':'planned',
  'work_session_id':session,'work_session_state':'ongoing',
 };
 test('old started one-day route is overdue, pending closure is not completed',(){
  expect(routeProgress(base,[],'2026-11-15'),RouteProgress.overdue);
  final closing=<String,dynamic>{'namespace':'sales-one:1',
   'path':'/api/v1/work-sessions/$session/close','status':'pending',
   'payload':{'action':'done'}};
  expect(routeProgress(base,[closing],'2026-11-15'),RouteProgress.awaitingSync);
  expect(isClosingRoute(base,[closing]),isTrue);
  expect(routeProgress(base,[{...closing,'status':'blocked'}],'2026-11-15'),
   RouteProgress.syncError);
  expect(routeProgress({...base,'work_session_state':'done'},[],'2026-11-15'),
   RouteProgress.completed);
  expect(outstandingWorkRoutes([base],[],'2026-11-15','2026-11-15'),
   hasLength(1));
  expect(outstandingWorkRoutes([base],[],'2026-11-15','2026-11-15',[closing]),
   isEmpty);
  expect(outstandingWorkRoutes([{...base,'work_session_state':'done'}],
   [],'2026-11-15','2026-11-15'),isEmpty);
 });
 test('planned, active, trip complete, cancelled and pending date have unique states',(){
  expect(routeProgress({...base,'route_date':'2026-11-16',
   'work_session_state':'open'},[],'2026-11-15'),RouteProgress.planned);
  expect(routeProgress({...base,'route_date':'2026-11-15'},[],'2026-11-15'),
   RouteProgress.running);
  final trip={...base,'trip_id':'22222222-2222-4222-8222-222222222222',
    'trip_start_date':'2026-11-14','trip_end_date':'2026-11-17',
    'work_session_state':'open'};
  expect(routeProgress(trip,[],'2026-11-15'),RouteProgress.running);
  expect(routeProgress({...trip,'trip_closed_at':'2026-11-15T05:00:00Z'},
    [],'2026-11-15'),RouteProgress.completed);
  expect(routeProgress({...base,'status':'cancelled'},[],'2026-11-15'),
   RouteProgress.cancelled);
  expect(routeProgressLabel(RouteProgress.completed),'Hoàn thành');
 });
 test('closing route waits for its own GPS, survey, media and stops only',(){
  const stop='33333333-3333-4333-8333-333333333333';
  const gps='44444444-4444-4444-8444-444444444444';
  const survey='55555555-5555-4555-8555-555555555555';
  const unrelated='66666666-6666-4666-8666-666666666666';
  final deps=workSessionClosureDependencies(
   routeId:route,sessionId:session,stopIds:[stop],pending:[
    {'path':'/api/v1/day-routes/$route/work-session',
     'payload':{'client_ref':session}},
    {'path':'/api/v1/customers/id/visits',
     'payload':{'client_ref':gps,'day_route_stop_id':stop}},
    {'path':'/api/v1/surveys',
     'payload':{'client_ref':survey},'depends_on':[gps]},
    {'path':'/api/v1/other',
     'payload':{'client_ref':unrelated},'depends_on':<String>[]},
   ]);
  expect(deps.toSet(),{session,gps,survey});
  expect(deps,hasLength(3));
 });
}
