import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sales_mien_tay/main.dart';

void main(){
  Widget shell({VoidCallback? update})=>MaterialApp(home:Scaffold(
    appBar:AppBar(title:const Text('Field Work')),
    drawer:SalesHomeDrawer(
      admin:false,loading:false,selectedIndex:0,
      sections:const ['Tổng quan'],icons:const [Icons.home_outlined],
      onSection:(_){},onRefresh:(){},onStaff:(){},onProfile:(){},
      onUpdate:update,
    ),
    body:const Text('Trang chính'),
  ));

  for(final width in [360.0,390.0,430.0]){
    testWidgets('P0-I update drawer action at ${width.toInt()}dp', (tester)async{
      tester.view.physicalSize=Size(width,844);
      tester.view.devicePixelRatio=1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var opened=0;
      await tester.pumpWidget(shell(update:()=>opened++));
      tester.state<ScaffoldState>(find.byType(Scaffold)).openDrawer();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('android-update-menu')),findsOneWidget);
      await tester.tap(find.byKey(const Key('android-update-menu')));
      await tester.pumpAndSettle();
      expect(opened,1);
      expect(tester.takeException(),isNull);
    });
  }

  testWidgets('PWA drawer with no native callback hides APK update', (tester)async{
    await tester.pumpWidget(shell());
    tester.state<ScaffoldState>(find.byType(Scaffold)).openDrawer();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('android-update-menu')),findsNothing);
    expect(find.text('Cập nhật ứng dụng'),findsNothing);
    expect(tester.takeException(),isNull);
  });
}
