import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sales_mien_tay/customers.dart';
import 'package:sales_mien_tay/models.dart';
import 'package:sales_mien_tay/surveys.dart';
import 'package:sales_mien_tay/sales_settings_page.dart';
import 'package:sales_mien_tay/offline_queue.dart';
import 'package:sales_mien_tay/session.dart';

void main(){
 testWidgets('Mẫu chung có nút Sửa nhưng không thể ngưng/xóa',(tester)async{
  final client=MockClient((request)async{
   if(request.url.path.endsWith('survey-templates')){
    return http.Response(jsonEncode({'items':[{
     'id':'11111111-1111-4111-8111-111111111111',
     'province':'*','version':4,'created_by':'admin',
     'status':'active','created_at':'2026-11-14T10:00:00Z',
     'questions':[
      {'id':'q1','label':'Nhãn hàng kinh doanh','type':'text','required':false},
      {'id':'q2','label':'Nội dung làm việc','type':'text','required':false},
      {'id':'q3','label':'Đánh giá','type':'choice','required':false,'options':['A','B']}
     ]
    }]}),200,headers:{'content-type':'application/json'});
   }
   return http.Response('{"items":[]}',200,headers:{'content-type':'application/json'});
  });
  await tester.pumpWidget(MaterialApp(home:SurveyTemplateAdmin(
   service:CustomerService('https://example.test','token',client:client),
   regions:const RegionCatalog({'Bến Tre':['Bình Đại']}),embedded:true,
  )));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('template-edit-button')),findsOneWidget);
  expect(find.byKey(const Key('template-pause-button')),findsNothing);
  expect(find.byKey(const Key('template-delete-button')),findsNothing);
  expect(find.textContaining('Mẫu chung phải luôn có'),findsOneWidget);
  expect(find.byKey(const Key('template-publish-button')),findsNothing);
  await tester.tap(find.byKey(const Key('template-edit-button')));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('template-title-field')),findsOneWidget);
  expect(find.byKey(const Key('template-publish-button')),findsOneWidget);
  expect(find.textContaining('Câu hỏi (3/50)'),findsOneWidget);
  await tester.tap(find.text('Nhãn hàng kinh doanh'));
  await tester.pumpAndSettle();
  expect(find.text('Xóa'),findsOneWidget);
  client.close();
 });

 testWidgets('Tỉnh có Sửa, Ngưng, Xóa và Khôi phục không mất lịch sử',(tester)async{
  String status='active';final transitions=<String>[];
  final client=MockClient((request)async{
   if(request.method=='PATCH'){
    final payload=jsonDecode(request.body) as Map<String,dynamic>;
    expect(payload['province'],'Bến Tre');
    expect(payload['expected_status'],status);
    status=payload['status'].toString();
    transitions.add(status);
    return http.Response(jsonEncode({'item':{'province':'Bến Tre','status':status}}),
     200,headers:{'content-type':'application/json'});
   }
   if(request.url.path.endsWith('survey-templates')){
    final province=request.url.queryParameters['province'];
    return http.Response(jsonEncode({'items':[{
     'id':'22222222-2222-4222-8222-222222222222',
     'province':province,'version':2,'created_by':'admin',
     'status':province=='*'?'active':status,
     'created_at':'2026-11-14T10:00:00Z',
     'questions':[{'id':'q1','label':'NPP địa phương','type':'text','required':false}]
    }]}),200,headers:{'content-type':'application/json'});
   }
   return http.Response('{"items":[]}',200,headers:{'content-type':'application/json'});
  });
  await tester.pumpWidget(MaterialApp(home:SurveyTemplateAdmin(
   service:CustomerService('https://example.test','token',client:client),
   regions:const RegionCatalog({'Bến Tre':['Bình Đại']}),embedded:true,
  )));
  await tester.pumpAndSettle();
  await tester.tap(find.byType(DropdownButtonFormField<String>));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Theo tỉnh · Bến Tre').last);
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('template-edit-button')),findsOneWidget);
  expect(find.byKey(const Key('template-pause-button')),findsOneWidget);
  expect(find.byKey(const Key('template-delete-button')),findsOneWidget);
  await tester.tap(find.byKey(const Key('template-pause-button')));
  await tester.pumpAndSettle();
  expect(find.text('Ngưng sử dụng mẫu?'),findsOneWidget);
  await tester.tap(find.widgetWithText(FilledButton,'Ngưng sử dụng'));
  await tester.pumpAndSettle();
  expect(status,'paused');
  expect(find.byKey(const Key('template-resume-button')),findsOneWidget);
  expect(find.byKey(const Key('template-delete-button')),findsOneWidget);
  await tester.tap(find.byKey(const Key('template-delete-button')));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(FilledButton,'Xóa khỏi sử dụng'));
  await tester.pumpAndSettle();
  expect(status,'archived');
  expect(find.byKey(const Key('template-delete-button')),findsNothing);
  expect(find.textContaining('Lịch sử phiên bản'),findsOneWidget);
  await tester.tap(find.byKey(const Key('template-resume-button')));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(FilledButton,'Bật lại'));
  await tester.pumpAndSettle();
  expect(status,'active');
  expect(transitions,['paused','archived','active']);
  client.close();
 });

 testWidgets('Thiết lập mở tab câu hỏi trước, tên tab dễ hiểu',(tester)async{
  final client=MockClient((_)async=>http.Response('{"items":[]}',200,
   headers:{'content-type':'application/json'}));
  final queue=OfflineQueue(SalesSession(),'template-test','1');
  await tester.pumpWidget(MaterialApp(home:SalesSettingsPage(
   service:CustomerService('https://example.test','token',client:client),
   queue:queue,regions:const RegionCatalog({'Bến Tre':['Bình Đại']}),
   admin:true,
  )));
  await tester.pumpAndSettle();
  expect(find.text('Mẫu lịch trình'),findsOneWidget);
  expect(find.text('Mẫu làm việc'),findsOneWidget);
  final controller=DefaultTabController.of(tester.element(find.byType(TabBar)));
  expect(controller.index,1);
  client.close();queue.dispose();
 });

 testWidgets('Lỗi tải mẫu không hiển thị giả là chưa phát hành; thử lại hồi phục',(tester)async{
  var broken=true;
  final client=MockClient((request)async{
   if(request.url.path.endsWith('survey-templates')){
    if(broken)return http.Response('{"error":"Lỗi hệ thống"}',500,
     headers:{'content-type':'application/json'});
    return http.Response(jsonEncode({'items':[{
     'id':'11111111-1111-4111-8111-111111111111',
     'province':'*','title':'Mẫu chung · Gặp khách',
     'version':4,'created_by':'admin','status':'active',
     'questions':[{'id':'q1','label':'Nội dung khảo sát',
      'type':'text','required':false}]
    }]}),200,headers:{'content-type':'application/json'});
   }
   return http.Response('{"items":[]}',200,headers:{'content-type':'application/json'});
  });
  await tester.pumpWidget(MaterialApp(home:SurveyTemplateAdmin(
   service:CustomerService('https://example.test','token',client:client),
   regions:const RegionCatalog({'Bến Tre':['Bình Đại']}),embedded:true,
  )));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('template-load-error')),findsOneWidget);
  expect(find.byKey(const Key('template-edit-button')),findsNothing);
  expect(find.text('Chưa phát hành'),findsNothing);
  broken=false;
  await tester.tap(find.byKey(const Key('template-retry-button')));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('template-load-error')),findsNothing);
  expect(find.byKey(const Key('template-edit-button')),findsOneWidget);
  expect(find.textContaining('Đang áp dụng · v4'),findsOneWidget);
  client.close();
 });

}
