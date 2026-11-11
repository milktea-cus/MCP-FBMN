import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'offline_queue.dart';
import 'session.dart';

String assortmentLabel(String? status)=>switch(status){
 'trading'=>'Đang kinh doanh',
 'imported'=>'Đã nhập hàng',
 'ordered'=>'Đã đặt',
 _=>'Chưa xác minh',
};
IconData assortmentIcon(String? status)=>switch(status){
 'trading'=>Icons.verified_outlined,
 'imported'=>Icons.inventory_2_outlined,
 'ordered'=>Icons.receipt_long_outlined,
 _=>Icons.question_mark_outlined,
};
String assortmentDate(Object? timestamp){
 final parsed=DateTime.tryParse(timestamp?.toString()??'');
 if(parsed==null)return 'Chưa ghi ngày';
 final date=parsed.toLocal();
 return '${date.day.toString().padLeft(2,'0')}/${date.month.toString().padLeft(2,'0')}/${date.year}';
}
class CustomerAssortmentApi{
 final String endpoint,token;
 final String? identity,revision;
 final http.Client? client;
 const CustomerAssortmentApi(this.endpoint,this.token,{
  this.identity,this.revision,this.client,
 });
 Uri _uri(String path,[Map<String,String>? query]){
  final host=Uri.parse(endpoint.replaceFirst(RegExp(r'/$'),''));
  if(host.scheme!='https'&&host.host!='localhost'&&host.host!='127.0.0.1'){
   throw StateError('API cần HTTPS');
  }
  return host.replace(path:path,queryParameters:query);
 }
 Map<String,String> get headers=>{
  ...sessionHeaders(token),
  if(identity!=null)'X-Sync-Identity':identity!,
  if(revision!=null)'X-Sync-Revision':revision!,
 };
 Future<Map<String,dynamic>> get(String path,[Map<String,String>? query])async{
  final uri=_uri(path,query);
  final response=await (client?.get(uri,headers:headers) ??
    http.get(uri,headers:headers)).timeout(const Duration(seconds:8));
  return decodeApi(response);
 }
 Future<List<Map<String,dynamic>>> products(String customerId,{
  String search='',String status='',String after='',
  void Function(List<Map<String,dynamic>> partial)? onPage,
 }) async{
  final rows=<Map<String,dynamic>>[];
  var cursor=after;
  for(var page=0;page<100;page++){
   final data=await get('/api/v1/customers/$customerId/products',{
    'limit':'60',if(search.trim().isNotEmpty)'q':search.trim(),
    if(status.isNotEmpty)'status':status,if(cursor.isNotEmpty)'after':cursor,
   });
   rows.addAll((data['items'] as List)
     .map((v)=>Map<String,dynamic>.from(v as Map)));
   onPage?.call(List<Map<String,dynamic>>.unmodifiable(rows));
   final next=data['next_cursor']?.toString()??'';
   if(next.isEmpty)return rows;
   if(next==cursor)throw const ApiFailure(502,'Phân trang SKU không hợp lệ');
   cursor=next;
  }
  throw const ApiFailure(502,'Danh sách SKU vượt giới hạn an toàn');
 }
 Future<List<Map<String,dynamic>>> catalog(String customerId,{String search=''})async{
  final data=await get('/api/v1/customers/$customerId/products/catalog',{
   'limit':'60',if(search.trim().isNotEmpty)'q':search.trim(),
  });
  return (data['items'] as List)
    .map((v)=>Map<String,dynamic>.from(v as Map)).toList();
 }
 Future<List<Map<String,dynamic>>> audit(String customerId)async{
  final data=await get('/api/v1/customers/$customerId/products/audit',{'limit':'40'});
  return (data['items'] as List)
    .map((v)=>Map<String,dynamic>.from(v as Map)).toList();
 }
 Future<Map<String,dynamic>> update(String customerId,Map<String,dynamic> data)async{
  final uri=_uri('/api/v1/customers/$customerId/products');
  final response=await (client?.post(uri,headers:headers,body:jsonEncode(data))??
    http.post(uri,headers:headers,body:jsonEncode(data)))
    .timeout(const Duration(seconds:12));
  return decodeApi(response);
 }
}

class CustomerAssortmentSection extends StatefulWidget{
 final String customerId,ownerSub;
 final bool editable;
 final CustomerAssortmentApi api;
 final OfflineQueue? queue;
 const CustomerAssortmentSection({
  super.key,required this.customerId,required this.ownerSub,
  required this.api,this.queue,this.editable=false,
 });
 @override State<CustomerAssortmentSection> createState()=>_CustomerAssortmentSectionState();
}
class _CustomerAssortmentSectionState extends State<CustomerAssortmentSection>{
 final search=TextEditingController();
 Timer? debounce;
 List<Map<String,dynamic>> items=[];
 bool loading=false,busy=false,offline=false;
 String? error;
 String status='';
 int visibleLimit=24;
 int previousPending=0,generation=0;
 String get cacheKey=>'customer-products:${widget.customerId}';
 @override void initState(){
  super.initState();
  previousPending=widget.queue?.pending.length??0;
  widget.queue?.addListener(_queueChanged);
  unawaited(_open());
 }
 @override void dispose(){
  debounce?.cancel();search.dispose();
  widget.queue?.removeListener(_queueChanged);
  super.dispose();
 }
 void _queueChanged(){
  if(!mounted||widget.queue==null)return;
  final count=widget.queue!.pending.length;
  if(count<previousPending)unawaited(refresh());
  previousPending=count;
 }
 Future<void> _open()async{
  if(widget.queue!=null){
   try{
    final rows=await widget.queue!.cached(cacheKey);
    if(mounted)setState(()=>items=rows);
   }catch(_){}
  }
  if(mounted)unawaited(refresh());
 }
 Future<void> refresh()async{
  final request=++generation;
  final previous=List<Map<String,dynamic>>.from(items);
  if(mounted)setState((){loading=true;error=null;});
  try{
   final data=await widget.api.products(widget.customerId,
    search:search.text,status:status,
    onPage:(partial){
     if(mounted&&generation==request)setState(()=>items=partial);
    });
   if(!mounted||generation!=request)return;
   setState((){items=data;offline=false;error=null;});
   // Persist complete account-scoped snapshots only, not a search subset.
   if(widget.queue!=null&&search.text.trim().isEmpty&&status.isEmpty){
    try{await widget.queue!.cache(cacheKey,data);}catch(_){}
   }
  }catch(e){
   if(!mounted||generation!=request)return;
   final denied=e is ApiFailure&&(e.status==401||e.status==403||e.status==404);
   setState((){
    offline=true;
    if(denied){
     items=[];
     error='Phiên hoặc quyền xem sản phẩm khách đã thay đổi.';
    }else{
     items=previous;
     error=items.isEmpty?'Không tải được danh mục SKU. Kiểm tra mạng.':
       'Đang xem SKU đã lưu trên máy · chưa cập nhật.';
    }
   });
  }finally{
   if(mounted&&generation==request)setState(()=>loading=false);
  }
 }
 void searchChanged(String text){
  setState((){});
  debounce?.cancel();
  debounce=Timer(const Duration(milliseconds:300),(){
   if(mounted)unawaited(refresh());
  });
 }
 Future<String?> _reason(String action)=>showDialog<String>(
  context:context,barrierDismissible:false,
  builder:(_)=>_AssortmentReasonDialog(action:action),
 );
 Future<void> _change(Map<String,dynamic> product,String action)async{
  if(busy||!widget.editable)return;
  final reason=await _reason(action);
  if(reason==null||!mounted)return;
  final id=product['product_id']?.toString()??'';
  if(widget.queue!=null&&widget.queue!.pending.any((job)=>
    job['path']=='/api/v1/customers/${widget.customerId}/products'&&
    (job['payload'] as Map?)?['product_id']==id)){
   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
    content:Text('SKU này đã có thay đổi chờ đồng bộ.')));
   return;
  }
  final version=(product['manual_version'] as num?)?.toInt()??0;
  final payload=<String,dynamic>{
   'client_ref':const Uuid().v4(),
   'product_id':id,'expected_version':version,
   'action':action,'reason':reason,
  };
  setState(()=>busy=true);
  try{
   if(widget.queue!=null){
    await widget.queue!.enqueue(
     '/api/v1/customers/${widget.customerId}/products',payload);
    if(!mounted)return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
     content:Text('Đã lưu xác minh trên máy · chờ đồng bộ và kiểm tra quyền.')));
   }else{
    await widget.api.update(widget.customerId,payload);
    if(!mounted)return;
    await refresh();
    if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
     content:Text('Đã ghi nhận xác minh SKU trên hệ thống.')));
   }
  }catch(e){
   if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content:Text('Chưa lưu xác minh SKU: $e')));
  }finally{if(mounted)setState(()=>busy=false);}
 }
 Future<void> _pickProduct()async{
  if(!widget.editable||busy)return;
  final selected=await showDialog<Map<String,dynamic>>(
   context:context,builder:(_)=>_AssortmentProductPicker(
    customerId:widget.customerId,api:widget.api,queue:widget.queue));
  if(selected!=null&&mounted)await _change(selected,'verify');
 }
 Future<void> _audit()async{
  await showDialog<void>(context:context,builder:(_)=>AlertDialog(
   title:const Text('Nhật ký xác minh SKU'),
   content:SizedBox(width:450,height:420,
    child:FutureBuilder<List<Map<String,dynamic>>>(
     future:widget.api.audit(widget.customerId),
     builder:(context,snapshot){
      if(!snapshot.hasData){
       return Center(child:Text(snapshot.hasError?
        'Không tải được nhật ký.':'Đang tải nhật ký…'));
      }
      return ListView(children:[
       for(final event in snapshot.data!)ListTile(
        leading:Icon(event['action']=='verify'?Icons.verified:Icons.remove_circle_outline),
        title:Text(event['action']=='verify'?'Xác minh đang kinh doanh':'Bỏ xác minh'),
        subtitle:Text('${event['reason']??''}\n${event['actor_sub']??''} · ${assortmentDate(event['created_at'])}'),
       ),
      ]);
     },
    )),
   actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('Đóng'))],
  ));
 }
 @override Widget build(BuildContext context){
  final q=search.text.trim().toLowerCase();
  final display=items.where((x)=>q.isEmpty||[
   x['company_code'],x['name'],x['sku'],x['brand']
  ].any((t)=>(t?.toString()??'').toLowerCase().contains(q))).toList();
  return Card(child:Padding(padding:const EdgeInsets.all(12),child:Column(
   crossAxisAlignment:CrossAxisAlignment.stretch,children:[
    Wrap(alignment:WrapAlignment.spaceBetween,spacing:6,runSpacing:6,children:[
     Text('Sản phẩm của điểm bán',style:Theme.of(context).textTheme.titleMedium),
     IconButton(onPressed:loading?null:refresh,
      tooltip:'Làm mới sản phẩm khách',icon:const Icon(Icons.refresh)),
     IconButton(onPressed:_audit,tooltip:'Nhật ký xác minh',
      icon:const Icon(Icons.history)),
     if(widget.editable)OutlinedButton.icon(
      onPressed:busy?null:_pickProduct,icon:const Icon(Icons.verified_outlined),
      label:const Text('Xác minh SKU')),
    ]),
    const SizedBox(height:6),
    const Text('Đã đặt ≠ Đã nhập hàng ≠ Đang kinh doanh.',
     style:TextStyle(fontSize:12)),
    const SizedBox(height:8),
    TextField(controller:search,onChanged:searchChanged,
     decoration:const InputDecoration(
      isDense:true,prefixIcon:Icon(Icons.search),labelText:'Tìm SKU / mã CTY / tên')),
    const SizedBox(height:6),
    Wrap(spacing:6,children:[
     for(final entry in [
      ('','Tất cả'),('ordered','Đã đặt'),
      ('imported','Đã nhập hàng'),('trading','Đang kinh doanh'),
     ])ChoiceChip(label:Text(entry.$2),selected:status==entry.$1,
      onSelected:(_){setState(()=>status=entry.$1);unawaited(refresh());}),
    ]),
    if(loading)const LinearProgressIndicator(minHeight:2),
    if(error!=null)Text(error!,style:Theme.of(context).textTheme.bodySmall),
    if(display.isEmpty&&!loading)const Padding(
     padding:EdgeInsets.all(8),child:Text('Chưa có SKU phù hợp.')),
    for(final product in display.take(visibleLimit))ListTile(
     dense:true,
     leading:Icon(assortmentIcon(product['status']?.toString())),
     title:Text('${product['company_code']??''} · ${product['name']??''}',
      maxLines:2,overflow:TextOverflow.ellipsis),
     subtitle:Text('${assortmentLabel(product['status']?.toString())} · ${assortmentDate(product['evidence_at'])}\n'
      'Đơn xuất: ${product['ordered_orders']??0} · Đã nhập: ${product['imported_orders']??0}',
      maxLines:2,overflow:TextOverflow.ellipsis),
     trailing:widget.editable&&product['is_trading']==true
      ?IconButton(onPressed:busy?null:()=>_change(product,'unverify'),
        tooltip:'Bỏ xác minh đang kinh doanh',
        icon:const Icon(Icons.remove_circle_outline))
      :null,
    ),
    if(display.length>visibleLimit)TextButton.icon(
     onPressed:()=>setState(()=>visibleLimit+=24),
     icon:const Icon(Icons.expand_more),
     label:Text('Xem thêm SKU (${display.length-visibleLimit} còn lại)')),
    if(widget.queue!=null)...[
     for(final job in widget.queue!.pending.where((x)=>
       x['path']=='/api/v1/customers/${widget.customerId}/products'))
      Padding(padding:const EdgeInsets.only(top:4),child:Text(
       'SKU đang chờ đồng bộ · ${(job['payload'] as Map?)?['action']??''}',
       style:Theme.of(context).textTheme.bodySmall)),
    ],
   ],
  )));
 }
}

class _AssortmentReasonDialog extends StatefulWidget{
 final String action;
 const _AssortmentReasonDialog({required this.action});
 @override State<_AssortmentReasonDialog> createState()=>_AssortmentReasonDialogState();
}
class _AssortmentReasonDialogState extends State<_AssortmentReasonDialog>{
 final reason=TextEditingController();
 String value='';
 @override void dispose(){reason.dispose();super.dispose();}
 @override Widget build(BuildContext context)=>AlertDialog(
  title:Text(widget.action=='verify'?'Xác minh SKU đang kinh doanh':'Bỏ xác minh SKU'),
  content:SizedBox(width:420,child:Column(mainAxisSize:MainAxisSize.min,children:[
   const Text('Chỉ xác minh nếu đã kiểm tra thực tế. Đơn xuất không tự chứng minh khách đang bán.'),
   const SizedBox(height:12),
   TextField(controller:reason,maxLength:500,minLines:2,maxLines:3,
    onChanged:(v)=>setState(()=>value=v.trim()),
    decoration:const InputDecoration(labelText:'Ghi rõ nguồn / lý do (ít nhất 8 ký tự)')),
  ])),
  actions:[
   TextButton(onPressed:()=>Navigator.pop(context),child:const Text('Hủy')),
   FilledButton(onPressed:value.length>=8&&value.length<=500
     ?()=>Navigator.pop(context,value):null,
    child:const Text('Xác nhận')),
  ],
 );
}
class _AssortmentProductPicker extends StatefulWidget{
 final String customerId;
 final CustomerAssortmentApi api;
 final OfflineQueue? queue;
 const _AssortmentProductPicker({required this.customerId,required this.api,this.queue});
 @override State<_AssortmentProductPicker> createState()=>_AssortmentProductPickerState();
}
class _AssortmentProductPickerState extends State<_AssortmentProductPicker>{
 final search=TextEditingController();
 Timer? debounce;
 List<Map<String,dynamic>> items=[];
 bool loading=false;
 int generation=0;
 @override void initState(){super.initState();unawaited(_open());}
 Future<void> _open()async{
  if(widget.queue!=null){
   try{
    final cached=await widget.queue!.cached('customer-product-catalog:${widget.customerId}');
    if(mounted)setState(()=>items=cached);
   }catch(_){}
  }
  if(mounted)unawaited(load());
 }
 @override void dispose(){search.dispose();debounce?.cancel();super.dispose();}
 Future<void> load()async{
  final id=++generation;
  setState(()=>loading=true);
  try{
   final result=await widget.api.catalog(widget.customerId,search:search.text);
   if(mounted&&id==generation)setState(()=>items=result);
   if(widget.queue!=null&&search.text.trim().isEmpty){
    try{
     await widget.queue!.cache('customer-product-catalog:${widget.customerId}',result);
    }catch(_){}
   }
  }catch(e){
   if(mounted&&id==generation&&e is ApiFailure&&
     (e.status==401||e.status==403))setState(()=>items=[]);
  }finally{if(mounted&&id==generation)setState(()=>loading=false);}
 }
 @override Widget build(BuildContext context)=>AlertDialog(
  title:const Text('Chọn SKU xác minh'),
  content:SizedBox(width:440,height:440,child:Column(children:[
   TextField(controller:search,autofocus:true,
    decoration:const InputDecoration(isDense:true,labelText:'Mã CTY / tên SKU',
     prefixIcon:Icon(Icons.search)),
    onChanged:(_){debounce?.cancel();debounce=Timer(
      const Duration(milliseconds:250),(){if(mounted)unawaited(load());});}),
   if(loading)const LinearProgressIndicator(minHeight:2),
   Expanded(child:ListView.builder(
    itemCount:items.where((item){
     final q=search.text.trim().toLowerCase();
     return q.isEmpty||[
      item['company_code'],item['name'],item['sku'],item['brand']
     ].any((v)=>(v?.toString()??'').toLowerCase().contains(q));
    }).length,
    itemBuilder:(ctx,i){
    final filtered=items.where((item){
     final q=search.text.trim().toLowerCase();
     return q.isEmpty||[
      item['company_code'],item['name'],item['sku'],item['brand']
     ].any((v)=>(v?.toString()??'').toLowerCase().contains(q));
    }).toList();
    final item=filtered[i];
    return ListTile(
     title:Text('${item['company_code']??''} · ${item['name']??''}',
      maxLines:2,overflow:TextOverflow.ellipsis),
     subtitle:Text(item['evidence_status']!=null?
      assortmentLabel(item['evidence_status']?.toString()):'Chưa có trong danh mục khách'),
     onTap:()=>Navigator.pop(context,item),
    );
   })),
  ])),
  actions:[TextButton(onPressed:()=>Navigator.pop(context),
   child:const Text('Đóng'))],
 );
}
