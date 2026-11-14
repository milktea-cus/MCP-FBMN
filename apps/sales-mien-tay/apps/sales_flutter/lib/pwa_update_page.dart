import 'dart:async';
import 'package:flutter/material.dart';
import 'pwa_update_bridge_stub.dart'
 if (dart.library.html) 'pwa_update_bridge_web.dart' as bridge;

const String runningPwaBuild=String.fromEnvironment('FBMN_BUILD_SHA',defaultValue:'dev');

/// App-shell update never resets business IndexedDB, session, or offline queue.
class PwaUpdatePage extends StatefulWidget{
 const PwaUpdatePage({super.key});
 @override State<PwaUpdatePage> createState()=>_PwaUpdatePageState();
}
class _PwaUpdatePageState extends State<PwaUpdatePage>{
 bool checking=false,updating=false;
 Map<String,dynamic>? result;
 String? error;
 @override void initState(){super.initState();unawaited(check());}
 Future<void> check()async{
  if(checking)return;
  setState((){checking=true;error=null;});
  try{
   final info=await bridge.pwaCheckVersion(runningPwaBuild);
   if(mounted)setState(()=>result=info);
  }catch(e){if(mounted)setState(()=>error=e.toString());}
  finally{if(mounted)setState(()=>checking=false);}
 }
 Future<void> update()async{
  if(checking||updating||result?['available']!=true)return;
  setState((){updating=true;error=null;});
  try{
   await bridge.pwaActivateUpdate();
   if(mounted)setState(()=>error='Đã kích hoạt bản mới. Ứng dụng sẽ tự mở lại.');
  }catch(e){if(mounted)setState(()=>error='Chưa cập nhật: $e. Dữ liệu trên máy được giữ nguyên.');}
  finally{if(mounted)setState(()=>updating=false);}
 }
 @override Widget build(BuildContext context){
  final info=result;
  final version=info?['latest']?.toString()??'Chưa kiểm tra';
  final available=info?['available']==true;
  return Scaffold(
   appBar:AppBar(title:const Text('Cập nhật PWA iPhone')),
   body:ListView(padding:const EdgeInsets.all(16),children:[
    const Text('Cập nhật trực tiếp từ máy chủ; không phải xóa ứng dụng hoặc dữ liệu offline.'),
    const SizedBox(height:12),
    ListTile(title:const Text('Bản đang chạy'),subtitle:SelectableText(runningPwaBuild)),
    ListTile(title:const Text('Bản trên máy chủ'),subtitle:SelectableText(version)),
    if(checking||updating)const LinearProgressIndicator(),
    if(error!=null)Padding(padding:const EdgeInsets.symmetric(vertical:8),
     child:Text(error!,style:TextStyle(color:Theme.of(context).colorScheme.error))),
    if(info!=null&&!available)
     const ListTile(leading:Icon(Icons.check_circle_outline),title:Text('Đã ở bản mới nhất')),
    const SizedBox(height:8),
    OutlinedButton.icon(onPressed:checking||updating?null:check,
     icon:const Icon(Icons.refresh),label:const Text('Kiểm tra bản mới')),
    const SizedBox(height:8),
    if(available)FilledButton.icon(
     key:const ValueKey('pwa-update-now'),
     onPressed:checking||updating?null:update,
     icon:const Icon(Icons.system_update_alt),label:const Text('Cập nhật ngay')),
    if(available)const Padding(padding:EdgeInsets.only(top:12),
     child:Text('Hãy lưu biểu mẫu đang nhập trước khi cập nhật. Bản mới sẽ mở lại tự động một lần; IndexedDB không bị xóa.')),
   ]),
  );
 }
}
