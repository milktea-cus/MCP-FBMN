import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'offline_queue.dart';
import 'session.dart';
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
 String? error,publicKey;
 bool _closed=false;
 int get unread=>items.where((i)=>i.unread).length;
 void changed(){if(!_closed){push.badge(unread);notifyListeners();}}
 Future<void> start()async{
  hasBrowserPush=push.supported();
  try{
   items=(await queue.cached('notifications')).map(FieldNotification.parse).toList();
   stale=true;changed();
  }catch(_){}
  await refresh();
  if(hasBrowserPush){
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
  }catch(e){
   if(e is ApiFailure&&(e.status==401||e.status==403)){
    items=[];error='Phiên hết hạn hoặc quyền đã thay đổi.';
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
  try{await session.post('/api/v1/notifications/test',{});await refresh();}
  catch(e){error=e.toString();changed();}
 }
 Future<void> enablePush()async{
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
 Future<void> disablePush()async{
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
      if(store.hasBrowserPush)Card(child:SwitchListTile(
        title:Text(store.pushEnabled?'Đã bật Push khóa màn hình':'Bật Push khóa màn hình'),
        subtitle:const Text('Cần cho phép thông báo; iPhone phải cài PWA ra Màn hình chính.'),
        secondary:const Icon(Icons.notifications_active_outlined),
        value:store.pushEnabled,
        onChanged:store.publicKey==null?null:(value){
          if(value){unawaited(store.enablePush());}
          else{unawaited(store.disablePush());}
        },
      )),
      if(!store.hasBrowserPush)const Card(child:ListTile(
        leading:Icon(Icons.info_outline),title:Text('Push khóa màn hình'),
        subtitle:Text('Android native cần FCM; hiện chỉ bật Web Push trong PWA được hỗ trợ.'),
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
