import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sales_mien_tay/customers.dart';
import 'package:sales_mien_tay/models.dart';
import 'package:sales_mien_tay/surveys.dart';

void main(){
 testWidgets('Tách màn sửa, đặt tên, xác nhận và phát hành phiên bản mới', (tester) async {
  String title='Mẫu chung · Gặp khách';
  var version=4;
  Map<String,dynamic>? posted;
  final questions=[
   {'id':'q1','label':'Nhãn hàng kinh doanh','type':'text','required':false},
   {'id':'q2','label':'Nội dung làm việc','type':'multi_choice','required':false,
    'options':['Ghé thăm','Giới thiệu sản phẩm']},
  ];
  final client=MockClient((request)async {
   if(request.method=='POST'){
    posted=jsonDecode(request.body) as Map<String,dynamic>;
    title=posted!['title'].toString();version++;
    return http.Response(jsonEncode({'item':{'title':title,'version':version,
     'questions':posted!['questions']}}),201,
     headers:{'content-type':'application/json'});
   }
   if(request.url.path.endsWith('/survey-templates'))return http.Response(
    jsonEncode({'items':[{'id':'11111111-1111-4111-8111-111111111111',
     'province':'*','title':title,'version':version,'created_by':'admin',
     'status':'active','created_at':'2026-11-15T01:00:00Z','questions':questions}]}),
    200,headers:{'content-type':'application/json'});
   return http.Response('{"items":[]}',200,
    headers:{'content-type':'application/json'});
  });
  await tester.pumpWidget(MaterialApp(home:SurveyTemplateAdmin(
   service:CustomerService('https://example.test','token',client:client),
   regions:const RegionCatalog({'Bến Tre':['Bình Đại']}),embedded:true)));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('template-title-field')),findsNothing);
  expect(find.text(title),findsOneWidget);
  await tester.tap(find.byKey(const Key('template-edit-button')));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('template-title-field')),findsOneWidget);
  expect(find.byKey(const Key('template-save-draft-button')),findsOneWidget);
  expect(find.byKey(const Key('template-publish-button')),findsOneWidget);
  expect(find.text('Xóa'),findsNothing); // cards are collapsed
  await tester.enterText(find.byKey(const Key('template-title-field')),
   'Khảo sát nhà sách tháng 11');
  await tester.tap(find.byKey(const Key('template-publish-button')));
  await tester.pumpAndSettle();
  expect(find.text('Phát hành mẫu?'),findsOneWidget);
  await tester.tap(find.widgetWithText(FilledButton,'Phát hành').last);
  await tester.pumpAndSettle();
  expect(posted, isNotNull);
  expect(posted!['title'],'Khảo sát nhà sách tháng 11');
  expect(posted!['province'],'*');
  expect(posted!['expected_version'],4);
  expect((posted!['questions'] as List).length,2);
  expect(find.byKey(const Key('template-title-field')),findsNothing);
  client.close();
 });
 testWidgets('Sửa từng câu dạng thu gọn và thêm lựa chọn, không phá các câu khác', (tester) async {
  final client=MockClient((_)async=>http.Response('{"items":[]}',200,
   headers:{'content-type':'application/json'}));
  await tester.pumpWidget(MaterialApp(home:SurveyTemplateAdmin(
   service:CustomerService('https://example.test','token',client:client),
   regions:const RegionCatalog({'Bến Tre':['Bình Đại']}),embedded:true)));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('template-edit-button')));
  await tester.pumpAndSettle();
  expect(find.text('Thêm câu'),findsOneWidget);
  await tester.tap(find.text('Thêm câu'));
  await tester.pumpAndSettle();
  expect(find.text('Nội dung câu hỏi'),findsOneWidget);
  expect(find.text('Bắt buộc trả lời'),findsOneWidget);
  client.close();
 });
}
