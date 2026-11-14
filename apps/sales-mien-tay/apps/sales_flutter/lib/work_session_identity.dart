import 'package:uuid/uuid.dart';

/// Stable across Safari restarts, devices and retries for the same employee/route.
String workSessionId(String owner,String routeId)=>
 const Uuid().v5(Uuid.NAMESPACE_URL,'fbmn-work-session:$owner:$routeId');

String workSessionRouteId(Map<String,dynamic> route,String owner)=>
 route['work_session_id']?.toString()??workSessionId(owner,route['id'].toString());

String workSessionState(Map<String,dynamic> route,List<Map<String,dynamic>> outbox){
 final routeId=route['id']?.toString()??'';
 final owner=route['owner_sub']?.toString()??'';
 final id=workSessionRouteId(route,owner);
 for(final item in outbox.reversed){
  if(item['path']=='/api/v1/work-sessions/$id/close'&&
   item['payload'] is Map){
   final state=(item['payload'] as Map)['action'];
   if(state=='done'||state=='cancelled')return state.toString();
  }
 }
 if(outbox.any((item)=>item['method']=='POST'&&
   item['path']=='/api/v1/day-routes/$routeId/work-session')){
  return 'ongoing';
 }
 return route['work_session_state']?.toString()??'open';
}
