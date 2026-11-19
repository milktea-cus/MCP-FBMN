import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:idb_shim/idb_shim.dart';
import 'package:uuid/uuid.dart';
import 'offline_factory.dart';
import 'session.dart';

/// Route execution uses the account-scoped outbox, just like planned stops.
bool isWorkVisitOfflineOperation(String path)=>
 RegExp(r'^/api/v1/day-routes/[a-f0-9-]{36}/unplanned-stops$').hasMatch(path)||
 RegExp(r'^/api/v1/day-routes/[a-f0-9-]{36}/stops/[a-f0-9-]{36}/missed$').hasMatch(path)||
 RegExp(r'^/api/v1/day-routes/[a-f0-9-]{36}/work-session$').hasMatch(path)||
 RegExp(r'^/api/v1/work-sessions/[a-f0-9-]{36}/close$').hasMatch(path);


bool sameSavedRoute(Map server,Map local,String owner){
 final remoteDate=server['route_date']?.toString()??'';
 final wanted=local['route_date']?.toString()??'';
 return server['owner_sub']==owner&&
  server['monthly_plan_id']==local['monthly_plan_id']&&
  remoteDate.length>=10&&remoteDate.substring(0,10)==wanted&&
  server['purpose']==local['purpose']?.toString().trim()&&
  (server['note']??'')==(local['note']??'')&&
  server['status']==(local['status']??'ready');
}
bool sameSavedStop(Map stop,Map local,String owner,String routeId,{bool isUnplanned=false}){
 if(stop['owner_sub']!=owner||stop['day_route_id']!=routeId||
    stop['stop_kind']!=local['stop_kind']||
    (stop['is_unplanned']==true)!=isUnplanned||
    stop['sequence']!=local['sequence']||
    (stop['purpose']??'')!=(local['purpose']??''))return false;
 switch(local['stop_kind']){
  case 'customer':return stop['customer_id']==local['customer_id'];
  case 'chain':return stop['chain_id']==local['chain_id'];
  case 'area':return stop['province']==local['province']&&
     stop['district']==local['district'];
 }
 return false;
}

/// A draft and its outbox operation are the same durable row. No credentials
/// are stored. Every queue read/write is scoped to identity + scope revision.
Future<Database>? _sharedDatabase;
Future<Database> openOfflineDatabase([IdbFactory? factory]){
 Future<Database> open()=> (factory??offlineFactory()).open('filed_work_offline_v1',version:1,onUpgradeNeeded:(e){final store=e.database.createObjectStore('outbox',keyPath:'key');store.createIndex('account','account');e.database.createObjectStore('cache',keyPath:'key');});
 if(factory!=null)return open();
 // An Android SQLite open error is not permanent; retry on next attempt.
 return _sharedDatabase??=open().catchError((Object error,StackTrace stack){
  _sharedDatabase=null;
  Error.throwWithStackTrace(error,stack);
 });
}
class OfflineQueue extends ChangeNotifier {
 final SalesSession session;
 final String identity,revision;
 final IdbFactory? factory;
 final http.Client? networkClient;
 OfflineQueue(this.session,this.identity,this.revision,{this.factory,this.networkClient});
 Future<Database>? _opening;
 bool _closed=false, syncing=false;
 String? error;
 /// Visible sync diagnostics; committed outbox rows are never dropped on errors.
 DateTime? lastAttemptAt,lastSuccessAt,nextRetryAt;
 String? activePath;
 int transientFailures=0;
 int get blockedCount=>pending.where((r)=>r['status']=='blocked').length;
 String? _dismissedBlockedSignature;
 String get _blockedSignature=>(pending.where((r)=>r['status']=='blocked')
  .map((r)=>'${r['key']}:${r['error']}').toList()..sort()).join('|');
 bool get blockedBannerDismissed=>blockedCount>0&&
  _dismissedBlockedSignature==_blockedSignature;
 /// Hide the persistent banner for reviewed 4xx errors without deleting,
 /// mutating, or resending any failed work from IndexedDB.
 Future<void> dismissBlockedBanner()async{
  if(_closed||blockedCount==0)return;
  final signature=_blockedSignature;
  await cache('sync-blocked-banner-dismiss',[{'signature':signature}]);
  _dismissedBlockedSignature=signature;
  _notify();
 }
 bool get reconciling=>_reconciling;
 int get readyCount=>pending.length-blockedCount;
 bool get isStalled=>syncing&&lastAttemptAt!=null&&
  DateTime.now().difference(lastAttemptAt!)>const Duration(minutes:2);
 Duration get retryDelay{
  final power=transientFailures.clamp(1,5).toInt();
  return Duration(seconds:(15*(1<<power)).clamp(30,300).toInt());
 }
 String describeFailure(Object failure)=>failure is ApiFailure
  ?'HTTP ${failure.status}: ${failure.message}'
  :failure is TimeoutException?'Quá thời gian kết nối':failure.toString();
 String describe(Map<String,dynamic> row){
  final path=row['path']?.toString()??'';
  if(path.startsWith('/api/v1/scoped-records'))return 'Đề xuất hỗ trợ / Thông tin đối thủ';
   if(path.startsWith('/api/v1/sessions/')){
   if(path.endsWith('/photos'))return 'Ảnh khảo sát';
   return 'Hoàn tất phiên khảo sát';
  }
  if(path=='/api/v1/sessions')return 'Bắt đầu phiên khảo sát';
  if(path.contains('/work-session')&&path.endsWith('/work-session'))return 'Bắt đầu phiên công tác';
  if(path.contains('/work-sessions/')&&path.endsWith('/close'))return 'Kết thúc phiên công tác';
  if(path.contains('/unplanned-stops'))return 'Khách phát sinh ngoài kế hoạch';
  if(path.endsWith('/missed'))return 'Lý do chưa ghé điểm bán';
  if(path=='/api/v1/trips')return 'Tạo chuyến công tác';
  if(path.startsWith('/api/v1/trips/'))return 'Gia hạn / kết thúc chuyến';
  if(path.startsWith('/api/v1/local-monthly-routes'))return 'Phân công cố định theo tuần tháng';
  if(path.startsWith('/api/v1/local-routes'))return 'Tuyến cố định Sales Local';
   if(path.startsWith('/api/v1/day-routes'))return 'Lịch trình trong ngày';
  if(path.startsWith('/api/v1/monthly-plans'))return 'Kế hoạch tháng';
  if(path.startsWith('/api/v1/records'))return 'Biểu mẫu / kế hoạch';
  if(path.startsWith('/api/v1/customers'))return 'Cập nhật khách hàng';
  if(path.startsWith('/api/v1/notifications'))return 'Đánh dấu thông báo';
  if(path.startsWith('/api/v1/area-visits'))return 'GPS / lead tìm khách mới';
  return 'Thao tác lưu trên máy';
 }

 List<Map<String,dynamic>> pending=[];
 List<Map<String,dynamic>> rescued=[];
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
  try{rescued=await cached('sync-rescued-operations');}catch(_){}
  // Once every durable operation has been acknowledged, an old HTTP error
  // cannot leave a permanent purple banner on the next screen.
  if(pending.isEmpty&&quarantined==0)error=null;
  _notify();
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
 /// Atomically reconcile a successful selling update with the offline
 /// customer snapshots, before deleting its durable outbox operation.
 Future<void> _ackSellingUpdate(Map<String,dynamic> operation,
     Map<String,dynamic> server)async{
   final database=await db;
   final tx=database.transactionList(['cache','outbox'],idbModeReadWrite);
   final store=tx.objectStore('cache');
   final province=server['province']?.toString()??'';
   for(final key in {'customers:','customers:$province'}){
     final cacheKey='$namespace:$key';
     final saved=await store.getObject(cacheKey);
     if(saved is! Map||saved['items'] is! List)continue;
     var modified=false;
     final records=<Map<String,dynamic>>[];
     for(final record in saved['items'] as List){
       final old=Map<String,dynamic>.from(record as Map);
       if(old['id']==server['id']){
         records.add({...old,...server});
         modified=true;
       }else{
         records.add(old);
       }
     }
     if(modified)await store.put({'key':cacheKey,'items':records});
   }
   await tx.objectStore('outbox').delete(operation['key'] as String);
   await tx.completed;
 }

 Future<void> enqueue(String path,Map<String,dynamic> data,{Uint8List? photo,Uint8List? thumbnail,String? sha256,String? thumbnailSha256,String? mime,String method='POST',List<String> dependsOn=const []}) async{
  if(_closed)throw StateError('Phiên đã đóng');
  if(!['/api/v1/scoped-records','/api/v1/records','/api/v1/customers','/api/v1/monthly-plans','/api/v1/day-routes','/api/v1/trips','/api/v1/area-visits','/api/v1/route-templates','/api/v1/local-routes','/api/v1/local-monthly-routes'].contains(path)&&!RegExp(r'^/api/v1/area-visits/[a-f0-9-]{36}/photos$').hasMatch(path)&&!RegExp(r'^/api/v1/route-templates/[a-f0-9-]{36}$').hasMatch(path)&&!RegExp(r'^/api/v1/local-routes/[a-f0-9-]{36}$').hasMatch(path)&&!RegExp(r'^/api/v1/local-monthly-routes/[a-f0-9-]{36}$').hasMatch(path)&&!RegExp(r'^/api/v1/prospects/[a-f0-9-]{36}/convert$').hasMatch(path)&&!RegExp(r'^/api/v1/day-routes/[a-f0-9-]{36}(/stops(/[a-f0-9-]{36})?)?$').hasMatch(path)&&!isWorkVisitOfflineOperation(path)&&!RegExp(r'^/api/v1/day-routes/[a-f0-9-]{36}/customer-work$').hasMatch(path)&&!RegExp(r'^/api/v1/trips/[a-f0-9-]{36}/(extend|close)$').hasMatch(path)&&!RegExp(r'^/api/v1/scoped-records/[a-f0-9-]{36}$').hasMatch(path)&&!RegExp(r'^/api/v1/records/[a-f0-9-]{36}$').hasMatch(path)&&!RegExp(r'^/api/v1/notifications/[0-9]{1,19}/read$').hasMatch(path)&&!RegExp(r'^/api/v1/customers/[a-f0-9-]{36}(/visits|/photos|/products|/brands|/cover)?$').hasMatch(path))throw ArgumentError('Unsupported offline operation');
  final id=data['client_ref']?.toString()??const Uuid().v4();
  if(photo!=null&&(photo.isEmpty||photo.length>5*1024*1024))throw StateError('Ảnh phải nhỏ hơn 5 MB');
  if(thumbnail!=null&&(photo==null||thumbnail.isEmpty||thumbnail.length>153600||sha256==null||thumbnailSha256==null))throw StateError('Thumbnail/checksum không hợp lệ');
  final d=await db;
  final tx=d.transaction('outbox',idbModeReadWrite),store=tx.objectStore('outbox');
  final key='$namespace:$id';
  final old=await store.getObject(key);
  if(old is Map){
   // Reopening a page or retrying must not replace a durable blocked item.
   final existing=Map<String,dynamic>.from(old);
   if(existing['path']!=path||existing['method']!=method||
     jsonEncode(existing['payload'])!=jsonEncode({...data,'client_ref':id})||
     jsonEncode(existing['depends_on'])!=jsonEncode(dependsOn)){
    await tx.completed;
    throw StateError('UUID thao tác đã có dữ liệu khác; giữ bản lưu cũ.');
   }
  }else{
   await store.put({'key':key,'namespace':namespace,'account':identity,
    'created':DateTime.now().millisecondsSinceEpoch,
    'path':path,'method':method,'payload':{...data,'client_ref':id},
    'status':'pending','attempts':0,'depends_on':dependsOn,
    if(photo!=null)'photo':photo,if(thumbnail!=null)'thumbnail':thumbnail,
    if(sha256!=null)'sha256':sha256,
    if(thumbnailSha256!=null)'thumbnail_sha256':thumbnailSha256,
    if(mime!=null)'mime':mime,
    if(RegExp(r'^/api/v1/area-visits/[a-f0-9-]{36}/photos$').hasMatch(path))
      'area_visit_id':path.split('/')[4], 'upload_id':id});
  }
  await tx.completed;
  await reload();
  if(_timer!=null)unawaited(sync());
 }

 /// Edit an unsynced scoped-record creation in the same durable IndexedDB/SQLite row.
 /// Do not turn it into a PATCH against an ID that only exists on this device.
 /// A blocked operation is never silently retried or rewritten.
 Future<void> replaceScopedDraft(String draftId,Map<String,dynamic> data)async{
  if(_closed)throw StateError('Phiên đã đóng');
  if(syncing)throw StateError('Đang đồng bộ, mở lại bản ghi sau khi hoàn tất.');
  if(!RegExp(r'^[a-fA-F0-9-]{36}$').hasMatch(draftId)||
      data['client_ref']!=draftId||data['version']!=0||
      !['support','competitor'].contains(data['kind']))
   throw ArgumentError('Mã bản nháp hoặc dữ liệu chỉnh sửa không hợp lệ');
  final database=await db;
  final tx=database.transaction('outbox',idbModeReadWrite);
  final store=tx.objectStore('outbox');
  final key='$namespace:$draftId';
  final existing=await store.getObject(key);
  if(existing is! Map||existing['namespace']!=namespace||
      existing['path']!='/api/v1/scoped-records'||existing['method']!='POST'||
      existing['status']!='pending'||(existing['payload'] as Map?)?['kind']!=data['kind']){
    await tx.completed;
    throw StateError('Bản nháp không còn ở trạng thái chờ; tải lại để tránh ghi đè.');
  }
  await store.put({...Map<String,dynamic>.from(existing),'payload':data});
  await tx.completed;
  await reload();
  if(_timer!=null)unawaited(sync());
 }

 /// Save a plan -> route -> trip as one local transaction, never as three
 /// independently committed rows. Compatible with IndexedDB and SQLite.
 Future<void> enqueueTripGraph({
  required Map<String,dynamic> plan,
  required Map<String,dynamic> route,
  required Map<String,dynamic> trip,
 })async{
  if(_closed)throw StateError('Phiên đã đóng');
  final ids=[plan['client_ref'],route['client_ref'],trip['client_ref']]
   .map((v)=>v?.toString()??'').toList();
  final uuid=RegExp(r'^[a-f0-9]{8}(-[a-f0-9]{4}){3}-[a-f0-9]{12}$',caseSensitive:false);
  if(ids.toSet().length!=3||ids.any((v)=>!uuid.hasMatch(v))||
    route['monthly_plan_id']!=ids[0]||trip['day_route_id']!=ids[1]||
    plan['work_date']!=route['route_date']||
    trip['start_date']!=route['route_date']||
    trip['end_date'].toString().compareTo(trip['start_date'].toString())<0||
    trip['scopes'] is! List||(trip['scopes'] as List).isEmpty){
   throw StateError('Lịch, tuyến và chuyến không khớp; không lưu thiếu');
  }
  final jobs=[
   <String,dynamic>{'path':'/api/v1/monthly-plans','payload':plan,'id':ids[0],'deps':<String>[]},
   <String,dynamic>{'path':'/api/v1/day-routes','payload':route,'id':ids[1],'deps':<String>[ids[0]]},
   <String,dynamic>{'path':'/api/v1/trips','payload':trip,'id':ids[2],'deps':<String>[ids[1]]},
  ];
  final d=await db,t=d.transaction('outbox',idbModeReadWrite),store=t.objectStore('outbox');
  final now=DateTime.now().millisecondsSinceEpoch;
  for(final job in jobs){
   final key='${namespace}:${job['id']}';
   final old=await store.getObject(key);
   if(old is Map){
    if(old['namespace']!=namespace||old['path']!=job['path']||
       jsonEncode(old['payload'])!=jsonEncode(job['payload'])||
       jsonEncode(old['depends_on'])!=jsonEncode(job['deps'])){
     await t.completed;throw StateError('UUID đã có dữ liệu khác; không ghi đè');
    }
   }
  }
  for(var i=0;i<jobs.length;i++){
   final job=jobs[i],key='${namespace}:${job['id']}';
   if(await store.getObject(key)!=null)continue;
   await store.put({'key':key,'namespace':namespace,'account':identity,
    'created':now+i,'path':job['path'],'method':'POST',
    'payload':job['payload'],'status':'pending','attempts':0,
    'depends_on':job['deps'],'upload_id':job['id']});
  }
  await t.completed;await reload();
  if(_timer!=null)unawaited(sync());
 }

 /// Rejected operations can be moved to a private, durable recovery shelf.
 /// The original operation is never destroyed; user may restore later.
 bool canRescue(Map<String,dynamic> job){
  if(job['status']!='blocked'||job['namespace']!=namespace)return false;
  final ref=(job['payload'] as Map?)?['client_ref']?.toString()??'';
  if(ref.isEmpty)return false;
  for(final other in pending){
   if(other['key']==job['key'])continue;
   if((other['depends_on'] as List? ?? []).contains(ref))return false;
   if((other['path']?.toString()??'').contains('/$ref/'))return false;
   final data=other['payload'] as Map?;
   if(data!=null&&['monthly_plan_id','day_route_id','trip_id',
     'route_stop_id','day_route_stop_id','customer_id','session_id']
     .any((field)=>data[field]?.toString()==ref))return false;
  }
  return true;
 }
 Future<void> rescueBlocked(String key)async{
  if(_closed||syncing||_reconciling||!key.startsWith('${namespace}:'))
   throw StateError('Đang đồng bộ hoặc sai tài khoản');
  await reload();
  final selected=pending.where((r)=>r['key']==key).firstOrNull;
  if(selected==null||!canRescue(selected))
   throw StateError('Còn thao tác phụ thuộc; không thể đưa vào lưu riêng');
  final reference=(selected['payload'] as Map)['client_ref']?.toString()??'';
  final drafts=await cached('survey-drafts');
  if(drafts.any((r)=>['id','day_route_id','route_stop_id','day_route_stop_id']
    .any((field)=>r[field]?.toString()==reference)))
   throw StateError('Có bản nháp khảo sát liên quan, không thể hủy an toàn');
  final d=await db,t=d.transactionList(['outbox','cache'],idbModeReadWrite),
    out=t.objectStore('outbox'),cache=t.objectStore('cache');
  final raw=await out.getObject(key);
  final record=await cache.getObject('${namespace}:sync-rescued-operations');
  final items=record is Map&&record['items'] is List
    ?(record['items'] as List).map((v)=>Map<String,dynamic>.from(v as Map)).toList()
    :<Map<String,dynamic>>[];
  if(raw is! Map||raw['namespace']!=namespace||raw['status']!='blocked'||
    items.any((r)=>r['key']==key)||items.length>=200){
   await t.completed;throw StateError('Không thể lưu riêng thao tác');
  }
  items.add({...Map<String,dynamic>.from(raw),
   'rescued_at':DateTime.now().toIso8601String()});
  await cache.put({'key':'${namespace}:sync-rescued-operations','items':items});
  await out.delete(key);
  await t.completed;await reload();
 }
 Future<void> restoreRescued(String key)async{
  if(_closed||syncing||_reconciling||!key.startsWith('${namespace}:'))
   throw StateError('Đang đồng bộ hoặc sai tài khoản');
  final d=await db,t=d.transactionList(['outbox','cache'],idbModeReadWrite),
    out=t.objectStore('outbox'),cache=t.objectStore('cache');
  final record=await cache.getObject('${namespace}:sync-rescued-operations');
  final items=record is Map&&record['items'] is List
    ?(record['items'] as List).map((v)=>Map<String,dynamic>.from(v as Map)).toList()
    :<Map<String,dynamic>>[];
  final index=items.indexWhere((r)=>r['key']==key);
  if(index<0||await out.getObject(key)!=null){
   await t.completed;throw StateError('Không tìm được thao tác cần khôi phục');
  }
  final row=Map<String,dynamic>.from(items.removeAt(index))..remove('rescued_at');
  if(row['namespace']!=namespace){await t.completed;throw StateError('Sai tài khoản');}
  await out.put(row);
  await cache.put({'key':'${namespace}:sync-rescued-operations','items':items});
  await t.completed;await reload();
 }

 /// Store a confirmed multi-stop plan in one local transaction.
 Future<void> enqueueRouteBatch(List<Map<String,dynamic>> records) async{
  if(_closed)throw StateError('Phiên đã đóng');
  if(records.isEmpty)return;
  final d=await db;
  if(_closed)throw StateError('Phiên đã đóng');
  final t=d.transaction('outbox',idbModeReadWrite),store=t.objectStore('outbox');
  final now=DateTime.now().millisecondsSinceEpoch;
  for(var i=0;i<records.length;i++){
   final record=records[i],id=record['client_ref'] as String;
   await store.put({'key':'$namespace:$id','namespace':namespace,'account':identity,'created':now+i,
    'path':'/api/v1/records','method':'POST','payload':record,'status':'pending','attempts':0,'upload_id':const Uuid().v4()});
  }
  await t.completed;await reload();
  if(_timer!=null)unawaited(sync());
 }
 /// Draft and operation share one transaction on both IndexedDB and native SQLite.
 Future<void> saveSurveyDraft(Map<String,dynamic> draft,{String? path,Map<String,dynamic>? payload,String method='POST',Uint8List? photo,Uint8List? thumbnail,String? mime,List<String> dependsOn=const []})async{
  if(_closed)throw StateError('Phiên đã đóng');
  final id=draft['id'] as String;
  if(path!=null&&!(path=='/api/v1/sessions'||path=='/api/v1/sessions/$id'||path=='/api/v1/sessions/$id/photos'))throw ArgumentError('Unsupported session operation');
  if(photo!=null&&(photo.isEmpty||photo.length>5*1024*1024))throw StateError('Ảnh phải nhỏ hơn 5 MB');
  final d=await db;if(_closed)throw StateError('Phiên đã đóng');
  final t=d.transactionList(['cache','outbox'],idbModeReadWrite),cache=t.objectStore('cache');
  final key='$namespace:survey-drafts';
  final existing=await cache.getObject(key);
  final items=existing==null?<Map<String,dynamic>>[]:((existing as Map)['items'] as List).map((r)=>Map<String,dynamic>.from(r as Map)).toList();
  final old=items.where((r)=>r['id']==id).firstOrNull;
  final next={...draft,if(old?['server_status']!=null)'server_status':old!['server_status'],if(old?['server_version']!=null)'server_version':old!['server_version'],if(old?['server_status']!=null&&old?['location_initialized']!=null)'location_initialized':old!['location_initialized']};
  // Acknowledged photos must not revert to pending when the user edits a draft.
  final known=(old?['photos'] as List?)??[];
  if(next['photos'] is List)next['photos']=(next['photos'] as List).map((p){final prior=known.where((r)=>(r as Map)['id']==(p as Map)['id']).firstOrNull;return {...Map<String,dynamic>.from(p as Map),if(prior is Map&&prior['sync_status']=='ready')'sync_status':'ready'};}).toList();
  items.removeWhere((r)=>r['id']==id);items.add(next);
  await cache.put({'key':key,'items':items});
  if(path!=null){
   final data=payload!;final op=data['client_ref'] as String;
   await t.objectStore('outbox').put({'key':'$namespace:$op','namespace':namespace,'account':identity,'created':DateTime.now().millisecondsSinceEpoch,'session_id':id,'depends_on':dependsOn,
    'path':path,'method':method,'payload':data,'status':'pending','attempts':0,'upload_id':op,if(photo!=null)'photo':photo,if(thumbnail!=null)'thumbnail':thumbnail,if(mime!=null)'mime':mime});
  }
  await t.completed;await reload();if(path!=null&&_timer!=null)unawaited(sync());
 }
 Future<bool> _dependencyPending(Map<String,dynamic> row)async{
  final deps=(row['depends_on'] as List?)??[];if(deps.isEmpty)return false;
  final d=await db,t=d.transaction('outbox',idbModeReadOnly),s=t.objectStore('outbox');var pending=false;
  for(final id in deps){if(await s.getObject('$namespace:$id')!=null)pending=true;}
  await t.completed;return pending;
 }
 Future<void> _ackSurvey(Map<String,dynamic> row,Map item)async{
  final d=await db,t=d.transactionList(['cache','outbox'],idbModeReadWrite),cache=t.objectStore('cache');
  final key='$namespace:survey-drafts',stored=await cache.getObject(key);
  if(stored!=null){
   final items=((stored as Map)['items'] as List).map((v)=>Map<String,dynamic>.from(v as Map)).toList();
   for(final draft in items.where((v)=>v['id']==row['session_id'])){
    if((row['path'] as String).endsWith('/photos')){
     draft['photos']=[for(final p in (draft['photos'] as List? ?? [])) {...Map<String,dynamic>.from(p as Map),if(p['id']==item['id'])'sync_status':'ready'}];
    }else{draft['server_status']=item['status'];draft['server_version']=item['version'];if(item['location_initialized']!=null)draft['location_initialized']=item['location_initialized'];}
   }
   await cache.put({'key':key,'items':items});
  }
  await t.objectStore('outbox').delete(row['key'] as String);await t.completed;
 }
 Future<void> retrySurveyOperation(String op)async{
  if(_closed||syncing)return;
  final d=await db,t=d.transaction('outbox',idbModeReadWrite),store=t.objectStore('outbox');final raw=await store.getObject('$namespace:$op');
  if(raw is Map&&raw['session_id']!=null&&raw['status']=='blocked')await store.put({...Map<String,dynamic>.from(raw),'status':'pending','error':null});
  await t.completed;await reload();await retryNow();
 }

 /// Even old iPhone builds stored 409 as plain Vietnamese text without a
 /// numeric status. Read-only matching is safe for any blocked route creation.
 bool isRoutePatchConflict(Map<String,dynamic> row)=>
  row['status']=='blocked'&&row['method']=='PATCH'&&
  RegExp(r'^/api/v1/day-routes/[a-f0-9-]{36}$',caseSensitive:false)
    .hasMatch(row['path']?.toString()??'');
 bool isRouteDuplicateConflict(Map<String,dynamic> row){
  final path=row['path']?.toString()??'';
  return row['status']=='blocked'&&row['method']=='POST'&&
   (path=='/api/v1/day-routes'||
    RegExp(r'^/api/v1/day-routes/[a-f0-9-]{36}/(stops|unplanned-stops)$',
     caseSensitive:false).hasMatch(path));
 }
 Future<Map<String,dynamic>> _readRoute(String path)async{
  final uri=session.uri(path),headers=sessionHeaders(session.cookie);
  final result=await (networkClient?.get(uri,headers:headers)??
   http.get(uri,headers:headers)).timeout(const Duration(seconds:12));
  return decodeApi(result);
 }
 Future<bool> _ackMatchedRouteRow(Map<String,dynamic> row,Map candidate,
     {required bool isStop})async{
  final local=(row['payload'] as Map)['client_ref']?.toString()??'';
  final canonical=candidate['id']?.toString()??'';
  final uuid=RegExp(r'^[a-f0-9-]{36}$',caseSensitive:false);
  if(!uuid.hasMatch(local)||!uuid.hasMatch(canonical))return false;
  final d=await db;
  final t=d.transactionList(['outbox','cache'],idbModeReadWrite);
  final store=t.objectStore('outbox');
  final actual=await store.getObject(row['key'] as String);
  if(actual is! Map||actual['namespace']!=namespace||
     actual['path']!=row['path']||
     (actual['payload'] as Map)['client_ref']!=local){
   await t.completed;return false;
  }
  if(local!=canonical){
   final others=await store.index('account').getAll(identity);
   final oldPrefix=isStop?'/stops/$local/':'/api/v1/day-routes/$local/';
   final newPrefix=isStop?'/stops/$canonical/':'/api/v1/day-routes/$canonical/';
   for(final raw in others){
    if(raw is! Map||raw['namespace']!=namespace||
       raw['key']==row['key'])continue;
    final op=Map<String,dynamic>.from(raw);
    var changed=false;
    final path=op['path']?.toString()??'';
    if((isStop&&path.startsWith('/api/v1/day-routes/')||
        !isStop)&&path.contains(oldPrefix)){
     op['path']=path.replaceFirst(oldPrefix,newPrefix);changed=true;
    }
    final deps=(op['depends_on'] as List?)??[];
    if(deps.contains(local)){
     op['depends_on']=deps.where((v)=>v!=local).toList();
     changed=true;
    }
    if(op['payload'] is Map){
     final data=Map<String,dynamic>.from(op['payload'] as Map);
     final fields=isStop
       ?['route_stop_id','day_route_stop_id']
       :['day_route_id'];
     for(final field in fields){
      if(data[field]==local){data[field]=canonical;changed=true;}
     }
     if(changed)op['payload']=data;
    }
    if(changed)await store.put(op);
   }
   if(isStop){
    final cache=t.objectStore('cache');
    final key='$namespace:survey-drafts';
    final saved=await cache.getObject(key);
    if(saved is Map&&saved['items'] is List){
     final drafts=(saved['items'] as List)
       .map((v)=>Map<String,dynamic>.from(v as Map)).toList();
     var updated=false;
     for(final draft in drafts){
      if(draft['day_route_stop_id']==local){
       draft['day_route_stop_id']=canonical;updated=true;
      }
     }
     if(updated)await cache.put({'key':key,'items':drafts});
    }
   }
  }
  await store.delete(row['key'] as String);
  await t.completed;
  return true;
 }
 /// Once the server confirms that an unstarted route was archived, a stale
 /// iPhone POST for its stop can be dismissed only if it has NO locally saved
 /// GPS/check-in/survey/photo or dependent operation. Never clear unrelated
 /// offline work or delete the actual server stop.
 Future<bool> _discardArchivedStop(Map<String,dynamic> row)async{
  if(_closed||row['namespace']!=namespace||row['method']!='POST')return false;
  final ref=(row['payload'] as Map?)?['client_ref']?.toString()??'';
  if(ref.isEmpty)return false;
  await reload();
  final drafts=await cached('survey-drafts');
  if(drafts.any((d)=>d['day_route_stop_id']==ref||d['route_stop_id']==ref)){
   return false;
  }
  for(final op in pending){
   if(op['key']==row['key'])continue;
   final deps=op['depends_on'] as List? ?? [];
   final payload=op['payload'];
   if(deps.contains(ref)||
      op['path']?.toString().contains('/stops/$ref/')==true||
      payload is Map&&(
       payload['route_stop_id']==ref||payload['day_route_stop_id']==ref
      ))return false;
  }
  final database=await db;
  final tx=database.transaction('outbox',idbModeReadWrite);
  final store=tx.objectStore('outbox');
  final saved=await store.getObject(row['key'] as String);
  if(saved is! Map||saved['namespace']!=namespace||
     saved['path']!=row['path']||saved['method']!='POST'||
     saved['status']!='blocked'&&saved['status']!='pending'||
     (saved['payload'] as Map?)?['client_ref']!=ref){
   await tx.completed;return false;
  }
  await store.delete(row['key'] as String);
  await tx.completed;
  return true;
 }
 Future<bool> _resolveDuplicate(Map<String,dynamic> row)async{
  if(_closed||row['namespace']!=namespace||row['method']!='POST')return false;
  final path=row['path']?.toString()??'';
  final payload=Map<String,dynamic>.from(row['payload'] as Map);
  if(path=='/api/v1/day-routes'){
   final date=payload['route_date']?.toString()??'';
   if(!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date))return false;
   final remote=await _readRoute('/api/v1/day-routes?month='+date.substring(0,7));
   final routes=remote['items'] as List? ?? [];
   for(final raw in routes){
    if(raw is Map&&sameSavedRoute(raw,payload,identity)){
     return _ackMatchedRouteRow(row,raw,isStop:false);
    }
   }
   // Only a route already cancelled by the server needs a second read of
   // the monthly plan to verify that Xóa lịch was explicitly confirmed.
   // Other 409 cases remain blocked rather than blindly reposting.
   if(row['status']=='blocked'&&routes.any((raw)=>raw is Map&&
     raw['monthly_plan_id']==payload['monthly_plan_id']&&
     raw['owner_sub']==identity&&raw['status']=='cancelled')){
    final plans=await _readRoute('/api/v1/monthly-plans?month='+date.substring(0,7));
    for(final raw in plans['items'] as List? ?? []){
     if(raw is Map&&raw['id']==payload['monthly_plan_id']&&
        raw['owner_sub']==identity&&raw['status']=='cancelled'){
      return (await discardPendingForArchivedPlan(
       payload['monthly_plan_id'].toString(),internal:true))>0;
     }
    }
   }
   return false;
  }
  final match=RegExp(r'^/api/v1/day-routes/([a-f0-9-]{36})/(stops|unplanned-stops)$',
   caseSensitive:false).firstMatch(path);
  if(match==null)return false;
  final routeId=match.group(1)!;
  final isUnplanned=match.group(2)=='unplanned-stops';
  final remote=await _readRoute('/api/v1/day-routes/'+routeId);
  if(remote['item'] is! Map||
    (remote['item'] as Map)['owner_sub']!=identity)return false;
  for(final raw in remote['stops'] as List? ?? []){
   if(raw is Map&&sameSavedStop(raw,payload,identity,routeId,
     isUnplanned:isUnplanned)){
    return _ackMatchedRouteRow(row,raw,isStop:true);
   }
  }
  // After an explicitly archived, never-started route, even a differing
  // unsubmitted stop is obsolete. Preserve it if any local execution exists.
  final parent=remote['item'] as Map;
  if(parent['plan_status']=='cancelled'&&parent['status']=='cancelled'){
   return _discardArchivedStop(row);
  }
  return false;
 }
 /// A stale PATCH after a plan's date has already been corrected on the
 /// server is safe to ACK only if EVERY requested field matches. A real
 /// conflict stays durable, never silently overwritten by another device.
 Future<bool> _ackAlreadyAppliedRoutePatch(Map<String,dynamic> row)async{
  final path=row['path']?.toString()??'';
  if(row['method']!='PATCH'||!RegExp(
    r'^/api/v1/day-routes/[a-f0-9-]{36}$',caseSensitive:false).hasMatch(path))
   return false;
  final payload=row['payload'] as Map?;
  if(payload==null)return false;
  final response=await _readRoute(path);
  final item=response['item'];
  if(item is! Map||item['owner_sub']!=identity||
     item['id'].toString()!=path.split('/').last||
     item['monthly_plan_id']!=payload['monthly_plan_id']||
     item['status']!=payload['status']||
     item['purpose']!=payload['purpose']?.toString().trim()||
     (item['note']??'')!=(payload['note']??'')||
     !item['route_date'].toString().startsWith(
      payload['route_date']?.toString()??'INVALID')||
     (item['version'] as num?)?.toInt()==null||
     (item['version'] as num).toInt()<(payload['version'] as num).toInt())
   return false;
  await _remove(row['key'] as String);
  return true;
 }

 /// Legacy PWA outboxes may store the server's Vietnamese conflict message
 /// without an HTTP status. Never POST them blindly when user taps retry.
 bool looksLikeConflict(Map<String,dynamic> row){
  final e=(row['error']?.toString()??'').toLowerCase();
  return RegExp(r'(^|[^0-9])409([^0-9]|$)').hasMatch(e)||
   e.contains('bị trùng')||e.contains('trùng tuyến')||
   e.contains('xung đột')||e.contains('phiên bản')||
   e.contains('stale')||e.contains('duplicate')||
   e.contains('version conflict');
 }
 bool isPlanDuplicateConflict(Map<String,dynamic> row)=>
  row['status']=='blocked'&&row['method']=='POST'&&
  row['path']=='/api/v1/monthly-plans'&&
  looksLikeConflict(row);
 bool isTripDuplicateConflict(Map<String,dynamic> row)=>
  row['status']=='blocked'&&row['method']=='POST'&&
  row['path']=='/api/v1/trips'&&
  looksLikeConflict(row);

 bool _samePlan(Map server,Map local){
  final day=local['work_date']?.toString()??'';
  return server['owner_sub']==identity&&
   server['period_ym']==local['period_ym']&&
   server['work_date']?.toString().startsWith(day)==true&&
   server['scope_kind']==local['scope_kind']&&
   server['scope_key']==local['scope_key']&&
   (server['province']??null)==(local['province']??null)&&
   (server['district']??null)==(local['district']??null)&&
   server['purpose']==local['purpose']?.toString().trim()&&
   (server['note']??'')==(local['note']??'')&&
   server['status']==(local['status']??'planned')&&
   (server['target_new_customers'] as num?)?.toInt()==
     (local['target_new_customers'] as num?)?.toInt();
 }
 String _scopeFingerprint(Object? input){
  if(input is! List)return '';
  final keys=<String>[];
  for(final scope in input){
   if(scope is! Map)return '';
   keys.add([scope['scope_kind'],scope['scope_key'],
    scope['province']??'',scope['district']??''].join('|'));
  }
  keys.sort();
  return keys.join(';;');
 }
 bool _sameTrip(Map server,Map local){
  final priorities=(server['priority_customer_ids'] as List? ?? [])
   .map((x)=>x.toString()).toList()..sort();
  final localPriorities=(local['priorities'] as List? ?? [])
   .map((x)=>x.toString()).toList()..sort();
  return server['owner_sub']==identity&&
   server['day_route_id']==local['day_route_id']&&
   server['start_date']?.toString().startsWith(local['start_date']?.toString()??'INVALID')==true&&
   server['end_date']?.toString().startsWith(local['end_date']?.toString()??'INVALID')==true&&
   server['purpose']==local['purpose']?.toString().trim()&&
   (server['note']??'')==(local['note']??'')&&
   _scopeFingerprint(server['scopes'])==_scopeFingerprint(local['scopes'])&&
   jsonEncode(priorities)==jsonEncode(localPriorities);
 }
 /// Parent ACK with a different canonical UUID must rewrite all descendants
 /// in one transaction. The server response is read-only and checked first.
 Future<bool> _ackParent(Map<String,dynamic> row,Map server,
     {required String field})async{
  final local=(row['payload'] as Map)['client_ref']?.toString()??'';
  final canonical=server['id']?.toString()??'';
  final uuid=RegExp(r'^[0-9a-f-]{36}$',caseSensitive:false);
  if(!uuid.hasMatch(local)||!uuid.hasMatch(canonical))return false;
  final d=await db,t=d.transaction('outbox',idbModeReadWrite),
    out=t.objectStore('outbox');
  final original=await out.getObject(row['key'] as String);
  if(original is! Map||original['namespace']!=namespace||
   original['path']!=row['path']||
   (original['payload'] as Map)['client_ref']!=local){
   await t.completed;return false;
  }
  if(canonical!=local){
   final others=await out.index('account').getAll(identity);
   for(final raw in others){
    if(raw is! Map||raw['namespace']!=namespace||
      raw['key']==row['key'])continue;
    final op=Map<String,dynamic>.from(raw);
    var changed=false;
    final deps=(op['depends_on'] as List? ?? []);
    if(deps.contains(local)){
     op['depends_on']=deps.where((x)=>x!=local).toList();changed=true;
    }
    if(op['payload'] is Map){
     final data=Map<String,dynamic>.from(op['payload'] as Map);
     if(data[field]==local){data[field]=canonical;changed=true;}
     if(changed)op['payload']=data;
    }
    final path=op['path']?.toString()??'';
    if(field=='trip_id'&&path.contains('/trips/$local/')){
     op['path']=path.replaceFirst('/trips/$local/','/trips/$canonical/');
     changed=true;
    }
    if(changed)await out.put(op);
   }
  }
  await out.delete(row['key'] as String);
  await t.completed;return true;
 }
 Future<bool> _resolveSavedPlan(Map<String,dynamic> row)async{
  if(row['namespace']!=namespace||row['path']!='/api/v1/monthly-plans'||
    row['method']!='POST')return false;
  final p=row['payload'] as Map,month=p['period_ym']?.toString()??'';
  if(!RegExp(r'^[0-9]{4}-(0[1-9]|1[0-2])$').hasMatch(month))return false;
  final remote=await _readRoute('/api/v1/monthly-plans?month=$month');
  for(final raw in remote['items'] as List? ?? []){
   if(raw is Map&&_samePlan(raw,p))
    return _ackParent(row,raw,field:'monthly_plan_id');
  }
  return false;
 }
 Future<bool> _resolveSavedTrip(Map<String,dynamic> row)async{
  if(row['namespace']!=namespace||row['path']!='/api/v1/trips'||
    row['method']!='POST')return false;
  final p=row['payload'] as Map,from=p['start_date']?.toString()??'',
    to=p['end_date']?.toString()??'';
  if(!RegExp(r'^[0-9]{4}-[0-9]{2}-[0-9]{2}$').hasMatch(from)||
     !RegExp(r'^[0-9]{4}-[0-9]{2}-[0-9]{2}$').hasMatch(to))return false;
  final remote=await _readRoute('/api/v1/trips?from=$from&to=$to');
  for(final raw in remote['items'] as List? ?? []){
   if(raw is Map&&_sameTrip(raw,p))
    return _ackParent(row,raw,field:'trip_id');
  }
  return false;
 }
 /// Read-only verification for a stuck 409. Never blindly POST a conflicting
 /// mutation a second time or declare a mismatch successfully synchronized.
 Future<bool> reviewBlocked(String key)async{
  if(_closed||syncing||_reconciling||!key.startsWith('$namespace:'))
   throw StateError('Đang đồng bộ hoặc sai tài khoản');
  await reload();
  final row=pending.where((r)=>r['key']==key).firstOrNull;
  if(row==null||row['status']!='blocked')return false;
  bool matched=false;
  try{
   if(isRoutePatchConflict(row))matched=await _ackAlreadyAppliedRoutePatch(row);
   else if(isRouteDuplicateConflict(row))matched=await _resolveDuplicate(row);
   else if(isPlanDuplicateConflict(row))matched=await _resolveSavedPlan(row);
   else if(isTripDuplicateConflict(row))matched=await _resolveSavedTrip(row);
  }catch(e){
   error='Không đối chiếu được thao tác: ${describeFailure(e)}';
   _notify();return false;
  }
  if(matched){error=null;lastSuccessAt=DateTime.now();await reload();
   if(readyCount>0)unawaited(sync(manual:true));
   return true;
  }
  error='Chưa tìm được bản lưu khớp trên máy chủ. Thao tác còn trên máy; '
    'nếu lỗi 409, không tự gửi lại để tránh trùng.';
  _notify();return false;
 }

 bool _reconciling=false;
 Future<void> reconcileBlockedRoutes()async{
  if(_closed||syncing||_reconciling)return;
  _reconciling=true;
  try{
   await reload();
   var fixed=false;
   for(final row in List<Map<String,dynamic>>.of(pending)){
    if(!isRouteDuplicateConflict(row)&&!isRoutePatchConflict(row)&&
       !isPlanDuplicateConflict(row)&&!isTripDuplicateConflict(row))continue;
    try{
     final matched=isRoutePatchConflict(row)
       ?await _ackAlreadyAppliedRoutePatch(row)
       :isRouteDuplicateConflict(row)?await _resolveDuplicate(row)
       :isPlanDuplicateConflict(row)?await _resolveSavedPlan(row)
       :await _resolveSavedTrip(row);
     if(matched)fixed=true;
    }
    catch(_){
     // A 401/403/timeout must never erase an unacknowledged local operation.
    }
   }
   if(fixed){
    lastSuccessAt=DateTime.now();error=null;
    await reload();
   }
  }finally{_reconciling=false;_notify();}
 }

 /// The server has already confirmed this plan is archived. Only now may the
 /// local create-route graph be dropped. Execution (GPS/visits/surveys/photos)
 /// must always survive.
 Future<int> discardPendingForArchivedPlan(String planId,{bool internal=false})async{
  if(_closed||syncing||(_reconciling&&!internal))return 0;
  await reload();
  final routes=pending.where((row)=>row['path']=='/api/v1/day-routes'&&
    row['method']=='POST'&&
    row['payload'] is Map&&
    (row['payload'] as Map)['monthly_plan_id']==planId).toList();
  final routeIds=routes
    .map((r)=>(r['payload'] as Map)['client_ref']?.toString()??'')
    .where((v)=>v.isNotEmpty).toSet();
  final draftOps=pending.where((row)=>row['method']=='POST'&&
    routeIds.any((id)=>row['path']=='/api/v1/day-routes/$id/stops')).toList();
  final stopIds=draftOps.map((r)=>
    (r['payload'] as Map)['client_ref']?.toString()??'')
    .where((id)=>id.isNotEmpty).toSet();
  final removalKeys={
   for(final r in routes)r['key'] as String,
   for(final r in draftOps)r['key'] as String,
  };
  if(removalKeys.isEmpty)return 0;
  // No real execution may be attached to a to-be-removed local stop/route.
  final drafts=await cached('survey-drafts');
  if(drafts.any((d)=>stopIds.contains(d['day_route_stop_id'])||
      stopIds.contains(d['route_stop_id'])))return 0;
  for(final row in pending.where((r)=>!removalKeys.contains(r['key']))){
   final depends=row['depends_on'] as List? ??[];
   final payload=row['payload'];
   if(depends.any((d)=>routeIds.contains(d)||stopIds.contains(d)))return 0;
   if(payload is Map&&
     (routeIds.contains(payload['day_route_id'])||
      stopIds.contains(payload['route_stop_id'])||
      stopIds.contains(payload['day_route_stop_id'])))return 0;
  }
  final database=await db;
  final tx=database.transaction('outbox',idbModeReadWrite);
  final store=tx.objectStore('outbox');
  for(final key in removalKeys){
   final row=await store.getObject(key);
   if(row is Map&&row['namespace']==namespace&&
      (row['method']=='POST')&&
      (row['path']=='/api/v1/day-routes'||
       routeIds.any((id)=>row['path']=='/api/v1/day-routes/$id/stops'))){
    await store.delete(key);
   }
  }
  await tx.completed;
  await reload();
  if(pending.isEmpty)error=null;
  _notify();
  return removalKeys.length;
 }
 /// Explicit user retry; errors and 409 conflicts are never discarded.
 Future<void> retryBlocked(String key)async{
  if(_closed||syncing||_reconciling||!key.startsWith('$namespace:'))return;
  final d=await db;
  final read=d.transaction('outbox',idbModeReadOnly);
  final rawRow=await read.objectStore('outbox').getObject(key);
  await read.completed;
  if(rawRow is Map){
   final row=Map<String,dynamic>.from(rawRow);
   if(row['namespace']!=namespace)return;
   // Read-only reconciliation is mandatory for 409, but 400/422 may
   // be explicitly retried after the user fixes a validation problem.
   final conflict=looksLikeConflict(row);
   if(conflict&&(isRouteDuplicateConflict(row)||isRoutePatchConflict(row)||
      isPlanDuplicateConflict(row)||isTripDuplicateConflict(row))){
    try{
     final matched=isRoutePatchConflict(row)
      ?await _ackAlreadyAppliedRoutePatch(row)
      :isRouteDuplicateConflict(row)?await _resolveDuplicate(row)
      :isPlanDuplicateConflict(row)?await _resolveSavedPlan(row)
      :await _resolveSavedTrip(row);
     await reload();
     if(matched){error=null;await retryNow();}
     else{
      error='Tuyến hoặc điểm ghé đã tồn tại nhưng nội dung không khớp. '
       'Thao tác vẫn giữ trên máy, không gửi trùng.';
      _notify();
     }
    }catch(e){
     error='Không đối chiếu được thao tác: '+describeFailure(e);_notify();
    }
    return;
   }
   // A selling-only PATCH may be rebased without changing other fields.
   // Never replay any other blocked customer PATCH blindly.
   if(row['status']=='blocked'&&looksLikeConflict(row)&&
      RegExp(r'^/api/v1/customers/[a-f0-9-]{36}$',caseSensitive:false)
       .hasMatch(row['path']?.toString()??'')){
    final payload=row['payload'];
    if(payload is Map&&payload['is_selling'] is bool&&
       payload.keys.every((key)=>
         ['is_selling','version','client_ref'].contains(key))&&
       payload['version'] is int){
     try{
      final response=await session.get(row['path'] as String);
      final server=response['item'];
      if(server is! Map||server['id']!=row['path'].toString().split('/').last||
         server['version'] is! int||server['is_selling'] is! bool){
       throw StateError('Phản hồi khách hàng không hợp lệ');
      }
      if(server['is_selling']==payload['is_selling']){
       await _ackSellingUpdate(row,Map<String,dynamic>.from(server));
       await reload();
       error=null;_notify();
      }else{
       await _updateIfPresent({...row,
        'payload':{...Map<String,dynamic>.from(payload),
          'version':server['version'],'client_ref':const Uuid().v4()},
        'status':'pending','error':null});
       await reload();
       await retryNow();
      }
     }catch(e){
      error='Không thể đối chiếu trạng thái khách hàng: ${describeFailure(e)}';
      _notify();
     }
     return;
    }
   }
   // An unresolved 409 is never replayed blindly. The user may keep it
   // or move it to the recoverable shelf after checking dependencies.
   if(row['status']=='blocked'&&looksLikeConflict(row)){
    error='Lỗi trùng/xung đột chưa đối chiếu được; bản lưu vẫn nằm trên máy.';
    _notify();return;
   }
  }
  final t=d.transaction('outbox',idbModeReadWrite),store=t.objectStore('outbox');
  final raw=await store.getObject(key);
  if(raw is Map&&raw['namespace']==namespace&&raw['status']=='blocked'){
   await store.put({...Map<String,dynamic>.from(raw),'status':'pending','error':null});
  }
  await t.completed;await reload();await retryNow();
 }
 Future<void> start() async{
  try{
   await reload();
   final acknowledged=await cached('sync-blocked-banner-dismiss');
   _dismissedBlockedSignature=acknowledged.firstOrNull?['signature']?.toString();
   _notify();
  }catch(e){error='Không mở được bộ nhớ máy: $e';_notify();return;}
  if(_closed)return;
  _timer=Timer.periodic(const Duration(seconds:30),(_)=>unawaited(sync()));
  unawaited(reconcileBlockedRoutes().then((_)=>sync()).catchError((Object e){
   error='Không đối chiếu được hàng đợi: '+describeFailure(e);_notify();
  }));
 }
 Future<void> sync({bool manual=false}) async{
  if(_closed||_reconciling)return;
  if(syncing){
   // iOS may suspend an in-flight IndexedDB/network Future when PWA sleeps.
   // Do not start a concurrent write: tell the user how to resume safely.
   if(isStalled){
    error='Lượt đồng bộ đã quá 2 phút không phản hồi. Đóng rồi mở lại '
     'Field Work để tiếp tục; dữ liệu chưa gửi vẫn nằm trên máy.';
    _notify();
   }
   return;
  }
  final now=DateTime.now();
  if(!manual&&nextRetryAt!=null&&now.isBefore(nextRetryAt!))return;
  if(manual){nextRetryAt=null;transientFailures=0;}
  // 4xx rejects stay on disk for the user, without retrying endlessly.
  if(pending.isNotEmpty&&readyCount==0){
   error='Có $blockedCount thao tác bị từ chối. Nhấn vào thanh đồng bộ để xem lỗi.';
   _notify();return;
  }
  syncing=true;error=null;activePath=null;lastAttemptAt=now;_notify();
  var matchedDuplicate=false;
  try{
   await reload();
   if(pending.isEmpty){nextRetryAt=null;transientFailures=0;return;}
   if(readyCount==0){
    error='Có $blockedCount thao tác bị từ chối. Mở chi tiết để thử lại.';
    return;
   }
   final me=await session.get('/api/v1/me');
   if(_closed||me['identity']!=identity||me['scope_revision'].toString()!=revision){
    error='Phiên đăng nhập hoặc phạm vi quyền đã thay đổi. Dữ liệu vẫn lưu trên máy.';
    nextRetryAt=DateTime.now().add(const Duration(minutes:5));return;
   }
   var waitingDependencies=0;
   for(final row in List.of(pending)){
    if(_closed)break;
    if(row['status']=='blocked')continue;
    if(await _dependencyPending(row)){waitingDependencies++;continue;}
    activePath=describe(row);_notify();
    try{
     final payload=Map<String,dynamic>.from(row['payload'] as Map);
     final headers={...sessionHeaders(session.cookie),'X-Sync-Identity':identity,'X-Sync-Revision':revision,'X-Sync-Protocol':'2'};
     final uri=session.uri(row['path'] as String);
     if((row['path'] as String).endsWith('/photos')){
      final bytes=Uint8List.fromList((row['photo'] as List).cast<int>());
      final thumb=row['thumbnail'];final modern=thumb is List;
      final upload=await (networkClient?.post(uri,headers:{...headers,'Content-Type':modern?'application/json':row['mime'] as String,'X-Upload-Id':row['upload_id'] as String,if(row['session_id']!=null||row['area_visit_id']!=null)'X-Photo-Kind':payload['kind'] as String,if(row['session_id']!=null||row['area_visit_id']!=null)'X-Captured-At':payload['captured_at'] as String},body:modern?jsonEncode({'image':base64Encode(bytes),'thumbnail':base64Encode(thumb.cast<int>()),'sha256':row['sha256']??payload['sha256'],'thumbnail_sha256':row['thumbnail_sha256']??payload['thumbnail_sha256']}):bytes)??http.post(uri,headers:{...headers,'Content-Type':modern?'application/json':row['mime'] as String,'X-Upload-Id':row['upload_id'] as String,if(row['session_id']!=null||row['area_visit_id']!=null)'X-Photo-Kind':payload['kind'] as String,if(row['session_id']!=null||row['area_visit_id']!=null)'X-Captured-At':payload['captured_at'] as String},body:modern?jsonEncode({'image':base64Encode(bytes),'thumbnail':base64Encode(thumb.cast<int>()),'sha256':row['sha256']??payload['sha256'],'thumbnail_sha256':row['thumbnail_sha256']??payload['thumbnail_sha256']}):bytes)).timeout(const Duration(seconds:30));
      final result=decodeApi(upload);
      if(row['session_id']!=null){await _ackSurvey(row,result['item'] as Map);}else{await _remove(row['key'] as String);}continue;
     }
     final response=await (row['method']=='PATCH'
       ?(networkClient?.patch(uri,headers:headers,body:jsonEncode(payload))??
          http.patch(uri,headers:headers,body:jsonEncode(payload)))
       :(networkClient?.post(uri,headers:headers,body:jsonEncode(payload))??
          http.post(uri,headers:headers,body:jsonEncode(payload)))
      ).timeout(const Duration(seconds:30));
     final result=decodeApi(response);
     // Some successful endpoints only acknowledge the write; entity is optional.
     final item=(row['session_id']!=null||row['photo']!=null)
       ?(result['item'] as Map):<String,dynamic>{};
     if(row['photo']!=null){
      final bytes=Uint8List.fromList((row['photo'] as List).cast<int>());
      if(_closed)break;
      final thumb=row['thumbnail'],modern=thumb is List;
       final upload=await (networkClient?.post(session.uri('/api/v1/customers/${item['id']}/photos'),
        headers:{...headers,'Content-Type':modern?'application/json':row['mime'] as String,'X-Upload-Id':row['upload_id'] as String},
        body:modern?jsonEncode({'image':base64Encode(bytes),'thumbnail':base64Encode(thumb.cast<int>()),
          'sha256':row['sha256'],'thumbnail_sha256':row['thumbnail_sha256']}):bytes)??http.post(
        session.uri('/api/v1/customers/${item['id']}/photos'),
        headers:{...headers,'Content-Type':modern?'application/json':row['mime'] as String,'X-Upload-Id':row['upload_id'] as String},
        body:modern?jsonEncode({'image':base64Encode(bytes),'thumbnail':base64Encode(thumb.cast<int>()),
          'sha256':row['sha256'],'thumbnail_sha256':row['thumbnail_sha256']}):bytes)
       ).timeout(const Duration(seconds:30));
       decodeApi(upload);
     }
     if(result['already_saved']==true&&result['item'] is Map&&
        row['method']=='POST'&&
        (row['path']=='/api/v1/day-routes'||
         RegExp(r'^/api/v1/day-routes/[a-f0-9-]{36}/(stops|unplanned-stops)$',
          caseSensitive:false).hasMatch(row['path']?.toString()??''))){
      // Canonical UUID differs from the local draft. First atomically remap
      // dependent stops/visits, then restart the queue from persisted state.
      if(!await _ackMatchedRouteRow(row,
        Map<String,dynamic>.from(result['item'] as Map),
        isStop:row['path']!='/api/v1/day-routes')){
       throw StateError('Không đối chiếu được mã tuyến đã lưu');
      }
      matchedDuplicate=true;
      lastSuccessAt=DateTime.now();transientFailures=0;nextRetryAt=null;
      break;
     }else if(row['method']=='PATCH'&&
         RegExp(r'^/api/v1/customers/[a-f0-9-]{36}$').hasMatch(row['path'].toString())&&
         payload['is_selling'] is bool){
       final saved=result['item'];
       if(saved is! Map||saved['id']!=row['path'].toString().split('/').last||
          saved['is_selling']!=payload['is_selling']){
         throw StateError('Máy chủ không xác nhận trạng thái đang bán');
       }
       await _ackSellingUpdate(row,Map<String,dynamic>.from(saved));
     }else if(row['session_id']!=null){
      await _ackSurvey(row,item);
     }else{
      await _remove(row['key'] as String);
     }
     lastSuccessAt=DateTime.now();transientFailures=0;nextRetryAt=null;
    }catch(e){
     final path=row['path']?.toString()??'';
     if(e is ApiFailure&&e.status==409&&row['method']=='PATCH'&&
       RegExp(r'^/api/v1/day-routes/[a-f0-9-]{36}$',
        caseSensitive:false).hasMatch(path)){
      try{
       if(await _ackAlreadyAppliedRoutePatch(row)){
        matchedDuplicate=true;lastSuccessAt=DateTime.now();error=null;
        break;
       }
      }catch(_){}
     }
     if(e is ApiFailure&&e.status==409&&row['method']=='POST'&&
      (path=='/api/v1/day-routes'||
       RegExp(r'^/api/v1/day-routes/[a-f0-9-]{36}/(stops|unplanned-stops)$',
        caseSensitive:false).hasMatch(path))){
      try{
       if(await _resolveDuplicate(row)){
        matchedDuplicate=true;
        lastSuccessAt=DateTime.now();error=null;
        break; // Re-read remapped dependencies before continuing.
       }
      }catch(_){}
     }
     if(e is ApiFailure&&e.status==409&&
       (path=='/api/v1/monthly-plans'||path=='/api/v1/trips')){
      try{
       final matched=path=='/api/v1/monthly-plans'
        ?await _resolveSavedPlan(row):await _resolveSavedTrip(row);
       if(matched){
        matchedDuplicate=true;lastSuccessAt=DateTime.now();error=null;break;
       }
      }catch(_){}
     }
     final blocked=e is ApiFailure&&[400,401,403,404,409,413,415,422].contains(e.status);
     await _updateIfPresent({...row,
      'status':blocked?'blocked':'pending',
      'attempts':((row['attempts'] as num?)?.toInt()??0)+1,
      'error':describeFailure(e),
      'last_error_at':DateTime.now().toIso8601String(),
     });
     error='${describe(row)}: ${describeFailure(e)}';
     if(!blocked){
      transientFailures++;
      nextRetryAt=DateTime.now().add(retryDelay);
      break;
     }
    }
   }
   if(error==null&&waitingDependencies>0){
    error='Đang chờ $waitingDependencies thao tác liên quan được hoàn tất.';
   }
  }catch(e){
   error='Không kiểm tra/gửi được dữ liệu: ${describeFailure(e)}';
   transientFailures++;
   nextRetryAt=DateTime.now().add(retryDelay);
  }
  finally{
   activePath=null;
   try{await reload();}catch(e){error='Không đọc được hàng đợi lưu máy: $e';}
   syncing=false;_notify();
   if(matchedDuplicate&&!_closed&&readyCount>0)unawaited(sync(manual:true));
  }
 }
 /// Manual retry first compares blocked routes without resending them.
 Future<void> retryNow()async{
  if(!_closed&&!syncing)await reconcileBlockedRoutes();
  await sync(manual:true);
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
