import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';

/// A small offline XLSX serializer. All untrusted labels are inline strings, not formulas.
String _xml(String text)=>text.runes.where((x)=>x>=32||x==9||x==10||x==13)
 .map((x)=>String.fromCharCode(x)).join().replaceAll('&','&amp;').replaceAll('<','&lt;')
 .replaceAll('>','&gt;').replaceAll('"','&quot;').replaceAll("'",'&apos;');
String _column(int i){var index=i+1,result='';while(index>0){index--;result=String.fromCharCode(65+index%26)+result;index~/=26;}return result;}
String _cell(Object? v,int col,int row){
 final ref='${_column(col)}$row';
 if(v==null)return '';
 final value=v.toString();
 if(v is num||(v is int)){return '<c r="$ref" t="n"><v>$value</v></c>';}
 if(v is ReportNumber){
  // Excel numeric cells retain at most 15 significant digits.
  return RegExp(r'^\d{1,15}$').hasMatch(value)
   ? '<c r="$ref" t="n"><v>$value</v></c>'
   : '<c r="$ref" t="inlineStr"><is><t>${_xml(value)}</t></is></c>';
 }
 return '<c r="$ref" t="inlineStr"><is><t xml:space="preserve">${_xml(value)}</t></is></c>';
}
class ReportNumber{
 final String number;
 const ReportNumber(this.number);
 @override String toString()=>number;
}
String _sheet(List<List<Object?>> data){
 final body=StringBuffer();
 for(var row=0;row<data.length;row++){
  body.write('<row r="${row+1}">');
  for(var col=0;col<data[row].length;col++){body.write(_cell(data[row][col],col,row+1));}
  body.write('</row>');
 }
 return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
 '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
 '<sheetData>$body</sheetData></worksheet>';
}
Object _integer(Object? v)=>v==null?'—':ReportNumber(v.toString());
String _period(Map<String,dynamic> f){
 final year=f['year'].toString(),mode=f['period'];
 if(mode=='year')return 'Năm $year';
 if(mode=='quarter')return 'Quý ${f['quarter']}/$year';
 return 'Tháng ${f['month']}/$year';
}
/// The caller supplies only an exact, authorized, server-filtered export (<=10k rows).
Uint8List buildPerformanceXlsx(Map<String,dynamic> report,List<Map<String,dynamic>> transactions){
 final f=Map<String,dynamic>.from(report['filters'] as Map);
 final metric=Map<String,dynamic>.from(report['metric'] as Map);
 final groups=(report['rows'] as List).map((x)=>Map<String,dynamic>.from(x as Map)).toList();
 final summary=<List<Object?>>[
  ['FIELD WORK — BÁO CÁO KINH DOANH'],
  ['Kỳ',_period(f)],['Nhóm',f['group']],['Nhân viên',f['owner']],['Tỉnh',f['province']],
  ['Khách hàng',f['customer']],['Mã CTY',f['product']],
  ['Chỉ tiêu so sánh',report['target_note']],['Target (VNĐ)',_integer(metric['target'])],
  ['Doanh số thực tế (VNĐ)',_integer(metric['actual'])],
  ['Số dòng chứng từ',_integer(metric['records'])],
  ['Số lượng',_integer(metric['quantity'])],
  ['Còn thiếu (VNĐ)',_integer(metric['remaining'])],
  ['Hoàn thành (%)',metric['progress_percent']??'Chưa xác định'],
  ['Nguồn số liệu','Chỉ doanh số thực tế đã ghi, chưa hủy. Không gồm dự kiến hoặc đơn nháp.'],
  ['Quy tắc','Target nhân viên, Target khách và Target SKU là các chiều riêng; không cộng các chiều.'],
 ];
 final groupRows=<List<Object?>>[
  ['Mã','Tên nhóm','Số dòng','Số lượng','Target (VNĐ)','Doanh số (VNĐ)','Còn thiếu (VNĐ)','Hoàn thành (%)'],
  for(final r in groups)[r['code']??'',r['label']??'',_integer(r['records']),_integer(r['quantity']),
   _integer(r['target']),_integer(r['actual']),_integer(r['remaining']),r['progress_percent']??'—'],
 ];
 final detail=<List<Object?>>[
  ['Ngày','Mã nhân viên','Nhân viên','Mã khách','Khách hàng','Tỉnh','Huyện',
   'Mã CTY','Sản phẩm','Số lượng','Doanh số (VNĐ)','Nguồn','Chứng từ','Mã dòng'],
  for(final r in transactions)[r['sale_date'],r['employee_code'],r['employee_name'],
   r['customer_code'],r['customer_name'],r['province'],r['district'],r['company_code'],
   r['product_name'],_integer(r['quantity']),_integer(r['amount']),r['source'],
   r['external_ref'],r['line_ref']],
 ];
 final files=<String,String>{
  '[Content_Types].xml':'<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
    '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
    '<Default Extension="xml" ContentType="application/xml"/>'
    '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
    '<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'
    '<Override PartName="/xl/worksheets/sheet2.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'
    '<Override PartName="/xl/worksheets/sheet3.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'
    '</Types>',
  '_rels/.rels':'<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
    '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>'
    '</Relationships>',
  'xl/workbook.xml':'<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
    '<sheets><sheet name="Tổng quan" sheetId="1" r:id="rId1"/>'
    '<sheet name="Theo nhóm" sheetId="2" r:id="rId2"/>'
    '<sheet name="Chi tiết" sheetId="3" r:id="rId3"/></sheets></workbook>',
  'xl/_rels/workbook.xml.rels':'<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
    '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>'
    '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet2.xml"/>'
    '<Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet3.xml"/>'
    '</Relationships>',
  'xl/worksheets/sheet1.xml':_sheet(summary),
  'xl/worksheets/sheet2.xml':_sheet(groupRows),
  'xl/worksheets/sheet3.xml':_sheet(detail)
 };
 final archive=Archive();
 for(final e in files.entries){final bytes=utf8.encode(e.value);archive.addFile(ArchiveFile(e.key,bytes.length,bytes));}
 return Uint8List.fromList(ZipEncoder().encode(archive));
}
