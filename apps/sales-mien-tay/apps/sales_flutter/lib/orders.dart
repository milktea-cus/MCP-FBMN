import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'actuals.dart';
import 'offline_queue.dart';
import 'order_export.dart';
import 'session.dart';
import 'order_picker.dart';
import 'order_cart_line.dart';

List<Map<String,dynamic>> orderRows(Object? value)=>(value as List? ?? []).map((x)=>Map<String,dynamic>.from(x as Map)).toList();
String orderTotalByUnit(List<Map<String,dynamic>> lines){
 final quantities=<String,int>{};
 for(final line in lines){
  final unit=line['unit']?.toString()??'—';
  quantities[unit]=(quantities[unit]??0)+(int.tryParse('${line['quantity']}')??0);
 }
 return quantities.entries.map((e)=>'${e.value} ${e.key}').join(' · ');
}
String orderStatus(String value)=>switch(value){
 'exported'=>'Đã xuất · chưa xác nhận nhập','imported'=>'Đã nhập công ty (Admin xác nhận)',
 'draft'=>'Nháp trên hệ thống','local'=>'Nháp trên máy',
  'cancelled'=>'Đã hủy (có nhật ký)','superseded'=>'Đã thay thế',_=>'Chưa xác định',
};
bool orderStockStale(Object? value,{DateTime? now}){
 final time=DateTime.tryParse(value?.toString()??'');
 if(time==null)return true;
 return (now??DateTime.now()).toUtc().difference(time.toUtc())>const Duration(hours:24);
}
String orderStockMessage(Map<String,dynamic> line,{DateTime? now}){
 final available=int.tryParse('${line['available']??line['quantity_stock']??''}');
 final qty=int.tryParse('${line['quantity']}')??0;
 if(available==null)return 'Chưa có số tồn';
 if(available<qty)return 'Thiếu tồn (${available - qty})';
 if(orderStockStale(line['snapshot_at'],now:now))return 'Tồn cũ · phải kiểm tra lại';
 return 'Tồn: $available ${line['unit']}';
}

bool orderCanEdit(String status)=>status=='draft'||status=='local';
bool orderCanCancel(String status,{required bool admin})=>
 status=='draft'||status=='local'||(status=='exported'&&admin);
bool orderCanReplace(String status,{required bool admin,bool alreadyReplaced=false})=>
 admin&&!alreadyReplaced&&(status=='exported'||status=='imported');
bool orderFilterRow(Map<String,dynamic> row,{
 String query='',String status='',DateTimeRange? range,
}){
 final kind=row['status']?.toString()??'local';
 if(status.isNotEmpty&&status!=kind)return false;
 final q=query.trim().toLowerCase();
 if(q.isNotEmpty&&![
  row['id'],row['customer_name'],row['customer_code'],row['note'],
  row['customer'] is Map?(row['customer'] as Map)['name']:null,
 ].any((x)=>(x?.toString()??'').toLowerCase().contains(q)))return false;
 if(range!=null){
  final created=DateTime.tryParse(row['created_at']?.toString()??'');
  if(created==null)return false;
  final date=DateTime(created.year,created.month,created.day);
  final start=DateTime(range.start.year,range.start.month,range.start.day);
  final end=DateTime(range.end.year,range.end.month,range.end.day);
  if(date.isBefore(start)||date.isAfter(end))return false;
 }
 return true;
}
String _orderDate(DateTime date)=>
 '${date.year.toString().padLeft(4,'0')}-${date.month.toString().padLeft(2,'0')}-${date.day.toString().padLeft(2,'0')}';
String orderEventStatus(Object? data){
 final raw=data is Map?data['item']??data:data;
 return raw is Map?orderStatus(raw['status']?.toString()??''):
   'Không xác định';
}

class OrdersPage extends StatefulWidget{
 final OfflineQueue queue;
 final bool admin;
 final ActualClient? client;
 const OrdersPage({super.key,required this.queue,required this.admin,this.client});
 @override State<OrdersPage> createState()=>_OrdersPageState();
}
class _OrdersPageState extends State<OrdersPage>{
 late final ActualClient client=widget.client??ActualClient(widget.queue);
 final note=TextEditingController();
 List<Map<String,dynamic>> saved=[],drafts=[],lines=[];
 Map<String,dynamic>? selected,customer,removedLine;
 Object? removedFromOrder;
 int removedIndex=0;
 bool busy=false,offline=false,loading=true,localSaving=false;
 String? error,localError;
 int localGeneration=0;
 String operation=const Uuid().v4();
 Future<void> writes=Future.value();
 final search=TextEditingController();
 Timer? searchDebounce;
 String filterStatus='';
 DateTimeRange? filterDates;
 Map<String,dynamic>? pendingLifecycle;
 int listGeneration=0;
 bool get canEdit=>selected!=null&&orderCanEdit(selected!['status']?.toString()??'local');
 bool get hasServerVersion=>(selected?['version'] as int? ?? 0)>0;
 String get draftKey=>'order-drafts-v1';
 @override void initState(){super.initState();load();}
 @override void dispose(){searchDebounce?.cancel();search.dispose();note.dispose();super.dispose();}
 Map<String,dynamic> snapshot(){
  final base=Map<String,dynamic>.from(selected??{});
  return {...base,'note':note.text,'customer':customer,'lines':[for(final l in lines)Map<String,dynamic>.from(l)],'client_ref':operation};
 }
 void localChanged(){
  if(selected==null)return;
  operation=const Uuid().v4();
  selected!['note']=note.text;
  selected!['local_dirty']=true;
  setState((){});
  unawaited(_persist().catchError((_){ }));
 }
 Future<void> _persist()async{
  if(selected==null)return;
  final snap=snapshot();
  final generation=++localGeneration;
  drafts.removeWhere((d)=>d['id']==snap['id']);
  drafts.add(snap);
  final data=[for(final d in drafts)Map<String,dynamic>.from(d)];
  if(mounted)setState((){localSaving=true;localError=null;});
  writes=writes.catchError((_){ }).then((_)=>widget.queue.cache(draftKey,data));
  try{
   await writes;
   if(mounted&&generation==localGeneration)setState(()=>localSaving=false);
  }catch(e){
   if(mounted&&generation==localGeneration){
    setState((){localSaving=false;localError='Không lưu được nháp trên máy. Thử lại.';});
   }
   rethrow;
  }
 }
 Future<void> _removeLocal(String id)async{
  drafts.removeWhere((d)=>d['id']==id);
  final data=[for(final d in drafts)Map<String,dynamic>.from(d)];
  writes=writes.catchError((_){ }).then((_)=>widget.queue.cache(draftKey,data));
  await writes;
 }
 Future<void> load()async{
  final generation=++listGeneration;
  if(mounted)setState((){loading=true;error=null;});
  try{
   final cached=await widget.queue.cached(draftKey);
   if(mounted&&generation==listGeneration)setState((){drafts=cached;loading=false;});
  }catch(_){
   if(mounted&&generation==listGeneration)setState((){
    loading=false;error='Không đọc được nháp trên máy. Kiểm tra bộ nhớ rồi thử lại.';
   });
  }
  final options=<String,String>{};
  final q=search.text.trim();
  if(q.isNotEmpty)options['q']=q;
  if(filterStatus.isNotEmpty&&filterStatus!='local')options['status']=filterStatus;
  if(filterDates!=null){
   options['from']=_orderDate(filterDates!.start);
   options['to']=_orderDate(filterDates!.end);
  }
  try{
   final doc=await client.get(saleParam('/api/v1/orders',options))
       .timeout(const Duration(seconds:8));
   if(mounted&&generation==listGeneration)setState((){
    saved=orderRows(doc['items']);offline=false;error=null;
   });
  }catch(e){
   if(!mounted||generation!=listGeneration)return;
   setState((){
    saved=[];offline=true;
    if(e is ApiFailure&&(e.status==401||e.status==403)){
     drafts=[];error='Phiên hoặc địa bàn bị thu hồi; vui lòng đăng nhập lại.';
    }else{
     error='Mất kết nối · vẫn có thể soạn đơn ngoại tuyến.';
    }
   });
  }
 }
 void searchChanged(String _){
  setState((){});
  searchDebounce?.cancel();
  searchDebounce=Timer(const Duration(milliseconds:280),(){
   if(mounted)unawaited(load());
  });
 }
 Future<void> pickOrderDates()async{
  final chosen=await showDateRangePicker(
   context:context,initialDateRange:filterDates,
   firstDate:DateTime(2020),lastDate:DateTime(DateTime.now().year+2),
   helpText:'Lọc đơn theo ngày tạo',
  );
  if(chosen!=null&&mounted){
   setState(()=>filterDates=chosen);
   unawaited(load());
  }
 }
 void create(){
  final id=const Uuid().v4();
  note.clear();customer=null;lines=[];removedLine=null;operation=const Uuid().v4();
  setState(()=>selected={'id':id,'owner_sub':widget.queue.identity,'customer_id':'','status':'local','version':0,'note':'','local_dirty':true,'created_at':DateTime.now().toUtc().toIso8601String()});
  unawaited(_persist().catchError((_){ }));
 }
 Future<void> open(Map<String,dynamic> row)async{
  if(selected!=null&&selected!['local_dirty']==true)await _persist();
  final r=Map<String,dynamic>.from(row);
  final local=drafts.where((d)=>d['id']==r['id']).firstOrNull;
  final source=local??r;
  removedLine=null;
  note.text=source['note']?.toString()??'';
  customer=source['customer'] is Map?Map<String,dynamic>.from(source['customer'] as Map):{
   'id':source['customer_id'],'owner_sub':source['owner_sub'],
   'name':source['customer_name']??'', 'export_code':source['customer_code']};
  lines=orderRows(source['lines']);
  operation=source['client_ref']?.toString()??const Uuid().v4();
  if(mounted)setState(()=>selected=Map<String,dynamic>.from(source));
 }
 Future<void> chooseCustomer()async{
  if(!canEdit||busy)return;
  final item=await showDialog<Map<String,dynamic>>(context:context,
   builder:(_)=>OrderPicker(client:client,queue:widget.queue,type:'customers'));
  if(item==null||!mounted)return;
  setState((){
   customer=item;selected!['customer_id']=item['id'];
   selected!['owner_sub']=item['owner_sub'];
  });localChanged();
 }
 Future<void> addProduct()async{
  if(!canEdit||busy)return;
  final item=await showDialog<Map<String,dynamic>>(context:context,
    builder:(_)=>OrderPicker(client:client,queue:widget.queue,type:'products'));
  if(item==null||!mounted)return;
  final productId=item['id']?.toString()??'';
  if(productId.isEmpty){
   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Sản phẩm chưa có mã đồng bộ.')));
   return;
  }
  final existing=lines.indexWhere((x)=>x['product_id']==productId);
  if(existing>=0){
   final quantity=int.tryParse('${lines[existing]['quantity']}')??0;
   if(quantity>=100000000){
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Số lượng đã đạt giới hạn.')));
    return;
   }
   changeLineQuantity(existing,quantity+1);
   return;
  }
  if(item['unit']==null||item['unit'].toString().trim().isEmpty){
   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Chưa có đơn vị tính, cần cập nhật sản phẩm trước.')));
   return;
  }
  lines.add({
   'line_id':const Uuid().v4(),'product_id':productId,'company_code':item['company_code'],
   'name':item['name'],'unit':item['unit'],'quantity':1,
   'available':item['quantity'],'snapshot_at':item['snapshot_at'],
  });localChanged();
 }
 void changeLineQuantity(int index,int amount){
  if(!canEdit||busy||index<0||index>=lines.length||amount<1||amount>100000000)return;
  if(lines[index]['quantity']==amount)return;
  lines[index]['quantity']=amount;
  localChanged();
 }
 void removeLine(int index){
  if(!canEdit||busy||index<0||index>=lines.length)return;
  removedFromOrder=selected!['id'];
  removedIndex=index;
  removedLine=Map<String,dynamic>.from(lines.removeAt(index));
  localChanged();
 }
 void undoRemove(){
  final removed=removedLine;
  if(removed==null||!canEdit||busy||selected?['id']!=removedFromOrder)return;
  if(lines.any((line)=>line['product_id']==removed['product_id'])){
   setState(()=>removedLine=null);return;
  }
  lines.insert(removedIndex>lines.length?lines.length:removedIndex,removed);
  removedLine=null;
  localChanged();
 }
 String get localStatus{
  if(localError!=null)return localError!;
  if(localSaving)return 'Đang lưu trên máy…';
  if(selected?['status']=='local'||selected?['local_dirty']==true){
   return offline?'Đã lưu trên máy · chờ kết nối':'Đã lưu trên máy · chưa đồng bộ';
  }
  return 'Đã lưu trên hệ thống';
 }
 Future<bool> saveOnline()async{
  if(selected==null||offline||busy)return false;
  if(customer==null||customer!['id']==null||lines.isEmpty){
   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Chọn khách và ít nhất một sản phẩm.')));
   return false;
  }
  if(lines.length>100||lines.any((l){
   final n=int.tryParse('${l['quantity']}');
   return n==null||n<1||n>100000000;
  })){
   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Kiểm lại số lượng và số mã trong giỏ.')));
   return false;
  }
  try{await _persist();}catch(_){return false;}
  if(!mounted)return false;
  setState(()=>busy=true);
  try{
   final doc=await client.post('/api/v1/orders',{
    'id':selected!['id'],'client_ref':operation,
    'version':selected!['version']??0,'owner_sub':customer!['owner_sub'],
    'customer_id':customer!['id'],'action':'save','accept_stale':false,
    'note':note.text,'lines':[for(final l in lines){
      'line_id':l['line_id'],'product_id':l['product_id'],
      'quantity':l['quantity'],'unit':l['unit']
    }],
   });
   final item=Map<String,dynamic>.from(doc['item'] as Map);
   selected={...selected!,...item,'status':item['status'],'local_dirty':false};
   saved.removeWhere((d)=>d['id']==item['id']);
   saved.insert(0,{...selected!,'customer_name':customer?['name'],
    'customer_code':customer?['export_code'],
    'lines':[for(final l in lines)Map<String,dynamic>.from(l)]});
   operation=const Uuid().v4();
   try{
    await _removeLocal(item['id'].toString());
   }catch(_){
    if(mounted)setState(()=>localError='Đã lưu hệ thống; chưa dọn được nháp máy.');
   }
   if(mounted){
    setState((){});
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Đã lưu đơn trên hệ thống.')));
   }
   return true;
  }catch(e){
   if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Chưa lưu hệ thống: $e')));
   return false;
  }finally{if(mounted)setState(()=>busy=false);}
 }
 Future<void> issue()async{
  if(selected==null||offline||busy)return;
  if(selected!['status']=='local'||selected!['local_dirty']==true||
     localSaving||localError!=null){
   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
    content:Text('Lưu đơn trên hệ thống trước khi xuất phiếu.')));
   return;
  }
  if(selected!['status']!='draft')return;
  final confirmed=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(
   title:const Text('Xuất phiếu yêu cầu hàng'),
   content:const Text(
    'Field Work ghi nhận yêu cầu của Sales, không kiểm tồn, không giữ hàng, không trừ kho và không ghi doanh số. Mã khách CTY có thể bổ sung sau để nhập vào app công ty.'),
   actions:[
    TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Đóng')),
    FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Xuất phiếu')),
   ],
  ));
  if(confirmed!=true||!mounted)return;
  setState(()=>busy=true);
  try{
   final doc=await client.post('/api/v1/orders',{
    'id':selected!['id'],'client_ref':const Uuid().v4(),
    'version':selected!['version']??0,'owner_sub':selected!['owner_sub'],
    'customer_id':selected!['customer_id'],'action':'export',
    'accept_stale':false,'note':note.text,'lines':[],
   });
   selected={...selected!,...Map<String,dynamic>.from(doc['item'] as Map)};
   await _removeLocal(selected!['id'].toString());
   if(mounted)setState((){});
   await download();
  }catch(e){
   if(mounted)ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content:Text('Chưa xuất phiếu: $e')));
  }finally{if(mounted)setState(()=>busy=false);}
 }
 Future<void> download()async{
  if(selected==null||offline)return;
  try{
   final doc=await client.get('/api/v1/orders/${selected!['id']}/export');
   final order=Map<String,dynamic>.from(doc['item'] as Map);
   final bytes=buildOrderPreparationXlsx(order);
   final path=await FilePicker.platform.saveFile(dialogTitle:'Lưu file đơn',
    fileName:'field-work-order-${order['id']}.xlsx',
    type:FileType.custom,allowedExtensions:['xlsx'],bytes:bytes);
   if(path==null&&mounted)ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content:Text('Chưa lưu file. Có thể tải lại từ đơn đã xuất.')));
  }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Không lưu được Excel: $e')));}
 }
 Future<void> markImported()async{
  if(!widget.admin||offline||selected?['status']!='exported')return;
  final controller=TextEditingController();
  final ref=await showDialog<String>(context:context,builder:(c)=>AlertDialog(
   title:const Text('Xác nhận đã nhập app công ty'),
   content:TextField(controller:controller,decoration:const InputDecoration(
    labelText:'Mã tham chiếu nhập từ app công ty',helperText:'Chỉ Admin xác nhận sau khi kiểm chứng thực tế')),
   actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('Hủy')),
    FilledButton(onPressed:()=>Navigator.pop(c,controller.text.trim()),child:const Text('Xác nhận'))]));
  controller.dispose();if(ref==null||ref.isEmpty||ref.length>120||!mounted)return;
  setState(()=>busy=true);
  try{
   final doc=await client.post('/api/v1/orders',{
    'id':selected!['id'],'client_ref':const Uuid().v4(),
    'version':selected!['version'],'owner_sub':selected!['owner_sub'],
    'customer_id':selected!['customer_id'],'action':'imported','accept_stale':false,
    'import_reference':ref,'note':note.text,'lines':[],
   });
   selected={...selected!,...Map<String,dynamic>.from(doc['item'] as Map)};
   if(mounted)setState((){});
  }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$e')));}
  finally{if(mounted)setState(()=>busy=false);}
 }
 Future<String?> lifecycleReason(String mode)=>showDialog<String>(
  context:context,barrierDismissible:false,
  builder:(_)=>_OrderLifecycleReasonDialog(
   mode:mode,status:selected?['status']?.toString()??'',
  ),
 );
 Future<void> lifecycle(String mode)async{
  if(selected==null||busy)return;
  final state=selected!['status']?.toString()??'local';
  if(mode=='cancel'&&!orderCanCancel(state,admin:widget.admin))return;
  if(mode=='replace'&&!orderCanReplace(state,admin:widget.admin,
     alreadyReplaced:selected!['replaced_by_id']!=null))return;
  final reason=await lifecycleReason(mode);
  if(reason==null||!mounted)return;
  if(state=='local'){
   final id=selected!['id'].toString();
   setState(()=>busy=true);
   try{
    await _removeLocal(id);
    if(mounted)setState(()=>selected=null);
   }catch(_){
    if(mounted)ScaffoldMessenger.of(context).showSnackBar(
     const SnackBar(content:Text('Không xóa được nháp trên máy. Thử lại.')));
   }finally{if(mounted)setState(()=>busy=false);}
   return;
  }
  if(offline){
   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
    content:Text('Cần kết nối mạng để ghi nhật ký hủy hoặc thay thế.')));
   return;
  }
  final id=selected!['id'].toString(),version=selected!['version'];
  final previous=pendingLifecycle;
  final payload=previous!=null&&previous['order_id']==id&&
   previous['expected_version']==version&&previous['action']==mode&&
   previous['reason']==reason
   ?previous
   :<String,dynamic>{
     'order_id':id,'expected_version':version,
     'client_ref':const Uuid().v4(),'action':mode,'reason':reason,
     if(mode=='replace')'replacement_id':const Uuid().v4(),
   };
  pendingLifecycle=payload;
  setState(()=>busy=true);
  try{
   final doc=await client.post('/api/v1/orders/lifecycle',payload);
   pendingLifecycle=null;
   if(!mounted)return;
   final item=Map<String,dynamic>.from(doc['item'] as Map);
   if(mode=='cancel'){
    setState(()=>selected={...selected!,...item,'local_dirty':false});
    try{await _removeLocal(id);}catch(_){}
    if(mounted)ScaffoldMessenger.of(context).showSnackBar(
     const SnackBar(content:Text('Đã hủy đơn và ghi nhật ký.')));
    if(mounted)unawaited(load());
   }else{
    final next=Map<String,dynamic>.from(doc['replacement'] as Map);
    final nextId=next['id'].toString();
    // Lifecycle already committed; do not issue another replacement when a
    // subsequent GET fails. The new draft is available in the order list.
    try{
     final detail=await client.get('/api/v1/orders/$nextId')
      .timeout(const Duration(seconds:8));
     if(!mounted)return;
     await open(Map<String,dynamic>.from(detail['item'] as Map));
     if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content:Text('Đã tạo nháp điều chỉnh. Kiểm tra giỏ trước khi xuất.')));
    }catch(_){
     if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content:Text('Đã tạo đơn $nextId. Tải lại để mở nháp.')));
    }
    if(mounted)unawaited(load());
   }
  }catch(e){
   if(mounted)ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content:Text('Chưa xác nhận thao tác: $e')));
  }finally{if(mounted)setState(()=>busy=false);}
 }
 Future<void> audit()async{
  if(selected==null||offline)return;
  try{
   final data=await client.get('/api/v1/orders/${selected!['id']}/audit');
   if(!mounted)return;
   await showDialog<void>(context:context,builder:(c)=>AlertDialog(
    title:const Text('Nhật ký đơn hàng'),
    content:SizedBox(width:450,height:340,child:ListView(children:[
     for(final r in orderRows(data['events']))ListTile(
      title:Text('${r['action']} · ${r['created_at']}'),
      subtitle:Text('${r['actor_sub']} · ${orderEventStatus(r['before_data'])} → ${orderEventStatus(r['after_data'])}${(r['request_data'] as Map?)?['reason']!=null?'\nLý do: ${(r['request_data'] as Map)['reason']}':''}')),
    ])),
    actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('Đóng'))]));
  }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$e')));}
 }
 @override Widget build(BuildContext context){
  final all=<Map<String,dynamic>>[...saved];
  for(final d in drafts){if(!all.any((x)=>x['id']==d['id']))all.insert(0,d);}
  final inCart=selected!=null;
  final filtered=all.where((row)=>orderFilterRow(row,
   query:search.text,status:filterStatus,range:filterDates)).toList();
  final currentStatus=selected?['status']?.toString()??'local';
  return ListView(key:ValueKey(inCart?'order-cart-${selected!['id']}':'order-list'),
   primary:false,padding:const EdgeInsets.all(12),children:[
   Row(children:[Expanded(child:Text('Ra đơn',style:Theme.of(context).textTheme.titleLarge)),
    IconButton(tooltip:'Tải lại đơn',onPressed:busy?null:load,icon:const Icon(Icons.refresh))]),
   const Text('Phiếu yêu cầu của Sales · không kiểm tồn, không trừ kho.'),
   if(loading)const LinearProgressIndicator(),
   if(offline)const Text('Ngoại tuyến · nháp vẫn lưu trên máy; cần mạng khi gửi phiếu.'),
   if(error!=null)Text(error!,style:TextStyle(color:Theme.of(context).colorScheme.error)),
   if(inCart)...[
    Row(children:[Expanded(child:Text('Đơn ${selected!['id'].toString().substring(0,8)} · ${orderStatus(selected!['status']?.toString()??'local')}')),
     IconButton(tooltip:'Đóng giỏ',onPressed:busy?null:()=>setState(()=>selected=null),icon:const Icon(Icons.close))]),
    OutlinedButton.icon(onPressed:canEdit&&!busy?chooseCustomer:null,icon:const Icon(Icons.storefront_outlined),
     label:Text(customer?['name']?.toString().isNotEmpty==true?
      '${customer!['name']} · FW: ${customer!['field_code']??'Đang cấp'}':'Chọn khách hàng')),
    if(selected!['replaces_order_id']!=null)
     Text('Điều chỉnh từ đơn ${selected!['replaces_order_id']} · Chứng từ công ty không tự thay đổi.'),
    if(selected!['replaced_by_id']!=null)
     Text('Đã có đơn thay thế: ${selected!['replaced_by_id']}'),
    if(selected!['cancel_reason']!=null)
     Text('Lý do hủy: ${selected!['cancel_reason']}'),
    if(selected!['replacement_reason']!=null)
     Text('Lý do điều chỉnh: ${selected!['replacement_reason']}'),
    if(customer!=null&&(customer!['export_code']==null||customer!['export_code'].toString().isEmpty))
     const Text('Chưa có mã CTY: vẫn xuất được phiếu Sales; cần đối chiếu mã CTY trước khi nhập app công ty.'),
    if(canEdit)OutlinedButton.icon(onPressed:busy?null:addProduct,icon:const Icon(Icons.add_shopping_cart),
     label:const Text('Thêm sản phẩm')),
    if(removedLine!=null&&canEdit)Card(
     child:Padding(padding:const EdgeInsets.symmetric(horizontal:10,vertical:4),
      child:Row(children:[
       Expanded(child:Text('Đã bỏ mã ${removedLine!['company_code']??'sản phẩm'}',
        maxLines:1,overflow:TextOverflow.ellipsis)),
       TextButton(onPressed:busy?null:undoRemove,child:const Text('Hoàn tác')),
       IconButton(tooltip:'Đóng hoàn tác',onPressed:()=>setState(()=>removedLine=null),
        icon:const Icon(Icons.close),constraints:const BoxConstraints(minWidth:44,minHeight:44)),
      ])),
    ),
    for(var i=0;i<lines.length;i++)OrderCartLine(
     key:ValueKey(lines[i]['line_id']),
     number:i+1,line:lines[i],stockMessage:'',
     editable:canEdit&&!busy,
     onQuantity:(value)=>changeLineQuantity(i,value),
     onRemove:()=>removeLine(i),
    ),
    if(lines.isNotEmpty)Text('${lines.length} mã · ${orderTotalByUnit(lines)}',
     style:Theme.of(context).textTheme.titleSmall),
    TextField(controller:note,readOnly:!canEdit||busy,maxLength:500,maxLines:2,
     onChanged:(_)=>localChanged(),decoration:const InputDecoration(labelText:'Ghi chú đơn hàng')),
    Row(children:[
     Expanded(child:Text(localStatus,style:Theme.of(context).textTheme.bodySmall?.copyWith(
      color:localError!=null?Theme.of(context).colorScheme.error:null))),
     if(localError!=null)IconButton(
      tooltip:'Thử lưu nháp lại',icon:const Icon(Icons.refresh),
      onPressed:()=>unawaited(_persist().catchError((_){ })),
     ),
    ]),
    if(busy||localSaving)const LinearProgressIndicator(),
    Wrap(spacing:8,runSpacing:8,children:[
     if(canEdit)FilledButton.icon(
      onPressed:busy||offline||localSaving||localError!=null||
       (selected!['status']=='draft'&&selected!['local_dirty']!=true)?null:saveOnline,
      icon:const Icon(Icons.save_outlined),label:const Text('Lưu đơn')),
     if(canEdit)OutlinedButton.icon(
      onPressed:busy||offline||localSaving||localError!=null||selected!['status']!='draft'||
       selected!['local_dirty']==true?null:issue,
      icon:const Icon(Icons.file_upload_outlined),label:const Text('Xuất')),
     if(!offline&&['exported','imported'].contains(selected!['status']))OutlinedButton.icon(
      onPressed:busy?null:download,icon:const Icon(Icons.file_download_outlined),label:const Text('Tải file')),
     if(!offline&&selected!['status']=='exported'&&widget.admin)
       OutlinedButton(onPressed:busy?null:markImported,child:const Text('Xác nhận đã nhập công ty')),
     if(orderCanCancel(currentStatus,admin:widget.admin))
      OutlinedButton.icon(onPressed:busy||localSaving||(offline&&currentStatus!='local')?null:()=>lifecycle('cancel'),
       icon:const Icon(Icons.cancel_outlined),label:const Text('Hủy đơn')),
     if(orderCanReplace(currentStatus,admin:widget.admin,
       alreadyReplaced:selected!['replaced_by_id']!=null))
      OutlinedButton.icon(onPressed:busy||offline?null:()=>lifecycle('replace'),
       icon:const Icon(Icons.content_copy_outlined),
       label:Text(currentStatus=='imported'?'Tạo điều chỉnh':'Thay thế đơn')),
     if(!offline&&hasServerVersion)TextButton(onPressed:audit,child:const Text('Nhật ký')),
    ]),
   ]else...[
    FilledButton.icon(onPressed:create,icon:const Icon(Icons.add),
     label:const Text('Tạo đơn mới')),
    const SizedBox(height:8),
    TextField(
     controller:search,onChanged:searchChanged,
     decoration:InputDecoration(
      isDense:true,labelText:'Tìm khách / mã đơn',
      prefixIcon:const Icon(Icons.search),
      suffixIcon:search.text.isNotEmpty?IconButton(
       tooltip:'Xóa tìm kiếm',icon:const Icon(Icons.close),
       onPressed:(){search.clear();searchChanged('');},
      ):null,
     ),
    ),
    const SizedBox(height:8),
    Wrap(spacing:8,runSpacing:8,crossAxisAlignment:WrapCrossAlignment.center,children:[
     SizedBox(width:210,child:DropdownButtonFormField<String>(
      value:filterStatus,
      isExpanded:true,decoration:const InputDecoration(labelText:'Trạng thái',isDense:true),
      items:const [
       DropdownMenuItem(value:'',child:Text('Tất cả')),
       DropdownMenuItem(value:'local',child:Text('Nháp trên máy')),
       DropdownMenuItem(value:'draft',child:Text('Nháp hệ thống')),
       DropdownMenuItem(value:'exported',child:Text('Đã xuất')),
       DropdownMenuItem(value:'imported',child:Text('Đã nhập công ty')),
       DropdownMenuItem(value:'cancelled',child:Text('Đã hủy')),
       DropdownMenuItem(value:'superseded',child:Text('Đã thay thế')),
      ],
      onChanged:(value){
       setState(()=>filterStatus=value??'');
       unawaited(load());
      },
     )),
     OutlinedButton.icon(onPressed:pickOrderDates,
      icon:const Icon(Icons.date_range),
      label:Text(filterDates==null?'Lọc ngày':
       '${_orderDate(filterDates!.start)} → ${_orderDate(filterDates!.end)}')),
     if(filterDates!=null)TextButton(
      onPressed:(){setState(()=>filterDates=null);unawaited(load());},
      child:const Text('Xóa ngày')),
    ]),
    Text('Danh sách đơn · ${filtered.length} đang hiển thị',
     style:Theme.of(context).textTheme.titleMedium),
    for(final row in filtered)Card(child:ListTile(
     leading:Icon(row['status']=='cancelled'?
      Icons.cancel_outlined:Icons.receipt_long_outlined),
     title:Text('${row['customer_name']??(row['customer'] is Map?(row['customer'] as Map)['name']:'Chưa chọn khách')??'Chưa chọn khách'}'),
     subtitle:Text('${orderStatus(row['status']?.toString()??'local')} · ${orderRows(row['lines']).length} mã CTY\n${row['id'].toString().substring(0,8)} · v${row['version']??0}${row['replaces_order_id']!=null?' · Điều chỉnh':''}'),
     trailing:const Icon(Icons.chevron_right),isThreeLine:true,
     onTap:()=>open(row))),
    if(filtered.isEmpty&&!loading)const Padding(
     padding:EdgeInsets.all(16),child:Text('Không có đơn phù hợp bộ lọc.')),
   ],
   const Padding(padding:EdgeInsets.all(8),child:Text('Excel chỉ là phiếu chuẩn bị nhập công ty, chưa được đối chiếu mẫu chính thức. Field Work không kiểm hoặc giữ tồn kho.')),
  ]);
 }
}

/// The modal owns its controller until the route finishes its closing
/// animation. Never dispose TextEditingController immediately after pop().
class _OrderLifecycleReasonDialog extends StatefulWidget{
 final String mode,status;
 const _OrderLifecycleReasonDialog({required this.mode,required this.status});
 @override State<_OrderLifecycleReasonDialog> createState()=>_OrderLifecycleReasonDialogState();
}
class _OrderLifecycleReasonDialogState extends State<_OrderLifecycleReasonDialog>{
 final controller=TextEditingController();
 String reason='';
 @override void dispose(){controller.dispose();super.dispose();}
 @override Widget build(BuildContext context){
  final replacing=widget.mode=='replace';
  return AlertDialog(
   title:Text(replacing?'Tạo đơn thay thế / điều chỉnh':'Hủy đơn có nhật ký'),
   content:SizedBox(width:440,child:Column(
    mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,
    children:[
     Text(replacing
      ?widget.status=='imported'
       ?'Đơn đã nhập công ty được giữ nguyên. Admin tạo nháp điều chỉnh riêng; không tự sửa chứng từ hoặc doanh số công ty.'
       :'Đơn đã xuất chuyển thành Đã thay thế. File đã gửi công ty không tự thu hồi.'
      :widget.status=='exported'
       ?'Đơn đã xuất chỉ Admin được hủy nội bộ. File đã gửi công ty không tự thu hồi.'
       :'Đơn nháp sẽ được hủy mềm và lưu lịch sử.'),
     const SizedBox(height:12),
     TextField(
      controller:controller,maxLength:300,minLines:2,maxLines:4,
      onChanged:(v)=>setState(()=>reason=v.trim()),
      decoration:const InputDecoration(
       labelText:'Lý do bắt buộc',hintText:'Nhập ít nhất 8 ký tự'),
     ),
    ],
   )),
   actions:[
    TextButton(onPressed:()=>Navigator.pop(context),child:const Text('Đóng')),
    FilledButton(
     onPressed:reason.length>=8&&reason.length<=300
      ?()=>Navigator.pop(context,reason):null,
     child:Text(replacing?'Tạo nháp điều chỉnh':'Xác nhận hủy'),
    ),
   ],
  );
 }
}
