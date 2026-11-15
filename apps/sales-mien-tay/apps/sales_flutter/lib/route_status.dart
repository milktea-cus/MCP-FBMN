import 'package:flutter/material.dart';
import 'theme.dart';
import 'work_session_identity.dart';

/// One business status for a route across Planning, Today and Results.
/// The status is derived from immutable server records plus the account's
/// pending outbox; no second, drifting "route status" is saved on-device.
enum RouteProgress {planned,running,completed,overdue,awaitingSync,syncError,cancelled}

bool isClosingRoute(Map<String,dynamic> route,List<Map<String,dynamic>> pending){
 final owner=route['owner_sub']?.toString()??'';
 final session=workSessionRouteId(route,owner);
 final trip=route['trip_id']?.toString()??'';
 return pending.any((job){
  final path=job['path']?.toString()??'';
  return path=='/api/v1/work-sessions/$session/close'||
   (trip.isNotEmpty&&path=='/api/v1/trips/$trip/close');
 });
}

RouteProgress routeProgress(Map<String,dynamic> route,
 List<Map<String,dynamic>> pending,String today){
 final id=route['id']?.toString()??'';
 final owner=route['owner_sub']?.toString()??'';
 final session=workSessionRouteId(route,owner);
 final trip=route['trip_id']?.toString()??'';
 final closures=pending.where((job){
  final path=job['path']?.toString()??'';
  return path=='/api/v1/work-sessions/$session/close'||
   (trip.isNotEmpty&&path=='/api/v1/trips/$trip/close');
 }).toList();
 if(closures.any((job)=>job['status']=='blocked'))return RouteProgress.syncError;
 if(closures.isNotEmpty)return RouteProgress.awaitingSync;
 if(route['trip_closed_at']!=null||
    route['work_session_state']=='done')return RouteProgress.completed;
 if(route['status']=='cancelled'||route['plan_status']=='cancelled'||
    route['work_session_state']=='cancelled')return RouteProgress.cancelled;
 if(pending.any((job)=>
    job['path']=='/api/v1/day-routes'&&
    (job['payload'] as Map?)?['client_ref']==id)){
   return RouteProgress.awaitingSync;
 }
 final end=(trip.isNotEmpty?route['trip_end_date']:route['route_date'])
   ?.toString()??'';
 if(end.length>=10&&end.substring(0,10).compareTo(today)<0){
  return RouteProgress.overdue;
 }
 final start=(trip.isNotEmpty?route['trip_start_date']:route['route_date'])
   ?.toString()??'';
 if(route['work_session_state']=='ongoing'||
    (trip.isNotEmpty&&start.length>=10&&
     start.substring(0,10).compareTo(today)<=0&&
     end.length>=10&&end.substring(0,10).compareTo(today)>=0)){
  return RouteProgress.running;
 }
 return RouteProgress.planned;
}

String routeProgressLabel(RouteProgress progress)=>switch(progress){
 RouteProgress.planned=>'Trong kế hoạch',
 RouteProgress.running=>'Đang chạy',
 RouteProgress.completed=>'Hoàn thành',
 RouteProgress.overdue=>'Quá hạn',
 RouteProgress.awaitingSync=>'Chờ đồng bộ',
 RouteProgress.syncError=>'Lỗi đồng bộ',
 RouteProgress.cancelled=>'Đã hủy',
};

/// FBMN semantic status token: one color rule reused across all route cards.
class RouteStatusChip extends StatelessWidget {
 final RouteProgress progress;
 const RouteStatusChip({super.key,required this.progress});
 @override Widget build(BuildContext context){
  final isDark=Theme.of(context).brightness==Brightness.dark;
  final color=switch(progress){
   RouteProgress.planned=>Theme.of(context).colorScheme.primary,
   RouteProgress.running=>isDark?SalesTheme.statusRunningDark:SalesTheme.statusRunning,
   RouteProgress.completed=>isDark?SalesTheme.statusCompletedDark:SalesTheme.statusCompleted,
   RouteProgress.overdue=>isDark?SalesTheme.statusOverdueDark:SalesTheme.statusOverdue,
   RouteProgress.awaitingSync=>isDark?SalesTheme.statusPendingDark:SalesTheme.statusPending,
   RouteProgress.syncError=>Theme.of(context).colorScheme.error,
   RouteProgress.cancelled=>Theme.of(context).colorScheme.onSurfaceVariant,
  };
  final icon=switch(progress){
   RouteProgress.planned=>Icons.event_note_outlined,
   RouteProgress.running=>Icons.directions_walk_outlined,
   RouteProgress.completed=>Icons.check_circle_outline,
   RouteProgress.overdue=>Icons.watch_later_outlined,
   RouteProgress.awaitingSync=>Icons.sync,
   RouteProgress.syncError=>Icons.sync_problem_outlined,
   RouteProgress.cancelled=>Icons.block_outlined,
  };
  return Container(
   padding:const EdgeInsets.symmetric(horizontal:8,vertical:4),
   decoration:BoxDecoration(color:color.withValues(alpha:isDark?0.18:0.09),
    border:Border.all(color:color.withValues(alpha:0.32)),
    borderRadius:BorderRadius.circular(SalesTheme.controlRadius)),
   child:Row(mainAxisSize:MainAxisSize.min,children:[
    Icon(icon,size:14,color:color),const SizedBox(width:4),
    Flexible(child:Text(routeProgressLabel(progress),maxLines:1,
     overflow:TextOverflow.ellipsis,softWrap:false,style:TextStyle(
     color:color,fontWeight:FontWeight.w700,fontSize:12))),
   ]),
  );
 }
}
