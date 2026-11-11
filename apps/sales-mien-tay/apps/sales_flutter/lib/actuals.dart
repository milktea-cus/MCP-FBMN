import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'offline_queue.dart';
import 'session.dart';
import 'actuals_import.dart';

String saleMoney(Object? value){
 final n=int.tryParse('$value')??0;
 return '${n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'),(_)=>'.')} đ';
}
List<Map<String,dynamic>> saleRows(Object? v)=>(v as List? ?? []).map((e)=>Map<String,dynamic>.from(e as Map)).toList();
class ActualClient{
 final OfflineQueue queue;final http.Client? client;
 const ActualClient(this.queue,{this.client});
 Map<String,String> get headers=>{...sessionHeaders(queue.session.cookie),'X-Sync-Identity':queue.identity,'X-Sync-Revision':queue.revision};
 Future<Map<String,dynamic>> request(String method,String path,[Map<String,dynamic>? data])async{
  final uri=queue.session.uri(path),body=data==null?null:jsonEncode(data);
  final reply=method=='GET'
    ? await (client?.get(uri,headers:headers)??http.get(uri,headers:headers))
    : method=='PATCH' ? await (client?.patch(uri,headers:headers,body:body)??http.patch(uri,headers:headers,body:body))
    : await (client?.post(uri,headers:headers,body:body)??http.post(uri,headers:headers,body:body));
  return decodeApi(reply);
 }
 Future<Map<String,dynamic>> get(String path)=>request('GET',path);
 Future<Map<String,dynamic>> post(String path,Map<String,dynamic> data)=>request('POST',path,data);
 Future<Map<String,dynamic>> patch(String path,Map<String,dynamic> data)=>request('PATCH',path,data);
}
String saleParam(String path,Map<String,String> values)=>Uri(path:path,queryParameters:values).toString();

class ActualsPage extends StatefulWidget{
 final OfflineQueue queue;final ActualClient? client;
 const ActualsPage({super.key,required this.queue,this.client});
 @override State<ActualsPage> createState()=>_ActualsPageState();
}
class _ActualsPageState extends State<ActualsPage>{
 late final ActualClient client=widget.client??ActualClient(widget.queue);
 DateTime month=DateTime(DateTime.now().year,DateTime.now().month);
 String owner='';bool busy=true,offline=false,canImport=false;String? error;
 List<Map<String,dynamic>> entries=[],staff=[];
 int generation=0;
 String get ym=>'${month.year}-${month.month.toString().padLeft(2,'0')}';
 String get cacheKey=>'sales-actuals:$ym:$owner';
 @override void initState(){super.initState();owner=widget.queue.identity;load();}
 Future<void> load()async{
  final g=++generation,key=cacheKey,path=saleParam('/api/v1/actuals',{'month':ym,'owner':owner});
  setState((){busy=true;offline=false;error=null;entries=[];canImport=false;});
  Map<String,dynamic>? doc;String? failure;
  try{doc=await client.get(path);try{await widget.queue.cache(key,[doc]);}catch(_){}}
  catch(e){failure=e.toString();if(e is! ApiFailure||e.status>=500){try{doc=(await widget.queue.cached(key)).firstOrNull;offline=doc!=null;}catch(_){}}}
  if(!mounted||g!=generation)return;
  setState((){busy=false;error=doc==null?failure:null;if(doc!=null){entries=saleRows(doc['items']);canImport=!offline&&doc['can_import']==true;}});
 }
 Future<void> loadStaff()async{
  try{final r=await client.get('/api/v1/actuals/options?type=staff');if(mounted)setState(()=>staff=saleRows(r['items']));}catch(_){}
 }
 @override void didChangeDependencies(){super.didChangeDependencies();if(staff.isEmpty)loadStaff();}
 Future<void> edit([Map<String,dynamic>? row])async{
  final ok=await showDialog<bool>(context:context,barrierDismissible:false,builder:(_)=>_ActualEditor(client:client,queue:widget.queue,initial:row));
  if(ok==true&&mounted)await load();
 }
 Future<void> history(Map<String,dynamic> row)async{
  try{final data=await client.get('/api/v1/actuals/${row['id']}/history');if(!mounted)return;
   final items=saleRows(data['items']);
   await showDialog<void>(context:context,builder:(c)=>AlertDialog(title:const Text('Nhật ký điều chỉnh'),content:SizedBox(width:470,height:370,child:ListView(children:[
    for(final r in items)ListTile(title:Text('${r['created_at']} · ${r['actor_sub']}'),
      subtitle:Text('${(r['before_data'] as Map?)?['amount']??'Tạo mới'} → ${(r['after_data'] as Map)['amount']} đ\nPhiên bản: ${(r['after_data'] as Map)['version']} · Trạng thái: ${(r['after_data'] as Map)['status']}')),
   ])),actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('Đóng'))]));
  }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$e')));}
 }
 @override Widget build(BuildContext context){
  final active=entries.where((r)=>r['status']=='active').toList();
  final amount=active.fold<int>(0,(a,r)=>a+(int.tryParse('${r['amount']}')??0));
  return Scaffold(appBar:AppBar(title:const Text('Doanh số thực tế')),body:ListView(padding:const EdgeInsets.all(12),children:[
   Row(children:[Expanded(child:Text('Doanh số công ty / nhập tay',style:Theme.of(context).textTheme.titleMedium)),
    IconButton(tooltip:'Tải lại',onPressed:busy?null:load,icon:const Icon(Icons.refresh))]),
   if(staff.length>1)DropdownButtonFormField<String>(key:ValueKey(owner),initialValue:staff.any((x)=>x['id']==owner)?owner:null,
    isExpanded:true,decoration:const InputDecoration(labelText:'Nhân viên'),items:[for(final r in staff)DropdownMenuItem(value:r['id'].toString(),child:Text('${r['code']} · ${r['name']}',overflow:TextOverflow.ellipsis))],
    onChanged:busy?null:(x){if(x!=null){owner=x;load();}}),
   Row(children:[IconButton(tooltip:'Tháng trước',onPressed:busy?null:()=>setState((){month=DateTime(month.year,month.month-1);load();}),icon:const Icon(Icons.chevron_left)),
    Expanded(child:Text('Tháng ${month.month}/${month.year}',textAlign:TextAlign.center)),
    IconButton(tooltip:'Tháng sau',onPressed:busy?null:()=>setState((){month=DateTime(month.year,month.month+1);load();}),icon:const Icon(Icons.chevron_right))]),
   if(busy)const LinearProgressIndicator(),
   if(offline)const Text('Đang xem bản lưu trên máy · chỉ đọc, không thể xác nhận doanh số khi offline.'),
   if(error!=null)Text(error!,style:TextStyle(color:Theme.of(context).colorScheme.error)),
   Card(child:Padding(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    const Text('Doanh số đã ghi nhận trong kỳ'),Text(saleMoney(amount),style:Theme.of(context).textTheme.headlineSmall),
    Text('Số dòng: ${active.length} · Hủy: ${entries.length-active.length}'),
    const Text('Chỉ tính dòng đang hiệu lực; không cộng dữ liệu dự kiến hoặc đơn nháp.'),
   ]))),
   if(!offline&&error==null)Wrap(spacing:8,runSpacing:8,children:[
    FilledButton.icon(onPressed:busy?null:()=>edit(),icon:const Icon(Icons.add),label:const Text('Nhập tay')),
    if(canImport)OutlinedButton.icon(onPressed:busy?null:()async{await Navigator.push(context,MaterialPageRoute(builder:(_)=>ActualImportPage(client:client)));if(mounted)load();},
      icon:const Icon(Icons.upload_file),label:const Text('Nhập Excel')),
    if(canImport)TextButton(onPressed:()async{await Navigator.push(context,MaterialPageRoute(builder:(_)=>ActualImportHistory(client:client)));},child:const Text('Nhật ký nhập')),
   ]),
   if(entries.isEmpty&&!busy&&error==null)const Padding(padding:EdgeInsets.all(24),child:Text('Chưa có doanh số trong tháng này.')),
   for(final r in entries)Card(child:ListTile(
    title:Text('${r['company_code']} · ${r['product_name']}'),
    subtitle:Text('${r['sale_date']} · ${r['employee_code']} · ${r['customer_name']}\nSL ${r['quantity']} · ${saleMoney(r['amount'])} · ${r['source']=='company'?'Công ty':'Nhập tay'}${r['status']=='void'?' · Đã hủy':''}'),
    isThreeLine:true,
    trailing:PopupMenuButton<String>(tooltip:'Thao tác doanh số',
      itemBuilder:(_)=>[const PopupMenuItem(value:'history',child:Text('Nhật ký chỉnh sửa')),
       if(!offline&&!busy&&(canImport||(r['source']=='manual'&&r['owner_sub']==widget.queue.identity)))const PopupMenuItem(value:'edit',child:Text('Sửa / hủy'))],
      onSelected:(v)=>v=='history'?history(r):edit(r)),
   )),
   const Padding(padding:EdgeInsets.all(12),child:Text('Doanh số được ghi nhận theo ngày trên hệ thống công ty. Nhập trùng mã giao dịch + mã dòng sẽ không tạo thêm doanh số.')),
  ]));
 }
}
class _ActualPicker extends StatefulWidget{
 final ActualClient client;final String type,owner;
 const _ActualPicker({required this.client,required this.type,required this.owner});
 @override State<_ActualPicker> createState()=>_ActualPickerState();
}
class _ActualPickerState extends State<_ActualPicker>{
 final input=TextEditingController();List<Map<String,dynamic>> items=[];String? error;bool busy=true;int gen=0;
 @override void initState(){super.initState();load();}
 @override void dispose(){input.dispose();super.dispose();}
 Future<void> load()async{
  final g=++gen;setState((){busy=true;error=null;});
  try{final data=await widget.client.get(saleParam('/api/v1/actuals/options',{'type':widget.type,'owner':widget.owner,'q':input.text.trim()}));
   if(mounted&&g==gen)setState(()=>items=saleRows(data['items']));
  }catch(e){if(mounted&&g==gen)setState(()=>error='$e');}
  finally{if(mounted&&g==gen)setState(()=>busy=false);}
 }
 @override Widget build(BuildContext context)=>AlertDialog(title:Text(widget.type=='product'?'Chọn mã CTY':'Chọn khách hàng'),
  content:SizedBox(width:450,height:380,child:Column(children:[
   TextField(controller:input,decoration:InputDecoration(labelText:'Tìm mã hoặc tên',suffixIcon:IconButton(icon:const Icon(Icons.search),onPressed:load)),onSubmitted:(_)=>load()),
   if(busy)const LinearProgressIndicator(),if(error!=null)Text(error!),
   Expanded(child:ListView(children:[for(final item in items)ListTile(
    title:Text(item['name'].toString()),subtitle:Text(item['code']?.toString()??'Chưa có mã'),
    onTap:()=>Navigator.pop(context,item)),if(!busy&&items.isEmpty)const Text('Không có dữ liệu phù hợp')]))
  ])),actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('Đóng'))]);
}
class _ActualEditor extends StatefulWidget{
 final ActualClient client;final OfflineQueue queue;final Map<String,dynamic>? initial;
 const _ActualEditor({required this.client,required this.queue,this.initial});
 @override State<_ActualEditor> createState()=>_ActualEditorState();
}
class _ActualEditorState extends State<_ActualEditor>{
 final quantity=TextEditingController(),amount=TextEditingController();List<Map<String,dynamic>> staff=[];
 String owner='',customer='',product='',customerName='',productName='',ref=const Uuid().v4();
 bool busy=false,voided=false;String? error,lastPayload;
 late DateTime day;
 @override void initState(){super.initState();
  final row=widget.initial;owner=row?['owner_sub']?.toString()??widget.queue.identity;
  customer=row?['customer_id']?.toString()??'';product=row?['product_id']?.toString()??'';
  customerName=row?['customer_name']?.toString()??'';productName=row?['product_name']?.toString()??'';
  quantity.text=row?['quantity']?.toString()??'1';amount.text=row?['amount']?.toString()??'0';
  day=DateTime.tryParse(row?['sale_date']?.toString()??'')??DateTime.now();voided=row?['status']=='void';
  loadStaff();
 }
 @override void dispose(){quantity.dispose();amount.dispose();super.dispose();}
 Future<void> loadStaff()async{try{final r=await widget.client.get('/api/v1/actuals/options?type=staff');if(mounted)setState(()=>staff=saleRows(r['items']));}catch(e){if(mounted)setState(()=>error='$e');}}
 Future<void> select(String type)async{
  final r=await showDialog<Map<String,dynamic>>(context:context,builder:(_)=>_ActualPicker(client:widget.client,type:type,owner:owner));
  if(r!=null&&mounted)setState((){if(type=='customer'){customer=r['id'].toString();customerName=r['name'].toString();}
    else{product=r['id'].toString();productName=r['name'].toString();}});
 }
 Future<void> chooseDate()async{
  final selected=await showDatePicker(context:context,initialDate:day,firstDate:DateTime(2000),lastDate:DateTime(2100));
  if(selected!=null&&mounted)setState(()=>day=selected);
 }
 Future<void> save()async{
  final q=int.tryParse(quantity.text),v=int.tryParse(amount.text);
  if(customer.isEmpty||product.isEmpty||q==null||q<1||q>1000000000||v==null||v<0||v>1000000000000){setState(()=>error='Chọn khách hàng, mã CTY và nhập số nguyên hợp lệ.');return;}
  final item={'owner_sub':owner,'customer_id':customer,'product_id':product,
   'sale_date':'${day.year.toString().padLeft(4,'0')}-${day.month.toString().padLeft(2,'0')}-${day.day.toString().padLeft(2,'0')}',
   'quantity':q,'amount':v,'status':voided?'void':'active'};
  final serialized=jsonEncode(item);
  if(lastPayload!=null&&lastPayload!=serialized)ref=const Uuid().v4();lastPayload=serialized;
  setState((){busy=true;error=null;});
  try{
   final path=widget.initial==null?'/api/v1/actuals':'/api/v1/actuals/${widget.initial!['id']}';
   final doc={'client_ref':ref,'version':widget.initial?['version']??0,'item':item};
   if(widget.initial==null)await widget.client.post(path,doc);else await widget.client.patch(path,doc);
   if(mounted)Navigator.pop(context,true);
  }catch(e){if(mounted)setState(()=>error='$e');}
  finally{if(mounted)setState(()=>busy=false);}
 }
 @override Widget build(BuildContext context)=>AlertDialog(title:Text(widget.initial==null?'Nhập doanh số':'Sửa doanh số'),
  content:SizedBox(width:500,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
   if(staff.length>1)DropdownButtonFormField<String>(key:ValueKey(owner),initialValue:staff.any((s)=>s['id']==owner)?owner:null,
    decoration:const InputDecoration(labelText:'Nhân viên'),isExpanded:true,
    items:[for(final s in staff)DropdownMenuItem(value:s['id'].toString(),child:Text('${s['code']} · ${s['name']}',overflow:TextOverflow.ellipsis))],
    onChanged:busy?null:(v){if(v!=null)setState((){owner=v;customer='';customerName='';});}),
   const SizedBox(height:8),
   OutlinedButton(onPressed:busy?null:chooseDate,child:Text('Ngày: ${day.day}/${day.month}/${day.year}')),
   const SizedBox(height:8),
   ListTile(title:Text(customerName.isEmpty?'Chọn khách hàng':customerName),subtitle:const Text('Khách hàng phải thuộc nhân viên'),trailing:const Icon(Icons.search),onTap:busy?null:()=>select('customer')),
   ListTile(title:Text(productName.isEmpty?'Chọn sản phẩm / mã CTY':productName),trailing:const Icon(Icons.search),onTap:busy?null:()=>select('product')),
   TextField(controller:quantity,enabled:!busy,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Số lượng')),
   const SizedBox(height:8),
   TextField(controller:amount,enabled:!busy,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Doanh số (VNĐ)')),
   if(widget.initial!=null)CheckboxListTile(value:voided,onChanged:busy?null:(v)=>setState(()=>voided=v??false),title:const Text('Hủy dòng doanh số (có nhật ký)')),
   if(busy)const LinearProgressIndicator(),if(error!=null)Text(error!,style:TextStyle(color:Theme.of(context).colorScheme.error)),
  ]))),actions:[TextButton(onPressed:busy?null:()=>Navigator.pop(context),child:const Text('Đóng')),
    FilledButton(onPressed:busy?null:save,child:const Text('Lưu doanh số'))]);
}
