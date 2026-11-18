import 'package:flutter_test/flutter_test.dart';
import 'package:sales_mien_tay/local_routes.dart';
void main(){
 final one=<String,dynamic>{
  'id':'ee0c7a07-f070-4e8c-a8a8-e9e1c631b2fb',
  'mode':'day','weekdays':[1],'active':true,'start_on':'2026-11-16'};
 test('single weekday repeats every week, not on another day',(){
  expect(localRuleOccurs(one,DateTime(2026,11,16)),isTrue);
  expect(localRuleOccurs(one,DateTime(2026,11,23)),isTrue);
  expect(localRuleOccurs(one,DateTime(2026,11,17)),isFalse);
  expect(localRuleOccurs(one,DateTime(2026,11,9)),isFalse);
 });
 test('weekly rule repeats across months; pause stops future dates',(){
  final r={...one,'mode':'week','weekdays':[2,4,6]};
  expect(localRuleOccurs(r,DateTime(2026,12,1)),isTrue);
  expect(localRuleOccurs(r,DateTime(2026,12,3)),isTrue);
  expect(localRuleOccurs(r,DateTime(2026,12,6)),isFalse);
  expect(localRuleOccurs({...r,'active':false},DateTime(2026,12,1)),isFalse);
 });
 test('one occurrence has stable unique plan, route and trip IDs',(){
  final id=one['id'].toString(),day=DateTime(2026,11,23);
  final plan=localOccurrenceId(id,day,'plan');
  expect(localOccurrenceId(id,day,'plan'),plan);
  expect(localOccurrenceId(id,day,'route'),isNot(plan));
  expect(localOccurrenceId(id,day,'trip'),isNot(plan));
  expect(localOccurrenceId(id,DateTime(2026,11,30),'plan'),isNot(plan));
 });
}
