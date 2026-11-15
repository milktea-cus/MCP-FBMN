import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:idb_shim/idb_shim.dart';
import 'package:sales_mien_tay/customer_photo_cache.dart';
import 'package:sales_mien_tay/offline_queue.dart';
import 'package:sales_mien_tay/session.dart';

class NoNetworkSession extends SalesSession{
 @override Future<Map<String,dynamic>> get(String path)async=>
  throw const ApiFailure(503,'offline');
}

void main(){
 const customer='11111111-1111-4111-8111-111111111111';
 const a='22222222-2222-4222-8222-222222222222';
 const b='33333333-3333-4333-8333-333333333333';
 test('P1-N warm read, checksum, TTL and LRU eviction, no credential storage',()async{
  final factory=newIdbFactoryMemory(),queue=OfflineQueue(
   NoNetworkSession(),'sales-a','scope-1',factory:factory);
  var now=DateTime(2026,11,15);
  final cache=CustomerPhotoCache(queue,maxBytes:8,maxEntries:2,
   thumbnailTtl:const Duration(days:2),clock:()=>now);
  final first=Uint8List.fromList([1,2,3,4]);
  final second=Uint8List.fromList([5,6,7,8]);
  await cache.put(customer,'customer',a,first);
  expect(await cache.get(customer,'customer',a),first);
  now=now.add(const Duration(seconds:1));
  await cache.put(customer,'customer',b,second);
  expect((await cache.usage())['bytes'],8);
  now=now.add(const Duration(seconds:1));
  expect(await cache.get(customer,'customer',a),first);
  final third='44444444-4444-4444-8444-444444444444';
  now=now.add(const Duration(seconds:1));
  await cache.put(customer,'customer',third,Uint8List.fromList([9,10,11,12]));
  expect(await cache.get(customer,'customer',b),isNull,
   reason:'Least recently used thumbnail evicted before the warm one');
  expect(await cache.get(customer,'customer',a),first);
  final other=OfflineQueue(NoNetworkSession(),'sales-b','scope-1',factory:factory);
  final changed=OfflineQueue(NoNetworkSession(),'sales-a','scope-2',factory:factory);
  expect(await CustomerPhotoCache(other).get(customer,'customer',a),isNull);
  expect(await CustomerPhotoCache(changed).get(customer,'customer',a),isNull);
  now=now.add(const Duration(days:3));
  expect(await cache.get(customer,'customer',a),isNull);
  expect((await cache.usage())['entries'],lessThanOrEqualTo(1));
  queue.dispose();other.dispose();changed.dispose();
 });
 test('P1-N invalid checksum is a miss, corrupted bytes are purged',()async{
  final factory=newIdbFactoryMemory(),queue=OfflineQueue(
   NoNetworkSession(),'sales-a','r1',factory:factory);
  final cache=CustomerPhotoCache(queue);
  final bytes=Uint8List.fromList([2,3,4,5]);
  await cache.put(customer,'customer',a,bytes,expectedSha:'wrong');
  expect((await cache.usage())['entries'],0);
  await cache.put(customer,'customer',a,bytes);
  expect(await cache.get(customer,'customer',a,expectedSha:'wrong'),isNull);
  await cache.put(customer,'customer',a,bytes);
  final d=await queue.db,tx=d.transaction('cache',idbModeReadWrite);
  final key='${queue.namespace}:customer-photo:v2:$customer:customer:$a:t';
  final raw=Map<String,dynamic>.from(
   await tx.objectStore('cache').getObject(key) as Map);
  await tx.objectStore('cache').put({...raw,'bytes':[8,8,8]});
  await tx.completed;
  expect(await cache.get(customer,'customer',a),isNull);
  queue.dispose();
 });
 test('P1-N 403 purge removes customer photos, metadata and old unbounded rows',()async{
  final factory=newIdbFactoryMemory(),queue=OfflineQueue(
   NoNetworkSession(),'sales-a','r1',factory:factory);
  final cache=CustomerPhotoCache(queue);
  await queue.cache('customer-media:$customer',[{'id':a}]);
  await queue.cache('visits:$customer',[{'id':'gps'}]);
  await queue.cache('customer-image:$customer:customer:$a:thumb',
   [{'bytes':[1,2,3]}]);
  await cache.put(customer,'customer',a,Uint8List.fromList([1,2,3]));
  await cache.revokeCustomer(customer);
  expect(await cache.get(customer,'customer',a),isNull);
  expect((await cache.usage())['entries'],0);
  expect(await queue.cached('customer-media:$customer'),isEmpty);
  expect(await queue.cached('visits:$customer'),isEmpty);
  expect(await queue.cached('customer-image:$customer:customer:$a:thumb'),isEmpty);
  final otherCustomer='55555555-5555-4555-8555-555555555555';
  await cache.put(otherCustomer,'customer',a,Uint8List.fromList([4,5]));
  await cache.pruneCustomer(otherCustomer,{}); // deleted on server
  expect(await cache.get(otherCustomer,'customer',a),isNull);
  queue.dispose();
 });
}
