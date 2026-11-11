import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sales_mien_tay/customers.dart';
import 'package:sales_mien_tay/field_work.dart';

FieldCustomer sampleCustomer(String name)=>FieldCustomer.fromJson({
  'id':'11111111-1111-4111-8111-111111111111',
  'name':name,'owner_sub':'sales-1','code':'000123',
  'address_line':'Đường Hùng Vương',
  'province':'Tiền Giang','district':'Thành phố Mỹ Tho',
  'category':'dai_ly','status':'active',
});

void main(){
  for(final width in [360.0,390.0,430.0]){
    testWidgets('Stop picker opens on tap without awaiting slow API at $width',
      (tester)async{
      tester.view.devicePixelRatio=1;
      tester.view.physicalSize=Size(width,800);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final deferred=Completer<List<FieldCustomer>>();
      FieldCustomer? picked;
      await tester.pumpWidget(MaterialApp(home:Scaffold(body:Builder(
        builder:(context)=>FilledButton(
          onPressed:()async{
            picked=await showDialog<FieldCustomer>(
              context:context,
              builder:(_)=>SalesStopCustomerPicker(customers:deferred.future));
          },
          child:const Text('Điểm ghé'),
        )))));
      await tester.tap(find.text('Điểm ghé'));
      await tester.pump();
      expect(find.text('Chọn điểm ghé'),findsOneWidget);
      expect(find.text('Đang mở danh sách khách hàng…'),findsOneWidget);
      expect(find.byType(CircularProgressIndicator),findsOneWidget);
      expect(picked,isNull);
      deferred.complete([sampleCustomer('Đại lý An Giang')]);
      await tester.pump();
      await tester.pump();
      expect(find.text('Đại lý An Giang'),findsOneWidget);
      await tester.tap(find.text('Đại lý An Giang'));
      await tester.pumpAndSettle();
      expect(picked?.name,'Đại lý An Giang');
      expect(tester.takeException(),isNull);
    });
  }

  testWidgets('Stop picker rejects denied data without exposing cached rows',
    (tester)async{
    final deferred=Completer<List<FieldCustomer>>();
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:Builder(
      builder:(context)=>TextButton(
        onPressed:()=>showDialog<FieldCustomer>(
          context:context,
          builder:(_)=>SalesStopCustomerPicker(customers:deferred.future)),
        child:const Text('Điểm ghé'),
      )))));
    await tester.tap(find.text('Điểm ghé'));
    await tester.pump();
    deferred.completeError(StateError('403'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Không tải được danh sách khách hàng. Kiểm tra kết nối và thử lại.'),
      findsOneWidget);
    expect(find.byType(ListTile),findsNothing);
    await tester.tap(find.text('Đóng'));
    await tester.pumpAndSettle();
    expect(tester.takeException(),isNull);
  });
}
