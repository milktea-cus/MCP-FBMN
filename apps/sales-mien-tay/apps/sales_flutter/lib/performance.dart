import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'actuals.dart';
import 'field_work.dart';
import 'customers.dart';
import 'offline_queue.dart';
import 'models.dart';
import 'report_xlsx.dart';
import 'session.dart';
import 'responsive_controls.dart';

int _amount(Object? v)=>int.tryParse('$v')??0;
String _money(Object? v)=>saleMoney(v);
String _pct(Object? value)=>value==null?'—': '${value.toString()}%';
String _label(String kind)=>switch(kind){
 'employee'=>'Nhân viên','customer'=>'Khách hàng','product'=>'Sản phẩm / SKU',
 'province'=>'Tỉnh','month'=>'Tháng',_=>'Nhóm',
};
List<Map<String,dynamic>> _rows(Object? value)=>(value as List? ?? []).map((r)=>Map<String,dynamic>.from(r as Map)).toList();

class PerformancePage extends StatefulWidget {
 final OfflineQueue queue;
 final RegionCatalog regions;
 final CustomerService service;
 final ActualClient? client;
 const PerformancePage({super.key,required this.queue,required this.regions,required this.service,this.client});
 @override State<PerformancePage> createState()=>_PerformancePageState();
}
class _PerformancePageState extends State<PerformancePage> {
 late final ActualClient client=widget.client??ActualClient(widget.queue);
 int year=DateTime.now().year,month=DateTime.now().month,quarter=(DateTime.now().month-1)~/3+1,generation=0;
 String period='month',group='employee',owner='',province='',customer='',product='';
 String provinceName='',customerName='',productName='';
 List<Map<String,dynamic>> staff=[],rows=[];
 Map<String,dynamic>? report;
 bool canViewTeam=false,busy=true,cached=false,exporting=false;
 String? error;
 Map<String,String> get filters=>{
  'year':'$year','period':period,'month':'$month','quarter':'$quarter',
  'group':group,'owner':owner,'province':province,'customer':customer,'product':product,
 };
 String get endpoint=>Uri(path:'/api/v1/reports/performance',queryParameters:filters).toString();
 String get cacheKey=>'report-performance-v1:${Uri(queryParameters:filters).query}';
 @override void initState(){super.initState();owner=widget.queue.identity;loadStaff();load();}
 Future<void> loadStaff()async{
  try{
   final r=await client.get('/api/v1/reports/performance/options?kind=employee');
   if(mounted)setState((){
    staff=_rows(r['items']);canViewTeam=r['can_view_team']==true;
    if(owner!='all'&&!staff.any((s)=>s['id']==owner))owner=widget.queue.identity;
   });
  }catch(_){}
 }
 Future<void> load()async{
  final g=++generation,key=cacheKey,path=endpoint;
  setState((){busy=true;error=null;cached=false;report=null;rows=[];});
  Map<String,dynamic>? data;String? failure;bool isCached=false;
  try{data=await client.get(path);try{await widget.queue.cache(key,[data]);}catch(_){}}
  catch(e){
   failure=e.toString();
   if(e is! ApiFailure||e.status>=500){try{data=(await widget.queue.cached(key)).firstOrNull;isCached=data!=null;}catch(_){}}
  }
  if(!mounted||g!=generation)return;
  setState((){busy=false;cached=isCached;error=data==null?failure:null;report=data;rows=_rows(data?['rows']);});
 }
 void changed(){load();}
 Future<void> select(String kind)async{
  final chosen=await showDialog<Map<String,dynamic>>(context:context,builder:(_)=>_ReportChoice(
    client:client,kind:kind,owner:owner));
  if(chosen==null||!mounted)return;
  setState((){
   if(kind=='province'){province=chosen['id'].toString();provinceName=chosen['name'].toString();customer='';customerName='';}
   if(kind=='customer'){customer=chosen['id'].toString();customerName=chosen['name'].toString();}
   if(kind=='product'){product=chosen['id'].toString();productName='${chosen['code']??''} · ${chosen['name']}';}
  });
  changed();
 }
 void reset(String kind){
  setState((){
   if(kind=='province'){province='';provinceName='';customer='';customerName='';}
   if(kind=='customer'){customer='';customerName='';}
   if(kind=='product'){product='';productName='';}
  });
  changed();
 }
 Future<void> exportXlsx()async{
  if(busy||cached||report==null||exporting)return;
  setState(()=>exporting=true);
  try{
   final data=await client.get(Uri(path:'/api/v1/reports/performance/export',queryParameters:filters).toString());
   if(data['exact']!=true)throw StateError('Server chưa xác nhận danh sách đầy đủ');
   if(!mounted)return;
   final bytes=buildPerformanceXlsx(report!,_rows(data['items']));
   final filename='filed-work-report-$year-${period=='month'?month:period=='quarter'?'Q$quarter':'full'}-${group}.xlsx';
   await FilePicker.platform.saveFile(dialogTitle:'Lưu báo cáo Excel',fileName:filename,
    type:FileType.custom,allowedExtensions:['xlsx'],bytes:bytes);
  }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Chưa xuất được báo cáo: $e')));}
  finally{if(mounted)setState(()=>exporting=false);}
 }
 Future<void> drill(Map<String,dynamic> row)async{
  if(cached)return;
  await Navigator.push(context,MaterialPageRoute(builder:(_)=>_ReportDetails(
   client:client,filters:filters,keyValue:row['id'].toString(),title:row['label'].toString())));
 }
 Widget metric(String title,String value,IconData icon){
  return Card(child:Padding(padding:const EdgeInsets.all(12),child:Column(
   crossAxisAlignment:CrossAxisAlignment.start,children:[Icon(icon,size:20),
   Text(title,style:Theme.of(context).textTheme.labelMedium),
   const SizedBox(height:4),
   Tooltip(message:value,child:FittedBox(fit:BoxFit.scaleDown,alignment:Alignment.centerLeft,
    child:Text(value,maxLines:1,softWrap:false,style:Theme.of(context).textTheme.titleMedium)))])));
 }
 Widget filterButton(String title,String value,String kind){
  return Row(children:[Expanded(child:OutlinedButton(onPressed:busy?null:()=>select(kind),
   child:Text('$title: ${value.isEmpty?'Tất cả':value}',maxLines:1,overflow:TextOverflow.ellipsis))),
   if(value.isNotEmpty)IconButton(tooltip:'Bỏ lọc $title',onPressed:busy?null:()=>reset(kind),icon:const Icon(Icons.close))]);
 }
 @override Widget build(BuildContext context){
  final data=report,metricData=Map<String,dynamic>.from(data?['metric'] as Map? ?? {});
  final hasReport=data!=null,hasActual=_amount(metricData['records'])>0;
  return ListView(padding:const EdgeInsets.all(12),children:[
   Row(children:[Expanded(child:Text('Báo cáo kinh doanh',style:Theme.of(context).textTheme.titleLarge)),
    IconButton(onPressed:busy?null:load,tooltip:'Làm mới báo cáo',icon:const Icon(Icons.refresh))]),
   if(staff.isNotEmpty)DropdownButtonFormField<String>(key:ValueKey('owner:$owner'),initialValue:owner,
    decoration:const InputDecoration(labelText:'Nhân viên / đội Sales'),isExpanded:true,
    items:[if(canViewTeam)const DropdownMenuItem(value:'all',child:Text('Tất cả trong quyền quản lý')),
     for(final s in staff)DropdownMenuItem(value:s['id'].toString(),
       child:Text('${s['code']} · ${s['name']}',overflow:TextOverflow.ellipsis))],
    onChanged:busy?null:(value){if(value!=null){setState((){owner=value;province='';customer='';provinceName='';customerName='';});changed();}}),
   const SizedBox(height:8),
   AdaptiveFilterRow(children:[
      DropdownButtonFormField<int>(key:ValueKey('year:$year'),initialValue:year,isExpanded:true,
        decoration:const InputDecoration(labelText:'Năm'),
        items:[for(var y=year-3;y<=year+3;y++)if(y>=2000&&y<=2100)
          DropdownMenuItem(value:y,child:Text('$y'))],
        onChanged:busy?null:(v){if(v!=null){setState(()=>year=v);changed();}}),
      DropdownButtonFormField<String>(initialValue:period,isExpanded:true,
        decoration:const InputDecoration(labelText:'Kỳ'),
        items:const [DropdownMenuItem(value:'month',child:Text('Tháng')),
          DropdownMenuItem(value:'quarter',child:Text('Quý')),
          DropdownMenuItem(value:'year',child:Text('Năm'))],
        onChanged:busy?null:(v){if(v!=null){setState(()=>period=v);changed();}}),
    ]),
    if(period!='year')...[
    const SizedBox(height:8),
    DropdownButtonFormField<int>(key:ValueKey('period:$period'),initialValue:period=='month'?month:quarter,
     decoration:InputDecoration(labelText:period=='month'?'Tháng':'Quý'),
     items:[for(var i=1;i<= (period=='month'?12:4);i++)DropdownMenuItem(value:i,child:Text('${period=='month'?'Tháng':'Quý'} $i'))],
     onChanged:busy?null:(v){if(v!=null){setState((){if(period=='month')month=v;else quarter=v;});changed();}}),
   ],
   const SizedBox(height:8),
   DropdownButtonFormField<String>(initialValue:group,isExpanded:true,decoration:const InputDecoration(labelText:'Nhóm báo cáo'),
    items:[for(final k in const ['employee','province','customer','product','month'])DropdownMenuItem(value:k,child:Text('Theo ${_label(k).toLowerCase()}'))],
    onChanged:busy?null:(v){if(v!=null){setState(()=>group=v);changed();}}),
   const SizedBox(height:8),
   AdaptiveFilterRow(children:[
     filterButton('Tỉnh',provinceName,'province'),
     filterButton('Khách',customerName,'customer'),
     filterButton('Mã CTY',productName,'product'),
    ]),
    if(busy)const LinearProgressIndicator(),
   if(cached)const Text('Đang xem báo cáo lưu trên máy (offline). Không được xuất hoặc xem chi tiết khi chưa xác minh dữ liệu mới.'),
   if(error!=null)Text(error!,style:TextStyle(color:Theme.of(context).colorScheme.error)),
   if(hasReport)...[
    LayoutBuilder(builder:(ctx,size){
     final columns=size.maxWidth>=1040?4:size.maxWidth>=300?2:1;
     final cells=[
      metric('Target',metricData['target']==null?'Không áp dụng':_money(metricData['target']),Icons.flag_outlined),
      metric('Doanh số',hasActual?_money(metricData['actual']):'Chưa có dữ liệu',Icons.payments_outlined),
      metric('Hoàn thành',hasActual?_pct(metricData['progress_percent']):'—',Icons.trending_up_outlined),
      metric('Còn thiếu',hasActual&&metricData['remaining']!=null?_money(metricData['remaining']):'—',Icons.account_balance_wallet_outlined),
     ];
     return GridView.count(primary:false,shrinkWrap:true,
      physics:const NeverScrollableScrollPhysics(),crossAxisCount:columns,
      crossAxisSpacing:8,mainAxisSpacing:8,mainAxisExtent:120,children:cells);
    }),
    const SizedBox(height:8),
    Text(data['target_note']?.toString()??'',style:Theme.of(context).textTheme.bodySmall),
    Text('Dựa trên ${metricData['records']??0} dòng doanh số đã ghi (không tính nháp/hủy).',
      style:Theme.of(context).textTheme.bodySmall),
    const SizedBox(height:8),
    Wrap(spacing:8,runSpacing:8,children:[
     FilledButton.icon(onPressed:busy||cached||exporting?null:exportXlsx,
      icon:const Icon(Icons.file_download_outlined),label:Text(exporting?'Đang xuất…':'Xuất')),
     OutlinedButton.icon(onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>
      FieldWorkPage(queue:widget.queue,regions:widget.regions,service:widget.service,report:true))),
      icon:const Icon(Icons.table_chart_outlined),label:const Text('Hiện diện')),
    ]),
    const SizedBox(height:8),
    Text('Chi tiết theo ${_label(group).toLowerCase()}',style:Theme.of(context).textTheme.titleMedium),
    if(rows.isEmpty)const Padding(padding:EdgeInsets.all(16),child:Text('Chưa có Target hoặc doanh số thực tế thuộc bộ lọc này.')),
    for(final r in rows)Card(child:ListTile(
     title:Text('${r['code']==null||r['code'].toString().isEmpty?'':'${r['code']} · '}${r['label']}',maxLines:2,overflow:TextOverflow.ellipsis),
     subtitle:Text('Thực tế: ${_money(r['actual'])} · ${r['records']} dòng\n'
      'Target: ${r['target']==null?'Không áp dụng':_money(r['target'])} · Tiến độ: ${_pct(r['progress_percent'])}'),
     isThreeLine:false,
     trailing:cached?null:const Icon(Icons.chevron_right),
     onTap:cached?null:()=>drill(r))),
    const Padding(padding:EdgeInsets.all(8),child:Text('Bấm một nhóm để xem các chứng từ; Excel gồm tổng quan, chi tiết nhóm và toàn bộ chứng từ thuộc bộ lọc (tối đa 10.000 dòng).')),
   ],
  ]);
 }
}
class _ReportChoice extends StatefulWidget{
 final ActualClient client;final String kind,owner;
 const _ReportChoice({required this.client,required this.kind,required this.owner});
 @override State<_ReportChoice> createState()=>_ReportChoiceState();
}
class _ReportChoiceState extends State<_ReportChoice>{
 final query=TextEditingController();List<Map<String,dynamic>> items=[];bool busy=true;String? error;int gen=0;
 @override void initState(){super.initState();load();}
 @override void dispose(){query.dispose();super.dispose();}
 Future<void> load()async{
  final g=++gen;setState((){busy=true;error=null;});
  try{
   final data=await widget.client.get(Uri(path:'/api/v1/reports/performance/options',
    queryParameters:{'kind':widget.kind,'owner':widget.owner,'q':query.text.trim()}).toString());
   if(mounted&&g==gen)setState(()=>items=_rows(data['items']));
  }catch(e){if(mounted&&g==gen)setState(()=>error='$e');}
  finally{if(mounted&&g==gen)setState(()=>busy=false);}
 }
 @override Widget build(BuildContext context)=>AlertDialog(
  title:Text('Chọn ${_label(widget.kind).toLowerCase()}'),
  content:SizedBox(width:460,height:400,child:Column(children:[
   TextField(controller:query,decoration:InputDecoration(labelText:'Tìm mã hoặc tên',
    suffixIcon:IconButton(icon:const Icon(Icons.search),onPressed:load)),onSubmitted:(_)=>load()),
   if(busy)const LinearProgressIndicator(),if(error!=null)Text(error!),
   Expanded(child:ListView(children:[for(final r in items)ListTile(
    title:Text(r['name'].toString()),subtitle:Text(r['code']?.toString()??''),
    onTap:()=>Navigator.pop(context,r)),
    if(!busy&&items.isEmpty)const Text('Không có dữ liệu trong phạm vi quyền')]))
  ])),actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('Đóng'))]);
}
class _ReportDetails extends StatefulWidget{
 final ActualClient client;final Map<String,String> filters;final String keyValue,title;
 const _ReportDetails({required this.client,required this.filters,required this.keyValue,required this.title});
 @override State<_ReportDetails> createState()=>_ReportDetailsState();
}
class _ReportDetailsState extends State<_ReportDetails>{
 final rows=<Map<String,dynamic>>[];bool busy=false,more=true;String? error;int offset=0;
 @override void initState(){super.initState();load();}
 Future<void> load()async{
  if(busy||!more)return;setState((){busy=true;error=null;});
  try{
   final d=await widget.client.get(Uri(path:'/api/v1/reports/performance/detail',
    queryParameters:{...widget.filters,'key':widget.keyValue,'offset':'$offset'}).toString());
   if(mounted)setState((){final next=_rows(d['items']);rows.addAll(next);offset+=next.length;more=d['has_more']==true;});
  }catch(e){if(mounted)setState(()=>error='$e');}
  finally{if(mounted)setState(()=>busy=false);}
 }
 @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:Text(widget.title)),
  body:ListView(padding:const EdgeInsets.all(12),children:[
   const Text('Chỉ gồm doanh số đã ghi, chưa hủy; bấm Xem thêm để tải các dòng tiếp theo.'),
   for(final r in rows)Card(child:ListTile(title:Text('${r['company_code']} · ${r['product_name']}'),
    subtitle:Text('${r['sale_date']} · ${r['employee_code']} · ${r['customer_name']}\n'
     'SL ${r['quantity']} · ${_money(r['amount'])} · ${r['external_ref']??'Nhập tay'}'),
    isThreeLine:true)),
   if(error!=null)Text(error!,style:TextStyle(color:Theme.of(context).colorScheme.error)),
   if(busy)const LinearProgressIndicator(),
   if(more)TextButton(onPressed:busy?null:load,child:const Text('Xem thêm')),
   if(!busy&&!more&&rows.isEmpty)const Text('Chưa có chứng từ của nhóm này.'),
  ]));
}
