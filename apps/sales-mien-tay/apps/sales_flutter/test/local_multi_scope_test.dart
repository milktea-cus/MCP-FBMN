import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sales_mien_tay/local_scope_picker.dart';

void main(){
 final district=<String,dynamic>{
  'scope_kind':'territory','scope_key':'Cần Thơ|Ninh Kiều',
  'province':'Cần Thơ','district':'Ninh Kiều','label':'Ninh Kiều · Cần Thơ'};
 final chain=<String,dynamic>{
  'scope_kind':'chain','scope_key':'6bca79a4-2a01-4c54-a266-c0d75364b0dd',
  'province':null,'district':null,'label':'Chuỗi Nhà Sách'};
 final customer=<String,dynamic>{
  'scope_kind':'customer','scope_key':'036bedf0-27ab-4ec4-965c-3981fdc112e2',
  'province':null,'district':null,'label':'Khách điểm bán A'};
 test('single legacy geographic route remains readable',(){
  final result=localTemplateScopes({
   'province':'Cần Thơ','district':'Ninh Kiều',
  });
  expect(result,hasLength(1));
  expect(result.single['scope_key'],'Cần Thơ|Ninh Kiều');
  expect(localScopeSummary(result),contains('Ninh Kiều'));
 });
 test('mixed scopes preserved without dropping chain or customer',(){
  final scopes=[district,chain,customer];
  final saved=localTemplateScopes({'scopes':scopes});
  expect(saved.map(localScopeFingerprint).toSet().length,3);
  expect(localScopeSummary(saved),contains('+1'));
  expect(saved[1]['scope_kind'],'chain');
  expect(saved[2]['scope_kind'],'customer');
 });
 testWidgets('multi-select keeps selections across category changes',(tester)async{
  List<Map<String,dynamic>> chosen=[];
  await tester.pumpWidget(
   MaterialApp(home:Scaffold(body:StatefulBuilder(
    builder:(ctx,update){
     return Center(child:TextButton(
      onPressed:()async{
       final next=await pickLocalScopes(
        context:ctx,options:[district,chain,customer],initial:chosen);
       if(next!=null)update(()=>chosen=next);
      },
      child:const Text('Chọn nhiều'),
     ));
    },
   ))),
  );
  await tester.tap(find.text('Chọn nhiều'));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(CheckboxListTile,'Ninh Kiều · Cần Thơ'));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(ChoiceChip,'Chuỗi'));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(CheckboxListTile,'Chuỗi Nhà Sách'));
  await tester.pumpAndSettle();
  expect(find.text('Áp dụng (2)'),findsOneWidget);
  await tester.tap(find.text('Áp dụng (2)'));
  await tester.pumpAndSettle();
  expect(chosen.map((s)=>s['scope_kind']).toList(),containsAll(['territory','chain']));
 });
}
