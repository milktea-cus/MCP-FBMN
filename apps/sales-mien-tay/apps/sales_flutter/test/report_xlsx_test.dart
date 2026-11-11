import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sales_mien_tay/report_xlsx.dart';
void main(){
 test('XLSX report has 3 sheets, numeric measures, and safe escaped labels',(){
  final doc={'filters':{'year':2026,'month':11,'quarter':4,'period':'month','group':'customer','owner':'one','province':'','customer':'','product':''},
  'metric':{'target':'1000000','actual':'600000','records':2,'quantity':'3','remaining':'400000','progress_percent':60.0},
  'target_note':'Chỉ phân bổ khách hàng', 'rows':[{'code':'0001','label':'=HYPERLINK("x") & <store>',
    'records':2,'quantity':'3','target':'1000000','actual':'600000','remaining':'400000','progress_percent':60.0}]};
  final bytes=buildPerformanceXlsx(doc,[{'sale_date':'2026-11-11','employee_code':'0003','employee_name':'A',
  'customer_code':'0001','customer_name':'Tên <Khách>','province':'Tỉnh','district':'Huyện',
  'company_code':'000123','product_name':'+SUM(1,2)','quantity':3,'amount':'600000','source':'company','external_ref':'INV','line_ref':'001'}]);
  final files={for(final f in ZipDecoder().decodeBytes(bytes).files)f.name:utf8.decode(f.content)};
  expect(files.keys,containsAll(['xl/workbook.xml','xl/worksheets/sheet1.xml','xl/worksheets/sheet2.xml','xl/worksheets/sheet3.xml']));
  expect(files['xl/workbook.xml'],contains('Theo nhóm'));
  expect(files['xl/worksheets/sheet1.xml'],contains('Doanh số thực tế'));
  expect(files['xl/worksheets/sheet2.xml'],contains('&lt;store&gt;'));
  expect(files['xl/worksheets/sheet2.xml'],contains('<v>600000</v>'));
  expect(files['xl/worksheets/sheet3.xml'],contains('000123'));
  expect(files['xl/worksheets/sheet2.xml'],isNot(contains('<f>')));
  expect(files['xl/worksheets/sheet3.xml'],isNot(contains('<f>')));
 });
}
