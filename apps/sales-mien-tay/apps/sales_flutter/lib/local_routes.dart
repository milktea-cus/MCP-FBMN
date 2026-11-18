import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'customers.dart';
import 'offline_queue.dart';
import 'planning_periods.dart';
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

class FixedLocalRoutesPage extends StatefulWidget{
 final OfflineQueue queue;
 final CustomerService service;
 const FixedLocalRoutesPage({super.key,required this.queue,required this.service});
 @override State<FixedLocalRoutesPage> createState()=>_FixedLocalRoutesPageState();
}
class _FixedLocalRoutesPageState extends State<FixedLocalRoutesPage>{
 List<Map<String,dynamic>> rules=[],scopes=[];
 DateTime week=weekMonday(DateTime.now());
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
    scopes=savedScopes.where((s)=>s['scope_kind']=='territory').toList();
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
   if(mounted)setState(()=>scopes=list.where((s)=>s['scope_kind']=='territory').toList());
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
 String _place(Map<String,dynamic> rule){
  final district=rule['district']?.toString()??'';
  return (district.isEmpty?'Toàn tỉnh':district)+' · '+rule['province'].toString();
 }
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
    'start_on':r['start_on'].toString().substring(0,10),
    'active':r['active']!=true,'version':r['version'],
   },method:'PATCH');
   _toast('Đã lưu thay đổi · chờ đồng bộ');
  }catch(e){_toast('Không thay đổi được: $e');}
 }
 Future<void> _schedule(Map<String,dynamic> rule,DateTime date)async{
  final now=DateTime.now().toUtc().add(const Duration(hours:7));
  if(dayKey(date).compareTo(dayKey(now))<0||!localRuleOccurs(rule,date))return;
  final textDate=dayKey(date),month=monthKey(date);
  final province=rule['province'].toString(),district=rule['district']?.toString()??'';
  final scopeKey=province+'|'+district;
  try{
   var existing=await widget.queue.cached('monthly-plans:'+month);
   try{
    final r=decodeApi(await _get(widget.service.uri('/api/v1/monthly-plans',{'month':month})));
    existing=(r['items'] as List).map((e)=>Map<String,dynamic>.from(e as Map)).toList();
    await widget.queue.cache('monthly-plans:'+month,existing);
   }on ApiFailure catch(e){if(e.status==401||e.status==403)rethrow;}
   catch(_){/* Offline changes remain durable. Server will reject conflicting dates. */}
   final inPlan=existing.any((p)=>p['status']=='planned'&&
    p['work_date'].toString().startsWith(textDate)&&p['scope_key']==scopeKey);
   final inQueue=widget.queue.pending.any((p)=>p['path']=='/api/v1/monthly-plans'&&
    (p['payload'] as Map?)?['work_date']==textDate&&
    (p['payload'] as Map?)?['scope_key']==scopeKey);
   if(inPlan||inQueue){
    _toast('Ngày/địa bàn này đã có kế hoạch. Dùng tuyến sẵn có, không tạo trùng.');return;
   }
   final id=rule['id'].toString(),purpose=rule['name'].toString();
   final planId=localOccurrenceId(id,date,'plan');
   final routeId=localOccurrenceId(id,date,'route');
   final tripId=localOccurrenceId(id,date,'trip');
   final note='Từ tuyến cố định '+id;
   await widget.queue.enqueueTripGraph(
    plan:{'client_ref':planId,'period_ym':month,'work_date':textDate,
     'scope_kind':'territory','scope_key':scopeKey,'province':province,
     'district':district,'purpose':purpose,'target_new_customers':0,
     'note':note,'status':'planned'},
    route:{'client_ref':routeId,'monthly_plan_id':planId,'route_date':textDate,
     'purpose':purpose,'note':note,'status':'ready'},
    trip:{'client_ref':tripId,'mutation_ref':tripId,'day_route_id':routeId,
     'start_date':textDate,'end_date':textDate,'purpose':purpose,'note':note,
     'scopes':[{'scope_kind':'territory','scope_key':scopeKey,
      'province':province,'district':district}],
     'priorities':<String>[]},
   );
   if(mounted)Navigator.pop(context,date);
  }catch(e){_toast('Không tạo được tuyến ngày: $e');}
 }
 @override Widget build(BuildContext context){
  final records=shown;
  final today=DateTime.now().toUtc().add(const Duration(hours:7));
  return Scaffold(
   appBar:AppBar(title:const Text('Tuyến cố định · Sales Local'),
    actions:[IconButton(icon:const Icon(Icons.refresh),tooltip:'Tải lại',
     onPressed:busy?null:_load)]),
   floatingActionButton:FloatingActionButton.extended(
    onPressed:scopes.isEmpty?null:()=>_edit(),
    icon:const Icon(Icons.add),label:const Text('Thêm tuyến')),
   body:ListView(padding:const EdgeInsets.fromLTRB(12,12,12,95),children:[
    const Text('Lặp theo thứ hàng tuần. Mỗi địa bàn có thể có tuyến riêng. '
     'Kế hoạch tháng và kết quả đã ghi không bị thay đổi.'),
    if(busy)const LinearProgressIndicator(minHeight:2),
    if(offline)const Text('Đang xem dữ liệu lưu trên máy; thay đổi chờ đồng bộ.'),
    if(error!=null)Text(error!,style:TextStyle(color:Theme.of(context).colorScheme.error)),
    const SizedBox(height:14),
    Text('Tuyến đã thiết lập',style:Theme.of(context).textTheme.titleMedium),
    if(records.isEmpty)const Padding(padding:EdgeInsets.all(10),
     child:Text('Chưa có tuyến cố định.')),
    for(final r in records)Card(child:Column(children:[
     ListTile(
      leading:Icon(r['active']==true?Icons.repeat:Icons.pause_circle_outline),
      title:Text(r['name']?.toString()??''),
      subtitle:Text(_place(r)+'\n'+_days(r)+' · từ '+
       (r['start_on']?.toString().substring(0,10)??'')+
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
    Row(children:[
     Expanded(child:Text('Lịch tuyến theo tuần',
      style:Theme.of(context).textTheme.titleMedium)),
     IconButton(onPressed:()=>setState(()=>
      week=week.subtract(const Duration(days:7))),
      icon:const Icon(Icons.chevron_left),tooltip:'Tuần trước'),
     IconButton(onPressed:()=>setState(()=>
      week=week.add(const Duration(days:7))),
      icon:const Icon(Icons.chevron_right),tooltip:'Tuần sau'),
    ]),
    Text(dayKey(week)+' – '+dayKey(week.add(const Duration(days:6)))),
    for(var i=0;i<7;i++)Builder(builder:(context){
     final date=week.add(Duration(days:i));
     final matches=records.where((r)=>localRuleOccurs(r,date)).toList();
     return Card(child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      Padding(padding:const EdgeInsets.fromLTRB(12,10,12,6),
       child:Text(localWeekdayNames[i]+' · '+dayKey(date)+
        (dayKey(date)==dayKey(today)?' · Hôm nay':''),
        style:Theme.of(context).textTheme.titleSmall)),
      if(matches.isEmpty)const Padding(padding:EdgeInsets.fromLTRB(12,0,12,10),
       child:Text('Không có tuyến cố định')),
      for(final r in matches)ListTile(dense:true,
       title:Text(r['name'].toString()),subtitle:Text(_place(r)),
       trailing:TextButton(
        onPressed:dayKey(date).compareTo(dayKey(today))<0?null:
         ()=>_schedule(r,date),
        child:const Text('Lập lịch ngày'))),
     ]));
    }),
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
 Map<String,dynamic>? scope;
 late Set<int> days;
 late String mode;
 late DateTime start;
 late bool active;
 @override void initState(){
  super.initState();
  final r=widget.original;
  name=TextEditingController(text:r?['name']?.toString()??'');
  mode=r?['mode']?.toString()??'day';
  days=r==null?{DateTime.now().weekday}:localRuleDays(r).toSet();
  if(days.isEmpty)days={DateTime.now().weekday};
  start=DateTime.tryParse(r?['start_on']?.toString()??'')??DateTime.now();
  active=r?['active']!=false;
  for(final s in widget.scopes){
   if(r!=null&&s['province']==r['province']&&s['district']==r['district']){
    scope=s;break;
   }
  }
 }
 @override void dispose(){name.dispose();super.dispose();}
 Future<void> _chooseScope()async{
  String query='';
  final selected=await showModalBottomSheet<Map<String,dynamic>>(
   context:context,isScrollControlled:true,builder:(sheet)=>SafeArea(
    child:StatefulBuilder(builder:(ctx,refresh)=>SizedBox(
     height:MediaQuery.sizeOf(sheet).height*0.70,child:Column(children:[
      const Padding(padding:EdgeInsets.all(12),child:Text('Chọn địa bàn được giao')),
      Padding(padding:const EdgeInsets.symmetric(horizontal:12),
       child:TextField(autofocus:true,decoration:const InputDecoration(
        prefixIcon:Icon(Icons.search),hintText:'Tìm tỉnh/huyện'),
        onChanged:(s)=>refresh(()=>query=s.toLowerCase()))),
      Expanded(child:Builder(builder:(context){
       final found=widget.scopes.where((s)=>
        (s['label']?.toString()??'').toLowerCase().contains(query)).toList();
       return ListView.builder(itemCount:found.length,
        itemBuilder:(ctx,i)=>ListTile(title:Text(found[i]['label'].toString()),
         onTap:()=>Navigator.pop(sheet,found[i])));
      })),
     ]),
    ))));
  if(selected!=null&&mounted)setState(()=>scope=selected);
 }
 void _save(){
  if(name.text.trim().length<2||name.text.length>120||scope==null||days.isEmpty){
   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
    content:Text('Nhập tên, địa bàn và ít nhất một thứ trong tuần.')));return;
  }
  Navigator.pop(context,<String,dynamic>{
   'name':name.text.trim(),'mode':mode,'weekdays':days.toList()..sort(),
   'province':scope!['province'],'district':scope!['district']??'',
   'start_on':dayKey(start),'active':active,
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
    label:Text(scope?['label']?.toString()??'Chọn tỉnh/huyện')),
   const SizedBox(height:16),
   Text('Kiểu lặp',style:Theme.of(context).textTheme.titleMedium),
   Wrap(spacing:8,children:[
    ChoiceChip(label:const Text('Theo ngày'),selected:mode=='day',
     onSelected:(_)=>setState((){mode='day';days={days.first};})),
    ChoiceChip(label:const Text('Theo tuần'),selected:mode=='week',
     onSelected:(_)=>setState(()=>mode='week')),
   ]),
   const Text('Theo ngày: chọn một thứ, tự lặp hàng tuần. '
    'Theo tuần: chọn nhiều thứ cùng một địa bàn. '
    'Địa bàn khác thì tạo tuyến khác.'),
   const SizedBox(height:10),
   Wrap(spacing:6,runSpacing:6,children:[
    for(var d=1;d<=7;d++)FilterChip(
     label:Text(localWeekdayNames[d-1]),selected:days.contains(d),
     onSelected:(chosen)=>setState((){
      if(mode=='day')days={d};
      else if(chosen)days.add(d);
      else if(days.length>1)days.remove(d);
     })),
   ]),
   const SizedBox(height:16),
   OutlinedButton.icon(onPressed:()async{
    final date=await showDatePicker(context:context,initialDate:start,
     firstDate:DateTime(2020),lastDate:DateTime(2099));
    if(date!=null&&mounted)setState(()=>start=date);
   },icon:const Icon(Icons.event_outlined),
    label:Text('Áp dụng từ: '+dayKey(start))),
   SwitchListTile(contentPadding:EdgeInsets.zero,value:active,
    title:const Text('Đang hoạt động'),
    onChanged:(v)=>setState(()=>active=v)),
   const Text('Sửa hoặc tạm dừng chỉ ảnh hưởng lịch chưa tạo. '
    'Lịch công tác và khảo sát đã thực hiện được giữ nguyên.'),
  ]),
 );
}
