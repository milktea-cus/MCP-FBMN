import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';
import 'package:sales_mien_tay/offline_queue.dart';
import 'package:sales_mien_tay/offline_factory.dart';
import 'package:sales_mien_tay/session.dart';

void main(){
 test('real browser IndexedDB persists draft after reopening and isolates accounts',() async{
  final id=const Uuid().v4();
  final factory=offlineFactory();
  final a=OfflineQueue(SalesSession(),id,'1',factory:factory);
  await a.enqueue('/api/v1/customers',{'name':'IndexedDB test'});
  await a.cache('customers:',[{'name':'Cached'}]);
  (await a.db).close();a.dispose();
  final b=OfflineQueue(SalesSession(),id,'1',factory:factory);
  await b.reload();expect(b.pending.single['payload']['name'],'IndexedDB test');
  expect((await b.cached('customers:')).single['name'],'Cached');
  final other=OfflineQueue(SalesSession(),const Uuid().v4(),'1',factory:factory);
  await other.reload();expect(other.pending,isEmpty);expect(await other.cached('customers:'),isEmpty);
  final revised=OfflineQueue(SalesSession(),id,'2',factory:factory);
  await revised.reload();expect(revised.pending,isEmpty);expect(revised.quarantined,1);
  (await b.db).close();(await other.db).close();(await revised.db).close();
  b.dispose();other.dispose();revised.dispose();
 });
}
