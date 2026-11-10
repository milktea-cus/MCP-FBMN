import 'package:flutter_test/flutter_test.dart';
import 'package:sales_mien_tay/field_work.dart';
void main(){
 test('five planning periods cover all dates, including six-calendar-week months',(){
  for(var year=2024;year<=2028;year++){for(var month=1;month<=12;month++){
   final d=DateTime(year,month);
   final days=[for(var p=1;p<=5;p++)...periodDays(d,p)];
   expect(days.length,monthEnd(d).day);
   expect(days.map(dayKey).toSet().length,days.length);
   for(var i=0;i<days.length;i++){expect(days[i].day,i+1);expect(planningPeriod(days[i]),((i)~/7)+1);}
  }}
  expect(periodDays(DateTime(2026,2),5),isEmpty);
  expect(periodDays(DateTime(2024,2),5).length,1);
  expect(periodDays(DateTime(2026,8),5).length,3);
 });
 test('calendar and report formatting',(){
  expect(dayKey(DateTime(2026,1,2)),'2026-01-02');
  expect(monthKey(DateTime(2026,1,2)),'2026-01');
  expect(dayKey(weekMonday(DateTime(2026,1,1))),'2025-12-29');
  expect(dayKey(weekMonday(DateTime(2026,11,15))),'2026-11-09');
  expect(money('1200000'),'1.200.000 đ');
 });
}
