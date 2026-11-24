import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'offline_queue.dart';
import 'session.dart';
import 'android_push_bridge.dart';
import 'push_bridge_stub.dart' if (dart.library.html) 'push_bridge_web.dart' as push;

bool notificationCoveredByWatermark(String id,BigInt? cutoff){
 final value=BigInt.tryParse(id);
 return cutoff!=null&&value!=null&&value<=cutoff;
}

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
 Future<void> _inboxTail=Future.value();
 bool _refreshQueued=false,_pageQueued=false;
 int _preferenceRevision=0;
 Future<void> _serial(Future<void> Function() action){
  final next=_inboxTail.then((_)async{if(!_closed)await action();});
  _inboxTail=next.catchError((Object e){error='Không hoàn tất được thao tác thông báo.';changed();});
  return _inboxTail;
 }
 bool _retryable(Object e)=>e is! ApiFailure||e.status>=500||e.status==408||e.status==429;
 Iterable<Map<String,dynamic>> get _pending=>queue.pending.where((x)=>x['status']!='blocked');
 Future<void> _saveSafely()async{try{await save();}catch(_){error='Không lưu được thông báo trên máy.';}}
 Future<void> _savePreferences()async{
  try{await queue.cache('notifications-settings',[{'categories':categories,'quiet_hours':{'quiet_start':quietStart,'quiet_end':quietEnd}}]);}
  catch(_){error='Không lưu được thiết lập trên máy.';}
 }
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
  for(final op in _pending){
   final payload=op['payload'];if(payload is! Map)continue;
   if(op['path']=='/api/v1/notifications/preferences'){
    for(final c in categories.where((c)=>c['category']==payload['category'])){
     c['mode']=c['mandatory']==true&&payload['mode']=='off'?'in_app':payload['mode'];
    }
   }else if(op['path']=='/api/v1/notifications/quiet-hours'){
    quietStart=(payload['quiet_start'] as num?)?.toInt()??quietStart;
    quietEnd=(payload['quiet_end'] as num?)?.toInt()??quietEnd;
   }
  }
 }
 Future<void> loadPreferences()async{
  final rev=_preferenceRevision;
  try{
   final doc=await session.get('/api/v1/notifications/preferences');
   if(_closed||rev!=_preferenceRevision||preferencesBusy)return;
   _applyPreferences(doc);
   await _savePreferences();
   changed();
  }catch(e){if(!_closed&&rev==_preferenceRevision&&!preferencesBusy&&e is ApiFailure&&(e.status==401||e.status==403)){
   categories=[];try{await queue.cache('notifications-settings',[]);}catch(_){}
   changed();
  }}
 }
 Future<void> setMode(String category,String mode)async{
  if(preferencesBusy)return;
  final index=categories.indexWhere((x)=>x['category']==category);
  if(index<0)return;
  final previous=categories[index]['mode']?.toString()??'';
  if(categories[index]['mandatory']==true&&mode=='off')mode='in_app';
  if(previous==mode)return;
  _preferenceRevision++;preferencesBusy=true;categories[index]['mode']=mode;changed();
  final doc={'category':category,'mode':mode};
  try{
   if(_pending.any((op)=>op['path']=='/api/v1/notifications/preferences'&&(op['payload'] as Map?)?['category']==category)){
    await queue.enqueue('/api/v1/notifications/preferences',doc,method:'PATCH');
    error='Thiết lập đã lưu trên máy, chờ đồng bộ.';
   }else{
    final result=await session.patch('/api/v1/notifications/preferences',doc);
    final item=result['item'];if(item is Map&&item['mode'] is String)categories[index]['mode']=item['mode'];
    error=null;
   }
  }catch(e){
   if(!_retryable(e)){
    categories[index]['mode']=previous;error=e.toString();
   }else{
    try{await queue.enqueue('/api/v1/notifications/preferences',doc,method:'PATCH');error='Thiết lập đã lưu trên máy, chờ đồng bộ.';}
    catch(_){categories[index]['mode']=previous;error='Không lưu được thiết lập trên máy.';}
   }
  }finally{
   preferencesBusy=false;await _savePreferences();changed();
  }
 }
 Future<void> setQuietHours(int start,int end)async{
  if(preferencesBusy||start<0||start>=1440||end<0||end>=1440)return;
  _preferenceRevision++;
  final oldStart=quietStart,oldEnd=quietEnd;
  quietStart=start;quietEnd=end;preferencesBusy=true;changed();
  try{
   final doc={'quiet_start':start,'quiet_end':end};
   if(_pending.any((op)=>op['path']=='/api/v1/notifications/quiet-hours')){
    await queue.enqueue('/api/v1/notifications/quiet-hours',doc,method:'PATCH');
    error='Giờ yên lặng đã lưu trên máy, chờ đồng bộ.';
   }else{await session.patch('/api/v1/notifications/quiet-hours',doc);error=null;}
  }catch(e){
   if(!_retryable(e)){quietStart=oldStart;quietEnd=oldEnd;error=e.toString();}
   else{
    try{await queue.enqueue('/api/v1/notifications/quiet-hours',
     {'quiet_start':start,'quiet_end':end},method:'PATCH');error='Giờ yên lặng đã lưu trên máy, chờ đồng bộ.';}
    catch(_){quietStart=oldStart;quietEnd=oldEnd;error='Không lưu được giờ yên lặng.';}
   }
  }finally{
   preferencesBusy=false;await _savePreferences();changed();
  }
 }
 bool _pendingRead(FieldNotification item){
  return _pending.any((op){
   if(op['path']=='/api/v1/notifications/${item.id}/read')return true;
   final payload=op['payload'];
   return op['path']=='/api/v1/notifications/read-all'&&payload is Map&&
     notificationCoveredByWatermark(item.id,BigInt.tryParse(payload['upto']?.toString()??''));
  });
 }
 List<FieldNotification> _parseItems(Map<String,dynamic> doc)=>(doc['items'] as List)
  .whereType<Map>().map((x)=>FieldNotification.parse(Map<String,dynamic>.from(x))).toList();
 Future<void> _clearDenied()async{
  items=[];unreadCount=0;nextCursor=null;categories=[];
  error='Phiên hết hạn hoặc quyền đã thay đổi.';
  await _saveSafely();
  try{await queue.cache('notifications-settings',[]);}catch(_){}
  if(isAndroid){try{await AndroidPushBridge.disable(queue.identity);}catch(_){}pushEnabled=false;}
 }
 Future<void> loadMore()async{
  if(_pageQueued||_closed||nextCursor==null)return;
  _pageQueued=true;
  try{await _serial(()async{
   final before=nextCursor;if(before==null)return;
   paging=true;changed();
   try{
    final data=await session.get('/api/v1/notifications?limit=40&before=$before');
    final received=_parseItems(data);
    final ids=items.map((x)=>x.id).toSet();
    items=[...items,...received.where((x)=>ids.add(x.id)).map((x)=>_pendingRead(x)?x.markRead():x)];
    final cursor=data['next_cursor']?.toString();
    nextCursor=cursor==before?null:cursor;error=null;await _saveSafely();
   }catch(e){
    if(e is ApiFailure&&(e.status==401||e.status==403))await _clearDenied();
    else error='Không tải được trang tiếp theo.';
   }finally{paging=false;changed();}
  });}finally{_pageQueued=false;}
 }
 Future<void> markAllRead()=>_serial(()async{
  if(unreadCount==0||items.isEmpty)return;
  readAllBusy=true;changed();
  final watermark=items.first.id;
  try{
   try{await session.post('/api/v1/notifications/read-all',{'upto':watermark});error=null;}
   catch(e){
    if(!_retryable(e)){error=e.toString();return;}
    await queue.enqueue('/api/v1/notifications/read-all',{'upto':watermark},method:'POST');
    error='Đã lưu thao tác đọc tất cả trên máy.';
   }
   items=items.map((x)=>x.unread?x.markRead():x).toList();
   unreadCount=0;await _saveSafely();
  }catch(_){error='Không lưu được thao tác đã đọc.';}
  finally{readAllBusy=false;changed();}
 });
 Future<void> refresh()async{
  if(_closed||_refreshQueued)return;
  _refreshQueued=true;
  try{await _serial(()async{
   loading=true;changed();
   try{
    final res=await session.get('/api/v1/notifications');
    final serverItems=_parseItems(res);
    var cursor=res['next_cursor']?.toString();
    final depth=items.length;
    // Reload the previously opened depth, not stale cached tail rows.
    while(cursor!=null&&serverItems.length<depth){
     final before=cursor;
     final page=await session.get('/api/v1/notifications?limit=40&before=$before');
     final ids=serverItems.map((x)=>x.id).toSet();
     final additional=_parseItems(page).where((x)=>ids.add(x.id)).toList();
     serverItems.addAll(additional);
     cursor=page['next_cursor']?.toString();
     if(additional.isEmpty||cursor==before){cursor=null;break;}
    }
    if(_closed)return;
    final locallyRead=serverItems.where((item)=>item.unread&&_pendingRead(item)).length;
    items=[for(final item in serverItems)_pendingRead(item)?item.markRead():item];
    nextCursor=cursor;
    unreadCount=(((res['unread_count'] as num?)?.toInt()??0)-locallyRead).clamp(0,2147483647);
    stale=false;error=null;await _saveSafely();
    if(isAndroid&&androidConfigured)await _syncAndroid();
   }catch(e){
    if(e is ApiFailure&&(e.status==401||e.status==403))await _clearDenied();
    else{stale=true;error='Thông báo đang hiển thị từ bộ nhớ máy.';}
   }finally{loading=false;changed();}
  });}finally{_refreshQueued=false;}
 }
 Future<void> markRead(FieldNotification item)=>_serial(()async{
  final current=items.where((x)=>x.id==item.id).firstOrNull;
  if(current==null||!current.unread)return;
  try{
   try{await session.post('/api/v1/notifications/${item.id}/read',{});error=null;}
   catch(e){
    if(!_retryable(e)){error=e.toString();return;}
    if(!_pendingRead(current))await queue.enqueue('/api/v1/notifications/${item.id}/read',{},method:'POST');
    error='Đã lưu trạng thái đọc trên máy.';
   }
   items=[for(final n in items)n.id==item.id?n.markRead():n];
   unreadCount=(unreadCount-1).clamp(0,2147483647);
   await _saveSafely();
  }catch(_){error='Không lưu được thao tác đã đọc.';}
  finally{changed();}
 });
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


String notificationCategoryName(String c)=>const <String,String>{
 'target':'Chỉ tiêu','assignment':'Phân công','security':'Bảo mật',
 'support':'Đề xuất hỗ trợ','order_action':'Đơn cần xử lý','daily_digest':'Tổng hợp công việc',
 'email':'Email','monthly_plan':'Kế hoạch tháng','school':'Trường học','catalog':'Danh mục','inventory':'Tồn kho','day_route':'Tuyến ngày','weekly_route':'Tuyến tuần','monthly_route':'Tuyến tháng',
 'trip':'Chuyến công tác','survey':'Khảo sát','prospect':'Điểm tiềm năng',
 'actuals':'Doanh số','release':'Bản cập nhật','sync':'Đồng bộ',
 'order_summary':'Đơn hàng','customer':'Khách hàng','competitor':'Đối thủ'
}[c]??'Thông báo';

IconData notificationCategoryIcon(String c)=>switch(c){
 'target'=>Icons.flag_outlined,
 'assignment'||'security'=>Icons.admin_panel_settings_outlined,
 'support'=>Icons.support_agent_outlined,
 'order_action'||'order_summary'=>Icons.shopping_cart_outlined,
 'daily_digest'||'day_route'||'weekly_route'||'monthly_route'||'trip'=>Icons.route_outlined,
 'email'=>Icons.mail_outline,'survey'=>Icons.fact_check_outlined,
 'prospect'||'customer'=>Icons.storefront_outlined,'release'=>Icons.system_update_outlined,
 _=>Icons.notifications_none_outlined
};

class FieldNotificationInbox extends StatefulWidget{
 final FieldNotificationStore store;
 final Future<void> Function(FieldNotification)? onOpen;
 const FieldNotificationInbox({super.key,required this.store,this.onOpen});
 @override State<FieldNotificationInbox> createState()=>_FieldNotificationInboxState();
}
class _FieldNotificationInboxState extends State<FieldNotificationInbox>{
 String filter='all';
 bool opening=false;
 Future<void> _open(FieldNotification item)async{
  if(opening)return;
  setState(()=>opening=true);
  try{
   if(widget.onOpen!=null){await widget.onOpen!(item);}
   else{await widget.store.markRead(item);}
  }catch(_){
   if(mounted)ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content:Text('Không mở được nghiệp vụ. Kiểm tra quyền hoặc kết nối.')));
  }finally{if(mounted)setState(()=>opening=false);}
 }
 String day(DateTime time){
  final d=time.toLocal(),today=DateTime.now();
  if(d.year==today.year&&d.month==today.month&&d.day==today.day)return 'Hôm nay';
  final yesterday=today.subtract(const Duration(days:1));
  if(d.year==yesterday.year&&d.month==yesterday.month&&d.day==yesterday.day)return 'Hôm qua';
  return d.day.toString().padLeft(2,'0')+'/'+d.month.toString().padLeft(2,'0')+'/'+d.year.toString();
 }
 String hour(DateTime time){
  final d=time.toLocal();
  return d.hour.toString().padLeft(2,'0')+':'+d.minute.toString().padLeft(2,'0');
 }
 @override Widget build(BuildContext context)=>Scaffold(
  appBar:AppBar(title:const Text('Trung tâm thông báo'),actions:[
   IconButton(tooltip:'Thiết lập thông báo',icon:const Icon(Icons.tune_outlined),
    onPressed:()=>Navigator.push(context,MaterialPageRoute(
     builder:(_)=>FieldNotificationSettingsPage(store:widget.store))))]),
  body:AnimatedBuilder(animation:widget.store,builder:(context,_){
   final store=widget.store;
   final showing=store.items.where((item)=>filter=='unread'?item.unread:
     filter=='action'?item.actionable:true).toList();
   final children=<Widget>[
    if(store.loading)const LinearProgressIndicator(minHeight:2),
    if(store.stale)const Padding(padding:EdgeInsets.all(8),
     child:Text('Đang xem bản lưu trên thiết bị. Có mạng sẽ tự cập nhật.')),
    if(store.error!=null)Padding(padding:const EdgeInsets.all(8),
     child:Text(store.error!,style:TextStyle(color:Theme.of(context).colorScheme.error))),
    Row(children:[
     Expanded(child:Text(store.unread.toString()+' chưa đọc',
       style:Theme.of(context).textTheme.titleMedium)),
     IconButton(tooltip:'Làm mới',onPressed:store.loading?null:()=>unawaited(store.refresh()),
      icon:const Icon(Icons.refresh)),
     TextButton.icon(icon:const Icon(Icons.done_all,size:18),label:const Text('Đọc tất cả'),
      onPressed:store.readAllBusy||store.unread==0?null:()=>unawaited(store.markAllRead()))
    ]),
    Wrap(spacing:8,runSpacing:6,children:[
     for(final choice in const [('all','Tất cả'),('action','Cần xử lý'),('unread','Chưa đọc')])
      FilterChip(label:Text(choice.$2),selected:filter==choice.$1,
       onSelected:(_)=>setState(()=>filter=choice.$1))
    ]),
    const SizedBox(height:12),
    if(showing.isEmpty)const Padding(padding:EdgeInsets.all(28),
     child:Center(child:Text('Không có thông báo trong bộ lọc này.'))),
   ];
   String? lastDay;
   for(final item in showing){
    final value=day(item.created);
    if(lastDay!=value){
     children.add(Padding(padding:const EdgeInsets.fromLTRB(4,10,0,6),
      child:Text(value,style:Theme.of(context).textTheme.titleSmall)));
     lastDay=value;
    }
    children.add(Card(margin:const EdgeInsets.only(bottom:7),child:ListTile(
     key:ValueKey('notification-'+item.id),
     contentPadding:const EdgeInsets.symmetric(horizontal:12,vertical:6),
     leading:Icon(notificationCategoryIcon(item.category),
      color:item.unread?Theme.of(context).colorScheme.primary:null),
     title:Text(item.title,maxLines:2,overflow:TextOverflow.ellipsis,
      style:TextStyle(fontWeight:item.unread?FontWeight.w700:FontWeight.w500)),
     subtitle:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const SizedBox(height:4),Text(item.body,maxLines:3,overflow:TextOverflow.ellipsis),
      const SizedBox(height:6),
      Text(notificationCategoryName(item.category)+' · '+hour(item.created)+
       (item.groupCount>1?' · '+item.groupCount.toString()+' sự kiện':''),
       style:Theme.of(context).textTheme.bodySmall)
     ]),
     trailing:item.unread?IconButton(tooltip:'Đánh dấu đã đọc',
      icon:const Icon(Icons.done,size:20),
      onPressed:()=>unawaited(store.markRead(item))):
      const Icon(Icons.chevron_right),
     onTap:opening?null:()=>unawaited(_open(item)),
    )));
   }
   if(store.nextCursor!=null)children.add(Padding(
    padding:const EdgeInsets.symmetric(vertical:10),
    child:OutlinedButton.icon(
     icon:store.paging?const SizedBox(width:16,height:16,
      child:CircularProgressIndicator(strokeWidth:2)):const Icon(Icons.expand_more),
     label:const Text('Xem thông báo cũ'),
     onPressed:store.paging?null:()=>unawaited(store.loadMore()))));
   return ListView(padding:const EdgeInsets.all(12),children:children);
  }),
 );
}

class FieldNotificationSettingsPage extends StatelessWidget{
 final FieldNotificationStore store;
 const FieldNotificationSettingsPage({super.key,required this.store});
 String showTime(int minute)=>(minute~/60).toString().padLeft(2,'0')+':'+
   (minute%60).toString().padLeft(2,'0');
 Future<void> pick(BuildContext context,bool start)async{
  final n=start?store.quietStart:store.quietEnd;
  final t=await showTimePicker(context:context,initialTime:TimeOfDay(hour:n~/60,minute:n%60));
  if(t==null)return;
  await store.setQuietHours(start?t.hour*60+t.minute:store.quietStart,
   start?store.quietEnd:t.hour*60+t.minute);
 }
 Widget item(Map<String,dynamic> entry){
  final key=entry['category']?.toString()??'';
  final choice=entry['mode']?.toString()??'off';
  return ListTile(dense:true,
   leading:Icon(notificationCategoryIcon(key),size:20),
   title:Text(notificationCategoryName(key)),
   subtitle:entry['mandatory']==true?const Text('Bắt buộc giữ trong hộp thư'):null,
   trailing:DropdownButton<String>(
    value:const ['immediate','digest','in_app','off'].contains(choice)?choice:'off',
    onChanged:store.preferencesBusy?null:(v){if(v!=null)unawaited(store.setMode(key,v));},
    items:[
     const DropdownMenuItem(value:'immediate',child:Text('Báo ngay')),
     const DropdownMenuItem(value:'digest',child:Text('Tổng hợp')),
     const DropdownMenuItem(value:'in_app',child:Text('Trong app')),
     DropdownMenuItem(value:'off',enabled:entry['mandatory']!=true,child:const Text('Tắt'))
    ]));
 }
 @override Widget build(BuildContext context)=>Scaffold(
  appBar:AppBar(title:const Text('Thiết lập thông báo')),
  body:AnimatedBuilder(animation:store,builder:(context,_){
   final active=store.categories.where((r)=>r['producer_enabled']==true).toList();
   final other=store.categories.where((r)=>r['producer_enabled']!=true).toList();
   return ListView(padding:const EdgeInsets.all(12),children:[
    Text('Theo nghiệp vụ',style:Theme.of(context).textTheme.titleMedium),
    const Padding(padding:EdgeInsets.symmetric(vertical:6),
     child:Text('Chọn báo ngay, tổng hợp, chỉ trong app hoặc tắt từng nghiệp vụ.')),
    if(active.isEmpty)const ListTile(title:Text('Thiết lập chưa tải được'),
     subtitle:Text('Có thể đang offline. Mở lại khi kết nối.')),
    for(final row in active)item(row),
    if(other.isNotEmpty)ExpansionTile(
     title:Text('Nhóm chưa kích hoạt ('+other.length.toString()+')'),
     children:[for(final row in other)ListTile(
      title:Text(notificationCategoryName(row['category']?.toString()??'')),
      subtitle:const Text('Chưa phát thông báo nghiệp vụ'))]),
    const SizedBox(height:12),
    Text('Giờ yên lặng · Việt Nam (UTC+7)',style:Theme.of(context).textTheme.titleMedium),
    Row(children:[
     Expanded(child:OutlinedButton.icon(
      icon:const Icon(Icons.bedtime_outlined),
      label:Text('Từ '+showTime(store.quietStart)),
      onPressed:store.preferencesBusy?null:()=>unawaited(pick(context,true)))),
     const SizedBox(width:8),
     Expanded(child:OutlinedButton.icon(
      icon:const Icon(Icons.wb_sunny_outlined),
      label:Text('Đến '+showTime(store.quietEnd)),
      onPressed:store.preferencesBusy?null:()=>unawaited(pick(context,false)))),
    ]),
    const SizedBox(height:5),
    const Text('Âm thanh, rung và màn hình khóa phụ thuộc quyền hệ điều hành.'),
    if(store.isAndroid||store.hasBrowserPush)SwitchListTile(
     title:const Text('Nhận Push trên thiết bị này'),
     value:store.pushEnabled,
     onChanged:store.pushBusy?null:(v)=>unawaited(v?store.enablePush():store.disablePush())),
    ListTile(
     leading:const Icon(Icons.health_and_safety_outlined),
     title:const Text('Chẩn đoán và gửi thử'),
     subtitle:const Text('Tách khỏi hộp thư công việc để tránh thao tác nhầm'),
     trailing:const Icon(Icons.chevron_right),
     onTap:()=>Navigator.push(context,MaterialPageRoute(
       builder:(_)=>FieldNotificationDiagnosticsPage(store:store)))),
    if(store.error!=null)Text(store.error!,
     style:TextStyle(color:Theme.of(context).colorScheme.error)),
   ]);
  }));
}

class FieldNotificationDiagnosticsPage extends StatelessWidget{
 final FieldNotificationStore store;
 const FieldNotificationDiagnosticsPage({super.key,required this.store});
 @override Widget build(BuildContext context)=>Scaffold(
  appBar:AppBar(title:const Text('Chẩn đoán Push')),
  body:AnimatedBuilder(animation:store,builder:(context,_)=>
   ListView(padding:const EdgeInsets.all(14),children:[
    ListTile(leading:const Icon(Icons.notifications_outlined),
     title:Text(store.pushEnabled?'Thiết bị đã đăng ký Push':'Chưa bật Push trên thiết bị')),
    if(store.isAndroid)Card(child:Padding(padding:const EdgeInsets.all(12),
     child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      if(store.androidDiagnostics['sound']==false||
       ((store.androidDiagnostics['importance'] as int?)??4)<4)
        const Text('Android đang tắt âm thanh hoặc banner nổi.'),
      if((store.androidDiagnostics['receivedAt'] as int? ??0)>0)
       Text('FCM gần nhất tại máy: '+
        DateTime.fromMillisecondsSinceEpoch(store.androidDiagnostics['receivedAt'] as int).toLocal().toString()),
      TextButton.icon(icon:const Icon(Icons.music_note),
       onPressed:store.pushEnabled?()=>unawaited(store.localAndroidTest()):null,
       label:const Text('Thử âm thanh trên máy')),
      TextButton.icon(icon:const Icon(Icons.settings_outlined),
       onPressed:()=>unawaited(store.androidSettings()),
       label:const Text('Cài đặt Android')),
     ]))),
    if(store.pushReport!=null)Text(store.pushReport!),
    FilledButton.icon(icon:const Icon(Icons.send_outlined),
     onPressed:()=>unawaited(store.sendTest()),
     label:const Text('Gửi thử từ máy chủ tới tài khoản của tôi')),
    const SizedBox(height:8),
    const Text('FCM chấp nhận yêu cầu không bảo đảm thiết bị đã hiển thị thông báo trên màn hình khóa.'),
    if(store.error!=null)Text(store.error!,
     style:TextStyle(color:Theme.of(context).colorScheme.error)),
   ])));
}
