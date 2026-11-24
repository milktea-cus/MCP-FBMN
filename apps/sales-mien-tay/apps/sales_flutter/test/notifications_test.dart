import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:idb_shim/idb_shim.dart';
import 'package:sales_mien_tay/notifications.dart';
import 'package:sales_mien_tay/offline_queue.dart';
import 'package:sales_mien_tay/session.dart';

class FakeInboxSession extends SalesSession {
 bool offline=false;
 bool newer=false;
 bool paged=false;
 int hiddenUnread=0;
 Completer<void>? readGate;
 final recorded=<String>[];
 @override Future<Map<String,dynamic>> get(String path) async {
  if(offline)throw const ApiFailure(503,'offline');
  if(path=='/api/v1/notifications?limit=40&before=42')return {'items':[{'id':'41','title':'Cũ','body':'','created_at':'2026-11-10T08:00:00Z','read_at':null}],'unread_count':2};
  final uri=Uri.parse(path);
  if(uri.path=='/api/v1/notifications'){
   final cutoff=BigInt.tryParse(uri.queryParameters['read_upto']??'');
   final ids=(uri.queryParameters['read_ids']??'').split(',');
   final all=<String>[if(newer)'43','42',if(paged)'41'];
   final count=all.where((id)=>!ids.contains(id)&&!notificationCoveredByWatermark(id,cutoff)).length+
    (cutoff==null?hiddenUnread:0);
   return {'items':[
   if(newer){'id':'43','title':'Việc mới','body':'Sau khi offline đọc tất cả',
    'created_at':'2026-11-12T08:00:00Z','read_at':null},
   {'id':'42','title':'Được giao chỉ tiêu','body':'Mở Field Work để xem.',
    'created_at':'2026-11-11T08:00:00Z','read_at':null}
  ],'unread_count':count,if(paged)'next_cursor':'42',
   'projected_read_count':uri.queryParameters.isNotEmpty};
  }
  if(path=='/api/v1/notifications/config')return {'supported':false,'public_key':null};
  throw StateError('Unexpected GET: $path');
 }
 @override Future<Map<String,dynamic>> post(String path,Map<String,dynamic> data)async{
  recorded.add(path);
  if(readGate!=null)await readGate!.future;
  if(offline)throw const ApiFailure(503,'No network');
  return {'item':{'id':'42','read_at':'2026-11-11T08:00:00Z'}};
 }
}

void main(){
 test('L2 read-all badge excludes unseen older rows while retaining a newer event',()async{
  final session=FakeInboxSession()..hiddenUnread=300;
  final queue=OfflineQueue(session,'worker','1',factory:newIdbFactoryMemory());
  final store=FieldNotificationStore(session,queue);await store.start();
  expect(store.unread,301);
  session.offline=true;await store.markAllRead();
  session.offline=false;session.newer=true;await store.refresh();
  expect(store.unread,1);expect(store.items.first.unread,true);
  store.dispose();queue.dispose();
 });

 test('L2 concurrent read taps decrement once and keep the other unread item',()async{
  final session=FakeInboxSession()..newer=true;
  final queue=OfflineQueue(session,'worker','1',factory:newIdbFactoryMemory());
  final store=FieldNotificationStore(session,queue);await store.start();
  final item=store.items.last;
  session.readGate=Completer<void>();
  final first=store.markRead(item),second=store.markRead(item);
  await Future<void>.delayed(Duration.zero);
  session.readGate!.complete();
  await Future.wait([first,second]);
  expect(store.unread,1);expect(session.recorded.length,1);
  store.dispose();queue.dispose();
 });
 test('L2 refresh preserves loaded pages and offline 503 receipts',()async{
  final session=FakeInboxSession()..paged=true;
  final queue=OfflineQueue(session,'worker','1',factory:newIdbFactoryMemory());
  final store=FieldNotificationStore(session,queue);await store.start();
  await store.loadMore();expect(store.items.map((x)=>x.id),['42','41']);
  session.offline=true;await store.markRead(store.items.last);
  expect(queue.pending.length,1);expect(store.unread,1);
  session.offline=false;await store.refresh();
  expect(store.items.map((x)=>x.id),['42','41']);expect(store.items.last.unread,false);
  expect(store.unread,1);store.dispose();queue.dispose();
 });

 test('inbox badge follows unread and durable offline read receipt survives app restart',()async{
  final db=newIdbFactoryMemory(),session=FakeInboxSession();
  final queue=OfflineQueue(session,'worker-a','7',factory:db);
  final store=FieldNotificationStore(session,queue);
  await store.start();
  expect(store.unread,1);
  expect(store.items.single.title,'Được giao chỉ tiêu');
  session.offline=true;
  await store.markRead(store.items.single);
  expect(store.unread,0);
  expect(queue.pending.single['path'],'/api/v1/notifications/42/read');
  expect(queue.pending.single['namespace'],'worker-a:7');
  final restart=OfflineQueue(session,'worker-a','7',factory:db);
  await restart.reload();
  expect(restart.pending.length,1);
  expect((await restart.cached('notifications')).single['read_at'],isNotNull);
  final stranger=OfflineQueue(session,'worker-b','7',factory:db);
  expect(await stranger.cached('notifications'),isEmpty);
  await stranger.reload();
  expect(stranger.pending,isEmpty);
  store.dispose();queue.dispose();restart.dispose();stranger.dispose();
 });
 test('offline read-all watermark preserves a newer server notification',()async{
  final db=newIdbFactoryMemory(),session=FakeInboxSession();
  final queue=OfflineQueue(session,'worker','scope-1',factory:db);
  final store=FieldNotificationStore(session,queue);await store.start();
  session.offline=true;
  await store.markAllRead();
  expect(store.unread,0);
  expect(queue.pending.where((x)=>x['path']=='/api/v1/notifications/read-all').length,1);
  session.offline=false;session.newer=true;
  await store.refresh();
  expect(store.items.map((x)=>x.id).toList(),['43','42']);
  expect(store.items.first.unread,true);
  expect(store.items.last.unread,false);
  expect(store.unread,1);
  expect(notificationCoveredByWatermark('43',BigInt.from(42)),false);
  expect(notificationCoveredByWatermark('42',BigInt.from(42)),true);
  store.dispose();queue.dispose();
 });
 test('idempotent mark read does not enqueue a second receipt',()async{
  final db=newIdbFactoryMemory(),session=FakeInboxSession();
  final queue=OfflineQueue(session,'worker','1',factory:db);
  final store=FieldNotificationStore(session,queue);await store.start();
  await store.markRead(store.items.single);
  expect(store.unread,0);
  await store.markRead(store.items.single);
  expect(session.recorded.where((x)=>x.endsWith('/read')).length,1);
  expect(queue.pending,isEmpty);
  store.dispose();queue.dispose();
 });
}
