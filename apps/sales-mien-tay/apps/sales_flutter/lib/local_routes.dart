import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'customers.dart';
import 'offline_queue.dart';
import 'planning_periods.dart';
import 'local_monthly_page.dart';
import 'local_scope_picker.dart';
import 'session.dart';

const localWeekdayNames=['T2','T3','T4','T5','T6','T7','CN'];
List<int> localRuleDays(Map<String,dynamic> rule){
 final values=rule['weekdays'];
 return values is List ? values.whereType<num>().map((v)=>v.toInt()).toList() : [];
}
bool localRuleOccurs(Map<String,dynamic> rule,DateTime date){
 final from=rule['start_on']?.toString().substring(0,10)??'';
 return rule['active']==true&&from.isNotEmpty&&dayKey(date).compareTo(from)>=0&&
  localRuleDays(rule).contains(date.weekday);
}
String localOccurrenceId(String ruleId,DateTime date,String type)=>
 const Uuid().v5(Uuid.NAMESPACE_URL,
  'fbmn:local:'+ruleId+':'+dayKey(date)+':'+type);

/// A recurring day becomes a real work plan only after an explicit user action.
/// This must not invent customer visits or alter an existing monthly plan.
bool hasLocalRouteAlready(List<Map<String,dynamic>> routes,
 Map<String,dynamic> rule,DateTime date,{String? owner}){
 final scopes=localTemplateScopes(rule);
 if(scopes.isEmpty)return false;
 final first=scopes.first,wantedDate=dayKey(date);
 return routes.any((r)=>(owner==null||r['owner_sub']==owner)&&
  r['route_date']?.toString().startsWith(wantedDate)==true&&
  r['scope_kind']==first['scope_kind']&&
  r['scope_key']==first['scope_key']&&
  r['plan_status']!='cancelled');
}
enum LocalCreateResult{created,existing}
Future<LocalCreateResult> createLocalOccurrence({
 required OfflineQueue queue,required CustomerService service,
 required Map<String,dynamic> rule,required DateTime date,
})async{
 final now=DateTime.now().toUtc().add(const Duration(hours:7));
 if(dayKey(date).compareTo(dayKey(now))<0||!localRuleOccurs(rule,date))
  throw StateError('Ngày không thuộc tuyến cố định đang hoạt động');
 final selections=localTemplateScopes(rule);
 if(selections.isEmpty||selections.length>50)
  throw StateError('Tuyến chưa có phạm vi hợp lệ');
 final first=selections.first,dateText=dayKey(date),month=monthKey(date),
  kind=first['scope_kind'].toString(),key=first['scope_key'].toString();
 var existing=await queue.cached('monthly-plans:'+month);
 try{
  final uri=service.uri('/api/v1/monthly-plans',{'month':month});
  final response=(service.client?.get(uri,headers:service.headers)??
   http.get(uri,headers:service.headers)).timeout(const Duration(seconds:15));
  final result=decodeApi(await response);
  existing=(result['items'] as List).map((e)=>Map<String,dynamic>.from(e as Map)).toList();
  await queue.cache('monthly-plans:'+month,existing);
 }on ApiFailure catch(e){if(e.status==401||e.status==403)rethrow;}
 catch(_){/* Replay verifies scopes; no fake success while offline. */}
 final inPlan=existing.any((p)=>p['owner_sub']==queue.identity&&
  p['status']=='planned'&&p['work_date'].toString().startsWith(dateText)&&
  p['scope_kind']==kind&&p['scope_key']==key);
 final inQueue=queue.pending.any((p)=>p['path']=='/api/v1/monthly-plans'&&
  (p['payload'] as Map?)?['status']=='planned'&&
  (p['payload'] as Map?)?['work_date']==dateText&&
  (p['payload'] as Map?)?['scope_kind']==kind&&
  (p['payload'] as Map?)?['scope_key']==key);
 if(inPlan||inQueue)return LocalCreateResult.existing;
 final id=rule['id'].toString(),purpose=rule['name'].toString();
 final planId=localOccurrenceId(id,date,'plan');
 final routeId=localOccurrenceId(id,date,'route');
 final tripId=localOccurrenceId(id,date,'trip');
 final note='Từ tuyến cố định '+id;
 final tripScopes=selections.map((s)=><String,dynamic>{
  'scope_kind':s['scope_kind'],'scope_key':s['scope_key'],
  'province':s['province'],'district':s['district'],
 }).toList();
 await queue.enqueueTripGraph(
  plan:{'client_ref':planId,'period_ym':month,'work_date':dateText,
   'scope_kind':kind,'scope_key':key,
   'province':first['province'],'district':first['district'],
   'purpose':purpose,'target_new_customers':0,'note':note,'status':'planned'},
  route:{'client_ref':routeId,'monthly_plan_id':planId,'route_date':dateText,
   'purpose':purpose,'note':note,'status':'ready'},
  trip:{'client_ref':tripId,'mutation_ref':tripId,'day_route_id':routeId,
   'start_date':dateText,'end_date':dateText,'purpose':purpose,'note':note,
   'scopes':tripScopes,'priorities':<String>[]},
 );
 return LocalCreateResult.created;
}

class FixedLocalRoutesPage extends StatefulWidget{
 final OfflineQueue queue;
 final CustomerService service;
 const FixedLocalRoutesPage({super.key,required this.queue,required this.service});
 @override State<FixedLocalRoutesPage> createState()=>_FixedLocalRoutesPageState();
}
class _FixedLocalRoutesPageState extends State<FixedLocalRoutesPage>{
 List<Map<String,dynamic>> rules=[],scopes=[];
 bool busy=false,offline=false;
 String? error;
 String get cacheKey=>'local-routes:'+widget.queue.revision;
 @override void initState(){super.initState();widget.queue.addListener(_changed);unawaited(_load());}
 @override void dispose(){widget.queue.removeListener(_changed);super.dispose();}
 void _changed(){if(mounted)setState((){});}
 void _toast(String s){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(s)));}
 Future<http.Response> _get(Uri uri)=>(
  widget.service.client?.get(uri,headers:widget.service.headers)??
  http.get(uri,headers:widget.service.headers)).timeout(const Duration(seconds:15));
 Future<void> _load()async{
  if(busy)return;
  setState((){busy=true;error=null;});
  try{
   final snapshot=await widget.queue.cached(cacheKey);
   final savedScopes=await widget.queue.cached('monthly-plan-scopes');
   if(mounted)setState((){
    rules=snapshot;
    scopes=savedScopes;
    offline=true;
   });
  }catch(_){}
  try{
   final result=decodeApi(await _get(widget.service.uri('/api/v1/local-routes')));
   final list=(result['items'] as List).map((e)=>Map<String,dynamic>.from(e as Map)).toList();
   await widget.queue.cache(cacheKey,list);
   if(mounted)setState((){rules=list;offline=false;});
  }catch(e){
   if(e is ApiFailure&&(e.status==401||e.status==403)&&mounted)
    setState((){rules=[];offline=false;});
   if(mounted)setState(()=>error='Tuyến cố định: $e');
  }
  try{
   final result=decodeApi(await _get(widget.service.uri('/api/v1/monthly-plans/options')));
   final list=(result['scopes'] as List).map((e)=>Map<String,dynamic>.from(e as Map)).toList();
   await widget.queue.cache('monthly-plan-scopes',list);
   if(mounted)setState(()=>scopes=list);
  }catch(e){
   if(e is ApiFailure&&(e.status==401||e.status==403)&&mounted)setState(()=>scopes=[]);
  }
  if(mounted)setState(()=>busy=false);
 }
 List<Map<String,dynamic>> get shown{
  final byId=<String,Map<String,dynamic>>{
   for(final rule in rules)rule['id'].toString():{...rule}
  };
  for(final op in widget.queue.pending){
   final path=op['path']?.toString()??'';
   if(op['payload'] is! Map)continue;
   final data=Map<String,dynamic>.from(op['payload'] as Map);
   if(path=='/api/v1/local-routes'&&op['method']=='POST'){
    final id=data['client_ref']?.toString()??'';
    if(id.isNotEmpty)byId[id]={...data,'id':id,'version':0,'_pending':true};
   }else if(path.startsWith('/api/v1/local-routes/')&&op['method']=='PATCH'){
    final id=path.substring('/api/v1/local-routes/'.length);
    if(byId.containsKey(id))byId[id]={...byId[id]!,...data,'id':id,'_pending':true};
   }
  }
  return byId.values.toList()..sort((a,b)=>
   (a['name']?.toString()??'').compareTo(b['name']?.toString()??''));
 }
 bool _pending(Map<String,dynamic> rule){
  final id=rule['id']?.toString()??'';
  return rule['_pending']==true||widget.queue.pending.any((op)=>
   op['path']=='/api/v1/local-routes/'+id||
   (op['path']=='/api/v1/local-routes'&&(op['payload'] as Map?)?['client_ref']==id));
 }
 String _place(Map<String,dynamic> rule)=>
  localScopeSummary(localTemplateScopes(rule));
 String _days(Map<String,dynamic> rule)=>localRuleDays(rule)
   .where((d)=>d>=1&&d<=7).map((d)=>localWeekdayNames[d-1]).join(', ');
 Future<void> _edit([Map<String,dynamic>? original])async{
  if(original!=null&&_pending(original)){
   _toast('Đang chờ đồng bộ; chưa thể sửa đè.');return;
  }
  if(scopes.isEmpty){_toast('Chưa có địa bàn hợp lệ; cần cập nhật quyền.');return;}
  final draft=await Navigator.push<Map<String,dynamic>>(context,MaterialPageRoute(
   builder:(_)=>_LocalRuleEditor(scopes:scopes,original:original)));
  if(draft==null||!mounted)return;
  final editing=original!=null;
  final id=editing?original['id'].toString():const Uuid().v4();
  try{
   await widget.queue.enqueue(editing?'/api/v1/local-routes/'+id:'/api/v1/local-routes',{
    ...draft,'client_ref':editing?const Uuid().v4():id,
    if(editing)'version':original['version'],
   },method:editing?'PATCH':'POST');
   _toast('Đã lưu tuyến cố định trên máy · chờ đồng bộ');
  }catch(e){_toast('Không lưu được: $e');}
 }
 Future<void> _toggle(Map<String,dynamic> r)async{
  if(_pending(r))return;
  try{
   await widget.queue.enqueue('/api/v1/local-routes/'+r['id'].toString(),{
    'client_ref':const Uuid().v4(),'name':r['name'],'mode':r['mode'],
    'weekdays':localRuleDays(r),'province':r['province'],'district':r['district'],
    'scopes':localTemplateScopes(r),
    'start_on':r['start_on'].toString().substring(0,10),
    'active':r['active']!=true,'version':r['version'],
   },method:'PATCH');
   _toast('Đã lưu thay đổi · chờ đồng bộ');
  }catch(e){_toast('Không thay đổi được: $e');}
 }
 Future<void> _monthly()async{
  final selected=await Navigator.push<DateTime>(context,MaterialPageRoute(
   builder:(_)=>FixedMonthPage(queue:widget.queue,service:widget.service)));
  if(selected!=null&&mounted)Navigator.pop(context,selected);
 }
 @override Widget build(BuildContext context){
  final records=shown;
  return Scaffold(
   appBar:AppBar(title:const Text('Tuyến cố định · Sales Local'),
    actions:[IconButton(icon:const Icon(Icons.refresh),tooltip:'Tải lại',
     onPressed:busy?null:_load)]),
   floatingActionButton:FloatingActionButton.extended(
    onPressed:scopes.isEmpty?null:()=>_edit(),
    icon:const Icon(Icons.add),label:const Text('Thêm tuyến')),
   body:ListView(padding:const EdgeInsets.fromLTRB(12,12,12,95),children:[
    const Text('Lặp theo thứ hàng tuần. Mỗi tuyến được chọn nhiều địa bàn, khách hoặc chuỗi. '
     'Kế hoạch tháng và kết quả đã ghi không bị thay đổi.'),
    if(busy)const LinearProgressIndicator(minHeight:2),
    if(offline)const Text('Đang xem dữ liệu lưu trên máy; thay đổi chờ đồng bộ.'),
    if(error!=null)Text(error!,style:TextStyle(color:Theme.of(context).colorScheme.error)),
    OutlinedButton.icon(
     onPressed:_monthly,icon:const Icon(Icons.calendar_month_outlined),
     label:const Text('Tuyến theo tuần 1–5 của tháng')),
    const SizedBox(height:10),
    const SizedBox(height:14),
    Text('Tuyến đã thiết lập',style:Theme.of(context).textTheme.titleMedium),
    if(records.isEmpty)const Padding(padding:EdgeInsets.all(10),
     child:Text('Chưa có tuyến cố định.')),
    for(final r in records)Card(child:Column(children:[
     ListTile(
      leading:Icon(r['active']==true?Icons.repeat:Icons.pause_circle_outline),
      title:Text(r['name']?.toString()??''),
      subtitle:Text(_place(r)+'\nLặp: '+_days(r)+
       (r['active']==true?'':' · Đã tạm dừng')+
       (_pending(r)?' · Chờ đồng bộ':'')),
      isThreeLine:true),
     Wrap(alignment:WrapAlignment.end,spacing:8,children:[
      TextButton.icon(onPressed:_pending(r)?null:()=>_edit(r),
       icon:const Icon(Icons.edit_outlined),label:const Text('Sửa')),
      TextButton.icon(onPressed:_pending(r)?null:()=>_toggle(r),
       icon:Icon(r['active']==true?Icons.pause_outlined:Icons.play_arrow_outlined),
       label:Text(r['active']==true?'Tạm dừng':'Bật lại')),
     ]),
    ])),
    const SizedBox(height:16),
    Text('Tuyến lặp theo thứ hằng tuần',
     style:Theme.of(context).textTheme.titleMedium),
    const Text('Thiết lập một lần, tự lặp mỗi tuần. Ngày đi thực tế nằm ở Công tác → Hôm nay.'),
    for(var i=0;i<7;i++)Card(child:Column(
     crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      Padding(padding:const EdgeInsets.fromLTRB(12,10,12,6),
       child:Text(localWeekdayNames[i],
        style:Theme.of(context).textTheme.titleSmall)),
      if(!records.any((r)=>r['active']==true&&localRuleDays(r).contains(i+1)))
       const Padding(padding:EdgeInsets.fromLTRB(12,0,12,10),
        child:Text('Chưa có tuyến cố định')),
      for(final r in records.where((r)=>
       r['active']==true&&localRuleDays(r).contains(i+1)))
       ListTile(dense:true,title:Text(r['name'].toString()),subtitle:Text(_place(r))),
     ])),
   ]),
  );
 }
}

class _LocalRuleEditor extends StatefulWidget{
 final List<Map<String,dynamic>> scopes;
 final Map<String,dynamic>? original;
 const _LocalRuleEditor({required this.scopes,this.original});
 @override State<_LocalRuleEditor> createState()=>_LocalRuleEditorState();
}
class _LocalRuleEditorState extends State<_LocalRuleEditor>{
 late final TextEditingController name;
 List<Map<String,dynamic>> selectedScopes=[];
 late Set<int> days;
 late bool active;
 @override void initState(){
  super.initState();
  final r=widget.original;
  name=TextEditingController(text:r?['name']?.toString()??'');
  days=r==null?{DateTime.now().weekday}:localRuleDays(r).toSet();
  if(days.isEmpty)days={DateTime.now().weekday};
  active=r?['active']!=false;
  if(r!=null)selectedScopes=localTemplateScopes(r);
 }
 @override void dispose(){name.dispose();super.dispose();}
 Future<void> _chooseScope()async{
  final picked=await pickLocalScopes(
   context:context,options:widget.scopes,initial:selectedScopes);
  if(picked!=null&&mounted)setState(()=>selectedScopes=picked);
 }
 void _save(){
  if(name.text.trim().length<2||name.text.length>120||selectedScopes.isEmpty||days.isEmpty){
   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
    content:Text('Nhập tên, chọn phạm vi và ít nhất một thứ trong tuần.')));return;
  }
  Navigator.pop(context,<String,dynamic>{
   'name':name.text.trim(),'mode':days.length==1?'day':'week',
   'weekdays':days.toList()..sort(),
   'scopes':selectedScopes,'province':selectedScopes.first['province'],
   'district':selectedScopes.first['district']??'',
   'start_on':widget.original?['start_on']?.toString().substring(0,10)??'2020-01-01',
   'active':active,
  });
 }
 @override Widget build(BuildContext context)=>Scaffold(
  appBar:AppBar(title:Text(widget.original==null?'Thêm tuyến cố định':'Sửa tuyến cố định')),
  bottomNavigationBar:SafeArea(child:Padding(padding:const EdgeInsets.all(12),
   child:FilledButton.icon(onPressed:_save,
    icon:const Icon(Icons.save_outlined),label:const Text('Lưu tuyến')))),
  body:ListView(padding:const EdgeInsets.all(14),children:[
   TextField(controller:name,maxLength:120,
    decoration:const InputDecoration(labelText:'Tên tuyến',
     hintText:'Ví dụ: Thứ Hai · Ninh Kiều')),
   OutlinedButton.icon(onPressed:_chooseScope,
    icon:const Icon(Icons.location_on_outlined),
    label:Text(localScopeSummary(selectedScopes))),
   if(selectedScopes.isNotEmpty)Padding(
    padding:const EdgeInsets.only(top:8),
    child:Wrap(spacing:5,runSpacing:4,children:[
     for(final scope in selectedScopes)Chip(
      label:Text(localScopeLabel(scope)),
      onDeleted:()=>setState(()=>selectedScopes.removeWhere((s)=>
       localScopeFingerprint(s)==localScopeFingerprint(scope))),
     ),
    ])),
   const SizedBox(height:16),
   Text('Chọn các thứ lặp hằng tuần',
    style:Theme.of(context).textTheme.titleMedium),
   const Text('Chọn một hoặc nhiều thứ. Không cần thiết lập ngày, lịch tự lặp hàng tuần.'),
   const SizedBox(height:10),
   Wrap(spacing:6,runSpacing:6,children:[
    for(var d=1;d<=7;d++)FilterChip(
     label:Text(localWeekdayNames[d-1]),selected:days.contains(d),
     onSelected:(chosen)=>setState((){
      if(chosen)days.add(d);
      else if(days.length>1)days.remove(d);
     })),
   ]),
   SwitchListTile(contentPadding:EdgeInsets.zero,value:active,
    title:const Text('Đang hoạt động'),
    onChanged:(v)=>setState(()=>active=v)),
   const Text('Sửa hoặc tạm dừng chỉ ảnh hưởng lịch chưa tạo. '
    'Lịch công tác và khảo sát đã thực hiện được giữ nguyên.'),
  ]),
 );
}
