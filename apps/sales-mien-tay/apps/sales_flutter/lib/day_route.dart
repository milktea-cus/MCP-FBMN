import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'customers.dart';
import 'customer_categories.dart';
import 'models.dart';
import 'offline_queue.dart';
import 'session.dart';
import 'surveys.dart';
import 'route_workflow.dart';
import 'schedule_archive.dart';
import 'work_session_identity.dart';
import 'dart:convert';

bool scopeSupportsExtra(Map<String,dynamic> route)=>
 route['scope_kind']=='territory'||route['scope_kind']=='chain';
String missedReasonLabel(Object? value)=>switch(value){
 'closed'=>'Khách đóng cửa',
 'unavailable'=>'Không gặp được khách',
 'unable'=>'Không đi được',
 'other'=>'Lý do khác',
 _=>'Chưa rõ',
};

/// Combine planned, queued and assigned-scope customers without
/// creating fake area stops or requiring selection in the monthly plan.
/// The customer ID is the deduplication key across all three sources.
List<Map<String,dynamic>> dayRouteCustomerCards(
 List<Map<String,dynamic>> stops,List<Map<String,dynamic>> assigned,
 List<Map<String,dynamic>> pending,{String query='',
 Map<String,Map<String,dynamic>> localCustomers=const {}}){
 final seen=<String>{};
 final rows=<Map<String,dynamic>>[];
 void append(Map<String,dynamic> row,String source){
  final customerId=row['customer_id']?.toString()??row['id']?.toString()??'';
  if(customerId.isEmpty||!seen.add(customerId))return;
  final local=localCustomers[customerId];
  final assignedRow=assigned.where((c)=>c['id'].toString()==customerId).firstOrNull;
  final customerName=(row['customer_name']??row['name']??assignedRow?['name']??local?['name']??'Khách hàng').toString();
  final district=(row['customer_district']??row['district']??assignedRow?['district']??local?['district']??'').toString();
  final province=(row['customer_province']??row['province']??assignedRow?['province']??local?['province']??'').toString();
  final category=(row['category']??assignedRow?['category']??local?['category'])?.toString();
  rows.add({...row,'customer_id':customerId,'customer_name':customerName,
   'customer_district':district,'customer_province':province,
   'customer_code':row['customer_code']??row['code']??assignedRow?['code']??local?['code']??'',
   'category':category,'source':source,'stop_kind':'customer'});
 }
 for(final stop in stops)if(stop['stop_kind']=='customer')append(stop,'planned');
 for(final job in pending){
  final v=job['payload'];
  if(v is Map&&v['stop_kind']=='customer'){
   final item=Map<String,dynamic>.from(v);
   item['id']=item['client_ref'];
   item['sync_status']=job['status'];
   item['sync_error']=job['error'];
   item['sync_key']=job['key'];
   append(item,'pending');
  }
 }
 for(final customer in assigned)append(customer,'scope');
 final needle=query.trim().toLowerCase();
 if(needle.isEmpty)return rows;
 return rows.where((c)=>
  ('${c['customer_name']} ${c['customer_code']} ${c['customer_district']}')
   .toLowerCase().contains(needle)).toList();
}

/// A day route may be a customer route or a market-development trip with no customers.
class DayRoutePage extends StatefulWidget {
 final OfflineQueue queue;
 final CustomerService service;
 final String routeId;
 final Map<String,dynamic>? cachedRoute;
 const DayRoutePage({super.key,required this.queue,required this.service,required this.routeId,this.cachedRoute});
 @override State<DayRoutePage> createState()=>_DayRoutePageState();
}
class _DayRoutePageState extends State<DayRoutePage>{
 Map<String,dynamic>? route;
 List<Map<String,dynamic>> stops=[],candidates=[];
 String candidateQuery='';
 bool busy=false,offline=false;
 String? error;
 int previousPending=0;
 String get key=>'day-route:${widget.routeId}';
 String get candidateKey=>'day-route-candidates:${widget.routeId}';
 @override void initState(){
  super.initState();
  route=widget.cachedRoute==null?null:effectiveRouteDate(widget.cachedRoute!,widget.queue.pending,widget.queue.identity);
  previousPending=widget.queue.pending.length;
  widget.queue.addListener(_changed);
  unawaited(load());
 }
 @override void dispose(){widget.queue.removeListener(_changed);super.dispose();}
 void _changed(){
  if(!mounted)return;
  final count=widget.queue.pending.length;
  if(count<previousPending&&!busy)unawaited(load());
  previousPending=count;
  setState((){});
 }
 void notice(String message){
  if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(message)));
 }
 Future<List<Map<String,dynamic>>> safeCached(String key)async{
  try{return await widget.queue.cached(key).timeout(const Duration(seconds:4));}
  catch(_){return <Map<String,dynamic>>[];}
 }
 Future<void> load()async{
  if(busy)return;
  setState((){busy=true;error=null;});
  try{
   // The monthly editor may have cached this territory's full customer list
   // even when the route-detail GET is temporarily offline/slow.
   final previous=await safeCached(candidateKey);
   if(previous.isNotEmpty&&mounted)setState(()=>candidates=previous);
   final areaRoute=route;
   if(previous.isEmpty&&areaRoute!=null&&
      areaRoute['scope_kind']!=null&&areaRoute['scope_key']!=null){
    final scope='${areaRoute['scope_kind']}:${areaRoute['scope_key']}';
    final saved=await safeCached('monthly-plan-candidates:$scope');
    if(saved.isNotEmpty&&mounted)setState(()=>candidates=saved);
   }
   final cached=await safeCached(key);
   if(cached.isNotEmpty&&mounted)setState((){
    route=effectiveRouteDate(Map<String,dynamic>.from(cached.first['route'] as Map),widget.queue.pending,widget.queue.identity);
    stops=(cached.first['stops'] as List).map((x)=>Map<String,dynamic>.from(x as Map)).toList();
    offline=true;
   });
   final res=decodeApi(await http.get(widget.service.uri('/api/v1/day-routes/${widget.routeId}'),
     headers:widget.service.headers).timeout(const Duration(seconds:20)));
   final item=Map<String,dynamic>.from(res['item'] as Map);
   final list=(res['stops'] as List).map((x)=>Map<String,dynamic>.from(x as Map)).toList();
   try{await widget.queue.cache(key,[{'route':item,'stops':list}]);}catch(_){}
   if(mounted)setState((){route=effectiveRouteDate(item,widget.queue.pending,widget.queue.identity);stops=list;offline=false;});
   try{
    final r=decodeApi(await http.get(widget.service.uri('/api/v1/day-routes/${widget.routeId}/candidates'),
      headers:widget.service.headers).timeout(const Duration(seconds:20)));
    candidates=(r['items'] as List).map((x)=>Map<String,dynamic>.from(x as Map)).toList();
    try{await widget.queue.cache(candidateKey,candidates);}catch(_){}
   }catch(e){
    if(e is ApiFailure&&(e.status==401||e.status==403))rethrow;
    final cached=await safeCached(candidateKey);
    if(cached.isNotEmpty)candidates=cached;
   }
  }catch(e){
   if(e is ApiFailure&&(e.status==401||e.status==403)){
    if(mounted)setState((){route=null;stops=[];candidates=[];offline=false;});
   }else{
    final cached=await safeCached(candidateKey);
    if(cached.isNotEmpty)candidates=cached;
   }
   if(mounted)setState(()=>error=e.toString());
  }finally{if(mounted)setState(()=>busy=false);}
 }
 List<Map<String,dynamic>> get pendingStops=>widget.queue.pending.where((op){
  final path=op['path']?.toString()??'';
  return (path.startsWith('/api/v1/day-routes/${widget.routeId}/stops')&&
    !path.endsWith('/missed'))||
   path=='/api/v1/day-routes/${widget.routeId}/unplanned-stops';
 }).toList();
 bool get isTodayRoute{
  final date=DateTime.tryParse(route?['route_date']?.toString()??'');
  final today=DateTime.now().toUtc().add(const Duration(hours:7));
  return date!=null&&date.year==today.year&&date.month==today.month&&date.day==today.day;
 }
 bool get hasRecordedActivity=>
  ((route?['market_visit_count'] as num?)?.toInt()??0)>0||
  widget.queue.pending.any((op)=>op['path']=='/api/v1/area-visits'&&
    (op['payload'] as Map?)?['day_route_id']==widget.routeId)||
  stops.any((stop)=>
    ((stop['visit_count'] as num?)?.toInt()??0)>0||
    ((stop['session_count'] as num?)?.toInt()??0)>0||
    stop['missed_code']!=null);
 String get workState=>route==null?'open':workSessionState(route!,widget.queue.pending);
 String get sessionId=>route==null?'':workSessionRouteId(route!,widget.queue.identity);
 bool get sessionActive=>workState=='ongoing';
 bool get canExecute=>canModify&&sessionActive&&isTodayRoute;
 bool get canEditPlannedStops=>canModify&&workState=='open'&&!hasRecordedActivity;
 bool missedPending(String id)=>widget.queue.pending.any((op)=>
  op['path']=='/api/v1/day-routes/${widget.routeId}/stops/$id/missed');
 bool activityPending(String id)=>widget.queue.pending.any((op){
  final payload=op['payload'];
  if(payload is! Map)return false;
  return (payload['route_stop_id']??payload['day_route_stop_id'])?.toString()==id;
 });
 int get nextOrder{
  var maxSeq=0;
  for(final r in stops){
   final n=(r['sequence'] as num?)?.toInt()??0;
   if(n>maxSeq)maxSeq=n;
  }
  for(final r in pendingStops){
   final n=((r['payload'] as Map)['sequence'] as num?)?.toInt()??0;
   if(n>maxSeq)maxSeq=n;
  }
  return maxSeq+1;
 }
 bool get isOwner=>route!=null&&route!['owner_sub']==widget.queue.identity;
 bool get canModify=>isOwner&&route!['status']=='ready'
   &&route!['plan_status']!='cancelled'&&
   workState!='done'&&workState!='cancelled'&&!busy;
 List<String> _routeDependencies()=>[
  for(final op in widget.queue.pending)
   if(op['path']=='/api/v1/day-routes'&&
      (op['payload'] as Map)['client_ref']==widget.routeId)
    widget.routeId,
  for(final op in widget.queue.pending)
   if(op['path']=='/api/v1/day-routes/${widget.routeId}/work-session')
    sessionId,
 ];
 Future<void> createCustomer()async{
  if(!canExecute||!scopeSupportsExtra(route!))return;
  final regions=await RegionCatalog.load();
  if(!mounted)return;
  final current=route!;
  final created=await Navigator.push<bool>(context,MaterialPageRoute(builder:(_)=>
   CustomerEditor(service:widget.service,regions:regions,queue:widget.queue,
    defaultProvince:current['scope_kind']=='territory'?current['province']?.toString():null,
    defaultDistrict:current['scope_kind']=='territory'?current['district']?.toString():null,
    onCreated:(id)async{
     await widget.queue.enqueue('/api/v1/day-routes/${widget.routeId}/unplanned-stops',{
      'client_ref':const Uuid().v4(),'stop_kind':'customer','customer_id':id,
      'sequence':nextOrder,'purpose':'Khách mới trong công tác',
      'captured_at':DateTime.now().toUtc().toIso8601String(),
     },dependsOn:[id,..._routeDependencies()]);
    },
   )));
  if(created==true&&mounted){notice('Đã lưu khách mới vào công tác trên máy.');await load();}
 }
 /// Opening a customer card only reads details; a route stop is created
 /// when the employee actually chooses an activity. This avoids phantom
 /// "outside plan" stops from simply browsing the assigned customer list.
 Future<Map<String,dynamic>?> ensureCustomerStop(Map<String,dynamic> customer)async{
  if(customer['source']!='scope')return customer;
  if(!canExecute)return null;
  final id=customer['customer_id']?.toString()??'';
  if(id.isEmpty)return null;
  for(final row in stops){
   if(row['customer_id']?.toString()==id)return row;
  }
  for(final p in pendingStops){
   if((p['payload'] as Map?)?['customer_id']?.toString()==id){
    return {...customer,'id':(p['payload'] as Map)['client_ref'],
     'source':'pending','sync_status':p['status']};
   }
  }
  try{
   final ref=const Uuid().v4();
   await widget.queue.enqueue('/api/v1/day-routes/${widget.routeId}/unplanned-stops',{
    'client_ref':ref,'stop_kind':'customer','customer_id':id,
    'sequence':nextOrder,'purpose':'Ghé khách trong phạm vi',
    'captured_at':DateTime.now().toUtc().toIso8601String(),
   },dependsOn:_routeDependencies());
   return {...customer,'id':ref,'source':'pending','sync_status':'pending'};
  }catch(e){
   notice('Không lưu được thao tác tại khách: $e');
   return null;
  }
 }
 Future<void> customerWork(Map<String,dynamic> stop)async{
  if(stop['stop_kind']!='customer')return;
  final action=await showModalBottomSheet<String>(context:context,
   showDragHandle:true,isScrollControlled:true,builder:(sheet)=>SafeArea(
    child:Padding(padding:const EdgeInsets.fromLTRB(12,4,12,16),child:
     Column(mainAxisSize:MainAxisSize.min,children:[
      CustomerCategoryLabel(category:stop['category']?.toString()),
      ListTile(title:Text(stop['customer_name']?.toString()??'Khách hàng',
       style:Theme.of(context).textTheme.titleMedium),
       subtitle:Text('${stop['customer_district']??''} · ${stop['customer_province']??''}')),
      const Divider(),
      ListTile(leading:const Icon(Icons.location_on_outlined),
       title:const Text('Check-in GPS'),
       enabled:canExecute&&stop['missed_code']==null,
       onTap:()=>Navigator.pop(sheet,'gps')),
      ListTile(leading:const Icon(Icons.checklist_outlined),
       title:const Text('Thông tin khách · Tick nhãn hàng'),
       subtitle:const Text('Khảo sát, ảnh và ghi chú theo lần ghé'),
       enabled:sessionActive&&isOwner&&isTodayRoute,
       onTap:()=>Navigator.pop(sheet,'survey')),
      ListTile(leading:const Icon(Icons.event_busy_outlined),
       title:const Text('Không ghé · Ghi lý do'),
       enabled:canExecute&&stop['missed_code']==null,
       onTap:()=>Navigator.pop(sheet,'missed')),
     ]))));
  if(!mounted)return;
  if(action==null)return;
  final recorded=await ensureCustomerStop(stop);
  if(recorded==null)return;
  if(action=='gps')await visit(recorded);
  if(action=='survey')await openCustomerSurvey(recorded);
  if(action=='missed')await recordMissed(recorded);
 }
 Future<void> addCustomers()async{
  if(!canEditPlannedStops)return;
  if(candidates.isEmpty){
   notice('Chưa có khách gợi ý trên tuyến. Có thể dùng Tìm khách mới để ghi nhận tại địa bàn mà không cần khách sẵn.');
   return;
  }
  final selected=<String>{};
  final picked=await showDialog<List<String>>(context:context,builder:(ctx)=>StatefulBuilder(
   builder:(ctx,setChoice)=>AlertDialog(
    title:const Text('Chọn nhiều khách trên tuyến'),
    content:SizedBox(width:440,height:360,child:ListView.builder(
     itemCount:candidates.length,itemBuilder:(c,i){
      final customer=candidates[i],id=customer['id'].toString();
      return CheckboxListTile(
       dense:true,controlAffinity:ListTileControlAffinity.leading,
       value:selected.contains(id),title:Text(customer['name'].toString()),
       subtitle:Text('${customer['district']}, ${customer['province']}'),
       onChanged:(checked)=>setChoice((){if(checked==true){selected.add(id);}else{selected.remove(id);}}));
     })),
    actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Hủy')),
     FilledButton(onPressed:()=>Navigator.pop(ctx,selected.toList()),child:Text('Lưu ${selected.length} điểm'))],
   )));
  if(picked==null||picked.isEmpty||!mounted)return;
  final occupied=<String>{for(final s in stops)if(s['customer_id']!=null)s['customer_id'].toString()};
  for(final op in pendingStops){
   final p=op['payload'] as Map;
   if(p['customer_id']!=null)occupied.add(p['customer_id'].toString());
  }
  final fresh=picked.where((id)=>!occupied.contains(id)).toList();
  if(fresh.isEmpty){notice('Các khách này đã có trong tuyến.');return;}
  var seq=nextOrder;
  if(seq+fresh.length>10000){notice('Tuyến vượt quá 9999 điểm.');return;}
  try{
   for(final cid in fresh){
    await widget.queue.enqueue('/api/v1/day-routes/${widget.routeId}/stops',{
      'client_ref':const Uuid().v4(),'stop_kind':'customer','customer_id':cid,
      'sequence':seq++,'purpose':'Chăm sóc điểm bán',
     },dependsOn:_routeDependencies());
   }
   notice('Đã lưu ${fresh.length} điểm bán trên máy · chờ đồng bộ.');
   if(mounted)await load();
  }catch(e){notice('Không lưu được khách trên tuyến: $e');}
 }
 Future<void> shift(Map<String,dynamic> item,int delta)async{
  final sorted=[...stops]..sort((a,b)=>(a['sequence'] as num).compareTo(b['sequence'] as num));
  final at=sorted.indexWhere((s)=>s['id']==item['id']);
  final otherIndex=at+delta;
  if(at<0||otherIndex<0||otherIndex>=sorted.length||pendingStops.isNotEmpty)return;
  final other=sorted[otherIndex];
  final n1=(item['sequence'] as num).toInt(),n2=(other['sequence'] as num).toInt();
  try{
   await widget.queue.enqueue('/api/v1/day-routes/${widget.routeId}/stops/${item['id']}',{
    'client_ref':const Uuid().v4(),'version':item['version'],
    'stop_kind':item['stop_kind'],'sequence':n2,
    'purpose':item['purpose']??'',
    if(item['stop_kind']=='customer')'customer_id':item['customer_id'],
    if(item['stop_kind']=='area')...{'province':item['province'],'district':item['district']},
    if(item['stop_kind']=='chain')'chain_id':item['chain_id'],
   },method:'PATCH');
   await widget.queue.enqueue('/api/v1/day-routes/${widget.routeId}/stops/${other['id']}',{
    'client_ref':const Uuid().v4(),'version':other['version'],
    'stop_kind':other['stop_kind'],'sequence':n1,
    'purpose':other['purpose']??'',
    if(other['stop_kind']=='customer')'customer_id':other['customer_id'],
    if(other['stop_kind']=='area')...{'province':other['province'],'district':other['district']},
    if(other['stop_kind']=='chain')'chain_id':other['chain_id'],
   },method:'PATCH');
   notice('Đã lưu thứ tự mới · chờ đồng bộ.');
  }catch(e){notice('Không đổi được thứ tự: $e');}
 }
 Future<void> visit(Map<String,dynamic> stop)async{
  if(!canExecute){
   notice('Hãy bắt đầu hoặc tiếp tục phiên hôm nay trước khi check-in.');return;
  }
  if(stop['missed_code']!=null||missedPending(stop['id'].toString())){
   notice('Điểm đã ghi nhận không ghé, không tạo check-in giả.');return;
  }
  if(!isTodayRoute){
   notice('Chỉ check-in tuyến ngày hôm nay. Có thể dời ngày tuyến trước khi bắt đầu.');
   return;
  }
  try{
   final pos=await captureGps(context);
   if(!pos.accuracy.isFinite||pos.accuracy>100||pos.accuracy<0){
    notice('GPS chưa đủ chính xác (yêu cầu ≤100 m).');return;
   }
   final kind=stop['stop_kind'];
   if(kind=='customer'){
    await widget.queue.enqueue('/api/v1/customers/${stop['customer_id']}/visits',{
     'client_ref':const Uuid().v4(),'route_stop_id':stop['id'],
     'latitude':pos.latitude,'longitude':pos.longitude,'accuracy_m':pos.accuracy,
     'captured_at':pos.timestamp.toUtc().toIso8601String(),
    },dependsOn:[..._routeDependencies(),if(pendingStops.any((p)=>(p['payload'] as Map?)?['client_ref']==stop['id']))stop['id'].toString()]);
   }else{
    final note=TextEditingController();
    final prospect=TextEditingController();
    final address=TextEditingController();
    final accepted=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
     title:const Text('Ghi nhận công tác tìm khách'),
     content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
      Text('GPS: ${pos.accuracy.toStringAsFixed(0)} m'),
      TextField(controller:note,maxLength:2000,decoration:const InputDecoration(labelText:'Kết quả công tác')),
      TextField(controller:prospect,maxLength:240,decoration:const InputDecoration(labelText:'Tên điểm bán tìm được (tùy chọn)')),
      TextField(controller:address,maxLength:500,decoration:const InputDecoration(labelText:'Địa chỉ điểm bán (nếu có lead)')),
     ])),
     actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Hủy')),
      FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Ghi nhận GPS'))],
    ));
    final info=note.text.trim(),lead=prospect.text.trim(),where=address.text.trim();
    note.dispose();prospect.dispose();address.dispose();
    if(accepted!=true)return;
    if(lead.isNotEmpty&&(lead.length<2||where.length<3)){
     notice('Lead phải có tên (từ 2 ký tự) và địa chỉ (từ 3 ký tự).');return;
    }
    await widget.queue.enqueue('/api/v1/area-visits',{
     'client_ref':const Uuid().v4(),'day_route_stop_id':stop['id'],
     'latitude':pos.latitude,'longitude':pos.longitude,'accuracy_m':pos.accuracy,
     'captured_at':pos.timestamp.toUtc().toIso8601String(),'note':info,
     if(lead.isNotEmpty)'prospect':{'name':lead,'address_line':where},
    },dependsOn:_routeDependencies());
   }
   notice('Đã ghi nhận GPS trên máy. Check-in chưa phải hoàn thành khảo sát.');
   if(mounted)await load();
  }catch(e){notice('Không ghi được GPS: $e');}
 }

 Future<void> recordMissed(Map<String,dynamic> stop)async{
  if(!canExecute||
    ((stop['visit_count'] as num?)?.toInt()??0)>0||
    ((stop['session_count'] as num?)?.toInt()??0)>0||
    stop['missed_code']!=null||missedPending(stop['id'].toString())||
    activityPending(stop['id'].toString()))return;
  var reason='closed';
  final note=TextEditingController();
  final accepted=await showDialog<bool>(context:context,builder:(dialog)=>StatefulBuilder(
   builder:(dialog,update)=>AlertDialog(
    title:const Text('Lý do không ghé'),
    content:Column(mainAxisSize:MainAxisSize.min,children:[
     DropdownButtonFormField<String>(
      initialValue:reason,isExpanded:true,
      decoration:const InputDecoration(labelText:'Tình trạng'),
      items:const [
       DropdownMenuItem(value:'closed',child:Text('Khách đóng cửa')),
       DropdownMenuItem(value:'unavailable',child:Text('Không gặp được khách')),
       DropdownMenuItem(value:'unable',child:Text('Không đi được')),
       DropdownMenuItem(value:'other',child:Text('Lý do khác')),
      ],onChanged:(v)=>update(()=>reason=v??'closed')),
     TextField(controller:note,maxLength:1000,maxLines:2,
      decoration:InputDecoration(labelText:reason=='other'?'Ghi rõ lý do *':'Ghi chú (tùy chọn)')),
    ]),
    actions:[
     TextButton(onPressed:()=>Navigator.pop(dialog,false),child:const Text('Hủy')),
     FilledButton(onPressed:()=>Navigator.pop(dialog,true),child:const Text('Ghi nhận')),
    ],
   )));
  final detail=note.text.trim();note.dispose();
  if(accepted!=true)return;
  if(reason=='other'&&detail.length<2){notice('Vui lòng ghi rõ lý do.');return;}
  try{
   await widget.queue.enqueue('/api/v1/day-routes/${widget.routeId}/stops/${stop['id']}/missed',{
    'client_ref':const Uuid().v4(),'reason_code':reason,
    'reason_note':detail,'captured_at':DateTime.now().toUtc().toIso8601String(),
   },dependsOn:_routeDependencies());
   notice('Đã lưu lý do, không tính là đã ghé · chờ đồng bộ.');
   if(mounted)await load();
  }catch(e){notice('Không lưu được lý do: $e');}
 }

 /// An unplanned STOP must always represent a real customer. Market discovery
 /// is recorded against the route itself, never as an area/chain stop.
 Future<void> addUnplanned({String? customerId})async{
  if(!canExecute||!scopeSupportsExtra(route!))return;
  final occupied=<String>{
   for(final s in stops)if(s['customer_id']!=null)s['customer_id'].toString(),
   for(final op in pendingStops)if((op['payload'] as Map)['customer_id']!=null)
    (op['payload'] as Map)['customer_id'].toString(),
  };
  final eligible=candidates.where((c)=>!occupied.contains(c['id'].toString())).toList();
  if(eligible.isEmpty){
   notice('Chưa có khách phù hợp để thêm. Dùng Tìm khách mới để ghi nhận lead thực tế.');
   return;
  }
  if(customerId!=null&&!eligible.any((c)=>c['id'].toString()==customerId)){
   notice('Khách không còn trong phạm vi được giao hoặc đã có trên tuyến.');return;
  }
  var query='';
  final selected=customerId??await showDialog<String>(context:context,builder:(dialog)=>StatefulBuilder(
   builder:(dialog,update){
    final visible=eligible.where((c)=>('${c['name']} ${c['code']??''}')
      .toLowerCase().contains(query.toLowerCase())).toList();
    return AlertDialog(
     title:const Text('Chọn khách phát sinh'),
     content:SizedBox(width:420,height:320,child:Column(children:[
      TextField(onChanged:(v)=>update(()=>query=v),
       decoration:const InputDecoration(prefixIcon:Icon(Icons.search),hintText:'Tìm khách trong quyền')),
      Expanded(child:ListView.builder(itemCount:visible.length,itemBuilder:(context,i){
       final c=visible[i];return ListTile(dense:true,
        title:Text(c['name'].toString()),
        subtitle:Text('${c['code']??''} · ${c['district']??''}'),
        onTap:()=>Navigator.pop(dialog,c['id'].toString()));
      })),
     ])),
     actions:[TextButton(onPressed:()=>Navigator.pop(dialog),child:const Text('Hủy'))],
    );
   }));
  if(selected==null||!mounted)return;
  try{
   final addedStopId=const Uuid().v4();
   await widget.queue.enqueue('/api/v1/day-routes/${widget.routeId}/unplanned-stops',{
    'client_ref':addedStopId,'stop_kind':'customer',
    'customer_id':selected,'sequence':nextOrder,'purpose':'Ghé khách phát sinh',
    'captured_at':DateTime.now().toUtc().toIso8601String(),
   },dependsOn:_routeDependencies());
   notice('Khách đã sẵn sàng trên máy · chờ đồng bộ.');
   if(mounted)await load();
   if(mounted&&customerId!=null){
    final entry=candidates.where((c)=>c['id'].toString()==selected).firstOrNull;
    await customerWork({'id':addedStopId,'stop_kind':'customer',
     'customer_id':selected,'customer_name':entry?['name']??'Khách hàng',
     'category':entry?['category'],'customer_district':entry?['district'],
     'customer_province':entry?['province'],'visit_count':0,'session_count':0});
   }
  }catch(e){notice('Không thêm được khách phát sinh: $e');}
 }
 /// For scheduled customer stops, open the existing survey linked by
 /// day_route_stop_id. SurveyPage handles its own GPS first verification.
 Future<void> openCustomerSurvey(Map<String,dynamic> stop)async{
  if(!sessionActive||!isOwner||!isTodayRoute){
   notice('Khảo sát chỉ được bắt đầu/tiếp tục trong phiên đang đi hôm nay.');return;
  }
  if(stop['missed_code']!=null||missedPending(stop['id'].toString())){
   notice('Điểm đã ghi nhận không ghé. Không thể bắt đầu khảo sát.');return;
  }
  final customerId=stop['customer_id']?.toString();
  if(customerId==null||customerId.isEmpty)return;
  if(pendingStops.any((p)=>(p['payload'] as Map)['customer_id']?.toString()==customerId)){
   notice('Điểm ghé chờ đồng bộ. Đồng bộ tuyến trước khi bắt đầu khảo sát.');
   return;
  }
  final regions=await RegionCatalog.load();
  if(!mounted)return;
  await Navigator.push(context,MaterialPageRoute(builder:(_)=>SurveyPage(
   queue:widget.queue,service:widget.service,regions:regions,initialCustomer:customerId,initialStop:{...stop,'route_date':route?['route_date'],'day_route_id':widget.routeId})));
  if(mounted)await load();
 }
 Future<void> openTemplates()async{
  if(route==null)return;
  await Navigator.push(context,MaterialPageRoute(builder:(_)=>RouteTemplatePage(
   queue:widget.queue,service:widget.service,route:route!,stops:stops)));
  if(mounted)await load();
 }
 /// Real market discovery lives at route level. No fake area/chain stop.
 Future<void> recordMarketVisit()async{
  if(!canExecute||!scopeSupportsExtra(route!))return;
  try{
   final pos=await captureGps(context);
   if(!mounted)return;
   if(!pos.accuracy.isFinite||pos.accuracy<0||pos.accuracy>100){
    notice('GPS chưa đủ chính xác (yêu cầu ≤100 m).');return;
   }
   final summary=TextEditingController(),name=TextEditingController(),
    address=TextEditingController();
   final accepted=await showDialog<bool>(context:context,builder:(dialog)=>AlertDialog(
    title:const Text('Ghi nhận tìm khách mới'),
    content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
     Text('Đã đo GPS · sai số ${pos.accuracy.toStringAsFixed(0)} m'),
     TextField(controller:summary,maxLength:2000,maxLines:2,
      decoration:const InputDecoration(labelText:'Kết quả đi thực tế')),
     TextField(controller:name,maxLength:240,
      decoration:const InputDecoration(labelText:'Tên lead tìm được (tùy chọn)')),
     TextField(controller:address,maxLength:500,
      decoration:const InputDecoration(labelText:'Địa chỉ lead (nếu có)')),
    ])),
    actions:[
     TextButton(onPressed:()=>Navigator.pop(dialog,false),child:const Text('Hủy')),
     FilledButton(onPressed:()=>Navigator.pop(dialog,true),
      child:const Text('Lưu GPS công tác')),
    ],
   ));
   final summaryText=summary.text.trim(),leadName=name.text.trim(),
    leadAddress=address.text.trim();
   summary.dispose();name.dispose();address.dispose();
   if(accepted!=true)return;
   if((leadName.isEmpty&&leadAddress.isNotEmpty)||
     (leadName.isNotEmpty&&(leadName.length<2||leadAddress.length<3))){
    notice('Nếu có lead, nhập tên (từ 2 ký tự) và địa chỉ (từ 3 ký tự).');return;
   }
   final ref=const Uuid().v4();
   await widget.queue.enqueue('/api/v1/area-visits',{
    'client_ref':ref,'day_route_id':widget.routeId,
    'latitude':pos.latitude,'longitude':pos.longitude,
    'accuracy_m':pos.accuracy,
    'captured_at':pos.timestamp.toUtc().toIso8601String(),
    'note':summaryText,
    if(leadName.isNotEmpty)'prospect':{
     'name':leadName,'address_line':leadAddress},
   },dependsOn:_routeDependencies());
   notice('GPS và kết quả công tác đã lưu trên máy · chờ đồng bộ.');
   if(mounted)await openMarketEvidence();
  }catch(e){notice('Không lưu được GPS thị trường: $e');}
 }
 Future<void> openMarketEvidence()async{
  if(route==null)return;
  await Navigator.push(context,MaterialPageRoute(builder:(_)=>AreaEvidencePage(
   queue:widget.queue,service:widget.service,route:route!)));
  if(mounted)await load();
 }
 Future<void> openEvidence(Map<String,dynamic> stop)async{
  if(route==null)return;
  await Navigator.push(context,MaterialPageRoute(builder:(_)=>AreaEvidencePage(
   queue:widget.queue,service:widget.service,route:route!,stop:stop)));
  if(mounted)await load();
 }
 /// A session closes only after every earlier local operation is ACKed.
 /// The queue dependency chain preserves GPS, photos, surveys and orders.
 Future<void> endWorkSession()async{
  if(!canExecute)return;
  final noteController=TextEditingController();
  final action=await showDialog<String>(context:context,builder:(dialog)=>AlertDialog(
   title:const Text('Kết thúc phiên công tác'),
   content:Column(mainAxisSize:MainAxisSize.min,children:[
    const Text('Kết thúc lưu lại toàn bộ lịch sử công việc. Không được sửa lại GPS/khảo sát đã xác nhận.'),
    TextField(controller:noteController,maxLength:2000,
     decoration:const InputDecoration(labelText:'Ghi chú kết quả phiên')),
   ]),
   actions:[
    TextButton(onPressed:()=>Navigator.pop(dialog),child:const Text('Tiếp tục đi')),
    TextButton(onPressed:()=>Navigator.pop(dialog,'cancelled'),child:const Text('Hủy phiên')),
    FilledButton(onPressed:()=>Navigator.pop(dialog,'done'),child:const Text('Kết thúc')),
   ],
  ));
  final note=noteController.text.trim();noteController.dispose();
  if(action==null)return;
  if(!mounted)return;
  // Wait for this route's real evidence, never an unrelated old 409.
  // The growing reference set follows survey/photo dependencies transitively.
  final relevant=<String>{widget.routeId,sessionId,
   for(final stop in stops)stop['id'].toString(),
   for(final op in pendingStops)
    if((op['payload'] as Map?)?['client_ref']!=null)
     (op['payload'] as Map)['client_ref'].toString(),
  };
  final pending=widget.queue.pending;
  final captured=<String>{};
  var changed=true;
  while(changed){
   changed=false;
   for(final op in pending){
    final payload=op['payload'] as Map?;
    final ref=payload?['client_ref']?.toString()??'';
    final path=op['path']?.toString()??'';
    final linked=path.startsWith('/api/v1/day-routes/${widget.routeId}')||
      path.startsWith('/api/v1/work-sessions/$sessionId')||
      ref==widget.routeId||ref==sessionId||
      relevant.contains(payload?['day_route_id']?.toString())||
      relevant.contains(payload?['route_stop_id']?.toString())||
      relevant.contains(payload?['day_route_stop_id']?.toString())||
      relevant.contains(op['session_id']?.toString())||
      (op['depends_on'] as List? ?? []).any((v)=>relevant.contains(v.toString()));
    if(linked&&ref.isNotEmpty){
     if(captured.add(ref))changed=true;
     relevant.add(ref);
    }
   }
  }
  final dependencies=captured.toList();
  try{
   await widget.queue.enqueue('/api/v1/work-sessions/$sessionId/close',{
    'client_ref':const Uuid().v4(),
    'version':(route?['work_session_version'] as num?)?.toInt()??1,
    'action':action,'note':note,
    'captured_at':DateTime.now().toUtc().toIso8601String(),
   },dependsOn:dependencies);
   notice('Đã lưu kết thúc phiên trên máy. Máy chủ sẽ đóng sau khi các việc trước đã đồng bộ.');
   if(mounted)Navigator.pop(context,true);
  }catch(e){notice('Không lưu được yêu cầu kết thúc phiên: $e');}
 }
 Future<void> deleteEmptyWorkSession()async{
  final current=route;
  if(current==null||!isOwner||!['done','cancelled'].contains(workState)||
    hasRecordedActivity||widget.queue.pending.isNotEmpty)return;
  final yes=await showDialog<bool>(context:context,builder:(dialog)=>AlertDialog(
   title:const Text('Xóa phiên rỗng?'),
   content:const Text('Chỉ xóa phiên không có GPS, lead, khảo sát, khách phát sinh hay lý do không ghé. Lịch gốc và nhật ký kiểm toán được giữ.'),
   actions:[
    TextButton(onPressed:()=>Navigator.pop(dialog,false),child:const Text('Giữ phiên')),
    FilledButton(onPressed:()=>Navigator.pop(dialog,true),child:const Text('Xóa phiên rỗng')),
   ],
  ));
  if(yes!=true||!mounted)return;
  try{
   decodeApi(await http.delete(widget.service.uri('/api/v1/work-sessions/$sessionId'),
    headers:widget.service.headers,body:jsonEncode({
     'client_ref':const Uuid().v4(),
     'confirm':'DELETE_EMPTY','version':(current['work_session_version'] as num?)?.toInt()??1,
    })).timeout(const Duration(seconds:25)));
   notice('Đã xóa phiên rỗng. Lịch và nhật ký vẫn còn.');
   if(mounted)Navigator.pop(context,true);
  }catch(e){notice('Không thể xóa phiên: $e');}
 }
 Future<void> deleteSchedule()async{
  final current=route;
  if(current==null||current['owner_sub']!=widget.queue.identity||
     current['plan_status']=='cancelled')return;
  final id=current['monthly_plan_id']?.toString()??'';
  final date=current['route_date']?.toString()??'';
  if(id.isEmpty||date.length<7)return;
  try{
   final res=decodeApi(await http.get(
    widget.service.uri('/api/v1/monthly-plans',{'month':date.substring(0,7)}),
    headers:widget.service.headers).timeout(const Duration(seconds:18)));
   final items=(res['items'] as List).whereType<Map>();
   final plan=items.where((p)=>p['id'].toString()==id).firstOrNull;
   if(plan==null){
    notice('Chưa tìm thấy lịch đã đồng bộ. Hãy về Kế hoạch để quản lý bản chờ.');
    return;
   }
   if(!mounted)return;
   final archived=await confirmArchiveWorkSchedule(context,
    service:widget.service,queue:widget.queue,
    plan:Map<String,dynamic>.from(plan));
   if(archived&&mounted)Navigator.pop(context,true);
  }catch(e){notice('Không kiểm tra được lịch để xóa: $e');}
 }
 @override Widget build(BuildContext context){
  final pending=pendingStops;
  final sorted=[...stops]..sort((a,b)=>(a['sequence'] as num).compareTo(b['sequence'] as num));
  final legacyStops=sorted.where((s)=>s['stop_kind']!='customer').toList();
  final localCustomers=<String,Map<String,dynamic>>{
   for(final op in widget.queue.pending)
    if(op['path']=='/api/v1/customers'&&op['payload'] is Map&&
      (op['payload'] as Map)['client_ref']!=null)
     (op['payload'] as Map)['client_ref'].toString():
      Map<String,dynamic>.from(op['payload'] as Map),
  };
  final customerRows=dayRouteCustomerCards(stops,candidates,pending,
   query:candidateQuery,localCustomers:localCustomers);
  final count=sorted.where((s)=>s['stop_kind']=='customer'&&
   ((s['visit_count'] as num?)?.toInt()??0)>0).length;
  return Scaffold(
   appBar:AppBar(title:const Text('Công tác tại khách'),actions:[
    IconButton(tooltip:'Làm mới',onPressed:busy?null:load,icon:const Icon(Icons.sync)),
   ]),
   body:ListView(padding:const EdgeInsets.all(12),children:[
    if(route!=null)...[
     Text('${route!['route_date']?.toString().substring(0,10)} · ${route!['purpose']}',
       style:Theme.of(context).textTheme.titleMedium),
     Text('${route!['scope_kind']=='chain'?'Chuỗi':route!['scope_kind']=='customer'?'Khách cụ thể':'Địa bàn'}: ${route!['scope_key']} · Đã ghé $count/${customerRows.length} khách · GPS thị trường ${route!['market_visit_count']??0}'),
     Text('Phiên: ${switch(workState){'ongoing'=>'Đang đi','done'=>'Đã kết thúc','cancelled'=>'Đã hủy',_=>'Trong lịch'}}',
      style:Theme.of(context).textTheme.bodyMedium),
     const SizedBox(height:8),
     Wrap(spacing:8,runSpacing:6,children:[
      if(scopeSupportsExtra(route!))FilledButton.icon(
       key:const ValueKey('route-create-customer'),
       onPressed:canExecute?createCustomer:null,
       icon:const Icon(Icons.person_add_alt_1_outlined),label:const Text('Thêm khách')),
      if(canExecute)OutlinedButton.icon(
       key:const ValueKey('work-session-finish'),
       onPressed:endWorkSession,
       icon:const Icon(Icons.flag_outlined),label:const Text('Kết thúc sớm')),
      if(isOwner&&['done','cancelled'].contains(workState)&&
        !hasRecordedActivity&&widget.queue.pending.isEmpty)
       TextButton.icon(key:const ValueKey('work-session-delete-empty'),
        onPressed:deleteEmptyWorkSession,
        icon:const Icon(Icons.delete_outline),label:const Text('Xóa công tác rỗng')),
     ]),
    ],
    if(busy)const LinearProgressIndicator(),
    if(offline)const Text('Đang hiển thị dữ liệu offline.'),
    if(error!=null)Text(error!,style:TextStyle(color:Theme.of(context).colorScheme.error)),
    if(route!=null)...[
     const SizedBox(height:10),
     TextField(onChanged:(value)=>setState(()=>candidateQuery=value),
      decoration:const InputDecoration(prefixIcon:Icon(Icons.search),
       hintText:'Tìm tên, mã khách hoặc huyện')),
     const SizedBox(height:10),
     Text('Khách trong phạm vi công tác (${customerRows.length})',
      style:Theme.of(context).textTheme.titleMedium),
     const SizedBox(height:4),
     Text('Danh sách tự lấy theo địa bàn, chuỗi hoặc khách được giao. '
      'Chạm vào khách để ghi nhận, không cần tích chọn trước.',
      style:Theme.of(context).textTheme.bodySmall),
    ],
    for(final c in customerRows.take(100))Card(child:ListTile(
     dense:true,
     key:ValueKey('work-customer:${c['customer_id']}'),
     leading:CustomerCategoryAvatar(category:c['category']?.toString()),
     title:Text(c['customer_name']?.toString()??'Khách hàng',
      maxLines:1,overflow:TextOverflow.ellipsis),
     subtitle:Text(
      '${c['customer_code']??''} · ${c['customer_district']??''}'
      '\n${switch(c['source']){
       'scope'=>'Trong phạm vi · Chưa ghé theo lịch',
       'pending'=>'Đã lưu máy · ${c['sync_status']=='blocked'?'Cần xử lý đồng bộ':'Chờ đồng bộ'}',
       _=>switch(c['activity_status']){
        'visited'=>'Đã ghé',
        'survey_started'=>'Đang ghi thông tin',
        'survey_completed'=>'Đã lưu thông tin',
        'missed'=>'Không ghé · ${missedReasonLabel(c['missed_code'])}',
        _=>'Chưa ghé',
       },
      }}',
      maxLines:2,overflow:TextOverflow.ellipsis),
     trailing:c['sync_status']=='blocked'
      ?IconButton(icon:const Icon(Icons.warning_amber_outlined),
       tooltip:'Xem lỗi đồng bộ',onPressed:()=>notice(
        c['sync_error']?.toString()??'Cần xử lý đồng bộ.'))
      :const Icon(Icons.chevron_right),
     onTap:()=>unawaited(customerWork(c)),
    )),
    if(customerRows.length>100)Padding(padding:const EdgeInsets.all(8),
     child:Text('Hiển thị 100/${customerRows.length} khách. '
      'Dùng ô tìm kiếm để mở khách khác.')),
    if(legacyStops.isNotEmpty)ExpansionTile(
     title:Text('Điểm tìm khách trong dữ liệu cũ (${legacyStops.length})'),
     subtitle:const Text('Chỉ xem lịch sử, không tạo thêm điểm địa bàn trùng'),
     children:[for(final stop in legacyStops)ListTile(
      leading:const Icon(Icons.history),
      title:Text(stop['stop_kind']=='area'?'Địa bàn · ${stop['district']??stop['province']??''}':'Chuỗi'),
      onTap:()=>openEvidence(stop),
     )],
    ),
    if(!busy&&sorted.isEmpty&&pending.isEmpty&&candidates.isEmpty)
     Padding(padding:const EdgeInsets.all(18),
      child:const Text('Chưa có khách trong phạm vi. Chọn Thêm khách để tạo điểm bán thực tế.')),
   ]),
  );
 }
}
