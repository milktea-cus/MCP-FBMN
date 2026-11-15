import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sales_mien_tay/customers.dart';
import 'package:sales_mien_tay/models.dart';
import 'package:sales_mien_tay/surveys.dart';

const formId='11111111-1111-4111-8111-111111111111';
const snapshotId='22222222-2222-4222-8222-222222222222';
final originalQuestions=<Map<String,dynamic>>[
 {'id':'q1','label':'Nhãn hàng kinh doanh','type':'text','required':false},
 {'id':'q2','label':'Nội dung làm việc','type':'multi_choice','required':false,
  'options':['Ghé thăm','Giới thiệu sản phẩm']},
];

void main(){
 testWidgets('Sửa tên mẫu theo ID độc lập, phạm vi không bị biến thành mã mẫu',(tester)async{
  String title='Mẫu chung · Gặp khách';
  Map<String,dynamic>? posted;
  final client=MockClient((request)async{
   if(request.method=='POST'){
    posted=jsonDecode(request.body) as Map<String,dynamic>;
    title=posted!['title'].toString();
    return http.Response(jsonEncode({'item':{'title':title,'form_id':formId}}),200,
     headers:{'content-type':'application/json'});
   }
   if(request.url.path.endsWith('/survey-templates'))return http.Response(
    jsonEncode({'items':[{'id':snapshotId,'form_id':formId,'revision':1,
     'title':title,'provinces':[],'status':'active','questions':originalQuestions}]}),
    200,headers:{'content-type':'application/json'});
   return http.Response('{"items":[]}',200,headers:{'content-type':'application/json'});
  });
  await tester.pumpWidget(MaterialApp(home:SurveyTemplateAdmin(
   service:CustomerService('https://example.test','token',client:client),
   regions:const RegionCatalog({'Bến Tre':['Bình Đại']}),embedded:true)));
  await tester.pumpAndSettle();
  expect(find.text('Mẫu chung · Gặp khách'),findsOneWidget);
  expect(find.textContaining('v4'),findsNothing);
  expect(find.textContaining('Lịch sử phiên bản'),findsNothing);
  await tester.tap(find.byKey(const Key('template-edit-button')));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('template-title-field')),findsOneWidget);
  await tester.enterText(find.byKey(const Key('template-title-field')),'Khảo sát nhà sách');
  await tester.tap(find.byKey(const Key('template-publish-button')));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(FilledButton,'Lưu mẫu').last);
  await tester.pumpAndSettle();
  expect(posted, isNotNull);
  expect(posted!['form_id'],formId);
  expect(posted!['expected_revision'],1);
  expect(posted!['provinces'],isEmpty);
  expect(posted!['title'],'Khảo sát nhà sách');
  expect(find.byKey(const Key('template-title-field')),findsNothing);
  client.close();
 });

 testWidgets('Tạo mẫu mới đặt tên và chọn nhiều tỉnh tại cùng biểu mẫu',(tester)async{
  Map<String,dynamic>? posted;
  final client=MockClient((request)async{
   if(request.method=='POST'){
    posted=jsonDecode(request.body) as Map<String,dynamic>;
    return http.Response('{"item":{}}',201,headers:{'content-type':'application/json'});
   }
   return http.Response('{"items":[]}',200,headers:{'content-type':'application/json'});
  });
  await tester.pumpWidget(MaterialApp(home:SurveyTemplateAdmin(
   service:CustomerService('https://example.test','token',client:client),
   regions:const RegionCatalog({'Bến Tre':['Bình Đại'],'Tiền Giang':['Mỹ Tho']}),
   embedded:true)));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('template-create-button')));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('template-title-field')),'Khảo sát đại lý');
  await tester.tap(find.byType(SwitchListTile));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Bến Tre'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Tiền Giang'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Thêm câu'));
  await tester.pumpAndSettle();
  // The expanded editor sits below the scope selector on a phone.
  // Scroll to the real TextFormField rather than searching its decoration label.
  final questionLabel=find.byWidgetPredicate((w)=>
   w is TextFormField && w.key is ValueKey<String> &&
   (w.key as ValueKey<String>).value.startsWith('label:'));
  await tester.scrollUntilVisible(questionLabel,220,
   scrollable:find.byType(Scrollable).first);
  await tester.pumpAndSettle();
  await tester.enterText(questionLabel,'Ghi nhận tại điểm bán');
  await tester.tap(find.byKey(const Key('template-publish-button')));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(FilledButton,'Lưu mẫu').last);
  await tester.pumpAndSettle();
  expect(posted!['expected_revision'],0);
  expect((posted!['provinces'] as List).toSet(),{'Bến Tre','Tiền Giang'});
  expect(posted!['form_id'],isNotEmpty);
  expect((posted!['questions'] as List),hasLength(1));
  client.close();
 });
}
