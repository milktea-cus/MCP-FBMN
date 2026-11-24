import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:idb_shim/idb_shim.dart';
import 'package:uuid/uuid.dart';
import 'package:sales_mien_tay/offline_queue.dart';
import 'package:sales_mien_tay/session.dart';

class BulkSession extends SalesSession {
 final String owner;
 BulkSession(this.owner);
 @override Future<Map<String,dynamic>> get(String path)async{
  expect(path,'/api/v1/me');
  return {'identity':owner,'scope_revision':'18'};
 }
}

// Real application outbox and cache; the network is a deterministic fixture.
// Orders are deliberately durable local drafts, not silently submitted orders.
Future<void> exerciseBulkReplay(IdbFactory factory)async{
 final uuid=const Uuid(),owner=uuid.v4(),session=BulkSession(owner);
 final acknowledged=<String>{},customerWrites=<String>{},uploads=<String>{};
 final expectedPhotos=<String,List<int>>{};
 final calls=<String,int>{};
 var lostReply=false;
 final mock=MockClient((request)async{
  expect(request.headers['X-Sync-Identity'],owner);
  expect(request.headers['X-Sync-Revision'],'18');
  final photo=request.url.path.endsWith('/photos');
  final payload=jsonDecode(request.body) as Map;
  final id=photo?request.headers['X-Upload-Id']!:payload['client_ref'] as String;
  calls[id]=(calls[id]??0)+1;
  final first=acknowledged.add(id);
  if(photo){
   expect(base64Decode(payload['image'] as String),expectedPhotos[id]);
   uploads.add(id);
  }else{
   expect(request.method,'PATCH');
   customerWrites.add(id);
  }
  // Model an acknowledged remote mutation whose response is lost, so the
  // original operation must survive restart and reuse its idempotency key.
  if(photo&&uploads.length==7&&!lostReply){
   lostReply=true;
   return http.Response('{"error":"connection lost after commit"}',503);
  }
  return http.Response(jsonEncode({'item':{'id':id},'idempotent':!first}),200,
   headers:{'content-type':'application/json'});
 });
 final a=OfflineQueue(session,owner,'18',factory:factory,networkClient:mock);
 final drafts=<Map<String,dynamic>>[];
 for(var i=0;i<20;i++){
  final customer=uuid.v4(),mutation=uuid.v4();
  final payload={'client_ref':mutation,'version':1,'name':'Fixture customer $i'};
  await a.enqueue('/api/v1/customers/$customer',payload,method:'PATCH');
  // Exact duplicate enqueue must keep a single durable operation.
  await a.enqueue('/api/v1/customers/$customer',payload,method:'PATCH');
  for(var j=0;j<3;j++){
   final upload=uuid.v4(),bytes=Uint8List.fromList([255,216,i,j,255,217]);
   expectedPhotos[upload]=bytes;
   await a.enqueue('/api/v1/customers/$customer/photos',{'client_ref':upload},
    photo:bytes,thumbnail:bytes,sha256:List.filled(64,'a').join(),
    thumbnailSha256:List.filled(64,'b').join(),mime:'image/jpeg',dependsOn:[mutation]);
  }
  if(i<5)drafts.add({'id':uuid.v4(),'client_ref':uuid.v4(),'owner_sub':owner,
   'status':'local','version':0,'customer_id':customer,'note':'Fixture draft $i',
   'lines':[{'line_id':uuid.v4(),'product_id':uuid.v4(),'quantity':i+1,'unit':'Quyển'}]});
 }
 await a.cache('order-drafts-v1',drafts);
 await a.reload();expect(a.pending,hasLength(80));expect(acknowledged,isEmpty);
 (await a.db).close();a.dispose();
 final b=OfflineQueue(session,owner,'18',factory:factory,networkClient:mock);
 await b.reload();expect(b.pending,hasLength(80));
 expect(await b.cached('order-drafts-v1'),drafts);
 final other=OfflineQueue(session,uuid.v4(),'18',factory:factory);
 final revoked=OfflineQueue(session,owner,'19',factory:factory);
 await other.reload();await revoked.reload();
 expect(other.pending,isEmpty);expect(await other.cached('order-drafts-v1'),isEmpty);
 expect(revoked.pending,isEmpty);expect(await revoked.cached('order-drafts-v1'),isEmpty);
 expect(revoked.quarantined,80);
 await b.sync();
 expect(lostReply,true);expect(b.pending,isNotEmpty);
 final failed=b.pending.where((r)=>(r['attempts'] as num)>0).single;
 final retryId=(failed['payload'] as Map)['client_ref'] as String;
 expect(calls[retryId],1);
 (await b.db).close();b.dispose();
 final c=OfflineQueue(session,owner,'18',factory:factory,networkClient:mock);
 await c.reload();
 // Dependencies are sorted by durable creation time; allow another pass if
 // a child was encountered before its parent in a same-millisecond batch.
 for(var i=0;i<4&&c.pending.isNotEmpty;i++){await c.sync(manual:true);}
 expect(c.pending,isEmpty);expect(customerWrites,hasLength(20));
 expect(uploads,hasLength(60));expect(acknowledged,hasLength(80));
 expect(calls[retryId],2);expect(calls.values.fold<int>(0,(a,b)=>a+b),81);
 await c.sync(manual:true);expect(calls.values.fold<int>(0,(a,b)=>a+b),81);
 expect(await c.cached('order-drafts-v1'),drafts,
  reason:'No implicit submission/deletion of local order drafts');
 (await c.db).close();(await other.db).close();(await revoked.db).close();
 c.dispose();other.dispose();revoked.dispose();mock.close();
}
