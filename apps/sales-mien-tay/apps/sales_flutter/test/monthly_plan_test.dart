import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sales_mien_tay/planning_periods.dart';
import 'package:sales_mien_tay/monthly_plan.dart';

void main() {
 test('empty area/chain schedules contain no fake stops',(){
  expect(plannedCustomerStops([]),isEmpty);
  final stops=plannedCustomerStops(['a','b']);
  expect(stops.length,2);
  expect(stops.every((s)=>s['stop_kind']=='customer'),true);
  expect(stops.map((s)=>s['sequence']).toList(),[1,2]);
 });

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

 testWidgets('P0-2A keeps period dropdown beside Add on 320dp mobile', (tester) async {
  tester.view.physicalSize=const Size(320,700);
  tester.view.devicePixelRatio=1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  var selected=0,added=false;
  await tester.pumpWidget(MaterialApp(home:Scaffold(body:Padding(
   padding:const EdgeInsets.all(12),
   child:StatefulBuilder(builder:(context,update)=>MonthlyPeriodActions(
    month:DateTime(2026,11),period:selected,canAdd:true,
    onPeriodChanged:(p)=>update(()=>selected=p),
    onAdd:()=>added=true,
   )),
  ))));
  expect(find.text('Thêm công tác'),findsOneWidget);
  expect(find.byType(DropdownButtonFormField<int>),findsOneWidget);
  expect(tester.takeException(),isNull);
  await tester.tap(find.text('Tất cả'));await tester.pumpAndSettle();
  await tester.tap(find.text('Kỳ 3').last);await tester.pumpAndSettle();
  expect(selected,3);
  await tester.tap(find.text('Thêm công tác'));
  expect(added,isTrue);
  final menu=tester.getTopLeft(find.byType(DropdownButtonFormField<int>));
  final action=tester.getTopLeft(find.text('Thêm công tác'));
  expect(menu.dx,lessThan(action.dx));
  expect((menu.dy-action.dy).abs(),lessThan(36));
 });
 testWidgets('P0-2A omits empty fifth period in February', (tester) async {
  await tester.pumpWidget(MaterialApp(home:Scaffold(body:MonthlyPeriodActions(
   month:DateTime(2025,2),period:0,canAdd:false,
   onPeriodChanged:(_){},onAdd:(){},
  ))));
  await tester.tap(find.text('Tất cả'));await tester.pumpAndSettle();
  expect(find.text('Kỳ 4'),findsOneWidget);
  expect(find.text('Kỳ 5'),findsNothing);
 });

 testWidgets('editor selects multiple business scopes without existing customers', (tester) async {
  tester.view.physicalSize=const Size(1000,1600);tester.view.devicePixelRatio=1;
  addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
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
  expect(find.text('Đã chọn 0 · 2 phạm vi'),findsOneWidget);
  await tester.ensureVisible(find.byType(CheckboxListTile).at(0));
  await tester.pumpAndSettle();
  await tester.tap(find.byType(CheckboxListTile).at(0));await tester.pumpAndSettle();
  await tester.ensureVisible(find.byType(CheckboxListTile).at(1));
  await tester.pumpAndSettle();
  await tester.tap(find.byType(CheckboxListTile).at(1));await tester.pumpAndSettle();
  expect(find.text('Đã chọn 2 · 2 phạm vi'),findsOneWidget);
  await tester.enterText(find.byType(TextField).first,'Đi tìm điểm bán mới');
  await tester.ensureVisible(find.text('Lưu lịch + tuyến (2)'));
  await tester.tap(find.text('Lưu lịch + tuyến (2)'));
  await tester.pumpAndSettle();
  expect(selection,isNotNull);
  expect(selection!.scopes.length,2);
  expect(selection!.purpose,'Đi tìm điểm bán mới');
  expect(selection!.date,DateTime(2026,11,1));
 });
}
