import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sales_mien_tay/models.dart';
import 'package:sales_mien_tay/session.dart';
import 'package:sales_mien_tay/staff_page.dart';

class FakeSession extends SalesSession {
 final calls=<String>[];
 bool fail=true;
 Map<String,dynamic>? saved;
 @override Future<Map<String,dynamic>> post(String path, Map<String,dynamic> data) async {
  calls.add(path);
  if(path.endsWith('/identity')) return {'user_sub':'11111111-1111-4111-8111-111111111111'};
  saved=data;
  if(fail) throw const ApiFailure(409,'Mã nhân viên đã tồn tại.');
  return {'item':data};
 }
}
void main(){
 testWidgets('Save provisions once, keeps errors visible and retries with two provinces',(tester) async{
  final session=FakeSession();
  await tester.pumpWidget(MaterialApp(home:Scaffold(body:Builder(builder:(context)=>TextButton(onPressed:()=>showDialog<bool>(context:context,builder:(_)=>StaffEditor(session:session,catalog:const RegionCatalog({'Tiền Giang':['Cái Bè'],'Bến Tre':['Ba Tri']}),staff:null,allStaff:const [])),child:const Text('Mở'))))));
  await tester.tap(find.text('Mở'));await tester.pumpAndSettle();
  await tester.tap(find.text('Lưu nhân viên'));await tester.pumpAndSettle();
  expect(find.text('Vui lòng nhập họ tên, email và mã nhân viên.'),findsOneWidget);
  final fields=find.byType(TextField);
  await tester.enterText(fields.at(0),'Sales Test');
  await tester.enterText(fields.at(1),'sales@example.invalid');
  await tester.enterText(fields.at(2),'TEST-001');
  await tester.ensureVisible(find.text('Tiền Giang'));await tester.tap(find.text('Tiền Giang'));await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('Toàn tỉnh').first);await tester.tap(find.text('Toàn tỉnh').first);await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('Bến Tre'));await tester.tap(find.text('Bến Tre'));await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('Toàn tỉnh').last);await tester.tap(find.text('Toàn tỉnh').last);await tester.pumpAndSettle();
  await tester.tap(find.text('Lưu nhân viên'));await tester.pumpAndSettle();
  expect(find.text('Mã nhân viên đã tồn tại.'),findsOneWidget);
  expect(session.calls,['/api/v1/admin/identity','/api/v1/admin/staff']);
  expect(session.saved?['scopes'],hasLength(2));
  session.fail=false;
  await tester.tap(find.text('Lưu nhân viên'));await tester.pumpAndSettle();
  expect(session.calls,['/api/v1/admin/identity','/api/v1/admin/staff','/api/v1/admin/staff']);
  expect(find.text('Lưu nhân viên'),findsNothing);
 });
}
