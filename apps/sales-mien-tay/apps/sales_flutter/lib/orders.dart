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
 'draft'=>'Nháp trên hệ thống','local'=>'Nháp trên máy',_=>'Chưa xác định',
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
 bool get canEdit=>selected!=null&&!['exported','imported'].contains(selected!['status']);
 bool get hasServerVersion=>(selected?['version'] as int? ?? 0)>0;
 String get draftKey=>'order-drafts-v1';
 @override void initState(){super.initState();load();}
 @override void dispose(){note.dispose();super.dispose();}
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
  if(mounted)setState((){loading=true;error=null;});
  try {
    final cached=await widget.queue.cached(draftKey);
    if(mounted)setState((){drafts=cached;loading=false;});
  } catch (_) {
    if(mounted)setState((){
      loading=false;
      error='Không đọc được nháp trên máy. Kiểm tra bộ nhớ rồi thử lại.';
    });
  }
  // Render account-scoped drafts before network; avoid a 20-second wait
  // on first opening the Ra đơn page or returning to a saved draft.
  try {
    final doc=await client.get('/api/v1/orders')
        .timeout(const Duration(seconds:8));
    if(mounted)setState((){
      saved=orderRows(doc['items']);
      offline=false;
      error=null;
    });
  } catch(e) {
    if(!mounted)return;
    setState((){
      saved=[];
      offline=true;
      if(e is ApiFailure&&(e.status==401||e.status==403)){
        // Fail closed on access revocation, without deleting offline data.
        drafts=[];
        error='Phiên hoặc địa bàn bị thu hồi; vui lòng đăng nhập lại.';
      }else{
        error='Mất kết nối · vẫn có thể soạn đơn ngoại tuyến.';
      }
    });
  }
 }
 void create(){
  final id=const Uuid().v4();
  note.clear();customer=null;lines=[];removedLine=null;operation=const Uuid().v4();
  setState(()=>selected={'id':id,'owner_sub':widget.queue.identity,'customer_id':'','status':'local','version':0,'note':'','local_dirty':true});
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
 Future<void> issue({bool acceptStale=false})async{
  if(selected==null||offline||busy)return;
  if(selected!['status']=='local'||selected!['local_dirty']==true||localSaving||localError!=null){
   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Lưu đơn trên hệ thống trước khi xuất.')));
   return;
  }
  if(selected!['status']!='draft')return;
  final confirmed=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(
   title:const Text('Xác minh và xuất đơn'),
   content:const Text('Máy chủ sẽ kiểm mã khách, ĐVT và tồn hiện tại. Xuất đơn KHÔNG trừ tồn và KHÔNG tạo doanh số. File là mẫu chuẩn bị, chưa được chứng thực tương thích app công ty.'),
   actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Đóng')),
    FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Kiểm tồn & xuất'))]));
  if(confirmed!=true||!mounted)return;
  setState(()=>busy=true);
  try{
   final doc=await client.post('/api/v1/orders',{
    'id':selected!['id'],'client_ref':const Uuid().v4(),
    'version':selected!['version']??0,'owner_sub':selected!['owner_sub'],
    'customer_id':selected!['customer_id'],'action':'export',
    'accept_stale':acceptStale,'note':note.text,'lines':[],
   });
   selected={...selected!,...Map<String,dynamic>.from(doc['item'] as Map)};
   await _removeLocal(selected!['id'].toString());
   if(mounted)setState((){});
   await download();
  }catch(e){
   if(mounted){
    final message='$e';
    if(message.contains('24 giờ')&&!acceptStale){
     final accepted=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(
      title:const Text('Tồn kho đã cũ'),
      content:const Text('Bản tồn quá 24 giờ. Anh có muốn sử dụng số tồn đã lưu (chưa quá 7 ngày) để xác minh xuất không? Số tồn không phải lượng đã giữ cho đơn.'),
      actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Không')),
       FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Đã hiểu · kiểm lại'))]));
     if(accepted==true&&mounted){setState(()=>busy=false);await issue(acceptStale:true);return;}
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Chưa xuất: $e')));
   }
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
 Future<void> audit()async{
  if(selected==null||offline)return;
  try{
   final data=await client.get('/api/v1/orders/${selected!['id']}/audit');
   if(!mounted)return;
   await showDialog<void>(context:context,builder:(c)=>AlertDialog(
    title:const Text('Nhật ký đơn hàng'),
    content:SizedBox(width:450,height:340,child:ListView(children:[
     for(final r in orderRows(data['events']))ListTile(
      title:Text('${r['action']} · ${r['created_at']}'),subtitle:Text(r['actor_sub'].toString())),
    ])),
    actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('Đóng'))]));
  }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$e')));}
 }
 @override Widget build(BuildContext context){
  final all=<Map<String,dynamic>>[...saved];
  for(final d in drafts){if(!all.any((x)=>x['id']==d['id']))all.insert(0,d);}
  final inCart=selected!=null;
  return ListView(key:ValueKey(inCart?'order-cart-${selected!['id']}':'order-list'),
   primary:false,padding:const EdgeInsets.all(12),children:[
   Row(children:[Expanded(child:Text('Ra đơn',style:Theme.of(context).textTheme.titleLarge)),
    IconButton(tooltip:'Tải lại đơn',onPressed:busy?null:load,icon:const Icon(Icons.refresh))]),
   const Text('Chọn khách và sản phẩm để tạo đơn. Không nhập giá, không trừ tồn.'),
   if(loading)const LinearProgressIndicator(),
   if(offline)const Text('Ngoại tuyến · chỉ lưu nháp trên máy, cần mạng để kiểm tồn và xuất.'),
   if(error!=null)Text(error!,style:TextStyle(color:Theme.of(context).colorScheme.error)),
   if(inCart)...[
    Row(children:[Expanded(child:Text('Đơn ${selected!['id'].toString().substring(0,8)} · ${orderStatus(selected!['status']?.toString()??'local')}')),
     IconButton(tooltip:'Đóng giỏ',onPressed:busy?null:()=>setState(()=>selected=null),icon:const Icon(Icons.close))]),
    OutlinedButton.icon(onPressed:canEdit&&!busy?chooseCustomer:null,icon:const Icon(Icons.storefront_outlined),
     label:Text(customer?['name']?.toString().isNotEmpty==true?
      '${customer!['name']} · CTY: ${customer!['export_code']??'CHƯA CÓ MÃ'}':'Chọn khách hàng')),
    if(customer!=null&&(customer!['export_code']==null||customer!['export_code'].toString().isEmpty))
     const Text('Khách chưa có mã công ty. Có thể lưu nháp nhưng chưa xuất được.'),
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
     number:i+1,line:lines[i],stockMessage:orderStockMessage(lines[i]),
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
     if(!offline&&hasServerVersion)TextButton(onPressed:audit,child:const Text('Nhật ký')),
    ]),
   ]else...[
    FilledButton.icon(onPressed:create,icon:const Icon(Icons.add),label:const Text('Tạo đơn mới')),
    Text('Danh sách đơn · ${all.length} (đã tải / nháp trên máy)',style:Theme.of(context).textTheme.titleMedium),
    for(final row in all)Card(child:ListTile(
     leading:const Icon(Icons.receipt_long_outlined),
     title:Text('${row['customer_name']??(row['customer'] is Map?(row['customer'] as Map)['name']:'Chưa chọn khách')??'Chưa chọn khách'}'),
     subtitle:Text('${orderStatus(row['status']?.toString()??'local')} · ${orderRows(row['lines']).length} mã CTY\n${row['id'].toString().substring(0,8)}'),
     trailing:const Icon(Icons.chevron_right),isThreeLine:true,onTap:()=>open(row))),
   ],
   const Padding(padding:EdgeInsets.all(8),child:Text('Excel xuất là mẫu CHUẨN BỊ nhập công ty, chưa được đối chiếu mẫu chính thức. Tồn là snapshot, không được giữ chỗ khi ra đơn.')),
  ]);
 }
}
