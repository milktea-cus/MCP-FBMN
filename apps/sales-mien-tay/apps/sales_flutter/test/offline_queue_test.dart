import 'package:flutter_test/flutter_test.dart';
import 'package:idb_shim/idb_shim.dart';
import 'package:sales_mien_tay/offline_queue.dart';
import 'package:sales_mien_tay/session.dart';

class Disconnected extends SalesSession {
 @override Future<Map<String,dynamic>> get(String path) async => throw const ApiFailure(503,'offline');
}
void main(){
 test('durable outbox separates identities and scope revisions',() async {
  final factory=newIdbFactoryMemory();
  final a=OfflineQueue(Disconnected(),'a','1',factory:factory);
  await a.enqueue('/api/v1/records',{'kind':'survey','client_ref':'11111111-1111-4111-8111-111111111111'});
  await a.sync();
  await a.reload();expect(a.pending.length,1);
  final b=OfflineQueue(Disconnected(),'b','1',factory:factory);await b.reload();expect(b.pending,isEmpty);
  final revised=OfflineQueue(Disconnected(),'a','2',factory:factory);await revised.reload();expect(revised.pending,isEmpty);expect(revised.quarantined,1);
  final reopened=OfflineQueue(Disconnected(),'a','1',factory:factory);await reopened.reload();expect(reopened.pending.single['payload']['kind'],'survey');
  a.dispose();b.dispose();revised.dispose();reopened.dispose();
 });
}
