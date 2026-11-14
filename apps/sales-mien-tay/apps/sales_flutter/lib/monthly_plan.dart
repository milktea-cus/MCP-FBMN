import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'customers.dart';
import 'offline_queue.dart';
import 'planning_periods.dart';
import 'session.dart';
import 'day_route.dart';
import 'schedule_archive.dart';

/// A plan is a dated business assignment, not a customer or a survey session.
/// Multiple territories/chains can be selected without requiring any customer.
class MonthlyPlanPage extends StatefulWidget {
 final OfflineQueue queue;
 final CustomerService service;
 const MonthlyPlanPage({super.key,required this.queue,required this.service});
 @override State<MonthlyPlanPage> createState()=>_MonthlyPlanPageState();
}
class _MonthlyPlanPageState extends State<MonthlyPlanPage> {
 DateTime month=DateTime(DateTime.now().year,DateTime.now().month);
 int period=0;
 List<Map<String,dynamic>> items=[],scopes=[],dayRoutes=[];
 bool busy=false,cached=false,showDeleted=false;
 String? error;
 String get monthCache=>'monthly-plans:${monthKey(month)}';
 String get optionsCache=>'monthly-plan-scopes';
 String get routeCache=>'day-routes:${monthKey(month)}';
 @override void initState(){super.initState();widget.queue.addListener(_changed);unawaited(_reload());}
 @override void dispose(){widget.queue.removeListener(_changed);super.dispose();}
 void _changed(){if(mounted)setState((){});}
 void _toast(String msg){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(msg)));}
 Future<void> _reload()async{
  if(busy)return;
  setState((){busy=true;error=null;});
  try{
   final localItems=await widget.queue.cached(monthCache);
   final localScopes=await widget.queue.cached(optionsCache);
    final localRoutes=await widget.queue.cached(routeCache);
   if(mounted)setState((){items=localItems;scopes=localScopes;dayRoutes=localRoutes;cached=true;});
   final results=await Future.wait([
    http.get(widget.queue.session.uri('/api/v1/monthly-plans').replace(queryParameters:{'month':monthKey(month)}),headers:widget.service.headers).timeout(const Duration(seconds:20)),
    http.get(widget.queue.session.uri('/api/v1/monthly-plans/options'),headers:widget.service.headers).timeout(const Duration(seconds:20)),
     http.get(widget.queue.session.uri('/api/v1/day-routes').replace(queryParameters:{'month':monthKey(month)}),headers:widget.service.headers).timeout(const Duration(seconds:20)),
   ]);
   final plans=decodeApi(results[0]),options=decodeApi(results[1]),routesData=decodeApi(results[2]);
   final fresh=(plans['items'] as List).map((e)=>Map<String,dynamic>.from(e as Map)).toList();
   final allowed=(options['scopes'] as List).map((e)=>Map<String,dynamic>.from(e as Map)).toList();
   final freshRoutes=(routesData['items'] as List).map((e)=>Map<String,dynamic>.from(e as Map)).toList();
   await widget.queue.cache(monthCache,fresh);
   await widget.queue.cache(routeCache,freshRoutes);
   await widget.queue.cache(optionsCache,allowed);
   if(mounted)setState((){items=fresh;scopes=allowed;dayRoutes=freshRoutes;cached=false;});
  }catch(e){
   if(e is ApiFailure&&(e.status==401||e.status==403)){
    if(mounted)setState((){items=[];scopes=[];cached=false;});
   }
   if(mounted)setState(()=>error=e.toString());
  }finally{if(mounted)setState(()=>busy=false);}
 }
 void _changeMonth(int delta){
  setState((){month=DateTime(month.year,month.month+delta);period=0;items=[];dayRoutes=[];});
  unawaited(_reload());
 }
 /// Create a plan and its ordered day stops as one dependency graph in the
 /// account-scoped outbox. Neither offline nor a retry duplicates stop IDs.
 Future<void> _edit({Map<String,dynamic>? original})async{
  if(scopes.isEmpty){_toast('Chưa có phạm vi được giao. Kết nối lại để cập nhật quyền.');return;}
  final selection=await Navigator.push<MonthlyPlanSelection>(context,MaterialPageRoute(
    builder:(_)=>MonthlyPlanEditor(month:month,scopes:scopes,original:original,
      queue:widget.queue,service:widget.service)));
  if(selection==null||!mounted)return;
  var added=0,skipped=0;
  try{
   for(final scope in selection.scopes){
    final editing=original!=null,ref=const Uuid().v4();
    final kind=scope['scope_kind'].toString(),key=scope['scope_key'].toString();
    final date=dayKey(selection.date);
    // Existing and queued work on that date/scope is not recreated.
    if(!editing&&(items.any((x)=>x['work_date'].toString().startsWith(date)
       &&x['scope_kind']==kind&&x['scope_key']==key&&x['status']=='planned') ||
       widget.queue.pending.any((x)=>x['path']=='/api/v1/monthly-plans'
        &&(x['payload'] as Map)['work_date']==date
        &&(x['payload'] as Map)['scope_kind']==kind
        &&(x['payload'] as Map)['scope_key']==key))){
     skipped++;continue;
    }
    final payload=<String,dynamic>{
     'client_ref':ref,'period_ym':monthKey(month),'work_date':date,
     'scope_kind':kind,'scope_key':key,
     'province':kind=='territory'?scope['province']:null,
     'district':kind=='territory'?scope['district']:null,
     'purpose':selection.purpose,'target_new_customers':selection.target,
     'note':selection.note,'status':selection.status,
     if(editing)'version':original['version'],
    };
    await widget.queue.enqueue(
     editing?'/api/v1/monthly-plans/${original['id']}':'/api/v1/monthly-plans',
     payload,method:editing?'PATCH':'POST');
    added++;
    if(editing)continue;
    final routeId=const Uuid().v4();
    await widget.queue.enqueue('/api/v1/day-routes',{
     'client_ref':routeId,'monthly_plan_id':ref,'route_date':date,
     'purpose':selection.purpose,'note':selection.note,'status':'ready',
    },dependsOn:[ref]);
    final sk='${kind}:${key}';
    final customers=selection.customersByScope[sk]??<String>[];
    var sequence=0;
    for(final cid in customers){
     await widget.queue.enqueue('/api/v1/day-routes/$routeId/stops',{
      'client_ref':const Uuid().v4(),'stop_kind':'customer',
      'customer_id':cid,'sequence':++sequence,'purpose':'Chăm sóc điểm bán',
     },dependsOn:[routeId]);
    }
    if(customers.isEmpty&&kind!='customer'){
     await widget.queue.enqueue('/api/v1/day-routes/$routeId/stops',{
      'client_ref':const Uuid().v4(),'stop_kind':kind=='chain'?'chain':'area',
      if(kind=='chain')'chain_id':key,
      if(kind=='territory')...{'province':scope['province'],'district':scope['district']},
      'sequence':1,'purpose':kind=='chain'?'Chăm sóc chuỗi':'Tìm điểm bán mới',
     },dependsOn:[routeId]);
    }
    await widget.queue.cache('day-route-candidates:$routeId',
      selection.availableByScope[sk]??<Map<String,dynamic>>[]);
   }
   _toast('Đã lưu $added lịch và tuyến ngày trên máy${skipped>0?' · bỏ qua $skipped lịch trùng':''}.');
   if(mounted)await _reload();
  }catch(e){_toast('Không lưu được kế hoạch/tuyến: $e');}
 }
 Future<void> deletePlan(Map<String,dynamic> plan)async{
  if(busy)return;
  final deleted=await confirmArchiveWorkSchedule(context,
   service:widget.service,queue:widget.queue,plan:plan);
  if(!mounted||!deleted)return;
  setState((){
   items=[for(final r in items)
    if(r['id']==plan['id']){...r,'status':'cancelled'} else r];
   dayRoutes=[for(final r in dayRoutes)
    if(r['monthly_plan_id']==plan['id']){...r,'plan_status':'cancelled'}
    else r];
  });
  await _reload();
 }
 Future<void> createRoute(Map<String,dynamic> plan)async{
  final id=const Uuid().v4();
  final payload=<String,dynamic>{'client_ref':id,'monthly_plan_id':plan['id'],
   'route_date':plan['work_date'].toString().substring(0,10),
   'purpose':plan['purpose'],'note':plan['note']??'','status':'ready'};
  try{
   await widget.queue.enqueue('/api/v1/day-routes',payload,dependsOn:[
    for(final op in widget.queue.pending)if(op['path']=='/api/v1/monthly-plans'&&
      (op['payload'] as Map)['client_ref']==plan['id'])plan['id'].toString(),
   ]);
   _toast('Đã lưu tuyến trên máy · chờ đồng bộ');
   if(mounted)await openRoute({...payload,'id':id,'owner_sub':widget.queue.identity,
    'scope_kind':plan['scope_kind'],'scope_key':plan['scope_key'],
    'province':plan['province'],'district':plan['district'],'plan_status':'planned'});
  }catch(e){_toast('Không tạo được tuyến: $e');}
 }
 Future<void> openRoute(Map<String,dynamic> r)async{
  await Navigator.push(context,MaterialPageRoute(builder:(_)=>DayRoutePage(
   queue:widget.queue,service:widget.service,routeId:r['id'].toString(),cachedRoute:r)));
  if(mounted)await _reload();
 }
 Future<void> moveRoute(Map<String,dynamic> r)async{
  final now=DateTime.tryParse(r['route_date'].toString())??month;
  final date=await showDatePicker(context:context,initialDate:now,
   firstDate:DateTime(month.year,month.month),lastDate:monthEnd(month));
  if(date==null)return;
  try{
   await widget.queue.enqueue('/api/v1/day-routes/${r['id']}',{
    'client_ref':const Uuid().v4(),'monthly_plan_id':r['monthly_plan_id'],
    'route_date':dayKey(date),'purpose':r['purpose'],'note':r['note']??'',
    'status':r['status'],'version':r['version'],
   },method:'PATCH');
   _toast('Đã lưu ngày mới, chờ đồng bộ.');
  }catch(e){_toast('Không dời được tuyến: $e');}
 }

 @override Widget build(BuildContext context){
  final visible=items.where((r){
   final date=DateTime.tryParse(r['work_date']?.toString()??'');
   return (showDeleted?(r['status']=='cancelled'):(r['status']!='cancelled'))&&
    (period==0||date!=null&&planningPeriod(date)==period);
  }).toList();
  final pending=widget.queue.pending.where((r){
   final path=r['path']?.toString()??'';
   if(!path.startsWith('/api/v1/monthly-plans'))return false;
   final v=r['payload'];return v is Map&&v['period_ym']==monthKey(month)
     &&(period==0||DateTime.tryParse(v['work_date'].toString())?.day != null
       &&planningPeriod(DateTime.parse(v['work_date'].toString()))==period);
  }).toList();
  final canCreate=scopes.isNotEmpty&&!busy;
  return Scaffold(
   appBar:AppBar(title:const Text('Kế hoạch tháng'),actions:[
    IconButton(key:const ValueKey('monthly-archived-toggle'),
     tooltip:showDeleted?'Xem lịch đang hoạt động':'Xem lịch đã xóa',
     onPressed:()=>setState(()=>showDeleted=!showDeleted),
     icon:Icon(showDeleted?Icons.event_available:Icons.delete_sweep_outlined)),
    IconButton(tooltip:'Tải lại',onPressed:busy?null:_reload,icon:const Icon(Icons.sync)),
   ]),
   body:ListView(padding:const EdgeInsets.all(12),children:[
    Row(children:[
     IconButton(tooltip:'Tháng trước',onPressed:busy?null:()=>_changeMonth(-1),icon:const Icon(Icons.chevron_left)),
     Expanded(child:Text('Tháng ${month.month.toString().padLeft(2,'0')}/${month.year}',
       textAlign:TextAlign.center,style:Theme.of(context).textTheme.titleLarge)),
     IconButton(tooltip:'Tháng sau',onPressed:busy?null:()=>_changeMonth(1),icon:const Icon(Icons.chevron_right)),
    ]),
    const SizedBox(height:8),
    MonthlyPeriodActions(
     month:month,period:period,
     onPeriodChanged:(value)=>setState(()=>period=value),
     onAdd:()=>_edit(),canAdd:canCreate,
    ),
    const SizedBox(height:10),
    if(showDeleted)const Padding(
     padding:EdgeInsets.symmetric(horizontal:4,vertical:6),
     child:Text('Đã xóa · chỉ xem lịch sử, không mất khảo sát hoặc lượt ghé')),
    if(busy)const LinearProgressIndicator(),
    if(error!=null)Padding(padding:const EdgeInsets.symmetric(vertical:8),child:
      Text(cached?'Dữ liệu đã lưu trên máy · chưa tải mới: ${error!}':error!,
       style:TextStyle(color:Theme.of(context).colorScheme.error))),
    for(final p in pending)Card(child:ListTile(
     leading:const Icon(Icons.cloud_upload_outlined),
     title:Text((p['payload'] as Map)['purpose']?.toString()??'Công tác'),
     subtitle:Text("${(p['payload'] as Map)['work_date']} · ${(p['payload'] as Map)['scope_key']}\n${p['error']??'Đã lưu máy · chờ đồng bộ'}"),
     trailing:Builder(builder:(_){
      final plan=Map<String,dynamic>.from(p['payload'] as Map);
      final routeOp=widget.queue.pending.where((op)=>
       op['path']=='/api/v1/day-routes' &&
       (op['payload'] as Map)['monthly_plan_id']==plan['client_ref']).firstOrNull;
      if(routeOp!=null){
       final route=Map<String,dynamic>.from(routeOp['payload'] as Map);
       return IconButton(icon:const Icon(Icons.route),tooltip:'Mở tuyến đang chờ đồng bộ',
        onPressed:()=>openRoute({...route,'id':route['client_ref'],
          'owner_sub':widget.queue.identity,'scope_kind':plan['scope_kind'],
          'scope_key':plan['scope_key'],'province':plan['province'],
          'district':plan['district'],'plan_status':'planned'}));
      }
      return p['status']=='blocked'?IconButton(icon:const Icon(Icons.refresh),
       tooltip:'Thử đồng bộ lại',onPressed:()=>widget.queue.retryBlocked(p['key'].toString())):const SizedBox.shrink();
     }),
    )),
    for(final r in visible)Card(child:ListTile(
     leading:CircleAvatar(child:Text(DateTime.tryParse(r['work_date'].toString())?.day.toString()??'–')),
     title:Text(r['purpose']?.toString()??''),
     subtitle:Text("${r['work_date'].toString().substring(0,10)} · ${r['scope_kind']=='chain'?'Chuỗi':r['district']==''?'Toàn tỉnh':'Địa bàn'}: ${r['scope_kind']=='chain'?scopes.where((s)=>s['scope_key']==r['scope_key']).map((s)=>s['label']).firstOrNull??'Chuỗi':r['scope_key']}\nMục tiêu khách mới: ${r['target_new_customers']} · ${r['status']=='cancelled'?'Đã hủy':'Đã lập kế hoạch'} · v${r['version']}"),
     isThreeLine:true,
     trailing:Builder(builder:(ctx){
       final matching=dayRoutes.where((t)=>t['monthly_plan_id']==r['id']).toList();
       final queued=widget.queue.pending.where((op)=>op['path']=='/api/v1/day-routes'&&
         (op['payload'] as Map)['monthly_plan_id']==r['id']).toList();
       final route=matching.firstOrNull;
       final assigned=r['owner_sub']==widget.queue.identity&&scopes.any(
         (s)=>s['scope_key']==r['scope_key']&&s['scope_kind']==r['scope_kind']);
       return Row(mainAxisSize:MainAxisSize.min,children:[
        if(assigned&&r['status']=='planned')IconButton(
         key:ValueKey('delete-plan:${r['id']}'),tooltip:'Xóa lịch',
         icon:const Icon(Icons.delete_outline),onPressed:()=>deletePlan(r),
         visualDensity:VisualDensity.compact),
        if(assigned||route!=null||queued.isNotEmpty)PopupMenuButton<String>(
         tooltip:'Thao tác lịch',icon:const Icon(Icons.more_vert),
         onSelected:(action){
          if(action=='edit')unawaited(_edit(original:r));
          if(action=='create')unawaited(createRoute(r));
          if(action=='open'&&route!=null)unawaited(openRoute(route));
          if(action=='move'&&route!=null)unawaited(moveRoute(route));
          if(action=='queued'&&queued.isNotEmpty){
           final op=queued.first,plan=Map<String,dynamic>.from(op['payload'] as Map);
           unawaited(openRoute({...plan,'id':plan['client_ref'],
            'owner_sub':widget.queue.identity,
            'scope_kind':r['scope_kind'],'scope_key':r['scope_key'],
            'province':r['province'],'district':r['district'],
            'plan_status':r['status']}));
          }
         },
         itemBuilder:(context)=>[
          if(assigned&&r['status']=='planned')
           const PopupMenuItem(value:'edit',child:Text('Sửa lịch')),
          if(assigned&&route==null&&queued.isEmpty&&r['status']=='planned')
           const PopupMenuItem(value:'create',child:Text('Tạo tuyến ngày')),
          if(route!=null)
           const PopupMenuItem(value:'open',child:Text('Mở tuyến ngày')),
          if(assigned&&r['status']=='planned'&&route!=null&&route['status']=='ready')
           const PopupMenuItem(value:'move',child:Text('Dời ngày tuyến')),
          if(queued.isNotEmpty)
           const PopupMenuItem(value:'queued',child:Text('Tuyến chờ đồng bộ')),
         ]),
       ]);
      }),
    )),
    if(!busy&&visible.isEmpty&&pending.isEmpty)const Padding(
      padding:EdgeInsets.all(24),child:Text('Chưa có công tác trong kỳ này. Hãy lập chuyến đi, không cần có khách sẵn.',textAlign:TextAlign.center)),
   ]),
  );
 }
}

/// Compact, one-row planning toolbar; period five is absent in February 28-day.
class MonthlyPeriodActions extends StatelessWidget {
 final DateTime month;
 final int period;
 final ValueChanged<int> onPeriodChanged;
 final VoidCallback onAdd;
 final bool canAdd;
 const MonthlyPeriodActions({super.key,required this.month,required this.period,
  required this.onPeriodChanged,required this.onAdd,required this.canAdd});
 @override Widget build(BuildContext context){
  final periods=[for(var p=1;p<=5;p++)if(periodDays(month,p).isNotEmpty)p];
  return Row(children:[
   Expanded(child:DropdownButtonFormField<int>(
    key:ValueKey('period-${monthKey(month)}-$period'),
    initialValue:period,isExpanded:true,
    decoration:const InputDecoration(labelText:'Lọc kỳ',isDense:true),
    items:[
     const DropdownMenuItem(value:0,child:Text('Tất cả')),
     for(final p in periods)DropdownMenuItem(value:p,child:Text('Kỳ $p')),
    ],
    onChanged:(value){if(value!=null)onPeriodChanged(value);},
   )),
   const SizedBox(width:8),
   FilledButton.icon(onPressed:canAdd?onAdd:null,
    icon:const Icon(Icons.add),label:const Text('Thêm công tác')),
  ]);
 }
}

class MonthlyPlanSelection {
 final List<Map<String,dynamic>> scopes;
 final DateTime date;
 final String purpose,note,status;
 final int target;
 final Map<String,List<String>> customersByScope;
 final Map<String,List<Map<String,dynamic>>> availableByScope;
 const MonthlyPlanSelection(this.scopes,this.date,this.purpose,this.note,
   this.status,this.target,this.customersByScope,this.availableByScope);
}
class MonthlyPlanEditor extends StatefulWidget {
 final DateTime month;
 final List<Map<String,dynamic>> scopes;
 final Map<String,dynamic>? original;
 final OfflineQueue? queue;
 final CustomerService? service;
 const MonthlyPlanEditor({super.key,required this.month,required this.scopes,
  this.queue,this.service,this.original});
 @override State<MonthlyPlanEditor> createState()=>_MonthlyPlanEditorState();
}
class _MonthlyPlanEditorState extends State<MonthlyPlanEditor>{
 late DateTime date;
 late final TextEditingController purpose,note,target,search;
 final selected=<String>{};
 final selectedCustomers=<String,Set<String>>{};
 final available=<String,List<Map<String,dynamic>>>{};
 final loadingCandidates=<String>{};
 final candidateErrors=<String,String>{};
 String mode='territory';
 late final TextEditingController customerSearch;
 String status='planned';
 @override void initState(){
  super.initState();
  final row=widget.original;
  date=row==null?DateTime(widget.month.year,widget.month.month,1):DateTime.tryParse(row['work_date'].toString())??widget.month;
  purpose=TextEditingController(text:row?['purpose']?.toString()??'');
  note=TextEditingController(text:row?['note']?.toString()??'');
  target=TextEditingController(text:row?['target_new_customers']?.toString()??'0');
  search=TextEditingController();customerSearch=TextEditingController();
  status=row?['status']?.toString()??'planned';
  if(row!=null){
   final key="${row['scope_kind']}:${row['scope_key']}";
   selected.add(key);mode=row['scope_kind'].toString();
   final scope=widget.scopes.where((s)=>"${s['scope_kind']}:${s['scope_key']}"==key).firstOrNull;
   if(scope!=null)unawaited(loadCustomers(scope));
  }
 }
 @override void dispose(){purpose.dispose();note.dispose();target.dispose();search.dispose();customerSearch.dispose();super.dispose();}
 String scopeId(Map<String,dynamic> scope)=>"${scope['scope_kind']}:${scope['scope_key']}";
 Future<void> loadCustomers(Map<String,dynamic> scope)async{
  if(widget.queue==null||widget.service==null)return;
  final id=scopeId(scope);
  if(loadingCandidates.contains(id))return;
  setState(()=>loadingCandidates.add(id));
  final cacheKey='monthly-plan-candidates:$id';
  try{
   final cached=await widget.queue!.cached(cacheKey);
   if(cached.isNotEmpty&&mounted)setState(()=>available[id]=cached);
   final response=await http.get(widget.service!.uri('/api/v1/monthly-plans/candidates',{
    'scope_kind':scope['scope_kind'].toString(),
    'scope_key':scope['scope_key'].toString(),
   }),headers:widget.service!.headers).timeout(const Duration(seconds:20));
   final data=decodeApi(response);
   final rows=(data['items'] as List).map((x)=>Map<String,dynamic>.from(x as Map)).toList();
   await widget.queue!.cache(cacheKey,rows);
   if(mounted)setState((){
    available[id]=rows;candidateErrors.remove(id);
    final allowed=rows.map((r)=>r['id'].toString()).toSet();
    selectedCustomers[id]?.removeWhere((cid)=>!allowed.contains(cid));
    if(scope['scope_kind']=='customer')selectedCustomers[id]={scope['scope_key'].toString()};
   });
  }catch(e){
   if(mounted)setState((){
    candidateErrors[id]=e is ApiFailure&&(e.status==401||e.status==403)
      ?'Không còn quyền chọn khách trong phạm vi này.': 'Dùng dữ liệu khách đã lưu trên máy (nếu có).';
    if(e is ApiFailure&&(e.status==401||e.status==403)){
     available.remove(id);selectedCustomers.remove(id);selected.remove(id);
    }
    if(scope['scope_kind']=='customer'&&selected.contains(id)){
     selectedCustomers[id]={scope['scope_key'].toString()};
    }
   });
  }finally{if(mounted)setState(()=>loadingCandidates.remove(id));}
 }
 void submit(){
  final scopes=widget.scopes.where((o)=>selected.contains("${o['scope_kind']}:${o['scope_key']}")).toList();
  final number=int.tryParse(target.text.trim());
  if(scopes.isEmpty||purpose.text.trim().length<2||purpose.text.length>500||number==null||number<0||number>9999||note.text.length>2000){
   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Chọn phạm vi; nhập mục đích (từ 2 ký tự) và số khách mới hợp lệ.')));
   return;
  }
  Navigator.pop(context,MonthlyPlanSelection(scopes,date,purpose.text.trim(),note.text.trim(),status,number,
   {for(final scope in scopes)scopeId(scope):(
    scope['scope_kind']=='customer'?[scope['scope_key'].toString()]:
    (selectedCustomers[scopeId(scope)]??<String>{}).toList())},
   {for(final scope in scopes)scopeId(scope):available[scopeId(scope)]??<Map<String,dynamic>>[]}));
 }
 Future<void> pickDate()async{
  final d=await showDatePicker(context:context,initialDate:date,firstDate:DateTime(widget.month.year,widget.month.month,1),lastDate:monthEnd(widget.month));
  if(d!=null&&mounted)setState(()=>date=d);
 }
 @override Widget build(BuildContext context){
  final q=search.text.trim().toLowerCase();
  final filtered=widget.scopes.where((o)=>o['scope_kind']==mode &&
    (o['label']?.toString()??'').toLowerCase().contains(q)).toList();
  return Scaffold(
   appBar:AppBar(title:Text(widget.original==null?'Thêm công tác':'Sửa công tác'),actions:[
    TextButton(onPressed:submit,child:const Text('Lưu')),
   ]),
   body:ListView(padding:const EdgeInsets.all(16),children:[
    OutlinedButton.icon(onPressed:pickDate,icon:const Icon(Icons.calendar_today),label:Text('Ngày đi: ${dayKey(date)}')),
    const SizedBox(height:12),
    TextField(controller:purpose,maxLength:500,decoration:const InputDecoration(labelText:'Mục đích công tác *',hintText:'Ví dụ: tìm điểm bán mới, chăm sóc chuỗi')),
    TextField(controller:target,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Chỉ tiêu phát triển khách mới',helperText:'Số lượng khách hàng mới dự kiến, có thể bằng 0')),
    TextField(controller:note,maxLength:2000,maxLines:2,decoration:const InputDecoration(labelText:'Ghi chú')),
    if(widget.original!=null)DropdownButtonFormField<String>(
      initialValue:status,decoration:const InputDecoration(labelText:'Trạng thái'),
      items:const [DropdownMenuItem(value:'planned',child:Text('Đã lập kế hoạch')),DropdownMenuItem(value:'cancelled',child:Text('Hủy kế hoạch'))],
      onChanged:(v)=>setState(()=>status=v??'planned')),
    const SizedBox(height:16),
    Text(widget.original==null?'Chọn địa bàn, chuỗi hoặc khách cụ thể *':'Phạm vi công tác',style:Theme.of(context).textTheme.titleMedium),
    const Text('Chỉ hiển thị phạm vi/khách được giao trực tiếp; không cần có sẵn điểm bán.'),
    const SizedBox(height:8),
    Wrap(spacing:6,runSpacing:4,children:[
     for(final entry in [('territory','Địa bàn'),('customer','Khách cụ thể'),('chain','Chuỗi')])
      ChoiceChip(label:Text(entry.$2),selected:mode==entry.$1,
       onSelected:(_)=>setState(()=>mode=entry.$1)),
    ]),
    const SizedBox(height:8),
    TextField(controller:search,onChanged:(_)=>setState((){}),decoration:const InputDecoration(prefixIcon:Icon(Icons.search),hintText:'Tìm địa bàn, tên khách hoặc chuỗi')),
    const SizedBox(height:8),
    Text('Đã chọn ${selected.length} · ${filtered.length} phạm vi'),
    SizedBox(height:300,child:ListView.builder(
     itemCount:filtered.length,itemBuilder:(ctx,i){
      final item=filtered[i],key="${item['scope_kind']}:${item['scope_key']}";
      return CheckboxListTile(
       dense:true,controlAffinity:ListTileControlAffinity.leading,
       title:Text(item['label'].toString()),value:selected.contains(key),
       onChanged:widget.original!=null?null:(checked){
        setState((){
         if(checked==true){
          selected.add(key);
          if(item['scope_kind']=='customer')selectedCustomers[key]={item['scope_key'].toString()};
         }else{selected.remove(key);selectedCustomers.remove(key);}
        });
        if(checked==true)unawaited(loadCustomers(item));
       });
     })),
    const SizedBox(height:14),
    if(selected.isNotEmpty)...[
     Text('Khách dự kiến ghé',style:Theme.of(context).textTheme.titleMedium),
     const Text('Chọn khách cần ghé. Không chọn khách vẫn lập được tuyến đi tìm điểm bán mới.'),
     const SizedBox(height:6),
     TextField(controller:customerSearch,onChanged:(_)=>setState((){}),
      decoration:const InputDecoration(prefixIcon:Icon(Icons.search),labelText:'Tìm khách/mã khách trong phạm vi đã chọn')),
     const SizedBox(height:8),
     for(final scope in widget.scopes.where((o)=>selected.contains(scopeId(o))))Builder(builder:(_){
      final id=scopeId(scope),rows=available[id]??<Map<String,dynamic>>[];
      final searchText=customerSearch.text.trim().toLowerCase();
      final filteredCustomers=rows.where((c)=>searchText.isEmpty ||
       ('${c['name']} ${c['code']??''} ${c['district']??''}').toLowerCase().contains(searchText)).toList();
      final picked=selectedCustomers[id]??<String>{};
      return Card(child:Padding(padding:const EdgeInsets.all(8),child:Column(
       crossAxisAlignment:CrossAxisAlignment.stretch,children:[
        Text(scope['label'].toString(),style:Theme.of(context).textTheme.titleSmall),
        Text('${rows.length} khách được phép lập lịch · Đã chọn ${picked.length}'),
        if(loadingCandidates.contains(id))const LinearProgressIndicator(minHeight:2),
        if(candidateErrors.containsKey(id))
         Text(candidateErrors[id]!,style:Theme.of(context).textTheme.bodySmall),
        if(!loadingCandidates.contains(id)&&rows.isEmpty)
         const Text('Chưa có khách. Vẫn có thể tạo điểm công tác phát triển thị trường.'),
        if(scope['scope_kind']!='customer'&&filteredCustomers.isNotEmpty)...[
         TextButton(onPressed:()=>setState((){
          selectedCustomers.putIfAbsent(id,()=><String>{})
           .addAll(filteredCustomers.map((c)=>c['id'].toString()));
         }),child:Text('Chọn tất cả ${filteredCustomers.length} khách hiển thị')),
         SizedBox(height:190,child:ListView.builder(
          itemCount:filteredCustomers.length,
          itemBuilder:(ctx,i){
           final c=filteredCustomers[i],cid=c['id'].toString();
           return CheckboxListTile(dense:true,
            controlAffinity:ListTileControlAffinity.leading,
            title:Text(c['name'].toString(),maxLines:1,overflow:TextOverflow.ellipsis),
            subtitle:Text('${c['code']??''} · ${c['district']}, ${c['province']}'),
            value:picked.contains(cid),onChanged:(v)=>setState((){
             final set=selectedCustomers.putIfAbsent(id,()=><String>{});
             if(v==true){set.add(cid);}else{set.remove(cid);}
            }));
          },
         )),
        ],
       ])));
     }),
    ],
    const SizedBox(height:16),
    FilledButton(onPressed:submit,child:Text(widget.original==null?'Lưu lịch + tuyến (${selected.length})':'Lưu thay đổi')),
    const SizedBox(height:24),
   ]),
  );
 }
}
