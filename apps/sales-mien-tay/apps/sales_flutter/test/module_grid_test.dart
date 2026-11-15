import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sales_mien_tay/main.dart';

void main() {
  const names = [
    'Tổng quan','Khách hàng / Điểm bán','Khảo sát','Target','Dự kiến',
    'Lịch trình','Hỗ trợ','Chính sách','Yêu cầu','Báo cáo tháng',
    'Danh mục SKU','Tra tồn','Ra đơn',
  ];
  for (final width in [320.0, 360.0, 390.0, 430.0, 780.0, 1280.0, 1440.0]) {
    testWidgets('all 12 shortcuts fit and navigate at $width', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 900);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final selected = <int>[];
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(
        child: Padding(padding: const EdgeInsets.all(18),
          child: SalesModuleGrid(sections: names,
            icons: List.filled(names.length, Icons.grid_view_outlined),
            onSelect: selected.add)),
      ))));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(InkWell), findsNWidgets(12));
      final delegate = tester.widget<GridView>(find.byType(GridView)).gridDelegate
        as SliverGridDelegateWithFixedCrossAxisCount;
      expect(delegate.crossAxisCount,
        width < 378 ? 3 : width < 1018 ? 4 : 6);
      expect(find.descendant(of:find.byType(SalesModuleGrid),
        matching:find.byType(Card)),findsNothing,
        reason:'Module shortcuts are bare icon+label, not individual cards');
      for(final surface in tester.widgetList<InkWell>(
         find.descendant(of:find.byType(SalesModuleGrid),
          matching:find.byType(InkWell)))){
        expect(surface.onTap,isNotNull);
      }
      final tile=tester.getSize(find.byKey(const ValueKey('module-grid-1')));
      expect(tile.width,greaterThanOrEqualTo(48));
      expect(tile.height,greaterThanOrEqualTo(48));
      await tester.ensureVisible(find.byKey(const ValueKey('module-grid-12')));
      await tester.tap(find.byKey(const ValueKey('module-grid-12')));
      expect(selected, [12]);
      expect(tester.takeException(), isNull);
    });
  }
  for(final brightness in [Brightness.light,Brightness.dark]){
    testWidgets('P1-O text scaling 1.4, focus and semantics $brightness',
      (tester)async{
      tester.view.devicePixelRatio=1;
      tester.view.physicalSize=const Size(320,800);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final selected=<int>[];
      await tester.pumpWidget(MaterialApp(
        theme:ThemeData(brightness:brightness),
        home:MediaQuery(data:const MediaQueryData(textScaler:TextScaler.linear(1.4)),
         child:Scaffold(body:SingleChildScrollView(child:Padding(
          padding:const EdgeInsets.all(18),child:SalesModuleGrid(
           sections:names,icons:List.filled(names.length,Icons.apps),
           onSelect:selected.add)))))));
      await tester.pumpAndSettle();
      expect(tester.takeException(),isNull);
      expect(find.descendant(of:find.byType(SalesModuleGrid),
       matching:find.byType(Card)),findsNothing);
      final node=find.byKey(const ValueKey('module-grid-5'));
      await tester.ensureVisible(node);
      await tester.tap(node);
      expect(selected,[5]);
      expect(tester.takeException(),isNull);
    });
  }
  testWidgets('Sales only sees Cong tac; independent survey is not a shortcut',(tester) async {
    final names=[
      'Tổng quan','Khách hàng / Điểm bán','Quản trị khảo sát',
      'Target','Dự kiến','Công tác','Hỗ trợ','Chính sách','Yêu cầu',
      'Báo cáo tháng','Danh mục SKU','Tra tồn','Ra đơn',
    ];
    final picked=<int>[];
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:SingleChildScrollView(
      child:SalesModuleGrid(sections:names,
       icons:List.filled(names.length,Icons.dashboard_outlined),
       hiddenIndices:const {2},onSelect:picked.add)))));
    expect(find.text('Công tác'),findsOneWidget);
    expect(find.text('Quản trị khảo sát'),findsNothing);
    await tester.ensureVisible(find.byKey(const ValueKey('module-grid-5')));
    await tester.tap(find.byKey(const ValueKey('module-grid-5')));
    expect(picked,[5]);
  });

}
