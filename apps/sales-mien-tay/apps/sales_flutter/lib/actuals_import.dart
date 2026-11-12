import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'actuals.dart';
import 'actuals_parser.dart';
import 'responsive_controls.dart';
import 'xlsx_reader.dart';

class ActualImportPage extends StatefulWidget{
 final ActualClient client;
 const ActualImportPage({super.key,required this.client});
 @override State<ActualImportPage> createState()=>_ActualImportPageState();
}
class _ActualImportPageState extends State<ActualImportPage>{
 XlsxBook? workbook;String filename='',sheet='';int header=0,generation=0;
 final mapping=<int,String>{};bool busy=false,done=false;String? error,hash;
 List<Map<String,dynamic>> preview=[],parsed=[];List<String> errors=[];
 String operation=const Uuid().v4();
 XlsxSheet? get selected=>workbook?.tables[sheet];
 void invalidate(){preview=[];parsed=[];hash=null;errors=[];error=null;operation=const Uuid().v4();}
 Future<void> pick()async{
  setState(()=>busy=true);
  try{
   final file=await FilePicker.platform.pickFiles(type:FileType.custom,allowedExtensions:['xlsx'],withData:true);
   if(file==null)return;
   final f=file.files.single;
   if(f.bytes==null||f.size>5*1024*1024||!f.name.toLowerCase().endsWith('.xlsx'))throw StateError('Chỉ nhận .xlsx tối đa 5 MB');
   final book=decodeInventoryWorkbook(f.bytes!);
   if(mounted)setState((){workbook=book;filename=f.name;sheet=book.tables.keys.first;header=0;generation++;mapping.clear();invalidate();done=false;});
  }catch(e){if(mounted)setState(()=>error='Không đọc được Excel: $e');}
  finally{if(mounted)setState(()=>busy=false);}
 }
 Future<void> inspect()async{
  final source=selected;if(source==null)return;
  final result=parseActualSheet(source,header,mapping);
  setState((){invalidate();errors=result.errors;parsed=result.rows;});
  if(errors.isNotEmpty)return;
  setState(()=>busy=true);
  try{
   final r=await widget.client.post('/api/v1/actuals/import/preview',{'filename':filename,'sheet':sheet,'rows':parsed});
   if(mounted)setState((){preview=saleRows(r['items']);hash=r['preview_hash'].toString();});
  }catch(e){if(mounted)setState(()=>error='$e');}
  finally{if(mounted)setState(()=>busy=false);}
 }
 Future<void> confirm()async{
  if(busy||hash==null||preview.isEmpty)return;
  final yes=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(
   title:const Text('Xác nhận nhập doanh số'),
   content:Text('File $filename · ${preview.length} dòng. Dòng trùng giống hệt sẽ bỏ qua; dữ liệu khác cùng mã chứng từ sẽ bị chặn. Không tự cập nhật Target hoặc tồn kho.'),
   actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Hủy')),
    FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Xác nhận ghi'))]));
  if(yes!=true||!mounted)return;setState(()=>busy=true);
  try{
   final r=await widget.client.post('/api/v1/actuals/import/confirm',{'client_ref':operation,
    'filename':filename,'sheet':sheet,'preview_hash':hash,'rows':parsed});
   final b=r['item'] as Map;
   if(mounted)setState((){done=true;error='Đã ghi ${b['inserted_count']} dòng, bỏ qua ${b['skipped_count']} dòng trùng. Có nhật ký lần nhập.';workbook=null;preview=[];parsed=[];hash=null;});
  }catch(e){if(mounted)setState(()=>error='Chưa xác nhận thành công: $e. Giữ UUID để thử lại đúng giao dịch; nếu có xung đột hãy xem trước lại.');}
  finally{if(mounted)setState(()=>busy=false);}
 }
 @override Widget build(BuildContext context){
  final s=selected,columns=s==null||header>=s.rows.length?<XlsxCell?>[]:s.rows[header];
  return Scaffold(appBar:AppBar(title:const Text('Nhập doanh số')),body:ListView(padding:const EdgeInsets.all(12),children:[
   ExpansionTile(
      tilePadding:EdgeInsets.zero,
      title:const Text('Lưu ý nhập file'),
      children:[Padding(padding:const EdgeInsets.only(bottom:8),
        child:Text('Mã nhân viên, khách, sản phẩm và chứng từ phải là ô văn bản '
          'để giữ số 0 đầu. Chọn đủ các cột bắt buộc, không chọn trùng. '
          'Cần cập nhật mã khách CTY trước khi nhập doanh số.'))],
    ),
    Wrap(spacing:8,runSpacing:8,children:[
    FilledButton.icon(onPressed:busy?null:pick,icon:const Icon(Icons.upload_file),label:const Text('Chọn file')),
    OutlinedButton(onPressed:busy?null:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>ActualImportHistory(client:widget.client))),child:const Text('Nhật ký')),
   ]),
   if(filename.isNotEmpty)Text(filename),
   if(busy)const LinearProgressIndicator(),if(error!=null)Text(error!,style:TextStyle(color:done?Colors.green:Theme.of(context).colorScheme.error)),
   if(s!=null)...[
    const SizedBox(height:10),
    AdaptiveFilterRow(children:[
      DropdownButtonFormField<String>(key:ValueKey('sheet:$generation'),initialValue:sheet,isExpanded:true,
        decoration:const InputDecoration(labelText:'Trang Excel'),
        items:[for(final name in workbook!.tables.keys)
          DropdownMenuItem(value:name,child:Text(name,overflow:TextOverflow.ellipsis))],
        onChanged:busy?null:(v){if(v!=null)setState((){sheet=v;header=0;mapping.clear();invalidate();});}),
      DropdownButtonFormField<int>(key:ValueKey('header:$sheet:$generation'),initialValue:header,isExpanded:true,
        decoration:const InputDecoration(labelText:'Dòng tiêu đề'),
        items:[for(var i=0;i<s.rows.length&&i<20;i++)
          DropdownMenuItem(value:i,child:Text('Dòng ${i+1}'))],
        onChanged:busy?null:(v){if(v!=null)setState((){header=v;mapping.clear();invalidate();});}),
    ]),
    const SizedBox(height:12),
    Text('Ánh xạ cột · vuốt ngang để xem thêm',style:Theme.of(context).textTheme.titleMedium),
    SingleChildScrollView(scrollDirection:Axis.horizontal,child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
     for(var i=0;i<columns.length;i++)SizedBox(width:190,child:Padding(padding:const EdgeInsets.all(4),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      SizedBox(height:46,child:Text('${actualColumn(i)} · ${columns[i]?.text??''}',maxLines:2,overflow:TextOverflow.ellipsis)),
      DropdownButtonFormField<String>(key:ValueKey('$generation:$sheet:$header:$i:${mapping[i]}'),initialValue:mapping[i]??'ignore',
       isExpanded:true,decoration:const InputDecoration(labelText:'Ánh xạ'),
       items:[for(final e in actualAttributes.entries)DropdownMenuItem(value:e.key,child:Text(e.value,overflow:TextOverflow.ellipsis))],
       onChanged:busy?null:(v){if(v!=null)setState((){mapping[i]=v;invalidate();});}),
      for(final row in s.rows.skip(header+1).take(3))Padding(padding:const EdgeInsets.symmetric(vertical:5),child:Text(i<row.length?row[i]?.text??'':'',maxLines:1,overflow:TextOverflow.ellipsis)),
     ]))),
    ])),
    if(mapping.values.where((x)=>x!='ignore').length!=mapping.values.where((x)=>x!='ignore').toSet().length)
     const Text('Không được chọn trùng thuộc tính.'),
    const SizedBox(height:8),
    FilledButton(onPressed:busy?null:inspect,child:const Text('Xem trước')),
   ],
   if(errors.isNotEmpty)...[Text('${errors.length} lỗi — chưa thể nhập',style:Theme.of(context).textTheme.titleMedium),
    for(final e in errors.take(50))Text(e)],
   if(preview.isNotEmpty)...[
    Text('Xem trước ${preview.length} dòng · ${preview.where((r)=>r['duplicate']==true).length} trùng giống hệt',style:Theme.of(context).textTheme.titleMedium),
    SizedBox(height:340,child:ListView.builder(itemCount:preview.length,itemBuilder:(_,i){final r=preview[i];return Card(child:ListTile(
     title:Text('${r['external_ref']} / ${r['line_ref']} · ${r['company_code']}'),
     subtitle:Text('${r['sale_date']} · NV ${r['employee_code']} · KH ${r['customer_code']}\nSL ${r['quantity']} · ${saleMoney(r['amount'])}${r['duplicate']==true?' · TRÙNG (BỎ QUA)':''}'),
     isThreeLine:true));})),
    FilledButton(onPressed:busy?null:confirm,child:const Text('Xác nhận')),
   ],
  ]));
 }
}
class ActualImportHistory extends StatefulWidget{
 final ActualClient client;const ActualImportHistory({super.key,required this.client});
 @override State<ActualImportHistory> createState()=>_ActualImportHistoryState();
}
class _ActualImportHistoryState extends State<ActualImportHistory>{
 bool busy=true;String? error;List<Map<String,dynamic>> rows=[];
 @override void initState(){super.initState();load();}
 Future<void> load()async{
  setState((){busy=true;error=null;});
  try{final result=await widget.client.get('/api/v1/actuals/import/history');if(mounted)setState(()=>rows=saleRows(result['items']));}
  catch(e){if(mounted)setState(()=>error='$e');}
  finally{if(mounted)setState(()=>busy=false);}
 }
 @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Nhật ký nhập doanh số')),
  body:ListView(padding:const EdgeInsets.all(12),children:[
   if(busy)const LinearProgressIndicator(),if(error!=null)Text(error!),
   for(final r in rows)Card(child:ListTile(
    title:Text('${r['filename']} · ${r['sheet']}'),
    subtitle:Text('${r['created_at']}\nTổng ${r['row_count']} · Ghi ${r['inserted_count']} · Bỏ qua ${r['skipped_count']} · Người nhập ${r['actor_sub']}'),
    isThreeLine:true)),
   if(!busy&&rows.isEmpty)const Text('Chưa có lần nhập nào.')
  ]));
}
