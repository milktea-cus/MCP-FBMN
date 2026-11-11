import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/main.dart';
import '../lib/theme.dart';
import '../lib/notifications.dart';
import '../lib/session.dart';
import '../lib/offline_queue.dart';

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
  testWidgets('red unread badge uses one header action and caps at 99',(tester)async{
    await tester.pumpWidget(MaterialApp(home:Scaffold(
      appBar:SalesHomeBar(loading:false,unreadCount:12,onNotifications:(){}),
      body:const SizedBox.expand())));
    expect(find.byType(Badge),findsOneWidget);
    expect(find.text('12'),findsOneWidget);
    expect(tester.widget<AppBar>(find.byType(AppBar)).actions!.length,1);
    await tester.pumpWidget(MaterialApp(home:Scaffold(
      appBar:SalesHomeBar(loading:false,unreadCount:120,onNotifications:(){}))));
    expect(find.text('99'),findsOneWidget);
    await tester.pumpWidget(MaterialApp(home:Scaffold(
      appBar:SalesHomeBar(loading:false,unreadCount:0,onNotifications:(){}))));
    expect(find.byType(Badge),findsNothing);
  });
  testWidgets('notification updates never rebuild the active business screen',
    (tester)async{
    final session=SalesSession();
    final queue=OfflineQueue(session,'seller-a','scope-1');
    final notifications=FieldNotificationStore(session,queue);
    var contentBuilds=0;
    var opens=0;
    await tester.pumpWidget(MaterialApp(home:Scaffold(
      appBar:SalesLiveHomeBar(
        store:notifications,loading:false,
        onNotifications:()=>opens++,
      ),
      body:Builder(builder:(context){
        contentBuilds++;
        return const Center(child:Text('Giỏ và biểu mẫu đang mở'));
      }),
    )));
    expect(contentBuilds,1);
    notifications.items=[FieldNotification(
      'notice-1','Thông báo mới','Đã đồng bộ',DateTime(2026,11,11),null)];
    notifications.changed();
    await tester.pump();
    expect(contentBuilds,1,reason:
      'Chuông cập nhật không được dựng lại biểu mẫu đang thao tác');
    expect(find.text('1'),findsOneWidget);
    await tester.tap(find.byTooltip('Thông báo'));
    expect(opens,1);
    notifications.items=[];
    notifications.changed();
    await tester.pump();
    expect(contentBuilds,1);
    expect(find.byType(Badge),findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    notifications.dispose();queue.dispose();
  });

  testWidgets('drawer dark mode toggle stays independent of bottom navigation',(tester)async{
    final calls=<String>[];
    await tester.pumpWidget(MaterialApp(theme:SalesTheme.build(),
      home:Scaffold(appBar:SalesHomeBar(loading:false,onNotifications:(){}),
        drawer:SalesHomeDrawer(admin:true,loading:false,selectedIndex:0,
          sections:sections,icons:List.filled(sections.length,Icons.dashboard_outlined),
          onSection:(_){},onRefresh:(){},onStaff:(){},onProfile:(){},
          themeMode:ThemeMode.light,onThemeModeChanged:(value)=>calls.add(value.name)),
        body:const SizedBox.expand())));
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    expect(find.text('Quản lý nhân viên'),findsOneWidget);
    expect(find.text('Hồ sơ / Đăng xuất'),findsOneWidget);
    await tester.tap(find.text('Chế độ tối'));
    expect(calls,['dark']);
    expect(tester.takeException(),isNull);
  });
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
