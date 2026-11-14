import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
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
 List<Map<String,dynamic>> routes=[];
 bool busy=false,offline=false;
 String? error;
 int lastPending=0;
 String get key=>'day-routes:${monthKey(day)}';
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
 Future<void> load()async{
  if(busy)return;
  setState((){busy=true;error=null;});
  try{
   final cache=await widget.queue.cached(key);
   if(mounted)setState((){routes=cache;offline=true;});
   final res=decodeApi(await http.get(
    widget.service.uri('/api/v1/day-routes',{'month':monthKey(day)}),
    headers:widget.service.headers).timeout(const Duration(seconds:18)));
   final fresh=(res['items'] as List)
     .map((v)=>Map<String,dynamic>.from(v as Map)).toList();
   await widget.queue.cache(key,fresh);
   if(mounted)setState((){routes=fresh;offline=false;});
  }catch(e){
   if(e is ApiFailure&&(e.status==401||e.status==403)){
    if(mounted)setState(()=>routes=[]);
   }
   if(mounted)setState(()=>error=e.toString());
  }finally{if(mounted)setState(()=>busy=false);}
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
  if(state=='open'&&route['owner_sub']==widget.queue.identity&&
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
 List<Map<String,dynamic>> get dayRoutes=>
  routes.where((r)=>r['route_date'].toString().startsWith(dayKey(day))
    &&r['status']=='ready'&&r['plan_status']!='cancelled').toList();
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
      if(dayRoutes.isEmpty&&!busy)
       const Padding(padding:EdgeInsets.all(18),child:Text(
        'Chưa có công tác trong ngày. Mở Kế hoạch để lập lịch.')),
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
       final start=state=='open'&&own&&route['route_date'].toString().startsWith(today);
       final action=start?'Bắt đầu phiên':state=='ongoing'?'Tiếp tục phiên'
        :state=='done'||state=='cancelled'?'Xem lịch sử':'Xem lịch';
       final status=state=='ongoing'?'Đang đi':state=='done'?'Đã kết thúc'
        :state=='cancelled'?'Đã hủy':'Chưa bắt đầu';
       return Card(child:Column(children:[
        ListTile(
         leading:Icon(state=='ongoing'?Icons.directions_walk_outlined:Icons.route_outlined),
         title:Text(route['purpose']?.toString()??'Công tác'),
         subtitle:Text(
          '${route['scope_kind']=='territory'?'Địa bàn':route['scope_kind']=='chain'?'Chuỗi':'Khách cụ thể'} · ${route['scope_key']}\n'
          '$status · Kế hoạch ${c.planned} · Đã ghé ${c.visited} · Chưa ghé ${c.notVisited}\n'
          'Khảo sát ${c.surveys} · Lead ${c.leads} · GPS thị trường ${c.marketVisits}',
         ),
         isThreeLine:true,onTap:()=>openRoute(route),
        ),
        Align(alignment:Alignment.centerRight,child:Padding(
         padding:const EdgeInsets.only(right:8,bottom:6),
         child:TextButton.icon(
          key:ValueKey('work-session-${route['id']}'),
          onPressed:()=>openRoute(route),
          icon:Icon(start?Icons.play_arrow_outlined:
           state=='ongoing'?Icons.play_circle_outline:Icons.history),
          label:Text(action)),
        )),
       ]));
      }),
    ])),
  ]);
 }
}
