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

  testWidgets('Bulk route planner opens immediately, preserves selection order',
    (tester)async{
    tester.view.devicePixelRatio=1;
    tester.view.physicalSize=const Size(390,844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final pending=Completer<List<FieldCustomer>>();
    SalesBulkCustomerSelection? choice;
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:Builder(
      builder:(context)=>FilledButton(
        onPressed:()async{
         choice=await showDialog<SalesBulkCustomerSelection>(
          context:context,
          builder:(_)=>SalesBulkCustomerPicker(
            customers:pending.future,
            initialDate:DateTime(2026,11,11),
          ),
         );
        },
        child:const Text('Lập nhiều khách'),
      )))));
    await tester.tap(find.text('Lập nhiều khách').first);
    await tester.pump();
    expect(find.text('Đang mở danh sách khách hàng…'),findsOneWidget);
    expect(find.text('Xem trước'),findsOneWidget);
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton,'Xem trước'))
      .onPressed,isNull);
    pending.complete([
      sampleCustomer('Đại lý A'),
      FieldCustomer.fromJson({
       ...sampleCustomer('Đại lý B').toJson(),
       'id':'22222222-2222-4222-8222-222222222222',
      }),
    ]);
    await tester.pump();
    await tester.pump();
    expect(find.text('Đại lý A'),findsOneWidget);
    expect(find.text('Đại lý B'),findsOneWidget);
    await tester.tap(find.text('Đại lý B'));
    await tester.pump();
    await tester.tap(find.text('Đại lý A'));
    await tester.pump();
    await tester.tap(find.text('Xem trước'));
    await tester.pumpAndSettle();
    expect(choice,isNotNull);
    expect(choice!.selected,[
      '22222222-2222-4222-8222-222222222222',
      '11111111-1111-4111-8111-111111111111',
    ]);
    expect(choice!.date,DateTime(2026,11,11));
    expect(tester.takeException(),isNull);
  });

  testWidgets('Bulk route copied selections stay scoped to returned customers',
    (tester)async{
    SalesBulkCustomerSelection? choice;
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:Builder(
      builder:(context)=>FilledButton(
        onPressed:()async{
         choice=await showDialog<SalesBulkCustomerSelection>(
          context:context,builder:(_)=>SalesBulkCustomerPicker(
            customers:Future.value([sampleCustomer('Đại lý A')]),
            initialDate:DateTime(2026,11,11),copying:true,
            preselectedIds:const [
              '11111111-1111-4111-8111-111111111111',
              'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
            ],
          ));
        },
        child:const Text('Sao chép'),
      )))));
    await tester.tap(find.text('Sao chép'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Xem trước tuyến sao chép'),findsOneWidget);
    await tester.tap(find.text('Xem trước'));
    await tester.pumpAndSettle();
    expect(choice!.selected,['11111111-1111-4111-8111-111111111111']);
    expect(tester.takeException(),isNull);
  });

}
