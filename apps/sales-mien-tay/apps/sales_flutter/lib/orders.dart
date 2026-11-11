import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'actuals.dart';
import 'offline_queue.dart';
import 'order_export.dart';
import 'session.dart';
import 'stock.dart';

List<Map<String,dynamic>> orderRows(Object? value)=>(value as List? ?? []).map((x)=>Map<String,dynamic>.from(x as Map)).toList();
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
 Map<String,dynamic>? selected,customer;
 bool busy=false,offline=false,loading=true;
 String? error;
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
  operation=const Uuid().v4();
  if(selected!=null){
   selected!['note']=note.text;
   selected!['local_dirty']=true;
   _persist();
  }
  setState((){});
 }
 Future<void> _persist()async{
  if(selected==null)return;
  final snap=snapshot();
  drafts.removeWhere((d)=>d['id']==snap['id']);
  drafts.add(snap);
  final data=[for(final d in drafts)Map<String,dynamic>.from(d)];
  writes=writes.catchError((_){ }).then((_)=>widget.queue.cache(draftKey,data));
  await writes;
 }
 Future<void> _removeLocal(String id)async{
  drafts.removeWhere((d)=>d['id']==id);
  final data=[for(final d in drafts)Map<String,dynamic>.from(d)];
  writes=writes.catchError((_){ }).then((_)=>widget.queue.cache(draftKey,data));
  await writes;
 }
 Future<void> load()async{
  if(mounted)setState((){loading=true;error=null;});
  try{drafts=await widget.queue.cached(draftKey);}catch(e){error='Không đọc được nháp trên máy: $e';}
  try{
   final doc=await client.get('/api/v1/orders');
   saved=orderRows(doc['items']);offline=false;
  }catch(e){
   saved=[];offline=true;
   if(e is ApiFailure&&(e.status==401||e.status==403)){
    drafts=[];error='Phiên hoặc địa bàn bị thu hồi; vui lòng đăng nhập lại.';
   }else{error='Chưa kết nối được máy chủ; chỉ xem và soạn nháp trên máy.';}
  }
  if(mounted)setState(()=>loading=false);
 }
 void create(){
  final id=const Uuid().v4();
  note.clear();customer=null;lines=[];operation=const Uuid().v4();
  setState(()=>selected={'id':id,'owner_sub':widget.queue.identity,'customer_id':'','status':'local','version':0,'note':'','local_dirty':true});
  unawaited(_persist());
 }
 Future<void> open(Map<String,dynamic> row)async{
  if(selected!=null)await _persist();
  final r=Map<String,dynamic>.from(row);
  final local=drafts.where((d)=>d['id']==r['id']).firstOrNull;
  final source=local??r;
  note.text=source['note']?.toString()??'';
  customer=source['customer'] is Map?Map<String,dynamic>.from(source['customer'] as Map):{
   'id':source['customer_id'],'owner_sub':source['owner_sub'],
   'name':source['customer_name']??'', 'export_code':source['customer_code']};
  lines=orderRows(source['lines']);
  operation=source['client_ref']?.toString()??const Uuid().v4();
  if(mounted)setState(()=>selected=Map<String,dynamic>.from(source));
 }
 Future<void> chooseCustomer()async{
  if(!canEdit)return;
  final item=await showDialog<Map<String,dynamic>>(context:context,
   builder:(_)=>_OrderPicker(client:client,queue:widget.queue,type:'customers'));
  if(item==null||!mounted)return;
  setState((){
   customer=item;selected!['customer_id']=item['id'];
   selected!['owner_sub']=item['owner_sub'];
  });localChanged();
 }
 Future<void> addProduct()async{
  if(!canEdit)return;
  final item=await showDialog<Map<String,dynamic>>(context:context,
    builder:(_)=>_OrderPicker(client:client,queue:widget.queue,type:'products'));
  if(item==null||!mounted)return;
  final productId=item['id']?.toString()??'';
  if(productId.isEmpty||lines.any((x)=>x['product_id']==productId)){
   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Mã CTY đã có trong giỏ hoặc chưa được đồng bộ.')));
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
 Future<void> changeQuantity(int idx)async{
  final controller=TextEditingController(text:lines[idx]['quantity'].toString());
  final value=await showDialog<int>(context:context,builder:(c)=>AlertDialog(title:Text(lines[idx]['name'].toString()),
   content:TextField(controller:controller,keyboardType:TextInputType.number,
    decoration:InputDecoration(labelText:'Số lượng (${lines[idx]['unit']})')),
   actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('Hủy')),
    FilledButton(onPressed:(){final n=int.tryParse(controller.text.trim());
     if(n!=null&&n>=1&&n<=100000000)Navigator.pop(c,n);},child:const Text('Lưu'))]));
  controller.dispose();
  if(value!=null&&mounted){lines[idx]['quantity']=value;localChanged();}
 }
 Future<bool> saveOnline()async{
  if(selected==null||offline)return false;
  if(customer==null||customer!['id']==null||lines.isEmpty){
   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Chọn khách hàng và ít nhất một sản phẩm.')));return false;
  }
  if(lines.any((l)=>int.tryParse('${l['quantity']}')==null||int.parse('${l['quantity']}')<1))return false;
  await _persist();
  if(mounted)setState(()=>busy=true);
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
   operation=const Uuid().v4();
   await _removeLocal(item['id'].toString());
   if(mounted){setState((){});ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Đã lưu nháp lên hệ thống.')));}
   return true;
  }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Chưa lưu trên server: $e')));return false;}
  finally{if(mounted)setState(()=>busy=false);}
 }
 Future<void> issue({bool acceptStale=false})async{
  if(selected==null||offline||busy)return;
  if(selected!['status']=='local'||selected!['local_dirty']==true){
   final ok=await saveOnline();if(!ok||!mounted)return;
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
   await FilePicker.platform.saveFile(dialogTitle:'Lưu Excel chuẩn bị nhập Retail',
    fileName:'field-work-order-${order['id']}.xlsx',
    type:FileType.custom,allowedExtensions:['xlsx'],bytes:bytes);
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
  return ListView(padding:const EdgeInsets.all(12),children:[
   Row(children:[Expanded(child:Text('Ra đơn',style:Theme.of(context).textTheme.titleLarge)),
    IconButton(tooltip:'Tải lại đơn',onPressed:busy?null:load,icon:const Icon(Icons.refresh))]),
   const Text('Theo quy trình Retail: chọn khách → SKU → giỏ → lưu nháp → kiểm tồn → xuất Excel. Không nhập giá, không trừ kho.'),
   if(loading)const LinearProgressIndicator(),
   if(offline)const Text('Ngoại tuyến · chỉ lưu nháp trên máy, cần mạng để kiểm tồn và xuất.'),
   if(error!=null)Text(error!,style:TextStyle(color:Theme.of(context).colorScheme.error)),
   if(inCart)...[
    Row(children:[Expanded(child:Text('Đơn ${selected!['id'].toString().substring(0,8)} · ${orderStatus(selected!['status']?.toString()??'local')}')),
     IconButton(tooltip:'Đóng giỏ',onPressed:()=>setState(()=>selected=null),icon:const Icon(Icons.close))]),
    OutlinedButton.icon(onPressed:canEdit?chooseCustomer:null,icon:const Icon(Icons.storefront_outlined),
     label:Text(customer?['name']?.toString().isNotEmpty==true?
      '${customer!['name']} · CTY: ${customer!['export_code']??'CHƯA CÓ MÃ'}':'Chọn khách hàng')),
    if(customer!=null&&(customer!['export_code']==null||customer!['export_code'].toString().isEmpty))
     const Text('Khách chưa có mã công ty. Có thể lưu nháp nhưng chưa xuất được.'),
    if(canEdit)OutlinedButton.icon(onPressed:addProduct,icon:const Icon(Icons.add_shopping_cart),
     label:const Text('Tìm và thêm mã CTY')),
    for(var i=0;i<lines.length;i++)Card(child:ListTile(
     title:Text('${lines[i]['company_code']} · ${lines[i]['name']}'),
     subtitle:Text('SL: ${lines[i]['quantity']} ${lines[i]['unit']} · ${orderStockMessage(lines[i])}'),
     trailing:canEdit?Row(mainAxisSize:MainAxisSize.min,children:[
      IconButton(tooltip:'Sửa số lượng',onPressed:()=>changeQuantity(i),icon:const Icon(Icons.edit_outlined)),
      IconButton(tooltip:'Bỏ dòng',onPressed:(){lines.removeAt(i);localChanged();},icon:const Icon(Icons.delete_outline))]):null,
    )),
    Text('Tổng số lượng: ${lines.fold<int>(0,(n,l)=>n+(int.tryParse('${l['quantity']}')??0))} (chỉ cộng số học, không cộng khác ĐVT thành một số tồn).'),
    TextField(controller:note,readOnly:!canEdit,maxLength:500,maxLines:2,
     onChanged:(_)=>localChanged(),decoration:const InputDecoration(labelText:'Ghi chú đơn hàng')),
    if(busy)const LinearProgressIndicator(),
    Wrap(spacing:8,runSpacing:8,children:[
     if(canEdit)OutlinedButton.icon(onPressed:()=>_persist(),icon:const Icon(Icons.save_outlined),label:const Text('Lưu nháp trên máy')),
     if(canEdit&&!offline)FilledButton.icon(onPressed:busy?null:saveOnline,icon:const Icon(Icons.cloud_upload_outlined),label:const Text('Lưu hệ thống')),
     if(canEdit&&!offline)FilledButton.icon(onPressed:busy?null:issue,icon:const Icon(Icons.verified_outlined),label:const Text('Kiểm tồn và xuất')),
     if(!offline&&['exported','imported'].contains(selected!['status']))OutlinedButton.icon(
      onPressed:busy?null:download,icon:const Icon(Icons.file_download_outlined),label:const Text('Xuất lại cùng mã đơn')),
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
class _OrderPicker extends StatefulWidget{
 final ActualClient client;final OfflineQueue queue;final String type;
 const _OrderPicker({required this.client,required this.queue,required this.type});
 @override State<_OrderPicker> createState()=>_OrderPickerState();
}
class _OrderPickerState extends State<_OrderPicker>{
 final search=TextEditingController();List<Map<String,dynamic>> rows=[];bool busy=true,offline=false;
 String? error;int generation=0;
 @override void initState(){super.initState();load();}
 @override void dispose(){search.dispose();super.dispose();}
 Future<void> load()async{
  final g=++generation;setState((){busy=true;error=null;offline=false;});
  try{
   final data=await widget.client.get(Uri(path:'/api/v1/orders/${widget.type}',
    queryParameters:{'q':search.text.trim()}).toString());
   if(mounted&&g==generation){rows=orderRows(data['items']);
    await widget.queue.cache('order-picker-${widget.type}',[{'items':rows}]);}
  }catch(e){
   if(e is ApiFailure&&(e.status==401||e.status==403)){rows=[];error='Quyền đã thay đổi.';}
   else{
    try{
     final saved=await widget.queue.cached('order-picker-${widget.type}');
     var all=orderRows(saved.firstOrNull?['items']);
     if(all.isEmpty&&widget.type=='products'){
      final stock=await widget.queue.cached(stockCacheKey);
      all=orderRows(stock.firstOrNull?['items']);
     }
     final q=search.text.toLowerCase().trim();
     rows=all.where((r)=>q.isEmpty||['name','company_code','export_code','sku'].any((k)=>(r[k]?.toString()??'').toLowerCase().contains(q))).toList();
     offline=true;error='Danh mục lưu máy; tồn và quyền sẽ kiểm lại khi xuất.';
    }catch(_){rows=[];error='Chưa có danh mục đã lưu.';}
   }
  }
  if(mounted&&g==generation)setState(()=>busy=false);
 }
 @override Widget build(BuildContext context)=>AlertDialog(
  title:Text(widget.type=='customers'?'Chọn điểm bán':'Chọn mã CTY'),
  content:SizedBox(width:500,height:430,child:Column(children:[
   TextField(controller:search,decoration:InputDecoration(labelText:'Tìm mã hoặc tên',
    suffixIcon:IconButton(icon:const Icon(Icons.search),onPressed:load)),onSubmitted:(_)=>load()),
   if(busy)const LinearProgressIndicator(),
   if(error!=null)Text(error!,style:TextStyle(color:Theme.of(context).colorScheme.error)),
   Expanded(child:ListView(children:[
    for(final r in rows)ListTile(
     title:Text('${widget.type=='products'?' ${r['company_code']} · ':''}${r['name']}'),
     subtitle:Text(widget.type=='products'?
      'ĐVT: ${r['unit']??'—'} · Tồn: ${r['quantity']??'Chưa có'} · ${orderStockStale(r['snapshot_at'])?'Tồn cũ':'Tồn mới'}':
      'Mã khách CTY: ${r['export_code']??'CHƯA CÓ'} · ${r['province']??''}'),
     onTap:()=>Navigator.pop(context,r)),
    if(!busy&&rows.isEmpty)const Text('Không tìm thấy dữ liệu phù hợp'),
   ])),
  ])),actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('Đóng'))]);
}
