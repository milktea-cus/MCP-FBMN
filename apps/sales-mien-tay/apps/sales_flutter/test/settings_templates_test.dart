import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sales_mien_tay/customer_work_page.dart';
import 'package:sales_mien_tay/main.dart';
import 'package:sales_mien_tay/models.dart';

void main(){
 test('Mẫu chung luôn kèm tỉnh đúng; ID trùng lấy phiên bản tỉnh',(){
  final common=<String,dynamic>{
   'id':'11111111-1111-4111-8111-111111111111','province':'*','version':2,
   'questions':[
    {'id':'brands','type':'text','label':'Nhãn chung'},
    {'id':'common_contact','type':'text','label':'Người liên hệ'},
   ],
  };
  final benTre=<String,dynamic>{
   'id':'22222222-2222-4222-8222-222222222222','province':'Bến Tre','version':3,
   'questions':[
    {'id':'npp','type':'text','label':'NPP Bến Tre'},
    {'id':'brands','type':'multi_choice','label':'Nhãn tại Bến Tre','options':['MGP','Thành Đạt']}
   ],
  };
  final dongThap=<String,dynamic>{
   'id':'33333333-3333-4333-8333-333333333333','province':'Đồng Tháp','version':4,
   'questions':[{'id':'npp','type':'text','label':'NPP Đồng Tháp'}],
  };
  final templates=[common,benTre,dongThap];
  final effective=mergeCustomerVisitTemplates(templates,'Bến Tre')!;
  expect(effective['id'],benTre['id']);
  expect(effective['common_version'],2);
  final questions=(effective['questions'] as List).cast<Map<String,dynamic>>();
  expect(questions.map((q)=>q['id']),['common_contact','npp','brands']);
  expect(questions.last['label'],'Nhãn tại Bến Tre');
  expect(questions.first['template_scope'],'common');
  expect(questions[1]['template_scope'],'province');
  final other=mergeCustomerVisitTemplates(templates,'Đồng Tháp')!;
  expect((other['questions'] as List).last['label'],'NPP Đồng Tháp');
  final fallback=mergeCustomerVisitTemplates([common],'Tiền Giang')!;
  expect(fallback['id'],common['id']);
  expect(fallback['questions'],hasLength(2));
  expect(mergeCustomerVisitTemplates([], 'Bến Tre'),isNull);
 });
 test('Làm việc cả chuyến nhiều ngày, không khóa ở ngày thứ hai',(){
  final trip=<String,dynamic>{
   'trip_id':'trip1','route_date':'2026-11-14',
   'trip_start_date':'2026-11-14','trip_end_date':'2026-11-17',
   'trip_closed_at':null,
  };
  for(final day in [14,15,16,17]){
   expect(customerWorkDateAllowed(trip,DateTime(2026,11,day)),true);
  }
  expect(customerWorkDateAllowed(trip,DateTime(2026,11,13)),false);
  expect(customerWorkDateAllowed(trip,DateTime(2026,11,18)),false);
  trip['trip_closed_at']='2026-11-15T08:00:00Z';
  expect(customerWorkDateAllowed(trip,DateTime(2026,11,15)),false);
  final legacy={'route_date':'2026-11-14'};
  expect(customerWorkDateAllowed(legacy,DateTime(2026,11,14)),true);
  expect(customerWorkDateAllowed(legacy,DateTime(2026,11,15)),false);
 });
 testWidgets('Menu chỉ có một Thiết lập, không có nút tải lại', (tester)async{
  const entries=['Tổng quan','Khách hàng','Khảo sát','Target',
   'Dự kiến','Lịch trình','Hỗ trợ','Chính sách','Yêu cầu',
   'Báo cáo','Danh mục SKU','Tra tồn','Ra đơn'];
  var opened=0;
  await tester.pumpWidget(MaterialApp(home:Scaffold(
   appBar:AppBar(title:const Text('Field Work')),
   drawer:SalesHomeDrawer(
    admin:true,loading:false,selectedIndex:0,sections:entries,
    icons:List.filled(entries.length,Icons.dashboard_outlined),
    onSection:(_){},onRefresh:(){},onStaff:(){},onProfile:(){},
    onSettings:()=>opened++,
   ),body:const SizedBox.expand(),
  )));
  tester.state<ScaffoldState>(find.byType(Scaffold).first).openDrawer();
  await tester.pumpAndSettle();
  expect(find.text('Thiết lập'),findsOneWidget);
  expect(find.text('Tải lại dữ liệu'),findsNothing);
  expect(find.text('Cài đặt mẫu tuyến'),findsNothing);
  expect(find.text('Cài đặt mẫu khảo sát · nhãn hàng'),findsNothing);
  await tester.tap(find.text('Thiết lập'));
  await tester.pumpAndSettle();
  expect(opened,1);
 });
 testWidgets('Tổng quan không lặp dropdown nhãn và huyện',(tester)async{
  await tester.pumpWidget(const MaterialApp(home:Scaffold(body:
   SingleChildScrollView(child:SalesBrandCoverageTable(
    surveys:<SalesRecord>[],provinces:['Bến Tre'],
    brandNames:['MGP'],verifiedData:true,
    customerCounts:[{'province':'Bến Tre','district':'Huyện Bình Đại','customers':3}],
    verifiedRows:[{'province':'Bến Tre','district':'Huyện Bình Đại','brand':'MGP','customers':1}],
   )))));
  expect(find.text('Nhãn hàng tại điểm bán'),findsOneWidget);
  expect(find.byType(DropdownButtonFormField<String>),findsNothing);
  expect(find.text('Tất cả huyện'),findsNothing);
  expect(find.text('Tên khách / mã khách / nhãn hàng'),findsNothing);
  expect(find.text('MGP'),findsOneWidget);
 });
}
