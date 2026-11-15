import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:idb_shim/idb_shim.dart';
import 'offline_queue.dart';

/// Authenticated customer image cache. NOT a shared HTTP, SW or public R2 cache.
/// All keys are isolated by account identity + scope revision.
class CustomerPhotoCache {
 final OfflineQueue queue;
 final int maxBytes,maxEntries;
 final Duration thumbnailTtl,fullTtl;
 final DateTime Function() clock;
 CustomerPhotoCache(this.queue,{
  this.maxBytes=8*1024*1024,this.maxEntries=72,
  this.thumbnailTtl=const Duration(days:14),
  this.fullTtl=const Duration(days:2),
  DateTime Function()? clock,
 }):clock=clock??DateTime.now;

 String get _indexKey=>'${queue.namespace}:customer-photo-index:v2';
 String _key(String customer,String source,String photo,bool thumbnail)=>
  '${queue.namespace}:customer-photo:v2:$customer:$source:$photo:${thumbnail?'t':'f'}';
 String _digest(Uint8List bytes)=>sha256.convert(bytes).toString();
 List<Map<String,dynamic>> _index(Object? row){
  if(row is! Map||row['items'] is! List)return [];
  return (row['items'] as List).whereType<Map>()
   .map((r)=>Map<String,dynamic>.from(r)).toList();
 }

 /// Null on miss, expiry, incompatible version or corrupt bytes.
 Future<Uint8List?> get(String customer,String source,String photo,{
  bool thumbnail=true,String? expectedSha,
 })async{
  if(queue.identity.isEmpty||queue.revision.isEmpty)return null;
  final d=await queue.db,t=d.transaction('cache',idbModeReadWrite),
   store=t.objectStore('cache'),key=_key(customer,source,photo,thumbnail);
  final raw=await store.getObject(key);
  final index=_index(await store.getObject(_indexKey));
  Uint8List? bytes;
  var valid=false;
  if(raw is Map&&raw['version']==2&&raw['customer_id']==customer&&
     raw['source']==source&&raw['photo_id']==photo&&
     raw['expires_at'] is num&&
     (raw['expires_at'] as num).toInt()>clock().millisecondsSinceEpoch&&
     raw['bytes'] is List){
   try{
    bytes=Uint8List.fromList((raw['bytes'] as List).cast<int>());
    valid=bytes.isNotEmpty&&bytes.length<=2*1024*1024&&
      _digest(bytes)==raw['sha256']&&
      (expectedSha==null||expectedSha==raw['sha256']);
   }catch(_){valid=false;}
  }
  index.removeWhere((e)=>e['key']==key);
  if(valid){
   index.add({'key':key,'customer_id':customer,'photo_id':photo,
    'size':bytes!.length,'used_at':clock().millisecondsSinceEpoch});
  }else if(raw!=null){
   await store.delete(key);
  }
  await store.put({'key':_indexKey,'items':index});
  await t.completed;
  return valid?bytes:null;
 }

 /// Immutable bytes only; never store URLs, cookies or tokens.
 /// Enforce global LRU budget inside the account+scope transaction.
 Future<void> put(String customer,String source,String photo,
  Uint8List bytes,{bool thumbnail=true,String? expectedSha})async{
  if(queue.identity.isEmpty||queue.revision.isEmpty||bytes.isEmpty||
     bytes.length>2*1024*1024||bytes.length>maxBytes||maxEntries<=0)return;
  final hash=_digest(bytes);
  if(expectedSha!=null&&expectedSha!=hash)return;
  final now=clock().millisecondsSinceEpoch,key=_key(customer,source,photo,thumbnail);
  final d=await queue.db,t=d.transaction('cache',idbModeReadWrite),
    store=t.objectStore('cache');
  final entries=_index(await store.getObject(_indexKey));
  entries.removeWhere((e)=>e['key']==key);
  await store.put({'key':key,'version':2,'customer_id':customer,
    'source':source,'photo_id':photo,'thumbnail':thumbnail,
    'bytes':bytes.toList(growable:false),'sha256':hash,'stored_at':now,
    'expires_at':now+(thumbnail?thumbnailTtl:fullTtl).inMilliseconds});
  entries.add({'key':key,'customer_id':customer,'photo_id':photo,
    'size':bytes.length,'used_at':now});
  entries.sort((a,b)=>(a['used_at'] as int).compareTo(b['used_at'] as int));
  var total=entries.fold<int>(0,(n,r)=>n+((r['size'] as num?)?.toInt()??0));
  while(entries.length>maxEntries||total>maxBytes){
   final old=entries.removeAt(0);
   total-=((old['size'] as num?)?.toInt()??0);
   if(old['key']!=key)await store.delete(old['key'] as String);
  }
  await store.put({'key':_indexKey,'items':entries});
  await t.completed;
 }

 /// A 403/401 on authenticated media revokes cached thumbnails, gallery
 /// metadata and visits for this customer (including legacy cache keys).
 Future<void> revokeCustomer(String customer)async{
  final d=await queue.db,t=d.transaction('cache',idbModeReadWrite),
   store=t.objectStore('cache');
  final all=await store.getAll(),index=_index(await store.getObject(_indexKey));
  final root='${queue.namespace}:';
  for(final entry in all){
   if(entry is! Map||entry['key'] is! String)continue;
   final key=entry['key'] as String;
   if(key.startsWith('${root}customer-photo:v2:$customer:')||
      key.startsWith('${root}customer-image:$customer:')||
      key=='${root}customer-media:$customer'||
      key=='${root}visits:$customer'){
    await store.delete(key);
   }
  }
  index.removeWhere((e)=>e['customer_id']==customer);
  await store.put({'key':_indexKey,'items':index});
  await t.completed;
 }

 /// Server metadata is authoritative. Retire bytes of deleted photos.
 Future<void> pruneCustomer(String customer,Set<String> allowedIds)async{
  final d=await queue.db,t=d.transaction('cache',idbModeReadWrite),
    store=t.objectStore('cache');
  final entries=_index(await store.getObject(_indexKey));
  final retained=<Map<String,dynamic>>[];
  for(final e in entries){
   if(e['customer_id']==customer&&!allowedIds.contains(e['photo_id'])){
    await store.delete(e['key'] as String);
   }else retained.add(e);
  }
  await store.put({'key':_indexKey,'items':retained});
  await t.completed;
 }

 /// Counts only: never returns image payloads or private metadata.
 Future<Map<String,int>> usage()async{
  final d=await queue.db,t=d.transaction('cache',idbModeReadOnly),
    store=t.objectStore('cache');
  final entries=_index(await store.getObject(_indexKey));
  await t.completed;
  return {'entries':entries.length,
   'bytes':entries.fold<int>(0,(sum,e)=>sum+((e['size'] as num?)?.toInt()??0))};
 }
}
