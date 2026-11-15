import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idb_shim/idb_shim.dart';
import 'package:sales_mien_tay/customers.dart';
import 'package:sales_mien_tay/models.dart';
import 'package:sales_mien_tay/offline_queue.dart';
import 'package:sales_mien_tay/scoped_record_editor.dart';
import 'package:sales_mien_tay/session.dart';

class OfflineSession extends SalesSession {
 @override Future<Map<String,dynamic>> get(String path)async=>throw const ApiFailure(503,'offline');
}
/// The widget contract is verified independently from the real IndexedDB transaction.
/// The adjacent unit test reopens the real durable outbox and checks persisted bytes.
class RecordingScopedDraftQueue extends OfflineQueue {
 String? savedDraftId;
 Map<String,dynamic>? savedDraft;
 RecordingScopedDraftQueue():super(OfflineSession(),'owner-d','9',factory:newIdbFactoryMemory());
 @override Future<void> replaceScopedDraft(String id,Map<String,dynamic> data)async{
  savedDraftId=id;savedDraft=Map<String,dynamic>.from(data);
 }
}
class PickerCustomers extends CustomerService {
 const PickerCustomers():super('https://example.test','');
 @override Future<List<FieldCustomer>> list({void Function(List<FieldCustomer> partial)? onPage})async=>[
  FieldCustomer.fromJson({'id':'11111111-1111-4111-8111-111111111111',
    'name':'VPP A','address_line':'12 ABC','province':'Tiền Giang',
    'district':'Cai Lậy','field_code':'VPP001','category':'van_phong_pham',
    'status':'active','version':1}),
  FieldCustomer.fromJson({'id':'22222222-2222-4222-8222-222222222222',
    'name':'VPP B','address_line':'13 ABC','province':'Bến Tre',
    'district':'Châu Thành','field_code':'VPP002','category':'van_phong_pham',
    'status':'active','version':1}),
 ];
}
const regions=RegionCatalog({'Tiền Giang':['Cai Lậy'],'Bến Tre':['Châu Thành']});

void main(){
 testWidgets('support chooses one county or multiple provinces, queues atomically offline',(tester)async{
  final queue=OfflineQueue(OfflineSession(),'owner-a','9',factory:newIdbFactoryMemory());
  await tester.pumpWidget(MaterialApp(home:ScopedRecordEditor(
   kind:'support',regions:regions,queue:queue,service:const PickerCustomers(),onSaved:(){})));
  await tester.enterText(find.byType(TextFormField).first,'Cần hỗ trợ thị trường');
  await tester.tap(find.text('Chọn tỉnh'));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(CheckboxListTile,'Tiền Giang'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Xong · 1 tỉnh'));
  await tester.pumpAndSettle();
  expect(find.text('Huyện (để trống = toàn tỉnh)'),findsOneWidget);
  await tester.tap(find.textContaining('1 tỉnh:'));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(CheckboxListTile,'Bến Tre'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Xong · 2 tỉnh'));
  await tester.pumpAndSettle();
  expect(find.textContaining('không chọn huyện'),findsOneWidget);
  await tester.scrollUntilVisible(find.text('Lưu trên máy · Đồng bộ khi có mạng'),240,scrollable:find.byType(Scrollable).first);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Lưu trên máy · Đồng bộ khi có mạng'));
  await tester.pumpAndSettle();
  expect(queue.pending.length,1);
  expect(queue.pending.single['path'],'/api/v1/scoped-records');
  final data=queue.pending.single['payload'] as Map;
  expect(data['provinces'],['Bến Tre','Tiền Giang']);
  expect(data['district'],'');
  expect(data['customer_ids'],isEmpty);
  queue.dispose();
 });
 testWidgets('competitor selects real customer IDs from multiple provinces',(tester)async{
  final queue=OfflineQueue(OfflineSession(),'owner-a','9',factory:newIdbFactoryMemory());
  await tester.pumpWidget(MaterialApp(home:ScopedRecordEditor(
   kind:'competitor',regions:regions,queue:queue,service:const PickerCustomers(),onSaved:(){})));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextFormField).first,'Nhãn đối thủ');
  await tester.tap(find.text('Chọn tỉnh'));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(CheckboxListTile,'Tiền Giang'));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(CheckboxListTile,'Bến Tre'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Xong · 2 tỉnh'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Chọn khách hàng (0 đã chọn)'));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(CheckboxListTile,'VPP A'));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(CheckboxListTile,'VPP B'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Xong · 2 khách'));
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(find.text('Lưu trên máy · Đồng bộ khi có mạng'),240,scrollable:find.byType(Scrollable).first);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Lưu trên máy · Đồng bộ khi có mạng'));
  await tester.pumpAndSettle();
  final payload=queue.pending.single['payload'] as Map;
  expect((payload['customer_ids'] as List).length,2);
  expect(payload['version'],0);
  queue.dispose();
 });
 test('offline scoped draft can be edited without creating a PATCH or losing original operation',()async{
  final factory=newIdbFactoryMemory();
  final queue=OfflineQueue(OfflineSession(),'editor','4',factory:factory);
  const id='33333333-3333-4333-8333-333333333333';
  final payload=<String,dynamic>{
   'client_ref':id,'kind':'support','version':0,
   'provinces':['Bến Tre'],'district':'','customer_ids':<String>[],
   'data':{'title':'Ban đầu'}
  };
  await queue.enqueue('/api/v1/scoped-records',payload);
  await queue.replaceScopedDraft(id,{...payload,'data':{'title':'Đã sửa lúc offline'}});
  final reopened=OfflineQueue(OfflineSession(),'editor','4',factory:factory);
  await reopened.reload();
  expect(reopened.pending.length,1);
  expect(reopened.pending.single['method'],'POST');
  expect(reopened.pending.single['payload']['client_ref'],id);
  expect(reopened.pending.single['payload']['data']['title'],'Đã sửa lúc offline');
  final other=OfflineQueue(OfflineSession(),'different','4',factory:factory);
  await other.reload();
  expect(other.pending,isEmpty);
  await expectLater(reopened.replaceScopedDraft('44444444-4444-4444-8444-444444444444',payload),
    throwsA(isA<ArgumentError>()));
  queue.dispose();reopened.dispose();other.dispose();
 });
 testWidgets('support can link selected customers and save real IDs',(tester)async{
  final queue=OfflineQueue(OfflineSession(),'owner-c','9',factory:newIdbFactoryMemory());
  await tester.pumpWidget(MaterialApp(home:ScopedRecordEditor(
   kind:'support',regions:regions,queue:queue,service:const PickerCustomers(),onSaved:(){})));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextFormField).first,'Đề nghị hàng trưng bày');
  await tester.tap(find.text('Chọn tỉnh'));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(CheckboxListTile,'Tiền Giang'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Xong · 1 tỉnh'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Chọn khách hàng (0 đã chọn)'));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(CheckboxListTile,'VPP A'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Xong · 1 khách'));
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(find.text('Lưu trên máy · Đồng bộ khi có mạng'),240,
   scrollable:find.byType(Scrollable).first);
  await tester.tap(find.text('Lưu trên máy · Đồng bộ khi có mạng'));
  await tester.pumpAndSettle();
  expect(queue.pending.single['payload']['customer_ids'],
   ['11111111-1111-4111-8111-111111111111']);
  queue.dispose();
 });
 testWidgets('pending offline editor submits original client_ref to durable outbox',(tester)async{
  final queue=RecordingScopedDraftQueue();
  const id='33333333-3333-4333-8333-333333333333';
  final initial=SalesRecord(id:id,kind:'support',owner:'owner-d',
   version:0,province:'Bến Tre',
   data:{'title':'Bản nháp cũ','provinces':['Bến Tre'],'customerIds':<String>[]});
  await tester.pumpWidget(MaterialApp(home:ScopedRecordEditor(
   kind:'support',regions:regions,queue:queue,initial:initial,
   service:const PickerCustomers(),onSaved:(){})));
  await tester.pump();
  expect(tester.widget<TextFormField>(find.byType(TextFormField).first).controller!.text,
   'Bản nháp cũ');
  await tester.enterText(find.byType(TextFormField).first,'Bản nháp đã sửa');
  await tester.scrollUntilVisible(find.text('Lưu trên máy · Đồng bộ khi có mạng'),240,
   scrollable:find.byType(Scrollable).first);
  await tester.tap(find.text('Lưu trên máy · Đồng bộ khi có mạng'));
  await tester.pump(const Duration(milliseconds:80));
  expect(queue.savedDraftId,id);
  expect(queue.savedDraft?['client_ref'],id);
  expect(queue.savedDraft?['version'],0);
  expect((queue.savedDraft?['data'] as Map?)?['title'],'Bản nháp đã sửa');
  queue.dispose();
 });

}
