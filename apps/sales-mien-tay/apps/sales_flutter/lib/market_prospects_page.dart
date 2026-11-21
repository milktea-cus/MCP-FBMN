import 'dart:async';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'survey_media.dart';
import 'customers.dart';
import 'models.dart';
import 'offline_queue.dart';
import 'session.dart';

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
 String _cacheKey(int n)=>'market-prospects:v1:$province:$district:$status:$n';
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
 Future<void> _create()async{
  final name=TextEditingController(),address=TextEditingController(),
   phone=TextEditingController(),tax=TextEditingController(),note=TextEditingController();
  var category='van_phong_pham',p=province.isNotEmpty?province:'',
   d=district.isNotEmpty?district:'';
  final regions=widget.regions;
  final school=widget.initialSchool;
  if(school!=null){p=school['province_old'].toString();d=school['district_old'].toString();}
  try{
   final payload=await showDialog<Map<String,dynamic>>(context:context,builder:(ctx)=>
    StatefulBuilder(builder:(ctx,refresh)=>AlertDialog(
    title:Text(school==null?'Thêm điểm bán tiềm năng':'Điểm bán gần ${school['name']}'),
    content:SizedBox(width:460,child:SingleChildScrollView(child:Column(
     mainAxisSize:MainAxisSize.min,children:[
     TextField(controller:name,maxLength:240,decoration:const InputDecoration(labelText:'Tên điểm bán *')),
     const SizedBox(height:8),
     DropdownButtonFormField<String>(
      key:ValueKey('market-province:$p'),initialValue:p.isEmpty?null:p,
      isExpanded:true,decoration:const InputDecoration(labelText:'Tỉnh cũ *'),
      items:[for(final value in regions.provinces)DropdownMenuItem(value:value,
       child:Text(value,overflow:TextOverflow.ellipsis))],
      onChanged:school==null?(v)=>refresh((){p=v??'';d='';}):null),
     const SizedBox(height:8),
     DropdownButtonFormField<String>(
      key:ValueKey('market-district:$p:$d'),initialValue:d.isEmpty?null:d,
      isExpanded:true,decoration:const InputDecoration(labelText:'Huyện cũ *'),
      items:[for(final value in regions.districts[p]??<String>[])
       DropdownMenuItem(value:value,child:Text(value,overflow:TextOverflow.ellipsis))],
      onChanged:school==null?(v)=>refresh(()=>d=v??''):null),
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
       'client_ref':const Uuid().v4(),'name':n,'address_line':a,'province':p,
       'district':d,'category':category,'phone':phone.text.trim().isEmpty?null:phone.text.trim(),
       'tax_code':t.isEmpty?null:t,'note':note.text.trim(),
       if(school!=null)'school_id':school['id'],
      });
     },child:const Text('Lưu điểm bán'))],
   )));
   if(payload==null||!mounted)return;
   final mst=payload['tax_code'] as String?;
   if(mst!=null&& !await _confirmTax(mst))return;
   await widget.queue.enqueue('/api/v1/market-prospects',payload);
   _notice('Đã lưu điểm bán trên máy · chờ đồng bộ');
   if(mounted)setState((){});
  }catch(e){_notice('Chưa lưu được: $e');}
  finally{name.dispose();address.dispose();phone.dispose();tax.dispose();note.dispose();}
 }
 Future<void> _visit(Map<String,dynamic> lead)async{
  if(lead['pending_status']!=null){_notice('Cần đồng bộ điểm bán mới trước khi ghé.');return;}
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
   });
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
    Row(children:[
     IconButton(tooltip:'Tìm trên Google Maps (chưa xác minh cổng)',
      onPressed:()=>launchUrl(maps,mode:LaunchMode.externalApplication),
      icon:const Icon(Icons.directions_outlined)),
     if((lead['phone']?.toString()??'').isNotEmpty)
      IconButton(tooltip:'Gọi điện',
       onPressed:()=>launchUrl(Uri(scheme:'tel',path:lead['phone'].toString())),
       icon:const Icon(Icons.phone_outlined)),
     if(isNew)PopupMenuButton<ImageSource>(
      tooltip:'Chụp hoặc chọn ảnh cửa hàng',
      icon:const Icon(Icons.add_a_photo_outlined),
      onSelected:(source)=>unawaited(_photo(lead,source)),
      itemBuilder:(_)=>const [
       PopupMenuItem(value:ImageSource.camera,child:Text('Chụp ảnh')),
       PopupMenuItem(value:ImageSource.gallery,child:Text('Chọn ảnh')),
      ]),
     const Spacer(),
     if(isNew&&!converted)
      TextButton(onPressed:blocked?null:()=>_visit(lead),child:const Text('Ghé thăm')),
     if(isNew&&visits>0&&!pending)
      FilledButton.tonal(onPressed:()=>_convert(lead),child:const Text('Đưa vào KH')),
     if(isNew&&!pending&&lead['pending_status']==null)
      PopupMenuButton<String>(tooltip:'Thao tác khác',
       onSelected:(v){if(v=='close')unawaited(_close(lead));},
       itemBuilder:(_)=>[const PopupMenuItem(value:'close',child:Text('Không phù hợp'))]),
    ]),
   ])));
 }
 @override Widget build(BuildContext context){
  final all=[...pendingNew,...items.where((i)=>!pendingNew.any((p)=>p['id']==i['id']))];
  return Column(children:[
   Padding(padding:const EdgeInsets.fromLTRB(12,12,12,6),child:Column(
    crossAxisAlignment:CrossAxisAlignment.start,children:[
    Row(children:[Expanded(child:Text('Điểm bán tiềm năng',style:Theme.of(context).textTheme.titleLarge)),
     IconButton(tooltip:'Làm mới',onPressed:loading?null:()=>_load(),
      icon:const Icon(Icons.refresh_outlined)),
     IconButton(tooltip:'Thêm điểm bán',onPressed:_create,icon:const Icon(Icons.add_circle_outline)),
    ]),
    TextField(controller:search,onChanged:(_){debounce?.cancel();debounce=Timer(
     const Duration(milliseconds:350),(){if(mounted)unawaited(_load());});},
     decoration:const InputDecoration(labelText:'Tìm theo tên điểm bán',
      isDense:true,prefixIcon:Icon(Icons.search_outlined))),
    const SizedBox(height:8),
    Row(children:[
     Expanded(child:DropdownButtonFormField<String>(
      key:ValueKey('filter-province:$province'),
      initialValue:province,isExpanded:true,decoration:const InputDecoration(labelText:'Tỉnh cũ',isDense:true),
      items:[const DropdownMenuItem(value:'',child:Text('Tất cả')),
       for(final p in widget.regions.provinces)DropdownMenuItem(value:p,child:Text(p,overflow:TextOverflow.ellipsis))],
      onChanged:widget.initialSchool!=null?null:(v){setState((){province=v??'';district='';});unawaited(_load());})),
     const SizedBox(width:8),
     Expanded(child:DropdownButtonFormField<String>(
      key:ValueKey('filter-district:$province:$district'),
      initialValue:district,isExpanded:true,decoration:const InputDecoration(labelText:'Huyện cũ',isDense:true),
      items:[const DropdownMenuItem(value:'',child:Text('Tất cả')),
       for(final d in widget.regions.districts[province]??<String>[])
        DropdownMenuItem(value:d,child:Text(d,overflow:TextOverflow.ellipsis))],
      onChanged:widget.initialSchool!=null||province.isEmpty?null:(v){setState(()=>district=v??'');unawaited(_load());})),
    ]),
    const SizedBox(height:6),
    Wrap(spacing:8,children:[
     for(final v in <String>['','new','converted','closed'])
      ChoiceChip(label:Text(switch(v){'new'=>'Đang tìm','converted'=>'Đã chuyển','closed'=>'Không phù hợp',_=>'Tất cả'}),
       selected:status==v,onSelected:(_){setState(()=>status=v);unawaited(_load());}),
    ]),
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
