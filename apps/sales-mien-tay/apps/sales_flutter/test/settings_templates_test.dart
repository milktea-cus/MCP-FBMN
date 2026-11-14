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

 test('Seeded province v1 never adds six unwanted default questions',(){
  final common={
   'id':'11111111-1111-4111-8111-111111111111',
   'province':'*','version':4,'created_by':'system:remove-inherited-questions',
   'questions':[{'id':'business_brands','label':'Nhãn hàng kinh doanh','type':'text'},
    {'id':'visit_content','label':'Nội dung làm việc','type':'text'},
    {'id':'rating','label':'Đánh giá','type':'choice','options':['A','B']}],
  };
  final legacy={
   'id':'22222222-2222-4222-8222-222222222222',
   'province':'Bến Tre','version':1,'created_by':'system:initial',
   'questions':[for(var i=0;i<6;i++){'id':'legacy_$i','label':'Câu mặc định $i','type':'text'}],
  };
  final effective=mergeCustomerVisitTemplates([common,legacy],'Bến Tre')!;
  final questions=effective['questions'] as List;
  expect(questions,hasLength(3));
  expect(effective['province_template_id'],null);
  expect(effective['common_version'],4);
  expect(effective['province_version'],null);
  expect(questions.every((q)=>(q as Map)['source_template_id']==common['id']),true);
  expect(customerWorkFormSegments(effective,{'rating':'A','visit_content':'Gặp khách'},'Ghi chú'),
   hasLength(1));
 });
 test('Own published provincial questions are saved under own immutable template ID',(){
  final common={
   'id':'11111111-1111-4111-8111-111111111111',
   'province':'*','version':4,'created_by':'system:remove-inherited-questions',
   'questions':[{'id':'common_text','label':'Nội dung chung','type':'text'}],
  };
  final province={
   'id':'33333333-3333-4333-8333-333333333333',
   'province':'Bến Tre','version':2,'created_by':'admin',
   'questions':[{'id':'local_npp','label':'NPP tỉnh','type':'text'}],
  };
  final effective=mergeCustomerVisitTemplates([common,province],'Bến Tre')!;
  final chunks=customerWorkFormSegments(effective,{
   'common_text':'Đã giới thiệu','local_npp':'NPP tỉnh','old_deleted':'should not save',
  },'Kết quả');
  expect(chunks,hasLength(2));
  expect(chunks[0]['template_id'],common['id']);
  expect(chunks[0]['answers'],{'common_text':'Đã giới thiệu'});
  expect(chunks[0]['note'],'Kết quả');
  expect(chunks[1]['template_id'],province['id']);
  expect(chunks[1]['answers'],{'local_npp':'NPP tỉnh'});
  expect(chunks[1]['note'],'');
  expect(chunks.every((v)=>(v['answers'] as Map).containsKey('old_deleted')==false),true);
 });
 test('Published source-specific market brand choices remain on their template',(){
  final common={'id':'11111111-1111-4111-8111-111111111111',
   'province':'*','version':4,'questions':[{'id':'brands','label':'Nhãn','type':'multi_choice','catalog_source':'brands','options':['MGP','M&G']}]};
  final province={'id':'33333333-3333-4333-8333-333333333333',
   'province':'Bến Tre','version':2,'created_by':'admin',
   'questions':[{'id':'local_npp','label':'NPP','type':'text'}]};
  final form=mergeCustomerVisitTemplates([common,province],'Bến Tre')!;
  final submissions=customerWorkFormSegments(form,{'brands':['MGP'],'local_npp':'A'},'Ghi chú',marketBrands:['MGP']);
  expect(submissions,hasLength(2));
  expect(submissions[0]['market_brands'],['MGP']);
  expect(submissions[1]['market_brands'],null);
 });

}
