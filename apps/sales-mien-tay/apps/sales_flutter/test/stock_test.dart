import 'package:flutter_test/flutter_test.dart';
import 'package:sales_mien_tay/stock.dart';
void main(){
 test('zero is not missing, bigint text and search preserve leading zeros',(){
  expect(stockStatus({'quantity':'0'}),'Hết tồn');expect(stockStatus({'quantity':null}),'Chưa cập nhật');expect(stockStatus({'quantity':'9'}),'Có tồn');
  expect(stockQuantityLabel({'quantity':0}),'0');expect(stockQuantityLabel({}),'—');
  expect(stockMatches({'company_code':'000123'},'000123'),true);expect(stockMatches({'name':'Bút bi'},'BÚT'),true);
  expect(stockIsStale('2026-11-10T00:00:00Z',DateTime.utc(2026,11,11)),true);
  expect(stockTime('2026-11-10T18:00:00Z'),'11/11/2026 01:00 (VN)');
 });
}
