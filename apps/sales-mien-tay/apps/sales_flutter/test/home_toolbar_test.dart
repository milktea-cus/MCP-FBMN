import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/main.dart';
import '../lib/theme.dart';

void main(){
  const sections=['Tổng quan','Khách hàng','Khảo sát','Target','Dự kiến','Lịch trình','Hỗ trợ','Chính sách','Yêu cầu','Báo cáo','Danh mục SKU','Tra tồn','Ra đơn'];
  Widget shell({required bool admin,required bool loading,required List<String> calls})=>MaterialApp(
    theme:SalesTheme.build(),home:Scaffold(
      appBar:SalesHomeBar(loading:loading,onNotifications:()=>calls.add('bell')),
      drawer:SalesHomeDrawer(admin:admin,loading:loading,selectedIndex:0,sections:sections,
        icons:List.filled(sections.length,Icons.dashboard_outlined),
        onSection:(i)=>calls.add('section:$i'),onRefresh:()=>calls.add('refresh'),
        onStaff:()=>calls.add('staff'),onProfile:()=>calls.add('profile')),
      body:const SizedBox.expand(),
    ));
  for(final width in [320.0,360.0,390.0,768.0,1280.0]){
    testWidgets('logo and one notification action fit $width',(tester)async{
      tester.view.devicePixelRatio=1;tester.view.physicalSize=Size(width,800);
      addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
      final calls=<String>[];
      await tester.pumpWidget(shell(admin:true,loading:false,calls:calls));
      await tester.pumpAndSettle();
      expect(tester.takeException(),isNull);
      expect(find.byType(Image),findsOneWidget);
      expect(find.text('Field Work'),findsOneWidget);
      expect(find.byTooltip('Thông báo'),findsOneWidget);
      final bar=tester.widget<AppBar>(find.byType(AppBar));
      expect(bar.actions!.length,1);
      expect(tester.getRect(find.byType(Image)).right,lessThanOrEqualTo(tester.getRect(find.text('Field Work')).left));
      expect(tester.getRect(find.text('Field Work')).right,lessThanOrEqualTo(tester.getRect(find.byTooltip('Thông báo')).left));
      await tester.tap(find.byTooltip('Thông báo'));expect(calls,['bell']);
      await tester.tap(find.byTooltip('Open navigation menu'));await tester.pumpAndSettle();
      expect(find.text('Quản lý nhân viên'),findsOneWidget);
      expect(find.text('Tra tồn'),findsOneWidget);
      expect(find.text('Danh mục SKU'),findsOneWidget);
      expect(find.text('Ra đơn'),findsOneWidget);
      await tester.tap(find.text('Quản lý nhân viên'));await tester.pumpAndSettle();
      expect(calls,['bell','staff']);expect(find.text('Quản lý nhân viên'),findsNothing);
      expect(tester.takeException(),isNull);
    });
  }
  testWidgets('sales cannot see staff; drawer retains stock and profile; loading disables refresh',(tester)async{
    final calls=<String>[];
    await tester.pumpWidget(shell(admin:false,loading:true,calls:calls));
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pump(); // Start the drawer animation before advancing its clock.
    await tester.pump(const Duration(milliseconds:350));
    expect(find.text('Quản lý nhân viên'),findsNothing);
    expect(find.text('Hồ sơ / Đăng xuất'),findsOneWidget);
    final refresh=tester.widget<ListTile>(find.ancestor(of:find.text('Tải lại dữ liệu'),matching:find.byType(ListTile)));
    expect(refresh.enabled,isFalse);
    expect(find.text('Tra tồn').hitTestable(),findsOneWidget);
    await tester.tap(find.text('Tra tồn'));await tester.pump();await tester.pump(const Duration(milliseconds:350));
    expect(calls,['section:11']);
  });
}
