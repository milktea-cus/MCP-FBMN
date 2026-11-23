import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:idb_shim/idb_shim.dart';
import 'package:sales_mien_tay/offline_queue.dart';
import 'package:sales_mien_tay/session.dart';

class _ReadyUser extends SalesSession {
  @override
  Future<Map<String,dynamic>> get(String path) async {
    expect(path,'/api/v1/me');
    return {'identity':'photo-sales','scope_revision':'12'};
  }
}

void main(){
  const customerId='22222222-2222-4222-8222-222222222222';
  const mutationId='33333333-3333-4333-8333-333333333333';
  final photo=Uint8List.fromList([255,216,1,2,3,255,217]);
  final thumb=Uint8List.fromList([255,216,4,5,255,217]);
  final checksum=List.filled(64,'a').join();
  final thumbChecksum=List.filled(64,'b').join();

  for(final legacy in [false,true]){
    test('customer PATCH + photo sync ${legacy?'repairs a legacy pending row':'writes an upload ID'}',() async{
      final factory=newIdbFactoryMemory();
      final session=_ReadyUser();
      var patchCalls=0, photoCalls=0;
      final network=MockClient((request)async{
        if(request.method=='PATCH'){
          patchCalls++;
          expect(request.url.path,'/api/v1/customers/$customerId');
          final data=jsonDecode(request.body) as Map<String,dynamic>;
          expect(data['client_ref'],mutationId);
          // Server mutation is confirmed once, then acknowledges the exact
          // same client_ref idempotently on retry after a photo failure.
          return http.Response(jsonEncode({
            'item':{'id':customerId,'version':2,'is_selling':false},
            'idempotent':patchCalls>1,
          }),200,headers:{'content-type':'application/json'});
        }
        expect(request.method,'POST');
        expect(request.url.path,'/api/v1/customers/$customerId/photos');
        photoCalls++;
        expect(request.headers['X-Upload-Id'],mutationId);
        final data=jsonDecode(request.body) as Map<String,dynamic>;
        expect(data['image'],base64Encode(photo));
        expect(data['thumbnail'],base64Encode(thumb));
        expect(data['sha256'],checksum);
        expect(data['thumbnail_sha256'],thumbChecksum);
        if(photoCalls==1){
          return http.Response(jsonEncode({'error':'Ảnh chưa tải lên được'}),503,
            headers:{'content-type':'application/json'});
        }
        return http.Response(jsonEncode({'item':{'id':mutationId}}),201,
          headers:{'content-type':'application/json'});
      });
      final queue=OfflineQueue(session,'photo-sales','12',
        factory:factory,networkClient:network);
      await queue.enqueue('/api/v1/customers/$customerId',{
        'client_ref':mutationId,'version':1,'name':'Nhà sách kiểm thử',
        'address_line':'123 Đường số 1','province':'TP Hồ Chí Minh',
        'district':'Quận 10','category':'nha_sach',
      },method:'PATCH',photo:photo,thumbnail:thumb,sha256:checksum,
        thumbnailSha256:thumbChecksum,mime:'image/jpeg');
      if(legacy){
        // A real iPhone outbox stored the image without upload_id.
        final db=await queue.db;
        final tx=db.transaction('outbox',idbModeReadWrite);
        final row=Map<String,dynamic>.from(queue.pending.single)
          ..remove('upload_id');
        await tx.objectStore('outbox').put(row);
        await tx.completed;
        await queue.reload();
        expect(queue.pending.single.containsKey('upload_id'),isFalse);
      } else {
        expect(queue.pending.single['upload_id'],mutationId);
      }
      await queue.sync();
      expect(patchCalls,1);
      expect(photoCalls,1);
      expect(queue.pending,single);
      expect(queue.pending.single['status'],'pending');
      // Simulates app re-opening with the same IndexedDB/SQLite queue.
      final restarted=OfflineQueue(session,'photo-sales','12',
        factory:factory,networkClient:network);
      await restarted.reload();
      expect(restarted.pending,single);
      await restarted.sync(manual:true);
      expect(patchCalls,2);
      expect(photoCalls,2);
      expect(restarted.pending,isEmpty);
      queue.dispose();
      restarted.dispose();
      network.close();
    });
  }
}
