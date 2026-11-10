import 'dart:async';
import 'package:flutter/material.dart';
import 'session.dart';
import 'models.dart';
import 'main.dart';

class AuthGate extends StatefulWidget {
 const AuthGate({super.key});
 @override State<AuthGate> createState()=>_AuthGateState();
}
class _AuthGateState extends State<AuthGate> with WidgetsBindingObserver {
 final session=SalesSession();
 final email=TextEditingController(),password=TextEditingController();
 Map<String,dynamic>? me;
 RegionCatalog? catalog;
 bool busy=true,checking=false,obscure=true;
 String? error;
 Timer? timer;
 @override void initState(){
  super.initState();WidgetsBinding.instance.addObserver(this);
  onSessionRejected=(){if(me!=null)unawaited(revalidate());};
  timer=Timer.periodic(const Duration(seconds:30),(_){if(me!=null)unawaited(revalidate());});
  unawaited(start());
 }
 Future<void> start() async{
  try{await session.restore();await revalidate();}
  catch(_){if(mounted)setState(()=>error='Không khôi phục được phiên. Vui lòng đăng nhập lại.');}
  finally{if(mounted)setState(()=>busy=false);}
 }
 @override void didChangeAppLifecycleState(AppLifecycleState state){if(state==AppLifecycleState.resumed&&me!=null)unawaited(revalidate());}
 Future<void> revalidate() async{
  if(checking)return;checking=true;
  try{
   final next=await session.get('/api/v1/me');
   if(!mounted)return;
   final changed=me==null||me!['identity']!=next['identity']||me!['scope_revision']!=next['scope_revision']||me!['role']!=next['role'];
   if(changed){
    final meta=await session.get('/api/v1/meta');
    final regions=RegionCatalog((meta['districts'] as Map<String,dynamic>).map((k,v)=>MapEntry(k,(v as List).cast<String>())));
    if(!mounted)return;
    Navigator.of(context).popUntil((r)=>r.isFirst);
    setState((){me=next;catalog=regions;error=null;});
   }
  }catch(e){
   final hadSession=me!=null;
   if(e is ApiFailure && (e.status==401||e.status==403)) await session.clear();
   if(mounted){
    if(hadSession)Navigator.of(context).popUntil((r)=>r.isFirst);
    setState((){me=null;catalog=null;error=hadSession||!(e is ApiFailure&&e.status==401)?e.toString():null;});
   }
  }finally{checking=false;}
 }
 Future<void> login() async{
  if(busy||email.text.trim().isEmpty||password.text.isEmpty)return;
  setState((){busy=true;error=null;});
  try{await session.login(email.text.trim(),password.text);await revalidate();}
  catch(e){if(mounted)setState(()=>error=e.toString());}
  finally{password.clear();if(mounted)setState(()=>busy=false);}
 }
 Future<void> logout() async{
  try{await session.logout();if(!mounted)return;Navigator.of(context).popUntil((r)=>r.isFirst);setState((){me=null;catalog=null;error=null;});}
  catch(e){if(mounted){Navigator.of(context).popUntil((r)=>r.isFirst);setState((){me=null;catalog=null;error='Chưa xác nhận đăng xuất trên máy chủ. Hãy kết nối mạng và thử lại.';});}}
 }
 @override void dispose(){timer?.cancel();onSessionRejected=null;WidgetsBinding.instance.removeObserver(this);email.dispose();password.dispose();super.dispose();}
 @override Widget build(BuildContext context){
  if(me!=null&&catalog!=null)return SalesHome(key:ValueKey(me!['identity'].toString()+':'+me!['scope_revision'].toString()),session:session,me:me!,catalog:catalog!,onLogout:logout);
  return Scaffold(body:SafeArea(child:Center(child:SingleChildScrollView(padding:const EdgeInsets.all(24),child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:420),child:Card(child:Padding(padding:const EdgeInsets.all(24),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,mainAxisSize:MainAxisSize.min,children:[
   Text('Sales Miền Tây',style:Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight:FontWeight.bold)),
   const SizedBox(height:8),const Text('Đăng nhập bằng tài khoản nhân viên được cấp.'),
   const SizedBox(height:24),
   const Text('Email',style:TextStyle(fontSize:13)),const SizedBox(height:6),
   TextField(controller:email,enabled:!busy,keyboardType:TextInputType.emailAddress,autofillHints:const [AutofillHints.username],decoration:const InputDecoration(hintText:'Email nhân viên')),
   const SizedBox(height:14),const Text('Mật khẩu',style:TextStyle(fontSize:13)),const SizedBox(height:6),
   TextField(controller:password,enabled:!busy,obscureText:obscure,autofillHints:const [AutofillHints.password],onSubmitted:(_)=>login(),decoration:InputDecoration(suffixIcon:IconButton(tooltip:obscure?'Hiện mật khẩu':'Ẩn mật khẩu',onPressed:()=>setState(()=>obscure=!obscure),icon:Icon(obscure?Icons.visibility_outlined:Icons.visibility_off_outlined)))),
   if(error!=null)...[const SizedBox(height:12),Text(error!,style:TextStyle(color:Theme.of(context).colorScheme.error))],
   const SizedBox(height:20),FilledButton(onPressed:busy?null:login,child:busy?const SizedBox(width:20,height:20,child:CircularProgressIndicator(strokeWidth:2)):const Text('Đăng nhập')),
   TextButton(onPressed:busy?null:()=>unawaited(revalidate()),child:const Text('Khôi phục phiên')),
   TextButton(onPressed:busy?null:logout,child:const Text('Xóa phiên / Đăng xuất')),
  ]))))))));
 }
}
