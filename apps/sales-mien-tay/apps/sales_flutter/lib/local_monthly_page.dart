import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'customers.dart';
import 'offline_queue.dart';
import 'planning_periods.dart';
import 'session.dart';
import 'local_monthly_core.dart';

class FixedMonthPage extends StatefulWidget{
 final OfflineQueue queue;
 final CustomerService service;
 const FixedMonthPage({super.key,required this.queue,required this.service});
 @override State<FixedMonthPage> createState()=>_FixedMonthPageState();
}
class _FixedMonthPageState extends State<FixedMonthPage>{
 DateTime month=DateTime(DateTime.now().year,DateTime.now().month);
 List<Map<String,dynamic>> rows=[],scopes=[];
 bool loading=false,fromCache=false;
 String? error;
 String get cacheKey=>'local-monthly-routes:'+monthKey(month);
 @override void initState(){
  super.initState();widget.queue.addListener(_changed);unawaited(load());
 }
 @override void dispose(){widget.queue.removeListener(_changed);super.dispose();}
 void _changed(){if(mounted)setState((){});}
 void notify(String s){if(mounted)ScaffoldMessenger.of(context)
  .showSnackBar(SnackBar(content:Text(s)));}
 Future<Map<String,dynamic>> fetch(String path,[Map<String,String>? params])async{
  final uri=widget.service.uri(path,params);
  return decodeApi(await (widget.service.client?.get(uri,headers:widget.service.headers)??
   http.get(uri,headers:widget.service.headers)).timeout(const Duration(seconds:20)));
 }
 Future<void> load()async{
  if(loading)return;
  setState((){loading=true;error=null;});
  try{
   final saved=await widget.queue.cached(cacheKey);
   final options=await widget.queue.cached('monthly-plan-scopes');
   if(mounted)setState((){rows=saved;scopes=options;fromCache=true;});
  }catch(_){}
  try{
   final result=await fetch('/api/v1/local-monthly-routes',{'month':monthKey(month)});
   final items=(result['items'] as List).map((x)=>Map<String,dynamic>.from(x as Map)).toList();
   await widget.queue.cache(cacheKey,items);
   if(mounted)setState((){rows=items;fromCache=false;});
  }catch(e){
   if(e is ApiFailure&&(e.status==401||e.status==403)&&mounted){
    setState((){rows=[];fromCache=false;});
   }
   if(mounted)setState(()=>error=e.toString());
  }
  try{
   final result=await fetch('/api/v1/monthly-plans/options');
   final items=(result['scopes'] as List)
    .map((x)=>Map<String,dynamic>.from(x as Map)).toList();
   await widget.queue.cache('monthly-plan-scopes',items);
   if(mounted)setState(()=>scopes=items);
  }catch(e){
   if(e is ApiFailure&&(e.status==401||e.status==403)&&mounted)setState(()=>scopes=[]);
  }
  if(mounted)setState(()=>loading=false);
 }
 List<Map<String,dynamic>> get shown{
  final byId=<String,Map<String,dynamic>>{
   for(final r in rows)r['id'].toString():{...r}
  };
  for(final op in widget.queue.pending){
   final path=op['path']?.toString()??'';
   if(op['payload'] is! Map)continue;
   final value=Map<String,dynamic>.from(op['payload'] as Map);
   if(path=='/api/v1/local-monthly-routes'&&op['method']=='POST'){
    final id=value['client_ref']?.toString()??'';
    if(id.isNotEmpty)byId[id]={...value,'id':id,'version':0,'_pending':true};
   }else if(path.startsWith('/api/v1/local-monthly-routes/')&&op['method']=='PATCH'){
    final id=path.substring('/api/v1/local-monthly-routes/'.length);
    if(byId.containsKey(id))byId[id]={...byId[id]!,...value,'id':id,'_pending':true};
   }
  }
  return byId.values.toList();
 }
 bool pending(Map<String,dynamic> r){
  final id=r['id'].toString();
  return r['_pending']==true||widget.queue.pending.any((op)=>
   op['path']=='/api/v1/local-monthly-routes/'+id||
   (op['path']=='/api/v1/local-monthly-routes'&&
    (op['payload'] as Map?)?['client_ref']==id));
 }
 Future<void> edit([Map<String,dynamic>? original])async{
  if(original!=null&&pending(original)){notify('Đang chờ đồng bộ; không sửa chồng.');return;}
  if(scopes.isEmpty){notify('Chưa có địa bàn, khách hoặc chuỗi được giao.');return;}
  final draft=await Navigator.push<Map<String,dynamic>>(context,MaterialPageRoute(
   builder:(_)=>_FixedMonthEditor(scopes:scopes,original:original)));
  if(draft==null||!mounted)return;
  final editing=original!=null;
  final id=editing?original['id'].toString():const Uuid().v4();
  try{
   await widget.queue.enqueue(
    editing?'/api/v1/local-monthly-routes/'+id:'/api/v1/local-monthly-routes',{
     ...draft,'client_ref':editing?const Uuid().v4():id,
     if(editing)'version':original['version'],
    },method:editing?'PATCH':'POST');
   notify('Đã lưu phân công cố định trên máy · chờ đồng bộ');
  }catch(e){notify('Không lưu được: '+e.toString());}
 }
 Future<void> toggle(Map<String,dynamic> r)async{
  if(pending(r))return;
  try{
   await widget.queue.enqueue('/api/v1/local-monthly-routes/'+r['id'].toString(),{
    'client_ref':const Uuid().v4(),'version':r['version'],
    'name':r['name'],'week_no':r['week_no'],'scope_kind':r['scope_kind'],
    'scope_key':r['scope_key'],'scope_label':r['scope_label'],
    'province':r['province'],'district':r['district'],
    'active':r['active']!=true,
   },method:'PATCH');
   notify('Đã lưu trạng thái · chờ đồng bộ');
  }catch(e){notify('Không đổi được trạng thái: '+e.toString());}
 }
 Future<void> plan(Map<String,dynamic> r)async{
  final dates=fixedMonthDays(month,(r['week_no'] as num).toInt());
  if(dates.isEmpty)return;
  final now=DateTime.now().toUtc().add(const Duration(hours:7));
  final today=DateTime(now.year,now.month,now.day);
  final first=dates.first.isBefore(today)?today:dates.first;
  if(first.isAfter(dates.last)){notify('Tuần đã kết thúc.');return;}
  final day=await showDatePicker(context:context,initialDate:first,
   firstDate:first,lastDate:dates.last,helpText:'Chọn ngày đi trong tuần được giao');
  if(day==null||!mounted)return;
  try{
   final result=await materializeFixedMonth(
    queue:widget.queue,service:widget.service,rule:r,date:day);
   if(!mounted)return;
   if(result==FixedMonthResult.existing){
    notify('Ngày này đã có lịch cùng phạm vi. Mở Kế hoạch để tiếp tục.');
   }else{
    Navigator.pop(context,day);
   }
  }catch(e){notify('Không lập được ngày đi: '+e.toString());}
 }
 String progress(Map<String,dynamic> r){
  if(r['active']!=true)return 'Đã tạm dừng';
  final p=r['progress'];
  if(p is! Map)return 'Kết quả đang chờ đồng bộ';
  final total=(p['customers_total'] as num?)?.toInt()??0,
   visited=(p['customers_visited'] as num?)?.toInt()??0,
   plans=(p['plan_count'] as num?)?.toInt()??0;
  if(total==0)return 'Chưa có khách được giao · '+plans.toString()+' lịch';
  return visited.toString()+'/'+total.toString()+' khách đã ghé · '+
   plans.toString()+' lịch'+(visited>=total?' · Đủ lượt ghé':'');
 }
 void changeMonth(int delta){
  setState(()=>month=DateTime(month.year,month.month+delta,1));
  unawaited(load());
 }
 @override Widget build(BuildContext context){
  final all=shown;
  return Scaffold(
   appBar:AppBar(title:const Text('Tuyến cố định · Theo tháng'),
    actions:[IconButton(icon:const Icon(Icons.refresh),tooltip:'Tải lại',
     onPressed:loading?null:load)]),
   floatingActionButton:FloatingActionButton.extended(
    onPressed:scopes.isEmpty?null:()=>edit(),
    icon:const Icon(Icons.add),label:const Text('Thêm phân công')),
   body:ListView(padding:const EdgeInsets.fromLTRB(12,12,12,100),children:[
    const Text('Tuần 1–5 lặp lại mỗi tháng. Mỗi tuần có thể giao nhiều tỉnh/huyện, '
     'khách hoặc chuỗi. Sales tự chọn ngày đi trong tuần, có thể chia nhiều ngày.'),
    Row(children:[
     IconButton(icon:const Icon(Icons.chevron_left),tooltip:'Tháng trước',
      onPressed:loading?null:()=>changeMonth(-1)),
     Expanded(child:Text('Tháng '+month.month.toString().padLeft(2,'0')+
      '/'+month.year.toString(),textAlign:TextAlign.center,
      style:Theme.of(context).textTheme.titleMedium)),
     IconButton(icon:const Icon(Icons.chevron_right),tooltip:'Tháng sau',
      onPressed:loading?null:()=>changeMonth(1)),
    ]),
    if(loading)const LinearProgressIndicator(minHeight:2),
    if(fromCache)const Text('Dữ liệu đã lưu trên máy; kết quả chờ xác minh'),
    if(error!=null)Text(error!,style:TextStyle(color:Theme.of(context).colorScheme.error)),
    for(var week=1;week<=5;week++)...[
     const SizedBox(height:12),
     Text('Tuần '+week.toString(),style:Theme.of(context).textTheme.titleMedium),
     if(fixedMonthDays(month,week).isEmpty)const Padding(
      padding:EdgeInsets.all(8),child:Text('Tháng này không có Tuần 5')),
     if(fixedMonthDays(month,week).isNotEmpty)...[
      Text(dayKey(fixedMonthDays(month,week).first)+' – '+
       dayKey(fixedMonthDays(month,week).last)),
      if(!all.any((r)=>(r['week_no'] as num?)?.toInt()==week))
       const Padding(padding:EdgeInsets.all(8),child:Text('Chưa có phân công')),
      for(final r in all.where((x)=>(x['week_no'] as num?)?.toInt()==week))
       Card(child:Column(children:[
        ListTile(
         leading:const Icon(Icons.event_repeat_outlined),
         title:Text(r['name']?.toString()??''),
         subtitle:Text((r['scope_label']??r['scope_key']).toString()+
          '\n'+progress(r)+(pending(r)?'\nChờ đồng bộ':'')),
         isThreeLine:true),
        Wrap(alignment:WrapAlignment.end,spacing:6,children:[
         TextButton(onPressed:pending(r)?null:()=>edit(r),
          child:const Text('Sửa')),
         TextButton(onPressed:pending(r)?null:()=>toggle(r),
          child:Text(r['active']==true?'Tạm dừng':'Bật lại')),
         if(r['active']==true)TextButton.icon(
          icon:const Icon(Icons.event_available_outlined),
          onPressed:pending(r)?null:()=>plan(r),label:const Text('Lập ngày đi')),
        ]),
       ])),
     ],
    ],
   ]),
  );
 }
}

class _FixedMonthEditor extends StatefulWidget{
 final List<Map<String,dynamic>> scopes;
 final Map<String,dynamic>? original;
 const _FixedMonthEditor({required this.scopes,this.original});
 @override State<_FixedMonthEditor> createState()=>_FixedMonthEditorState();
}
class _FixedMonthEditorState extends State<_FixedMonthEditor>{
 late final TextEditingController name;
 Map<String,dynamic>? selected;
 late int week;
 late bool active;
 @override void initState(){
  super.initState();
  final r=widget.original;
  name=TextEditingController(text:r?['name']?.toString()??'');
  week=(r?['week_no'] as num?)?.toInt()??1;
  active=r?['active']!=false;
  for(final s in widget.scopes){
   if(r!=null&&s['scope_kind']==r['scope_kind']&&s['scope_key']==r['scope_key']){
    selected=s;break;
   }
  }
 }
 @override void dispose(){name.dispose();super.dispose();}
 Future<void> chooseScope()async{
  String query='',kind='all';
  final result=await showModalBottomSheet<Map<String,dynamic>>(
   context:context,isScrollControlled:true,builder:(sheet)=>SafeArea(
    child:StatefulBuilder(builder:(ctx,rebuild)=>SizedBox(
     height:MediaQuery.sizeOf(sheet).height*0.72,child:Column(children:[
      const Padding(padding:EdgeInsets.all(12),
       child:Text('Chọn tỉnh/huyện, khách hoặc chuỗi được giao')),
      Wrap(spacing:6,children:[
       for(final option in const ['all','territory','customer','chain'])
        ChoiceChip(label:Text({'all':'Tất cả','territory':'Địa bàn',
         'customer':'Khách','chain':'Chuỗi'}[option]!),
         selected:kind==option,onSelected:(_)=>rebuild(()=>kind=option)),
      ]),
      Padding(padding:const EdgeInsets.symmetric(horizontal:12),
       child:TextField(autofocus:true,decoration:const InputDecoration(
        prefixIcon:Icon(Icons.search),hintText:'Tìm phạm vi được giao'),
        onChanged:(s)=>rebuild(()=>query=s.toLowerCase()))),
      Expanded(child:Builder(builder:(_){
       final options=widget.scopes.where((s)=>
        (kind=='all'||s['scope_kind']==kind)&&
        (s['label']?.toString()??'').toLowerCase().contains(query)).toList();
       return ListView.builder(itemCount:options.length,itemBuilder:(context,i)=>
        ListTile(title:Text(options[i]['label'].toString()),
         onTap:()=>Navigator.pop(sheet,options[i])));
      })),
     ]),
    ))));
  if(result!=null&&mounted)setState(()=>selected=result);
 }
 void save(){
  if(name.text.trim().length<2||name.text.length>120||selected==null){
   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
    content:Text('Nhập tên tuyến và chọn phạm vi.')));return;
  }
  final area=selected!['scope_kind']=='territory';
  Navigator.pop(context,<String,dynamic>{
   'name':name.text.trim(),'week_no':week,'scope_kind':selected!['scope_kind'],
   'scope_key':selected!['scope_key'],'scope_label':selected!['label'],
   'province':area?selected!['province']:null,
   'district':area?selected!['district']:null,'active':active,
  });
 }
 @override Widget build(BuildContext context)=>Scaffold(
  appBar:AppBar(title:Text(widget.original==null?'Thêm phân công cố định':'Sửa phân công')),
  bottomNavigationBar:SafeArea(child:Padding(padding:const EdgeInsets.all(12),
   child:FilledButton.icon(icon:const Icon(Icons.save_outlined),
    onPressed:save,label:const Text('Lưu phân công')))),
  body:ListView(padding:const EdgeInsets.all(14),children:[
   TextField(controller:name,maxLength:120,decoration:const InputDecoration(
    labelText:'Tên tuyến / nhiệm vụ',hintText:'Ví dụ: Tuần 2 · nhà sách')),
   const SizedBox(height:12),
   Text('Tuần lặp hằng tháng',style:Theme.of(context).textTheme.titleMedium),
   Wrap(spacing:7,children:[
    for(var i=1;i<=5;i++)ChoiceChip(label:Text('Tuần '+i.toString()),
     selected:week==i,onSelected:(_)=>setState(()=>week=i)),
   ]),
   const SizedBox(height:12),
   OutlinedButton.icon(onPressed:chooseScope,
    icon:const Icon(Icons.location_on_outlined),
    label:Text(selected?['label']?.toString()??'Chọn tỉnh/huyện, khách hoặc chuỗi')),
   const SizedBox(height:10),
   const Text('Không cần chọn ngày. Thêm nhiều phân công nếu cùng tuần '
    'cần phụ trách nhiều địa bàn, khách hoặc chuỗi.'),
   SwitchListTile(contentPadding:EdgeInsets.zero,title:const Text('Đang hoạt động'),
    value:active,onChanged:(v)=>setState(()=>active=v)),
   const Text('Thay đổi tuyến cố định không sửa lịch, GPS, lượt ghé '
    'hay khảo sát đã thực hiện.'),
  ]),
 );
}
