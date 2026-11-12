import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:http/http.dart' as http;
import 'offline_queue.dart';
import 'session.dart';
import 'actuals.dart';
import 'responsive_controls.dart';

List<int> targetMonths(String period,int month)=>period=='year'?List.generate(12,(i)=>i+1):
  period=='quarter'?List.generate(3,(i)=>((month-1)~/3)*3+i+1):[month];
int targetAmount(Object? value)=>int.tryParse('$value')??0;
String targetMoney(int value)=>'${value.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'),(_)=>'.')} đ';
List<Map<String,dynamic>> targetRows(Object? value)=>(value as List? ?? []).map((r)=>Map<String,dynamic>.from(r as Map)).toList();
int targetTotal(List<Map<String,dynamic>> rows,List<int> months,String dimension,[String? entity])=>rows.where((r)=>r['dimension']==dimension&&months.contains(targetAmount(r['month']))&&(entity==null||r['entity_id']==entity)).fold(0,(sum,r)=>sum+targetAmount(r['amount']));


class TargetClient {
 final OfflineQueue queue;
 final http.Client? client;
 const TargetClient(this.queue,{this.client});
 Map<String,String> get headers=>{...sessionHeaders(queue.session.cookie),'X-Sync-Identity':queue.identity,'X-Sync-Revision':queue.revision};
 Future<Map<String,dynamic>> get(String path) async {
  final uri=queue.session.uri(path);
  return decodeApi(await (client==null?http.get(uri,headers:headers):client!.get(uri,headers:headers)).timeout(const Duration(seconds:20)));
 }
 Future<Map<String,dynamic>> post(String path,Map<String,dynamic> body) async {
  final uri=queue.session.uri(path),data=jsonEncode(body);
  return decodeApi(await (client==null?http.post(uri,headers:headers,body:data):client!.post(uri,headers:headers,body:data)).timeout(const Duration(seconds:20)));
 }
}

class TargetPage extends StatefulWidget{
 final OfflineQueue queue;
 final TargetClient? client;
 const TargetPage({super.key,required this.queue,this.client});
 @override State<TargetPage> createState()=>_TargetPageState();
}
class _TargetPageState extends State<TargetPage>{
 int year=DateTime.now().year,month=DateTime.now().month,_generation=0;
 String period='month',owner='';
 late final TargetClient client=widget.client??TargetClient(widget.queue);
 List<Map<String,dynamic>> staff=[],rows=[],allocations=[],actuals=[];
 bool busy=true,cached=false,canEdit=false;
 String? error;
 List<int> get months=>targetMonths(period,month);
 String get path=>Uri(path:'/api/v1/targets',queryParameters:{'year':'$year','owner':owner}).toString();
 String get cacheKey=>'targets-v2:$year:$owner';
 @override void initState(){super.initState();owner=widget.queue.identity;load();}
 Future<void> load()async{
  final generation=++_generation,key=cacheKey,request=path;
  setState((){busy=true;error=null;cached=false;canEdit=false;rows=[];allocations=[];actuals=[];});
  Map<String,dynamic>? data;bool offline=false;String? failure;
  try{data=await client.get(request);
   try{await widget.queue.cache(key,[data]);}catch(_){}
  }catch(e){
   failure=e.toString();
   if(e is! ApiFailure||e.status>=500){try{data=(await widget.queue.cached(key)).firstOrNull;offline=data!=null;}catch(_){}}
  }
  if(!mounted||generation!=_generation)return;
  setState((){
   busy=false;cached=offline;error=data==null?failure:null;
   if(data!=null){staff=targetRows(data['staff']);owner=data['owner'].toString();rows=targetRows(data['items']);allocations=targetRows(data['allocations']);actuals=targetRows(data['actuals']);canEdit=!offline&&data['can_edit']==true;}
  });
 }
 Future<void> choose(String dimension)async{
  if(dimension=='employee'){await edit(dimension,'','Target nhân viên');return;}
  final selected=await showDialog<Map<String,dynamic>>(context:context,builder:(_)=>_TargetPicker(client:client,owner:owner,dimension:dimension));
  if(selected!=null&&mounted)await edit(dimension,selected['id'].toString(),selected['name'].toString());
 }
 Future<void> edit(String dimension,String entity,String name)async{
  final selectedMonths=List<int>.of(months),selectedYear=year,selectedOwner=owner;
  final existing={for(final r in rows.where((r)=>r['dimension']==dimension&&r['entity_id']==entity))targetAmount(r['month']):r};
  final result=await showDialog<bool>(context:context,barrierDismissible:false,builder:(_)=>_TargetEditor(
   client:client,year:selectedYear,owner:selectedOwner,dimension:dimension,entity:entity,name:name,months:selectedMonths,existing:existing));
  if(result==true&&mounted)await load();
 }
 Widget allocationCard(String dimension,String label,int total){
  final groups=<String,List<Map<String,dynamic>>>{};
  for(final r in rows.where((r)=>r['dimension']==dimension&&months.contains(targetAmount(r['month'])))){
   (groups[r['entity_id'].toString()]??=[]).add(r);
  }
  final allocated=targetTotal(allocations,months,dimension);
  return Card(child:Padding(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
   Row(children:[Expanded(child:Text(label,style:Theme.of(context).textTheme.titleMedium)),if(canEdit)IconButton(tooltip:'Thêm $label',onPressed:()=>choose(dimension),icon:const Icon(Icons.add))]),
   Text('Đã phân bổ: ${targetMoney(allocated)}'),
   Text('Chưa phân bổ: ${targetMoney(total-allocated)}'),
   if(groups.isEmpty)const Padding(padding:EdgeInsets.symmetric(vertical:8),child:Text('Chưa có phân bổ trong kỳ.')),
   for(final entry in groups.entries)ListTile(contentPadding:EdgeInsets.zero,title:Text('${entry.value.first['code']??''} · ${entry.value.first['name']??'Không còn trong danh mục'}'),
    subtitle:Text(targetMoney(targetTotal(entry.value,months,dimension))),
    trailing:canEdit?IconButton(tooltip:'Sửa phân bổ',icon:const Icon(Icons.edit_outlined),onPressed:()=>edit(dimension,entry.key,entry.value.first['name']?.toString()??entry.key)):null),
  ])));
 }
 @override Widget build(BuildContext context){
  final total=targetTotal(rows,months,'employee');
  final fact=actuals.where((r)=>months.contains(targetAmount(r['month']))).toList();
  final hasActual=fact.any((r)=>targetAmount(r['records'])>0);
  final actual=fact.fold<int>(0,(sum,r)=>sum+targetAmount(r['amount']));
  return ListView(padding:const EdgeInsets.all(12),children:[
   Row(children:[Expanded(child:Text('Chỉ tiêu',style:Theme.of(context).textTheme.titleLarge)),IconButton(tooltip:'Tải lại Target',onPressed:busy?null:load,icon:const Icon(Icons.refresh))]),
   OutlinedButton.icon(onPressed:()async{await Navigator.push(context,MaterialPageRoute(builder:(_)=>ActualsPage(queue:widget.queue)));if(mounted)load();},
     icon:const Icon(Icons.receipt_long_outlined),label:const Text('Doanh số thực tế')),
   if(staff.isNotEmpty)DropdownButtonFormField<String>(key:ValueKey('owner:$owner'),initialValue:staff.any((s)=>s['user_sub']==owner)?owner:null,isExpanded:true,decoration:const InputDecoration(labelText:'Nhân viên'),
    items:[for(final s in staff)DropdownMenuItem(value:s['user_sub'].toString(),child:Text('${s['employee_code']} · ${s['full_name']}',overflow:TextOverflow.ellipsis))],onChanged:busy?null:(v){if(v!=null){owner=v;load();}}),
   const SizedBox(height:8),
   AdaptiveFilterRow(children:[
     DropdownButtonFormField<int>(key:ValueKey(year),initialValue:year,isExpanded:true,
       decoration:const InputDecoration(labelText:'Năm'),
       items:[for(var y=year-3;y<=year+3;y++)if(y>=2000&&y<=2100)
         DropdownMenuItem(value:y,child:Text('$y'))],
       onChanged:busy?null:(v){if(v!=null){year=v;load();}}),
     DropdownButtonFormField<String>(initialValue:period,isExpanded:true,
       decoration:const InputDecoration(labelText:'Kỳ'),
       items:const [DropdownMenuItem(value:'month',child:Text('Tháng')),
         DropdownMenuItem(value:'quarter',child:Text('Quý')),
         DropdownMenuItem(value:'year',child:Text('Năm'))],
       onChanged:(v)=>setState(()=>period=v??'month')),
    ]),
    if(period!='year')...[
    const SizedBox(height:8),
    DropdownButtonFormField<int>(key:ValueKey('period:$period'),initialValue:period=='quarter'?((month-1)~/3)*3+1:month,decoration:InputDecoration(labelText:period=='quarter'?'Quý':'Tháng'),items:[for(final m in period=='quarter'?[1,4,7,10]:List.generate(12,(i)=>i+1))DropdownMenuItem(value:m,child:Text(period=='quarter'?'Quý ${(m-1)~/3+1}':'Tháng $m'))],onChanged:(v)=>setState(()=>month=v??1)),
   ],
   if(busy)const LinearProgressIndicator(),
   if(cached)const Text('Dữ liệu lưu máy · cần mạng để giao hoặc sửa chỉ tiêu.'),
   if(error!=null)Text(error!,style:TextStyle(color:Theme.of(context).colorScheme.error)),
   if(!busy&&error==null&&owner.isEmpty)const Text('Chưa có nhân viên thuộc phạm vi quản lý.'),
   if(!busy&&error==null&&owner.isNotEmpty)...[
    Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
     Row(children:[const Expanded(child:Text('Target nhân viên')),if(canEdit)TextButton(onPressed:()=>choose('employee'),child:const Text('Giao / sửa'))]),
     Text(targetMoney(total),style:Theme.of(context).textTheme.headlineSmall),
     const SizedBox(height:8),
     Text(hasActual?'Thực hiện: ${targetMoney(actual)}':'Thực hiện: Chưa có dữ liệu doanh số thực tế'),
     Text(hasActual?'Hoàn thành: ${total>0?(100*actual/total).toStringAsFixed(1)+'%':'— (Target = 0)'}   Còn thiếu: ${total>0?targetMoney((total-actual).clamp(0,total).toInt()):'—'}':'Hoàn thành: —     Còn thiếu: —'),
     const Text('Target khách và SKU là hai nhóm phân bổ riêng; không cộng vào Target nhân viên.'),
    ]))),
    allocationCard('customer','Khách hàng',total),allocationCard('product','Sản phẩm / SKU',total),
    const Padding(padding:EdgeInsets.all(8),child:Text('Chỉ tiêu quý/năm cộng từ các tháng. Mỗi nhân viên có Target cá nhân riêng, kể cả Admin/Manager trực tiếp bán hàng. Admin/Manager giao hoặc sửa trong phạm vi quyền; Sales chỉ xem của mình.')),
   ],
  ]);
 }
}

class _TargetPicker extends StatefulWidget{
 final TargetClient client;final String owner,dimension;
 const _TargetPicker({required this.client,required this.owner,required this.dimension});
 @override State<_TargetPicker> createState()=>_TargetPickerState();
}
class _TargetPickerState extends State<_TargetPicker>{
 final search=TextEditingController();List<Map<String,dynamic>> items=[];bool busy=true;String? error;int generation=0;
 @override void initState(){super.initState();load();}
 @override void dispose(){search.dispose();super.dispose();}
 Future<void> load()async{
  final g=++generation;setState((){busy=true;error=null;});
  try{final r=await widget.client.get(Uri(path:'/api/v1/targets/options',queryParameters:{'owner':widget.owner,'dimension':widget.dimension,'q':search.text.trim()}).toString());
   if(mounted&&g==generation)setState(()=>items=targetRows(r['items']));
  }catch(e){if(mounted&&g==generation)setState(()=>error=e.toString());}
  finally{if(mounted&&g==generation)setState(()=>busy=false);}
 }
 @override Widget build(BuildContext context)=>AlertDialog(title:Text(widget.dimension=='customer'?'Chọn khách hàng':'Chọn sản phẩm'),
  content:SizedBox(width:480,height:400,child:Column(children:[
   TextField(controller:search,decoration:InputDecoration(labelText:'Tìm mã hoặc tên',suffixIcon:IconButton(onPressed:load,icon:const Icon(Icons.search))),onSubmitted:(_)=>load()),
   if(busy)const LinearProgressIndicator(),if(error!=null)Text(error!),
   Expanded(child:ListView(children:[for(final r in items)ListTile(title:Text(r['name'].toString()),subtitle:Text(r['code']?.toString()??''),onTap:()=>Navigator.pop(context,r)),if(!busy&&items.isEmpty)const Text('Không tìm thấy dữ liệu.')]))
  ])),actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('Đóng'))]);
}
class _TargetEditor extends StatefulWidget{
 final TargetClient client;final int year;final String owner,dimension,entity,name;final List<int> months;final Map<int,Map<String,dynamic>> existing;
 const _TargetEditor({required this.client,required this.year,required this.owner,required this.dimension,required this.entity,required this.name,required this.months,required this.existing});
 @override State<_TargetEditor> createState()=>_TargetEditorState();
}
class _TargetEditorState extends State<_TargetEditor>{
 late final Map<int,TextEditingController> inputs;bool busy=false;String? error,lastPayload;String ref=const Uuid().v4();
 @override void initState(){super.initState();inputs={for(final m in widget.months)m:TextEditingController(text:targetAmount(widget.existing[m]?['amount']).toString())};}
 @override void dispose(){for(final c in inputs.values){c.dispose();}super.dispose();}
 Future<void> save()async{
  final values=<Map<String,dynamic>>[];
  for(final m in widget.months){final v=int.tryParse(inputs[m]!.text.trim());if(v==null||v<0||v>1000000000000){setState(()=>error='Tháng $m: nhập số đồng nguyên từ 0 đến 1.000 tỷ.');return;}values.add({'month':m,'amount':v,'version':targetAmount(widget.existing[m]?['version'])});}
  final payload=jsonEncode(values);if(lastPayload!=null&&lastPayload!=payload)ref=const Uuid().v4();lastPayload=payload;
  setState((){busy=true;error=null;});
  try{
   await widget.client.post('/api/v1/targets',{'client_ref':ref,'owner':widget.owner,'year':widget.year,'dimension':widget.dimension,'entity_id':widget.entity,'months':values});
   if(mounted)Navigator.pop(context,true);
  }catch(e){if(mounted)setState(()=>error=e.toString());}
  finally{if(mounted)setState(()=>busy=false);}
 }
 @override Widget build(BuildContext context)=>AlertDialog(title:Text(widget.name),content:SizedBox(width:440,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
  Text('Năm ${widget.year} · nhập doanh số mục tiêu từng tháng (VNĐ).'),
  const SizedBox(height:8),
  for(final m in widget.months)Padding(padding:const EdgeInsets.only(bottom:8),child:TextField(controller:inputs[m],enabled:!busy,keyboardType:TextInputType.number,decoration:InputDecoration(labelText:'Tháng $m · VNĐ'),onChanged:(_)=>setState((){}))),
  Text('Tổng kỳ: ${targetMoney(inputs.values.fold(0,(a,c)=>a+targetAmount(c.text)))}'),
  if(error!=null)Text(error!,style:TextStyle(color:Theme.of(context).colorScheme.error)),
 ]))),actions:[TextButton(onPressed:busy?null:()=>Navigator.pop(context),child:const Text('Đóng')),FilledButton(onPressed:busy?null:save,child:Text(busy?'Đang lưu…':'Lưu chỉ tiêu'))]);
}
