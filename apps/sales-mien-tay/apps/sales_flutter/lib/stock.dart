import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'customers.dart';
import 'offline_queue.dart';
import 'session.dart';
import 'catalog.dart' show specSummary;

const stockCacheKey='stock-snapshot-v1';
Map<String,dynamic> _map(dynamic v)=>Map<String,dynamic>.from(v as Map);
String stockStatus(Map<String,dynamic> r){
 final n=int.tryParse(r['quantity']?.toString()??'');
 return n==null?'Chưa cập nhật':n==0?'Hết tồn':'Có tồn';
}
String stockQuantityLabel(Map<String,dynamic> r)=>r['quantity']==null?'—':r['quantity'].toString();
String stockTime(dynamic v){
 final d=DateTime.tryParse(v?.toString()??'')?.toUtc().add(const Duration(hours:7));
 if(d==null)return 'Chưa cập nhật';
 String two(int n)=>n.toString().padLeft(2,'0');
 return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)} (VN)';
}
bool stockMatches(Map<String,dynamic> r,String query){
 final q=query.trim().toLowerCase();
 return q.isEmpty||['company_code','sku','name','brand','category'].any((k)=>(r[k]?.toString()??'').toLowerCase().contains(q));
}
bool stockIsStale(dynamic v,DateTime now){
 final d=DateTime.tryParse(v?.toString()??'');return d==null||now.toUtc().difference(d.toUtc())>=const Duration(hours:24);
}
class StockPage extends StatefulWidget{
 final OfflineQueue queue;final CustomerService service;
 const StockPage({super.key,required this.queue,required this.service});
 @override State<StockPage> createState()=>_StockPageState();
}
class _StockPageState extends State<StockPage>{
 final search=TextEditingController();
 List<Map<String,dynamic>> rows=[],serverRows=[];
 String? syncedAt,error,serverCursor,serverToken,serverQuery;
 bool busy=false,offline=false,partial=false,denied=false,hasCache=false,searching=false;
 String filter='all';int visibleCount=50;Timer? timer;
 @override void initState(){super.initState();unawaited(refresh());}
 @override void dispose(){timer?.cancel();search.dispose();super.dispose();}
 Future<Map<String,dynamic>> page(String after,String token,{String q='',int limit=500})async=>decodeApi(await http.get(widget.service.uri('/api/v1/inventory/stock',{'after':after,'snapshot':token,'q':q,'limit':'$limit'}),headers:widget.service.headers).timeout(const Duration(seconds:25)));
 void reject(){if(mounted)setState((){denied=true;rows=[];serverRows=[];hasCache=false;error='Không còn quyền truy cập. Vui lòng đăng nhập lại.';});}
 Future<void> refresh()async{
  if(busy||denied)return;
  setState((){busy=true;error=null;serverQuery=null;serverRows=[];serverCursor=null;visibleCount=50;});
  try{
   final cached=await widget.queue.cached(stockCacheKey);
   if(cached.isNotEmpty&&mounted){final c=cached.first;setState((){rows=(c['items'] as List).map(_map).toList();syncedAt=c['synced_at']?.toString();partial=c['partial']==true;hasCache=true;offline=true;});}
   final items=<Map<String,dynamic>>[];String after='',token='',stamp='';bool truncated=false;
   while(true){
    final d=await page(after,token);if(!mounted)return;
    token=d['snapshot'].toString();stamp=d['synced_at'].toString();
    items.addAll((d['items'] as List).map(_map));
    final next=d['next_cursor']?.toString();
    if(next==null)break;
    if(items.length>=10000){truncated=true;break;}
    if(next==after)throw StateError('Phân trang không tiến');
    after=next;
   }
   await widget.queue.cache(stockCacheKey,[{'items':items,'synced_at':stamp,'partial':truncated,'snapshot':token}]);
   if(mounted)setState((){rows=items;syncedAt=stamp;partial=truncated;offline=false;hasCache=true;});
  }catch(e){
   if(e is ApiFailure&&(e.status==401||e.status==403)){reject();}
   else if(mounted)setState((){offline=true;error=hasCache?'Chưa đồng bộ được · đang dùng dữ liệu lưu máy.':'Chưa tải được tồn kho; chưa có bản lưu máy.';});
  }finally{if(mounted)setState(()=>busy=false);}
 }
 Future<void> onlineSearch({bool more=false})async{
  if(searching||busy||denied)return;
  final q=search.text.trim();if(q.isEmpty||q.length>120)return;
  setState(()=>searching=true);
  try{
   final d=await page(more?serverCursor??'':'',more?serverToken??'':'',q:q,limit:100);
   if(!mounted||search.text.trim()!=q)return;
   setState((){serverQuery=q;serverRows=[if(more)...serverRows,...(d['items'] as List).map(_map)];serverCursor=d['next_cursor']?.toString();serverToken=d['snapshot'].toString();visibleCount=50;error=null;});
  }catch(e){if(e is ApiFailure&&(e.status==401||e.status==403)){reject();}else if(mounted)setState(()=>error='Tìm trên server chưa thành công. Thử đồng bộ lại.');}
  finally{if(mounted)setState(()=>searching=false);}
 }
 void changed(String v){setState((){serverQuery=null;serverRows=[];serverCursor=null;visibleCount=50;});timer?.cancel();if(partial&&!offline&&v.trim().isNotEmpty)timer=Timer(const Duration(milliseconds:400),()=>onlineSearch());}
 void detail(Map<String,dynamic> r){
  final spec=_map(r['product_spec']??{});
  final summary=specSummary(spec);
  showDialog<void>(context:context,builder:(c)=>AlertDialog(title:Text(r['name'].toString()),content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
   Text('Mã CTY: ${r['company_code']} · SKU: ${r['sku']??"—"}'),
   Text('Tồn theo file: ${stockQuantityLabel(r)} · ${stockStatus(r)}'),
   Text('Cập nhật tồn: ${stockTime(r['snapshot_at'])}'),
   Text('ĐVT danh mục: ${r['unit']??"Chưa xác minh"}'),
   Text(summary.isEmpty?'Chưa có quy cách':summary),
   if(r['needs_review']==true)const Text('Mã mới, cần Admin xác minh tên và ĐVT.'),
   const Text('Không quy đổi số tồn khi chưa xác minh đơn vị nguồn Excel.'),
  ])),actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('Đóng'))]));
 }
 @override Widget build(BuildContext context){
  if(denied)return Center(child:Text(error!));
  final data=(serverQuery==search.text.trim()?serverRows:rows).where((r)=>stockMatches(r,search.text)&&(filter=='all'||stockStatus(r)==filter)).toList();
  final displayed=data.take(visibleCount).toList();
  return ListView.builder(padding:const EdgeInsets.all(12),itemCount:displayed.length+2,itemBuilder:(c,i){
   if(i==0)return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Row(children:[Expanded(child:Text('Tra tồn kho',style:Theme.of(context).textTheme.titleLarge)),IconButton(tooltip:'Đồng bộ tồn',onPressed:busy?null:refresh,icon:const Icon(Icons.sync))]),
    const Text('Tồn theo Excel · không phải tồn realtime · không hiển thị giá'),
    Text('Bản lưu: ${stockTime(syncedAt)}'),
    if(offline||stockIsStale(syncedAt,DateTime.now()))Text(offline?'Đang dùng bản lưu máy, số tồn có thể đã thay đổi.':'Bản lưu đã cũ hoặc chưa có dữ liệu.',style:TextStyle(color:Theme.of(context).colorScheme.error)),
    if(partial)const Text('Bản lưu giới hạn 10.000 mã. Tìm trên server để tra ngoài bản lưu.'),
    if(error!=null)Text(error!),
    if(busy||searching)const LinearProgressIndicator(),
    const SizedBox(height:8),
    TextField(controller:search,maxLength:120,onChanged:changed,onSubmitted:(_)=>onlineSearch(),decoration:InputDecoration(labelText:'Mã CTY, SKU, tên, nhãn hoặc nhóm hàng',prefixIcon:const Icon(Icons.search),suffixIcon:IconButton(tooltip:'Xóa tìm kiếm',onPressed:(){search.clear();changed('');},icon:const Icon(Icons.clear)))),
    if(partial)TextButton(onPressed:busy||searching||search.text.trim().isEmpty?null:()=>onlineSearch(),child:const Text('Tìm trên server')),
    Wrap(spacing:6,children:[for(final f in ['all','Có tồn','Hết tồn','Chưa cập nhật'])ChoiceChip(label:Text(f=='all'?'Tất cả':f),selected:filter==f,onSelected:(_)=>setState((){filter=f;visibleCount=50;}))]),
    Text('${data.length} mã phù hợp${serverCursor!=null?" · còn trang tiếp":""}'),
    if(data.isEmpty&&!busy)Text(hasCache?'Không có mã phù hợp trong dữ liệu đang xem.':'Chưa có dữ liệu tồn để tra cứu.'),
   ]);
   if(i==displayed.length+1)return Column(children:[if(data.length>visibleCount)OutlinedButton(onPressed:()=>setState(()=>visibleCount+=50),child:const Text('Xem thêm')),if(serverCursor!=null&&serverQuery==search.text.trim())OutlinedButton(onPressed:searching?null:()=>onlineSearch(more:true),child:const Text('Tải thêm kết quả server'))]);
   final r=displayed[i-1],status=stockStatus(r);
   return Card(child:ListTile(title:Text(r['name'].toString()),subtitle:Text('Mã CTY: ${r['company_code']} · SKU: ${r['sku']??"—"}\n${r['brand']??"—"} · ĐVT danh mục: ${r['unit']??"Chưa xác minh"}\n${stockTime(r['snapshot_at'])}${stockIsStale(r['snapshot_at'],DateTime.now())&&r['quantity']!=null?" · Tồn cũ":""}'),trailing:Column(mainAxisAlignment:MainAxisAlignment.center,crossAxisAlignment:CrossAxisAlignment.end,children:[Text(stockQuantityLabel(r),style:Theme.of(context).textTheme.titleLarge),Text(status,style:Theme.of(context).textTheme.bodySmall)]),onTap:()=>detail(r)));
  });
 }
}
