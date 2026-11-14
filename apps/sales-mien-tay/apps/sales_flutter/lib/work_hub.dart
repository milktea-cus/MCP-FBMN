import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'customers.dart';
import 'offline_queue.dart';
import 'monthly_plan.dart';
import 'day_route.dart';
import 'work_session_identity.dart';
import 'planning_periods.dart';
import 'session.dart';

/// Plan and actual counters are deliberately separate: GPS does not finish a survey.
class WorkCounts {
 final int planned,visited,missed,unplanned,unplannedVisited,surveys,leads,marketVisits;
 const WorkCounts(this.planned,this.visited,this.missed,this.unplanned,
  this.unplannedVisited,this.surveys,this.leads,this.marketVisits);
 int get notVisited=>planned>visited?planned-visited:0;
 int get withoutReason=>notVisited>missed?notVisited-missed:0;
 static int count(Map<String,dynamic> r,String key){
  final v=r[key];return v is num&&v>0?v.toInt():0;
 }
 factory WorkCounts.fromRoutes(Iterable<Map<String,dynamic>> routes){
  var planned=0,visited=0,missed=0,unplanned=0,unplannedVisited=0,surveys=0,leads=0,marketVisits=0;
  for(final r in routes){
   planned+=count(r,'stop_count');
   visited+=count(r,'visited_count');
   missed+=count(r,'missed_count');
   unplanned+=count(r,'unplanned_count');
   unplannedVisited+=count(r,'unplanned_visited_count');
   surveys+=count(r,'survey_count');
   leads+=count(r,'lead_count');
   marketVisits+=count(r,'market_visit_count');
  }
  return WorkCounts(planned,visited,missed,unplanned,unplannedVisited,surveys,leads,marketVisits);
 }
}

/// Preserve dated plans waiting in IndexedDB even before a slow server GET.
/// Never synthesize a stop: customers on a scope are loaded by /candidates.
List<Map<String,dynamic>> mergePendingDayRoutes(
 List<Map<String,dynamic>> server,List<Map<String,dynamic>> pending,String owner){
 final ids=<String>{for(final r in server)r['id'].toString()};
 final all=<Map<String,dynamic>>[...server];
 for(final op in pending){
  if(op['method']!='POST'||op['path']!='/api/v1/day-routes'||op['payload'] is! Map)continue;
  final route=Map<String,dynamic>.from(op['payload'] as Map);
  final id=route['client_ref']?.toString()??'';
  if(id.isEmpty||!ids.add(id))continue;
  final plans=pending.where((p)=>p['method']=='POST'&&
   p['path']=='/api/v1/monthly-plans'&&p['payload'] is Map&&
   (p['payload'] as Map)['client_ref']==route['monthly_plan_id']);
  if(plans.isEmpty)continue;
  final plan=plans.first['payload'] as Map;
  if(op['namespace']?.toString().startsWith('$owner:')!=true)continue;
  all.add({...route,'id':id,'owner_sub':owner,
   'plan_status':plan['status']??'planned',
   'scope_kind':plan['scope_kind'],'scope_key':plan['scope_key'],
   'province':plan['province'],'district':plan['district'],
   'stop_count':pending.where((p)=>p['path']=='/api/v1/day-routes/$id/stops'&&
    (p['payload'] as Map?)?['stop_kind']=='customer').length,
   'visited_count':0,'survey_count':0,'lead_count':0,
   'work_session_state':'open','pending_route':true});
 }
 return all;
}

/// Trip is the stable parent across days. Only one route is kept as the
/// compatibility parent for existing GPS, work, surveys, orders and photos.
List<Map<String,dynamic>> mergeTripRoutes(
 List<Map<String,dynamic>> dayRoutes,List<Map<String,dynamic>> tripRows,
 List<Map<String,dynamic>> pending,String owner,String selectedDate){
 final byRoute=<String,Map<String,dynamic>>{
  for(final route in mergePendingDayRoutes(dayRoutes,pending,owner))
    route['id'].toString():{...route},
 };
 final allTrips=<Map<String,dynamic>>[...tripRows];
 for(final op in pending){
  if(op['path']!='/api/v1/trips'||op['method']!='POST'||
      op['payload'] is! Map||op['namespace']?.toString().startsWith('${owner}:')!=true)continue;
  final data=Map<String,dynamic>.from(op['payload'] as Map);
  final id=data['client_ref'].toString();
  if(!allTrips.any((t)=>t['id']==id)){
   allTrips.add({...data,'id':id,'owner_sub':owner,'version':1,
     'trip_state':'pending','closed_at':null});
  }
 }
 for(final original in allTrips){
  final trip=Map<String,dynamic>.from(original);
  final tripId=trip['id']?.toString()??'';
  final routeId=trip['day_route_id']?.toString()??'';
  if(tripId.isEmpty||routeId.isEmpty)continue;
  for(final op in pending){
   if(op['payload'] is! Map||op['namespace']?.toString().startsWith('${owner}:')!=true)continue;
   final v=op['payload'] as Map,path=op['path']?.toString();
   if(path=='/api/v1/trips/${tripId}/extend'&&v['end_date']!=null)trip['end_date']=v['end_date'];
   if(path=='/api/v1/trips/${tripId}/close'&&v['captured_at']!=null)trip['closed_at']=v['captured_at'];
  }
  final existing=byRoute[routeId]??<String,dynamic>{};
  final scopes=trip['scopes'] is List?trip['scopes'] as List:const [];
  final first=scopes.isNotEmpty&&scopes.first is Map?scopes.first as Map:const {};
  byRoute[routeId]={
   ...existing,...trip,
   'id':routeId,'trip_id':tripId,
   'trip_start_date':trip['start_date'],'trip_end_date':trip['end_date'],
   'trip_closed_at':trip['closed_at'],'trip_version':trip['version']??1,
   'route_date':existing['route_date']??trip['start_date'],
   'scope_kind':existing['scope_kind']??trip['scope_kind']??first['scope_kind'],
   'scope_key':existing['scope_key']??trip['scope_key']??first['scope_key'],
   'status':existing['status']??trip['route_status']??'ready',
   'plan_status':existing['plan_status']??'planned',
   'owner_sub':trip['owner_sub']??existing['owner_sub'],
   'purpose':trip['purpose']??existing['purpose'],
   'work_session_state':trip['closed_at']!=null?'done':'ongoing',
  };
 }
 return byRoute.values.where((r){
  if(r['status']!='ready'||r['plan_status']=='cancelled')return false;
  if(r['trip_id']==null)return r['route_date'].toString().startsWith(selectedDate);
  final from=r['trip_start_date']?.toString().substring(0,10)??'';
  final to=r['trip_end_date']?.toString().substring(0,10)??'';
  return selectedDate.compareTo(from)>=0&&selectedDate.compareTo(to)<=0||
    (r['trip_closed_at']==null&&selectedDate==dayKey(
       DateTime.now().toUtc().add(const Duration(hours:7)))&&to.compareTo(selectedDate)<0);
 }).toList();
}

/// Single Sales entry: plan, execute, compare. The legacy route screen stays
/// readable through old records but is no longer a second route editor.
class WorkHubPage extends StatefulWidget {
 final OfflineQueue queue;
 final CustomerService service;
 const WorkHubPage({super.key,required this.queue,required this.service});
 @override State<WorkHubPage> createState()=>_WorkHubPageState();
}
class _WorkHubPageState extends State<WorkHubPage>{
 int tab=1;
 DateTime day=DateTime.now().toUtc().add(const Duration(hours:7));
 List<Map<String,dynamic>> routes=[],trips=[];
 bool busy=false,offline=false;
 String? error;
 int lastPending=0;
 String get key=>'day-routes:${dayKey(day)}';
 String get monthCache=>'day-routes:${monthKey(day)}';
 String get tripsCache=>'trips:all';
 @override void initState(){
  super.initState();
  lastPending=widget.queue.pending.length;
  widget.queue.addListener(_changed);
  unawaited(load());
 }
 @override void dispose(){widget.queue.removeListener(_changed);super.dispose();}
 void _changed(){
  if(!mounted)return;
  final count=widget.queue.pending.length;
  if(count<lastPending&&!busy)unawaited(load());
  lastPending=count;
 }
 Future<void> loadTrips()async{
  try{
   final cached=await widget.queue.cached(tripsCache).timeout(const Duration(seconds:4));
   if(mounted&&cached.isNotEmpty)setState(()=>trips=cached);
  }catch(_){}
  try{
   final from=DateTime(day.year,day.month,1),to=DateTime(day.year,day.month+1,0);
   final res=decodeApi(await (widget.service.client?.get(
    widget.service.uri('/api/v1/trips',{'from':dayKey(from),'to':dayKey(to)}),
    headers:widget.service.headers)??
    http.get(widget.service.uri('/api/v1/trips',{'from':dayKey(from),'to':dayKey(to)}),
    headers:widget.service.headers)).timeout(const Duration(seconds:20)));
   final fresh=(res['items'] as List).map((v)=>Map<String,dynamic>.from(v as Map)).toList();
   // Keep other months offline; replace all records overlapping this query.
   final old=trips.where((t){
    final start=t['start_date']?.toString().substring(0,10)??'',
      end=t['end_date']?.toString().substring(0,10)??'';
    return end.compareTo(dayKey(from))<0||start.compareTo(dayKey(to))>0;
   }).toList();
   trips=[...fresh,...old];
   try{await widget.queue.cache(tripsCache,trips);}catch(_){}
   if(mounted)setState(()=>offline=false);
  }catch(e){
   if(e is ApiFailure&&(e.status==401||e.status==403)){
    if(mounted)setState(()=>trips=[]);
   }else if(mounted&&routes.isEmpty&&trips.isEmpty){
    setState(()=>error='Không tải được chuyến. Lịch trên máy vẫn được giữ để đồng bộ.');
   }
  }
 }
 Future<void> load()async{
  if(busy)return;
  setState((){busy=true;error=null;});
  try{
   // A stalled IndexedDB read must not prevent the server request.
   List<Map<String,dynamic>> old=[];
   try{
    final cache=await widget.queue.cached(key)
     .timeout(const Duration(seconds:4));
    old=cache.isNotEmpty?cache:await widget.queue.cached(monthCache)
     .timeout(const Duration(seconds:4));
   }catch(_){}
   if(mounted)setState((){routes=old;offline=old.isNotEmpty;});
   final uri=widget.service.uri('/api/v1/day-routes',{
    'month':monthKey(day)});
   final res=decodeApi(await (
    widget.service.client?.get(uri,headers:widget.service.headers)??
    http.get(uri,headers:widget.service.headers))
      .timeout(const Duration(seconds:25)));
   final fresh=(res['items'] as List)
     .map((v)=>Map<String,dynamic>.from(v as Map)).toList();
   try{await widget.queue.cache(key,fresh);}catch(_){}
   if(mounted)setState((){routes=fresh;offline=false;});
  }catch(e){
   if(e is ApiFailure&&(e.status==401||e.status==403)){
    if(mounted)setState((){routes=[];trips=[];});
   }
   if(mounted)setState(()=>error=e is TimeoutException
    ?'Máy chủ phản hồi chậm. Dữ liệu đã lưu trên máy vẫn còn; nhấn Làm mới hoặc kiểm tra hàng đợi đồng bộ.'
    :e.toString());
  }finally{
   await loadTrips();
   if(mounted)setState(()=>busy=false);
  }
 }
 Future<void> chooseDay()async{
  final value=await showDatePicker(context:context,initialDate:day,
   firstDate:DateTime(2020),lastDate:DateTime(2100));
  if(value!=null&&mounted){setState(()=>day=value);await load();}
 }
 Future<void> openRoute(Map<String,dynamic> route)async{
  final id=route['id'].toString();
  final state=workSessionState(route,widget.queue.pending);
  final today=dayKey(DateTime.now().toUtc().add(const Duration(hours:7)));
  if(route['trip_id']==null&&state=='open'&&route['owner_sub']==widget.queue.identity&&
    route['route_date'].toString().startsWith(today)){
   final another=routes.any((r)=>r['id']!=id&&
     r['owner_sub']==widget.queue.identity&&
     workSessionState(r,widget.queue.pending)=='ongoing');
   if(another){
    if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
     content:Text('Đã có phiên đang đi. Hãy tiếp tục hoặc kết thúc phiên đó trước.')));
    return;
   }
   final ref=workSessionId(widget.queue.identity,id);
   // Do not open the real session before locally scheduled customer
   // stops are acknowledged. Same-millisecond outbox rows may reorder.
   final depends=<String>[
    for(final op in widget.queue.pending)
     if(op['path']=='/api/v1/day-routes'&&
       (op['payload'] as Map?)?['client_ref']==id)id,
    for(final op in widget.queue.pending)
     if(op['path']=='/api/v1/day-routes/$id'&&
       op['method']=='PATCH'&&
       (op['payload'] as Map?)?['client_ref']!=null)
      (op['payload'] as Map)['client_ref'].toString(),
    for(final op in widget.queue.pending)
     if(op['path']=='/api/v1/day-routes/$id/stops'&&
       op['method']=='POST'&&
       (op['payload'] as Map?)?['client_ref']!=null)
      (op['payload'] as Map)['client_ref'].toString(),
   ];
   try{
    await widget.queue.enqueue('/api/v1/day-routes/$id/work-session',{
     'client_ref':ref,'captured_at':DateTime.now().toUtc().toIso8601String(),
    },dependsOn:depends);
    route={...route,'work_session_state':'ongoing',
     'work_session_id':ref,'work_session_version':1};
   }catch(e){
    if(mounted)ScaffoldMessenger.of(context).showSnackBar(
     SnackBar(content:Text('Không lưu được mở phiên: $e')));
    return;
   }
  }
  if(!mounted)return;
  await Navigator.push(context,MaterialPageRoute(builder:(_)=>DayRoutePage(
   queue:widget.queue,service:widget.service,routeId:id,cachedRoute:route)));
  if(mounted)await load();
 }
 Future<void> mutateTrip(Map<String,dynamic> route,{required bool close})async{
  final id=route['trip_id']?.toString();
  if(id==null)return;
  if(widget.queue.pending.any((op)=>
    (op['path']=='/api/v1/trips/${id}/extend'||
     op['path']=='/api/v1/trips/${id}/close')&&
    op['namespace']?.toString().startsWith('${widget.queue.identity}:')==true)){
   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
    content:Text('Thay đổi chuyến trước đang chờ đồng bộ. Hãy xử lý xong rồi sửa tiếp.')));
   return;
  }
  final first=DateTime.tryParse(route['trip_start_date']?.toString()??'');
  final lastDay=DateTime.tryParse(route['trip_end_date']?.toString()??'');
  if(first==null||lastDay==null)return;
  final note=TextEditingController();
  String? until;
  if(close){
   final confirm=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
    title:const Text('Kết thúc chuyến sớm?'),
    content:Column(mainAxisSize:MainAxisSize.min,children:[
     const Text('Lịch sử khách, GPS, ảnh, đơn và khảo sát vẫn được giữ nguyên.'),
     TextField(controller:note,maxLength:2000,maxLines:2,
      decoration:const InputDecoration(labelText:'Lý do kết thúc (tùy chọn)')),
    ]),
    actions:[
     TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Quay lại')),
     FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Xác nhận kết thúc')),
    ]));
   if(confirm!=true){note.dispose();return;}
  }else{
   final earliest=lastDay.add(const Duration(days:1));
   final latest=first.add(const Duration(days:90));
   if(earliest.isAfter(latest)){
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Đã đến giới hạn 90 ngày.')));
    return;
   }
   final today=DateTime.now().toUtc().add(const Duration(hours:7));
   final suggested=DateTime(today.year,today.month,today.day);
   final picked=await showDatePicker(context:context,
     initialDate:suggested.isAfter(earliest)&&suggested.isBefore(latest)?suggested:earliest,
     firstDate:earliest,lastDate:latest);
   if(picked==null){note.dispose();return;}
   until=dayKey(picked);
  }
  try{
   await widget.queue.enqueue('/api/v1/trips/${id}/${close?'close':'extend'}',{
    'client_ref':const Uuid().v4(),'version':route['trip_version']??1,
    'note':note.text.trim(),
    'captured_at':DateTime.now().toUtc().toIso8601String(),
    if(!close)'end_date':until,
   },dependsOn:[
    for(final op in widget.queue.pending)
     if(op['path']=='/api/v1/trips'&&
      (op['payload'] as Map?)?['client_ref']==id)id,
   ]);
   if(mounted){
    setState((){});
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
     content:Text('Đã lưu thay đổi trên máy · đang chờ đồng bộ')));
   }
  }catch(e){
   if(mounted)ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content:Text('Không lưu được thay đổi chuyến: ${e}')));
  }finally{note.dispose();}
 }
 List<Map<String,dynamic>> get dayRoutes=>mergeTripRoutes(
  routes,trips,widget.queue.pending,widget.queue.identity,dayKey(day));
 @override Widget build(BuildContext context){
  final today=dayKey(DateTime.now().toUtc().add(const Duration(hours:7)));
  final totals=WorkCounts.fromRoutes(dayRoutes);
  return Column(children:[
   Padding(padding:const EdgeInsets.fromLTRB(12,12,12,6),child:Column(
    crossAxisAlignment:CrossAxisAlignment.stretch,children:[
     Text('Công tác',style:Theme.of(context).textTheme.titleLarge),
     const SizedBox(height:8),
     SegmentedButton<int>(
      segments:const [
       ButtonSegment(value:0,icon:Icon(Icons.calendar_month_outlined),label:Text('Kế hoạch')),
       ButtonSegment(value:1,icon:Icon(Icons.route_outlined),label:Text('Hôm nay')),
       ButtonSegment(value:2,icon:Icon(Icons.fact_check_outlined),label:Text('Kết quả')),
      ],
      selected:{tab},onSelectionChanged:(s){
        setState(()=>tab=s.first);
        if(tab!=0)unawaited(load());
       },
     ),
    ])),
   Expanded(child:tab==0
    ?MonthlyPlanPage(queue:widget.queue,service:widget.service)
    :ListView(padding:const EdgeInsets.all(12),children:[
      Row(children:[
       Expanded(child:Text(tab==1?'Tuyến ngày':'Đối chiếu kế hoạch – thực tế',
        style:Theme.of(context).textTheme.titleMedium)),
       IconButton(tooltip:'Chọn ngày',icon:const Icon(Icons.calendar_today_outlined),
        onPressed:chooseDay),
       IconButton(tooltip:'Làm mới',icon:const Icon(Icons.sync),onPressed:busy?null:load),
      ]),
      Text('${dayKey(day)}${dayKey(day)==today?' · Hôm nay':''}'),
      if(busy)const LinearProgressIndicator(minHeight:2),
      if(offline)Text('Dữ liệu đã lưu trên máy · chờ đồng bộ.',
       style:Theme.of(context).textTheme.bodySmall),
      if(error!=null)Text(error!,style:TextStyle(color:Theme.of(context).colorScheme.error)),
      if(dayRoutes.isEmpty&&!busy)...[
       Padding(padding:const EdgeInsets.all(12),child:Text(
        error!=null||offline
          ?'Chưa xác nhận được tuyến ngày từ máy chủ. Không có nghĩa là lịch bị mất. '
           'Bấm Làm mới hoặc mở Kế hoạch để kiểm tra lịch chờ đồng bộ.'
          :'Chưa có tuyến cho ngày này. Nếu đã lập lịch, mở Kế hoạch để kiểm tra tuyến ngày.')),
       TextButton.icon(onPressed:()=>setState(()=>tab=0),
        icon:const Icon(Icons.calendar_month_outlined),
        label:const Text('Mở Kế hoạch')),
      ],
      if(tab==2&&dayRoutes.isNotEmpty)Card(child:Padding(
       padding:const EdgeInsets.all(12),child:Column(
        crossAxisAlignment:CrossAxisAlignment.start,children:[
         Text('Tổng kết ngày',style:Theme.of(context).textTheme.titleMedium),
         Text('Kế hoạch: ${totals.planned} · Đã ghé: ${totals.visited} · Chưa ghé: ${totals.notVisited}'),
         Text('Không ghé có lý do: ${totals.missed} · Chưa ghi nhận: ${totals.withoutReason}'),
         Text('Hoàn thành khảo sát: ${totals.surveys} · Lead mới: ${totals.leads}'),
         Text('GPS phát triển thị trường: ${totals.marketVisits} lần'),
         Text('Ngoài kế hoạch: ${totals.unplanned} điểm · Đã ghé: ${totals.unplannedVisited}'),
        ],
       ))),
      for(final route in dayRoutes)Builder(builder:(context){
       final c=WorkCounts.fromRoutes([route]);
       final state=workSessionState(route,widget.queue.pending);
       final own=route['owner_sub']==widget.queue.identity;
       final trip=route['trip_id']!=null;
       final start=!trip&&state=='open'&&own&&route['route_date'].toString().startsWith(today);
       final action=trip?'Mở danh sách khách':start?'Làm việc tại khách':state=='ongoing'?'Tiếp tục công tác'
        :state=='done'||state=='cancelled'?'Xem lịch sử':'Xem lịch';
       final rangeStart=route['trip_start_date']?.toString().substring(0,10)??'';
       final rangeEnd=route['trip_end_date']?.toString().substring(0,10)??'';
       final tripLength=trip?DateTime.parse(rangeEnd).difference(DateTime.parse(rangeStart)).inDays+1:1;
       final progress=trip?DateTime.parse(dayKey(day)).difference(DateTime.parse(rangeStart)).inDays+1:1;
       final tripState=route['trip_closed_at']!=null?'Đã kết thúc':
         today.compareTo(rangeStart)<0?'Sắp đến ngày':
         today.compareTo(rangeEnd)>0?'Quá hạn · có thể gia hạn':'Đang công tác';
       final scopesCount=(route['scopes'] as List?)?.length??1;
       final status=route['pending_route']==true
        ?'Lịch đã lưu trên máy · chờ đồng bộ'
        :route['pending_route_date']==true
        ?'Ngày mới đã lưu máy · chờ máy chủ xác nhận'
        :state=='ongoing'?'Đang đi':state=='done'?'Đã kết thúc'
        :state=='cancelled'?'Đã hủy':'Trong lịch công tác';
       return Card(child:Column(children:[
        ListTile(
         leading:Icon(state=='ongoing'?Icons.directions_walk_outlined:Icons.route_outlined),
         title:Text(route['purpose']?.toString()??'Công tác'),
         subtitle:Text(
          '${trip?'${scopesCount} phạm vi':route['scope_kind']=='territory'?'Địa bàn':route['scope_kind']=='chain'?'Chuỗi':'Khách cụ thể'} · ${trip?'${rangeStart} – ${rangeEnd} · ngày ${progress.clamp(1,tripLength)}/${tripLength}':route['scope_key']}\n'
          '${trip?tripState:status} · Ưu tiên ${trip?(route['priority_customer_ids'] as List?)?.length??0:c.planned} · Đã ghé ${c.visited}\n'
          'Khảo sát ${c.surveys} · Lead ${c.leads} · GPS thị trường ${c.marketVisits}',
         ),
         isThreeLine:true,onTap:()=>openRoute(route),
        ),
        if(trip&&own&&route['trip_closed_at']==null)
         Wrap(alignment:WrapAlignment.end,spacing:4,runSpacing:0,children:[
          TextButton.icon(onPressed:()=>mutateTrip(route,close:false),
           icon:const Icon(Icons.date_range_outlined),label:const Text('Gia hạn')),
          if(today.compareTo(rangeStart)>=0)
           TextButton.icon(onPressed:()=>mutateTrip(route,close:true),
            icon:const Icon(Icons.stop_circle_outlined),label:const Text('Kết thúc sớm')),
         ]),
        Align(alignment:Alignment.centerRight,child:Padding(
         padding:const EdgeInsets.only(right:8,bottom:6),
         child:TextButton.icon(
          key:ValueKey('work-session-${route['id']}'),
          onPressed:()=>openRoute(route),
          icon:Icon(trip?Icons.people_outline:start?Icons.play_arrow_outlined:
           state=='ongoing'?Icons.play_circle_outline:Icons.history),
          label:Text(action)),
        )),
       ]));
      }),
    ])),
  ]);
 }
}
