import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:idb_shim/idb_shim.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';
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
class CaptureDialLauncher extends UrlLauncherPlatform {
  String? lastUrl;
  // Ignore uncalled platform-specific members in this fake; only launchUrl is used.
  @override dynamic noSuchMethod(Invocation invocation)=>super.noSuchMethod(invocation);
  @override Future<bool> launchUrl(String url, LaunchOptions options)async{
    lastUrl=url;
    return true;
  }
}

class Disconnected extends SalesSession{
  @override Future<Map<String,dynamic>> get(String path) async=>
    throw const ApiFailure(503,'offline');
}
class CoverSelectionProbe extends OfflineQueue {
  CoverSelectionProbe()
    :super(Disconnected(),'sales-1','scope-1',factory:newIdbFactoryMemory());
  String? lastPhotoId,lastPath,lastMethod;
  Map<String,dynamic>? lastPayload;
  @override
  Future<void> enqueue(String path,Map<String,dynamic> data,{
    Uint8List? photo,Uint8List? thumbnail,String? sha256,
    String? thumbnailSha256,String? mime,String method='POST',
  })async{
    lastPath=path;
    lastPayload=Map<String,dynamic>.from(data);
    lastPhotoId=data['photo_id']?.toString();
    lastMethod=method;
  }
}

class FakeDirectoryService extends FakeService {
  @override Future<List<FieldCustomer>> list({
    void Function(List<FieldCustomer> partial)? onPage,
  })async{
    final rows=[customer()];
    onPage?.call(rows);
    return rows;
  }
}

FieldCustomer customer({String? phone='0912345678'})=>FieldCustomer.fromJson({
  'id':customerId,'name':'Nhà sách Minh Anh','address_line':'2 Lê Lợi',
  'province':'Tiền Giang','district':'Mỹ Tho','category':'nha_sach',
  'owner_sub':'sales-1','status':'active','field_code':'NM0001',
  'phone':phone,'contact_name':'Nguyễn Văn A','version':1,
});
void main(){
  test('phone sanitizer generates tel: URI and rejects invalid values',(){
    expect(customerCallUri('0912 345 678').toString(),'tel:0912345678');
    expect(customerCallUri('+84 (912) 345-678').toString(),'tel:+84912345678');
    for(final bad in <String?>[null,'','abc','https://example.com/0900000000',
      '09+12345678','+84\\r\\nEvil','1234','000000000000000000000']){
      expect(customerCallUri(bad),isNull,reason:'invalid phone: $bad');
    }
  });
  test('cover PATCH sends validated id via scoped customer API',()async{
    late http.Request req;
    final client=MockClient((request)async{
      req=request;
      return http.Response('{"item":{"cover_photo_id":"$secondId"}}',200,
        headers:{'content-type':'application/json'});
    });
    final service=CustomerService('https://example.test','token',
      identity:'sales-1',revision:'scope-1',client:client);
    await service.setCover(customerId,secondId);
    expect(req.method,'PATCH');
    expect(req.url.path,'/api/v1/customers/$customerId/cover');
    expect(jsonDecode(req.body)['photo_id'],secondId);
    expect(req.headers['X-Sync-Identity'],'sales-1');
    expect(req.headers['X-Sync-Revision'],'scope-1');
    client.close();
  });

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
      expect(find.text('Check-in'),findsNothing);
      expect(find.text('Dự kiến doanh thu'),findsNothing);
      expect(find.byType(NestedScrollView),findsOneWidget);
      final sticky=tester.widget<SliverPersistentHeader>(
        find.byType(SliverPersistentHeader).first);
      expect(sticky.pinned,isTrue);
      expect(find.text('Thông tin liên hệ'),findsOneWidget);
      await tester.tap(find.text('Hình ảnh'));
      await tester.pumpAndSettle();
      expect(find.text('Hình ảnh cửa hàng · 2'),findsOneWidget);
      expect(find.textContaining('Ảnh khảo sát'),findsNothing);
      expect(find.byTooltip('Ảnh đại diện hiện tại'),findsOneWidget);
      expect(tester.takeException(),isNull);
    });
  }
  testWidgets('swiping up hides shop header while 3 tabs remain pinned',(tester)async{
    tester.view.devicePixelRatio=1;
    tester.view.physicalSize=const Size(390,700);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home:CustomerDetail(
      service:FakeService(),customer:customer(),
      regions:const RegionCatalog(<String,List<String>>{}))));
    await tester.pump();
    await tester.pump();
    final before=tester.getTopLeft(find.byType(TabBar)).dy;
    expect(before,greaterThan(200));
    await tester.drag(find.byKey(const PageStorageKey('customer-info')),
      const Offset(0,-700));
    await tester.pumpAndSettle();
    final pinned=tester.getTopLeft(find.byType(TabBar)).dy;
    expect(pinned,lessThan(before-100));
    expect(pinned,closeTo(kToolbarHeight+4,4));
    expect(find.text('Thông tin'),findsOneWidget);
    await tester.tap(find.text('Hình ảnh'));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.byType(TabBar)).dy,closeTo(kToolbarHeight+4,4));
    expect(tester.takeException(),isNull);
  });
  testWidgets('call button launches sanitized telephone URI',(tester)async{
    final original=UrlLauncherPlatform.instance;
    final launcher=CaptureDialLauncher();
    UrlLauncherPlatform.instance=launcher;
    addTearDown(()=>UrlLauncherPlatform.instance=original);
    await tester.pumpWidget(MaterialApp(home:CustomerDetail(
      service:FakeService(),customer:customer(),
      regions:const RegionCatalog(<String,List<String>>{}))));
    await tester.pump();
    await tester.tap(find.text('Gọi điện'));
    await tester.pump();
    expect(launcher.lastUrl,'tel:0912345678');
    expect(tester.takeException(),isNull);
  });
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
  testWidgets('select cover image in gallery persists the chosen photo',(tester)async{
    tester.view.devicePixelRatio=1;
    tester.view.physicalSize=const Size(390,1450);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final queue=CoverSelectionProbe();
    await tester.pumpWidget(MaterialApp(home:CustomerDetail(
      service:FakeService(),customer:customer(),
      regions:const RegionCatalog(<String,List<String>>{}),queue:queue)));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.text('Hình ảnh'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Ảnh đại diện hiện tại'),findsOneWidget);
    final choose=find.byTooltip('Chọn làm ảnh đại diện');
    expect(choose,findsOneWidget);
    await tester.tap(choose);
    await tester.pump();
    await tester.pump();
    expect(queue.lastPath,'/api/v1/customers/$customerId/cover');
    expect(queue.lastPhotoId,secondId);
    expect(queue.lastMethod,'PATCH');
    await tester.pumpWidget(const SizedBox.shrink());
    queue.dispose();
  });

  testWidgets('P0-F customer editor previews manual point then stores provenance offline',(tester)async{
    tester.view.devicePixelRatio=1;
    tester.view.physicalSize=const Size(390,900);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final queue=CoverSelectionProbe();
    await tester.pumpWidget(MaterialApp(home:CustomerEditor(
      service:FakeService(),customer:customer(),queue:queue,
      regions:const RegionCatalog({'Tiền Giang':['Mỹ Tho']}))));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Nhập tọa độ'),300,scrollable:find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nhập tọa độ'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byKey(const Key('customer-location-lat')),300,scrollable:find.byType(Scrollable).first);
    await tester.enterText(find.byKey(const Key('customer-location-lat')),'10.345');
    await tester.enterText(find.byKey(const Key('customer-location-lon')),'106.123');
    await tester.scrollUntilVisible(find.text('Xem trước tọa độ'),300,scrollable:find.byType(Scrollable).first);
    await tester.tap(find.text('Xem trước tọa độ'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Tọa độ mới: 10.345000, 106.123000'),findsOneWidget);
    await tester.tap(find.text('Xác nhận vị trí'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Lưu điểm bán'),300,scrollable:find.byType(Scrollable).first);
    await tester.tap(find.text('Lưu điểm bán'));
    await tester.pump();
    expect(queue.lastPath,'/api/v1/customers/$customerId');
    expect(queue.lastMethod,'PATCH');
    expect(queue.lastPayload?['location_source'],'manual');
    expect(queue.lastPayload?['location_consent'],isTrue);
    expect(queue.lastPayload?['latitude'],10.345);
    expect(queue.lastPayload?['longitude'],106.123);
    expect(queue.lastPayload?['location_accuracy_m'],isNull);
    expect(queue.lastPayload?.containsKey('location_override_confirmed'),isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
    queue.dispose();
  });
  testWidgets('P0-F protected GPS cannot be replaced with manual/link',(tester)async{
    final existing=FieldCustomer.fromJson({
      ...customer().toJson(),'latitude':10.35,'longitude':106.36,
      'location_source':'gps','location_accuracy_m':17.0,
    });
    final queue=CoverSelectionProbe();
    await tester.pumpWidget(MaterialApp(home:CustomerEditor(
      service:FakeService(),customer:existing,queue:queue,
      regions:const RegionCatalog({'Tiền Giang':['Mỹ Tho']}))));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.widgetWithText(ChoiceChip,'Nhập tọa độ'),300,scrollable:find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    final manual=tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip,'Nhập tọa độ'));
    final link=tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip,'Dán link Maps'));
    expect(manual.onSelected,isNull);
    expect(link.onSelected,isNull);
    await tester.scrollUntilVisible(find.text('Lưu điểm bán'),300,scrollable:find.byType(Scrollable).first);
    await tester.tap(find.text('Lưu điểm bán'));
    await tester.pump();
    expect(queue.lastPayload?.containsKey('latitude'),isFalse);
    expect(queue.lastPayload?.containsKey('longitude'),isFalse);
    expect(queue.lastPayload?.containsKey('location_source'),isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
    queue.dispose();
  });
  testWidgets('P0-F GPS consent refusal cannot save a fake position',(tester)async{
    tester.view.devicePixelRatio=1;
    tester.view.physicalSize=const Size(390,1900);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final queue=CoverSelectionProbe();
    await tester.pumpWidget(MaterialApp(home:CustomerEditor(
      service:FakeService(),customer:customer(),queue:queue,
      regions:const RegionCatalog({'Tiền Giang':['Mỹ Tho']}))));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Lấy GPS thiết bị và xem trước'),300,scrollable:find.byType(Scrollable).first);
    await tester.tap(find.text('Lấy GPS thiết bị và xem trước'));
    await tester.pumpAndSettle();
    expect(find.text('Sử dụng vị trí'),findsOneWidget);
    await tester.tap(find.text('Không'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Lưu điểm bán'),300,scrollable:find.byType(Scrollable).first);
    await tester.tap(find.text('Lưu điểm bán'));
    await tester.pump();
    expect(queue.lastPayload?.containsKey('latitude'),isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
    queue.dispose();
  });
  testWidgets('P0-F directory directions use address with no GPS',(tester)async{
    tester.view.devicePixelRatio=1;
    tester.view.physicalSize=const Size(360,760);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final original=UrlLauncherPlatform.instance;
    final launcher=CaptureDialLauncher();
    UrlLauncherPlatform.instance=launcher;
    addTearDown(()=>UrlLauncherPlatform.instance=original);
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:CustomerDirectoryPage(
      service:FakeDirectoryService(),
      regions:const RegionCatalog({'Tiền Giang':['Mỹ Tho']})))));
    await tester.pumpAndSettle();
    // The compact card hides address/GPS details, but directions still fall
    // back to the customer's stored address when there is no coordinate.
    expect(find.textContaining('2 Lê Lợi'),findsNothing);
    expect(find.byTooltip('Chỉ đường'),findsOneWidget);
    await tester.tap(find.byTooltip('Chỉ đường'));
    await tester.pump();
    expect(launcher.lastUrl,contains('maps/dir/'));
    expect(Uri.parse(launcher.lastUrl!).queryParameters['destination'],
      contains('2 Lê Lợi'));
    expect(tester.takeException(),isNull);
  });

  test('cover selection uses a durable account-scoped PATCH operation',()async{
    final factory=newIdbFactoryMemory();
    final queue=OfflineQueue(Disconnected(),'sales-1','scope-1',factory:factory);
    await queue.enqueue('/api/v1/customers/$customerId/cover',
      {'photo_id':secondId},method:'PATCH');
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
    queue.dispose();restored.dispose();other.dispose();
  });
}
