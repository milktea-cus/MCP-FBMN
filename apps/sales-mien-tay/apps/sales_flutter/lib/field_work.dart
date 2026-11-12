import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'customers.dart';
import 'customer_categories.dart';
import 'models.dart';
import 'offline_queue.dart';
import 'session.dart';

String dayKey(DateTime day)=>'${day.year.toString().padLeft(4,'0')}-${day.month.toString().padLeft(2,'0')}-${day.day.toString().padLeft(2,'0')}';
DateTime weekMonday(DateTime day)=>DateTime(day.year,day.month,day.day).subtract(Duration(days:day.weekday-1));
String monthKey(DateTime day)=>dayKey(day).substring(0,7);
/// Five planning periods are dates 1–7, 8–14, 15–21, 22–28, 29–end.
int planningPeriod(DateTime day)=>((day.day-1)~/7)+1;
DateTime monthEnd(DateTime day)=>DateTime(day.year,day.month+1,0);
List<DateTime> periodDays(DateTime month,int period){
 if(period<1||period>5)throw ArgumentError('Kỳ phải từ 1 đến 5');
 final first=(period-1)*7+1,last=monthEnd(month).day;
 return [for(var d=first;d<=last&&d<first+7;d++)DateTime(month.year,month.month,d)];
}
String money(dynamic value){final n=num.tryParse(value.toString())??0;return '${n.round().toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'),(m)=>'.')} đ';}
class FieldWorkPage extends StatefulWidget{
 final OfflineQueue queue;final RegionCatalog regions;final CustomerService service;final bool report;
 const FieldWorkPage({super.key,required this.queue,required this.regions,required this.service,this.report=false});
 @override State<FieldWorkPage> createState()=>_FieldWorkPageState();
}
class _FieldWorkPageState extends State<FieldWorkPage>{
 DateTime day=DateTime.now().toUtc().add(const Duration(hours:7));bool weekly=false,monthly=false;int period=0;String employee='',district='',status='';List<Map<String,dynamic>> rows=[];bool busy=false,cached=false;String? error;
 String get keyName=>widget.report?'report:${monthKey(day)}:${widget.service.province}':'routes-v2:${monthly?'month':weekly?'week':'day'}:${dayKey(day)}:${widget.service.province}';
 int previousPending=0;
 String _queueSignature='';
 String _signature(){
  final pending=widget.queue.pending;
  return '${pending.length}:${widget.queue.quarantined}:${widget.queue.error}:'
   '${[for(final p in pending) '${p['key']}:${p['status']}:${p['error']}'].join('|')}';
 }
 @override void initState(){
  super.initState();
  previousPending=widget.queue.pending.length;
  _queueSignature=_signature();
  widget.queue.addListener(queueChanged);
  load();
 }
 // Sync progress with unchanged rows must not rebuild every route/card/control.
 void queueChanged(){
  if(!mounted)return;
  final n=widget.queue.pending.length;
  if(n<previousPending&&!busy)unawaited(load());
  previousPending=n;
  final signature=_signature();
  if(_queueSignature!=signature){
   _queueSignature=signature;
   setState((){});
  }
 }
 @override void dispose(){widget.queue.removeListener(queueChanged);super.dispose();}
 Future<void> load()async{
  if(busy)return;
  setState((){busy=true;error=null;});
  try{
   final uri=widget.queue.session.uri(widget.report?'/api/v1/reports/monthly':'/api/v1/routes').replace(queryParameters:{widget.report?'month':'day':widget.report?monthKey(day):dayKey(day),'province':widget.service.province,if(!widget.report)'period':monthly?'month':weekly?'week':'day'});
   final data=decodeApi(await http.get(uri,headers:widget.service.headers).timeout(const Duration(seconds:20)));
   final list=(data['items'] as List).map((e)=>Map<String,dynamic>.from(e as Map)).toList();
   await widget.queue.cache(keyName,list);
   if(mounted)setState((){rows=list;cached=false;if(!rows.any((r)=>r['owner_sub']==employee))employee='';if(!rows.any((r)=>r['district']==district))district='';});
  }catch(e){
   if(e is ApiFailure&&(e.status==401||e.status==403)){if(mounted)setState(()=>rows=[]);}
   else{try{final list=await widget.queue.cached(keyName);if(mounted)setState((){rows=list;cached=true;});}catch(_){}}
   if(mounted)setState(()=>error=e.toString());
  }finally{if(mounted)setState(()=>busy=false);}
 }
 Future<void> chooseDate()async{final d=await showDatePicker(context:context,initialDate:day,firstDate:DateTime(2020),lastDate:DateTime(2100));if(d!=null&&mounted){setState((){day=d;rows=[];employee='';district='';});await load();}}
 String get templateKey=>'fixed-route-v1:${widget.service.province}';
 String get startDate=>monthly?dayKey(DateTime(day.year,day.month,1)):weekly?dayKey(monday):dayKey(day);
 String get endDate=>monthly?dayKey(monthEnd(day)):weekly?dayKey(monday.add(const Duration(days:6))):dayKey(day);
 bool inRange(String date)=>date.compareTo(startDate)>=0&&date.compareTo(endDate)<=0;
 void notify(String message){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(message)));}
 Future<void> bulkPlan({List<Map<String,dynamic>>? source})async{
  try{
   // Open the planner immediately: fetching permission-scoped customers does
   // not block the first animation frame of its dialog.
   final available=()async{
    List<FieldCustomer> customers;
    try{
     customers=await widget.service.list();
     unawaited(widget.queue.cache('customers:${widget.service.province}',
       customers.map((c)=>c.toJson()).toList()).catchError((_){ }));
    }catch(e){
     if(e is ApiFailure&&(e.status==401||e.status==403))rethrow;
     customers=(await widget.queue.cached('customers:${widget.service.province}'))
       .map(FieldCustomer.fromJson).toList();
    }
    return customers.where((c)=>c.owner==widget.queue.identity&&
      (district.isEmpty||c.district==district)).toList();
   }();
   if(!mounted)return;
   final choice=await showDialog<SalesBulkCustomerSelection>(
    context:context,
    builder:(_)=>SalesBulkCustomerPicker(
     customers:available,
     initialDate:day,
     copying:source!=null,
     preselectedIds:[
      for(final entry in source??<Map<String,dynamic>>[])
       entry['customer_id'].toString(),
     ],
    ),
   );
   if(choice==null||!mounted)return;
   final date=choice.date,customers=choice.customers,selected=choice.selected;
   final key=dayKey(date);
   List<Map<String,dynamic>> existing;
   final cacheKey='routes-v2:day:$key:${widget.service.province}';
   try{final data=decodeApi(await http.get(widget.queue.session.uri('/api/v1/routes').replace(queryParameters:{'day':key,'province':widget.service.province,'period':'day'}),headers:widget.service.headers).timeout(const Duration(seconds:20)));
    existing=(data['items'] as List).map((e)=>Map<String,dynamic>.from(e as Map)).toList();await widget.queue.cache(cacheKey,existing);
   }catch(e){if(e is ApiFailure&&(e.status==401||e.status==403))rethrow;existing=await widget.queue.cached(cacheKey);if(existing.isEmpty)throw StateError('Chưa có dữ liệu tuyến ngày đích trên máy. Tải ngày đích trước khi lập offline.');}
   final occupied=<String>{for(final r in existing)if(r['planned']==true&&r['owner_sub']==widget.queue.identity)r['customer_id'].toString()};
   var order=existing.where((r)=>r['planned']==true&&r['owner_sub']==widget.queue.identity).fold<int>(0,(n,r){final v=int.tryParse((r['data'] as Map)['sequence'].toString())??0;return v>n?v:n;});
   for(final row in widget.queue.pending){final p=row['payload'] as Map,d=p['data'];if(d is Map&&d['plannedDate']==key&&d['customerId']!=null){occupied.add(d['customerId'].toString());final n=int.tryParse(d['sequence'].toString())??0;if(n>order)order=n;}}
   final fresh=selected.where((id)=>!occupied.contains(id)).toList();
   if(fresh.isEmpty){notify('Không có điểm mới; khách đã có lịch được giữ nguyên.');return;}
   if(order+fresh.length>9999)throw StateError('Vượt giới hạn thứ tự điểm ghé');
   if(!mounted)return;
   final records=<Map<String,dynamic>>[];
   for(final id in fresh){final c=customers.firstWhere((c)=>c.id==id);records.add({'client_ref':const Uuid().v4(),'kind':'visit','province':c.province,'district':c.district,'customer_name':c.name,'data':{'customerId':id,'plannedDate':key,'sequence':++order,'purpose':''}});}
   final confirm=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:Text('Xác nhận tuyến $key'),content:SizedBox(width:440,child:ListView(shrinkWrap:true,children:[Text('${records.length} điểm mới · bỏ qua ${selected.length-fresh.length} điểm trùng. Không sửa lịch cũ.'),for(final r in records)ListTile(title:Text(r['customer_name'].toString()),leading:Text('${(r['data'] as Map)['sequence']}'))])),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Hủy')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Lưu tuyến'))]));
   if(confirm!=true||!mounted)return;
   await widget.queue.enqueueRouteBatch(records);notify('Đã lưu ${records.length} điểm trên máy · chờ đồng bộ');await load();
  }catch(e){notify('Không lưu được tuyến: $e');}
 }
 List<Map<String,dynamic>> get ownDayStops=>rows.where((r)=>r['planned']==true&&r['owner_sub']==widget.queue.identity&&(r['data'] as Map)['plannedDate']==dayKey(day)&&(district.isEmpty||r['district']==district)).toList();
 Future<void> saveTemplate()async{
  final stops=ownDayStops;if(stops.isEmpty){notify('Chọn ngày có tuyến của mình trước.');return;}
  try{await widget.queue.cache(templateKey,stops.map((r)=><String,dynamic>{'customer_id':r['customer_id'],'name':r['name']}).toList());notify('Đã lưu mẫu tuyến cố định trên thiết bị này.');}catch(e){notify(e.toString());}
 }
 Future<void> useTemplate()async{
  try{final list=await widget.queue.cached(templateKey);if(list.isEmpty){notify('Chưa có mẫu tuyến trên thiết bị này.');return;}await bulkPlan(source:list);}catch(e){notify(e.toString());}
 }
 Future<void> addStop()async{
  try{
   // Push the picker on the same tap. Network/cache lookup runs inside the
   // already-visible dialog rather than delaying its opening by 7–20 seconds.
   final available=()async{
    List<FieldCustomer> customers;
    try{
     customers=await widget.service.list();
     // Local persistence is background work, never a delay before showing rows.
     unawaited(widget.queue.cache('customers:${widget.service.province}',
       customers.map((c)=>c.toJson()).toList()).catchError((_){ }));
    }catch(e){
     if(e is ApiFailure&&(e.status==401||e.status==403))rethrow;
     customers=(await widget.queue.cached('customers:${widget.service.province}'))
       .map(FieldCustomer.fromJson).toList();
    }
    return customers.where((c)=>c.owner==widget.queue.identity).toList();
   }();
   if(!mounted)return;
   final selected=await showDialog<FieldCustomer>(
     context:context,
     builder:(_)=>SalesStopCustomerPicker(customers:available),
   );
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
 DateTime get monday=>weekMonday(day);
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
  final pending=widget.queue.pending.where((r){final p=r['payload'] as Map;final d=p['data'];return (p['kind']=='visit'||r['method']=='PATCH'&&d is Map&&d['customerId']!=null&&d['plannedDate']!=null)&&d is Map&&inRange(d['plannedDate'].toString())&&(employee.isEmpty||employee==widget.queue.identity)&&(widget.service.province.isEmpty||p['province']==widget.service.province||r['method']=='PATCH');}).toList();
  final filtered=rows.where((r)=>(employee.isEmpty||r['owner_sub']==employee)&&(district.isEmpty||r['district']==district)).toList();
  final people=<String,String>{for(final r in rows)if(r['owner_sub']!=null)r['owner_sub'].toString():r['full_name']?.toString()??''};
  final districts=rows.map((r)=>r['district']?.toString()??'').where((d)=>d.isNotEmpty).toSet().toList()..sort();
  final unique=<String,Map<String,dynamic>>{for(final r in filtered)r['customer_id'].toString():r};
  final planned=filtered.where((r)=>r['planned']==true).toList();
  final done=planned.where((r)=>r['visited']==true).length;
  final visited=unique.values.where((r)=>r['visited_period']==true).length;
  final completed=unique.values.fold<int>(0,(n,r)=>n+(int.tryParse(r['completed_sessions'].toString())??0));
  final visible=filtered.where((r)=>(!monthly||period==0||r['planned']!=true||planningPeriod(DateTime.parse((r['data'] as Map)['plannedDate'].toString()))==period)&&(status.isEmpty||status=='planned'&&r['planned']==true||status=='visited'&&r['visited_period']==true||status=='unvisited'&&r['visited_period']!=true)).toList();
  return ListView(padding:const EdgeInsets.only(bottom:12),children:[
   Padding(padding:const EdgeInsets.all(12),child:Row(children:[Expanded(child:Text(widget.report?'Báo cáo tháng':'Tuyến đi',style:Theme.of(context).textTheme.titleLarge)),IconButton(onPressed:busy?null:load,icon:const Icon(Icons.sync)),if(!widget.report)FilledButton.icon(onPressed:busy?null:addStop,icon:const Icon(Icons.add),label:const Text('Điểm ghé'))])),
   Padding(padding:const EdgeInsets.symmetric(horizontal:12),child:OutlinedButton.icon(onPressed:busy?null:chooseDate,icon:const Icon(Icons.calendar_today),label:Text(widget.report?monthKey(day):dayKey(day)))),
   if(!widget.report)...[
    SegmentedButton<String>(segments:const [ButtonSegment(value:'day',label:Text('Ngày')),ButtonSegment(value:'week',label:Text('Tuần')),ButtonSegment(value:'month',label:Text('Tháng'))],selected:{monthly?'month':weekly?'week':'day'},onSelectionChanged:busy?null:(v){setState((){monthly=v.first=='month';weekly=v.first=='week';period=0;rows=[];employee='';district='';});load();}),
    if(monthly)Padding(padding:const EdgeInsets.all(8),child:Column(children:[const Text('5 kỳ: 1–7 · 8–14 · 15–21 · 22–28 · 29–cuối tháng (không phải tuần lịch)'),Wrap(spacing:6,children:[for(var i=0;i<=5;i++)ChoiceChip(label:Text(i==0?'Tất cả':'Kỳ $i'),selected:period==i,onSelected:busy?null:(_)=>setState(()=>period=i))]),if(period>0&&periodDays(day,period).isEmpty)const Text('Tháng này không có ngày trong kỳ 5.')])),
    Padding(padding:const EdgeInsets.all(8),child:Wrap(spacing:8,runSpacing:6,children:[
     FilledButton(onPressed:busy?null:()=>bulkPlan(),child:const Text('Lập nhiều khách')),
     OutlinedButton(onPressed:busy||ownDayStops.isEmpty?null:()=>bulkPlan(source:ownDayStops),child:const Text('Sao chép ngày')),
     OutlinedButton(onPressed:busy||ownDayStops.isEmpty?null:saveTemplate,child:const Text('Lưu mẫu')),
     OutlinedButton(onPressed:busy?null:useTemplate,child:const Text('Dùng mẫu')),
    ])),
    if(weekly)Text('${dayKey(monday)} – ${dayKey(monday.add(const Duration(days:6)))}'),
    Padding(padding:const EdgeInsets.all(8),child:Column(children:[
      if(people.length>1)DropdownButtonFormField<String>(initialValue:people.containsKey(employee)?employee:'',decoration:const InputDecoration(labelText:'Nhân viên'),items:[const DropdownMenuItem(value:'',child:Text('Tất cả trong quyền')),for(final e in people.entries)DropdownMenuItem(value:e.key,child:Text(e.value))],onChanged:(v)=>setState(()=>employee=v??'')),
      Row(children:[Expanded(child:DropdownButtonFormField<String>(key:ValueKey(districts.join('|')),initialValue:districts.contains(district)?district:'',isExpanded:true,decoration:const InputDecoration(labelText:'Huyện'),items:[const DropdownMenuItem(value:'',child:Text('Tất cả')),for(final d in districts)DropdownMenuItem(value:d,child:Text(d,overflow:TextOverflow.ellipsis))],onChanged:(v)=>setState(()=>district=v??''))),const SizedBox(width:8),Expanded(child:DropdownButtonFormField<String>(initialValue:status,decoration:const InputDecoration(labelText:'Trạng thái'),items:const [DropdownMenuItem(value:'',child:Text('Tất cả')),DropdownMenuItem(value:'planned',child:Text('Có lịch')),DropdownMenuItem(value:'visited',child:Text('Đã ghé trong kỳ')),DropdownMenuItem(value:'unvisited',child:Text('Chưa ghé trong kỳ'))],onChanged:(v)=>setState(()=>status=v??'')))]),
      const SizedBox(height:8),Text('Toàn ${monthly?'tháng':weekly?'tuần':'ngày'}: điểm theo lịch đã ghé $done/${planned.length} · Khách duy nhất đã ghé $visited/${unique.length} · Phiên hoàn thành $completed'),
      if(planned.isNotEmpty)LinearProgressIndicator(value:done/planned.length),
    ])),
   ],
   if(busy)const LinearProgressIndicator(),
   if(error!=null)Padding(padding:const EdgeInsets.all(8),child:Text(cached?'Dữ liệu lưu máy · chưa cập nhật: $error':error!)),
   Padding(padding:const EdgeInsets.all(12),child:Column(children:[
    if(widget.report)...[
     const Text('Chỉ tiêu ≠ dự kiến ≠ doanh thu thực thu. Số liệu theo tháng và phạm vi quyền; chỉ tiêu chung không phân bổ tự động cho tỉnh.'),
     for(final r in rows)Card(child:ListTile(title:Text('${r['full_name']} · ${r['province']??'Chung'}'),subtitle:Text('Chỉ tiêu: ${money(r['target'])}\nDự kiến 5 tuần: ${money(r['forecast'])}\nCheck-in đã xác minh: ${r['checkins']} · ${r['forecasts']} dự kiến'))),
    ]else...[
     for(final r in pending)Card(child:ListTile(leading:const Icon(Icons.cloud_upload_outlined),title:Text((r['payload'] as Map)['customer_name']?.toString()??'Thay đổi tuyến'),subtitle:Text(r['error']?.toString()??'Đã lưu máy · chờ đồng bộ'))),
     for(final r in visible)Card(child:ListTile(leading:r['category']==null
        ?CircleAvatar(child:Text(r['planned']==true?'${(r['data'] as Map)['sequence']??''}':'–'))
        :Stack(clipBehavior:Clip.none,children:[
          CustomerCategoryAvatar(category:r['category']?.toString()),
          Positioned(bottom:-5,right:-5,child:CircleAvatar(radius:10,
            backgroundColor:Theme.of(context).colorScheme.surfaceContainerHighest,
            child:Text(r['planned']==true?'${(r['data'] as Map)['sequence']??''}':'–',
              style:Theme.of(context).textTheme.labelSmall))),
        ]),title:Text(r['name'].toString()),subtitle:Text('${r['full_name']} · ${r['district']}, ${r['province']}\n${r['planned']==true?'${(r['data'] as Map)['plannedDate']} · ${r['visited']==true?'Đã ghé':'Chưa ghé theo lịch'}':'Chưa lên lịch'} · ${r['visited_period']==true?'Đã ghé trong kỳ':'Chưa ghé trong kỳ'}\nLần gần nhất: ${r['last_visit']==null?'Chưa có':DateTime.tryParse(r['last_visit'].toString())?.toLocal().toString().substring(0,16)??''}'),trailing:r['planned']==true&&r['visited']!=true&&r['owner_sub']==widget.queue.identity?IconButton(tooltip:'Sửa tuyến',icon:const Icon(Icons.edit_outlined),onPressed:()=>editStop(r)):const Icon(Icons.chevron_right),onTap:()=>openCustomer(r))),
    ],
    if(rows.isEmpty&&(widget.report||pending.isEmpty))const Padding(padding:EdgeInsets.all(18),child:Text('Chưa có dữ liệu trong kỳ đã chọn.')),
   ]))
  ]);
 }
}

/// The route picker appears on the first frame even if the account-scoped
/// customer query is still pending. It never makes unauthorised data visible:
/// a 401/403 from the server does not fall back to the offline cache.
class SalesStopCustomerPicker extends StatelessWidget {
 final Future<List<FieldCustomer>> customers;
 const SalesStopCustomerPicker({super.key,required this.customers});
 @override Widget build(BuildContext context)=>AlertDialog(
  title:const Text('Chọn điểm ghé'),
  content:SizedBox(width:440,height:420,
   child:FutureBuilder<List<FieldCustomer>>(
    future:customers,
    builder:(context,snapshot){
     if(snapshot.connectionState!=ConnectionState.done){
      return const Center(child:Column(mainAxisSize:MainAxisSize.min,children:[
       CircularProgressIndicator(),
       SizedBox(height:16),
       Text('Đang mở danh sách khách hàng…'),
      ]));
     }
     if(snapshot.hasError){
      return const Center(child:Text(
       'Không tải được danh sách khách hàng. Kiểm tra kết nối và thử lại.'));
     }
     final items=snapshot.data??[];
     if(items.isEmpty)return const Center(child:Text(
       'Chưa có khách hàng trong phạm vi được cấp.'));
     return ListView.builder(
      itemCount:items.length,
      itemBuilder:(context,index){
       final item=items[index];
       return ListTile(
        leading:CustomerCategoryAvatar(category:item.category),
        title:Text(item.name,maxLines:2,overflow:TextOverflow.ellipsis),
        subtitle:Text('${item.district}, ${item.province}',
         maxLines:1,overflow:TextOverflow.ellipsis),
        onTap:()=>Navigator.pop(context,item),
       );
      },
     );
    },
   )),
  actions:[TextButton(onPressed:()=>Navigator.pop(context),
   child:const Text('Đóng'))],
 );
}

/// Selection carries exactly the account- and district-filtered customer rows
/// used for the preview; order remains the tap order, not an implicit sorting.
class SalesBulkCustomerSelection {
 final DateTime date;
 final List<FieldCustomer> customers;
 final List<String> selected;
 const SalesBulkCustomerSelection(this.date,this.customers,this.selected);
}

/// Render the multi-stop planner before network data arrives. No data from a
/// denied request is displayed; offline fallback is still scoped by the queue.
class SalesBulkCustomerPicker extends StatefulWidget {
 final Future<List<FieldCustomer>> customers;
 final DateTime initialDate;
 final bool copying;
 final List<String> preselectedIds;
 const SalesBulkCustomerPicker({
  super.key,required this.customers,required this.initialDate,
  this.copying=false,this.preselectedIds=const [],
 });
 @override State<SalesBulkCustomerPicker> createState()=>_SalesBulkCustomerPickerState();
}
class _SalesBulkCustomerPickerState extends State<SalesBulkCustomerPicker> {
 late final Future<List<FieldCustomer>> _available;
 late DateTime date;
 final selected=<String>[];
 @override void initState(){
  super.initState();
  date=widget.initialDate;
  // The FutureBuilder rebuilds after the allowed preselection is ready.
  _available=widget.customers.then((rows){
   for(final id in widget.preselectedIds){
    if(rows.any((c)=>c.id==id)&&!selected.contains(id))selected.add(id);
   }
   return rows;
  });
 }
 @override Widget build(BuildContext context)=>FutureBuilder<List<FieldCustomer>>(
  future:_available,
  builder:(context,snapshot){
   final customers=snapshot.data??<FieldCustomer>[];
   return AlertDialog(
    title:Text(widget.copying?'Xem trước tuyến sao chép':'Lập tuyến nhiều khách'),
    content:SizedBox(width:460,height:440,child:
     snapshot.connectionState!=ConnectionState.done
      ?const Center(child:Column(mainAxisSize:MainAxisSize.min,children:[
        CircularProgressIndicator(),SizedBox(height:16),
        Text('Đang mở danh sách khách hàng…'),
       ]))
      :snapshot.hasError
       ?const Center(child:Text('Không tải được khách hàng. Kiểm tra mạng rồi thử lại.'))
       :Column(children:[
        OutlinedButton.icon(
         onPressed:()async{
          final chosen=await showDatePicker(context:context,
           initialDate:date,firstDate:DateTime(2020),lastDate:DateTime(2100));
          if(chosen!=null&&mounted)setState(()=>date=chosen);
         },
         icon:const Icon(Icons.calendar_today),
         label:Text('${dayKey(date)} · Kỳ ${planningPeriod(date)}'),
        ),
        Text('${selected.length} khách · thứ tự theo thứ tự chọn'),
        Expanded(child:ListView.builder(
         itemCount:customers.length,
         itemBuilder:(context,index){
          final customer=customers[index];
          final position=selected.indexOf(customer.id);
          return CheckboxListTile(
           value:position>=0,
           title:Text(customer.name),
           subtitle:Text('${customer.district}, ${customer.province}'),
           secondary:Stack(clipBehavior:Clip.none,children:[
             CustomerCategoryAvatar(category:customer.category),
             if(position>=0)Positioned(bottom:-5,right:-5,child:CircleAvatar(
               radius:10,child:Text('${position+1}',style:const TextStyle(fontSize:10)))),
           ]),
           onChanged:(checked)=>setState((){
            if(checked==true){
             if(!selected.contains(customer.id))selected.add(customer.id);
            }else{
             selected.remove(customer.id);
            }
           }),
          );
         })),
       ])),
    actions:[
     TextButton(onPressed:()=>Navigator.pop(context),child:const Text('Hủy')),
     FilledButton(
      onPressed:snapshot.hasData&&selected.isNotEmpty
       ?()=>Navigator.pop(context,SalesBulkCustomerSelection(
         date,customers,List<String>.of(selected)))
       :null,
      child:const Text('Xem trước'),
     ),
    ],
   );
  });
}
