import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'customers.dart';
import 'customer_categories.dart';
import 'responsive_controls.dart';
import 'field_work.dart';
import 'models.dart';
import 'offline_queue.dart';
import 'session.dart';
import 'survey_media.dart';

const photoLabels={'front':'Mặt tiền','shelf':'Quầy kệ','goods':'Hàng hóa','other':'Ảnh khác'};
DateTime vnToday()=>DateTime.now().toUtc().add(const Duration(hours:7));
Map<String,dynamic> asMap(dynamic v)=>Map<String,dynamic>.from(v as Map);
List<Map<String,dynamic>> asRows(dynamic v)=>(v as List? ?? []).map(asMap).toList();
String surveyStatus(Map<String,dynamic> s){
 if(s['server_status']=='completed'||s['status']=='completed')return 'Hoàn thành';
 if(s['status']=='completed_pending')return 'Chờ xác minh hoàn thành';
 if(s['server_status']=='in_progress'||s['status']=='in_progress'&&s['start_op']==null)return s['location_initialized']==true?'Đang khảo sát · tọa độ lần đầu đã ghi nhận':'Đang khảo sát · GPS đã xác minh';
 return 'Đang khảo sát · GPS chờ đồng bộ';
}
String? checklistError(List<Map<String,dynamic>> qs,Map<String,dynamic> answers){
 for(final q in qs){
  final v=answers[q['id']];
  if(v==null||v is String&&v.trim().isEmpty||q['type']=='multi_choice'&&v is List&&v.isEmpty){if(q['required']==true)return 'Thiếu: ${q['label']}';continue;}
  if(q['type']=='number'&&(v is! num||!v.isFinite||v<0)||q['type']=='boolean'&&v is! bool||q['type']=='choice'&&!(q['options'] as List).contains(v)||q['type']=='multi_choice'&&(v is! List||v.length>50||v.toSet().length!=v.length||v.any((x)=>x is! String||!(q['options'] as List).contains(x)))||q['type']=='text'&&(v is! String||v.length>2000))return 'Không hợp lệ: ${q['label']}';
 }
 return null;
}
Future<Map<String,dynamic>> surveyGet(CustomerService service,String path,[Map<String,String>? params])async=>decodeApi(await http.get(service.uri(path,params),headers:service.headers).timeout(const Duration(seconds:20)));

class SurveyPage extends StatefulWidget{
 final OfflineQueue queue;final CustomerService service;final RegionCatalog regions;final bool admin;final String? initialCustomer;final WidgetBuilder? legacy;
 const SurveyPage({super.key,required this.queue,required this.service,required this.regions,this.admin=false,this.initialCustomer,this.legacy});
 @override State<SurveyPage> createState()=>_SurveyPageState();
}
class _SurveyPageState extends State<SurveyPage>{
 DateTime day=vnToday();bool weekly=false,all=false,busy=false;String district='',employee='';String? error;
 List<Map<String,dynamic>> routes=[],sessions=[],drafts=[];
 int lastPending=0;
 @override void initState(){super.initState();all=widget.initialCustomer!=null;lastPending=widget.queue.pending.length;widget.queue.addListener(changed);load();}
 @override void dispose(){widget.queue.removeListener(changed);super.dispose();}
 void changed(){if(!mounted)return;final n=widget.queue.pending.length;if(n<lastPending&&!busy){unawaited(load());}else{unawaited(readDrafts());}lastPending=n;}
 Future<void> readDrafts()async{try{final d=await widget.queue.cached('survey-drafts');if(mounted)setState(()=>drafts=d);}catch(_){}}
 Future<List<Map<String,dynamic>>> list(String path,Map<String,String> params,String key)async{
  try{final data=await surveyGet(widget.service,path,params);final rows=asRows(data['items']);await widget.queue.cache(key,rows);if(data['truncated']==true)error='Có hơn 500 phiên; hãy chọn ngày hoặc địa bàn hẹp hơn.';return rows;}
  catch(e){if(e is ApiFailure&&(e.status==401||e.status==403))rethrow;error='Dữ liệu lưu máy · chưa cập nhật';return widget.queue.cached(key);}
 }
 Future<void> load()async{
  if(busy)return;setState((){busy=true;error=null;});
  final period=weekly?'week':'day',key='${widget.service.province}:$period:${dayKey(day)}';
  try{
   final params={'day':dayKey(day),'period':period,'province':widget.service.province};
   final values=await Future.wait([list('/api/v1/routes',params,'routes-v2:$period:${dayKey(day)}:${widget.service.province}'),list('/api/v1/sessions',params,'surveys:$key'),widget.queue.cached('survey-drafts')]);
   try{final t=asRows((await surveyGet(widget.service,'/api/v1/survey-templates'))['items']);for(final item in t){await widget.queue.cache('survey-template:${item['province']}',[item]);}}catch(e){if(e is ApiFailure&&(e.status==401||e.status==403))rethrow;}
   if(mounted)setState((){routes=values[0];sessions=values[1];drafts=values[2];if(!routes.any((r)=>r['district']==district))district='';if(!routes.any((r)=>r['owner_sub']==employee))employee='';});
  }catch(e){if(mounted)setState((){error=e.toString();if(e is ApiFailure&&(e.status==401||e.status==403)){routes=[];sessions=[];drafts=[];}});}
  finally{if(mounted)setState(()=>busy=false);}
 }
 void notify(String msg){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(msg)));}
 List<Map<String,dynamic>> mergeSessions(List<Map<String,dynamic>> server,List<Map<String,dynamic>> local){
  final m=<String,Map<String,dynamic>>{for(final s in server)s['id'].toString():s};
  for(final d in local){final id=d['id'].toString(),s=m[id];if(s?['status']=='completed'){m[id]=s!;}else{m[id]={...?s,...d,if(s?['status']!=null)'server_status':s!['status'],if(s?['location_initialized']!=null)'location_initialized':s!['location_initialized']};}}
  final out=m.values.toList();out.sort((a,b)=>b['started_at'].toString().compareTo(a['started_at'].toString()));return out;
 }
 bool isToday(Map<String,dynamic> row)=>row['planned']==true?(row['data'] as Map)['plannedDate']==dayKey(vnToday()):dayKey(day)==dayKey(vnToday());
 List<Map<String,dynamic>> rowSessions(Map<String,dynamic> row){
  final start=dayKey(weekly?weekMonday(day):day),end=dayKey(weekly?weekMonday(day).add(const Duration(days:6)):day);
  return mergeSessions(sessions,drafts).where((s){
   final started=DateTime.tryParse(s['started_at'].toString());if(started==null)return false;
   final d=dayKey(started.toUtc().add(const Duration(hours:7)));
   return s['customer_id']==row['customer_id']&&s['owner_sub']==row['owner_sub']&&d.compareTo(start)>=0&&d.compareTo(end)<=0&&(row['planned']!=true?s['route_stop_id']==null:s['route_stop_id']==row['id']);
  }).toList();
 }
 Future<void> pickDay()async{
  final d=await showDatePicker(context:context,initialDate:day,firstDate:DateTime(2020),lastDate:DateTime(2100));
  if(d!=null&&mounted){setState((){day=d;routes=[];sessions=[];});await load();}
 }
 Future<Map<String,dynamic>> template(String province)async{
  final items=await list('/api/v1/survey-templates',{'province':province},'survey-template:$province');
  if(items.isEmpty)throw StateError('Chưa có mẫu khảo sát tỉnh này trên máy; cần đồng bộ hoặc Admin tạo mẫu.');
  return items.first;
 }
 Future<void> begin(Map<String,dynamic> row)async{
  if(busy||row['owner_sub']!=widget.queue.identity||!isToday(row))return;
  setState(()=>busy=true);
  try{
   final t=await template(row['province'].toString());if(!mounted)return;
   var pos=await captureGps(context);
   while(!pos.accuracy.isFinite||pos.accuracy>100||pos.accuracy<0){
    if(!mounted)return;
    final retry=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('Vị trí thiết bị chưa đủ chính xác'),content:Text('Sai số hiện tại: ${pos.accuracy.isFinite?pos.accuracy.toStringAsFixed(0):"không xác định"} m. Cần tối đa 100 m. Nếu dùng máy tính, hãy thử trên điện thoại có GPS; bật Vị trí chính xác và đứng nơi thoáng. Tọa độ khách hàng chưa được kiểm tra ở bước này.'),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Hủy')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Lấy lại GPS'))]));
    if(retry!=true||!mounted)return;
    pos=await captureGps(context);
   }
   final first=row['latitude']==null&&row['longitude']==null;
   if(first){
    if(!mounted)return;
    final consent=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('Điểm bán chưa có tọa độ'),content:Text('Bạn đang ở đúng địa chỉ của ${row['name']}? ${row['address_line']??""}\n\nChỉ xác nhận khi đang có mặt và được phép ghi nhận tọa độ điểm bán. Vị trí GPS này sẽ làm mốc cho các lần ghé sau. Lần đầu là ghi nhận mốc, không phải đối chiếu với vị trí có sẵn.'),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Hủy')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Xác nhận vị trí lần đầu'))]));
    if(consent!=true||!mounted)return;
   }else if(row['location_consent']==false){notify('Điểm bán chưa được phép sử dụng tọa độ. Kiểm tra hồ sơ khách hàng.');return;}
   final id=const Uuid().v4(),started=pos.timestamp.toUtc().toIso8601String();
   final payload=<String,dynamic>{'client_ref':id,'customer_id':row['customer_id'],'route_stop_id':row['planned']==true?row['id']:null,'template_id':t['id'],'started_at':started,'latitude':pos.latitude,'longitude':pos.longitude,'accuracy_m':pos.accuracy,if(first)'initialize_location':true};
   final draft=<String,dynamic>{...payload,'id':id,'owner_sub':widget.queue.identity,'province':row['province'],'district':row['district'],'customer_name':row['name'],'template_version':t['version'],'questions':t['questions'],'status':'in_progress','location_initialized':first,'start_op':id,'version':1,'answers':<String,dynamic>{},'note':'','photos':<Map<String,dynamic>>[]};
   await widget.queue.saveSurveyDraft(draft,path:'/api/v1/sessions',payload:payload);
   if(mounted)await open(draft);
  }catch(e){notify('Không bắt đầu được: $e');}
  finally{if(mounted){setState(()=>busy=false);await load();}}
 }
 Future<void> open(Map<String,dynamic> s)async{
  await Navigator.push(context,MaterialPageRoute(builder:(_)=>SurveyDetail(queue:widget.queue,service:widget.service,initial:s)));
  if(mounted){await readDrafts();if(!busy)await load();}
 }
 Future<void> history(Map<String,dynamic> row)async{
  try{
   final cid=row['customer_id'].toString();
   final items=await list('/api/v1/sessions',{'customer_id':cid},'survey-history:$cid');
   final local=(await widget.queue.cached('survey-drafts')).where((s)=>s['customer_id']==cid).toList();
   final history=mergeSessions(items,local);
   if(!mounted)return;
   final chosen=await showDialog<Map<String,dynamic>>(context:context,builder:(c)=>AlertDialog(title:Text(row['name'].toString()),content:SizedBox(width:420,child:ListView(shrinkWrap:true,children:[
    Text(row['planned']==true?'Theo lịch ${(row['data'] as Map)['plannedDate']}':'Ngoài tuyến · ghé đột xuất'),
    if(history.isEmpty)const Text('Chưa có phiên khảo sát.'),
    for(final s in history)ListTile(title:Text(surveyStatus(s)),subtitle:Text('${s['started_at']} · Mẫu v${s['template_version']} · ${s['route_stop_id']==null?'Ngoài tuyến':'Theo tuyến'}'),onTap:()=>Navigator.pop(c,s)),
   ])),actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('Đóng')),if(row['owner_sub']==widget.queue.identity&&isToday(row))FilledButton(onPressed:()=>Navigator.pop(c,{'new':true}),child:const Text('Bắt đầu phiên mới'))]));
   if(chosen==null||!mounted)return;
   if(chosen['new']==true){await begin(row);}else{await open(chosen);}
  }catch(e){notify(e.toString());}
 }
 @override Widget build(BuildContext context){
  final districts=routes.map((r)=>r['district'].toString()).toSet().toList()..sort();
  final staff=<String,String>{for(final r in routes)r['owner_sub'].toString():r['full_name']?.toString()??''};
  final candidates=<Map<String,dynamic>>[...routes.where((r)=>r['planned']==true),if(all)...{for(final r in routes)r['customer_id']:{...r,'planned':false,'id':null,'data':{},'visited':false}}.values];
  final visible=candidates.where((r)=>(all||r['planned']==true)&&(district.isEmpty||r['district']==district)&&(employee.isEmpty||r['owner_sub']==employee)&&(widget.initialCustomer==null||r['customer_id']==widget.initialCustomer)).toList();
  return ListView(padding:const EdgeInsets.all(12),children:[
   Row(children:[Expanded(child:Text('Khảo sát theo tuyến',style:Theme.of(context).textTheme.titleLarge)),IconButton(onPressed:busy?null:load,tooltip:'Đồng bộ',icon:const Icon(Icons.sync))]),
   Wrap(spacing:8,runSpacing:8,children:[OutlinedButton.icon(onPressed:busy?null:pickDay,icon:const Icon(Icons.calendar_today),label:Text(dayKey(day))),if(widget.admin)OutlinedButton(onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>SurveyTemplateAdmin(service:widget.service,regions:widget.regions))),child:const Text('Mẫu khảo sát')),if(widget.admin)OutlinedButton(onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>MediaUsagePage(service:widget.service))),child:const Text('Dung lượng')),if(widget.legacy!=null)TextButton(onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:widget.legacy!)),child:const Text('Mẫu cũ'))]),
   const SizedBox(height:8),
   SegmentedButton<bool>(segments:const [ButtonSegment(value:false,label:Text('Ngày')),ButtonSegment(value:true,label:Text('Tuần'))],selected:{weekly},onSelectionChanged:busy?null:(v){setState(()=>weekly=v.first);load();}),
   if(weekly)Text('${dayKey(weekMonday(day))} – ${dayKey(weekMonday(day).add(const Duration(days:6)))}'),
   SwitchListTile(contentPadding:EdgeInsets.zero,title:const Text('Tất cả khách trong quyền'),subtitle:const Text('Bật để ghé ngoài tuyến.'),value:all,onChanged:(v)=>setState(()=>all=v)),
   AdaptiveFilterRow(minFieldWidth:190,children:[
      DropdownButtonFormField<String>(key:ValueKey(districts.join('|')),
        initialValue:districts.contains(district)?district:'',isExpanded:true,
        decoration:const InputDecoration(labelText:'Huyện'),
        items:[const DropdownMenuItem(value:'',child:Text('Tất cả')),
          for(final d in districts)DropdownMenuItem(value:d,child:Text(d,overflow:TextOverflow.ellipsis))],
        onChanged:(v)=>setState(()=>district=v??'')),
      if(staff.length>1)DropdownButtonFormField<String>(key:ValueKey(staff.keys.join('|')),
        initialValue:staff.containsKey(employee)?employee:'',isExpanded:true,
        decoration:const InputDecoration(labelText:'Nhân viên'),
        items:[const DropdownMenuItem(value:'',child:Text('Tất cả trong quyền')),
          for(final e in staff.entries)DropdownMenuItem(value:e.key,child:Text(e.value,overflow:TextOverflow.ellipsis))],
        onChanged:(v)=>setState(()=>employee=v??'')),
    ]),
    if(busy)const LinearProgressIndicator(),if(error!=null)Padding(padding:const EdgeInsets.all(8),child:Text(error!)),
   if(visible.isEmpty&&!busy)const Padding(padding:EdgeInsets.all(16),child:Text('Không có điểm ghé trong kỳ này. Bật tất cả khách để ghé đột xuất.')),
   for(final r in visible)Card(child:ListTile(title:Text(r['name'].toString()),leading:r['category']==null
      ?CircleAvatar(child:Text(r['planned']==true?((r['data'] as Map)['sequence']??'').toString():'–'))
      :Stack(clipBehavior:Clip.none,children:[
        CustomerCategoryAvatar(category:r['category']?.toString()),
        Positioned(bottom:-5,right:-5,child:CircleAvatar(radius:10,
          backgroundColor:Theme.of(context).colorScheme.surfaceContainerHighest,
          child:Text(r['planned']==true?((r['data'] as Map)['sequence']??'').toString():'–',
            style:Theme.of(context).textTheme.labelSmall))),
      ]),subtitle:Text('${r['district']}, ${r['province']} · ${r['full_name']}\n${r['planned']==true?(r['data'] as Map)['plannedDate']:'Ngoài tuyến'} · ${rowSessions(r).isNotEmpty?surveyStatus(rowSessions(r).first):r['visited']==true?'GPS đã xác minh · chưa có phiên':'Chưa ghé'}'),trailing:const Icon(Icons.chevron_right),onTap:busy?null:()=>history(r))),
  ]);
 }
}

class SurveyDetail extends StatefulWidget{
 final OfflineQueue queue;final CustomerService service;final Map<String,dynamic> initial;
 const SurveyDetail({super.key,required this.queue,required this.service,required this.initial});
 @override State<SurveyDetail> createState()=>_SurveyDetailState();
}
class _SurveyDetailState extends State<SurveyDetail>{
 late Map<String,dynamic> draft;bool busy=false,denied=false;String? message;
 final images=<String,Future<Uint8List>>{};
 String get id=>draft['id'].toString();
 bool get own=>draft['owner_sub']==widget.queue.identity;
 bool get locked=>!own||draft['status']=='completed'||draft['status']=='completed_pending'||draft['server_status']=='completed';
 List<Map<String,dynamic>> get qs=>asRows(draft['questions']);
 List<Map<String,dynamic>> get photos=>asRows(draft['photos']);
 Map<String,dynamic> get answers=>asMap(draft['answers']??{});
 List<String> get parent=>draft['start_op']==null?[]:[draft['start_op'].toString()];
 @override void initState(){super.initState();draft={...widget.initial,'photos':asRows(widget.initial['photos']),'answers':asMap(widget.initial['answers']??{})};widget.queue.addListener(changed);load();}
 @override void dispose(){widget.queue.removeListener(changed);super.dispose();}
 void changed(){if(mounted)unawaited(acks());}
 Future<void> acks()async{
  try{final local=(await widget.queue.cached('survey-drafts')).where((s)=>s['id']==id).firstOrNull;
   if(local!=null&&mounted)setState((){draft['server_status']=local['server_status'];draft['server_version']=local['server_version'];if(local['location_initialized']!=null)draft['location_initialized']=local['location_initialized'];final ready=asRows(local['photos']).where((p)=>p['sync_status']=='ready').map((p)=>p['id']).toSet();draft['photos']=[for(final p in photos){...p,if(ready.contains(p['id']))'sync_status':'ready'}];});
  }catch(_){}
 }
 Future<void> load()async{
  if(busy)return;setState(()=>busy=true);images.clear();
  try{
   final local=(await widget.queue.cached('survey-drafts')).where((s)=>s['id']==id).firstOrNull;
   if(local!=null&&own&&mounted)setState(()=>draft=local);
   try{
    final data=await surveyGet(widget.service,'/api/v1/sessions/$id');
    final server=asMap(data['item']),serverPhotos=asRows(data['photos']).map((p)=>{...p,'sync_status':p['status']}).toList();
    await widget.queue.cache('survey-detail:$id',[{...server,'photos':serverPhotos}]);
    if(mounted)setState((){
     if(server['status']=='completed'||local==null){draft={...server,'photos':serverPhotos,'server_status':server['status']};}
     else{final media=<String,Map<String,dynamic>>{for(final p in photos)p['id'].toString():p,for(final p in serverPhotos)p['id'].toString():p};draft={...draft,'server_status':server['status'],'server_version':server['version'],'location_initialized':server['location_initialized'],'photos':media.values.toList()};}
    });
   }catch(e){
    if(e is ApiFailure&&(e.status==401||e.status==403||e.status==404&&(local==null||local['server_status']!=null)))rethrow;
    final saved=await widget.queue.cached('survey-detail:$id');if(local==null&&saved.isNotEmpty&&mounted)setState(()=>draft=saved.first);
    if(mounted)setState(()=>message='Phiên lưu máy · chưa cập nhật');
   }
  }catch(e){if(mounted)setState((){message=e.toString();if(e is ApiFailure&&(e.status==401||e.status==403||e.status==404))denied=true;});}
  finally{if(mounted)setState(()=>busy=false);}
 }
 Map<String,dynamic> snapshot()=>{...draft,'answers':answers,'photos':photos};
 Future<bool> persist()async{try{await widget.queue.saveSurveyDraft(snapshot());return true;}catch(e){if(mounted)setState(()=>message='Không lưu được nháp: $e');return false;}}
 void answer(String key,dynamic value){if(locked||busy)return;setState(()=>draft['answers']={...answers,key:value});unawaited(persist());}
 Future<void> photo(String kind,ImageSource source)async{
  if(locked||busy)return;if(photos.length>=12){setState(()=>message='Tối đa 12 ảnh mỗi phiên');return;}
  setState(()=>busy=true);
  try{
   final f=await ImagePicker().pickImage(source:source,maxWidth:1600,maxHeight:1600,imageQuality:80);if(f==null)return;
   final compressed=compressSurveyMedia(await f.readAsBytes()),bytes=compressed.image;
   const mime='image/jpeg';
   final op=const Uuid().v4(),captured=DateTime.now().toUtc().toIso8601String();
   final p=<String,dynamic>{'id':op,'kind':kind,'captured_at':captured,'bytes':bytes.length,'sync_status':'pending','created_by':widget.queue.identity};
   final next={...snapshot(),'photos':[...photos,p]};
   await widget.queue.saveSurveyDraft(next,path:'/api/v1/sessions/$id/photos',payload:{'client_ref':op,'kind':kind,'captured_at':captured,'sha256':compressed.hash,'thumbnail_sha256':compressed.thumbnailHash},photo:bytes,thumbnail:compressed.thumbnail,mime:mime,dependsOn:parent);
   if(mounted)setState(()=>draft=next);await acks();
  }catch(e){if(mounted)setState(()=>message=e.toString());}
  finally{if(mounted)setState(()=>busy=false);}
 }
 Future<void> finish()async{
  if(locked||busy)return;
  final err=checklistError(qs,answers);
  if(err!=null){setState(()=>message=err);return;}
  if(!['front','shelf','goods'].every((kind)=>photos.any((p)=>p['kind']==kind))){setState(()=>message='Cần ảnh mặt tiền, quầy kệ và hàng hóa.');return;}
  final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('Hoàn thành phiên?'),content:const Text('GPS, checklist và ảnh sẽ được xác minh trên server. Nếu mất mạng, phiên vẫn chờ đồng bộ.'),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Hủy')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Gửi hoàn thành'))]));
  if(ok!=true||!mounted)return;
  setState(()=>busy=true);
  try{
   final op=const Uuid().v4(),end=DateTime.now().toUtc().toIso8601String(),next={...snapshot(),'status':'completed_pending','ended_at':end,'finish_op':op};
   await widget.queue.saveSurveyDraft(next,path:'/api/v1/sessions/$id',method:'PATCH',payload:{'client_ref':op,'version':draft['server_version']??draft['version']??1,'answers':answers,'note':draft['note']??'','ended_at':end},dependsOn:[...parent,...photos.map((p)=>p['id'].toString())]);
   if(mounted)setState(()=>draft=next);await acks();
  }catch(e){if(mounted)setState(()=>message=e.toString());}
  finally{if(mounted)setState(()=>busy=false);}
 }
 Future<Uint8List> remoteImage(String photoId,{bool thumbnail=true})async{
  final r=await http.get(widget.service.uri('/api/v1/sessions/$id/photos/$photoId',thumbnail?{'thumbnail':'1'}:null),headers:widget.service.headers).timeout(const Duration(seconds:20));
  if(r.statusCode!=200){checkSessionStatus(r);throw StateError('Không tải được ảnh');}return r.bodyBytes;
 }
 Widget media(Map<String,dynamic> p){
  final pid=p['id'].toString(),pending=widget.queue.pending.where((r)=>r['upload_id']==pid&&r['session_id']==id).firstOrNull;
  final bytes=pending?['thumbnail']??pending?['photo'];
  return Card(child:Padding(padding:const EdgeInsets.all(8),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
   Text('${photoLabels[p['kind']]??p['kind']} · ${p['sync_status']=='ready'?'Đã đồng bộ':'Chờ đồng bộ'}'),
   Text('${p['captured_at']} · ${p['created_by']??''}',style:Theme.of(context).textTheme.bodySmall),
   if(bytes is List)Image.memory(Uint8List.fromList(bytes.cast<int>()),height:140,fit:BoxFit.contain)
   else if(p['sync_status']=='ready')FutureBuilder<Uint8List>(future:images.putIfAbsent(pid,()=>remoteImage(pid)),builder:(c,s)=>s.hasData?InkWell(onTap:()=>showDialog<void>(context:context,builder:(c)=>AlertDialog(title:const Text('Ảnh khảo sát'),content:FutureBuilder<Uint8List>(future:remoteImage(pid,thumbnail:false),builder:(c,v)=>v.hasData?Image.memory(v.data!):Text(v.hasError?'Không tải được ảnh':'Đang tải…')),actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('Đóng'))])),child:Image.memory(s.data!,height:140,fit:BoxFit.contain)):Text(s.hasError?'Không tải được ảnh khi offline':'Đang tải ảnh…')),
  ])));
 }
 Widget question(Map<String,dynamic> q){
  final key=q['id'].toString(),v=answers[key],label='${q['label']}${q['required']==true?' *':''}';
  if(locked)return ListTile(contentPadding:EdgeInsets.zero,title:Text(label),subtitle:Text(v==null?'Chưa trả lời':v is bool?(v?'Có':'Không'):v is List?v.join(', '):v.toString()));
  if(q['type']=='boolean')return DropdownButtonFormField<bool>(initialValue:v is bool?v:null,decoration:InputDecoration(labelText:label),items:const [DropdownMenuItem(value:true,child:Text('Có')),DropdownMenuItem(value:false,child:Text('Không'))],onChanged:(v)=>answer(key,v));
  if(q['type']=='multi_choice'){
   final options=(q['options'] as List).cast<String>(),selected=(v is List?v.cast<String>():<String>[]);
   return InputDecorator(decoration:InputDecoration(labelText:label,helperText:'Chọn nhiều · ${selected.length} đã chọn'),child:Wrap(spacing:6,runSpacing:4,children:[for(final option in options)FilterChip(label:Text(option),selected:selected.contains(option),onSelected:busy?null:(checked)=>answer(key,checked?[...selected,option]:selected.where((x)=>x!=option).toList()))]));
  }
  if(q['type']=='choice'){final options=(q['options'] as List).cast<String>();return DropdownButtonFormField<String>(initialValue:options.contains(v)?v:null,isExpanded:true,decoration:InputDecoration(labelText:label),items:[for(final o in options)DropdownMenuItem(value:o,child:Text(o))],onChanged:(v)=>answer(key,v));}
  return TextFormField(initialValue:v?.toString()??'',decoration:InputDecoration(labelText:label),keyboardType:q['type']=='number'?const TextInputType.numberWithOptions(decimal:true):TextInputType.text,maxLines:q['type']=='number'?1:2,onChanged:(s)=>answer(key,q['type']=='number'?num.tryParse(s):s));
 }
 @override Widget build(BuildContext context){
  final pending=widget.queue.pending.where((r)=>r['session_id']==id).toList();
  if(denied)return Scaffold(appBar:AppBar(title:const Text('Phiên khảo sát')),body:const Center(child:Text('Không còn quyền truy cập phiên này.')));
  return Scaffold(appBar:AppBar(title:const Text('Phiên khảo sát'),actions:[IconButton(onPressed:busy?null:load,tooltip:'Tải lại phiên',icon:const Icon(Icons.sync))]),
   body:ListView(padding:const EdgeInsets.all(16),children:[
    Text(draft['customer_name'].toString(),style:Theme.of(context).textTheme.titleLarge),Text('${draft['district']}, ${draft['province']} · Mẫu v${draft['template_version']}'),
    Text(draft['route_stop_id']==null?'Ngoài tuyến':'Theo tuyến'),Text(surveyStatus(draft),style:Theme.of(context).textTheme.titleMedium),
    Text('Bắt đầu: ${draft['started_at']}'),if(draft['ended_at']!=null)Text('Kết thúc: ${draft['ended_at']}'),
    Text('GPS: ${draft['latitude']}, ${draft['longitude']} · Sai số ${draft['accuracy_m']} m'),
    if(draft['location_initialized']==true)Text(draft['server_status']==null?'Tọa độ lần đầu chờ ghi nhận trên server.':'Ghi nhận tọa độ lần đầu · chưa có mốc để đối chiếu.'),
    if(!own)const Text('Chế độ xem của quản lý · không được sửa phiên người khác.'),
    if(busy)const LinearProgressIndicator(),if(message!=null)Text(message!),
    for(final p in pending)ListTile(contentPadding:EdgeInsets.zero,leading:const Icon(Icons.cloud_upload_outlined),title:Text(p['status']=='blocked'?'Cần xử lý lỗi đồng bộ':'Đang chờ đồng bộ'),subtitle:Text(p['error']?.toString()??p['path'].toString()),trailing:p['status']=='blocked'&&own?TextButton(onPressed:busy||widget.queue.syncing?null:()=>widget.queue.retrySurveyOperation(p['upload_id'].toString()),child:const Text('Thử lại')):null),
    const SizedBox(height:16),Text('Checklist',style:Theme.of(context).textTheme.titleMedium),
    for(final q in qs)Padding(padding:const EdgeInsets.only(top:12),child:question(q)),
    const SizedBox(height:12),
    if(locked)Text('Ghi chú: ${draft['note']??''}')else TextFormField(enabled:!busy,initialValue:draft['note']?.toString()??'',maxLines:3,decoration:const InputDecoration(labelText:'Ghi chú phiên'),onChanged:(v){draft['note']=v;unawaited(persist());}),
    const SizedBox(height:16),Text('Ảnh phiên (${photos.length}/12)',style:Theme.of(context).textTheme.titleMedium),
    const Text('Bắt buộc: mặt tiền, quầy kệ và hàng hóa.'),
    if(!locked)Wrap(spacing:8,runSpacing:8,children:[for(final k in photoLabels.entries)OutlinedButton.icon(onPressed:busy?null:()=>photo(k.key,ImageSource.camera),icon:const Icon(Icons.camera_alt_outlined),label:Text(k.value))]),
    for(final p in photos)media(p),
    if(!locked)Padding(padding:const EdgeInsets.only(top:16),child:Wrap(spacing:8,runSpacing:8,children:[OutlinedButton(onPressed:busy?null:()async{final saved=await persist();if(saved&&mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Đã lưu nháp trên máy')));},child:const Text('Lưu nháp')),FilledButton(onPressed:busy?null:finish,child:const Text('Hoàn thành phiên'))])),
   ]));
 }
}

class SurveyTemplateAdmin extends StatefulWidget{
 final CustomerService service;final RegionCatalog regions;
 const SurveyTemplateAdmin({super.key,required this.service,required this.regions});
 @override State<SurveyTemplateAdmin> createState()=>_SurveyTemplateAdminState();
}
class _SurveyTemplateAdminState extends State<SurveyTemplateAdmin>{
 String province='';int version=0;bool busy=false;String? message;
 List<Map<String,dynamic>> qs=[];
 Future<void> load(String p)async{
  setState((){province=p;busy=true;message=null;qs=[];version=0;});
  try{final data=await surveyGet(widget.service,'/api/v1/survey-templates',{'province':p});final items=asRows(data['items']);if(items.isNotEmpty&&mounted)setState((){version=(items.first['version'] as num).toInt();qs=asRows(items.first['questions']);});}
  catch(e){if(mounted)setState(()=>message=e.toString());}
  finally{if(mounted)setState(()=>busy=false);}
 }
 Future<void> publish()async{
  if(busy||province.isEmpty)return;
  if(qs.isEmpty||qs.length>50||qs.any((q)=>q['label'].toString().trim().isEmpty||['choice','multi_choice'].contains(q['type'])&&((q['options'] as List? ?? []).length<2))){setState(()=>message='Mỗi câu cần nhãn; câu chọn cần ít nhất 2 lựa chọn.');return;}
  setState(()=>busy=true);
  try{
   final r=await http.post(widget.service.uri('/api/v1/survey-templates'),headers:widget.service.headers,body:jsonEncode({'client_ref':const Uuid().v4(),'province':province,'expected_version':version,'questions':qs})).timeout(const Duration(seconds:20));
   final item=asMap(decodeApi(r)['item']);if(mounted)setState((){version=(item['version'] as num).toInt();qs=asRows(item['questions']);message='Đã phát hành mẫu v$version. Phiên cũ giữ nguyên mẫu.';});
  }catch(e){if(mounted)setState(()=>message=e.toString());}
  finally{if(mounted)setState(()=>busy=false);}
 }
 @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Mẫu khảo sát theo tỉnh')),body:ListView(padding:const EdgeInsets.all(16),children:[
  DropdownButtonFormField<String>(initialValue:province.isEmpty?null:province,isExpanded:true,decoration:const InputDecoration(labelText:'Tỉnh/TP'),items:[for(final p in widget.regions.provinces)DropdownMenuItem(value:p,child:Text(p))],onChanged:busy?null:(p){if(p!=null)load(p);}),
  if(busy)const LinearProgressIndicator(),if(message!=null)Text(message!),
  if(province.isNotEmpty)...[Text('Phiên bản hiện tại: $version · lưu sẽ tạo phiên bản mới'),const Text('Chọn nhiều cho NPP, nhãn hàng, SKU. Thêm lựa chọn Khác và câu văn bản tùy chọn để ghi tên ngoài danh mục.'),
   for(final q in qs)Card(key:ValueKey(q['id']),child:Padding(padding:const EdgeInsets.all(12),child:Column(children:[
    TextFormField(key:ValueKey('${province}:$version:${q['id']}'),initialValue:q['label'].toString(),decoration:const InputDecoration(labelText:'Nội dung câu hỏi'),onChanged:(v)=>q['label']=v),
    const SizedBox(height:8),
    DropdownButtonFormField<String>(initialValue:q['type'].toString(),decoration:const InputDecoration(labelText:'Kiểu trả lời'),items:const [DropdownMenuItem(value:'text',child:Text('Văn bản')),DropdownMenuItem(value:'number',child:Text('Số')),DropdownMenuItem(value:'boolean',child:Text('Có / Không')),DropdownMenuItem(value:'choice',child:Text('Chọn một')),DropdownMenuItem(value:'multi_choice',child:Text('Chọn nhiều'))],onChanged:(v)=>setState(()=>q['type']=v??'text')),
    if(['choice','multi_choice'].contains(q['type']))TextFormField(initialValue:(q['options'] as List? ?? []).join(', '),decoration:const InputDecoration(labelText:'Lựa chọn (ngăn cách bằng dấu phẩy)'),onChanged:(v)=>q['options']=v.split(',').map((s)=>s.trim()).where((s)=>s.isNotEmpty).toSet().toList()),
    CheckboxListTile(contentPadding:EdgeInsets.zero,value:q['required']==true,title:const Text('Bắt buộc'),onChanged:(v)=>setState(()=>q['required']=v==true)),
    TextButton(onPressed:busy?null:()=>setState(()=>qs.remove(q)),child:const Text('Bỏ câu hỏi trong bản mới')),
   ]))),
   Wrap(spacing:8,children:[OutlinedButton(onPressed:busy||qs.length>=50?null:()=>setState(()=>qs.add({'id':'q_${const Uuid().v4().replaceAll('-','').substring(0,16)}','label':'','type':'text','required':false})),child:const Text('Thêm câu hỏi')),FilledButton(onPressed:busy?null:publish,child:const Text('Phát hành phiên bản'))]),
  ]
 ]));
}

class MediaUsagePage extends StatefulWidget{
 final CustomerService service;
 const MediaUsagePage({super.key,required this.service});
 @override State<MediaUsagePage> createState()=>_MediaUsagePageState();
}
class _MediaUsagePageState extends State<MediaUsagePage>{
 late Future<Map<String,dynamic>> data;
 @override void initState(){super.initState();data=surveyGet(widget.service,'/api/v1/admin/media-usage');}
 String gb(dynamic v)=>'${((v as num)/1000000000).toStringAsFixed(3)} GB';
 @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Ngân sách R2'),actions:[IconButton(onPressed:()=>setState(()=>data=surveyGet(widget.service,'/api/v1/admin/media-usage')),icon:const Icon(Icons.refresh))]),body:FutureBuilder<Map<String,dynamic>>(future:data,builder:(c,s){
 if(s.hasError)return Center(child:Text(s.error.toString()));if(!s.hasData)return const Center(child:CircularProgressIndicator());
 final d=s.data!,pct=(d['percent'] as num).toDouble(),warn=d['warning'] as num;
 return ListView(padding:const EdgeInsets.all(16),children:[Text('Đã dùng ${gb(d['used_bytes'])} / 10 GB',style:Theme.of(context).textTheme.titleLarge),LinearProgressIndicator(value:(pct/100).clamp(0,1).toDouble()),Text('${pct.toStringAsFixed(2)}% · ${d['objects']} đối tượng'),if(d['complete']!=true)const Text('Chưa quét hết kho: số liệu là mức tối thiểu.'),if(warn>0)Text('Cảnh báo: vượt ngưỡng $warn%',style:TextStyle(color:Theme.of(context).colorScheme.error)),ListTile(title:const Text('Ảnh'),trailing:Text(gb(d['photo_bytes']))),ListTile(title:const Text('APK'),trailing:Text(gb(d['apk_bytes']))),ListTile(title:const Text('Khác'),trailing:Text(gb(d['other_bytes']))),const Text('Ngưỡng 70% / 85% / 95%. Không tự xóa ảnh hoặc APK. Đề xuất giữ ảnh gốc 180 ngày, thumbnail lâu hơn; chỉ áp dụng sau Owner duyệt và backup.')]);
 }));
}
