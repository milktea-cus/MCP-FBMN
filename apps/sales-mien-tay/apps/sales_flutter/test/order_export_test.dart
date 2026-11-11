import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sales_mien_tay/order_export.dart';
void main(){
 test('safe preparation xlsx has text codes, integer quantity and no price or formula',(){
  final bytes=buildOrderPreparationXlsx({'id':'abc','status':'exported','customer_code':'0001','customer_name':'Đại lý',
   'note':'=1+2','lines':[{'company_code':'00123','unit':'Thùng','quantity':'5'}]});
  final files={for(final f in ZipDecoder().decodeBytes(bytes).files)f.name:utf8.decode(f.content)};
  final xml=files['xl/worksheets/sheet1.xml']!;
  expect(xml,contains('0001'));expect(xml,contains('00123'));
  expect(xml,contains('<v>5</v>'));expect(xml,contains('=1+2'));
  expect(xml, isNot(contains('<f>')));expect(xml,isNot(contains('Đơn giá')));
  expect(files['xl/worksheets/sheet2.xml'],contains('CHƯA ĐƯỢC ĐỐI CHIẾU'));
 });
 test('reject draft/empty cart but allow Sales request without ERP company mapping',(){
  expect(()=>buildOrderPreparationXlsx({'status':'draft','customer_code':'1','lines':[]}),throwsStateError);
  expect(()=>buildOrderPreparationXlsx({'status':'exported','customer_code':'','lines':[]}),throwsStateError);
  final data=buildOrderPreparationXlsx({
   'id':'fb-order','status':'exported','customer_field_code':'TGMT01',
   'customer_code':'','customer_name':'Nhà sách Minh Tâm',
   'lines':[{'company_code':'000999','unit':'Hộp','quantity':3}],
  });
  final files={for(final f in ZipDecoder().decodeBytes(data).files)f.name:utf8.decode(f.content)};
  expect(files['xl/worksheets/sheet1.xml'],contains('000999'));
  expect(files['xl/worksheets/sheet2.xml'],contains('TGMT01'));
  expect(files['xl/worksheets/sheet2.xml'],contains('CHƯA ÁNH XẠ'));
  expect(files['xl/worksheets/sheet2.xml'],contains('không kiểm tồn'));
 });
}
