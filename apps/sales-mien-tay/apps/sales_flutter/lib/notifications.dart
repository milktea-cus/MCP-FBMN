import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'offline_queue.dart';
import 'session.dart';
import 'android_push_bridge.dart';
import 'push_bridge_stub.dart' if (dart.library.html) 'push_bridge_web.dart' as push;

class FieldNotification {
 final String id,title,body,category;
 final DateTime created;
 final DateTime? readAt;
 final int groupCount;
 const FieldNotification(this.id,this.title,this.body,this.created,this.readAt,
  {this.category='',this.groupCount=1});
 bool get unread=>readAt==null;
 bool get actionable=>const {'target','assignment','security','support','order_action'}
  .contains(category);
 factory FieldNotification.parse(Map<String,dynamic> json)=>FieldNotification(
  json['id'].toString(),json['title']?.toString()??'Thông báo',
  json['body']?.toString()??'',DateTime.tryParse(json['created_at']?.toString()??'')??DateTime.now(),
  DateTime.tryParse(json['read_at']?.toString()??''),
  category:json['category']?.toString()??'',
  groupCount:(json['group_count'] as num?)?.toInt()??1);
 Map<String,dynamic> toJson()=>{'id':id,'title':title,'body':body,
  'category':category,'group_count':groupCount,
  'created_at':created.toIso8601String(),'read_at':readAt?.toIso8601String()};
 FieldNotification markRead()=>FieldNotification(id,title,body,created,DateTime.now(),
  category:category,groupCount:groupCount);
}
/// The inbox is scoped by the existing per-account offline namespace.
/// Cached notifications are never interpreted as permission to access the server.
class FieldNotificationStore extends ChangeNotifier {
 final SalesSession session;
 final OfflineQueue queue;
 FieldNotificationStore(this.session,this.queue);
 List<FieldNotification> items=[];
 int unreadCount=0;
 String? nextCursor;
 bool paging=false,preferencesBusy=false,readAllBusy=false;
 List<Map<String,dynamic>> categories=[];
 int quietStart=1260,quietEnd=420;
 bool stale=false,loading=false,pushEnabled=false,hasBrowserPush=false;
 String? error,publicKey,pushReport;
 Map<String,dynamic> androidDiagnostics={};
 bool _closed=false;
 bool get isAndroid=>AndroidPushBridge.supported;
 bool androidConfigured=false,pushBusy=false;
 String? _registeredToken,_registeredBinding;
 DateTime? _registeredAt;
 int get unread=>unreadCount;
 void changed(){if(!_closed){push.badge(unread);notifyListeners();}}
 Future<void> start()async{
  hasBrowserPush=push.supported();
  try{
   items=(await queue.cached('notifications')).map(FieldNotification.parse).toList();
   final meta=await queue.cached('notifications-meta');
   unreadCount=meta.isEmpty?items.where((x)=>x.unread).length:(meta.first['unread_count'] as num?)?.toInt()??0;
   nextCursor=meta.isEmpty?null:meta.first['next_cursor']?.toString();
   final saved=await queue.cached('notifications-settings');
   if(saved.isNotEmpty)_applyPreferences(saved.first);
   stale=true;changed();
  }catch(_){}
  await refresh();
  unawaited(loadPreferences());
  if(isAndroid){
   try{
    final config=await session.get('/api/v1/notifications/config');
    androidConfigured=config['android_supported']==true;
    if(androidConfigured)await _syncAndroid();
   }catch(_){}
  }else if(hasBrowserPush){
   try{
    final config=await session.get('/api/v1/notifications/config');
    publicKey=config['supported']==true?config['public_key']?.toString():null;
    pushEnabled=await push.subscribed();
    if(pushEnabled&&publicKey!=null){
      final raw=await push.existing();
      if(raw.isNotEmpty)await session.post('/api/v1/notifications/subscription',
        Map<String,dynamic>.from(jsonDecode(raw) as Map));
    }
   }catch(_){}
  }
  changed();
 }
 Future<void> _syncAndroid()async{
  if(!isAndroid||!androidConfigured||pushBusy||_closed)return;
  pushBusy=true;
  try{
   androidDiagnostics=await AndroidPushBridge.diagnostics(queue.identity);
   final data=await AndroidPushBridge.status(queue.identity);
   if(_closed)return;
   if(data==null){pushEnabled=false;_registeredToken=null;_registeredBinding=null;return;}
   if(data['token']!=_registeredToken||data['binding']!=_registeredBinding||
     _registeredAt==null||DateTime.now().difference(_registeredAt!).inHours>=6){
    await session.post('/api/v1/notifications/android/subscription',data);
    _registeredToken=data['token'] as String;_registeredBinding=data['binding'] as String;
    _registeredAt=DateTime.now();
   }
   pushEnabled=true;
  }catch(_){pushEnabled=false;}
  finally{pushBusy=false;changed();}
 }
 Future<void> save()async{
  await queue.cache('notifications',items.map((x)=>x.toJson()).toList());
  await queue.cache('notifications-meta',[{'unread_count':unreadCount,'next_cursor':nextCursor}]);
 }
 void _applyPreferences(Map<String,dynamic> doc){
  categories=(doc['categories'] as List? ??[]).whereType<Map>()
    .map((x)=>Map<String,dynamic>.from(x)).toList();
  final quiet=doc['quiet_hours'] as Map?;
  quietStart=(quiet?['quiet_start'] as num?)?.toInt()??1260;
  quietEnd=(quiet?['quiet_end'] as num?)?.toInt()??420;
 }
 Future<void> loadPreferences()async{
  try{
   final doc=await session.get('/api/v1/notifications/preferences');
   if(_closed)return;
   _applyPreferences(doc);
   await queue.cache('notifications-settings',[doc]);
   changed();
  }catch(e){if(e is ApiFailure&&(e.status==401||e.status==403)){
   categories=[];await queue.cache('notifications-settings',[]);
   changed();
  }}
 }
 Future<void> setMode(String category,String mode)async{
  if(preferencesBusy)return;
  final index=categories.indexWhere((x)=>x['category']==category);
  if(index<0)return;
  final previous=categories[index]['mode']?.toString()??'';
  if(previous==mode)return;
  preferencesBusy=true;categories[index]['mode']=mode;changed();
  final doc={'category':category,'mode':mode};
  try{
   await session.patch('/api/v1/notifications/preferences',doc);
   error=null;
  }catch(e){
   if(e is ApiFailure&&e.status>=400&&e.status<500){
    categories[index]['mode']=previous;error=e.message;
   }else{
    try{await queue.enqueue('/api/v1/notifications/preferences',doc,method:'PATCH');}
    catch(_){categories[index]['mode']=previous;error='Không lưu được thiết lập trên máy.';}
   }
  }finally{
   preferencesBusy=false;
   await queue.cache('notifications-settings',[{'categories':categories,
     'quiet_hours':{'quiet_start':quietStart,'quiet_end':quietEnd}}]);changed();
  }
 }
 Future<void> setQuietHours(int start,int end)async{
  if(preferencesBusy)return;
  final oldStart=quietStart,oldEnd=quietEnd;
  quietStart=start;quietEnd=end;preferencesBusy=true;changed();
  try{
   await session.patch('/api/v1/notifications/quiet-hours',{'quiet_start':start,'quiet_end':end});
   error=null;
  }catch(e){
   if(e is ApiFailure&&e.status>=400&&e.status<500){quietStart=oldStart;quietEnd=oldEnd;error=e.message;}
   else{
    try{await queue.enqueue('/api/v1/notifications/quiet-hours',
     {'quiet_start':start,'quiet_end':end},method:'PATCH');}
    catch(_){quietStart=oldStart;quietEnd=oldEnd;error='Không lưu được giờ yên lặng.';}
   }
  }finally{
   preferencesBusy=false;await queue.cache('notifications-settings',[{'categories':categories,
     'quiet_hours':{'quiet_start':quietStart,'quiet_end':quietEnd}}]);changed();
  }
 }
 Future<void> loadMore()async{
  if(loading||paging||nextCursor==null||_closed)return;
  paging=true;changed();
  try{
   final data=await session.get('/api/v1/notifications?limit=40&before=$nextCursor');
   final received=(data['items'] as List).whereType<Map>().map(
      (x)=>FieldNotification.parse(Map<String,dynamic>.from(x))).toList();
   final ids=items.map((x)=>x.id).toSet();
   items=[...items,...received.where((x)=>!ids.contains(x.id))];
   nextCursor=data['next_cursor']?.toString();
   await save();error=null;
  }catch(e){error='Không tải được trang tiếp theo.';}
  finally{paging=false;changed();}
 }
 Future<void> markAllRead()async{
  if(readAllBusy||unreadCount==0)return;
  readAllBusy=true;changed();
  // Snapshot watermark guarantees offline replay never erases a later event.
  final watermark=items.isEmpty?null:items.first.id;
  if(watermark==null){readAllBusy=false;changed();return;}
  final old=items;final oldCount=unreadCount;
  items=items.map((x)=>x.unread?x.markRead():x).toList();
  unreadCount=0;await save();changed();
  try{
   await session.post('/api/v1/notifications/read-all',{'upto':watermark});
   error=null;
  }catch(e){
   if(e is ApiFailure&&e.status>=400&&e.status<500){
    items=old;unreadCount=oldCount;error=e.message;await save();
   }else{
    try{await queue.enqueue('/api/v1/notifications/read-all',
     {'upto':watermark},method:'POST');}
    catch(_){items=old;unreadCount=oldCount;error='Không lưu được thao tác đã đọc.';await save();}
   }
  }finally{readAllBusy=false;changed();}
 }

 Future<void> refresh()async{
  if(_closed||loading)return;
  loading=true;changed();
  try{
   final res=await session.get('/api/v1/notifications');
   final waiting=queue.pending.map((x)=>RegExp(r'/notifications/([0-9]+)/read$')
       .firstMatch(x['path']?.toString()??'')?.group(1)).whereType<String>().toSet();
   final pendingAll=queue.pending.any((x)=>x['path']=='/api/v1/notifications/read-all');
   items=[for(final item in (res['items'] as List).map((x)=>FieldNotification.parse(
      Map<String,dynamic>.from(x as Map))))(pendingAll||waiting.contains(item.id))?item.markRead():item];
   nextCursor=res['next_cursor']?.toString();
   unreadCount=pendingAll?0:((res['unread_count'] as num?)?.toInt()??0);
   if(!pendingAll)unreadCount=(unreadCount-waiting.length).clamp(0,2147483647);
   await save();
   stale=false;error=null;
   if(isAndroid&&androidConfigured)await _syncAndroid();
  }catch(e){
   if(e is ApiFailure&&(e.status==401||e.status==403)){
    items=[];unreadCount=0;nextCursor=null;categories=[];
    await save();await queue.cache('notifications-settings',[]);
    error='Phiên hết hạn hoặc quyền đã thay đổi.';
    if(isAndroid){try{await AndroidPushBridge.disable(queue.identity);}catch(_){}pushEnabled=false;}
   }else{stale=true;error='Thông báo đang hiển thị từ bộ nhớ máy.';}
  }finally{loading=false;changed();}
 }
 Future<void> markRead(FieldNotification item)async{
  if(!item.unread)return;
  try{
   await session.post('/api/v1/notifications/${item.id}/read',{});
  }catch(e){
   if(e is ApiFailure){error=e.message;changed();return;}
   await queue.enqueue('/api/v1/notifications/${item.id}/read',{},method:'POST');
  }
  items=[for(final n in items)n.id==item.id?n.markRead():n];
  unreadCount=(unreadCount-1).clamp(0,2147483647);
  await save();changed();
 }
 Future<void> sendTest()async{
  try{
   final result=await session.post('/api/v1/notifications/test',{});
   await refresh();
   if(isAndroid){
    final report=result['android'];
    if(report is Map){
     final accepted=report['accepted'];
     final reason=report['reason']?.toString();
     pushReport=accepted is num&&accepted>0
       ?'Google FCM đã nhận yêu cầu gửi. Kiểm tra banner/âm thanh trên máy.'
       :'Đã tạo thông báo trong hộp thư nhưng FCM chưa gửi được (${reason??'unknown'}).';
    }else{pushReport='Máy chủ chưa trả kết quả gửi FCM.';}
    androidDiagnostics=await AndroidPushBridge.diagnostics(queue.identity);
   }
   changed();
  }catch(e){error=e.toString();changed();}
 }
 Future<void> localAndroidTest()async{
  try{await AndroidPushBridge.localTest(queue.identity);pushReport='Đã yêu cầu Android hiển thị thông báo thử tại máy.';changed();}
  catch(_){error='Không hiển thị được thông báo thử. Kiểm tra quyền Android.';changed();}
 }
 Future<void> androidSettings()async{
  try{await AndroidPushBridge.settings();}catch(_){error='Không mở được cài đặt Android.';changed();}
 }
 Future<void> enablePush()async{
  if(isAndroid){await _enableAndroid();return;}
  if(publicKey==null){error='Máy chủ chưa cấu hình Push.';changed();return;}
  try{
   // The JS permission prompt begins directly inside the button handler.
   final raw=await push.enable(publicKey!);
   await session.post('/api/v1/notifications/subscription',
    Map<String,dynamic>.from(jsonDecode(raw) as Map));
   pushEnabled=true;error=null;
  }catch(e){pushEnabled=false;error='Không bật được Push: $e';}
  changed();
 }
 Future<void> _enableAndroid()async{
  if(pushBusy||_closed)return;
  if(!androidConfigured){error='Máy chủ chưa cấu hình FCM.';changed();return;}
  pushBusy=true;changed();
  String? binding;
  try{
   final data=await AndroidPushBridge.prepare(queue.identity);
   binding=data['binding'] as String;
   if(_closed)throw StateError('Phiên đã đóng');
   await session.post('/api/v1/notifications/android/subscription',data);
   if(_closed)throw StateError('Phiên đã đóng');
   await AndroidPushBridge.activate(queue.identity,binding);
   _registeredToken=data['token'] as String;_registeredBinding=binding;_registeredAt=DateTime.now();
   pushEnabled=true;error=null;
  }catch(e){
   try{await AndroidPushBridge.disable(queue.identity);}catch(_){}
   if(binding!=null){try{await session.post('/api/v1/notifications/android/unsubscribe',{'binding':binding});}catch(_){}}
   pushEnabled=false;
   error=e is ApiFailure?e.message:'Không bật được thông báo Android. Kiểm tra quyền thông báo, mạng và Google Play Services.';
  }finally{pushBusy=false;changed();}
 }
 Future<void> disablePush()async{
  if(isAndroid){
   // Local suppression first: no old-account notification even during offline logout.
   try{
    final binding=await AndroidPushBridge.disable(queue.identity);
    pushEnabled=false;
    final old=binding??_registeredBinding;
    _registeredToken=null;_registeredBinding=null;_registeredAt=null;
    if(old!=null)await session.post('/api/v1/notifications/android/unsubscribe',{'binding':old});
    error=null;
   }catch(_){pushEnabled=false;error='Đã yêu cầu tắt thông báo; máy chủ sẽ cập nhật lại khi có mạng.';}
   changed();return;
  }
  try{
   final raw=await push.disable();
   if(raw.isNotEmpty){
    final data=Map<String,dynamic>.from(jsonDecode(raw) as Map);
    await session.post('/api/v1/notifications/unsubscribe',{'endpoint':data['endpoint']});
   }
   pushEnabled=false;error=null;
  }catch(e){error='Không tắt được Push: $e';}
  changed();
 }
 @override void dispose(){_closed=true;super.dispose();}
}

class FieldNotificationInbox extends StatelessWidget {
 final FieldNotificationStore store;
 const FieldNotificationInbox({super.key,required this.store});
 @override
 Widget build(BuildContext context)=>Scaffold(
  appBar:AppBar(title:const Text('Thông báo')),
  body:AnimatedBuilder(animation:store,builder:(context,_)=>ListView(
    padding:const EdgeInsets.all(12),children:[
      if(store.stale)const Padding(padding:EdgeInsets.all(8),
        child:Text('Đang xem bản đã lưu trên máy. Có mạng sẽ cập nhật lại.')),
      if(store.error!=null)Padding(padding:const EdgeInsets.all(8),
        child:Text(store.error!,style:TextStyle(color:Theme.of(context).colorScheme.error))),
      if(store.hasBrowserPush||store.isAndroid)Card(child:SwitchListTile(
        title:Text(store.pushEnabled?'Đã bật Push khóa màn hình':'Bật Push khóa màn hình'),
        subtitle:Text(store.isAndroid?(store.androidConfigured?'Cho phép thông báo Android để nhận khi khóa màn hình.':'Máy chủ chưa cấu hình FCM.'):'Cần cho phép thông báo; iPhone phải cài PWA ra Màn hình chính.'),
        secondary:const Icon(Icons.notifications_active_outlined),
        value:store.pushEnabled,
        onChanged:(store.pushBusy||(store.isAndroid?!store.androidConfigured:store.publicKey==null))?null:(value){
          if(value){unawaited(store.enablePush());}
          else{unawaited(store.disablePush());}
        },
      )),
      if(store.isAndroid)Card(child:Padding(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        if(store.androidDiagnostics['sound']==false||((store.androidDiagnostics['importance'] as int?)??4)<4)const Text('Kênh thông báo đang im lặng hoặc không bật banner. Mở cài đặt để chọn âm thanh và hiển thị nổi.'),
        if(store.pushReport!=null)Text(store.pushReport!),
        if((store.androidDiagnostics['receivedAt'] as int? ?? 0)>0)Text('FCM gần nhất: ${DateTime.fromMillisecondsSinceEpoch(store.androidDiagnostics['receivedAt'] as int).toLocal().toString().substring(0,19)}'),
        Wrap(spacing:8,children:[TextButton(onPressed:store.pushEnabled?()=>unawaited(store.localAndroidTest()):null,child:const Text('Thử âm thanh máy')),TextButton(onPressed:()=>unawaited(store.androidSettings()),child:const Text('Cài đặt âm thanh'))]),
      ]))),
      if(!store.hasBrowserPush&&!store.isAndroid)const Card(child:ListTile(
        leading:Icon(Icons.info_outline),title:Text('Push khóa màn hình'),
        subtitle:Text('Thiết bị hoặc trình duyệt hiện không hỗ trợ Push.'),
      )),
      Row(children:[
       Expanded(child:Text('Chưa đọc: ${store.unread}',style:Theme.of(context).textTheme.titleMedium)),
       IconButton(tooltip:'Làm mới',onPressed:()=>unawaited(store.refresh()),icon:const Icon(Icons.refresh)),
       TextButton(onPressed:()=>unawaited(store.sendTest()),child:const Text('Gửi thử')),
      ]),
      if(store.items.isEmpty)const Padding(padding:EdgeInsets.all(24),
       child:Center(child:Text('Chưa có thông báo.'))),
      for(final item in store.items)Card(child:ListTile(
        leading:Icon(item.unread?Icons.mark_email_unread_outlined:Icons.drafts_outlined,
          color:item.unread?Theme.of(context).colorScheme.primary:null),
        title:Text(item.title,style:TextStyle(fontWeight:item.unread?FontWeight.bold:FontWeight.normal)),
        subtitle:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
         Text(item.body),
         Text(item.created.toLocal().toString().substring(0,16),
           style:Theme.of(context).textTheme.bodySmall),
        ]),
        trailing:item.unread?IconButton(tooltip:'Đánh dấu đã đọc',
          onPressed:()=>unawaited(store.markRead(item)),icon:const Icon(Icons.done)):null,
        onTap:item.unread?()=>unawaited(store.markRead(item)):null,
      )),
    ])),
 );
}
