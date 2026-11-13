import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'customers.dart';
import 'models.dart';
import 'offline_queue.dart';
import 'session.dart';
import 'surveys.dart';

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
 bool busy=false,offline=false;
 String? error;
 int previousPending=0;
 String get key=>'day-route:${widget.routeId}';
 String get candidateKey=>'day-route-candidates:${widget.routeId}';
 @override void initState(){
  super.initState();
  route=widget.cachedRoute;
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
 Future<void> load()async{
  if(busy)return;
  setState((){busy=true;error=null;});
  try{
   final cached=await widget.queue.cached(key);
   if(cached.isNotEmpty&&mounted)setState((){
    route=Map<String,dynamic>.from(cached.first['route'] as Map);
    stops=(cached.first['stops'] as List).map((x)=>Map<String,dynamic>.from(x as Map)).toList();
    offline=true;
   });
   final res=decodeApi(await http.get(widget.service.uri('/api/v1/day-routes/${widget.routeId}'),
     headers:widget.service.headers).timeout(const Duration(seconds:20)));
   final item=Map<String,dynamic>.from(res['item'] as Map);
   final list=(res['stops'] as List).map((x)=>Map<String,dynamic>.from(x as Map)).toList();
   await widget.queue.cache(key,[{'route':item,'stops':list}]);
   if(mounted)setState((){route=item;stops=list;offline=false;});
   try{
    final r=decodeApi(await http.get(widget.service.uri('/api/v1/day-routes/${widget.routeId}/candidates'),
      headers:widget.service.headers).timeout(const Duration(seconds:20)));
    candidates=(r['items'] as List).map((x)=>Map<String,dynamic>.from(x as Map)).toList();
    await widget.queue.cache(candidateKey,candidates);
   }catch(e){
    if(e is ApiFailure&&(e.status==401||e.status==403))rethrow;
    candidates=await widget.queue.cached(candidateKey);
   }
  }catch(e){
   if(e is ApiFailure&&(e.status==401||e.status==403)){
    if(mounted)setState((){route=null;stops=[];candidates=[];offline=false;});
   }else{
    candidates=await widget.queue.cached(candidateKey);
   }
   if(mounted)setState(()=>error=e.toString());
  }finally{if(mounted)setState(()=>busy=false);}
 }
 List<Map<String,dynamic>> get pendingStops=>widget.queue.pending.where((op)=>
  (op['path']?.toString()??'').startsWith('/api/v1/day-routes/${widget.routeId}/stops')).toList();
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
 bool get isOwner=route!=null&&route!['owner_sub']==widget.queue.identity;
 bool get canModify=isOwner&&route!['status']=='ready'
   &&route!['plan_status']!='cancelled'&&!busy;
 Future<void> addAreaOrChain()async{
  if(!canModify)return;
  final r=route!;
  final area=r['scope_kind']=='territory';
  final ref=const Uuid().v4();
  final payload=<String,dynamic>{
   'client_ref':ref,'stop_kind':area?'area':'chain','sequence':nextOrder,
   'purpose':area?'Phát triển điểm bán mới':'Chăm sóc chuỗi',
   if(area)...{'province':r['province'],'district':r['district']},
   if(!area)'chain_id':r['scope_key'],
  };
  try{
   await widget.queue.enqueue('/api/v1/day-routes/${widget.routeId}/stops',payload,
     dependsOn:_routeDependencies());
   notice('Đã thêm điểm công tác ${area?'địa bàn':'chuỗi'} (chưa cần khách hàng).');
   if(mounted)await load();
  }catch(e){notice('Không thêm được điểm công tác: $e');}
 }
 List<String> _routeDependencies()=>[
  for(final op in widget.queue.pending)
   if(op['path']=='/api/v1/day-routes'&&(op['payload'] as Map)['client_ref']==widget.routeId)
    widget.routeId
 ];
 Future<void> addCustomers()async{
  if(!canModify)return;
  if(candidates.isEmpty){
   notice('Chưa có khách gợi ý trên tuyến. Anh vẫn có thể thêm điểm công tác địa bàn để tìm khách mới.');
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
  if(!isOwner)return;
  final date=DateTime.tryParse(route?['route_date']?.toString()??'');
  final now=DateTime.now().toUtc().add(const Duration(hours:7));
  if(date==null||date.year!=now.year||date.month!=now.month||date.day!=now.day){
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
    });
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
    });
   }
   notice('Đã ghi nhận GPS trên máy. Check-in chưa phải hoàn thành khảo sát.');
   if(mounted)await load();
  }catch(e){notice('Không ghi được GPS: $e');}
 }
 Future<void> openSurveys()async{
  final regions=await RegionCatalog.load();
  if(!mounted)return;
  await Navigator.push(context,MaterialPageRoute(builder:(_)=>SurveyPage(
   queue:widget.queue,service:widget.service,regions:regions)));
  if(mounted)await load();
 }
 @override Widget build(BuildContext context){
  final pending=pendingStops;
  final sorted=[...stops]..sort((a,b)=>(a['sequence'] as num).compareTo(b['sequence'] as num));
  final count=sorted.where((s)=>(s['visit_count'] as num?)?.toInt()!=null&&
    (s['visit_count'] as num).toInt()>0).length;
  return Scaffold(
   appBar:AppBar(title:const Text('Tuyến ngày'),actions:[
    IconButton(tooltip:'Làm mới',onPressed:busy?null:load,icon:const Icon(Icons.sync)),
   ]),
   body:ListView(padding:const EdgeInsets.all(12),children:[
    if(route!=null)...[
     Text('${route!['route_date']?.toString().substring(0,10)} · ${route!['purpose']}',
       style:Theme.of(context).textTheme.titleMedium),
     Text('${route!['scope_kind']=='chain'?'Chuỗi':'Địa bàn'}: ${route!['scope_key']} · Đã ghé ${count}/${sorted.length} điểm'),
     const SizedBox(height:8),
     Wrap(spacing:8,runSpacing:6,children:[
      OutlinedButton.icon(onPressed:canModify?addAreaOrChain:null,
       icon:const Icon(Icons.place_outlined),label:Text(route!['scope_kind']=='chain'?'Điểm công tác chuỗi':'Điểm tìm khách')),
      OutlinedButton.icon(onPressed:canModify?addCustomers:null,
       icon:const Icon(Icons.group_add_outlined),label:const Text('Chọn nhiều khách')),
      OutlinedButton.icon(onPressed:openSurveys,icon:const Icon(Icons.fact_check_outlined),
       label:const Text('Khảo sát hôm nay')),
     ]),
    ],
    if(busy)const LinearProgressIndicator(),
    if(offline)const Text('Đang hiển thị dữ liệu offline.'),
    if(error!=null)Text(error!,style:TextStyle(color:Theme.of(context).colorScheme.error)),
    for(final p in pending)Card(child:ListTile(
     leading:const Icon(Icons.cloud_upload_outlined),
     title:Text('Điểm ghé · ${(p['payload'] as Map)['stop_kind']}'),
     subtitle:Text(p['error']?.toString()??'Đã lưu máy · chờ đồng bộ'),
     trailing:p['status']=='blocked'?IconButton(tooltip:'Đồng bộ lại',
      icon:const Icon(Icons.refresh),onPressed:()=>widget.queue.retryBlocked(p['key'].toString())):null,
    )),
    for(var i=0;i<sorted.length;i++)
     Card(child:ListTile(
      leading:CircleAvatar(child:Text('${sorted[i]['sequence']}')),
      title:Text(sorted[i]['stop_kind']=='customer'
       ?sorted[i]['customer_name']?.toString()??'Điểm bán'
       :sorted[i]['stop_kind']=='chain'
        ?sorted[i]['chain_name']?.toString()??'Công tác chuỗi'
        :'Tìm khách mới · ${sorted[i]['district']==''?sorted[i]['province']:sorted[i]['district']}'),
      subtitle:Text('${sorted[i]['purpose']??''}\n${switch (sorted[i]['activity_status']) {
       'visited'=>'Đã ghé GPS, chưa kết luận khảo sát',
       'survey_started'=>'Đang khảo sát',
       'survey_completed'=>'Hoàn thành khảo sát',
       _=>'Chưa đi',
      }}'),
      isThreeLine:true,
      trailing:Row(mainAxisSize:MainAxisSize.min,children:[
       if(canModify&&pending.isEmpty)...[
        IconButton(tooltip:'Lên trên',icon:const Icon(Icons.arrow_upward),
         onPressed:i==0?null:()=>shift(sorted[i],-1)),
        IconButton(tooltip:'Xuống dưới',icon:const Icon(Icons.arrow_downward),
         onPressed:i==sorted.length-1?null:()=>shift(sorted[i],1)),
       ],
       if(isOwner)IconButton(tooltip:'Check-in GPS',icon:const Icon(Icons.my_location),
        onPressed:()=>visit(sorted[i])),
      ]),
     )),
    if(!busy&&sorted.isEmpty&&pending.isEmpty)
     const Padding(padding:EdgeInsets.all(18),
      child:Text('Chưa có điểm ghé. Có thể đi tìm khách ở địa bàn trống; không cần tạo khách giả.')),
   ]),
  );
 }
}
