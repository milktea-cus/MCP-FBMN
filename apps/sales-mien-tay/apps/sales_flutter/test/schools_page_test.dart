import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idb_shim/idb_shim_memory.dart';
import 'package:sales_mien_tay/offline_queue.dart';
import 'package:sales_mien_tay/schools_page.dart';
import 'package:sales_mien_tay/session.dart';

class SchoolSession extends SalesSession {
  final requests=<String>[];
  @override Future<Map<String,dynamic>> get(String path)async{
    requests.add(path);
    if(path=='/api/v1/schools/areas')return {'items':[
      {'province':'Long An','districts':['TP Tân An','Huyện Bến Lức']},
    ]};
    if(path.contains('q=khongco'))return {
      'items':<Map<String,dynamic>>[],'total':0,'hasMore':false};
    return {'items':[
      {'source_ref':'THEF4145DA8','name':'Trường Tiểu học An Vĩnh Ngãi',
        'education_level':'Tiểu học','province_old':'Long An',
        'district_old':'TP Tân An','address_text':'Ấp Vĩnh Bình, Long An',
        'maps_search_url':'https://www.google.com/maps/search/?api=1&query=An+Vinh+Ngai',
        'gps_verified':false,'latitude':null,'longitude':null}
    ],'total':1,'page':1,'size':20,'hasMore':false};
  }
}

void main(){
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
}
