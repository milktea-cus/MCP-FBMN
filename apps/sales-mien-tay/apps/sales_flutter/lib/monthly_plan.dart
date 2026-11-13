import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'customers.dart';
import 'offline_queue.dart';
import 'planning_periods.dart';
import 'session.dart';

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
 List<Map<String,dynamic>> items=[],scopes=[];
 bool busy=false,cached=false;
 String? error;
 String get monthCache=>'monthly-plans:${monthKey(month)}';
 String get optionsCache=>'monthly-plan-scopes';
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
   if(mounted)setState((){items=localItems;scopes=localScopes;cached=true;});
   final results=await Future.wait([
    http.get(widget.queue.session.uri('/api/v1/monthly-plans').replace(queryParameters:{'month':monthKey(month)}),headers:widget.service.headers).timeout(const Duration(seconds:20)),
    http.get(widget.queue.session.uri('/api/v1/monthly-plans/options'),headers:widget.service.headers).timeout(const Duration(seconds:20)),
   ]);
   final plans=decodeApi(results[0]),options=decodeApi(results[1]);
   final fresh=(plans['items'] as List).map((e)=>Map<String,dynamic>.from(e as Map)).toList();
   final allowed=(options['scopes'] as List).map((e)=>Map<String,dynamic>.from(e as Map)).toList();
   await widget.queue.cache(monthCache,fresh);
   await widget.queue.cache(optionsCache,allowed);
   if(mounted)setState((){items=fresh;scopes=allowed;cached=false;});
  }catch(e){
   if(e is ApiFailure&&(e.status==401||e.status==403)){
    if(mounted)setState((){items=[];scopes=[];cached=false;});
   }
   if(mounted)setState(()=>error=e.toString());
  }finally{if(mounted)setState(()=>busy=false);}
 }
 void _changeMonth(int delta){
  setState((){month=DateTime(month.year,month.month+delta);period=0;items=[];});
  unawaited(_reload());
 }
 Future<void> _edit({Map<String,dynamic>? original})async{
  if(scopes.isEmpty){_toast('Chưa tải được phạm vi được giao. Kết nối lại để lấy quyền lập kế hoạch.');return;}
  final selection=await Navigator.push<MonthlyPlanSelection>(context,MaterialPageRoute(
    builder:(_)=>MonthlyPlanEditor(month:month,scopes:scopes,original:original)));
  if(selection==null||!mounted)return;
  try{
   for(final scope in selection.scopes){
    final editing=original!=null,ref=const Uuid().v4();
    final payload=<String,dynamic>{
     'client_ref':ref,'period_ym':monthKey(month),'work_date':dayKey(selection.date),
     'scope_kind':scope['scope_kind'],'scope_key':scope['scope_key'],
     'province':scope['scope_kind']=='territory'?scope['province']:null,
     'district':scope['scope_kind']=='territory'?scope['district']:null,
     'purpose':selection.purpose,'target_new_customers':selection.target,
     'note':selection.note,'status':selection.status,
     if(editing)'version':original['version'],
    };
    await widget.queue.enqueue(
     editing?'/api/v1/monthly-plans/${original['id']}':'/api/v1/monthly-plans',
     payload,method:editing?'PATCH':'POST');
   }
   _toast('Đã lưu ${selection.scopes.length} công việc trên máy · chờ đồng bộ');
   if(mounted)await _reload();
  }catch(e){_toast('Không lưu được kế hoạch: ${e.toString()}');}
 }
 @override Widget build(BuildContext context){
  final days=monthEnd(month).day;
  final periods=[for(var p=1;p<=5;p++)if(periodDays(month,p).isNotEmpty)p];
  final visible=items.where((r){
   final date=DateTime.tryParse(r['work_date']?.toString()??'');
   return period==0||date!=null&&planningPeriod(date)==period;
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
    Text('Kỳ kế hoạch theo ngày trong tháng (01–07, 08–14, 15–21, 22–28${days>28?', 29–cuối':''}). Không phải tuần Thứ Hai–Chủ nhật.',
      style:Theme.of(context).textTheme.bodySmall),
    const SizedBox(height:10),
    Wrap(spacing:6,runSpacing:6,children:[
     ChoiceChip(label:const Text('Tất cả'),selected:period==0,onSelected:(_)=>setState(()=>period=0)),
     for(final p in periods)ChoiceChip(
      label:Text('Kỳ ${p} (${((p-1)*7+1).toString().padLeft(2,'0')}–${(p*7>days?days:p*7).toString().padLeft(2,'0')}/${month.month.toString().padLeft(2,'0')})'),
      selected:period==p,onSelected:(_)=>setState(()=>period=p)),
    ]),
    const SizedBox(height:12),
    FilledButton.icon(onPressed:canCreate?()=>_edit():null,
     icon:const Icon(Icons.add_location_alt_outlined),
     label:const Text('Thêm công tác địa bàn / chuỗi')),
    const SizedBox(height:6),
    const Text('Có thể lập chuyến đi phát triển thị trường ngay cả khi địa bàn chưa có khách hàng.'),
    if(busy)const LinearProgressIndicator(),
    if(error!=null)Padding(padding:const EdgeInsets.symmetric(vertical:8),child:
      Text(cached?'Dữ liệu đã lưu trên máy · chưa tải mới: ${error!}':error!,
       style:TextStyle(color:Theme.of(context).colorScheme.error))),
    for(final p in pending)Card(child:ListTile(
     leading:const Icon(Icons.cloud_upload_outlined),
     title:Text((p['payload'] as Map)['purpose']?.toString()??'Công tác'),
     subtitle:Text("${(p['payload'] as Map)['work_date']} · ${(p['payload'] as Map)['scope_key']}\n${p['error']??'Đã lưu máy · chờ đồng bộ'}"),
     trailing:p['status']=='blocked'?IconButton(icon:const Icon(Icons.refresh),
      tooltip:'Thử đồng bộ lại',onPressed:()=>widget.queue.retryBlocked(p['key'].toString())):null,
    )),
    for(final r in visible)Card(child:ListTile(
     leading:CircleAvatar(child:Text(DateTime.tryParse(r['work_date'].toString())?.day.toString()??'–')),
     title:Text(r['purpose']?.toString()??''),
     subtitle:Text("${r['work_date'].toString().substring(0,10)} · ${r['scope_kind']=='chain'?'Chuỗi':r['district']==''?'Toàn tỉnh':'Địa bàn'}: ${r['scope_kind']=='chain'?scopes.where((s)=>s['scope_key']==r['scope_key']).map((s)=>s['label']).firstOrNull??'Chuỗi':r['scope_key']}\nMục tiêu khách mới: ${r['target_new_customers']} · ${r['status']=='cancelled'?'Đã hủy':'Đã lập kế hoạch'} · v${r['version']}"),
     isThreeLine:true,
     trailing:r['owner_sub']==widget.queue.identity&&
       scopes.any((s)=>s['scope_key']==r['scope_key']&&s['scope_kind']==r['scope_kind'])
       ?IconButton(tooltip:'Sửa công tác',icon:const Icon(Icons.edit_outlined),onPressed:()=>_edit(original:r))
       :null,
    )),
    if(!busy&&visible.isEmpty&&pending.isEmpty)const Padding(
      padding:EdgeInsets.all(24),child:Text('Chưa có công tác trong kỳ này. Hãy lập chuyến đi, không cần có khách sẵn.',textAlign:TextAlign.center)),
   ]),
  );
 }
}

class MonthlyPlanSelection {
 final List<Map<String,dynamic>> scopes;
 final DateTime date;
 final String purpose,note,status;
 final int target;
 const MonthlyPlanSelection(this.scopes,this.date,this.purpose,this.note,this.status,this.target);
}
class MonthlyPlanEditor extends StatefulWidget {
 final DateTime month;
 final List<Map<String,dynamic>> scopes;
 final Map<String,dynamic>? original;
 const MonthlyPlanEditor({super.key,required this.month,required this.scopes,this.original});
 @override State<MonthlyPlanEditor> createState()=>_MonthlyPlanEditorState();
}
class _MonthlyPlanEditorState extends State<MonthlyPlanEditor>{
 late DateTime date;
 late final TextEditingController purpose,note,target,search;
 final selected=<String>{};
 String status='planned';
 @override void initState(){
  super.initState();
  final row=widget.original;
  date=row==null?DateTime(widget.month.year,widget.month.month,1):DateTime.tryParse(row['work_date'].toString())??widget.month;
  purpose=TextEditingController(text:row?['purpose']?.toString()??'');
  note=TextEditingController(text:row?['note']?.toString()??'');
  target=TextEditingController(text:row?['target_new_customers']?.toString()??'0');
  search=TextEditingController();
  status=row?['status']?.toString()??'planned';
  if(row!=null)selected.add("${row['scope_kind']}:${row['scope_key']}");
 }
 @override void dispose(){purpose.dispose();note.dispose();target.dispose();search.dispose();super.dispose();}
 void submit(){
  final scopes=widget.scopes.where((o)=>selected.contains("${o['scope_kind']}:${o['scope_key']}")).toList();
  final number=int.tryParse(target.text.trim());
  if(scopes.isEmpty||purpose.text.trim().length<2||purpose.text.length>500||number==null||number<0||number>9999||note.text.length>2000){
   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Chọn phạm vi; nhập mục đích (từ 2 ký tự) và số khách mới hợp lệ.')));
   return;
  }
  Navigator.pop(context,MonthlyPlanSelection(scopes,date,purpose.text.trim(),note.text.trim(),status,number));
 }
 Future<void> pickDate()async{
  final d=await showDatePicker(context:context,initialDate:date,firstDate:DateTime(widget.month.year,widget.month.month,1),lastDate:monthEnd(widget.month));
  if(d!=null&&mounted)setState(()=>date=d);
 }
 @override Widget build(BuildContext context){
  final q=search.text.trim().toLowerCase();
  final filtered=widget.scopes.where((o)=>(o['label']?.toString()??'').toLowerCase().contains(q)).toList();
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
    Text(widget.original==null?'Chọn nhiều địa bàn hoặc chuỗi *':'Phạm vi công tác',style:Theme.of(context).textTheme.titleMedium),
    const Text('Chỉ hiện những nơi/chuỗi được giao. Không cần có sẵn điểm bán.'),
    const SizedBox(height:8),
    TextField(controller:search,onChanged:(_)=>setState((){}),decoration:const InputDecoration(prefixIcon:Icon(Icons.search),hintText:'Tìm tỉnh, huyện, chuỗi')),
    const SizedBox(height:8),
    Text('Đã chọn ${selected.length} · ${filtered.length} phạm vi'),
    SizedBox(height:300,child:ListView.builder(
     itemCount:filtered.length,itemBuilder:(ctx,i){
      final item=filtered[i],key="${item['scope_kind']}:${item['scope_key']}";
      return CheckboxListTile(
       dense:true,controlAffinity:ListTileControlAffinity.leading,
       title:Text(item['label'].toString()),value:selected.contains(key),
       onChanged:widget.original!=null?null:(checked)=>setState((){if(checked==true){selected.add(key);}else{selected.remove(key);}}));
     })),
    const SizedBox(height:16),
    FilledButton(onPressed:submit,child:Text(widget.original==null?'Lưu ${selected.length} công việc':'Lưu thay đổi')),
    const SizedBox(height:24),
   ]),
  );
 }
}
