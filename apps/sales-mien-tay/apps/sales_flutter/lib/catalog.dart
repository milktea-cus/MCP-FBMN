import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'customers.dart';
import 'offline_queue.dart';
import 'session.dart';
import 'inventory_import.dart';

Map<String,dynamic> map(dynamic v)=>Map<String,dynamic>.from(v as Map);
String? packagingError(Map<String,dynamic> spec){
 for(final k in ['unitsPerCarton','unitsPerPack','packsPerCarton','pages','gsm']){
  final v=spec[k];if(v!=null&&(v is! int||v<1||v>1000000))return 'Quy cách phải là số nguyên dương (tối đa 1 triệu)';
 }
 final a=spec['unitsPerCarton'],b=spec['unitsPerPack'],c=spec['packsPerCarton'];
 if(a is int&&b is int&&c is int&&a!=b*c)return 'SP/lốc × lốc/thùng phải bằng SP/thùng';
 return null;
}
class CatalogPage extends StatefulWidget{
 final CustomerService service;final OfflineQueue queue;final bool admin;
 const CatalogPage({super.key,required this.service,required this.queue,required this.admin});
 @override State<CatalogPage> createState()=>_CatalogPageState();
}
class _CatalogPageState extends State<CatalogPage>{
 final search=TextEditingController();List<Map<String,dynamic>> rows=[];String? cursor,error;bool busy=false,offline=false;int generation=0;Timer? timer;
 @override void initState(){super.initState();load();}
 @override void dispose(){timer?.cancel();search.dispose();super.dispose();}
 Future<void> load({bool more=false})async{
  if(more&&(busy||cursor==null||offline))return;
  final gen=++generation,q=search.text.trim(),after=more?cursor!:'';
  setState((){busy=true;error=null;if(!more){rows=[];cursor=null;offline=false;}});
  final key='catalog-v1:${widget.admin?'admin':'viewer'}:$q';
  try{
   final data=decodeApi(await http.get(widget.service.uri('/api/v1/catalog/products',{'q':q,'after':after,'limit':'50'}),headers:widget.service.headers).timeout(const Duration(seconds:20)));
   final page=(data['items'] as List).map(map).toList();
   if(!mounted||gen!=generation)return;
   final items=more?[...rows,...page]:page;
   await widget.queue.cache(key,[{'items':items,'synced_at':data['synced_at'],'next_cursor':data['next_cursor']}]);
   if(mounted&&gen==generation)setState((){rows=items;cursor=data['next_cursor'] as String?;});
  }catch(e){
   if(!mounted||gen!=generation)return;
   if(e is ApiFailure&&(e.status==401||e.status==403)){setState((){rows=[];cursor=null;error='Không còn quyền truy cập danh mục';});}
   else{
    final saved=await widget.queue.cached(key);
    if(mounted&&gen==generation)setState((){offline=true;cursor=null;rows=saved.isEmpty?[]:(saved.first['items'] as List).map(map).toList();error=saved.isEmpty?'Không có dữ liệu danh mục đã lưu cho tìm kiếm này.':'Dữ liệu lưu máy · ${saved.first['synced_at']} · có thể chưa đầy đủ';});
   }
  }finally{if(mounted&&gen==generation)setState(()=>busy=false);}
 }
 Future<void> edit([Map<String,dynamic>? product])async{
  final ok=await Navigator.push<bool>(context,MaterialPageRoute(builder:(_)=>ProductEditor(service:widget.service,product:product)));
  if(ok==true&&mounted)await load();
 }
 @override Widget build(BuildContext context)=>ListView(padding:const EdgeInsets.all(12),children:[
  Row(children:[Expanded(child:Text('Danh mục SKU',style:Theme.of(context).textTheme.titleLarge)),IconButton(tooltip:'Đồng bộ',onPressed:busy?null:()=>load(),icon:const Icon(Icons.sync))]),
  const SizedBox(height:8),
  TextField(controller:search,decoration:const InputDecoration(prefixIcon:Icon(Icons.search),labelText:'Mã CTY, SKU, tên hoặc nhãn hàng'),onChanged:(_){timer?.cancel();timer=Timer(const Duration(milliseconds:350),()=>load());}),
  if(widget.admin)Padding(padding:const EdgeInsets.symmetric(vertical:8),child:Wrap(spacing:8,runSpacing:8,children:[FilledButton.icon(onPressed:busy||offline?null:()=>edit(),icon:const Icon(Icons.add),label:const Text('Thêm')),OutlinedButton(onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>BrandCatalogPage(service:widget.service,queue:widget.queue,admin:widget.admin))),child:const Text('Nhãn hàng')),OutlinedButton(onPressed:busy||offline?null:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>CustomerMappingPage(service:widget.service))),child:const Text('Mã KH')),OutlinedButton.icon(onPressed:busy||offline?null:()async{await Navigator.push(context,MaterialPageRoute(builder:(_)=>InventoryImportHubPage(service:widget.service)));if(mounted)await load();},icon:const Icon(Icons.upload_file),label:const Text('Nhập')),TextButton(onPressed:busy||offline?null:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>CatalogAuditPage(service:widget.service))),child:const Text('Nhật ký'))])),
  if(busy)const LinearProgressIndicator(),if(error!=null)Padding(padding:const EdgeInsets.all(8),child:Text(error!)),
  if(rows.isEmpty&&!busy)const Padding(padding:EdgeInsets.all(16),child:Text('Không có sản phẩm phù hợp.')),
  for(final p in rows)Card(child:ListTile(title:Text(p['name'].toString()),subtitle:Text('Mã CTY: ${p['company_code']} · SKU: ${p['sku']??"—"}\n${p['brand']??"—"} · ${p['category']??"—"} · ĐVT: ${p['unit']??"Chưa xác minh"}${p['active']==false?" · Ngừng sử dụng":""}'),trailing:widget.admin&&!offline?IconButton(tooltip:'Sửa sản phẩm',onPressed:()=>edit(p),icon:const Icon(Icons.edit_outlined)):const Icon(Icons.chevron_right),onTap:()=>showDialog<void>(context:context,builder:(c)=>AlertDialog(title:Text(p['name'].toString()),content:Text('Mã CTY: ${p['company_code']}\nĐVT: ${p['unit']??"Chưa xác minh"}\n${specSummary(map(p['product_spec']??{}))}\nXem số tồn tại Tra tồn'),actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('Đóng'))])))),
  if(cursor!=null)OutlinedButton(onPressed:busy?null:()=>load(more:true),child:const Text('Tải thêm')),
 ]);
}
String specSummary(Map<String,dynamic> s){
 final a=s['unitsPerCarton'],b=s['unitsPerPack'],c=s['packsPerCarton'],piece=s['pieceUnit'];
 final effective=a??(b is int&&c is int?b*c:null);
 return [if(piece!=null)'ĐVT lẻ: $piece',if(effective!=null)'$effective SP/thùng${a==null?" (tính từ quy cách)":""}',if(b!=null)'$b SP/${s['packUnit']??"gói"}',if(c!=null)'$c ${s['packUnit']??"gói"}/thùng',if(s['packagingNote']!=null)s['packagingNote'].toString()].join('\n');
}
class ProductEditor extends StatefulWidget{
 final CustomerService service;final Map<String,dynamic>? product;
 const ProductEditor({super.key,required this.service,this.product});
 @override State<ProductEditor> createState()=>_ProductEditorState();
}
class _ProductEditorState extends State<ProductEditor>{
 final fields=<String,TextEditingController>{};bool active=true,busy=false;String? error;String op=const Uuid().v4();List<String> brandNames=[];
 static const labels={'company_code':'Mã CTY','name':'Tên hàng','sku':'SKU','brand':'Nhãn hàng','category':'Nhóm hàng','unit':'Đơn vị tính','pieceUnit':'ĐVT lẻ','packUnit':'Tên gói/lốc/hộp','unitsPerCarton':'SP/thùng','unitsPerPack':'SP/gói','packsPerCarton':'Gói/thùng','paperSize':'Khổ giấy','pages':'Số trang','ruling':'Dòng kẻ','gsm':'Định lượng giấy','coverType':'Loại bìa','packagingNote':'Ghi chú quy cách'};
 static const numbers=['unitsPerCarton','unitsPerPack','packsPerCarton','pages','gsm'];
 @override void initState(){super.initState();final p=widget.product??{},spec=map(p['product_spec']??{});active=p['active']!=false;for(final k in labels.keys){fields[k]=TextEditingController(text:(p[k]??spec[k]??(k=='unit'&&widget.product==null?'Thùng':'')).toString());}unawaited(loadBrands());}
 @override void dispose(){for(final c in fields.values){c.dispose();}super.dispose();}
 Future<void> loadBrands()async{
  try{
   final res=decodeApi(await http.get(widget.service.uri('/api/v1/catalog/brands'),
     headers:widget.service.headers).timeout(const Duration(seconds:15)));
   final names=(res['items'] as List).map(map)
    .where((b)=>b['active']==true).map((b)=>b['name'].toString()).toSet().toList()..sort();
   if(mounted)setState(()=>brandNames=names);
  }catch(_){}
 }

 Future<void> save()async{
  if(busy)return;
  final data=<String,dynamic>{'client_ref':op,'active':active,if(widget.product!=null)'version':widget.product!['version']},spec=<String,dynamic>{};
  for(final k in labels.keys){final v=fields[k]!.text.trim();if(['company_code','name','sku','brand','category','unit'].contains(k)){data[k]=v.isEmpty?null:v;}else if(v.isNotEmpty){spec[k]=numbers.contains(k)?int.tryParse(v)??v:v;}}
  final err=packagingError(spec);
  if(data['company_code']==null||data['name']==null||err!=null){setState(()=>error=err??'Nhập mã CTY và tên hàng');return;}
  data['product_spec']=spec;
  setState(()=>busy=true);
  try{
   final uri=widget.service.uri('/api/v1/catalog/products${widget.product==null?"":"/${widget.product!['id']}"}');
   final res=await (widget.product==null?http.post(uri,headers:widget.service.headers,body:jsonEncode(data)):http.patch(uri,headers:widget.service.headers,body:jsonEncode(data))).timeout(const Duration(seconds:25));
   decodeApi(res);if(mounted)Navigator.pop(context,true);
  }catch(e){if(mounted)setState(()=>error=e.toString());}
  finally{if(mounted)setState(()=>busy=false);}
 }
 @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:Text(widget.product==null?'Tạo sản phẩm':'Sửa sản phẩm')),body:ListView(padding:const EdgeInsets.all(16),children:[
  const Text('Mã CTY giữ nguyên sau khi tạo. Chỉ nhập thông tin đã xác minh.'),
  for(final k in labels.keys)...[const SizedBox(height:12),if(k=='pieceUnit')Text('Quy cách bán sỉ',style:Theme.of(context).textTheme.titleMedium),if(k=='brand'&&brandNames.isNotEmpty)
    DropdownButtonFormField<String>(
     initialValue:fields[k]!.text.isEmpty?null:fields[k]!.text,
     isExpanded:true,decoration:InputDecoration(labelText:labels[k]),
     items:[
      const DropdownMenuItem<String>(value:'',child:Text('Chưa chọn nhãn hàng')),
      for(final brand in { ...brandNames,if(fields[k]!.text.isNotEmpty)fields[k]!.text })
       DropdownMenuItem(value:brand,child:Text(brand,overflow:TextOverflow.ellipsis)),
     ],
     onChanged:busy?null:(brand)=>setState(()=>fields[k]!.text=brand??''),
    )
   else TextField(controller:fields[k],enabled:!busy&&(k!='company_code'||widget.product==null),keyboardType:numbers.contains(k)?TextInputType.number:TextInputType.text,decoration:InputDecoration(labelText:labels[k]))],
  SwitchListTile(value:active,title:const Text('Đang sử dụng'),onChanged:busy?null:(v)=>setState(()=>active=v)),
  if(error!=null)Text(error!),FilledButton(onPressed:busy?null:save,child:Text(busy?'Đang lưu…':'Lưu sản phẩm')),
 ]));
}
class CustomerMappingPage extends StatefulWidget{
 final CustomerService service;
 const CustomerMappingPage({super.key,required this.service});
 @override State<CustomerMappingPage> createState()=>_CustomerMappingPageState();
}
class _CustomerMappingPageState extends State<CustomerMappingPage>{
 late Future<List<FieldCustomer>> customers;String q='';
 @override void initState(){super.initState();customers=widget.service.list();}
 Future<void> edit(FieldCustomer c)async{
  try{
   final uri=widget.service.uri('/api/v1/catalog/customers/${c.id}'),body=decodeApi(await http.get(uri,headers:widget.service.headers).timeout(const Duration(seconds:20))),old=body['item'] as Map?;
   if(!mounted)return;final ctl=TextEditingController(text:old?['company_code']?.toString()??'');
   final code=await showDialog<String>(context:context,builder:(d)=>AlertDialog(title:Text(c.name),content:TextField(controller:ctl,decoration:const InputDecoration(labelText:'Mã khách CTY (text)')),actions:[TextButton(onPressed:()=>Navigator.pop(d),child:const Text('Hủy')),FilledButton(onPressed:()=>Navigator.pop(d,ctl.text.trim()),child:const Text('Lưu mapping'))]));ctl.dispose();
   if(code==null||code.isEmpty)return;
   decodeApi(await http.patch(uri,headers:widget.service.headers,body:jsonEncode({'client_ref':const Uuid().v4(),'company_code':code,'version':old?['version']??0})).timeout(const Duration(seconds:20)));
   if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Đã lưu mã khách CTY')));
  }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString())));}
 }
 @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Mapping mã khách CTY')),body:Column(children:[Padding(padding:const EdgeInsets.all(12),child:TextField(decoration:const InputDecoration(labelText:'Tìm điểm bán'),onChanged:(v)=>setState(()=>q=v.toLowerCase()))),Expanded(child:FutureBuilder<List<FieldCustomer>>(future:customers,builder:(c,s){if(s.hasError)return Center(child:Text(s.error.toString()));if(!s.hasData)return const Center(child:CircularProgressIndicator());final items=s.data!.where((x)=>x.name.toLowerCase().contains(q)).toList();return ListView(children:[for(final x in items)ListTile(title:Text(x.name),subtitle:Text('${x.district}, ${x.province}'),trailing:const Icon(Icons.edit_outlined),onTap:()=>edit(x))]);}))]));
}
class CatalogAuditPage extends StatelessWidget{
 final CustomerService service;
 const CatalogAuditPage({super.key,required this.service});
 @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Nhật ký danh mục')),body:FutureBuilder<http.Response>(future:http.get(service.uri('/api/v1/catalog/edits'),headers:service.headers),builder:(c,s){if(s.hasError)return Center(child:Text(s.error.toString()));if(!s.hasData)return const Center(child:CircularProgressIndicator());try{final rows=(decodeApi(s.data!)['items'] as List).map(map);return ListView(children:[for(final r in rows)ListTile(title:Text('${r['before_data']==null?"Tạo":"Sửa"} · ${(r['after_data'] as Map)['company_code']}'),subtitle:Text('${r['created_at']} · ${r['actor_sub']}'))]);}catch(e){return Center(child:Text(e.toString()));}}));
}

class BrandCatalogPage extends StatefulWidget{
 final CustomerService service;
 final OfflineQueue queue;
 final bool admin;
 const BrandCatalogPage({super.key,required this.service,required this.queue,required this.admin});
 @override State<BrandCatalogPage> createState()=>_BrandCatalogPageState();
}
class _BrandCatalogPageState extends State<BrandCatalogPage>{
 List<Map<String,dynamic>> brands=[];
 bool busy=false,offline=false;String? error;
 @override void initState(){super.initState();unawaited(load());}
 Future<void> load()async{
  if(busy)return;
  setState((){busy=true;error=null;});
  try{
   final cached=await widget.queue.cached('canonical-brand-admin-v1');
   if(mounted)setState(()=>brands=cached);
   final res=decodeApi(await http.get(widget.service.uri('/api/v1/catalog/brands'),
    headers:widget.service.headers).timeout(const Duration(seconds:18)));
   final list=(res['items'] as List).map(map).toList();
   await widget.queue.cache('canonical-brand-admin-v1',list);
   if(mounted)setState((){brands=list;offline=false;});
  }catch(e){
   if(e is ApiFailure&&(e.status==401||e.status==403)){
    if(mounted)setState((){brands=[];offline=true;error='Quyền truy cập đã thay đổi';});
   }else if(mounted)setState((){offline=true;error='Dữ liệu nhãn hàng lưu trên máy; chưa cập nhật.';});
  }finally{if(mounted)setState(()=>busy=false);}
 }
 Future<void> add()async{
  final ctl=TextEditingController();
  final name=await showDialog<String>(context:context,builder:(ctx)=>AlertDialog(
   title:const Text('Thêm nhãn hàng'),
   content:TextField(controller:ctl,maxLength:120,
    decoration:const InputDecoration(labelText:'Tên nhãn hàng chính thức')),
   actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Hủy')),
    FilledButton(onPressed:()=>Navigator.pop(ctx,ctl.text.trim()),child:const Text('Lưu'))]));
  ctl.dispose();
  if(name==null||name.isEmpty||!mounted)return;
  await save('/api/v1/catalog/brands',{
   'client_ref':const Uuid().v4(),'name':name,'active':true
  });
 }
 Future<void> addAlias(Map<String,dynamic> brand)async{
  if(brand['active']!=true)return;
  final ctl=TextEditingController();
  final alias=await showDialog<String>(context:context,builder:(ctx)=>AlertDialog(
   title:Text('Tên thay thế cho ${brand['name']}'),
   content:TextField(controller:ctl,maxLength:120,
    decoration:const InputDecoration(labelText:'Tên cũ / biến thể tên nhãn')),
   actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Hủy')),
    FilledButton(onPressed:()=>Navigator.pop(ctx,ctl.text.trim()),child:const Text('Lưu'))]));
  ctl.dispose();
  if(alias==null||alias.isEmpty||!mounted)return;
  await save('/api/v1/catalog/brand-aliases',{
   'client_ref':const Uuid().v4(),'brand_id':brand['id'],'alias_name':alias});
 }
 Future<void> toggle(Map<String,dynamic> brand)async{
  final enabled=brand['active']==true;
  final confirmed=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
   title:Text(enabled?'Ngừng dùng nhãn hàng?':'Kích hoạt nhãn hàng?'),
   content:Text('Nhãn: ${brand['name']}\nKhông xóa SKU hoặc lịch sử cũ.'),
   actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Hủy')),
    FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Xác nhận'))]));
  if(confirmed!=true||!mounted)return;
  await save('/api/v1/catalog/brands/${brand['id']}',{
   'client_ref':const Uuid().v4(),'name':brand['name'],
   'version':brand['version'],'active':!enabled,
  },patch:true);
 }
 Future<void> save(String path,Map<String,dynamic> data,{bool patch=false})async{
  if(busy||offline)return;
  setState(()=>busy=true);
  try{
   final uri=widget.service.uri(path);
   final response=await (patch?http.patch(uri,headers:widget.service.headers,
      body:jsonEncode(data)):http.post(uri,headers:widget.service.headers,
      body:jsonEncode(data))).timeout(const Duration(seconds:20));
   decodeApi(response);
  }catch(e){
   if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$e')));
  }finally{if(mounted)setState(()=>busy=false);}
  if(mounted)await load();
 }
 @override Widget build(BuildContext context)=>Scaffold(
  appBar:AppBar(title:const Text('Danh mục nhãn hàng'),actions:[
   IconButton(tooltip:'Làm mới',onPressed:busy?null:load,icon:const Icon(Icons.sync))]),
  body:ListView(padding:const EdgeInsets.all(12),children:[
   const Text('Nhãn hàng dùng chung với SKU, hồ sơ điểm bán và thống kê tổng quan.'),
   if(widget.admin)Padding(padding:const EdgeInsets.symmetric(vertical:8),
    child:FilledButton.icon(onPressed:busy||offline?null:add,
     icon:const Icon(Icons.add),label:const Text('Thêm nhãn hàng'))),
   if(busy)const LinearProgressIndicator(minHeight:2),
   if(error!=null)Text(error!),
   for(final brand in brands)Card(child:ListTile(
    title:Text(brand['name'].toString()),
    subtitle:Text('${brand['product_count']??0} SKU · ${brand['active']==true?'Đang dùng':'Ngừng dùng'}'
     '${(brand['aliases'] as List? ?? []).isNotEmpty?'\nTên khác: ${(brand['aliases'] as List).join(', ')}':''}'),
    isThreeLine:(brand['aliases'] as List? ?? []).isNotEmpty,
    trailing:widget.admin?Wrap(mainAxisSize:MainAxisSize.min,children:[
      IconButton(tooltip:'Thêm tên thay thế',onPressed:busy||offline||
       brand['active']!=true?null:()=>addAlias(brand),
       icon:const Icon(Icons.label_outline)),
      Switch(value:brand['active']==true,
       onChanged:busy||offline?null:(_)=>toggle(brand)),
    ]):null)),
  ]),
 );
}
