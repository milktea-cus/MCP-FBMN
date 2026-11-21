import 'dart:async';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'survey_media.dart';
import 'customers.dart';
import 'models.dart';
import 'offline_queue.dart';
import 'session.dart';
import 'theme.dart';

/// Canonical field_prospects list; PWA uses IndexedDB and Android uses SQLite
/// through the existing account-scoped OfflineQueue. The customer bottom
/// navigation and customer cards are deliberately untouched.
class MarketProspectsPage extends StatefulWidget {
 final OfflineQueue queue;
 final SalesSession session;
 final RegionCatalog regions;
 final Map<String,dynamic>? initialSchool;
 const MarketProspectsPage({super.key,required this.queue,required this.session,
  required this.regions,this.initialSchool});
 @override State<MarketProspectsPage> createState()=>_MarketProspectsPageState();
}

class _MarketProspectsPageState extends State<MarketProspectsPage>{
 final search=TextEditingController();
 Timer? debounce;
 String province='',district='',status='';
 List<Map<String,dynamic>> items=[];
 int page=0,total=0,generation=0;
 bool loading=false,offline=false,more=false;
 String? error;
 @override void initState(){
  super.initState();
  province=widget.initialSchool?['province_old']?.toString()??'';
  district=widget.initialSchool?['district_old']?.toString()??'';
  widget.queue.addListener(_queueChanged);
  unawaited(_load());
 }
 @override void dispose(){
  generation++;
  widget.queue.removeListener(_queueChanged);
  debounce?.cancel();search.dispose();
  super.dispose();
 }
 void _queueChanged(){if(mounted)setState((){});}
 String _cacheKey(int n)=>'market-prospects:v2:${widget.initialSchool?['id']??''}:$province:$district:$status:$n';
 Future<void> _load({bool append=false})async{
  final token=++generation,next=append?page+1:1;
  final p=province,d=district,s=status,q=search.text.trim();
  setState((){loading=true;error=null;if(!append){items=[];page=0;total=0;more=false;}});
  bool cached=false;
  if(q.isEmpty&&next<=3)try{
   final rows=await widget.queue.cached(_cacheKey(next));
   if(!mounted||generation!=token)return;
   if(rows.isNotEmpty){
    cached=true;
    _apply(rows,next,append:append,local:true,hasMore:rows.length==20);
   }
  }catch(_){}
  try{
   final uri=Uri(path:'/api/v1/market-prospects',queryParameters:{
    'page':'$next','size':'20',
    if(p.isNotEmpty)'province':p,if(d.isNotEmpty)'district':d,
    if(s.isNotEmpty)'status':s,
    if(q.isNotEmpty)'q':q,
    if(widget.initialSchool?['id']!=null)'school_id':widget.initialSchool!['id'].toString(),
   });
   final data=await widget.session.get(uri.toString());
   if(!mounted||generation!=token)return;
   final rows=(data['items'] as List? ?? [])
     .map((v)=>Map<String,dynamic>.from(v as Map)).toList();
   total=(data['total'] as num?)?.toInt()??0;
   _apply(rows,next,append:append,local:false,hasMore:data['hasMore']==true);
   if(q.isEmpty&&next<=3)await widget.queue.cache(_cacheKey(next),rows);
  }on ApiFailure catch(e){
   if(!mounted||generation!=token)return;
   setState((){
    loading=false;offline=true;
    if(e.status==401||e.status==403){items.clear();more=false;cached=false;}
    error=cached?'Đang xem dữ liệu đã lưu trên máy':e.message;
   });
  }catch(_){
   if(!mounted||generation!=token)return;
   setState((){
    loading=false;offline=true;
    error=cached?'Đang xem dữ liệu đã lưu trên máy':'Không tải được danh sách';
   });
  }
 }
 void _apply(List<Map<String,dynamic>> rows,int n,
   {required bool append,required bool local,required bool hasMore}){
  if(!mounted)return;
  setState((){
   if(!append)items=[];
   final ids=items.map((e)=>e['id'].toString()).toSet();
   for(final row in rows)if(ids.add(row['id'].toString()))items.add(row);
   page=n;more=hasMore;offline=local;loading=local;error=null;
  });
 }
 void _notice(String value){
  if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(value)));
 }
 List<Map<String,dynamic>> get pendingNew{
  return widget.queue.pending.where((job)=>
   job['path']=='/api/v1/market-prospects'&&job['method']=='POST'
  ).map((job){
   final map=Map<String,dynamic>.from(job['payload'] as Map);
   return {...map,'id':map['client_ref'],'status':'new',
    'visits':0,'pending_status':job['status']};
  }).where((r)=>
   (province.isEmpty||r['province']==province)&&
   (district.isEmpty||r['district']==district)&&
   (status.isEmpty||status=='new')&&
   (search.text.trim().isEmpty||r['name'].toString().toLowerCase().contains(search.text.trim().toLowerCase()))&&
   (widget.initialSchool==null||r['school_id']==widget.initialSchool!['id'])
  ).toList();
 }
 Future<bool> _confirmTax(String code)async{
  try{
   final data=await widget.session.get('/api/v1/market-prospects/tax-check?mst=${Uri.encodeQueryComponent(code)}');
   if(!mounted)return false;
   final oldCustomers=data['customers'] as List? ?? [];
   final oldLeads=data['prospects'] as List? ?? [];
   if(oldCustomers.isEmpty&&oldLeads.isEmpty)return true;
   return await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
    title:const Text('MST đã có trên hệ thống'),
    content:Text('Tìm thấy ${oldCustomers.length} hồ sơ Khách hàng và ${oldLeads.length} điểm bán tiềm năng có MST này trong phạm vi được xem. Nếu là chi nhánh khác, anh có thể tiếp tục.'),
    actions:[
     TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Xem lại')),
     FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Là chi nhánh khác')),
    ]))??false;
  }on ApiFailure catch(e){
   if(e.status==401||e.status==403)rethrow;
   // Discovery can be saved offline. Do not falsely claim that MST was checked.
   if(mounted)_notice('Chưa đối chiếu được MST do mất mạng; lưu điểm bán và kiểm tra sau.');
   return true;
  }catch(_){
   if(mounted)_notice('Chưa đối chiếu được MST do mất mạng; kiểm tra sau.');
   return true;
  }
 }
 Future<void> _create({Map<String,dynamic>? edit})async{
  final name=TextEditingController(),address=TextEditingController(),
   phone=TextEditingController(),tax=TextEditingController(),note=TextEditingController();
  var category=edit?['category']?.toString()??'van_phong_pham',
   p=edit?['province']?.toString()??(province.isNotEmpty?province:''),
   d=edit?['district']?.toString()??(district.isNotEmpty?district:'');
  final regions=widget.regions;
  final school=widget.initialSchool;
  if(school!=null&&edit==null){p=school['province_old'].toString();d=school['district_old'].toString();}
  if(edit!=null){name.text=edit['name']?.toString()??'';address.text=edit['address_line']?.toString()??'';
   phone.text=edit['phone']?.toString()??'';tax.text=edit['tax_code']?.toString()??'';
   note.text=edit['note']?.toString()??'';}
  try{
   final payload=await showDialog<Map<String,dynamic>>(context:context,builder:(ctx)=>
    StatefulBuilder(builder:(ctx,refresh)=>AlertDialog(
    title:Text(edit!=null?'Sửa điểm bán':school==null?'Thêm điểm bán tiềm năng':'Điểm bán gần ${school['name']}'),
    content:SizedBox(width:460,child:SingleChildScrollView(child:Column(
     mainAxisSize:MainAxisSize.min,children:[
     TextField(controller:name,maxLength:240,decoration:const InputDecoration(labelText:'Tên điểm bán *')),
     const SizedBox(height:8),
     DropdownButtonFormField<String>(
      key:ValueKey('market-province:$p'),initialValue:p.isEmpty?null:p,
      isExpanded:true,decoration:const InputDecoration(labelText:'Tỉnh cũ *'),
      items:[for(final value in regions.provinces)DropdownMenuItem(value:value,
       child:Text(value,overflow:TextOverflow.ellipsis))],
      onChanged:school==null&&edit==null?(v)=>refresh((){p=v??'';d='';}):null),
     const SizedBox(height:8),
     DropdownButtonFormField<String>(
      key:ValueKey('market-district:$p:$d'),initialValue:d.isEmpty?null:d,
      isExpanded:true,decoration:const InputDecoration(labelText:'Huyện cũ *'),
      items:[for(final value in regions.districts[p]??<String>[])
       DropdownMenuItem(value:value,child:Text(value,overflow:TextOverflow.ellipsis))],
      onChanged:school==null&&edit==null?(v)=>refresh(()=>d=v??''):null),
     const SizedBox(height:8),
     TextField(controller:address,maxLength:500,decoration:const InputDecoration(labelText:'Địa chỉ *')),
     const SizedBox(height:8),
     DropdownButtonFormField<String>(initialValue:category,isExpanded:true,
      decoration:const InputDecoration(labelText:'Loại điểm bán'),
      items:const [
       DropdownMenuItem(value:'van_phong_pham',child:Text('Văn phòng phẩm')),
       DropdownMenuItem(value:'nha_sach',child:Text('Nhà sách')),
       DropdownMenuItem(value:'dai_ly',child:Text('Đại lý')),
       DropdownMenuItem(value:'npp',child:Text('Nhà phân phối')),
       DropdownMenuItem(value:'tap_hoa',child:Text('Tạp hóa')),
       DropdownMenuItem(value:'cua_hang',child:Text('Cửa hàng')),
       DropdownMenuItem(value:'khac',child:Text('Khác')),
      ],onChanged:(v)=>refresh(()=>category=v??category)),
     TextField(controller:phone,maxLength:20,keyboardType:TextInputType.phone,
      decoration:const InputDecoration(labelText:'Điện thoại (không bắt buộc)')),
     TextField(controller:tax,maxLength:20,
      decoration:const InputDecoration(labelText:'Mã số thuế (không bắt buộc)')),
     TextField(controller:note,maxLength:2000,maxLines:2,
      decoration:const InputDecoration(labelText:'Ghi chú')),
    ]))),
    actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Hủy')),
     FilledButton(onPressed:(){
      final n=name.text.trim(),a=address.text.trim(),t=tax.text.replaceAll(RegExp(r'[\s.-]'),'');
      if(n.length<2||a.length<3||p.isEmpty||d.isEmpty||
        (t.isNotEmpty&&!RegExp(r'^\d{10}(\d{3})?$').hasMatch(t))){
       ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content:Text('Cần tên, địa bàn, địa chỉ; MST nếu có phải đủ 10 hoặc 13 số')));return;
      }
      Navigator.pop(ctx,{
       'client_ref':const Uuid().v4(),'name':n,'address_line':a,
       if(edit==null)'province':p,
       if(edit==null)'district':d,
       if(edit!=null)'version':edit['version'],
       'category':category,'phone':phone.text.trim().isEmpty?null:phone.text.trim(),
       'tax_code':t.isEmpty?null:t,'note':note.text.trim(),
       if(school!=null&&edit==null)'school_id':school['id'],
      });
     },child:Text(edit==null?'Lưu điểm bán':'Lưu sửa'))],
   )));
   if(payload==null||!mounted)return;
   final mst=payload['tax_code'] as String?;
   if(mst!=null&&mst!=edit?['tax_code']?.toString()&& !await _confirmTax(mst))return;
   await widget.queue.enqueue(edit==null?'/api/v1/market-prospects':'/api/v1/market-prospects/${edit['id']}',payload,method:edit==null?'POST':'PATCH');
   _notice('Đã lưu thông tin trên máy · chờ đồng bộ');
   if(mounted)setState((){});
  }catch(e){_notice('Chưa lưu được: $e');}
  finally{name.dispose();address.dispose();phone.dispose();tax.dispose();note.dispose();}
 }
 Future<void> _visit(Map<String,dynamic> lead)async{
  if(lead['pending_status']=='blocked'){_notice('Điểm bán bị từ chối đồng bộ. Kiểm tra trước khi ghi GPS.');return;}
  try{
   final pos=await captureGps(context);
   if(!mounted)return;
   if(!pos.accuracy.isFinite||pos.accuracy<0||pos.accuracy>100){
    _notice('GPS chưa đủ chính xác: yêu cầu sai số ≤100 m');return;
   }
   final note=TextEditingController();
   final ok=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
    title:const Text('Xác nhận đã ghé thực tế'),
    content:Column(mainAxisSize:MainAxisSize.min,children:[
     Text('Sai số GPS: ${pos.accuracy.toStringAsFixed(0)} m'),
     TextField(controller:note,maxLines:2,maxLength:2000,
      decoration:const InputDecoration(labelText:'Kết quả tiếp xúc')),
    ]),
    actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Hủy')),
     FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Lưu lượt ghé'))]));
   if(ok!=true){note.dispose();return;}
   final text=note.text.trim();note.dispose();
   await widget.queue.enqueue('/api/v1/market-prospects/${lead['id']}/visits',{
    'client_ref':const Uuid().v4(),
    'captured_at':pos.timestamp.toUtc().toIso8601String(),
    'latitude':pos.latitude,'longitude':pos.longitude,
    'accuracy_m':pos.accuracy,'location_consent':true,'note':text,
   },dependsOn:lead['pending_status']!=null?[lead['id'].toString()]:const []);
   _notice('Đã lưu GPS ghé thăm trên máy · chờ đồng bộ');
   if(mounted)setState((){});
  }catch(e){_notice('Không ghi nhận được lượt ghé: $e');}
 }
 Future<void> _convert(Map<String,dynamic> lead)async{
  if(lead['pending_status']!=null){_notice('Chờ đồng bộ điểm bán.');return;}
  if((lead['visits'] as num?)?.toInt()==0){
   _notice('Cần ghi nhận lượt ghé thực tế và đồng bộ GPS trước khi chuyển khách');return;
  }
  final mode=await showDialog<String>(context:context,builder:(ctx)=>AlertDialog(
   title:const Text('Đưa vào Khách hàng'),
   content:const Text('Tạo hồ sơ Khách hàng mới mặc định Chưa bán, hoặc liên kết với khách đã có. Lịch sử điểm bán được giữ nguyên.'),
   actions:[
    TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Hủy')),
    TextButton(onPressed:()=>Navigator.pop(ctx,'link'),child:const Text('Liên kết khách có sẵn')),
    FilledButton(onPressed:()=>Navigator.pop(ctx,'new'),child:const Text('Tạo khách mới')),
   ]));
  if(!mounted||mode==null)return;
  String? customerId;
  if(mode=='link'){
   try{
    final customers=<Map<String,dynamic>>[];
    for(var offset=0;offset<1000;offset+=100){
     final uri=Uri(path:'/api/v1/customers',queryParameters:{
      'province':lead['province'].toString(),'limit':'100','offset':'$offset'});
     final result=await widget.session.get(uri.toString());
     final rows=(result['items'] as List? ?? [])
      .map((x)=>Map<String,dynamic>.from(x as Map)).toList();
     customers.addAll(rows.where((x)=>x['district']==lead['district']));
     if(rows.length<100)break;
    }
    if(!mounted)return;
    if(customers.isEmpty){_notice('Không có khách cùng huyện trong quyền được cấp');return;}
    customerId=await showDialog<String>(context:context,builder:(ctx)=>SimpleDialog(
     title:const Text('Chọn hồ sơ Khách hàng có sẵn'),
     children:[SizedBox(height:360,width:390,child:ListView.builder(
      itemCount:customers.length,itemBuilder:(_,i)=>ListTile(
       title:Text(customers[i]['name'].toString()),
       subtitle:Text(customers[i]['address_line']?.toString()??''),
       onTap:()=>Navigator.pop(ctx,customers[i]['id'].toString()))))],
    ));
    if(customerId==null)return;
   }catch(e){_notice('Không tìm được khách hàng: $e');return;}
  }
  try{
   await widget.queue.enqueue('/api/v1/market-prospects/${lead['id']}/convert',{
    'client_ref':const Uuid().v4(),'customer_id':customerId,
   });
   _notice('Đã lưu yêu cầu chuyển khách · chờ đồng bộ');
  }catch(e){_notice('Chưa lưu được yêu cầu chuyển: $e');}
 }
 Future<void> _photo(Map<String,dynamic> lead,ImageSource source)async{
  try{
   final picked=await ImagePicker().pickImage(source:source);
   if(picked==null)return;
   final media=compressSurveyMedia(await picked.readAsBytes());
   final id=const Uuid().v4(),leadId=lead['id'].toString();
   await widget.queue.enqueue('/api/v1/market-prospects/${lead['id']}/photos',{
    'client_ref':id,'kind':'front',
    'captured_at':DateTime.now().toUtc().toIso8601String(),
   },photo:media.image,thumbnail:media.thumbnail,
     sha256:media.hash,thumbnailSha256:media.thumbnailHash,mime:'image/jpeg',
     dependsOn:lead['pending_status']!=null?[leadId]:const []);
   _notice('Ảnh đã lưu trên máy · chờ đồng bộ R2');
  }catch(e){_notice('Không lưu được ảnh: $e');}
 }
 Future<void> _close(Map<String,dynamic> lead)async{
  final accepted=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
   title:const Text('Đánh dấu không phù hợp?'),
   content:const Text('Điểm bán vẫn được giữ lại trong lịch sử, không xóa dữ liệu.'),
   actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Hủy')),
    FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Xác nhận'))]));
  if(accepted!=true)return;
  try{
   await widget.queue.enqueue('/api/v1/market-prospects/${lead['id']}/close',{
    'client_ref':const Uuid().v4(),
   });
   _notice('Đã lưu trạng thái không phù hợp · chờ đồng bộ');
  }catch(e){_notice('Chưa lưu được: $e');}
 }

 Future<void> _openConvertedCustomer(Map<String,dynamic> lead) async {
  final customerId=lead['converted_customer_id']?.toString()??'';
  if(customerId.isEmpty){_notice('Chưa có mã Khách hàng sau đồng bộ');return;}
  try{
   final response=await widget.session.get('/api/v1/customers/$customerId');
   if(!mounted)return;
   final customer=FieldCustomer.fromJson(Map<String,dynamic>.from(response['item'] as Map));
   final service=CustomerService(salesOrigin,widget.session.cookie,
    identity:widget.queue.identity,revision:widget.queue.revision);
   await Navigator.push(context,MaterialPageRoute(builder:(_)=>CustomerDetail(
    service:service,customer:customer,regions:widget.regions,queue:widget.queue)));
  }catch(e){_notice('Không mở được hồ sơ Khách hàng: $e');}
 }
 Future<Uint8List> _image(String leadId,String imageId) async{
  final response=await http.get(widget.session.uri(
   '/api/v1/market-prospects/$leadId/photos/$imageId?thumbnail=1'),
   headers:sessionHeaders(widget.session.cookie)).timeout(const Duration(seconds:15));
  if(response.statusCode!=200)throw StateError('Không tải được ảnh');
  return response.bodyBytes;
 }
 Future<void> _details(Map<String,dynamic> current) async {
  if(current['pending_status']!=null){
   _notice('Điểm bán chưa đồng bộ; có thể xem và sửa ngay trên card.');return;
  }
  final id=current['id'].toString();
  try {
   final response=await Future.wait([
    widget.session.get('/api/v1/market-prospects/$id'),
    widget.session.get('/api/v1/market-prospects/$id/visits'),
    widget.session.get('/api/v1/market-prospects/$id/photos')]);
   if(!mounted)return;
   final item=Map<String,dynamic>.from(response[0]['item'] as Map);
   final visits=(response[1]['items'] as List? ?? [])
    .map((x)=>Map<String,dynamic>.from(x as Map)).toList();
   final photos=(response[2]['items'] as List? ?? [])
    .map((x)=>Map<String,dynamic>.from(x as Map)).toList();
   await showModalBottomSheet<void>(context:context,isScrollControlled:true,
    showDragHandle:true,builder:(sheetCtx)=>SafeArea(child:DraggableScrollableSheet(
     expand:false,initialChildSize:.75,minChildSize:.4,maxChildSize:.94,
     builder:(ctx,scroll)=>ListView(controller:scroll,
      padding:const EdgeInsets.fromLTRB(16,0,16,26),children:[
      Text(item['name']?.toString()??'Điểm bán',
       style:Theme.of(ctx).textTheme.titleLarge),
      const SizedBox(height:6),
      Text(item['address_line']?.toString()??''),
      Text('${item['district']} · ${item['province']}'),
      const SizedBox(height:10),
      Text('Nguồn: ${item['source_kind']??'Chưa xác định'}'),
      if(item['phone']!=null)Text('Điện thoại: ${item['phone']}'),
      if(item['tax_code']!=null)Text('MST: ${item['tax_code']}'),
      if((item['note']?.toString()??'').isNotEmpty)
       Text('Ghi chú: ${item['note']}'),
      if(item['status']=='converted')...[
       const SizedBox(height:12),
       FilledButton.icon(
        onPressed:(){
         Navigator.pop(sheetCtx);
         unawaited(_openConvertedCustomer(item));
        },icon:const Icon(Icons.open_in_new),label:const Text('Mở hồ sơ Khách hàng')),
      ],
      const SizedBox(height:14),
      Text('Lịch sử ghé thực tế · ${visits.length}',
       style:Theme.of(ctx).textTheme.titleMedium),
      if(visits.isEmpty)const Text('Chưa ghi nhận ghé thực tế'),
      for(final v in visits)ListTile(
       dense:true,leading:const Icon(Icons.location_on_outlined),
       title:Text(v['checked_at']?.toString().replaceFirst('T',' ').split('.').first??''),
       subtitle:Text('GPS: ${v['latitude']}, ${v['longitude']} · sai số ${v['accuracy_m']} m'
         '\n${v['note']??''}'),
       isThreeLine:true,
       trailing:IconButton(tooltip:'Mở vị trí GPS trên bản đồ',
        icon:const Icon(Icons.map_outlined),
        onPressed:()=>launchUrl(Uri.https('www.google.com','/maps/search/',{
         'api':'1','query':'${v['latitude']},${v['longitude']}'
        }),mode:LaunchMode.externalApplication)),
      ),
      const SizedBox(height:12),
      Text('Ảnh cửa hàng · ${photos.length}',style:Theme.of(ctx).textTheme.titleMedium),
      if(photos.isEmpty)const Text('Chưa có ảnh đã đồng bộ'),
      if(photos.isNotEmpty)Wrap(spacing:8,runSpacing:8,children:[
       for(final p in photos.take(12))SizedBox(width:110,height:120,
        child:Column(children:[
         Expanded(child:ClipRRect(borderRadius:BorderRadius.circular(8),
          child:FutureBuilder<Uint8List>(
           future:_image(id,p['id'].toString()),
           builder:(_,snapshot)=>snapshot.hasData
            ?Image.memory(snapshot.data!,width:110,fit:BoxFit.cover)
            :Center(child:Icon(snapshot.hasError
             ?Icons.broken_image_outlined:Icons.image_outlined))))),
         Text(p['kind']?.toString()??'Ảnh',maxLines:1,overflow:TextOverflow.ellipsis),
        ])),
      ]),
     ]))));
  }catch(e){_notice('Không tải được lịch sử điểm bán: $e');}
 }

 Widget _card(Map<String,dynamic> lead){
  final isNew=lead['status']=='new',converted=lead['status']=='converted';
  final visits=(lead['visits'] as num?)?.toInt()??0;
  final blocked=lead['pending_status']=='blocked';
  final name=lead['name']?.toString()??'Điểm bán';
  final address=lead['address_line']?.toString()??'';
  final maps=Uri.https('www.google.com','/maps/search/',{
   'api':'1','query':'$name, $address, ${lead['district']}, ${lead['province']}, Việt Nam',
  });
  final pending=widget.queue.pending.any((r)=>
   r['path']?.toString().startsWith('/api/v1/market-prospects/${lead['id']}/')==true);
  return Card(margin:const EdgeInsets.fromLTRB(10,4,10,4),
   child:Padding(padding:const EdgeInsets.all(12),child:Column(
    crossAxisAlignment:CrossAxisAlignment.start,children:[
    Row(children:[
     Expanded(child:Text(name,style:Theme.of(context).textTheme.titleSmall)),
     Text(converted?'Đã chuyển':lead['status']=='closed'?'Không phù hợp':
      visits>0?'Đã ghé':'Chưa ghé',
      style:Theme.of(context).textTheme.labelMedium),
    ]),
    const SizedBox(height:4),
    Text('${lead['district']} · ${lead['province']}',style:Theme.of(context).textTheme.bodySmall),
    Text(address,maxLines:2,overflow:TextOverflow.ellipsis),
    if(lead['school_name']!=null)
      Text('Nguồn: ${lead['school_name']}',style:Theme.of(context).textTheme.labelSmall),
    if(lead['tax_code']!=null)
      Text('MST: ${lead['tax_code']}',style:Theme.of(context).textTheme.labelSmall),
    if((lead['photo_count'] as num?)?.toInt()!=null)
      Text('Ảnh thực tế: ${lead['photo_count']}',style:Theme.of(context).textTheme.labelSmall),
    if(lead['pending_status']!=null||pending)
      Text(blocked?'Đồng bộ bị từ chối · xem Chi tiết đồng bộ':'Có thao tác chờ đồng bộ',
        style:TextStyle(color:Theme.of(context).colorScheme.error)),
    Wrap(spacing:1,runSpacing:0,crossAxisAlignment:WrapCrossAlignment.center,
     children:[
     IconButton(tooltip:'Tìm trên Google Maps (chưa xác minh cổng)',
      onPressed:()=>launchUrl(maps,mode:LaunchMode.externalApplication),
      icon:const Icon(Icons.directions_outlined)),
     if((lead['phone']?.toString()??'').isNotEmpty)...[
      IconButton(tooltip:'Gọi điện',
       onPressed:()=>launchUrl(Uri(scheme:'tel',path:lead['phone'].toString())),
       icon:const Icon(Icons.phone_outlined)),
      IconButton(tooltip:'Mở Zalo',
       onPressed:(){
        final number=lead['phone'].toString().replaceAll(RegExp(r'[^0-9]'),'');
        if(number.isNotEmpty)launchUrl(Uri.https('zalo.me','/$number'),
          mode:LaunchMode.externalApplication);
       },
       icon:const Icon(Icons.chat_bubble_outline)),
     ],
     IconButton(tooltip:'Xem chi tiết, lịch sử và ảnh',
      onPressed:()=>_details(lead),icon:const Icon(Icons.info_outline)),
     if(isNew)PopupMenuButton<ImageSource>(
      tooltip:'Chụp hoặc chọn ảnh cửa hàng',
      icon:const Icon(Icons.add_a_photo_outlined),
      onSelected:(source)=>unawaited(_photo(lead,source)),
      itemBuilder:(_)=>const [
       PopupMenuItem(value:ImageSource.camera,child:Text('Chụp ảnh')),
       PopupMenuItem(value:ImageSource.gallery,child:Text('Chọn ảnh')),
      ]),
     if(isNew&&!converted)
      TextButton(onPressed:blocked?null:()=>_visit(lead),child:const Text('Ghé thăm')),
     if(isNew&&visits>0&&!pending)
      FilledButton.tonal(onPressed:()=>_convert(lead),child:const Text('Đưa vào KH')),
     if(converted)
      TextButton.icon(onPressed:()=>_openConvertedCustomer(lead),
       icon:const Icon(Icons.open_in_new,size:18),label:const Text('Hồ sơ KH')),
     if(isNew&&!pending&&lead['pending_status']==null)
      PopupMenuButton<String>(tooltip:'Thao tác khác',
       onSelected:(v){if(v=='close')unawaited(_close(lead));if(v=='edit')unawaited(_create(edit:lead));},
       itemBuilder:(_)=>const [
        PopupMenuItem(value:'edit',child:Text('Sửa điểm bán')),
        PopupMenuItem(value:'close',child:Text('Không phù hợp')),
       ]),
    ]),
   ])));
 }
 @override Widget build(BuildContext context){
  final all=[...pendingNew,...items.where((i)=>!pendingNew.any((p)=>p['id']==i['id']))];
  return Column(children:[
   Padding(padding:const EdgeInsets.fromLTRB(12,8,12,6),child:Column(
    crossAxisAlignment:CrossAxisAlignment.start,children:[
    // Search and high-contrast actions share one 44px touch row.
    Row(children:[
     Expanded(child:SizedBox(height:44,child:TextField(
      controller:search,
      onChanged:(_){debounce?.cancel();debounce=Timer(
       const Duration(milliseconds:350),(){if(mounted)unawaited(_load());});},
      decoration:const InputDecoration(
       hintText:'Tìm điểm bán',isDense:true,
       contentPadding:EdgeInsets.symmetric(horizontal:10,vertical:10),
       prefixIcon:Icon(Icons.search_outlined,size:20),
       prefixIconConstraints:BoxConstraints(minWidth:38)),
     ))),
     const SizedBox(width:6),
     // Explicit high-contrast foreground and text glyphs: some iOS WebKit
     // builds show filled IconButton circles without the rounded icon glyphs.
     SizedBox(width:44,height:44,child:IconButton(
      key:const ValueKey('market-prospects-refresh'),
      tooltip:'Làm mới danh sách',
      onPressed:loading?null:()=>_load(),
      style:IconButton.styleFrom(
       backgroundColor:Theme.of(context).colorScheme.surfaceContainerHighest,
       foregroundColor:Theme.of(context).colorScheme.onSurface,
       disabledBackgroundColor:Theme.of(context).colorScheme.surfaceContainerHighest,
       disabledForegroundColor:Theme.of(context).colorScheme.onSurfaceVariant,
       padding:EdgeInsets.zero,
       shape:RoundedRectangleBorder(
        borderRadius:BorderRadius.circular(SalesTheme.controlRadius))),
      icon:Text('↻',style:TextStyle(
       fontSize:30,height:1,fontWeight:FontWeight.w700,
       color:loading
        ?Theme.of(context).colorScheme.onSurfaceVariant
        :Theme.of(context).colorScheme.onSurface)))),
     const SizedBox(width:6),
     SizedBox(width:44,height:44,child:IconButton(
      key:const ValueKey('market-prospects-add'),
      tooltip:'Thêm điểm bán',
      onPressed:_create,
      style:IconButton.styleFrom(
       backgroundColor:Theme.of(context).colorScheme.primary,
       foregroundColor:Theme.of(context).colorScheme.onPrimary,
       padding:EdgeInsets.zero,
       shape:RoundedRectangleBorder(
        borderRadius:BorderRadius.circular(SalesTheme.controlRadius))),
      icon:Text('+',style:TextStyle(
       fontSize:29,height:1,fontWeight:FontWeight.w700,
       color:Theme.of(context).colorScheme.onPrimary)))),
    ]),
    const SizedBox(height:8),
    // All three searchable filters remain on one row on narrow phones.
    Row(children:[
     Expanded(child:DropdownButtonFormField<String>(
      key:ValueKey('filter-province:$province'),
      initialValue:province,isExpanded:true,
      style:Theme.of(context).textTheme.bodyMedium?.copyWith(
       fontSize:SalesTheme.controlFontSize,
       color:Theme.of(context).colorScheme.onSurface),
      icon:const Icon(Icons.expand_more,size:18),
      decoration:const InputDecoration(
       labelText:'Tỉnh cũ',isDense:true,
       contentPadding:EdgeInsets.symmetric(horizontal:8,vertical:9)),
      items:[const DropdownMenuItem(value:'',child:Text('Tất cả')),
       for(final p in widget.regions.provinces)DropdownMenuItem(value:p,
        child:Text(p,maxLines:1,overflow:TextOverflow.ellipsis))],
      onChanged:widget.initialSchool!=null?null:(v){
       setState((){province=v??'';district='';});unawaited(_load());
      })),
     const SizedBox(width:6),
     Expanded(child:DropdownButtonFormField<String>(
      key:ValueKey('filter-district:$province:$district'),
      initialValue:district,isExpanded:true,
      style:Theme.of(context).textTheme.bodyMedium?.copyWith(
       fontSize:SalesTheme.controlFontSize,
       color:Theme.of(context).colorScheme.onSurface),
      icon:const Icon(Icons.expand_more,size:18),
      decoration:const InputDecoration(
       labelText:'Huyện cũ',isDense:true,
       contentPadding:EdgeInsets.symmetric(horizontal:8,vertical:9)),
      items:[const DropdownMenuItem(value:'',child:Text('Tất cả')),
       for(final d in widget.regions.districts[province]??<String>[])
        DropdownMenuItem(value:d,
         child:Text(d,maxLines:1,overflow:TextOverflow.ellipsis))],
      onChanged:widget.initialSchool!=null||province.isEmpty?null:(v){
       setState(()=>district=v??'');unawaited(_load());
      })),
     const SizedBox(width:6),
     Expanded(child:DropdownButtonFormField<String>(
      key:ValueKey('filter-status:$status'),
      initialValue:status,isExpanded:true,
      style:Theme.of(context).textTheme.bodyMedium?.copyWith(
       fontSize:SalesTheme.controlFontSize,
       color:Theme.of(context).colorScheme.onSurface),
      icon:const Icon(Icons.expand_more,size:18),
      decoration:const InputDecoration(
       labelText:'Trạng thái',isDense:true,
       contentPadding:EdgeInsets.symmetric(horizontal:8,vertical:9)),
      items:const [
       DropdownMenuItem(value:'',child:Text('Tất cả',maxLines:1)),
       DropdownMenuItem(value:'new',child:Text('Đang tìm',maxLines:1)),
       DropdownMenuItem(value:'converted',child:Text('Đã chuyển',maxLines:1)),
       DropdownMenuItem(value:'closed',child:Text('Không phù hợp',
        maxLines:1,overflow:TextOverflow.ellipsis)),
      ],
      onChanged:(v){setState(()=>status=v??'');unawaited(_load());})),
    ]),
    const SizedBox(height:6),
    Text(offline?'Dữ liệu đã lưu máy · cần mạng để cập nhật':'$total điểm bán phù hợp',
      style:Theme.of(context).textTheme.bodySmall),
    if(error!=null)Text(error!,style:TextStyle(color:Theme.of(context).colorScheme.error)),
   ])),
   if(loading&&items.isEmpty)const LinearProgressIndicator(minHeight:2),
   Expanded(child:all.isEmpty
     ?Center(child:Text(loading?'Đang tải...':'Chưa có điểm bán tiềm năng'))
     :ListView.builder(itemCount:all.length+(more?1:0),itemBuilder:(ctx,i){
       if(i==all.length)return Padding(padding:const EdgeInsets.all(12),
        child:OutlinedButton(onPressed:loading?null:()=>_load(append:true),
         child:Text(loading?'Đang tải...':'Tải thêm')));
       return _card(all[i]);
      })),
  ]);
 }
}
