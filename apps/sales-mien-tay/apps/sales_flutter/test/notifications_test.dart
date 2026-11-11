import 'package:flutter_test/flutter_test.dart';
import 'package:idb_shim/idb_shim.dart';
import 'package:sales_mien_tay/notifications.dart';
import 'package:sales_mien_tay/offline_queue.dart';
import 'package:sales_mien_tay/session.dart';

class FakeInboxSession extends SalesSession {
 bool offline=false;
 final recorded=<String>[];
 @override Future<Map<String,dynamic>> get(String path) async {
  if(offline)throw const ApiFailure(503,'offline');
  if(path=='/api/v1/notifications')return {'items':[{
   'id':'42','title':'Được giao chỉ tiêu','body':'Mở Field Work để xem.',
   'created_at':'2026-11-11T08:00:00Z','read_at':null
  }],'unread_count':1};
  if(path=='/api/v1/notifications/config')return {'supported':false,'public_key':null};
  throw StateError('Unexpected GET: $path');
 }
 @override Future<Map<String,dynamic>> post(String path,Map<String,dynamic> data)async{
  recorded.add(path);
  if(offline)throw StateError('No network');
  return {'item':{'id':'42','read_at':'2026-11-11T08:00:00Z'}};
 }
}

void main(){
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
