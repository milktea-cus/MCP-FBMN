import 'package:flutter_test/flutter_test.dart';
import 'package:sales_mien_tay/actuals_parser.dart';
import 'package:sales_mien_tay/xlsx_reader.dart';
void main(){
 XlsxSheet sheet(List<List<XlsxCell?>> values)=>XlsxSheet(values);
 XlsxCell t(String s)=>XlsxCell(s,'text');
 XlsxCell n(String s)=>XlsxCell(s,'number');
 final mapping={0:'sale_date',1:'employee_code',2:'customer_code',3:'company_code',4:'quantity',5:'amount',6:'external_ref'};
 test('Excel actual mapping preserves text codes, converts dates, stable row key, and zero revenue',(){
  final r=parseActualSheet(sheet([[t('Ngày'),t('Nhân viên'),t('Khách'),t('SP'),t('SL'),t('VNĐ'),t('Giao dịch')],
    [t('11/11/2026'),t('0009'),t('KH0003'),t('000123'),n('3'),t('1.200.000'),t('INV001')],
    [n('46337'),t('0009'),t('KH0003'),t('000124'),n('1'),n('0'),t('INV001')]]),0,mapping);
  expect(r.errors,isEmpty);expect(r.rows.length,2);
  expect(r.rows.first['company_code'],'000123');
  expect(r.rows.first['sale_date'],'2026-11-11');
  expect(r.rows.first['amount'],1200000);
  expect(r.rows.last['amount'],0);
  expect(r.rows.first['line_ref'],'000123');
 });
 test('reject duplicate lines, numeric codes, invalid dates and fractional money',(){
  final r=parseActualSheet(sheet([[for(var i=0;i<7;i++)t('$i')],
   [t('31/02/2026'),t('A'),t('C'),t('P'),n('1'),n('20'),t('TX')],
   [t('11/11/2026'),t('A'),t('C'),n('123'),n('1'),n('20'),t('TX')],
   [t('11/11/2026'),t('A'),t('C'),t('P'),n('2'),n('2.5'),t('TX')],
   [t('11/11/2026'),t('A'),t('C'),t('P'),n('2'),n('20'),t('TX')],
   [t('11/11/2026'),t('A'),t('C'),t('P'),n('2'),n('20'),t('TX')]]),0,mapping);
  expect(r.rows,hasLength(1));expect(r.errors.length,4);
 });
 test('cannot map the same field to two Excel columns',(){
  final r=parseActualSheet(sheet([[t('x')]]),0,{...mapping,7:'amount'});
  expect(r.errors.single,contains('không chọn trùng'));
 });
}
