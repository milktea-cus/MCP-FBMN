import 'package:flutter_test/flutter_test.dart';
import 'package:sales_mien_tay/inventory_import.dart';
import 'package:sales_mien_tay/xlsx_reader.dart';
void main(){
 test('mapped columns preserve blanks and leading zero',(){
  const s=XlsxSheet([[XlsxCell('Mã','text'),XlsxCell('Tên','text'),XlsxCell('ĐVT','text')],[XlsxCell('001','text'),XlsxCell('Tên mới','text'),null]]);
  final result=parseCatalogImport(s,0,{0:'company_code',1:'name',2:'unit'});
  expect(result.errors,isEmpty);expect(result.rows.single['company_code'],'001');expect(result.rows.single['patch'],{'name':'Tên mới'});
  expect(parseCatalogImport(s,0,{0:'company_code',1:'name',2:'name'}).errors,isNotEmpty);
 });
}
