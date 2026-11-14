import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'customers.dart';
import 'models.dart';
import 'offline_queue.dart';
import 'session.dart';
import 'survey_media.dart';
import 'work_session_identity.dart';

List<Map<String,dynamic>> routeTemplateStops(
 List<Map<String,dynamic>> stops,List<Map<String,dynamic>> pending
){
 final result=<Map<String,dynamic>>[];
 void add(Map<String,dynamic> s){
  final kind=s['stop_kind']?.toString();
  if(kind!='customer')return; // Scope context is never a template stop.
  result.add(<String,dynamic>{
   'stop_kind':kind,'sequence':(s['sequence'] as num).toInt(),
   'purpose':s['purpose']?.toString()??'',
   if(kind=='customer')'customer_id':s['customer_id'],
   if(kind=='area')...{'province':s['province'],'district':s['district']},
   if(kind=='chain')'chain_id':s['chain_id'],
  });
 }
 for(final s in stops)add(s);
 for(final op in pending){
  if(op['method']!='POST')continue;
  add(Map<String,dynamic>.from(op['payload'] as Map));
 }
 result.sort((a,b)=>(a['sequence'] as int).compareTo(b['sequence'] as int));
 return result;
}
String routeStopIdentity(Map<String,dynamic> stop){
 return switch(stop['stop_kind']){
  'customer'=>'customer:${stop['customer_id']}',
  'chain'=>'chain:${stop['chain_id']}',
  'area'=>'area:${stop['province']}:${stop['district']}',
  _=>'unknown',
 };
}

class RouteTemplatePage extends StatefulWidget{
 final OfflineQueue queue;
 final CustomerService service;
 final Map<String,dynamic> route;
 final List<Map<String,dynamic>> stops;
 const RouteTemplatePage({super.key,required this.queue,required this.service,
  required this.route,required this.stops});
 @override State<RouteTemplatePage> createState()=>_RouteTemplatePageState();
}
class _RouteTemplatePageState extends State<RouteTemplatePage>{
 List<Map<String,dynamic>> templates=[];
 bool loading=true;
 String? error;
 String get cacheKey=>'route-templates:${widget.queue.revision}';
 List<Map<String,dynamic>> get pendingStops=>widget.queue.pending.where((r)=>
   r['path']=='/api/v1/day-routes/${widget.route['id']}/stops').toList();
 List<Map<String,dynamic>> get usable=>[
  ...templates.where(scopeMatches),
  ...widget.queue.pending.where((r)=>r['path']=='/api/v1/route-templates')
   .map((r)=>Map<String,dynamic>.from(r['payload'] as Map))
   .where(scopeMatches),
 ];
 bool scopeMatches(Map<String,dynamic> data)=>
   data['scope_kind']==widget.route['scope_kind']&&data['scope_key']==widget.route['scope_key'];
 void note(String message){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(message)));}
 @override void initState(){super.initState();unawaited(load());}
 Future<void> load()async{
  setState((){loading=true;error=null;});
  try{
   final cached=await widget.queue.cached(cacheKey);
   if(mounted)setState(()=>templates=cached.where(scopeMatches).toList());
   final r=decodeApi(await http.get(widget.service.uri('/api/v1/route-templates'),
     headers:widget.service.headers).timeout(const Duration(seconds:20)));
   final all=(r['items'] as List).map((x)=>Map<String,dynamic>.from(x as Map)).toList();
   await widget.queue.cache(cacheKey,all);
   if(mounted)setState(()=>templates=all.where(scopeMatches).toList());
  }catch(e){
   if(e is ApiFailure&&(e.status==401||e.status==403)){
    if(mounted)setState(()=>templates=[]);
   }
   if(mounted)setState(()=>error=e.toString());
  }finally{if(mounted)setState(()=>loading=false);}
 }
 Future<void> save({Map<String,dynamic>? previous})async{
  if(widget.route['owner_sub']!=widget.queue.identity)return;
  final existing=routeTemplateStops(widget.stops,pendingStops);
  if(existing.isEmpty){note('Tuyến chưa có điểm ghé để lưu mẫu.');return;}
  final input=TextEditingController(text:previous==null?'Mẫu tuyến mới':(previous['name']?.toString()??''));
  final name=await showDialog<String>(context:context,builder:(ctx)=>AlertDialog(
   title:Text(previous==null?'Lưu mẫu tuyến':'Cập nhật mẫu tuyến'),
   content:TextField(controller:input,maxLength:120,decoration:const InputDecoration(labelText:'Tên mẫu')),
   actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Hủy')),
    FilledButton(onPressed:()=>Navigator.pop(ctx,input.text.trim()),child:const Text('Lưu'))]));
  input.dispose();
  if(name==null)return;
  if(name.length<2){note('Tên mẫu từ 2 ký tự.');return;}
  final id=previous?['id']?.toString()??const Uuid().v4();
  final payload=<String,dynamic>{
   'client_ref':const Uuid().v4(),'name':name,
   'scope_kind':widget.route['scope_kind'],'scope_key':widget.route['scope_key'],
   'province':widget.route['scope_kind']=='territory'?widget.route['province']:null,
   'district':widget.route['scope_kind']=='territory'?widget.route['district']:null,
   'stops':existing,
   if(previous!=null)'version':previous['version'],
  };
  if(previous==null)payload['client_ref']=id;
  try{
   await widget.queue.enqueue(
    previous==null?'/api/v1/route-templates':'/api/v1/route-templates/$id',
    payload,method:previous==null?'POST':'PATCH');
   note('Đã lưu mẫu trên máy, sẽ đồng bộ phiên bản lên Neon.');
   if(mounted)await load();
  }catch(e){note('Không lưu được mẫu: $e');}
 }
 Future<void> apply(Map<String,dynamic> selected)async{
  if(widget.route['owner_sub']!=widget.queue.identity||widget.route['status']!='ready')return;
  if(widget.stops.any((s)=>((s['visit_count'] as num?)?.toInt()??0)>0||
      ((s['session_count'] as num?)?.toInt()??0)>0)){
   note('Tuyến đã ghé thực tế. Không áp mẫu làm thay đổi lịch sử.');return;
  }
  final raw=selected['stops'];
  if(raw is! List||raw.length>100)return;
  final records=raw.map((x)=>Map<String,dynamic>.from(x as Map))
    .where((x)=>x['stop_kind']=='customer').toList();
  final taken=<String>{
   for(final s in widget.stops)routeStopIdentity(s),
   for(final op in pendingStops)
    routeStopIdentity(Map<String,dynamic>.from(op['payload'] as Map)),
  };
  final fresh=<Map<String,dynamic>>[];
  for(final s in records){
   if(taken.add(routeStopIdentity(s)))fresh.add(s);
  }
  if(fresh.isEmpty){note('Các điểm trong mẫu đã có trên tuyến.');return;}
  var seq=1;
  for(final s in widget.stops){
   final n=(s['sequence'] as num?)?.toInt()??0;if(n>=seq)seq=n+1;
  }
  for(final p in pendingStops){
   final n=((p['payload'] as Map)['sequence'] as num?)?.toInt()??0;if(n>=seq)seq=n+1;
  }
  if(seq+fresh.length>10000){note('Tuyến vượt số điểm tối đa.');return;}
  final confirmed=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
   title:const Text('Áp dụng mẫu tuyến'),
   content:Text('Thêm ${fresh.length} điểm vào ngày ${widget.route['route_date'].toString().substring(0,10)}? Không tự sao chép check-in hay khảo sát.'),
   actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Hủy')),
    FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Thêm điểm'))]));
  if(confirmed!=true)return;
  final routePending=widget.queue.pending.any((r)=>
    r['path']=='/api/v1/day-routes'&&(r['payload'] as Map)['client_ref']==widget.route['id']);
  try{
   for(final stop in fresh){
    await widget.queue.enqueue('/api/v1/day-routes/${widget.route['id']}/stops',{
     ...stop,'client_ref':const Uuid().v4(),'sequence':seq++,
    },dependsOn:routePending?[widget.route['id'].toString()]:[]);
   }
   note('Đã thêm ${fresh.length} điểm · không sao chép GPS cũ.');
   if(mounted)Navigator.pop(context,true);
  }catch(e){note('Không áp được mẫu: $e');}
 }
 @override Widget build(BuildContext context)=>Scaffold(
  appBar:AppBar(title:const Text('Mẫu tuyến lưu trên Neon')),
  body:ListView(padding:const EdgeInsets.all(12),children:[
   const Text('Mẫu chỉ giữ danh sách điểm và thứ tự. Ngày tháng, GPS và khảo sát không được sao chép.'),
   const SizedBox(height:10),
   FilledButton.icon(onPressed:widget.route['owner_sub']==widget.queue.identity?()=>save():null,
    icon:const Icon(Icons.bookmark_add_outlined),label:const Text('Lưu tuyến hiện tại thành mẫu')),
   if(loading)const LinearProgressIndicator(),
   if(error!=null)Text(error!,style:TextStyle(color:Theme.of(context).colorScheme.error)),
   for(final t in usable)Card(child:ListTile(
    title:Text(t['name']?.toString()??'Mẫu tuyến'),
    subtitle:Text('${(t['stops'] as List?)?.length??0} điểm · phiên bản ${t['version']??'đang chờ'}'),
    trailing:Wrap(spacing:0,children:[
     if(t['owner_sub']==widget.queue.identity&&t['version']!=null)
      IconButton(tooltip:'Cập nhật mẫu',icon:const Icon(Icons.edit_outlined),
       onPressed:()=>save(previous:t)),
     IconButton(tooltip:'Sử dụng mẫu',icon:const Icon(Icons.playlist_add_outlined),
      onPressed:()=>apply(t)),
    ]),
   )),
   if(!loading&&usable.isEmpty)const Text('Chưa có mẫu tuyến nào cho khu vực hoặc chuỗi này.'),
  ]));
}

class AreaEvidencePage extends StatefulWidget{
 final OfflineQueue queue;
 final CustomerService service;
 final Map<String,dynamic> route;
 final Map<String,dynamic>? stop;
 const AreaEvidencePage({super.key,required this.queue,required this.service,
  required this.route,this.stop});
 @override State<AreaEvidencePage> createState()=>_AreaEvidencePageState();
}
class _AreaEvidencePageState extends State<AreaEvidencePage>{
 List<Map<String,dynamic>> visits=[],prospects=[];
 bool loading=false,offline=false;
 String? error;
 bool get routeMarket=>widget.stop==null;
 String get stopId=>widget.stop?['id']?.toString()??'';
 String get areaId=>routeMarket?widget.route['id'].toString():stopId;
 String get areaFilter=>routeMarket?'route_id':'stop_id';
 String get cacheVisit=>'area-visits:${areaFilter}:$areaId';
 String get cacheLead=>'area-prospects:${areaFilter}:$areaId';
 bool get own=>widget.route['owner_sub']==widget.queue.identity&&
  workSessionState(widget.route,widget.queue.pending)=='ongoing';
 List<Map<String,dynamic>> get queuedVisits=>widget.queue.pending.where((r)=>
  r['path']=='/api/v1/area-visits'&&
   (r['payload'] as Map)[routeMarket?'day_route_id':'day_route_stop_id']==areaId).toList();
 List<Map<String,dynamic>> get photoJobs=>widget.queue.pending.where((r)=>
  (r['path']?.toString()??'').startsWith('/api/v1/area-visits/')&&
  (r['path']?.toString()??'').endsWith('/photos')&&
  ([...visits.map((x)=>x['id'].toString()),...queuedVisits.map((x)=>(x['payload'] as Map)['client_ref'].toString())]
    .contains((r['path'] as String).split('/')[4]))).toList();
 @override void initState(){super.initState();unawaited(load());}
 void note(String message){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(message)));}
 Future<void> load()async{
  if(loading)return;
  setState((){loading=true;error=null;});
  try{
   final savedVisits=await widget.queue.cached(cacheVisit),
    savedLeads=await widget.queue.cached(cacheLead);
   if(mounted)setState((){visits=savedVisits;prospects=savedLeads;offline=true;});
   final results=await Future.wait([
    http.get(widget.service.uri('/api/v1/area-visits').replace(
     queryParameters:{areaFilter:areaId}),headers:widget.service.headers).timeout(const Duration(seconds:20)),
    http.get(widget.service.uri('/api/v1/prospects').replace(
     queryParameters:{areaFilter:areaId}),headers:widget.service.headers).timeout(const Duration(seconds:20)),
   ]);
   final a=decodeApi(results[0]),b=decodeApi(results[1]);
   final confirmed=(a['items'] as List).map((x)=>Map<String,dynamic>.from(x as Map)).toList(),
    realLeads=(b['items'] as List).map((x)=>Map<String,dynamic>.from(x as Map)).toList();
   await widget.queue.cache(cacheVisit,confirmed);
   await widget.queue.cache(cacheLead,realLeads);
   if(mounted)setState((){visits=confirmed;prospects=realLeads;offline=false;});
  }catch(e){
   if(e is ApiFailure&&(e.status==401||e.status==403)){
    await widget.queue.cache(cacheVisit,[]);
    await widget.queue.cache(cacheLead,[]);
    if(mounted)setState((){visits=[];prospects=[];offline=false;});
   }
   if(mounted)setState(()=>error=e.toString());
  }finally{if(mounted)setState(()=>loading=false);}
 }
 Future<void> capturePhoto(String visitId,{required bool pending})async{
  if(!own)return;
  final source=await showModalBottomSheet<ImageSource>(context:context,builder:(ctx)=>SafeArea(
   child:Wrap(children:[
    ListTile(leading:const Icon(Icons.camera_alt_outlined),title:const Text('Chụp ảnh thực địa'),
     onTap:()=>Navigator.pop(ctx,ImageSource.camera)),
    ListTile(leading:const Icon(Icons.photo_library_outlined),title:const Text('Chọn ảnh có sẵn'),
     onTap:()=>Navigator.pop(ctx,ImageSource.gallery)),
   ])));
  if(source==null)return;
  try{
   final x=await ImagePicker().pickImage(source:source,maxWidth:1600,imageQuality:85);
   if(x==null)return;
   final media=compressSurveyMedia(await x.readAsBytes());
   final id=const Uuid().v4();
   await widget.queue.enqueue('/api/v1/area-visits/$visitId/photos',{
    'client_ref':id,'kind':'front','captured_at':DateTime.now().toUtc().toIso8601String(),
   },photo:media.image,thumbnail:media.thumbnail,
    sha256:media.hash,thumbnailSha256:media.thumbnailHash,
    mime:'image/jpeg',dependsOn:pending?[visitId]:[]);
   note('Ảnh công tác đã lưu trên máy · sẽ tải lên kho R2 riêng tư.');
   if(mounted)setState((){});
  }catch(e){note('Không lưu được ảnh công tác: $e');}
 }
 Future<void> convert(Map<String,dynamic> p,String customerId)async{
  decodeApi(await http.post(widget.service.uri('/api/v1/prospects/${p['id']}/convert'),
   headers:widget.service.headers,body:jsonEncode({'customer_id':customerId}))
   .timeout(const Duration(seconds:25)));
  if(mounted)await load();
 }
 Future<void> createCustomer(Map<String,dynamic> lead)async{
  final regions=await RegionCatalog.load();
  if(!mounted)return;
  await Navigator.push(context,MaterialPageRoute(builder:(_)=>CustomerEditor(
   service:widget.service,regions:regions,prospect:lead,
   onCreated:(id)=>convert(lead,id),
  )));
  if(mounted)await load();
 }
 Future<void> attachCustomer(Map<String,dynamic> lead)async{
  try{
   final res=decodeApi(await http.get(widget.service.uri(
    '/api/v1/day-routes/${widget.route['id']}/candidates'),
     headers:widget.service.headers).timeout(const Duration(seconds:25)));
   final choices=(res['items'] as List).map((x)=>Map<String,dynamic>.from(x as Map)).toList();
   if(!mounted)return;
   if(choices.isEmpty){note('Chưa có khách trong khu vực, hãy tạo khách từ lead.');return;}
   final selected=await showDialog<String>(context:context,builder:(ctx)=>AlertDialog(
    title:const Text('Liên kết khách đã có'),
    content:SizedBox(width:440,height:350,child:ListView(children:[
     for(final c in choices)ListTile(title:Text(c['name'].toString()),
      subtitle:Text('${c['district']}, ${c['province']}'),
      onTap:()=>Navigator.pop(ctx,c['id'].toString()))
    ])),
    actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Đóng'))],
   ));
   if(selected==null)return;
   await convert(lead,selected);
   note('Đã liên kết lead với khách thật, giữ nguyên lịch sử GPS.');
  }catch(e){note('Không liên kết được lead: $e');}
 }
 @override Widget build(BuildContext context)=>Scaffold(
  appBar:AppBar(title:const Text('Công tác & tìm khách'),actions:[
   IconButton(tooltip:'Làm mới',onPressed:loading?null:load,icon:const Icon(Icons.refresh)),
  ]),
  body:ListView(padding:const EdgeInsets.all(12),children:[
   Text(routeMarket?'Thực địa · ${widget.route['scope_kind']=='chain'?'Chuỗi':'Địa bàn'}'
    :widget.stop?['stop_kind']=='chain'?'Công tác chuỗi':'Địa bàn tìm khách mới',
    style:Theme.of(context).textTheme.titleMedium),
   const SizedBox(height:5),
   Text('GPS thực địa gắn trực tiếp với ${routeMarket?'lịch công tác':'điểm ghé cũ'}; không tự tạo khách và không tự hoàn thành khảo sát.'),
   if(loading)const LinearProgressIndicator(),
   if(offline)const Text('Dữ liệu lưu trên máy · đang ngoại tuyến.'),
   if(error!=null)Text(error!,style:TextStyle(color:Theme.of(context).colorScheme.error)),
   for(final visit in [
    ...visits.map((x)=>{...x,'pending':false}),
    ...queuedVisits.map((x)=>{...(x['payload'] as Map),'id':(x['payload'] as Map)['client_ref'],'pending':true}),
   ])
    Card(child:Padding(padding:const EdgeInsets.all(10),child:Column(
     crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text('GPS: ${visit['captured_at']??visit['checkin_at']}',
       style:Theme.of(context).textTheme.titleSmall),
      Text('Ghi chú: ${visit['note']??''}'),
      Text('Ảnh xác nhận: ${visit['photo_count']??0} · ${visit['pending']==true?'Đang chờ đồng bộ':'Đã ghi trên server'}'),
      Align(alignment:Alignment.centerRight,
       child:TextButton.icon(onPressed:own?()=>capturePhoto(
        visit['id'].toString(),pending:visit['pending']==true):null,
        icon:const Icon(Icons.camera_alt_outlined),label:const Text('Thêm ảnh công tác'))),
     ]))),
   for(final op in photoJobs)ListTile(
    leading:const Icon(Icons.cloud_upload_outlined),
    title:const Text('Ảnh công tác đang chờ tải R2'),
    subtitle:Text(op['error']?.toString()??'Đã lưu máy'),
    trailing:op['status']=='blocked'?IconButton(icon:const Icon(Icons.refresh),
     tooltip:'Đồng bộ lại',onPressed:()=>widget.queue.retryBlocked(op['key'].toString())):null),
   const Divider(),
   Text('Lead tìm được',style:Theme.of(context).textTheme.titleMedium),
   if(prospects.isEmpty)const Padding(padding:EdgeInsets.all(8),
    child:Text('Chưa có lead xác nhận. Quay về lịch công tác và chọn Tìm khách mới để ghi nhận GPS.')),
   for(final p in prospects)Card(child:ListTile(
    title:Text(p['name'].toString()),
    subtitle:Text('${p['address_line']}\n${p['status']=='converted'?'Đã liên kết khách thật':'Chưa chuyển thành khách'}'),
    isThreeLine:true,
    trailing:p['status']=='converted'?const Icon(Icons.check_circle_outline):
     PopupMenuButton<String>(tooltip:'Chuyển lead thành khách',
      onSelected:(value){if(value=='new'){unawaited(createCustomer(p));}
       else{unawaited(attachCustomer(p));}},
      itemBuilder:(_)=>const [
       PopupMenuItem(value:'new',child:Text('Tạo khách thật từ lead')),
       PopupMenuItem(value:'existing',child:Text('Liên kết khách đã có')),
      ]),
   )),
   if(prospects.isEmpty&&queuedVisits.any((r)=>(r['payload'] as Map)['prospect']!=null))
    const Text('Đã có lead lưu máy, sẽ xuất hiện sau khi đồng bộ GPS.'),
  ]),
 );
}
