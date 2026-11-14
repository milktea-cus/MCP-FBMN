import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sales_mien_tay/main.dart';
import 'package:sales_mien_tay/offline_queue.dart';
import 'package:sales_mien_tay/session.dart';

void main(){
 for(final width in [320.0,360.0,390.0]){
  testWidgets('pending iPhone sync always opens details at $width px',(tester)async{
   tester.view.devicePixelRatio=1;
   tester.view.physicalSize=Size(width,800);
   addTearDown(tester.view.resetPhysicalSize);
   addTearDown(tester.view.resetDevicePixelRatio);
   final queue=OfflineQueue(SalesSession(),'customer-1','revision-1');
   queue.pending=[{
    'path':'/api/v1/sessions/11111111-1111-4111-8111-111111111111',
    'status':'pending',
    'attempts':12,
    'created':DateTime(2026,11,13).millisecondsSinceEpoch,
    'payload':{'client_ref':'22222222-2222-4222-8222-222222222222'},
   }];
   queue.syncing=true;
   queue.lastAttemptAt=DateTime.now().subtract(const Duration(minutes:3));
   var opened=0;
   await tester.pumpWidget(MaterialApp(home:Builder(builder:(context)=>
    Scaffold(body:SyncQueueBanner(
     queue:queue,
     onDetails:(){
      opened++;
      showSyncQueueDetails(context,queue);
     },
    )))));
   expect(find.textContaining('Chờ đồng bộ: 1'),findsOneWidget);
   expect(find.textContaining('Đồng bộ đã treo'),findsOneWidget);
   expect(tester.takeException(),isNull);
   final details=tester.widget<OutlinedButton>(
    find.byKey(const ValueKey('sync-details-button')));
   expect(details.onPressed,isNotNull,
    reason:'Đang đồng bộ không được vô hiệu hóa nút mở lỗi');
   await tester.tap(find.byKey(const ValueKey('sync-details-button')));
   await tester.pumpAndSettle();
   expect(opened,1);
   expect(find.text('Hàng đợi đồng bộ trên máy'),findsOneWidget);
   expect(find.textContaining('Tác vụ chờ: 1'),findsOneWidget);
   expect(find.text('Hoàn tất phiên khảo sát'),findsOneWidget);
   expect(find.text('Thử ngay'),findsOneWidget);
   expect(tester.takeException(),isNull);
   await tester.tap(find.text('Đóng'));
   await tester.pumpAndSettle();
   await tester.tap(find.byKey(const ValueKey('sync-banner-tap')));
   await tester.pumpAndSettle();
   expect(opened,2);
   expect(tester.takeException(),isNull);
   await tester.pumpWidget(const SizedBox.shrink());
   queue.dispose();
  });
 }
}
