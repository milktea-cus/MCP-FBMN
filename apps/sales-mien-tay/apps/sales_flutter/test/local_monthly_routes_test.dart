import 'package:flutter_test/flutter_test.dart';
import 'package:sales_mien_tay/local_monthly_core.dart';
import 'package:sales_mien_tay/planning_periods.dart';

void main(){
 test('monthly weeks follow existing five planning periods',(){
  final month=DateTime(2026,11);
  expect(fixedMonthDays(month,1).map(dayKey).toList(),
   ['2026-11-01','2026-11-02','2026-11-03','2026-11-04',
    '2026-11-05','2026-11-06','2026-11-07']);
  expect(dayKey(fixedMonthDays(month,2).first),'2026-11-08');
  expect(dayKey(fixedMonthDays(month,4).last),'2026-11-28');
  expect(fixedMonthDays(month,5).map(dayKey).toList(),
   ['2026-11-29','2026-11-30']);
  expect(fixedMonthDays(DateTime(2027,2),5),isEmpty);
  expect(fixedMonthDays(DateTime(2028,2),5).map(dayKey).toList(),
   ['2028-02-29']);
 });
 test('scope recurs in the same month week independent of weekday',(){
  final r=<String,dynamic>{'week_no':2,'active':true};
  expect(fixedMonthMatches(r,DateTime(2026,11,8)),isTrue);
  expect(fixedMonthMatches(r,DateTime(2026,11,14)),isTrue);
  expect(fixedMonthMatches(r,DateTime(2026,12,8)),isTrue);
  expect(fixedMonthMatches(r,DateTime(2026,12,15)),isFalse);
  expect(fixedMonthMatches({...r,'active':false},DateTime(2026,12,8)),isFalse);
 });
 test('occurrence identifiers stable and distinct by actual date and stage',(){
  const id='ee0c7a07-f070-4e8c-a8a8-e9e1c631b2fb';
  final a=DateTime(2026,11,8),b=DateTime(2026,11,12);
  expect(fixedMonthId(id,a,'plan'),fixedMonthId(id,a,'plan'));
  expect(fixedMonthId(id,a,'plan'),isNot(fixedMonthId(id,b,'plan')));
  expect(fixedMonthId(id,a,'plan'),isNot(fixedMonthId(id,a,'route')));
  expect(fixedMonthId(id,a,'route'),isNot(fixedMonthId(id,a,'trip')));
 });
}
