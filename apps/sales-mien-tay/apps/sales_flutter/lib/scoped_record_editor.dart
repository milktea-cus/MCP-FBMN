import 'dart:async';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'customers.dart';
import 'models.dart';
import 'offline_queue.dart';

/// Independent editor: multi-province scope and real customer IDs, never free-text customer names.
class ScopedRecordEditor extends StatefulWidget {
 final String kind;
 final RegionCatalog regions;
 final CustomerService service;
 final OfflineQueue queue;
 final SalesRecord? initial;
 final VoidCallback onSaved;
 const ScopedRecordEditor({super.key,required this.kind,required this.regions,
   required this.service,required this.queue,required this.onSaved,this.initial});
 @override State<ScopedRecordEditor> createState()=>_ScopedRecordEditorState();
}

class _ScopedRecordEditorState extends State<ScopedRecordEditor>{
 final _form=GlobalKey<FormState>();
 final _fields=<String,TextEditingController>{};
 final _provinces=<String>{};
 final _customerIds=<String>{};
 String? _district;
 bool _saving=false,_loadingCustomers=false,_offlineCustomers=false;
 List<FieldCustomer> _customers=[];
 static const _labels=<String,String>{
  'title':'Vấn đề / cơ hội','requestedHelp':'Hỗ trợ đề nghị',
  'expectedOutcome':'Kết quả mong đợi','priority':'Mức ưu tiên',
  'dueDate':'Hạn cần (YYYY-MM-DD)','status':'Trạng thái',
  'department':'Bộ phận phối hợp','notes':'Ghi chú',
  'program':'Chương trình chính','discount':'Chiết khấu / thưởng',
  'pricing':'Giá / chính sách giá','effectivePeriod':'Thời gian áp dụng',
  'source':'Nguồn thông tin / trạng thái xác minh',
  'recommendation':'Nhận định / đề xuất'
 };
 static const _supportFields=['title','requestedHelp','expectedOutcome','priority','dueDate','status','department','notes'];
 static const _competitorFields=['title','program','discount','pricing','effectivePeriod','source','recommendation'];
 bool get _isCompetitor=>widget.kind=='competitor';
 List<String> get _fieldsForKind=>_isCompetitor?_competitorFields:_supportFields;
 TextEditingController _fieldCtrl(String key)=>_fields.putIfAbsent(key,()=>TextEditingController());
 @override void initState(){
  super.initState();
  final old=widget.initial;
  for(final key in _fieldsForKind){
   _fieldCtrl(key).text=old?.data[key]?.toString()??'';
  }
  final oldProvinces=old?.data['provinces'];
  if(oldProvinces is List){
    _provinces.addAll(oldProvinces.whereType<String>().where(widget.regions.districts.containsKey));
  }else if(old?.province!=null&&widget.regions.districts.containsKey(old!.province)){
    _provinces.add(old.province!);
  }
  _district=old?.district;
  if(_provinces.length!=1)_district=null;
  final oldCustomers=old?.data['customerIds'];
  if(oldCustomers is List)_customerIds.addAll(oldCustomers.map((v)=>v.toString()));
  if(_isCompetitor)unawaited(_loadCustomers());
 }
 @override void dispose(){
  for(final f in _fields.values){f.dispose();}
  super.dispose();
 }
 Future<void> _loadCustomers()async{
  final cached=await widget.queue.cached('scoped-record-customer-options');
  if(mounted&&cached.isNotEmpty)setState((){
   _customers=cached.map(FieldCustomer.fromJson).toList();
   _offlineCustomers=true;
  });
  if(!mounted)return;
  setState(()=>_loadingCustomers=true);
  try{
   final fresh=await widget.service.list();
   if(!mounted)return;
   await widget.queue.cache('scoped-record-customer-options',
       fresh.map((c)=>c.toJson()).toList());
   if(mounted)setState((){
    _customers=fresh;_offlineCustomers=false;
   });
  }catch(_){
   if(mounted)setState(()=>_offlineCustomers=true);
  }finally{
   if(mounted)setState(()=>_loadingCustomers=false);
  }
 }
 Future<void> _toggleProvince(String p,bool enabled,StateSetter modalSet)async{
  if(!enabled){
   final impacted=_customers.where((c)=>c.province==p&&_customerIds.contains(c.id)).toList();
   if(impacted.isNotEmpty){
    final confirmed=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(
     title:const Text('Bỏ tỉnh đang có khách đã chọn?'),
     content:Text('Sẽ bỏ liên kết ${impacted.length} khách thuộc $p khỏi báo cáo.'),
     actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Giữ lại')),
      FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Bỏ tỉnh'))],
    ));
    if(confirmed!=true||!mounted)return;
   }
  }
  if(!mounted)return;
  setState((){
   if(enabled){_provinces.add(p);}
   else{
    _provinces.remove(p);
    _customerIds.removeAll(_customers.where((c)=>c.province==p).map((c)=>c.id));
   }
   if(_provinces.length!=1)_district=null;
  });
  modalSet((){});
 }
 Future<void> _selectProvinces()async{
  await showModalBottomSheet<void>(context:context,isScrollControlled:true,
   showDragHandle:true,builder:(ctx)=>SafeArea(child:StatefulBuilder(builder:(ctx,modalSet)=>
    Padding(padding:EdgeInsets.only(bottom:MediaQuery.viewInsetsOf(ctx).bottom),
    child:ConstrainedBox(constraints:BoxConstraints(maxHeight:MediaQuery.sizeOf(ctx).height*0.75),
    child:Column(mainAxisSize:MainAxisSize.min,children:[
     const ListTile(title:Text('Tỉnh áp dụng'),subtitle:Text('Chọn 1 tỉnh để lọc huyện; chọn nhiều tỉnh sẽ áp dụng toàn tỉnh.')),
     Expanded(child:ListView(children:[
      for(final province in widget.regions.provinces)CheckboxListTile(
       title:Text(province),value:_provinces.contains(province),
       onChanged:(v)=>_toggleProvince(province,v==true,modalSet)),
     ])),
     Padding(padding:const EdgeInsets.all(12),child:FilledButton(
      onPressed:()=>Navigator.pop(ctx),child:Text('Xong · ${_provinces.length} tỉnh'))),
    ]))))));
 }
 Future<void> _selectCustomers()async{
  if(_loadingCustomers&&_customers.isEmpty)return;
  final search=TextEditingController();
  try{
   await showModalBottomSheet<void>(context:context,isScrollControlled:true,
    showDragHandle:true,builder:(ctx)=>SafeArea(child:StatefulBuilder(builder:(ctx,refresh){
     final q=search.text.trim().toLowerCase();
     final visible=_customers.where((c)=>_provinces.contains(c.province)&&
       (_district==null||_district!.isEmpty||c.district==_district)&&
       (q.isEmpty||'${c.name} ${c.fieldCode??''} ${c.province} ${c.district}'
       .toLowerCase().contains(q))).toList();
     return Padding(padding:EdgeInsets.only(bottom:MediaQuery.viewInsetsOf(ctx).bottom),
      child:ConstrainedBox(constraints:BoxConstraints(maxHeight:MediaQuery.sizeOf(ctx).height*0.84),
       child:Column(children:[
        ListTile(title:const Text('Chọn khách hàng'),subtitle:Text('Đã chọn ${_customerIds.length} · ${visible.length} khách phù hợp')),
        Padding(padding:const EdgeInsets.symmetric(horizontal:16),child:TextField(
         controller:search,decoration:const InputDecoration(
           prefixIcon:Icon(Icons.search),labelText:'Tìm tên / mã khách / địa bàn'),
         onChanged:(_)=>refresh((){}))),
        if(_offlineCustomers)const Padding(padding:EdgeInsets.all(8),
         child:Text('Đang dùng danh sách khách lưu máy; quyền sẽ được kiểm tra khi đồng bộ.')),
        if(_loadingCustomers)const LinearProgressIndicator(minHeight:2),
        Expanded(child:visible.isEmpty?const Center(child:Text('Chưa có khách trong địa bàn hoặc chưa tải dữ liệu.')):
         ListView.builder(itemCount:visible.length,itemBuilder:(ctx,i){
          final c=visible[i];
          return CheckboxListTile(key:ValueKey('customer:${c.id}'),
           value:_customerIds.contains(c.id),title:Text(c.name),
           subtitle:Text('${c.fieldCode??''} · ${c.district}, ${c.province}'),
           onChanged:(value){
             setState((){
              if(value==true){_customerIds.add(c.id);}
              else{_customerIds.remove(c.id);}
             });
             refresh((){});
           });
         })),
        Padding(padding:const EdgeInsets.all(12),child:FilledButton(
         onPressed:()=>Navigator.pop(ctx),child:Text('Xong · ${_customerIds.length} khách'))),
       ])));
    }))));
  }finally{search.dispose();}
 }
 Widget _regionFields()=>Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
  const SizedBox(height:10),
  Text('Địa bàn áp dụng',style:Theme.of(context).textTheme.titleMedium),
  const SizedBox(height:8),
  OutlinedButton.icon(onPressed:_saving?null:_selectProvinces,icon:const Icon(Icons.map_outlined),
    label:Text(_provinces.isEmpty?'Chọn tỉnh':
      '${_provinces.length} tỉnh: ${(_provinces.toList()..sort()).join(', ')}',
      overflow:TextOverflow.ellipsis)),
  const SizedBox(height:10),
  if(_provinces.length==1)
   DropdownButtonFormField<String>(
    key:ValueKey('district:${_provinces.single}'),
    isExpanded:true,initialValue:(_district!=null&&widget.regions.districts[_provinces.single]!.contains(_district))
     ?_district:null,
    decoration:const InputDecoration(labelText:'Huyện (để trống = toàn tỉnh)'),
    items:[const DropdownMenuItem<String>(value:'',child:Text('Toàn tỉnh')),
      for(final d in widget.regions.districts[_provinces.single]!)
       DropdownMenuItem(value:d,child:Text(d,overflow:TextOverflow.ellipsis))],
    onChanged:_saving?null:(v)=>setState((){
     _district=(v==null||v.isEmpty)?null:v;
     if(_isCompetitor){
      _customerIds.removeWhere((id)=>_customers.any((c)=>c.id==id&&
        c.province==_provinces.single&&_district!=null&&c.district!=_district));
     }
    }))
  else if(_provinces.length>1)
   const Text('Đã chọn nhiều tỉnh: không chọn huyện, áp dụng toàn bộ các tỉnh được chọn.')
  else const Text('Chọn ít nhất một tỉnh để tiếp tục.'),
  const SizedBox(height:10),
  if(_isCompetitor)...[
   OutlinedButton.icon(onPressed:_saving||_provinces.isEmpty?null:_selectCustomers,
    icon:const Icon(Icons.storefront_outlined),
    label:Text('Chọn khách hàng (${_customerIds.length} đã chọn)')),
   if(_customerIds.isNotEmpty)Padding(padding:const EdgeInsets.all(8),
    child:Text('${_customerIds.length} khách liên kết · Không bắt buộc chọn khách',
      style:Theme.of(context).textTheme.bodySmall)),
   const SizedBox(height:8),
  ],
 ]);
 Widget _textField(String key)=>Padding(padding:const EdgeInsets.only(bottom:12),
  child:TextFormField(controller:_fieldCtrl(key),enabled:!_saving,
   maxLines:['requestedHelp','notes','program','recommendation'].contains(key)?3:1,
   decoration:InputDecoration(labelText:key=='title'&&_isCompetitor?'Tên nhãn hàng / đối thủ':_labels[key]),
   validator:key=='title'?(v)=>v==null||v.trim().isEmpty?'Vui lòng nhập tiêu đề':null:null));
 Future<void> _save()async{
  if(!_form.currentState!.validate())return;
  if(_provinces.isEmpty){
   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Vui lòng chọn ít nhất một tỉnh.')));return;
  }
  if(_provinces.length>1&&_district!=null){
   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Nhiều tỉnh không được chọn huyện.')));return;
  }
  final byId={for(final c in _customers)c.id:c};
  if(_isCompetitor&&_customerIds.any((id)=>byId.containsKey(id)&&
    (!_provinces.contains(byId[id]!.province)||
     (_district!=null&&byId[id]!.district!=_district)))){
   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Khách đã chọn không thuộc địa bàn.')));return;
  }
  final provinces=_provinces.toList()..sort();
  final ids=_customerIds.toList()..sort();
  final record=<String,dynamic>{
   'kind':widget.kind,'provinces':provinces,'district':_district??'',
   'customer_ids':_isCompetitor?ids:<String>[],
   'version':widget.initial?.version??0,'client_ref':const Uuid().v4(),
   'data':{for(final key in _fieldsForKind) key:_fieldCtrl(key).text.trim()}
  };
  setState(()=>_saving=true);
  try{
   final target=widget.initial==null?'/api/v1/scoped-records':
      '/api/v1/scoped-records/${widget.initial!.id}';
   await widget.queue.enqueue(target,record,method:widget.initial==null?'POST':'PATCH');
   widget.onSaved();
   if(mounted)Navigator.pop(context,true);
  }catch(error){
   if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Không lưu được: $error')));
  }finally{
   if(mounted)setState(()=>_saving=false);
  }
 }
 @override Widget build(BuildContext context)=>Scaffold(
  appBar:AppBar(title:Text(widget.kind=='support'?'Đề xuất hỗ trợ':'Thông tin đối thủ')),
  body:Center(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:720),
   child:Form(key:_form,child:ListView(padding:const EdgeInsets.all(16),children:[
    Text(widget.initial==null?'Tạo bản ghi mới':'Chỉnh sửa bản ghi',
     style:Theme.of(context).textTheme.titleLarge),
    const SizedBox(height:12),
    _textField('title'),_regionFields(),
    for(final key in _fieldsForKind.where((key)=>key!='title'))_textField(key),
    const SizedBox(height:12),
    FilledButton.icon(onPressed:_saving?null:_save,
     icon:_saving?const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2)):
       const Icon(Icons.save_outlined),
     label:const Text('Lưu trên máy · Đồng bộ khi có mạng')),
    const SizedBox(height:24),
   ])))),
 );
}
