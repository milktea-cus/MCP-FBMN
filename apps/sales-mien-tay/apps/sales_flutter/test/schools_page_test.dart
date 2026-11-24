import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idb_shim/idb_shim.dart';
import 'package:sales_mien_tay/offline_queue.dart';
import 'package:sales_mien_tay/schools_page.dart';
import 'package:sales_mien_tay/session.dart';

class SchoolSession extends SalesSession {
  final requests=<String>[];
  bool offline=false;
  @override Future<Map<String,dynamic>> get(String path)async{
    requests.add(path);
    if(offline)throw const ApiFailure(503,'offline');
    if(path=='/api/v1/schools/areas')return {'items':[
      {'province':'Long An','districts':['TP Tân An','Huyện Bến Lức']},
    ]};
    if(path.contains('q=khongco'))return {
      'items':<Map<String,dynamic>>[],'total':0,'hasMore':false};
    if(path.contains('level=2')||path.contains('level=3'))return {
      'items':[
        {'source_ref':'SCHOOL-MIXED-23','name':'Trường liên cấp kiểm thử',
          'education_level':'THCS & THPT','province_old':'Long An',
          'district_old':'TP Tân An','address_text':'Long An',
          'maps_search_url':'https://www.google.com/maps/search/?api=1&query=Test',
          'gps_verified':false,'latitude':null,'longitude':null}
      ],'total':1,'page':1,'size':20,'hasMore':false};
    return {'items':[
      {'source_ref':'THEF4145DA8','name':'Trường Tiểu học An Vĩnh Ngãi',
        'education_level':'Tiểu học','province_old':'Long An',
        'district_old':'TP Tân An','address_text':'Ấp Vĩnh Bình, Long An',
        'maps_search_url':'https://www.google.com/maps/search/?api=1&query=An+Vinh+Ngai',
        'gps_verified':false,'latitude':null,'longitude':null}
    ],'total':1,'page':1,'size':20,'hasMore':false};
  }
}

class EmptySchoolCache extends OfflineQueue {
 EmptySchoolCache(SalesSession session):super(session,'school-empty','1',factory:newIdbFactoryMemory());
 @override Future<List<Map<String,dynamic>>> cached(String key)async=>[];
 @override Future<Map<String,dynamic>?> directoryPage(String key)async=>
  key=='schools:page:v2:_:_:_:1'?{'items':<Map<String,dynamic>>[],'total':0,'has_more':false}:null;
}

void main(){
  testWidgets('L3 saved empty school page remains a valid offline result',(tester)async{
   final session=SchoolSession()..offline=true;
   // The actual storage transaction is tested in offline_queue_test and
   // the real Chrome suite; isolate widget rendering from fake-clock DB I/O.
   final queue=EmptySchoolCache(session);
   await tester.pumpWidget(MaterialApp(home:Scaffold(body:SchoolDirectoryPage(queue:queue,session:session))));
   await tester.pumpAndSettle();
   expect(session.requests.any((p)=>p.startsWith('/api/v1/schools?')),isTrue);
   expect(find.text('Không có mạng, đang xem dữ liệu đã lưu.'),findsOneWidget);
   expect(find.text('Tải thêm trường'),findsNothing);
   await tester.pumpWidget(const SizedBox.shrink());queue.dispose();
  });
  testWidgets('Trường Học shows old-geography cards, unverified Maps and search',
    (tester)async{
      final session=SchoolSession();
      final queue=OfflineQueue(session,'sales-school','1',
        factory:newIdbFactoryMemory());
      await tester.pumpWidget(MaterialApp(home:Scaffold(body:
        SchoolDirectoryPage(queue:queue,session:session))));
      await tester.pumpAndSettle();
      expect(find.text('Trường Tiểu học An Vĩnh Ngãi'),findsOneWidget);
      expect(find.textContaining('Long An · TP Tân An'),findsOneWidget);
      expect(find.textContaining('chưa xác minh'),findsWidgets);
      expect(find.byIcon(Icons.directions_outlined),findsOneWidget);
      await tester.enterText(find.byType(TextField),'khongco');
      await tester.pump(const Duration(milliseconds:400));
      await tester.pumpAndSettle();
      expect(find.text('Không tìm thấy trường trong phạm vi của bạn'),
        findsOneWidget);
      expect(session.requests.any((p)=>p.contains('q=khongco')),isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
      queue.dispose();
    });

  testWidgets('School grade filter includes multi-level institutions',
    (tester)async{
      final session=SchoolSession();
      final queue=OfflineQueue(session,'sales-school-grade','1',
        factory:newIdbFactoryMemory());
      await tester.pumpWidget(MaterialApp(home:Scaffold(body:
        SchoolDirectoryPage(queue:queue,session:session))));
      await tester.pumpAndSettle();
      expect(find.text('Cấp 1 · Tiểu học'),findsOneWidget);
      await tester.tap(find.text('Tất cả cấp'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cấp 2 · THCS').last);
      await tester.pumpAndSettle();
      expect(session.requests.any((p)=>p.contains('level=2')),isTrue);
      expect(find.text('Trường liên cấp kiểm thử'),findsOneWidget);
      expect(find.text('Liên cấp 2–3 · THCS & THPT'),findsOneWidget);
      await tester.tap(find.text('Cấp 2 · THCS').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cấp 3 · THPT').last);
      await tester.pumpAndSettle();
      expect(session.requests.any((p)=>p.contains('level=3')),isTrue);
      expect(find.text('Trường liên cấp kiểm thử'),findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      queue.dispose();
    });
}
