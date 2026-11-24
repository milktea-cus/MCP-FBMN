import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'offline_queue.dart';
import 'session.dart';
import 'android_push_bridge.dart';
import 'push_bridge_stub.dart' if (dart.library.html) 'push_bridge_web.dart' as push;

class FieldNotification {
 final String id,title,body;
 final DateTime created;
 final DateTime? readAt;
 const FieldNotification(this.id,this.title,this.body,this.created,this.readAt);
 bool get unread=>readAt==null;
 factory FieldNotification.parse(Map<String,dynamic> json)=>FieldNotification(
  json['id'].toString(),json['title']?.toString()??'Thông báo',
  json['body']?.toString()??'',DateTime.tryParse(json['created_at']?.toString()??'')??DateTime.now(),
  DateTime.tryParse(json['read_at']?.toString()??''));
 Map<String,dynamic> toJson()=>{'id':id,'title':title,'body':body,
  'created_at':created.toIso8601String(),'read_at':readAt?.toIso8601String()};
 FieldNotification markRead()=>FieldNotification(id,title,body,created,DateTime.now());
}

/// The inbox is scoped by the existing per-account offline namespace.
/// Cached notifications are never interpreted as permission to access the server.
class FieldNotificationStore extends ChangeNotifier {
 final SalesSession session;
 final OfflineQueue queue;
 FieldNotificationStore(this.session,this.queue);
 List<FieldNotification> items=[];
 bool stale=false,loading=false,pushEnabled=false,hasBrowserPush=false;
 String? error,publicKey,pushReport;
 Map<String,dynamic> androidDiagnostics={};
 bool _closed=false;
 bool get isAndroid=>AndroidPushBridge.supported;
 bool androidConfigured=false,pushBusy=false;
 String? _registeredToken,_registeredBinding;
 DateTime? _registeredAt;
 int get unread=>items.where((i)=>i.unread).length;
 void changed(){if(!_closed){push.badge(unread);notifyListeners();}}
 Future<void> start()async{
  hasBrowserPush=push.supported();
  try{
   items=(await queue.cached('notifications')).map(FieldNotification.parse).toList();
   stale=true;changed();
  }catch(_){}
  await refresh();
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
 Future<void> save()async=>queue.cache('notifications',items.map((x)=>x.toJson()).toList());
 Future<void> refresh()async{
  if(_closed||loading)return;
  loading=true;changed();
  try{
   final res=await session.get('/api/v1/notifications');
   final waiting=queue.pending.map((x)=>RegExp(r'/notifications/([0-9]+)/read$')
       .firstMatch(x['path']?.toString()??'')?.group(1)).whereType<String>().toSet();
   items=[for(final item in (res['items'] as List).map((x)=>FieldNotification.parse(
      Map<String,dynamic>.from(x as Map))))waiting.contains(item.id)?item.markRead():item];
   await save();
   stale=false;error=null;
   if(isAndroid&&androidConfigured)await _syncAndroid();
  }catch(e){
   if(e is ApiFailure&&(e.status==401||e.status==403)){
    items=[];error='Phiên hết hạn hoặc quyền đã thay đổi.';
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
