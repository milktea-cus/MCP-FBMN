import 'dart:async';
import 'package:flutter/material.dart';
import 'session.dart';
import 'models.dart';
import 'main.dart';
import 'offline_queue.dart';

class AuthGate extends StatefulWidget {
 const AuthGate({super.key});
 @override State<AuthGate> createState()=>_AuthGateState();
}
class _AuthGateState extends State<AuthGate> with WidgetsBindingObserver {
 final session=SalesSession();
 final email=TextEditingController(),password=TextEditingController();
 Map<String,dynamic>? me;
 RegionCatalog? catalog;
 bool busy=true,checking=false,obscure=true,otpMode=true,logoutPending=false;
 String? error,notice;
 bool recovering=false, connectionNotice=false;
 bool _logoutStateChecked=false;
 DateTime? leaseExpires;
 Timer? timer;
 @override void initState(){
  super.initState();WidgetsBinding.instance.addObserver(this);
  onSessionRejected=(){if(me!=null)unawaited(revalidate());};
  timer=Timer.periodic(const Duration(seconds:30),(_){if(me!=null||recovering)unawaited(revalidate());});
  unawaited(start());
 }
 /// A failed offline SQLite read must not be mistaken for an expired login.
 /// A valid server session remains usable even when the optional lease fails.
 Future<void> start() async{
  try{
   try{
    await session.restore();
   }catch(_){
    if(mounted)setState(()=>error='Không đọc được phiên bảo mật trên thiết bị. '
      'Dữ liệu chưa đồng bộ vẫn giữ nguyên. Hãy đăng nhập lại.');
    return;
   }
   bool pending=false;
   try{
    pending=await OfflineLease.logoutPending();
   }catch(_){
    // Retry a transient database-open failure; never erase the secure cookie.
    try{pending=await OfflineLease.logoutPending();}
    catch(_){
     if(mounted)setState(()=>error='Không mở được dữ liệu offline để kiểm tra '
       'yêu cầu đăng xuất. Hãy chọn Khôi phục phiên sau khi khởi động lại.');
     return;
    }
   }
   _logoutStateChecked=true;
   if(pending){
    if(mounted)setState(()=>logoutPending=true);
    try{
     await session.logout();
     try{await OfflineLease.finishLogout();}catch(_){}
     if(mounted)setState(()=>logoutPending=false);
    }catch(_){
     if(mounted)setState(()=>error='Đã yêu cầu đăng xuất. Kết nối mạng '
       'và bấm Hoàn tất đăng xuất.');
    }
    return;
   }
   await revalidate();
  }catch(_){
   if(mounted)setState(()=>error='Chưa hoàn tất bước khôi phục. '
     'Phiên trên máy chưa bị xóa; chọn Khôi phục phiên để thử lại.');
  }finally{
   if(mounted)setState(()=>busy=false);
  }
 }
 @override void didChangeAppLifecycleState(AppLifecycleState state){if(state==AppLifecycleState.resumed&&me!=null)unawaited(revalidate());}
 Future<void> revalidate() async{
  if(checking||logoutPending)return;checking=true;
  try{
   // A failed local SQLite read is not permission to bypass a pending logout.
   if(!_logoutStateChecked){
    bool pending;
    try{pending=await OfflineLease.logoutPending();}
    catch(_){
     if(mounted)setState(()=>error='Không xác minh được trạng thái đăng xuất '
       'trên máy. Thử Khôi phục phiên khi dữ liệu offline sẵn sàng.');
     return;
    }
    if(pending){
     if(mounted)setState(()=>logoutPending=true);
     return;
    }
    _logoutStateChecked=true;
   }
   final next=await session.get('/api/v1/me');
   if(!mounted||logoutPending)return;
   if(connectionNotice||recovering){if(mounted)setState((){connectionNotice=false;recovering=false;error=null;});}
   final changed=me==null||me!['identity']!=next['identity']||me!['scope_revision']!=next['scope_revision']||me!['role']!=next['role'];
   if(changed){
    // Cache/lease I/O is best-effort; server-authenticated users must not be
    // sent to the login page solely because an offline database is unavailable.
    try{await OfflineLease.clear();}catch(_){}
    if(me!=null){if(!mounted)return;Navigator.of(context).popUntil((r)=>r.isFirst);setState((){me=null;catalog=null;});}
    // /me already authenticated the actor. A temporary metadata outage must
    // not force logout; public province labels are bundled with the app.
    RegionCatalog regions;
    try{
     final meta=await session.get('/api/v1/meta');
     regions=RegionCatalog((meta['districts'] as Map<String,dynamic>)
       .map((k,v)=>MapEntry(k,(v as List).cast<String>())));
    }catch(e){
     if(e is ApiFailure&&(e.status==401||e.status==403))rethrow;
     regions=await RegionCatalog.load();
    }
    if(!mounted||logoutPending)return;
    Navigator.of(context).popUntil((r)=>r.isFirst);
    setState((){me=next;catalog=regions;error=null;});
   }
   leaseExpires=DateTime.now().add(OfflineLease.duration);
   if(catalog!=null){try{await OfflineLease.remember(next,catalog!.districts);}catch(_){/* online session remains available */}
   }
  }catch(e){
   final hadSession=me!=null;
   final rejected=e is ApiFailure && (e.status==401||e.status==403);
   if(!rejected){
    if(hadSession&&leaseExpires!=null&&DateTime.now().isBefore(leaseExpires!)){if(mounted&&!connectionNotice){connectionNotice=true;ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Mất kết nối tạm thời. Phiên vẫn được giữ.')));}return;}
    if(!hadSession){try{final saved=await OfflineLease.read();if(saved!=null&&mounted&&!logoutPending){final cachedMe=Map<String,dynamic>.from(saved['me'] as Map);final districts=(saved['districts'] as Map).map((k,v)=>MapEntry(k.toString(),(v as List).cast<String>()));leaseExpires=DateTime.fromMillisecondsSinceEpoch(saved['expires'] as int);setState((){me=cachedMe;catalog=RegionCatalog(districts);recovering=false;connectionNotice=true;});return;}}catch(_) {}}
    // Never hold the whole app on an endless recovery spinner during an outage.
    // Preserve the cookie and account-scoped offline data for an explicit retry.
    if(mounted){
     Navigator.of(context).popUntil((r)=>r.isFirst);
     setState((){
      me=null;catalog=null;recovering=false;
      error='Không kết nối được máy chủ. Kiểm tra mạng rồi chọn Khôi phục phiên.';
     });
    }
    return;
   }
   recovering=false;
   if(rejected){
    try{await OfflineLease.clear();}catch(_){}
    try{await session.clear();}catch(_){
     // The server already rejected the cookie. No authenticated UI may stay.
     session.cookie='';
    }
   }
   if(mounted){
    if(hadSession)Navigator.of(context).popUntil((r)=>r.isFirst);
    setState((){me=null;catalog=null;error=hadSession||e.status!=401?e.toString():null;});
   }
  }finally{checking=false;}
 }
 Future<void> login() async{
  if(busy||logoutPending||email.text.trim().isEmpty||password.text.isEmpty)return;
  setState((){busy=true;error=null;});
  try{await OfflineLease.clear();await session.login(email.text.trim(),password.text,otp:otpMode);await revalidate();}
  catch(e){if(mounted)setState(()=>error=e.toString());}
  finally{password.clear();if(mounted)setState(()=>busy=false);}
 }
 Future<void> sendOtp() async {
  if(busy||logoutPending||email.text.trim().isEmpty)return;
  setState((){busy=true;error=null;notice=null;});
  try{await session.requestOtp(email.text.trim());if(mounted)setState(()=>notice='Nếu email đã được cấp quyền, mã đăng nhập sẽ được gửi đến hộp thư.');}
  catch(e){if(mounted)setState(()=>error=e.toString());}
  finally{if(mounted)setState(()=>busy=false);}
 }
 Future<void> logout() async{
  if(busy)return;
  setState((){logoutPending=true;busy=true;me=null;catalog=null;recovering=false;});
  try{await OfflineLease.markLogout();await session.logout();await OfflineLease.finishLogout();if(!mounted)return;Navigator.of(context).popUntil((r)=>r.isFirst);setState((){me=null;catalog=null;error=null;logoutPending=false;});}
  catch(e){if(mounted){Navigator.of(context).popUntil((r)=>r.isFirst);setState((){me=null;catalog=null;error='Chưa xác nhận đăng xuất trên máy chủ. Hãy kết nối mạng và thử lại.';});}}
  finally{if(mounted)setState(()=>busy=false);}
 }
 @override void dispose(){timer?.cancel();onSessionRejected=null;WidgetsBinding.instance.removeObserver(this);email.dispose();password.dispose();super.dispose();}
 @override Widget build(BuildContext context){
  // The login form below always stays accessible when session recovery fails.
  if(me!=null&&catalog!=null)return SalesHome(key:ValueKey(me!['identity'].toString()+':'+me!['scope_revision'].toString()),session:session,me:me!,catalog:catalog!,onLogout:logout);
  return Scaffold(body:SafeArea(child:Center(child:SingleChildScrollView(padding:const EdgeInsets.all(24),child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:420),child:Card(child:Padding(padding:const EdgeInsets.all(24),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,mainAxisSize:MainAxisSize.min,children:[
   Image.asset('assets/fbmn-transparent-logo.webp',height:46,alignment:Alignment.centerLeft),const SizedBox(height:12),
   Text('Field Work',style:Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight:FontWeight.bold)),
   const SizedBox(height:8),const Text('Đăng nhập bằng tài khoản nhân viên được cấp.'),
   const SizedBox(height:24),
   const Text('Email',style:TextStyle(fontSize:13)),const SizedBox(height:6),
   TextField(controller:email,enabled:!busy,keyboardType:TextInputType.emailAddress,autofillHints:const [AutofillHints.username],decoration:const InputDecoration(hintText:'Email nhân viên')),
   const SizedBox(height:14),Text(otpMode?'Mã đăng nhập email':'Mật khẩu',style:const TextStyle(fontSize:13)),const SizedBox(height:6),
   TextField(controller:password,enabled:!busy,obscureText:otpMode?false:obscure,keyboardType:otpMode?TextInputType.number:TextInputType.visiblePassword,autofillHints:otpMode?const [AutofillHints.oneTimeCode]:const [AutofillHints.password],onSubmitted:(_)=>login(),decoration:InputDecoration(suffixIcon:otpMode?null:IconButton(tooltip:obscure?'Hiện mật khẩu':'Ẩn mật khẩu',onPressed:()=>setState(()=>obscure=!obscure),icon:Icon(obscure?Icons.visibility_outlined:Icons.visibility_off_outlined)))),
   if(otpMode)TextButton(onPressed:busy||logoutPending?null:sendOtp,child:const Text('Gửi mã đăng nhập')),
   TextButton(onPressed:busy||logoutPending?null:()=>setState((){otpMode=!otpMode;password.clear();error=null;notice=null;}),child:Text(otpMode?'Dùng mật khẩu':'Dùng mã email')),
   if(notice!=null)Text(notice!),
   if(logoutPending)...[const SizedBox(height:12),
    const Text('Phiên đăng xuất cũ đang chờ xác nhận từ máy chủ. Chọn Hoàn tất đăng xuất để thử lại.')],
   if(error!=null)...[const SizedBox(height:12),Text(error!,style:TextStyle(color:Theme.of(context).colorScheme.error))],
   const SizedBox(height:20),FilledButton(onPressed:busy||logoutPending?null:login,child:busy?const SizedBox(width:20,height:20,child:CircularProgressIndicator(strokeWidth:2)):const Text('Đăng nhập')),
   TextButton(onPressed:busy||logoutPending?null:()=>unawaited(revalidate()),child:const Text('Khôi phục phiên')),
   TextButton(onPressed:busy?null:logout,child:Text(logoutPending?'Hoàn tất đăng xuất':'Xóa phiên / Đăng xuất')),
  ]))))))));
 }
}
