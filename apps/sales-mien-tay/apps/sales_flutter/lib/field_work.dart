import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'customers.dart';
import 'models.dart';
import 'offline_queue.dart';
import 'session.dart';

String dayKey(DateTime day)=>'${day.year.toString().padLeft(4,'0')}-${day.month.toString().padLeft(2,'0')}-${day.day.toString().padLeft(2,'0')}';
String monthKey(DateTime day)=>dayKey(day).substring(0,7);
String money(dynamic value){final n=num.tryParse(value.toString())??0;return '${n.round().toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'),(m)=>'.')} đ';}
class FieldWorkPage extends StatefulWidget{
 final OfflineQueue queue;final RegionCatalog regions;final CustomerService service;final bool report;
 const FieldWorkPage({super.key,required this.queue,required this.regions,required this.service,this.report=false});
 @override State<FieldWorkPage> createState()=>_FieldWorkPageState();
}
class _FieldWorkPageState extends State<FieldWorkPage>{
 DateTime day=DateTime.now().toUtc().add(const Duration(hours:7));bool weekly=false;String employee='',district='',status='';List<Map<String,dynamic>> rows=[];bool busy=false,cached=false;String? error;
 String get keyName=>widget.report?'report:${monthKey(day)}:${widget.service.province}':'routes-v2:${weekly?'week':'day'}:${dayKey(day)}:${widget.service.province}';
 int previousPending=0;
 @override void initState(){super.initState();previousPending=widget.queue.pending.length;widget.queue.addListener(queueChanged);load();}
 void queueChanged(){if(!mounted)return;final n=widget.queue.pending.length;if(n<previousPending&&!busy)load();previousPending=n;setState((){});}
 @override void dispose(){widget.queue.removeListener(queueChanged);super.dispose();}
 Future<void> load()async{
  if(busy)return;
  setState((){busy=true;error=null;});
  try{
   final uri=widget.queue.session.uri(widget.report?'/api/v1/reports/monthly':'/api/v1/routes').replace(queryParameters:{widget.report?'month':'day':widget.report?monthKey(day):dayKey(day),'province':widget.service.province,if(!widget.report)'period':weekly?'week':'day'});
   final data=decodeApi(await http.get(uri,headers:widget.service.headers).timeout(const Duration(seconds:20)));
   final list=(data['items'] as List).map((e)=>Map<String,dynamic>.from(e as Map)).toList();
   await widget.queue.cache(keyName,list);
   if(mounted)setState((){rows=list;cached=false;});
  }catch(e){
   if(e is ApiFailure&&(e.status==401||e.status==403)){if(mounted)setState(()=>rows=[]);}
   else{try{final list=await widget.queue.cached(keyName);if(mounted)setState((){rows=list;cached=true;});}catch(_){}}
   if(mounted)setState(()=>error=e.toString());
  }finally{if(mounted)setState(()=>busy=false);}
 }
 Future<void> chooseDate()async{final d=await showDatePicker(context:context,initialDate:day,firstDate:DateTime(2020),lastDate:DateTime(2100));if(d!=null&&mounted){setState(()=>day=d);await load();}}
 Future<void> addStop()async{
  try{
   List<FieldCustomer> customers;
   try{customers=await widget.service.list();await widget.queue.cache('customers:${widget.service.province}',customers.map((c)=>c.toJson()).toList());}
   catch(e){if(e is ApiFailure&&(e.status==401||e.status==403))rethrow;customers=(await widget.queue.cached('customers:${widget.service.province}')).map(FieldCustomer.fromJson).toList();}
   customers=customers.where((c)=>c.owner==widget.queue.identity).toList();
   if(!mounted)return;
   final selected=await showDialog<FieldCustomer>(context:context,builder:(c)=>AlertDialog(title:const Text('Chọn điểm ghé'),content:SizedBox(width:440,child:ListView(shrinkWrap:true,children:[if(customers.isEmpty)const Text('Chưa có khách hàng. Tạo và đồng bộ khách hàng trước.'),for(final item in customers)ListTile(title:Text(item.name),subtitle:Text('${item.district}, ${item.province}'),onTap:()=>Navigator.pop(c,item))])),actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('Đóng'))]));
   if(selected==null||!mounted)return;
   final sequence=TextEditingController(text:'${rows.where((r)=>r['planned']==true&&(r['data'] as Map)['plannedDate']==dayKey(day)).length+1}'),purpose=TextEditingController();
   final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:Text('Tuyến ${dayKey(day)}'),content:Column(mainAxisSize:MainAxisSize.min,children:[Text(selected.name),TextField(controller:sequence,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Thứ tự ghé')),TextField(controller:purpose,decoration:const InputDecoration(labelText:'Mục đích'))]),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Hủy')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Lưu điểm ghé'))]));
   final order=int.tryParse(sequence.text);final note=purpose.text.trim();sequence.dispose();purpose.dispose();
   if(ok!=true||!mounted)return;
   if(order==null||order<1||order>9999)throw StateError('Thứ tự phải từ 1 đến 9999');
   await widget.queue.enqueue('/api/v1/records',{'client_ref':const Uuid().v4(),'kind':'visit','province':selected.province,'district':selected.district,'customer_name':selected.name,'data':{'customerId':selected.id,'plannedDate':dayKey(day),'sequence':order,'purpose':note}});
   if(mounted){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Đã lưu điểm ghé trên máy · chờ đồng bộ')));setState((){});}
  }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Không lưu được: $e')));}
 }
 Future<void> editStop(Map<String,dynamic> row)async{
  final data=Map<String,dynamic>.from(row['data'] as Map);
  final sequence=TextEditingController(text:data['sequence'].toString()),purpose=TextEditingController(text:data['purpose']?.toString()??'');
  var date=DateTime.tryParse(data['plannedDate'].toString())??day;
  final ok=await showDialog<bool>(context:context,builder:(c)=>StatefulBuilder(builder:(c,setLocal)=>AlertDialog(title:Text('Sửa tuyến · ${row['name']}'),content:Column(mainAxisSize:MainAxisSize.min,children:[OutlinedButton.icon(onPressed:()async{final d=await showDatePicker(context:c,initialDate:date,firstDate:DateTime(2020),lastDate:DateTime(2100));if(d!=null)setLocal(()=>date=d);},icon:const Icon(Icons.calendar_today),label:Text(dayKey(date))),TextField(controller:sequence,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Thứ tự ghé')),TextField(controller:purpose,decoration:const InputDecoration(labelText:'Mục đích'))]),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Hủy')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Lưu'))])));
  final order=int.tryParse(sequence.text);final note=purpose.text.trim();sequence.dispose();purpose.dispose();
  if(ok!=true||!mounted)return;
  try{if(order==null||order<1||order>9999)throw StateError('Thứ tự phải từ 1 đến 9999');await widget.queue.enqueue('/api/v1/records/${row['id']}',{'version':row['version'],'data':{...data,'plannedDate':dayKey(date),'sequence':order,'purpose':note}},method:'PATCH');if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Đã lưu thay đổi · chờ đồng bộ')));}
  catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString())));}
 }
 DateTime get monday=>DateTime(day.year,day.month,day.day).subtract(Duration(days:day.weekday-1));
 Future<void> openCustomer(Map<String,dynamic> row)async{
  try{
   final id=row['customer_id'].toString();
   FieldCustomer customer;
   try{final data=decodeApi(await http.get(widget.queue.session.uri('/api/v1/customers/$id'),headers:widget.service.headers).timeout(const Duration(seconds:20)));customer=FieldCustomer.fromJson(Map<String,dynamic>.from(data['item'] as Map));}
   catch(e){if(e is ApiFailure&&(e.status==401||e.status==403||e.status==404))rethrow;final list=await widget.queue.cached('customers:${widget.service.province}');customer=FieldCustomer.fromJson(list.firstWhere((c)=>c['id']==id));}
   if(!mounted)return;
   await Navigator.push(context,MaterialPageRoute(builder:(_)=>CustomerDetail(service:widget.service,customer:customer,regions:widget.regions,queue:widget.queue)));
   if(mounted)await load();
  }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Không mở được điểm bán: $e')));}
 }
 @override Widget build(BuildContext context){
  final pending=widget.queue.pending.where((r){final p=r['payload'] as Map;final d=p['data'];return p['kind']=='visit'&&d is Map&&(weekly?(d['plannedDate'].toString().compareTo(dayKey(monday))>=0&&d['plannedDate'].toString().compareTo(dayKey(monday.add(const Duration(days:6))))<=0):d['plannedDate']==dayKey(day))&&(widget.service.province.isEmpty||p['province']==widget.service.province);}).toList();
  final filtered=rows.where((r)=>(employee.isEmpty||r['owner_sub']==employee)&&(district.isEmpty||r['district']==district)).toList();
  final people=<String,String>{for(final r in rows)if(r['owner_sub']!=null)r['owner_sub'].toString():r['full_name']?.toString()??''};
  final districts=rows.map((r)=>r['district']?.toString()??'').where((d)=>d.isNotEmpty).toSet().toList()..sort();
  final unique=<String,Map<String,dynamic>>{for(final r in filtered)r['customer_id'].toString():r};
  final planned=filtered.where((r)=>r['planned']==true).toList();
  final done=planned.where((r)=>r['visited']==true).length;
  final visited=unique.values.where((r)=>r['visited_week']==true).length;
  final visible=filtered.where((r)=>status.isEmpty||status=='planned'&&r['planned']==true||status=='visited'&&r['visited_week']==true||status=='unvisited'&&r['visited_week']!=true).toList();
  return Column(children:[
   Padding(padding:const EdgeInsets.all(12),child:Row(children:[Expanded(child:Text(widget.report?'Báo cáo tháng':'Tuyến đi',style:Theme.of(context).textTheme.titleLarge)),IconButton(onPressed:busy?null:load,icon:const Icon(Icons.sync)),if(!widget.report)FilledButton.icon(onPressed:busy?null:addStop,icon:const Icon(Icons.add),label:const Text('Điểm ghé'))])),
   Padding(padding:const EdgeInsets.symmetric(horizontal:12),child:OutlinedButton.icon(onPressed:busy?null:chooseDate,icon:const Icon(Icons.calendar_today),label:Text(widget.report?monthKey(day):dayKey(day)))),
   if(!widget.report)...[
    SegmentedButton<bool>(segments:const [ButtonSegment(value:false,label:Text('Ngày')),ButtonSegment(value:true,label:Text('Tuần'))],selected:{weekly},onSelectionChanged:busy?null:(v){setState(()=>weekly=v.first);load();}),
    if(weekly)Text('${dayKey(monday)} – ${dayKey(monday.add(const Duration(days:6)))}'),
    Padding(padding:const EdgeInsets.all(8),child:Column(children:[
      if(people.length>1)DropdownButtonFormField<String>(initialValue:people.containsKey(employee)?employee:'',decoration:const InputDecoration(labelText:'Nhân viên'),items:[const DropdownMenuItem(value:'',child:Text('Tất cả trong quyền')),for(final e in people.entries)DropdownMenuItem(value:e.key,child:Text(e.value))],onChanged:(v)=>setState(()=>employee=v??'')),
      Row(children:[Expanded(child:DropdownButtonFormField<String>(key:ValueKey(districts.join('|')),initialValue:districts.contains(district)?district:'',isExpanded:true,decoration:const InputDecoration(labelText:'Huyện'),items:[const DropdownMenuItem(value:'',child:Text('Tất cả')),for(final d in districts)DropdownMenuItem(value:d,child:Text(d,overflow:TextOverflow.ellipsis))],onChanged:(v)=>setState(()=>district=v??''))),const SizedBox(width:8),Expanded(child:DropdownButtonFormField<String>(initialValue:status,decoration:const InputDecoration(labelText:'Trạng thái'),items:const [DropdownMenuItem(value:'',child:Text('Tất cả')),DropdownMenuItem(value:'planned',child:Text('Có lịch')),DropdownMenuItem(value:'visited',child:Text('Ghé tuần')),DropdownMenuItem(value:'unvisited',child:Text('Chưa ghé tuần'))],onChanged:(v)=>setState(()=>status=v??'')))]),
      const SizedBox(height:8),Text('Điểm theo lịch: $done/${planned.length} · Khách đã ghé tuần: $visited/${unique.length}'),
      if(planned.isNotEmpty)LinearProgressIndicator(value:done/planned.length),
    ])),
   ],
   if(busy)const LinearProgressIndicator(),
   if(error!=null)Padding(padding:const EdgeInsets.all(8),child:Text(cached?'Dữ liệu lưu máy · chưa cập nhật: $error':error!)),
   Expanded(child:ListView(padding:const EdgeInsets.all(12),children:[
    if(widget.report)...[
     const Text('Chỉ tiêu ≠ dự kiến ≠ doanh thu thực thu. Số liệu theo tháng và phạm vi quyền; chỉ tiêu chung không phân bổ tự động cho tỉnh.'),
     for(final r in rows)Card(child:ListTile(title:Text('${r['full_name']} · ${r['province']??'Chung'}'),subtitle:Text('Chỉ tiêu: ${money(r['target'])}\nDự kiến 5 tuần: ${money(r['forecast'])}\nCheck-in đã xác minh: ${r['checkins']} · ${r['forecasts']} dự kiến'))),
    ]else...[
     for(final r in pending)Card(child:ListTile(leading:const Icon(Icons.cloud_upload_outlined),title:Text((r['payload'] as Map)['customer_name'].toString()),subtitle:Text(r['error']?.toString()??'Đã lưu máy · chờ đồng bộ'))),
     for(final r in visible)Card(child:ListTile(leading:CircleAvatar(child:Text(r['planned']==true?'${(r['data'] as Map)['sequence']??''}':'–')),title:Text(r['name'].toString()),subtitle:Text('${r['full_name']} · ${r['district']}, ${r['province']}\n${r['planned']==true?'${(r['data'] as Map)['plannedDate']} · ${r['visited']==true?'Đã ghé':'Chưa ghé theo lịch'}':'Chưa lên lịch'} · ${r['visited_week']==true?'Đã ghé tuần':'Chưa ghé tuần'}\nLần gần nhất: ${r['last_visit']==null?'Chưa có':DateTime.tryParse(r['last_visit'].toString())?.toLocal().toString().substring(0,16)??''}'),trailing:r['planned']==true&&r['owner_sub']==widget.queue.identity?IconButton(tooltip:'Sửa tuyến',icon:const Icon(Icons.edit_outlined),onPressed:()=>editStop(r)):const Icon(Icons.chevron_right),onTap:()=>openCustomer(r))),
    ],
    if(rows.isEmpty&&(widget.report||pending.isEmpty))const Padding(padding:EdgeInsets.all(18),child:Text('Chưa có dữ liệu trong kỳ đã chọn.')),
   ]))
  ]);
 }
}
