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

final forms=[
 {'id':'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
  'form_id':'11111111-1111-4111-8111-111111111111',
  'title':'Khảo sát NPP','revision':1,'status':'active',
  'provinces':['Bến Tre'],'questions':[{'id':'q1','label':'Nguồn hàng','type':'text','required':false}]},
 {'id':'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
  'form_id':'22222222-2222-4222-8222-222222222222',
  'title':'Khảo sát nhà sách','revision':1,'status':'active',
  'provinces':['Bến Tre','Tiền Giang'],'questions':[{'id':'q2','label':'Trưng bày','type':'text','required':false}]},
];

// Use bounded frame pumps: a failed API can coexist with indefinite animations
// elsewhere in the widget tree; test actions must not hang the entire CI runner.
Future<void> settle(WidgetTester tester)async{
 await tester.pump();
 await tester.pump(const Duration(milliseconds:100));
 await tester.pump(const Duration(milliseconds:250));
}

void main(){
 testWidgets('Nhiều mẫu cùng tỉnh, mỗi mẫu bật ngưng áp dụng độc lập',(tester)async{
  final state=['active','active'],revision=[1,1];
  final transitions=<String>[];
  final client=MockClient((request)async{
   if(request.method=='PATCH'){
    final payload=jsonDecode(request.body) as Map<String,dynamic>;
    final i=forms.indexWhere((f)=>f['form_id']==payload['form_id']);
    expect(i,isNonNegative);
    expect(payload['expected_revision'],revision[i]);
    state[i]=payload['status'].toString();revision[i]++;
    transitions.add(state[i]);
    return http.Response(jsonEncode({'item':{'status':state[i],'revision':revision[i]}}),
     200,headers:{'content-type':'application/json'});
   }
   if(request.url.path.endsWith('survey-templates')){
    return http.Response(jsonEncode({'items':[
     for(var i=0;i<forms.length;i){...forms[i],'status':state[i],
      'revision':revision[i]}
    ]}),200,headers:{'content-type':'application/json'});
   }
   return http.Response('{"items":[]}',200,headers:{'content-type':'application/json'});
  });
  await tester.pumpWidget(MaterialApp(home:SurveyTemplateAdmin(
   service:CustomerService('https://example.test','token',client:client),
   regions:const RegionCatalog({'Bến Tre':['Bình Đại'],'Tiền Giang':['Mỹ Tho']}),
   embedded:true)));
  await settle(tester);
  expect(find.byKey(const Key('template-edit-button')),findsNWidgets(2));
  expect(find.text('Khảo sát NPP'),findsOneWidget);
  expect(find.text('Khảo sát nhà sách'),findsOneWidget);
  expect(find.textContaining('Lịch sử phiên bản'),findsNothing);
  await tester.tap(find.byKey(const Key('template-pause-button')).first);
  await settle(tester);
  await tester.tap(find.widgetWithText(FilledButton,'Ngưng áp dụng').last);
  await settle(tester);
  expect(state,['paused','active']);
  expect(find.byKey(const Key('template-resume-button')),findsOneWidget);
  await tester.tap(find.byKey(const Key('template-resume-button')));
  await settle(tester);
  await tester.tap(find.widgetWithText(FilledButton,'Áp dụng lại').last);
  await settle(tester);
  expect(state,['active','active']);
  expect(transitions,['paused','active']);
  await tester.pumpWidget(const SizedBox.shrink());
  await settle(tester);
  client.close();
 });

 testWidgets('Lỗi API không hiển thị danh sách rỗng giả và cho thử lại',(tester)async{
  var broken=true;
  final client=MockClient((request)async{
   if(request.url.path.endsWith('survey-templates')){
    if(broken)return http.Response('{"error":"API error"}',500,
     headers:{'content-type':'application/json'});
    return http.Response(jsonEncode({'items':[forms.first]}),200,
     headers:{'content-type':'application/json'});
   }
   return http.Response('{"items":[]}',200,headers:{'content-type':'application/json'});
  });
  await tester.pumpWidget(MaterialApp(home:SurveyTemplateAdmin(
   service:CustomerService('https://example.test','token',client:client),
   regions:const RegionCatalog({'Bến Tre':['Bình Đại']}),embedded:true)));
  await settle(tester);
  expect(find.byKey(const Key('template-load-error')),findsOneWidget);
  expect(find.byKey(const Key('template-edit-button')),findsNothing);
  broken=false;
  await tester.tap(find.byKey(const Key('template-retry-button')));
  await settle(tester);
  expect(find.byKey(const Key('template-edit-button')),findsOneWidget);
  await tester.pumpWidget(const SizedBox.shrink());
  await settle(tester);
  client.close();
 });

 testWidgets('Thiết lập vẫn mở tab mẫu làm việc trước',(tester)async{
  final client=MockClient((_)async=>http.Response('{"items":[]}',200,
   headers:{'content-type':'application/json'}));
  final queue=OfflineQueue(SalesSession(),'template-test','1');
  await tester.pumpWidget(MaterialApp(home:SalesSettingsPage(
   service:CustomerService('https://example.test','token',client:client),
   queue:queue,regions:const RegionCatalog({'Bến Tre':['Bình Đại']}),
   admin:true)));
  await settle(tester);
  final controller=DefaultTabController.of(tester.element(find.byType(TabBar)));
  expect(controller.index,1);
  await tester.pumpWidget(const SizedBox.shrink());
  await settle(tester);
  client.close();queue.dispose();
 });
}
