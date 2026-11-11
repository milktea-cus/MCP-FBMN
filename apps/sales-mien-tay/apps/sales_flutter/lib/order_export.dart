import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';

/// Preparation workbook, NOT a claim of certification by the company importer.
/// No prices, tax, invoices or payment fields are introduced.
String _escape(String s)=>s.runes.where((r)=>r>=32||r==9||r==10||r==13)
 .map(String.fromCharCode).join().replaceAll('&','&amp;').replaceAll('<','&lt;')
 .replaceAll('>','&gt;').replaceAll('"','&quot;').replaceAll("'",'&apos;');
String _col(int n){var i=n+1,s='';while(i>0){i--;s=String.fromCharCode(65+i%26)+s;i~/=26;}return s;}
String _xmlSheet(List<List<Object?>> rows){
 final output=StringBuffer('<?xml version="1.0" encoding="utf-8"?>'
  '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>');
 for(var y=0;y<rows.length;y++){
  output.write('<row r="${y+1}">');
  for(var x=0;x<rows[y].length;x++){
   final item=rows[y][x];if(item==null)continue;
   final position='${_col(x)}${y+1}';
   if(item is int){output.write('<c r="$position" t="n"><v>$item</v></c>');}
   else{output.write('<c r="$position" t="inlineStr"><is><t xml:space="preserve">${_escape('$item')}</t></is></c>');}
  }
  output.write('</row>');
 }
 output.write('</sheetData></worksheet>');return output.toString();
}
Uint8List buildOrderPreparationXlsx(Map<String,dynamic> order){
 if(!['exported','imported'].contains(order['status']))throw StateError('Đơn chưa xuất');
 final code=order['customer_code']?.toString()??'';
 if(code.isEmpty)throw StateError('Thiếu mã khách CTY');
 final lines=(order['lines'] as List? ?? []).map((e)=>Map<String,dynamic>.from(e as Map)).toList();
 if(lines.isEmpty)throw StateError('Giỏ hàng rỗng');
 final data=<List<Object?>>[
  ['Mã đơn Field Work','Mã khách CTY','Mã CTY','Đơn vị tính','Số lượng','Ghi chú'],
  for(final line in lines)[order['id'].toString(),code,line['company_code']?.toString()??'',
    line['unit']?.toString()??'',int.parse(line['quantity'].toString()),order['note']?.toString()??'']
 ];
 if(lines.any((r)=>(r['company_code']?.toString()??'').isEmpty||int.tryParse('${r['quantity']}')==null))
  throw StateError('Dòng sản phẩm chưa xác minh');
 final readme=<List<Object?>>[
  ['FIELD WORK — FILE CHUẨN BỊ NHẬP ĐƠN HÀNG'],
  ['Trạng thái','CHƯA ĐƯỢC ĐỐI CHIẾU VỚI MẪU IMPORT APP CÔNG TY'],
  ['Mã đơn',order['id'].toString()],
  ['Khách hàng',order['customer_name']??''],
  ['Mã khách công ty',code],
  ['Ngày xuất',order['exported_at']?.toString()??''],
  ['Lưu ý','Không có giá/thuế/thanh toán. Xuất đơn không trừ tồn kho và không tạo doanh số.'],
  ['Tồn kho','Đã kiểm tra online lúc xác nhận xuất, không đặt giữ số lượng.'],
  ['Nhập hệ thống công ty','Chỉ xác nhận đã nhập khi nhân viên đối chiếu với app công ty.'],
 ];
 final strings=<String,String>{
 '[Content_Types].xml':'<?xml version="1.0" encoding="UTF-8"?>'
 '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
 '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
 '<Default Extension="xml" ContentType="application/xml"/>'
 '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
 '<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'
 '<Override PartName="/xl/worksheets/sheet2.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/></Types>',
 '_rels/.rels':'<?xml version="1.0" encoding="UTF-8"?>'
 '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
 '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>',
 'xl/workbook.xml':'<?xml version="1.0" encoding="UTF-8"?>'
 '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
 '<sheets><sheet name="Đơn hàng" sheetId="1" r:id="rId1"/><sheet name="Hướng dẫn" sheetId="2" r:id="rId2"/></sheets></workbook>',
 'xl/_rels/workbook.xml.rels':'<?xml version="1.0" encoding="UTF-8"?>'
 '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
 '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>'
 '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet2.xml"/></Relationships>',
 'xl/worksheets/sheet1.xml':_xmlSheet(data),
 'xl/worksheets/sheet2.xml':_xmlSheet(readme),
 };
 final archive=Archive();
 for(final f in strings.entries){final b=utf8.encode(f.value);archive.addFile(ArchiveFile(f.key,b.length,b));}
 return Uint8List.fromList(ZipEncoder().encode(archive));
}
