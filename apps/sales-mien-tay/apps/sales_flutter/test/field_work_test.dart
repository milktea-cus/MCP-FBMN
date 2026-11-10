import 'package:flutter_test/flutter_test.dart';
import 'package:sales_mien_tay/field_work.dart';
void main(){
 test('calendar and report formatting',(){
  expect(dayKey(DateTime(2026,1,2)),'2026-01-02');
  expect(monthKey(DateTime(2026,1,2)),'2026-01');
  expect(dayKey(weekMonday(DateTime(2026,1,1))),'2025-12-29');
  expect(dayKey(weekMonday(DateTime(2026,11,15))),'2026-11-09');
  expect(money('1200000'),'1.200.000 đ');
 });
}
