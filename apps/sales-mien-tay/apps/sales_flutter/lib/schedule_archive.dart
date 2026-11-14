import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'customers.dart';
import 'offline_queue.dart';
import 'session.dart';

/// The user-facing "Xóa lịch" archives instead of physically destroying
/// customer visits/surveys. The server enforces owner + version checks.
Future<Map<String,dynamic>> archiveWorkScheduleRequest(
 CustomerService service,Map<String,dynamic> plan,{http.Client? client}
)async{
 final id=plan['id']?.toString()??'';
 final version=plan['version'];
 if(!RegExp(r'^[a-f0-9-]{36}$',caseSensitive:false).hasMatch(id)||
   version is! int||version<1)throw StateError('Thiếu mã/phiên bản lịch');
 final uri=service.uri('/api/v1/monthly-plans/$id',{
  'version':version.toString(),
 });
 final response=await (client?.delete(uri,headers:service.headers)??
   http.delete(uri,headers:service.headers))
  .timeout(const Duration(seconds:20));
 final result=decodeApi(response);
 if(result['item'] is! Map||
   (result['item'] as Map)['status']!='cancelled'||
   (result['item'] as Map)['id'].toString()!=id){
  throw StateError('Máy chủ chưa xác nhận xóa lịch');
 }
 return Map<String,dynamic>.from(result);
}

Future<bool> confirmArchiveWorkSchedule(BuildContext context,{
 required CustomerService service,
 required OfflineQueue queue,
 required Map<String,dynamic> plan,
})async{
 final title=plan['purpose']?.toString()??'Lịch công tác';
 final date=plan['work_date']?.toString().split('T').first??'';
 final agreed=await showDialog<bool>(
  context:context,
  builder:(dialogContext)=>AlertDialog(
   title:const Text('Xóa lịch công tác?'),
   content:Text('Lịch "$title" ngày $date sẽ không còn trong lịch '
    'đang hoạt động.\n\nLịch sử ghé khách, khảo sát và nhật ký '
    'vẫn được giữ để đối chiếu. Có thể xem lại ở mục "Đã xóa".'),
   actions:[
    TextButton(onPressed:()=>Navigator.pop(dialogContext,false),
     child:const Text('Giữ lịch')),
    FilledButton.icon(
     key:const ValueKey('confirm-delete-schedule'),
     onPressed:()=>Navigator.pop(dialogContext,true),
     icon:const Icon(Icons.delete_outline),label:const Text('Xóa lịch')),
   ],
  ),
 );
 if(agreed!=true||!context.mounted)return false;
 try{
  final response=await archiveWorkScheduleRequest(service,plan);
  final server=Map<String,dynamic>.from(response['item'] as Map);
  final month=server['period_ym']?.toString()??'';
  if(month.isNotEmpty){
   final cacheKey='monthly-plans:$month';
   final old=await queue.cached(cacheKey);
   await queue.cache(cacheKey,[
    for(final r in old)
     if(r['id']==server['id'])server else r,
   ]);
   final routeCache='day-routes:$month';
   final routes=await queue.cached(routeCache);
   final started=response['has_activity']==true;
   await queue.cache(routeCache,[
    for(final r in routes)
     if(r['monthly_plan_id']==server['id'])
      {...r,'plan_status':'cancelled',if(!started)'status':'cancelled'}
     else r,
   ]);
  }
  // Only a server-acknowledged archive may cancel a queued duplicate route
  // graph, and only when it has no dependent field execution/drafts.
  final discarded=await queue.discardPendingForArchivedPlan(server['id'].toString());
  if(context.mounted){
   ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content:Text(discarded>0
     ?'Đã xóa lịch và dọn $discarded thao tác lập tuyến chưa gửi.'
     :'Đã xóa lịch khỏi kế hoạch đang hoạt động. Lịch sử vẫn được giữ.')));
  }
  return true;
 }catch(e){
  if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(
   SnackBar(content:Text('Không xóa được lịch: $e')),
  );
  return false;
 }
}
