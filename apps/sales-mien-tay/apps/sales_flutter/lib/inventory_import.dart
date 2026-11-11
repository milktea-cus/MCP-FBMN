import 'dart:convert';
import 'xlsx_reader.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'customers.dart';
import 'session.dart';

Map<String,dynamic> _map(dynamic v)=>Map<String,dynamic>.from(v as Map);
List<Map<String,dynamic>> _rows(dynamic v)=>(v as List).map(_map).toList();
String cellText(XlsxCell? cell)=>cell?.text??'';
String? textCode(XlsxCell? cell){
 if(cell?.type!='text')return null;
 final s=cell!.text.replaceAll(RegExp(r'[\u200B-\u200D\uFEFF]'),'').trim();
 return s.isEmpty||s.length>80?null:s;
}
int? stockQuantity(XlsxCell? cell){
 if(cell==null)return null;
 num? n;
 if(cell.type=='number'){n=num.tryParse(cell.text);}
 else if(cell.type=='text'){final s=cell.text.trim();if(!RegExp(r'^(?:\d+|\d{1,3}(?:[.,]\d{3})+)$').hasMatch(s))return null;n=int.tryParse(s.replaceAll(RegExp(r'[.,]'),''));}
 if(n==null||!n.isFinite||n<0||n>2147483647||n!=n.truncate())return null;
 return n.toInt();
}
class InventoryParse{
 final List<Map<String,dynamic>> rows;final List<String> errors;
 InventoryParse(this.rows,this.errors);
}
InventoryParse parseInventory(XlsxSheet sheet,int header,int code,int qty){
 final rows=<Map<String,dynamic>>[],errors=<String>[],seen=<String>{};
 final all=sheet.rows;
 XlsxCell? at(List<XlsxCell?> r,int i)=>i<r.length?r[i]:null;
 for(var i=header+1;i<all.length;i++){
  final row=all[i],c=at(row,code),q=at(row,qty);
  if(row.every((v)=>cellText(v).trim().isEmpty))continue;
  final key=textCode(c),number=stockQuantity(q);
  if(key==null){errors.add('Dòng ${i+1}: mã CTY phải là ô văn bản, không được trống');continue;}
  if(number==null){errors.add('Dòng ${i+1}: tồn phải là số nguyên không âm, không được trống');continue;}
  if(!seen.add(key.toUpperCase())){errors.add('Dòng ${i+1}: mã trùng $key');continue;}
  rows.add({'company_code':key,'quantity':number,'row_number':i+1});
 }
 if(rows.isEmpty)errors.add('Không có dòng tồn hợp lệ');
 if(rows.length>2000)errors.add('Tối đa 2000 dòng mỗi lần nhập. Chia file thành các phần.');
 return InventoryParse(rows,errors);
}
const importAttributes={'ignore':'Bỏ qua','company_code':'Mã CTY','name':'Tên hàng','sku':'SKU','brand':'Nhãn hàng','category':'Nhóm hàng','unit':'ĐVT','pieceUnit':'ĐVT lẻ','packUnit':'Tên gói/lốc/hộp','unitsPerCarton':'SP/thùng','unitsPerPack':'SP/gói','packsPerCarton':'Gói/thùng','paperSize':'Khổ giấy','pages':'Số trang','ruling':'Dòng kẻ','gsm':'Định lượng giấy','coverType':'Loại bìa','packagingNote':'Ghi chú quy cách','quantity':'Tồn kho'};
const numericAttributes=['unitsPerCarton','unitsPerPack','packsPerCarton','pages','gsm'];
InventoryParse parseCatalogImport(XlsxSheet sheet,int header,Map<int,String> mapping){
 final rows=<Map<String,dynamic>>[],errors=<String>[],seen=<String>{};
 final keys=mapping.entries.where((e)=>e.value!='ignore').toList();
 if(keys.where((e)=>e.value=='company_code').length!=1||keys.length<2||keys.map((e)=>e.value).toSet().length!=keys.length)return InventoryParse([],['Chọn một cột mã CTY và ít nhất một thuộc tính, không trùng mapping']);
 for(var i=header+1;i<sheet.rows.length;i++){
  final row=sheet.rows[i];XlsxCell? at(int j)=>j<row.length?row[j]:null;
  if(row.every((c)=>cellText(c).trim().isEmpty))continue;
  final code=textCode(at(keys.firstWhere((e)=>e.value=='company_code').key));
  if(code==null||!seen.add(code.toUpperCase())){errors.add('Dòng ${i+1}: mã CTY thiếu, không phải text hoặc trùng');continue;}
  final patch=<String,dynamic>{};bool invalid=false;
  for(final e in keys.where((e)=>e.value!='company_code')){
   final cell=at(e.key),v=cellText(cell).trim();if(v.isEmpty)continue;
   if(cell!.type=='formula'||cell.type=='other'){errors.add('Dòng ${i+1}: ${importAttributes[e.value]} không hỗ trợ công thức');invalid=true;continue;}
   if(numericAttributes.contains(e.value)){final n=stockQuantity(cell);if(n==null||n<1||n>1000000){errors.add('Dòng ${i+1}: ${importAttributes[e.value]} phải là số nguyên dương');invalid=true;}else{patch[e.value]=n;}}
   else{if(e.value=='sku'&&cell.type!='text'){errors.add('Dòng ${i+1}: SKU phải là text');invalid=true;}else{patch[e.value]=v;}}
  }
  if(!invalid&&patch.isNotEmpty)rows.add({'company_code':code,'row_number':i+1,'patch':patch});
 }
 if(rows.isEmpty)errors.add('Không có thay đổi hợp lệ');
 if(rows.length>2000)errors.add('Tối đa 2000 dòng mỗi lần');
 return InventoryParse(rows,errors);
}
String excelColumn(int i){var n=i+1,s='';while(n>0){n--;s=String.fromCharCode(65+n%26)+s;n~/=26;}return s;}

class InventoryImportPage extends StatefulWidget{
 final CustomerService service;
 const InventoryImportPage({super.key,required this.service});
 @override State<InventoryImportPage> createState()=>_InventoryImportPageState();
}
class _InventoryImportPageState extends State<InventoryImportPage>{
 XlsxBook? book;String filename='',sheetName='';int header=0;int? code,qty;bool busy=false;String? message;List<String> errors=[];List<Map<String,dynamic>> preview=[];String? revision;String op=const Uuid().v4();bool canConfirm=false,duplicate=false;int fileGeneration=0;bool catalogMode=false;final mapping=<int,String>{};
 XlsxSheet? get sheet=>book?.tables[sheetName];
 void invalidate(){preview=[];revision=null;errors=[];canConfirm=false;duplicate=false;op=const Uuid().v4();}
 Future<Map<String,dynamic>> post(String path,Map<String,dynamic> data)async=>decodeApi(await http.post(widget.service.uri(path),headers:widget.service.headers,body:jsonEncode(data)).timeout(const Duration(seconds:60)));
 Future<void> pick()async{
  if(busy)return;setState(()=>busy=true);
  try{
   final picked=await FilePicker.platform.pickFiles(type:FileType.custom,allowedExtensions:['xlsx'],withData:true);
   if(picked==null)return;
   final f=picked.files.single;
   if(f.bytes==null||f.size>5*1024*1024||!f.name.toLowerCase().endsWith('.xlsx'))throw StateError('Chỉ nhận .xlsx tối đa 5 MB');
   final decoded=decodeInventoryWorkbook(f.bytes!);
   if(decoded.tables.isEmpty)throw StateError('File không có sheet');
   if(mounted)setState((){book=decoded;fileGeneration++;filename=f.name;sheetName=decoded.tables.keys.first;header=0;code=null;qty=null;mapping.clear();invalidate();message=null;});
  }catch(e){if(mounted)setState(()=>message='Không đọc được Excel: $e');}
  finally{if(mounted)setState(()=>busy=false);}
 }
 Future<void> inspect()async{
  if(busy||sheet==null)return;
  if(!catalogMode&&(code==null||qty==null||code==qty))return;
  final parsed=catalogMode?parseCatalogImport(sheet!,header,mapping):parseInventory(sheet!,header,code!,qty!);
  setState((){invalidate();errors=parsed.errors;message=null;});
  if(errors.isNotEmpty)return;
  setState(()=>busy=true);
  try{
   final data=await post(catalogMode?'/api/v1/catalog/import/preview':'/api/v1/inventory/preview',{'filename':filename,'sheet':sheetName,'rows':parsed.rows});
   if(mounted)setState((){preview=_rows(data['items']);revision=catalogMode?'catalog':data['revision'].toString();canConfirm=catalogMode||data['can_confirm']==true;duplicate=data['duplicate']==true;});
  }catch(e){if(mounted)setState(()=>message=e.toString());}
  finally{if(mounted)setState(()=>busy=false);}
 }
 Future<void> confirm()async{
  if(busy||!canConfirm||preview.isEmpty||revision==null)return;
  final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:Text(catalogMode?'Xác nhận cập nhật sản phẩm':'Xác nhận nhập tồn'),content:Text(catalogMode?'Cập nhật ${preview.length} mã. Ô trống giữ nguyên; không thay tồn hoặc giá.':'Cập nhật ${preview.length} mã từ $filename. Mã ngoài file giữ nguyên. Mã mới chưa xác minh tên/ĐVT. Không thay giá hoặc quy cách.'),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Hủy')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Xác nhận'))]));
  if(ok!=true||!mounted)return;
  setState(()=>busy=true);
  try{
   final data=await post(catalogMode?'/api/v1/catalog/import/confirm':'/api/v1/inventory/confirm',{'client_ref':op,'filename':filename,'sheet':sheetName,'revision':revision,'rows':catalogMode?[for(final r in preview){'company_code':r['company_code'],'row_number':r['row_number'],'patch':r['patch'],'version':r['version']}]:[for(final r in preview){'company_code':r['company_code'],'quantity':int.parse(r['quantity'].toString()),'row_number':r['row_number'],'product_version':r['product_version']}]});
   if(mounted)setState((){message='Đã ghi ${_map(data['item'])['row_count']} mã. Xem nhật ký để kiểm tra.';invalidate();book=null;filename='';sheetName='';});
  }catch(e){if(mounted)setState(()=>message='Chưa xác nhận thành công: $e. Nếu mất mạng, thử lại cùng thao tác; nếu xung đột, xem trước lại.');}
  finally{if(mounted)setState(()=>busy=false);}
 }
 @override Widget build(BuildContext context){
  final s=sheet,headerRows=s==null?0:(s.maxRows<20?s.maxRows:20),columns=s==null||header>=s.rows.length?<XlsxCell?>[]:s.rows[header];
  final attrs=importAttributes.entries.where((e)=>catalogMode?e.key!='quantity':['ignore','company_code','quantity'].contains(e.key)).toList();
  return Scaffold(appBar:AppBar(title:const Text('Nhập Excel')),body:ListView(padding:const EdgeInsets.all(16),children:[
   SegmentedButton<bool>(segments:const [ButtonSegment(value:false,label:Text('Cập nhật tồn')),ButtonSegment(value:true,label:Text('Cập nhật sản phẩm'))],selected:{catalogMode},onSelectionChanged:busy?null:(v)=>setState((){catalogMode=v.single;mapping.clear();code=null;qty=null;mapping.clear();invalidate();})),
   Text(catalogMode?'Ô trống giữ nguyên · chỉ cập nhật thuộc tính đã chọn · mã mới cần tên hàng.':'Snapshot tồn · chỉ cập nhật mã có trong file · không realtime.'),
   Wrap(spacing:8,runSpacing:8,children:[FilledButton.icon(onPressed:busy?null:pick,icon:const Icon(Icons.upload_file),label:const Text('Chọn file .xlsx')),OutlinedButton(onPressed:busy?null:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>catalogMode?CatalogImportHistory(service:widget.service):InventoryHistoryPage(service:widget.service))),child:const Text('Nhật ký nhập'))]),
   if(filename.isNotEmpty)Text(filename),if(busy)const LinearProgressIndicator(),if(message!=null)Padding(padding:const EdgeInsets.all(8),child:Text(message!)),
   if(s!=null)...[
    const SizedBox(height:12),
    DropdownButtonFormField<String>(key:ValueKey(fileGeneration),initialValue:sheetName,isExpanded:true,decoration:const InputDecoration(labelText:'Sheet'),items:[for(final name in book!.tables.keys)DropdownMenuItem(value:name,child:Text(name))],onChanged:busy?null:(v)=>setState((){sheetName=v!;header=0;code=null;qty=null;mapping.clear();invalidate();})),
    const SizedBox(height:12),
    DropdownButtonFormField<int>(key:ValueKey('$fileGeneration:$sheetName'),initialValue:headerRows>0?header:null,decoration:const InputDecoration(labelText:'Dòng tiêu đề'),items:[for(var i=0;i<headerRows;i++)DropdownMenuItem(value:i,child:Text('Dòng ${i+1}'))],onChanged:busy?null:(v)=>setState((){header=v!;code=null;qty=null;mapping.clear();invalidate();})),
    const SizedBox(height:12),
    const Text('Ánh xạ cột Excel · cuộn ngang để xem toàn bộ'),
    SingleChildScrollView(scrollDirection:Axis.horizontal,child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
     for(var i=0;i<columns.length;i++)SizedBox(width:190,child:Padding(padding:const EdgeInsets.all(4),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      SizedBox(height:44,child:Text('${excelColumn(i)} · ${cellText(columns[i])}',maxLines:2,overflow:TextOverflow.ellipsis,style:Theme.of(context).textTheme.titleSmall)),
      const SizedBox(height:6),
      DropdownButtonFormField<String>(key:ValueKey('map:$fileGeneration:$sheetName:$header:$catalogMode:$i:${mapping[i]}'),initialValue:mapping[i]??'ignore',isExpanded:true,decoration:const InputDecoration(labelText:'Thuộc tính'),items:[for(final e in attrs)DropdownMenuItem(value:e.key,child:Text(e.value,overflow:TextOverflow.ellipsis))],onChanged:busy?null:(v)=>setState((){mapping[i]=v!;code=null;qty=null;for(final e in mapping.entries){if(e.value=='company_code')code=e.key;if(e.value=='quantity')qty=e.key;}invalidate();})),
      for(final row in s.rows.skip(header+1).take(3))Padding(padding:const EdgeInsets.symmetric(vertical:5),child:Text(i<row.length?cellText(row[i]):'',maxLines:1,overflow:TextOverflow.ellipsis)),
     ]))),
    ])),
    if(mapping.values.where((v)=>v!='ignore').toSet().length!=mapping.values.where((v)=>v!='ignore').length)const Text('Không chọn trùng thuộc tính.'),
    const SizedBox(height:12),FilledButton(onPressed:busy||code==null||(!catalogMode&&qty==null)||mapping.values.where((v)=>v!='ignore').toSet().length!=mapping.values.where((v)=>v!='ignore').length?null:inspect,child:const Text('Xem trước')),
   ],
   if(errors.isNotEmpty)...[Text('${errors.length} lỗi · chưa thể nhập',style:Theme.of(context).textTheme.titleMedium),for(final e in errors.take(50))Text(e),if(errors.length>50)const Text('Còn lỗi khác; sửa file rồi chọn lại.')],
   if(preview.isNotEmpty)...[
    Text('Xem trước ${preview.length} mã · ${preview.where((r)=>catalogMode?r['is_new']==true:r['product_version']==0).length} mã mới',style:Theme.of(context).textTheme.titleMedium),
    if(duplicate)const Text('Nội dung trùng lần nhập gần nhất; không nhập lại.')else if(!canConfirm)const Text('Có mã ngừng sử dụng; Admin cần kiểm tra danh mục trước khi nhập.'),
    SizedBox(height:400,child:ListView.builder(itemCount:preview.length,itemBuilder:(c,i){final r=preview[i];return Card(child:ListTile(title:Text('${r['company_code']} · ${r['name']??"Mã mới, chưa xác minh"}'),subtitle:Text(catalogMode?(r['changes'] as List).map((x)=>'${importAttributes[x['field']]}: ${x['before']??"—"} → ${x['after']}').join('\n'):'Dòng ${r['row_number']} · ĐVT: ${r['unit']??"Chưa xác minh"}${r['active']==false?" · Ngừng sử dụng":""}\nTồn cũ: ${r['old_quantity']??"Chưa cập nhật"} → Mới: ${r['quantity']}')));})),
    FilledButton(onPressed:busy||!canConfirm?null:confirm,child:Text(catalogMode?'Xác nhận cập nhật sản phẩm':'Xác nhận nhập tồn')),
   ]
  ]));
 }
}
class InventoryHistoryPage extends StatefulWidget{
 final CustomerService service;
 const InventoryHistoryPage({super.key,required this.service});
 @override State<InventoryHistoryPage> createState()=>_InventoryHistoryPageState();
}
class _InventoryHistoryPageState extends State<InventoryHistoryPage>{
 List<Map<String,dynamic>> batches=[];String? latest,error;bool busy=false;final ops=<String,String>{};
 @override void initState(){super.initState();load();}
 Future<Map<String,dynamic>> get(String p)async=>decodeApi(await http.get(widget.service.uri(p),headers:widget.service.headers).timeout(const Duration(seconds:25)));
 Future<void> load()async{
  if(busy)return;setState(()=>busy=true);
  try{final d=await get('/api/v1/inventory/batches');if(mounted)setState((){batches=_rows(d['items']);latest=_map(d['state'])['latest_batch']?.toString();error=null;});}catch(e){if(mounted)setState(()=>error=e.toString());}finally{if(mounted)setState(()=>busy=false);}
 }
 Future<void> detail(Map<String,dynamic> b)async{
  try{final d=await get('/api/v1/inventory/batches/${b['id']}');if(!mounted)return;final rows=_rows(d['items']);await showDialog<void>(context:context,builder:(c)=>AlertDialog(title:Text(b['filename'].toString()),content:SizedBox(width:420,height:400,child:ListView.builder(itemCount:rows.length,itemBuilder:(c,i){final r=rows[i];return ListTile(title:Text(r['company_code'].toString()),subtitle:Text('${r['old_quantity']??"Chưa cập nhật"} → ${r['new_quantity']}${r['created_product']==true?" · Mã mới":""}'));})),actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('Đóng'))]));}catch(e){if(mounted)setState(()=>error=e.toString());}
 }
 Future<void> rollback(Map<String,dynamic> b)async{
  final id=b['id'].toString();if(busy||latest!=id)return;
  final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('Hoàn tác lần nhập gần nhất?'),content:const Text('Khôi phục tồn và thời điểm cũ. Mã mới chưa sửa sẽ ngừng sử dụng, giữ lịch sử. Không xóa sản phẩm.'),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Hủy')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Hoàn tác'))]));
  if(ok!=true||!mounted)return;setState(()=>busy=true);
  try{decodeApi(await http.post(widget.service.uri('/api/v1/inventory/rollback'),headers:widget.service.headers,body:jsonEncode({'batch_id':id,'client_ref':ops.putIfAbsent(id,()=>const Uuid().v4())})).timeout(const Duration(seconds:60)));if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Đã hoàn tác')));}catch(e){if(mounted)setState(()=>error=e.toString());}
  finally{if(mounted){setState(()=>busy=false);await load();}}
 }
 @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Nhật ký nhập tồn'),actions:[IconButton(onPressed:busy?null:load,icon:const Icon(Icons.sync))]),body:ListView(padding:const EdgeInsets.all(12),children:[if(busy)const LinearProgressIndicator(),if(error!=null)Text(error!),if(batches.isEmpty&&!busy)const Text('Chưa có lần nhập.'),for(final b in batches)Card(child:ListTile(title:Text(b['filename'].toString()),subtitle:Text('${b['sheet']} · ${b['row_count']} mã · ${b['status']=="applied"?"Đã nhập":"Đã hoàn tác"}\n${b['applied_at']}'),onTap:()=>detail(b),trailing:b['id']==latest?TextButton(onPressed:busy?null:()=>rollback(b),child:const Text('Hoàn tác')):null))]));
}

class CatalogImportHistory extends StatelessWidget{
 final CustomerService service;
 const CatalogImportHistory({super.key,required this.service});
 @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Nhật ký nhập sản phẩm')),body:FutureBuilder<http.Response>(future:http.get(service.uri('/api/v1/catalog/import/history'),headers:service.headers),builder:(c,s){if(s.hasError)return Center(child:Text(s.error.toString()));if(!s.hasData)return const Center(child:CircularProgressIndicator());try{final rows=_rows(decodeApi(s.data!)['items']);return ListView(children:[for(final r in rows)ListTile(title:Text(r['filename'].toString()),subtitle:Text('${r['sheet']} · ${r['row_count']} mã · ${r['created_at']}'))]);}catch(e){return Center(child:Text(e.toString()));}}));
}
