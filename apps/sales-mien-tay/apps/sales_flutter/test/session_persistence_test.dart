import 'package:flutter_test/flutter_test.dart';
import 'package:sales_mien_tay/session.dart';

/// Simulates the process being killed and relaunched with the same encrypted
/// credential store. No real session token is persisted or logged by this test.
class _MemorySecretStore implements SessionSecretStore {
 String? saved;
 int readFailures=0;
 @override Future<String?> read() async {
  if(readFailures>0){readFailures--;throw StateError('test-only transient read');}
  return saved;
 }
 @override Future<void> write(String value) async {saved=value;}
 @override Future<void> delete() async {saved=null;}
}
void main(){
 test('Android restart restores the same session from the secure store',()async{
  final store=_MemorySecretStore()..saved='synthetic-cookie-not-real';
  final first=SalesSession(store:store);
  await first.restore();
  expect(first.cookie,'synthetic-cookie-not-real');
  final afterRestart=SalesSession(store:store);
  await afterRestart.restore();
  expect(afterRestart.cookie,'synthetic-cookie-not-real');
 });
 test('transient Keystore read does not log out and can be retried',()async{
  final store=_MemorySecretStore()
   ..saved='synthetic-cookie-not-real'
   ..readFailures=1;
  final session=SalesSession(store:store);
  await session.restore();
  expect(session.cookie,'synthetic-cookie-not-real');
  expect(store.saved,'synthetic-cookie-not-real');
 });
 test('a failed credential read never deletes persistent credentials',()async{
  final store=_MemorySecretStore()
   ..saved='synthetic-cookie-not-real'
   ..readFailures=2;
  final session=SalesSession(store:store);
  await expectLater(session.restore(),throwsStateError);
  expect(store.saved,'synthetic-cookie-not-real');
  await session.restore();
  expect(session.cookie,'synthetic-cookie-not-real');
 });
 test('explicit logout clears only the test credential',()async{
  final store=_MemorySecretStore()..saved='synthetic-cookie-not-real';
  final session=SalesSession(store:store);
  await session.restore();
  await session.clear();
  expect(session.cookie,isEmpty);
  expect(store.saved,isNull);
 });
}
