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
 DateTime day=DateTime.now();List<Map<String,dynamic>> rows=[];bool busy=false,cached=false;String? error;
 String get keyName=>widget.report?'report:${monthKey(day)}:${widget.service.province}':'routes:${dayKey(day)}:${widget.service.province}';
 int previousPending=0;
 @override void initState(){super.initState();previousPending=widget.queue.pending.length;widget.queue.addListener(queueChanged);load();}
 void queueChanged(){if(!mounted)return;final n=widget.queue.pending.length;if(n<previousPending&&!busy)load();previousPending=n;setState((){});}
 @override void dispose(){widget.queue.removeListener(queueChanged);super.dispose();}
 Future<void> load()async{
  if(busy)return;
  setState((){busy=true;error=null;});
  try{
   final uri=widget.queue.session.uri(widget.report?'/api/v1/reports/monthly':'/api/v1/routes').replace(queryParameters:{widget.report?'month':'day':widget.report?monthKey(day):dayKey(day),'province':widget.service.province});
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
   if(!mounted)return;
   final selected=await showDialog<FieldCustomer>(context:context,builder:(c)=>AlertDialog(title:const Text('Chọn điểm ghé'),content:SizedBox(width:440,child:ListView(shrinkWrap:true,children:[if(customers.isEmpty)const Text('Chưa có khách hàng. Tạo và đồng bộ khách hàng trước.'),for(final item in customers)ListTile(title:Text(item.name),subtitle:Text('${item.district}, ${item.province}'),onTap:()=>Navigator.pop(c,item))])),actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('Đóng'))]));
   if(selected==null||!mounted)return;
   final sequence=TextEditingController(text:'${rows.length+1}'),purpose=TextEditingController();
   final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:Text('Tuyến ${dayKey(day)}'),content:Column(mainAxisSize:MainAxisSize.min,children:[Text(selected.name),TextField(controller:sequence,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Thứ tự ghé')),TextField(controller:purpose,decoration:const InputDecoration(labelText:'Mục đích'))]),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Hủy')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Lưu điểm ghé'))]));
   final order=int.tryParse(sequence.text);final note=purpose.text.trim();sequence.dispose();purpose.dispose();
   if(ok!=true||!mounted)return;
   if(order==null||order<1||order>9999)throw StateError('Thứ tự phải từ 1 đến 9999');
   await widget.queue.enqueue('/api/v1/records',{'client_ref':const Uuid().v4(),'kind':'visit','province':selected.province,'district':selected.district,'customer_name':selected.name,'data':{'customerId':selected.id,'plannedDate':dayKey(day),'sequence':order,'purpose':note}});
   if(mounted){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Đã lưu điểm ghé trên máy · chờ đồng bộ')));setState((){});}
  }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Không lưu được: $e')));}
 }
 Future<void> openCustomer(Map<String,dynamic> row)async{
  try{
   final id=row['customer_id'].toString();
   final data=decodeApi(await http.get(widget.queue.session.uri('/api/v1/customers/$id'),headers:widget.service.headers).timeout(const Duration(seconds:20)));
   final customer=FieldCustomer.fromJson(Map<String,dynamic>.from(data['item'] as Map));
   if(!mounted)return;
   await Navigator.push(context,MaterialPageRoute(builder:(_)=>CustomerDetail(service:widget.service,customer:customer,regions:widget.regions,queue:widget.queue)));
   if(mounted)await load();
  }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Không mở được điểm bán: $e')));}
 }
 @override Widget build(BuildContext context){
  final pending=widget.queue.pending.where((r){final p=r['payload'] as Map;final d=p['data'];return p['kind']=='visit'&&d is Map&&d['plannedDate']==dayKey(day)&&(widget.service.province.isEmpty||p['province']==widget.service.province);}).toList();
  return Column(children:[
   Padding(padding:const EdgeInsets.all(12),child:Row(children:[Expanded(child:Text(widget.report?'Báo cáo tháng':'Tuyến đi theo ngày',style:Theme.of(context).textTheme.titleLarge)),IconButton(onPressed:busy?null:load,icon:const Icon(Icons.sync)),if(!widget.report)FilledButton.icon(onPressed:busy?null:addStop,icon:const Icon(Icons.add),label:const Text('Điểm ghé'))])),
   Padding(padding:const EdgeInsets.symmetric(horizontal:12),child:OutlinedButton.icon(onPressed:busy?null:chooseDate,icon:const Icon(Icons.calendar_today),label:Text(widget.report?monthKey(day):dayKey(day)))),
   if(busy)const LinearProgressIndicator(),
   if(error!=null)Padding(padding:const EdgeInsets.all(8),child:Text(cached?'Dữ liệu lưu máy · chưa cập nhật: $error':error!)),
   Expanded(child:ListView(padding:const EdgeInsets.all(12),children:[
    if(widget.report)...[
     const Text('Chỉ tiêu ≠ dự kiến ≠ doanh thu thực thu. Số liệu theo tháng và phạm vi quyền; chỉ tiêu chung không phân bổ tự động cho tỉnh.'),
     for(final r in rows)Card(child:ListTile(title:Text('${r['full_name']} · ${r['province']??'Chung'}'),subtitle:Text('Chỉ tiêu: ${money(r['target'])}\nDự kiến 5 tuần: ${money(r['forecast'])}\nCheck-in đã xác minh: ${r['checkins']} · ${r['forecasts']} dự kiến'))),
    ]else...[
     for(final r in pending)Card(child:ListTile(leading:const Icon(Icons.cloud_upload_outlined),title:Text((r['payload'] as Map)['customer_name'].toString()),subtitle:Text(r['error']?.toString()??'Đã lưu máy · chờ đồng bộ'))),
     for(final r in rows)Card(child:ListTile(leading:CircleAvatar(child:Text('${(r['data'] as Map)['sequence']??''}')),title:Text(r['name'].toString()),subtitle:Text('${r['district']}, ${r['province']} · ${r['visited']==true?'Đã check-in':'Chưa check-in'}\n${r['address_line']}'),trailing:const Icon(Icons.chevron_right),onTap:()=>openCustomer(r))),
    ],
    if(rows.isEmpty&&(widget.report||pending.isEmpty))const Padding(padding:EdgeInsets.all(18),child:Text('Chưa có dữ liệu trong kỳ đã chọn.')),
   ]))
  ]);
 }
}
