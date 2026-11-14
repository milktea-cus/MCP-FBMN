import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'customers.dart';
import 'offline_queue.dart';
import 'route_workflow.dart';
import 'session.dart';

/// Only the actual route owner can apply a template. A manager's read
/// visibility never grants write access to a subordinate's route.
bool routeTemplateMatchesRoute(Map<String,dynamic> template,
 Map<String,dynamic> route,String owner)=>
 route['owner_sub']==owner&&route['status']=='ready'&&
 route['plan_status']!='cancelled'&&
 template['scope_kind']==route['scope_kind']&&
 template['scope_key']==route['scope_key'];

/// Templates belong in the drawer, never inside the daily customer roster.
class RouteTemplateLibraryPage extends StatefulWidget{
 final CustomerService service;
 final OfflineQueue queue;
 final bool embedded;
 const RouteTemplateLibraryPage({super.key,required this.service,required this.queue,
  this.embedded=false});
 @override State<RouteTemplateLibraryPage> createState()=>_RouteTemplateLibraryPageState();
}
class _RouteTemplateLibraryPageState extends State<RouteTemplateLibraryPage>{
 List<Map<String,dynamic>> templates=[];
 bool busy=false,offline=false;
 String? error;
 final String cacheKey='route-templates-menu-v1';

 @override void initState(){super.initState();unawaited(load());}
 void notify(String message){
  if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(message)));
 }
 Future<void> load()async{
  if(busy)return;
  setState((){busy=true;error=null;});
  try{
   final cached=await widget.queue.cached(cacheKey);
   if(cached.isNotEmpty&&mounted)setState((){templates=cached;offline=true;});
   final response=decodeApi(await http.get(widget.service.uri('/api/v1/route-templates'),
    headers:widget.service.headers).timeout(const Duration(seconds:20)));
   final rows=(response['items'] as List).map((x)=>Map<String,dynamic>.from(x as Map)).toList();
   await widget.queue.cache(cacheKey,rows);
   if(mounted)setState((){templates=rows;offline=false;});
  }catch(e){
   if(e is ApiFailure&&(e.status==401||e.status==403)&&mounted){
    setState((){templates=[];offline=false;});
   }
   if(mounted)setState(()=>error=e.toString());
  }finally{if(mounted)setState(()=>busy=false);}
 }
 Future<void> openMatchingRoute(Map<String,dynamic> template)async{
  if(busy)return;
  setState(()=>busy=true);
  try{
   final now=DateTime.now().toUtc().add(const Duration(hours:7));
   final month='${now.year.toString().padLeft(4,'0')}-${now.month.toString().padLeft(2,'0')}';
   final response=decodeApi(await http.get(widget.service.uri(
     '/api/v1/day-routes',{'month':month}),headers:widget.service.headers)
      .timeout(const Duration(seconds:20)));
   final routes=(response['items'] as List)
    .map((x)=>Map<String,dynamic>.from(x as Map))
    .where((r)=>routeTemplateMatchesRoute(template,r,widget.queue.identity))
    .toList();
   if(!mounted)return;
   if(routes.isEmpty){
    notify('Tháng hiện tại chưa có lịch cùng địa bàn/chuỗi để áp dụng mẫu.');return;
   }
   final selected=await showModalBottomSheet<Map<String,dynamic>>(
    context:context,showDragHandle:true,builder:(sheet)=>SafeArea(
     child:ListView(shrinkWrap:true,children:[
      const ListTile(title:Text('Chọn lịch để dùng hoặc lưu mẫu'),
       subtitle:Text('Chỉ lịch mình phụ trách trong phạm vi phù hợp')),
      for(final route in routes)ListTile(
       leading:const Icon(Icons.calendar_month_outlined),
       title:Text(route['purpose']?.toString()??'Công tác'),
       subtitle:Text(route['route_date']?.toString()??''),
       trailing:const Icon(Icons.chevron_right),
       onTap:()=>Navigator.pop(sheet,route)),
     ])));
   if(selected==null||!mounted)return;
   final detail=decodeApi(await http.get(widget.service.uri(
     '/api/v1/day-routes/${selected['id']}'),headers:widget.service.headers)
      .timeout(const Duration(seconds:20)));
   if(!mounted)return;
   final stops=(detail['stops'] as List)
    .map((x)=>Map<String,dynamic>.from(x as Map)).toList();
   await Navigator.push(context,MaterialPageRoute(builder:(_)=>RouteTemplatePage(
    service:widget.service,queue:widget.queue,
    route:Map<String,dynamic>.from(detail['item'] as Map),stops:stops)));
   if(mounted)await load();
  }catch(e){notify('Không mở được mẫu tuyến: $e');}
  finally{if(mounted)setState(()=>busy=false);}
 }
 @override Widget build(BuildContext context)=>Scaffold(
  appBar:widget.embedded?null:AppBar(title:const Text('Mẫu tuyến'),actions:[
   IconButton(onPressed:busy?null:load,tooltip:'Tải lại mẫu',icon:const Icon(Icons.sync)),
  ]),
  body:ListView(padding:const EdgeInsets.all(12),children:[
   if(widget.embedded)Align(alignment:Alignment.centerRight,
    child:TextButton.icon(onPressed:busy?null:load,
     icon:const Icon(Icons.sync),label:const Text('Đồng bộ mẫu tuyến'))),
   const Text('Mẫu tuyến chỉ lưu khách ưu tiên và thứ tự; '
    'không sao chép GPS, khảo sát hay kết quả công tác.'),
   const SizedBox(height:8),
   if(busy)const LinearProgressIndicator(minHeight:2),
   if(offline)const Text('Đang xem mẫu đã lưu trên máy.'),
   if(error!=null)Text(error!,style:TextStyle(color:Theme.of(context).colorScheme.error)),
   if(templates.isEmpty&&!busy)const Padding(padding:EdgeInsets.all(12),
    child:Text('Chưa có mẫu tuyến. Mở một lịch có khách để lưu mẫu đầu tiên.')),
   for(final template in templates)Card(child:Column(children:[
    ListTile(
     leading:const Icon(Icons.bookmark_outline),
     title:Text(template['name']?.toString()??'Mẫu tuyến'),
     subtitle:Text('${template['scope_kind']=='chain'?'Chuỗi':'Địa bàn'} · '
       '${(template['stops'] as List?)?.length??0} khách ưu tiên · '
       'v${template['version']??1}'),
     trailing:const Icon(Icons.chevron_right),
     onTap:()=>openMatchingRoute(template),
    ),
    if(template['owner_sub']==widget.queue.identity)
     Align(alignment:Alignment.centerRight,child:TextButton.icon(
      onPressed:busy?null:()=>rename(template),
      icon:const Icon(Icons.edit_outlined),label:const Text('Đổi tên mẫu'))),
   ])),
  ]),
 );
 Future<void> rename(Map<String,dynamic> template)async{
  final controller=TextEditingController(text:template['name']?.toString()??'');
  final name=await showDialog<String>(context:context,builder:(dialog)=>AlertDialog(
   title:const Text('Đổi tên mẫu tuyến'),
   content:TextField(controller:controller,maxLength:120,
    decoration:const InputDecoration(labelText:'Tên mẫu')),
   actions:[
    TextButton(onPressed:()=>Navigator.pop(dialog),child:const Text('Hủy')),
    FilledButton(onPressed:()=>Navigator.pop(dialog,controller.text.trim()),
     child:const Text('Lưu')),
   ]));
  controller.dispose();
  if(name==null)return;
  if(name.length<2){notify('Tên mẫu ít nhất 2 ký tự.');return;}
  try{
   await widget.queue.enqueue('/api/v1/route-templates/${template['id']}',{
    'client_ref':const Uuid().v4(),'version':template['version'],
    'name':name,'scope_kind':template['scope_kind'],
    'scope_key':template['scope_key'],
    'province':template['province'],'district':template['district'],
    'stops':template['stops'],
   },method:'PATCH');
   if(mounted)setState(()=>templates=[
    for(final t in templates)if(t['id']==template['id']){...t,'name':name}else t,
   ]);
   notify('Đã lưu tên mẫu trên máy · chờ đồng bộ.');
  }catch(e){notify('Không đổi được mẫu: $e');}
 }
}
