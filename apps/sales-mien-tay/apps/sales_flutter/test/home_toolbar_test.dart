import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/main.dart';
import '../lib/theme.dart';

void main(){
  for(final width in [320.0,360.0,390.0,768.0]){
    testWidgets('compact toolbar fits $width with drawer and admin actions',(tester)async{
      tester.view.devicePixelRatio=1;
      tester.view.physicalSize=Size(width,800);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final calls=<String>[];
      await tester.pumpWidget(MaterialApp(theme:SalesTheme.build(width:width),home:Scaffold(
        drawer:const Drawer(),
        appBar:SalesHomeBar(compact:true,loading:false,admin:true,
          onStock:()=>calls.add('stock'),onCatalog:()=>calls.add('catalog'),
          onRefresh:()=>calls.add('refresh'),onStaff:()=>calls.add('staff'),onProfile:()=>calls.add('profile')),
      )));
      expect(tester.takeException(),isNull);
      expect(find.text('Filed Work'),findsOneWidget);
      expect(find.byTooltip('Tra tồn'),findsOneWidget);
      expect(find.byTooltip('Thêm thao tác'),findsOneWidget);
      expect(find.byTooltip('Danh mục SKU'),findsNothing);
      final title=tester.getRect(find.text('Filed Work'));
      expect(title.left,greaterThanOrEqualTo(56));
      expect(title.right,lessThanOrEqualTo(tester.getRect(find.byTooltip('Tra tồn')).left));
      await tester.tap(find.byTooltip('Tra tồn'));
      expect(calls,['stock']);
      await tester.tap(find.byTooltip('Thêm thao tác'));
      await tester.pumpAndSettle();
      expect(find.text('Danh mục sản phẩm'),findsOneWidget);
      expect(find.text('Quản lý nhân viên'),findsOneWidget);
      await tester.tap(find.text('Danh mục sản phẩm'));
      await tester.pumpAndSettle();
      expect(calls,['stock','catalog']);
      expect(tester.takeException(),isNull);
    });
  }
  testWidgets('sales menu hides staff management and loading disables refresh',(tester)async{
    tester.view.devicePixelRatio=1;
    tester.view.physicalSize=const Size(360,800);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home:Scaffold(drawer:const Drawer(),
      appBar:SalesHomeBar(compact:true,loading:true,admin:false,
        onStock:(){},onCatalog:(){},onRefresh:(){},onStaff:(){},onProfile:(){}))));
    expect(find.byType(LinearProgressIndicator),findsOneWidget);
    await tester.tap(find.byTooltip('Thêm thao tác'));
    await tester.pump(const Duration(milliseconds:350));
    expect(find.text('Quản lý nhân viên'),findsNothing);
    final items=tester.widgetList<PopupMenuItem>(find.byWidgetPredicate((w)=>w is PopupMenuItem));
    expect(items.where((w)=>!w.enabled).length,1);
    expect(tester.takeException(),isNull);
  });
}
