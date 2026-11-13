import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sales_mien_tay/planning_periods.dart';
import 'package:sales_mien_tay/monthly_plan.dart';

void main() {
 test('monthly period buttons match calendar dates; period five hidden for 28 days', () {
  for(final year in [2024,2025,2026,2028]){
   for(var month=1;month<=12;month++){
    final reference=DateTime(year,month);
    final daysInMonth=monthEnd(reference).day;
    final periods=[for(var k=1;k<=5;k++)periodDays(reference,k)];
    expect(periods.expand((days)=>days).length,daysInMonth);
    final flattened=[for(final list in periods)...list];
    expect(flattened.map(dayKey).toSet().length,daysInMonth);
    expect(periods[0].first.day,1);
    expect(periods[0].last.day,7);
    expect(periods[3].first.day,22);
    expect(periods[3].last.day,28);
    expect(periods[4].length,daysInMonth-28);
    if(daysInMonth==28)expect(periods[4],isEmpty);
   }
  }
 });
 testWidgets('editor selects multiple business scopes without existing customers', (tester) async {
  final month=DateTime(2026,11);
  const areas=[
   {'scope_kind':'territory','scope_key':'An Giang|','province':'An Giang','district':'','label':'Toàn tỉnh · An Giang'},
   {'scope_kind':'territory','scope_key':'Kiên Giang|','province':'Kiên Giang','district':'','label':'Toàn tỉnh · Kiên Giang'},
   {'scope_kind':'chain','scope_key':'12345678-1234-4123-8123-123456789abc','province':null,'district':null,'label':'Chuỗi · Nhà sách'}
  ];
  MonthlyPlanSelection? selection;
  await tester.pumpWidget(MaterialApp(home:Builder(builder:(context)=>Scaffold(
   body:TextButton(onPressed:()async{
    selection=await Navigator.push<MonthlyPlanSelection>(context,MaterialPageRoute(
     builder:(_)=>MonthlyPlanEditor(month:month,scopes:areas)));
   },child:const Text('Start'))))));
  await tester.tap(find.text('Start'));await tester.pumpAndSettle();
  expect(find.text('Đã chọn 0 · 3 phạm vi'),findsOneWidget);
  await tester.tap(find.byType(CheckboxListTile).at(0));await tester.pump();
  await tester.tap(find.byType(CheckboxListTile).at(1));await tester.pump();
  expect(find.text('Đã chọn 2 · 3 phạm vi'),findsOneWidget);
  await tester.enterText(find.byType(TextField).first,'Đi tìm điểm bán mới');
  await tester.ensureVisible(find.text('Lưu 2 công việc'));
  await tester.tap(find.text('Lưu 2 công việc'));
  await tester.pumpAndSettle();
  expect(selection,isNotNull);
  expect(selection!.scopes.length,2);
  expect(selection!.purpose,'Đi tìm điểm bán mới');
  expect(selection!.date,DateTime(2026,11,1));
 });
}
