import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:idb_shim/idb_shim.dart';
import 'package:uuid/uuid.dart';
import 'offline_factory.dart';
import 'session.dart';

/// A draft and its outbox operation are the same durable row. No credentials
/// are stored. Every queue read/write is scoped to identity + scope revision.
Future<Database>? _sharedDatabase;
Future<Database> openOfflineDatabase([IdbFactory? factory]){
 Future<Database> open()=> (factory??offlineFactory()).open('filed_work_offline_v1',version:1,onUpgradeNeeded:(e){final store=e.database.createObjectStore('outbox',keyPath:'key');store.createIndex('account','account');e.database.createObjectStore('cache',keyPath:'key');});
 return factory==null?(_sharedDatabase??=open()):open();
}
class OfflineQueue extends ChangeNotifier {
 final SalesSession session;
 final String identity,revision;
 final IdbFactory? factory;
 OfflineQueue(this.session,this.identity,this.revision,{this.factory});
 Future<Database>? _opening;
 bool _closed=false, syncing=false;
 String? error;
 List<Map<String,dynamic>> pending=[];
 int quarantined=0;
 Timer? _timer;
 String get namespace=>'$identity:$revision';
 Future<Database> get db=>_opening??=openOfflineDatabase(factory);
 Future<void> cache(String key,List<Map<String,dynamic>> items) async{
  final d=await db;final t=d.transaction('cache',idbModeReadWrite);
  await t.objectStore('cache').put({'key':'$namespace:$key','items':items});await t.completed;
 }
 Future<List<Map<String,dynamic>>> cached(String key) async{
  final d=await db;final t=d.transaction('cache',idbModeReadOnly);
  final row=await t.objectStore('cache').getObject('$namespace:$key');await t.completed;
  return row==null?[]:((row as Map)['items'] as List).map((r)=>Map<String,dynamic>.from(r as Map)).toList();
 }
 void _notify(){if(!_closed)notifyListeners();}
 Future<List<Map<String,dynamic>>> rows() async{
  final d=await db;
  final t=d.transaction('outbox',idbModeReadOnly);
  final list=await t.objectStore('outbox').index('account').getAll(identity);
  await t.completed;
  return list.map((v)=>Map<String,dynamic>.from(v as Map)).toList();
 }
 Future<void> reload() async{
  final all=await rows();
  pending=all.where((r)=>r['namespace']==namespace).toList()..sort((a,b)=>(a['created'] as int).compareTo(b['created'] as int));
  quarantined=all.length-pending.length;
  _notify();
 }
 Future<void> _put(Map<String,dynamic> row) async{
  final d=await db;
  final t=d.transaction('outbox',idbModeReadWrite);
  await t.objectStore('outbox').put(row);await t.completed;
 }
 Future<void> _updateIfPresent(Map<String,dynamic> row) async{
  final d=await db;final t=d.transaction('outbox',idbModeReadWrite);final store=t.objectStore('outbox');
  if(await store.getObject(row['key'] as String)!=null)await store.put(row);await t.completed;
 }
 Future<void> _remove(String key) async{
  final d=await db;
  final t=d.transaction('outbox',idbModeReadWrite);
  await t.objectStore('outbox').delete(key);await t.completed;
 }
 Future<void> enqueue(String path,Map<String,dynamic> data,{Uint8List? photo,String? mime,String method='POST'}) async{
  if(_closed)throw StateError('Phiên đã đóng');
  if(!['/api/v1/records','/api/v1/customers'].contains(path)&&!RegExp(r'^/api/v1/records/[a-f0-9-]{36}[a-f0-9-]{36}(/visits|/photos)?$').hasMatch(path))throw ArgumentError('Unsupported offline operation');
  final id=data['client_ref']?.toString()??const Uuid().v4();
  if(photo!=null&&(photo.isEmpty||photo.length>5*1024*1024))throw StateError('Ảnh phải nhỏ hơn 5 MB');
  await _put({'key':'$namespace:$id','namespace':namespace,'account':identity,'created':DateTime.now().millisecondsSinceEpoch,
    'path':path,'method':method,'payload':{...data,'client_ref':id},'status':'pending','attempts':0,
    if(photo!=null)'photo':photo,if(mime!=null)'mime':mime,'upload_id':const Uuid().v4()});
  await reload();
  if(_timer!=null)unawaited(sync());
 }
 Future<void> start() async{
  try{await reload();}catch(e){error='Không mở được bộ nhớ máy: $e';_notify();return;}
  if(_closed)return;
  _timer=Timer.periodic(const Duration(seconds:30),(_)=>unawaited(sync()));
  unawaited(sync());
 }
 Future<void> sync() async{
  if(_closed||syncing)return;
  syncing=true;error=null;_notify();
  try{
   await reload();
   if(pending.isEmpty)return;
   final me=await session.get('/api/v1/me');
   if(_closed||me['identity']!=identity||me['scope_revision'].toString()!=revision){error='Quyền đã thay đổi. Dữ liệu cũ được cách ly.';return;}
   for(final row in List.of(pending)){
    if(_closed)break;
    if(row['status']=='blocked')continue;
    try{
     final payload=Map<String,dynamic>.from(row['payload'] as Map);
     final headers={...sessionHeaders(session.cookie),'X-Sync-Identity':identity,'X-Sync-Revision':revision};
     final uri=session.uri(row['path'] as String);
     if((row['path'] as String).endsWith('/photos')){
      final bytes=Uint8List.fromList((row['photo'] as List).cast<int>());
      final upload=await http.post(uri,headers:{...headers,'Content-Type':row['mime'] as String,'X-Upload-Id':row['upload_id'] as String},body:bytes).timeout(const Duration(seconds:30));
      decodeApi(upload);await _remove(row['key'] as String);continue;
     }
     final response=await (row['method']=='PATCH'?http.patch(uri,headers:headers,body:jsonEncode(payload)):http.post(uri,headers:headers,body:jsonEncode(payload))).timeout(const Duration(seconds:30));
     final result=decodeApi(response);
     final item=result['item'] as Map;
     if(row['photo']!=null){
      final bytes=Uint8List.fromList((row['photo'] as List).cast<int>());
      if(_closed)break;
      final upload=await http.post(session.uri('/api/v1/customers/${item['id']}/photos'),
       headers:{...headers,'Content-Type':row['mime'] as String,'X-Upload-Id':row['upload_id'] as String},body:bytes).timeout(const Duration(seconds:30));
      decodeApi(upload);
     }
     await _remove(row['key'] as String);
    }catch(e){
     final blocked=e is ApiFailure&&[400,403,404,409,413,415,422].contains(e.status);
     await _updateIfPresent({...row,'status':blocked?'blocked':'pending','attempts':(row['attempts'] as int)+1,'error':e.toString()});
     error=e.toString();
     if(!blocked)break;
    }
   }
  }catch(e){error=e.toString();}
  finally{try{await reload();}catch(e){error=e.toString();}syncing=false;_notify();}
 }
 @override void dispose(){_closed=true;_timer?.cancel();super.dispose();}
}
class OfflineLease {
 static const duration=Duration(hours:12);
 static Future<void> remember(Map<String,dynamic> me,Map<String,List<String>> districts) async{
  final db=await openOfflineDatabase();final t=db.transaction('cache',idbModeReadWrite);
  if(await t.objectStore('cache').getObject('logout_pending')!=null){await t.completed;return;}
  await t.objectStore('cache').put({'key':'active_lease','me':me,'districts':districts,'expires':DateTime.now().add(duration).millisecondsSinceEpoch});await t.completed;
 }
 static Future<Map<String,dynamic>?> read() async{
  final db=await openOfflineDatabase();final t=db.transaction('cache',idbModeReadOnly);final row=await t.objectStore('cache').getObject('active_lease');await t.completed;
  if(row==null)return null;final v=Map<String,dynamic>.from(row as Map);
  return (v['expires'] as int)>DateTime.now().millisecondsSinceEpoch?v:null;
 }
 static Future<void> markLogout() async{
  final db=await openOfflineDatabase();final t=db.transaction('cache',idbModeReadWrite);final s=t.objectStore('cache');await s.delete('active_lease');await s.put({'key':'logout_pending'});await t.completed;
 }
 static Future<bool> logoutPending() async{
  final db=await openOfflineDatabase();final t=db.transaction('cache',idbModeReadOnly);final row=await t.objectStore('cache').getObject('logout_pending');await t.completed;return row!=null;
 }
 static Future<void> finishLogout() async{
  final db=await openOfflineDatabase();final t=db.transaction('cache',idbModeReadWrite);await t.objectStore('cache').delete('logout_pending');await t.completed;
 }
 static Future<void> clear() async{
  final db=await openOfflineDatabase();final t=db.transaction('cache',idbModeReadWrite);await t.objectStore('cache').delete('active_lease');await t.completed;
 }
}
).hasMatch(path)&&!RegExp(r'^/api/v1/customers/[a-f0-9-]{36}(/visits|/photos)?$').hasMatch(path))throw ArgumentError('Unsupported offline operation');
  final id=data['client_ref']?.toString()??const Uuid().v4();
  if(photo!=null&&(photo.isEmpty||photo.length>5*1024*1024))throw StateError('Ảnh phải nhỏ hơn 5 MB');
  await _put({'key':'$namespace:$id','namespace':namespace,'account':identity,'created':DateTime.now().millisecondsSinceEpoch,
    'path':path,'method':method,'payload':{...data,'client_ref':id},'status':'pending','attempts':0,
    if(photo!=null)'photo':photo,if(mime!=null)'mime':mime,'upload_id':const Uuid().v4()});
  await reload();
  if(_timer!=null)unawaited(sync());
 }
 Future<void> start() async{
  try{await reload();}catch(e){error='Không mở được bộ nhớ máy: $e';_notify();return;}
  if(_closed)return;
  _timer=Timer.periodic(const Duration(seconds:30),(_)=>unawaited(sync()));
  unawaited(sync());
 }
 Future<void> sync() async{
  if(_closed||syncing)return;
  syncing=true;error=null;_notify();
  try{
   await reload();
   if(pending.isEmpty)return;
   final me=await session.get('/api/v1/me');
   if(_closed||me['identity']!=identity||me['scope_revision'].toString()!=revision){error='Quyền đã thay đổi. Dữ liệu cũ được cách ly.';return;}
   for(final row in List.of(pending)){
    if(_closed)break;
    if(row['status']=='blocked')continue;
    try{
     final payload=Map<String,dynamic>.from(row['payload'] as Map);
     final headers={...sessionHeaders(session.cookie),'X-Sync-Identity':identity,'X-Sync-Revision':revision};
     final uri=session.uri(row['path'] as String);
     if((row['path'] as String).endsWith('/photos')){
      final bytes=Uint8List.fromList((row['photo'] as List).cast<int>());
      final upload=await http.post(uri,headers:{...headers,'Content-Type':row['mime'] as String,'X-Upload-Id':row['upload_id'] as String},body:bytes).timeout(const Duration(seconds:30));
      decodeApi(upload);await _remove(row['key'] as String);continue;
     }
     final response=await (row['method']=='PATCH'?http.patch(uri,headers:headers,body:jsonEncode(payload)):http.post(uri,headers:headers,body:jsonEncode(payload))).timeout(const Duration(seconds:30));
     final result=decodeApi(response);
     final item=result['item'] as Map;
     if(row['photo']!=null){
      final bytes=Uint8List.fromList((row['photo'] as List).cast<int>());
      if(_closed)break;
      final upload=await http.post(session.uri('/api/v1/customers/${item['id']}/photos'),
       headers:{...headers,'Content-Type':row['mime'] as String,'X-Upload-Id':row['upload_id'] as String},body:bytes).timeout(const Duration(seconds:30));
      decodeApi(upload);
     }
     await _remove(row['key'] as String);
    }catch(e){
     final blocked=e is ApiFailure&&[400,403,404,409,413,415,422].contains(e.status);
     await _updateIfPresent({...row,'status':blocked?'blocked':'pending','attempts':(row['attempts'] as int)+1,'error':e.toString()});
     error=e.toString();
     if(!blocked)break;
    }
   }
  }catch(e){error=e.toString();}
  finally{try{await reload();}catch(e){error=e.toString();}syncing=false;_notify();}
 }
 @override void dispose(){_closed=true;_timer?.cancel();super.dispose();}
}
class OfflineLease {
 static const duration=Duration(hours:12);
 static Future<void> remember(Map<String,dynamic> me,Map<String,List<String>> districts) async{
  final db=await openOfflineDatabase();final t=db.transaction('cache',idbModeReadWrite);
  if(await t.objectStore('cache').getObject('logout_pending')!=null){await t.completed;return;}
  await t.objectStore('cache').put({'key':'active_lease','me':me,'districts':districts,'expires':DateTime.now().add(duration).millisecondsSinceEpoch});await t.completed;
 }
 static Future<Map<String,dynamic>?> read() async{
  final db=await openOfflineDatabase();final t=db.transaction('cache',idbModeReadOnly);final row=await t.objectStore('cache').getObject('active_lease');await t.completed;
  if(row==null)return null;final v=Map<String,dynamic>.from(row as Map);
  return (v['expires'] as int)>DateTime.now().millisecondsSinceEpoch?v:null;
 }
 static Future<void> markLogout() async{
  final db=await openOfflineDatabase();final t=db.transaction('cache',idbModeReadWrite);final s=t.objectStore('cache');await s.delete('active_lease');await s.put({'key':'logout_pending'});await t.completed;
 }
 static Future<bool> logoutPending() async{
  final db=await openOfflineDatabase();final t=db.transaction('cache',idbModeReadOnly);final row=await t.objectStore('cache').getObject('logout_pending');await t.completed;return row!=null;
 }
 static Future<void> finishLogout() async{
  final db=await openOfflineDatabase();final t=db.transaction('cache',idbModeReadWrite);await t.objectStore('cache').delete('logout_pending');await t.completed;
 }
 static Future<void> clear() async{
  final db=await openOfflineDatabase();final t=db.transaction('cache',idbModeReadWrite);await t.objectStore('cache').delete('active_lease');await t.completed;
 }
}
