import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:idb_shim/idb_shim.dart';
import 'package:sales_mien_tay/customers.dart';
import 'package:sales_mien_tay/models.dart';
import 'package:sales_mien_tay/offline_queue.dart';
import 'package:sales_mien_tay/session.dart';

const customerId='11111111-1111-4111-8111-111111111111';
const coverId='22222222-2222-4222-8222-222222222222';
const secondId='33333333-3333-4333-8333-333333333333';
const surveyId='44444444-4444-4444-8444-444444444444';
const images=<Map<String,dynamic>>[
  {'id':coverId,'source':'customer','kind':'store','is_cover':true,
    'captured_at':'2026-11-10T11:00:00Z'},
  {'id':secondId,'source':'customer','kind':'store','is_cover':false,
    'captured_at':'2026-11-09T11:00:00Z'},
  {'id':surveyId,'source':'survey','kind':'front','is_cover':false,
    'captured_at':'2026-11-11T11:00:00Z'},
];

class FakeService extends CustomerService {
  FakeService() : super('https://example.test','',identity:'sales-1',
    client:MockClient((_)async=>http.Response(
      '{"items":[],"next_cursor":null}',200,
      headers:{'content-type':'application/json'})));
  @override Future<List<Map<String,dynamic>>> media(String id)async=>images;
  @override Future<List<Map<String,dynamic>>> visits(String id)async=>[];
  @override Future<Uint8List> mediaBytes(String id,Map<String,dynamic> media,
    {bool thumbnail=true})async=>base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/hoUAAAAASUVORK5CYII=');
}
class Disconnected extends SalesSession{
  @override Future<Map<String,dynamic>> get(String path) async=>
    throw const ApiFailure(503,'offline');
}
FieldCustomer customer({String? phone='0912345678'})=>FieldCustomer.fromJson({
  'id':customerId,'name':'Nhà sách Minh Anh','address_line':'2 Lê Lợi',
  'province':'Tiền Giang','district':'Mỹ Tho','category':'nha_sach',
  'owner_sub':'sales-1','status':'active','field_code':'NM0001',
  'phone':phone,'contact_name':'Nguyễn Văn A','version':1,
});
void main(){
  for(final width in [360.0,390.0,780.0]){
    testWidgets('P0-E customer uses exactly three compact tabs at $width',(tester)async{
      tester.view.devicePixelRatio=1;
      tester.view.physicalSize=Size(width,844);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(home:CustomerDetail(
        service:FakeService(),customer:customer(),
        regions:const RegionCatalog(<String,List<String>>{}))));
      await tester.pump();
      await tester.pump();
      expect(find.byType(TabBar),findsOneWidget);
      expect(find.text('Thông tin'),findsOneWidget);
      expect(find.text('Sản phẩm'),findsOneWidget);
      expect(find.text('Hình ảnh'),findsOneWidget);
      expect(find.text('Gọi điện'),findsOneWidget);
      expect(find.text('Google Maps'),findsOneWidget);
      expect(find.text('Phiên khảo sát'),findsNothing);
      expect(find.text('Thông tin liên hệ'),findsOneWidget);
      await tester.tap(find.text('Hình ảnh'));
      await tester.pumpAndSettle();
      expect(find.text('Hình ảnh cửa hàng · 2'),findsOneWidget);
      expect(find.textContaining('Ảnh khảo sát'),findsNothing);
      expect(find.byTooltip('Ảnh đại diện hiện tại'),findsOneWidget);
      expect(tester.takeException(),isNull);
    });
  }
  testWidgets('no phone disables call without disabling Google Maps',(tester)async{
    await tester.pumpWidget(MaterialApp(home:CustomerDetail(
      service:FakeService(),customer:customer(phone:null),
      regions:const RegionCatalog(<String,List<String>>{}))));
    await tester.pump();
    final call=tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton,'Gọi điện'));
    final map=tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton,'Google Maps'));
    expect(call.onPressed,isNull);
    expect(map.onPressed,isNotNull);
    expect(tester.takeException(),isNull);
  });
  testWidgets('cover selection is an account-scoped durable PATCH operation',(tester)async{
    final factory=newIdbFactoryMemory();
    final queue=OfflineQueue(Disconnected(),'sales-1','scope-1',factory:factory);
    await tester.pumpWidget(MaterialApp(home:CustomerDetail(
      service:FakeService(),customer:customer(),
      regions:const RegionCatalog(<String,List<String>>{}),queue:queue)));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.text('Hình ảnh'));
    await tester.pumpAndSettle();
    // The second dated group is below the phone viewport; scroll before tapping.
    await tester.drag(find.byKey(const PageStorageKey('customer-photos')),
      const Offset(0,-520));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('Chọn làm ảnh đại diện'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Chọn làm ảnh đại diện'));
    await tester.pumpAndSettle();
    expect(queue.pending.length,1);
    expect(queue.pending.single['path'],'/api/v1/customers/$customerId/cover');
    expect(queue.pending.single['method'],'PATCH');
    expect(queue.pending.single['payload']['photo_id'],secondId);
    final restored=OfflineQueue(Disconnected(),'sales-1','scope-1',factory:factory);
    await restored.reload();
    expect(restored.pending.single['payload']['photo_id'],secondId);
    final other=OfflineQueue(Disconnected(),'sales-2','scope-1',factory:factory);
    await other.reload();
    expect(other.pending,isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
    queue.dispose();restored.dispose();other.dispose();
  });
}
