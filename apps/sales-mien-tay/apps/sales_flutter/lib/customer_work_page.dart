import 'dart:async';
 import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'customers.dart';
import 'models.dart';
import 'customer_categories.dart';
import 'offline_queue.dart';
import 'session.dart';
import 'orders.dart';
import 'survey_media.dart';

/// A visit is a set of independently auditable activities. The shop's stored
/// coordinates are never used as substitute for a live GPS fix. Opening a
/// customer is read-only; the route stop is materialized only on SAVE.
bool customerWorkRecorded(Iterable<Map<String,dynamic>> actions,String customerId)=>
 actions.any((a)=>a['customer_id']?.toString()==customerId &&
  ['form','photo','order'].contains(a['kind']?.toString()));

List<Map<String,dynamic>> pendingCustomerWork(OfflineQueue queue,String routeId)=>[
 for(final op in queue.pending)
  if(op['path']=='/api/v1/day-routes/$routeId/customer-work' &&
    op['payload'] is Map)
   {...Map<String,dynamic>.from(op['payload'] as Map),
    'sync_status':op['status'],'sync_error':op['error']},
];

class CustomerWorkPage extends StatefulWidget{
 final CustomerService service;
 final OfflineQueue queue;
 final Map<String,dynamic> route,customer;
 final Future<Map<String,dynamic>?> Function(Map<String,dynamic>) ensureStop;
 final List<String> Function() dependencies;
 final bool editable;
 final VoidCallback? onSaved;
 const CustomerWorkPage({super.key,required this.service,required this.queue,
  required this.route,required this.customer,required this.ensureStop,
  required this.dependencies,required this.editable,this.onSaved});
 @override State<CustomerWorkPage> createState()=>_CustomerWorkPageState();
}
class _CustomerWorkPageState extends State<CustomerWorkPage>{
 final note=TextEditingController();
 Map<String,dynamic>? profile;
 Map<String,dynamic>? template;
 Map<String,dynamic> answers={};
 List<Map<String,dynamic>> history=[];
 bool loading=true,saving=false,denied=false,brandsChecked=false;
 String? message;
 Future<void> pendingWrites=Future<void>.value();
 String get cid=>widget.customer['customer_id'].toString();
 String get routeId=>widget.route['id'].toString();
 String get draftKey=>'customer-work:$routeId:$cid';
 List<Map<String,dynamic>> get fields=>
   ((template?['questions'] as List?)??[])
    .map((q)=>Map<String,dynamic>.from(q as Map)).toList();
 bool get isToday{
  final d=DateTime.tryParse(widget.route['route_date']?.toString()??'');
  final today=DateTime.now().toUtc().add(const Duration(hours:7));
  return d!=null&&d.year==today.year&&d.month==today.month&&d.day==today.day;
 }
 bool get writable=>widget.editable&&isToday&&!denied;
 String get province=>profile?['province']?.toString()??
  widget.customer['customer_province']?.toString()??'';
 String get district=>profile?['district']?.toString()??
  widget.customer['customer_district']?.toString()??'';
 @override void initState(){super.initState();unawaited(load());}
 @override void dispose(){note.dispose();super.dispose();}
 void inform(String s){if(mounted)setState(()=>message=s);}
 Future<List<Map<String,dynamic>>> cache(String key)async{
  try{return await widget.queue.cached(key).timeout(const Duration(seconds:4));}
  catch(_){return [];}
 }
 Future<void> persistDraft(){
  final saved={'note':note.text,'answers':Map<String,dynamic>.from(answers),
  'brands_checked':brandsChecked};
  pendingWrites=pendingWrites.catchError((_){})
   .then((_)=>widget.queue.cache(draftKey,[saved]));
  return pendingWrites;
 }
 Future<void> load()async{
  setState(()=>loading=true);
  try{
   final drafts=await cache(draftKey);
   if(drafts.isNotEmpty&&mounted){
    final a=drafts.first['answers'];
    setState((){
     note.text=drafts.first['note']?.toString()??'';
     if(a is Map)answers=Map<String,dynamic>.from(a);
     brandsChecked=drafts.first['brands_checked']==true || answers['brands'] is List;
    });
   }
   final cached=await cache('customer-work-profile:$cid');
   if(cached.isNotEmpty&&mounted)setState(()=>profile=cached.first);
   try{
    final res=decodeApi(await http.get(widget.service.uri('/api/v1/customers/$cid'),
     headers:widget.service.headers).timeout(const Duration(seconds:15)));
    final data=Map<String,dynamic>.from(res['item'] as Map);
    if(mounted)setState(()=>profile=data);
    try{await widget.queue.cache('customer-work-profile:$cid',[data]);}catch(_){}
   }catch(e){
    if(e is ApiFailure&&(e.status==401||e.status==403)){
     if(mounted)setState((){denied=true;profile=null;});return;
    }
    inform('Hồ sơ đang dùng dữ liệu trên máy; chưa cập nhật từ máy chủ.');
   }
   final area=province;
   if(area.isNotEmpty){
    final key='survey-template:$area';
    var saved=await cache(key);
    if(saved.isNotEmpty&&mounted)setState(()=>template=saved.first);
    try{
     final res=decodeApi(await http.get(widget.service.uri(
      '/api/v1/survey-templates',{'province':area}),
      headers:widget.service.headers).timeout(const Duration(seconds:15)));
     final items=((res['items'] as List?)??[])
      .map((v)=>Map<String,dynamic>.from(v as Map)).toList();
     if(items.isNotEmpty){
      if(mounted)setState(()=>template=items.first);
      try{await widget.queue.cache(key,items);}catch(_){}
     }
    }catch(e){
     if(e is ApiFailure&&(e.status==401||e.status==403)){
      if(mounted)setState(()=>denied=true);
     }
    }
   }
   try{
    final res=decodeApi(await http.get(widget.service.uri(
     '/api/v1/day-routes/$routeId/customer-work'),
     headers:widget.service.headers).timeout(const Duration(seconds:12)));
    final values=((res['items'] as List?)??[])
     .map((v)=>Map<String,dynamic>.from(v as Map))
     .where((x)=>x['customer_id']?.toString()==cid).toList();
    if(mounted)setState(()=>history=values);
   }catch(_){
    // Assigned customers and offline drafts must remain available.
   }
  }finally{if(mounted)setState(()=>loading=false);}
 }
 void answer(String id,dynamic value){
  if(!writable||saving)return;
  setState((){
   answers={...answers,id:value};
   if(fields.any((q)=>q['id']==id&&q['catalog_source']=='brands'))brandsChecked=true;
  });
  unawaited(persistDraft().catchError((Object e){inform('Không lưu được nháp: $e');}));
 }
 bool get hasConfiguredBrands=>fields.any((f)=>f['catalog_source']=='brands');
 List<String> get chosenMarketBrands{
  final field=fields.where((q)=>q['catalog_source']=='brands').firstOrNull;
  if(field==null)return [];
  final selected=answers[field['id']];
  return selected is List?selected.map((x)=>x.toString()).toList():[];
 }
 List<String> get depKeys=>[
  ...widget.dependencies(),
  for(final op in widget.queue.pending)
   if(op['path']=='/api/v1/customers'&&
    (op['payload'] as Map?)?['client_ref']==cid) cid,
 ];
 Future<Map<String,dynamic>?> resolveStop()async{
  final stop=await widget.ensureStop(widget.customer);
  if(stop==null){inform('Chưa tạo được điểm làm việc. Dữ liệu nháp vẫn giữ nguyên.');}
  return stop;
 }
 List<String> dependenciesFor(Map<String,dynamic> stop)=>[
  ...depKeys,
  for(final op in widget.queue.pending)
   if((op['path']=='/api/v1/day-routes/$routeId/unplanned-stops'||
     op['path']=='/api/v1/day-routes/$routeId/stops')&&
     (op['payload'] as Map?)?['client_ref']==stop['id'])
    stop['id'].toString(),
 ];
 Future<void> record(String kind,{String noteText='',Map<String,dynamic>? form,
  List<String>? brands,List<String> additionalDeps=const []})async{
  if(!writable)return;
  setState(()=>saving=true);
  try{
   final stop=await resolveStop();
   if(stop==null)return;
   await widget.queue.enqueue('/api/v1/day-routes/$routeId/customer-work',{
    'client_ref':const Uuid().v4(),'kind':kind,'customer_id':cid,
    'route_stop_id':stop['id'],'template_id':template?['id'],
    'answers':form??<String,dynamic>{},
    'market_brands':brands,'note':noteText,
    'captured_at':DateTime.now().toUtc().toIso8601String(),
   },dependsOn:[...dependenciesFor(stop),...additionalDeps]);
   widget.onSaved?.call();
   if(mounted)setState(()=>message='Đã lưu hoạt động trên máy · đang chờ xác nhận đồng bộ.');
  }catch(e){inform('Không lưu được hoạt động: $e');}
  finally{if(mounted)setState(()=>saving=false);}
 }
 Future<void> saveForm()async{
  if(!writable||saving)return;
  final trimmed=note.text.trim();
  final selected=chosenMarketBrands;
  final hasAnswers=answers.values.any((v)=>v!=null&&v!=''&&
   (v is! List||v.isNotEmpty));
  if(trimmed.isEmpty&&!hasAnswers&&!brandsChecked){
   inform('Chọn một hạng mục hoặc nhập ghi chú để lưu lần ghé.');return;
  }
  try{await persistDraft();}catch(e){inform('Chưa lưu được nháp: $e');return;}
  await record('form',noteText:trimmed,form:Map<String,dynamic>.from(answers),
   brands:hasConfiguredBrands&&brandsChecked?selected:null);
 }
 Future<void> checkIn()async{
  if(!writable||saving)return;
  try{
   // Capture first; denied GPS must not fabricate a route stop.
   final pos=await captureGps(context);
   if(!pos.accuracy.isFinite||pos.accuracy<0||pos.accuracy>100){
    inform('GPS chưa đủ chính xác (tối đa 100m). Bấm thử lại tại cửa hàng.');
    return;
   }
   setState(()=>saving=true);
   final stop=await resolveStop();if(stop==null)return;
   await widget.queue.enqueue('/api/v1/customers/$cid/visits',{
    'client_ref':const Uuid().v4(),'route_stop_id':stop['id'],
    'latitude':pos.latitude,'longitude':pos.longitude,
    'accuracy_m':pos.accuracy,
    'captured_at':pos.timestamp.toUtc().toIso8601String(),
   },dependsOn:dependenciesFor(stop));
   widget.onSaved?.call();
   inform('Đã lưu GPS thực tế · chờ đồng bộ. Tọa độ cửa hàng không bị thay đổi.');
  }catch(e){inform('Không lấy được GPS thực tế: $e');}
  finally{if(mounted)setState(()=>saving=false);}
 }
 Future<void> photo()async{
  if(!writable||saving)return;
  try{
   final selected=await ImagePicker().pickImage(source:ImageSource.camera,
    maxWidth:1600,maxHeight:1600,imageQuality:80);
   if(selected==null)return;
   final media=compressSurveyMedia(await selected.readAsBytes());
   setState(()=>saving=true);
   final stop=await resolveStop();if(stop==null)return;
   final photoRef=const Uuid().v4();
   await widget.queue.enqueue('/api/v1/customers/$cid/photos',{
     'client_ref':photoRef,
   },photo:media.image,thumbnail:media.thumbnail,
    sha256:media.hash,thumbnailSha256:media.thumbnailHash,
    mime:'image/jpeg',dependsOn:dependenciesFor(stop));
   await record('photo',form:{'photo_id':photoRef},additionalDeps:[photoRef]);
   widget.onSaved?.call();
   inform('Ảnh tại cửa hàng đã lưu máy · chờ đồng bộ, chưa thay ảnh đại diện.');
  }catch(e){inform('Không lưu được ảnh: $e');}
  finally{if(mounted)setState(()=>saving=false);}
 }
 Future<void> openProfile()async{
  if(profile==null){
   inform('Hồ sơ khách chưa tải được. Bấm làm mới khi có mạng.');return;
  }
  final regions=await RegionCatalog.load();
  if(!mounted)return;
  await Navigator.push(context,MaterialPageRoute(builder:(_)=>CustomerDetail(
   service:widget.service,queue:widget.queue,
   customer:FieldCustomer.fromJson(profile!),regions:regions)));
 }
 Future<void> createOrder()async{
  final customer=profile;
  if(customer==null){inform('Chưa tải được khách để lập đơn.');return;}
  await Navigator.push(context,MaterialPageRoute(builder:(_)=>Scaffold(
   appBar:AppBar(title:const Text('Ra đơn tại khách')),
   body:OrdersPage(queue:widget.queue,admin:false,
    initialCustomer:{'id':cid,'name':customer['name'],
     'owner_sub':customer['owner_sub'],
     'field_code':customer['field_code'],
     'export_code':customer['code']},
    onOrderSaved:(orderId)async{
     await record('order',form:{'order_id':orderId},noteText:'Đã lưu đơn $orderId');
    }),
  )));
  if(mounted)setState((){});
 }
 Widget question(Map<String,dynamic> q){
  final key=q['id'].toString(),label=q['label']?.toString()??key;
  final value=answers[key];
  final options=((q['options'] as List?)??[]).map((x)=>x.toString()).toList();
  if(q['type']=='multi_choice'){
   final chosen=value is List?value.map((e)=>e.toString()).toList():<String>[];
   return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Text(label,style:Theme.of(context).textTheme.titleSmall),
    const SizedBox(height:6),
    Wrap(spacing:6,runSpacing:5,children:[
     for(final option in options)FilterChip(
      label:Text(option),selected:chosen.contains(option),
      onSelected:!writable||saving?null:(selected)=>answer(key,
       selected?[...chosen,option]:chosen.where((s)=>s!=option).toList())),
    ]),
   ]);
  }
  if(q['type']=='choice')return DropdownButtonFormField<String>(
    key:ValueKey('work-choice:$key:${template?['version']}'),
    initialValue:options.contains(value)?value as String:null,
    isExpanded:true,decoration:InputDecoration(labelText:label),
    items:[for(final s in options)DropdownMenuItem(value:s,child:Text(s,
      overflow:TextOverflow.ellipsis))],
    onChanged:!writable||saving?null:(s)=>answer(key,s));
  if(q['type']=='boolean')return SwitchListTile(
   contentPadding:EdgeInsets.zero,title:Text(label),value:value==true,
   onChanged:!writable||saving?null:(s)=>answer(key,s));
  return TextFormField(
   key:ValueKey('work-field:$key:${template?['version']}'),
   initialValue:value?.toString()??'',
   enabled:writable&&!saving,
   decoration:InputDecoration(labelText:label),
   maxLines:q['type']=='number'?1:2,
   keyboardType:q['type']=='number'?TextInputType.number:TextInputType.text,
   onChanged:(text)=>answer(key,q['type']=='number'?num.tryParse(text):text));
 }
 @override Widget build(BuildContext context){
  final customer=profile;
  final name=customer?['name']?.toString()??widget.customer['customer_name']?.toString()??'Khách hàng';
  final phone=customer?['phone']?.toString()??widget.customer['phone']?.toString();
  // The local roster is enough for safe navigation/calls offline. Never
  // dereference a missing server profile or expose actions after 403.
  final FieldCustomer? location=denied?null:FieldCustomer.fromJson(
   customer??{
    'id':cid,'owner_sub':widget.customer['owner_sub'],
    'name':name,'address_line':widget.customer['address_line']??'',
    'province':province,'district':district,
    'category':widget.customer['category']??'khac',
    'status':'active','phone':phone,
    'latitude':widget.customer['latitude'],
    'longitude':widget.customer['longitude'],
   });
  final activities=[...history,...pendingCustomerWork(widget.queue,routeId)
   .where((e)=>e['customer_id']?.toString()==cid)];
  final hasGps=widget.queue.pending.any((p)=>
   p['path']=='/api/v1/customers/$cid/visits'&&
   (p['payload'] as Map?)?['route_stop_id']!=null);
  return Scaffold(
   appBar:AppBar(title:const Text('Làm việc với khách'),actions:[
    IconButton(tooltip:'Làm mới',onPressed:loading||saving?null:load,
     icon:const Icon(Icons.refresh))]),
   body:ListView(padding:const EdgeInsets.all(12),children:[
    Text(name,style:Theme.of(context).textTheme.titleLarge),
    Text('${customer?['district']??district} · ${customer?['province']??province}',
     style:Theme.of(context).textTheme.bodySmall),
    const SizedBox(height:8),
    CustomerCategoryLabel(category:customer?['category']?.toString()??
     widget.customer['category']?.toString()),
    const SizedBox(height:10),
    Wrap(spacing:6,runSpacing:4,children:[
     OutlinedButton.icon(onPressed:openProfile,
      icon:const Icon(Icons.person_outline),label:const Text('Hồ sơ khách')),
     if(location!=null)IconButton.outlined(
      tooltip:'Chỉ đường',onPressed:()=>openCustomerDirections(context,location),
      icon:const Icon(Icons.directions_outlined)),
     IconButton.outlined(tooltip:'Gọi điện',
      onPressed:location==null||customerCallUri(phone)==null
       ?null:()=>openCustomerCall(context,location),
      icon:const Icon(Icons.call_outlined)),
     IconButton.outlined(tooltip:'Zalo',
      onPressed:location==null||customerZaloUri(phone)==null
       ?null:()=>openCustomerZalo(context,location),
      icon:const CustomerZaloMark()),
    ]),
    const SizedBox(height:12),
    if(loading)const LinearProgressIndicator(minHeight:2),
    if(denied)const Text('Quyền khách đã thay đổi. Không lưu hoặc hiện dữ liệu cũ.'),
    if(message!=null)Padding(padding:const EdgeInsets.all(8),
     child:Text(message!,style:Theme.of(context).textTheme.bodySmall)),
    Text(customerWorkRecorded(activities,cid)||hasGps?'Đã ghé · đã có hoạt động'
      :'Chưa ghi nhận hoạt động',
      style:Theme.of(context).textTheme.titleSmall),
    const SizedBox(height:10),
    if(template==null)const Text('Địa bàn chưa có mẫu hạng mục ghé khách. '
     'Admin cấu hình trong menu · Mẫu khảo sát; hiện có thể ghi chú/GPS/ảnh/đơn.'),
    if(template!=null)...[
     Text('Hạng mục theo cấu hình · mẫu v${template!['version']}',
      style:Theme.of(context).textTheme.titleMedium),
     const SizedBox(height:8),
     for(final q in fields)...[
      if(q['catalog_source']=='brands')...[
       CheckboxListTile(contentPadding:EdgeInsets.zero,
        title:const Text('Đã kiểm tra nhãn hàng tại khách'),
        subtitle:const Text('Chỉ cập nhật danh sách nhãn khi đã đánh dấu kiểm tra.'),
        value:brandsChecked,
        onChanged:!writable||saving?null:(checked){
         setState(()=>brandsChecked=checked==true);
         unawaited(persistDraft());
        }),
       if(brandsChecked)question(q),
      ]else question(q),
      const SizedBox(height:12),
     ],
    ],
    TextField(controller:note,enabled:writable&&!saving,
     maxLength:500,maxLines:2,
     decoration:const InputDecoration(labelText:'Ghi chú ngắn tại điểm bán',
      hintText:'Kết quả trao đổi, hẹn lại, nhu cầu…'),
     onChanged:(_)=>unawaited(persistDraft().catchError(
      (Object e){inform('Không lưu được nháp: $e');}))),
    FilledButton.icon(
     key:const ValueKey('customer-work-save'),
     onPressed:writable&&!saving?saveForm:null,
     icon:const Icon(Icons.save_outlined),
     label:const Text('Lưu thông tin tại khách')),
    const SizedBox(height:12),
    Wrap(spacing:8,runSpacing:8,children:[
     OutlinedButton.icon(key:const ValueKey('customer-work-gps'),
      onPressed:writable&&!saving?checkIn:null,
      icon:const Icon(Icons.my_location_outlined),
      label:const Text('Check-in GPS thực tế')),
     OutlinedButton.icon(key:const ValueKey('customer-work-photo'),
      onPressed:writable&&!saving?photo:null,
      icon:const Icon(Icons.photo_camera_outlined),
      label:const Text('Chụp ảnh cửa hàng')),
     OutlinedButton.icon(key:const ValueKey('customer-work-order'),
      onPressed:writable&&!saving?createOrder:null,
      icon:const Icon(Icons.shopping_cart_checkout),
      label:const Text('Ra đơn')),
    ]),
    const SizedBox(height:8),
    const Text('Ghi chú, nhãn hàng và nguồn hàng có thể lưu không cần GPS. '
     'GPS thực tế được lưu riêng để quản lý đối chiếu; không tự thay tọa độ cửa hàng.'),
    if(activities.isNotEmpty)...[
     const Divider(),
     Text('Lịch sử công việc (${activities.length})',
      style:Theme.of(context).textTheme.titleSmall),
     for(final a in activities.take(10))ListTile(
      dense:true,
      leading:Icon(a['kind']=='photo'?Icons.photo_camera_outlined:
       a['kind']=='order'?Icons.receipt_long_outlined:Icons.checklist_outlined),
      title:Text(a['kind']=='photo'?'Ảnh tại khách':
       a['kind']=='order'?'Đã ra đơn':'Thông tin / nhãn hàng'),
      subtitle:Text('${a['captured_at']??''} · '
       '${a['sync_status']??'Đã đồng bộ'}${a['note']?.toString().isNotEmpty==true?' · ${a['note']}':''}'),
     ),
    ],
   ]),
  );
 }
}
