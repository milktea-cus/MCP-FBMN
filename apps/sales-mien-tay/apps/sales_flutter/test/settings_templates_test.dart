import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sales_mien_tay/customer_work_page.dart';
import 'package:sales_mien_tay/main.dart';
import 'package:sales_mien_tay/models.dart';

void main(){
 test('Mẫu là đối tượng độc lập; phạm vi chỉ là thuộc tính của mẫu',(){
  final a=<String,dynamic>{
   'id':'11111111-1111-4111-8111-111111111111',
   'form_id':'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
   'title':'Nhà sách','status':'active','provinces':['Bến Tre','Tiền Giang'],
   'questions':[{'id':'q1','type':'text','label':'Trưng bày'}],
  };
  final b=<String,dynamic>{
   'id':'22222222-2222-4222-8222-222222222222',
   'form_id':'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
   'title':'NPP','status':'active','provinces':<String>[],
   'questions':[{'id':'q2','type':'text','label':'Nguồn hàng'}],
  };
  final c=<String,dynamic>{
   'id':'33333333-3333-4333-8333-333333333333',
   'form_id':'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
   'title':'Ngưng','status':'paused','provinces':['Bến Tre'],
   'questions':[{'id':'q3','type':'text','label':'Khác'}],
  };
  final forms=[a,b,c];
  expect(availableCustomerWorkTemplates(forms,'Bến Tre').map((f)=>f['title']),
   ['Nhà sách','NPP']);
  expect(availableCustomerWorkTemplates(forms,'Đồng Tháp').map((f)=>f['title']),
   ['NPP']);
  final segments=customerWorkFormSegments(a,{'q1':'Đã kiểm tra','q2':'không thuộc mẫu'},'Ghi chú');
  expect(segments,hasLength(1));
  expect(segments.first['template_id'],a['id']);
  expect(segments.first['answers'],{'q1':'Đã kiểm tra'});
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
