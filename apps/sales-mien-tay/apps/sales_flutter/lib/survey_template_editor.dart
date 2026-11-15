import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'customers.dart';
import 'offline_queue.dart';
import 'surveys.dart';
import 'session.dart';

/// Versioned form editor, isolated from the read-only library/history.
class SurveyTemplateEditorPage extends StatefulWidget {
 final CustomerService service;
 final OfflineQueue? queue;
 final String province,initialTitle;
 final int version;
 final List<Map<String,dynamic>> initialQuestions;
 final List<String> brandOptions,supplierOptions;
 const SurveyTemplateEditorPage({super.key,required this.service,required this.province,
  required this.version,required this.initialTitle,required this.initialQuestions,
  this.queue,this.brandOptions=const [],this.supplierOptions=const []});
 @override State<SurveyTemplateEditorPage> createState()=>_SurveyTemplateEditorPageState();
}
class _SurveyTemplateEditorPageState extends State<SurveyTemplateEditorPage> {
 late TextEditingController title;
 late List<Map<String,dynamic>> questions;
 final Map<String,List<String>> optionKeys={};
 String? openId,error;
 bool saving=false,dirty=false;
 String get draftKey=>'survey-template-draft:'+widget.province;
 List<Map<String,dynamic>> clone(List<Map<String,dynamic>> v)=>asRows(jsonDecode(jsonEncode(v)));
 @override void initState(){
  super.initState();title=TextEditingController(text:widget.initialTitle);
  questions=clone(widget.initialQuestions);
  WidgetsBinding.instance.addPostFrameCallback((_){unawaited(restoreDraft());});
 }
 @override void dispose(){title.dispose();super.dispose();}
 void changed(){dirty=true;error=null;}
 void toast(String s){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(s)));}
 Future<void> restoreDraft()async{
  try{
   final rows=await widget.queue?.cached(draftKey)??[];
   if(!mounted||rows.isEmpty||rows.first['base_version']!=widget.version)return;
   final use=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(
    title:const Text('Bản nháp chưa phát hành'),
    content:const Text('Tiếp tục bản nháp đã lưu trên thiết bị này?'),
    actions:[
     TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Bỏ nháp')),
     FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Tiếp tục')),
    ]));
   if(!mounted)return;
   if(use==true)setState((){
    title.text=rows.first['title']?.toString()??widget.initialTitle;
    questions=asRows(rows.first['questions']);optionKeys.clear();dirty=true;
   });
   if(use==false)await widget.queue?.cache(draftKey,[]);
  }catch(_){}
 }
 Future<void> saveDraft()async{
  if(saving)return;
  try{
   if(widget.queue==null){toast('Không có kho lưu bản nháp.');return;}
   await widget.queue!.cache(draftKey,[{
    'base_version':widget.version,'title':title.text,'questions':questions,
   }]);
   dirty=false;toast('Đã lưu nháp trên thiết bị; chưa phát hành cho Sales.');
  }catch(e){toast('Không lưu được nháp: $e');}
 }
 Future<bool> canLeave()async{
  if(!dirty)return true;
  return await showDialog<bool>(context:context,builder:(c)=>AlertDialog(
   title:const Text('Thoát trình soạn mẫu?'),
   content:const Text('Thay đổi chưa lưu sẽ mất. Có thể lưu nháp để sửa tiếp.'),
   actions:[
    TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Tiếp tục sửa')),
    TextButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Bỏ thay đổi')),
   ]))??false;
 }
 Future<void> leave()async{if(await canLeave()&&mounted)Navigator.pop(context,false);}
 void addQuestion(){
  if(questions.length>=50)return;
  final id='q_'+const Uuid().v4().replaceAll('-','').substring(0,16);
  setState((){
   questions.add({'id':id,'label':'','type':'text','required':false});
   openId=id;changed();
  });
 }
 void addPreset(String id,String name,List<String> options,{bool catalog=false}){
  setState((){
   final q=<String,dynamic>{'id':id,'label':name,'type':'multi_choice',
    'required':false,'options':List<String>.of(options),
    if(catalog)'catalog_source':'brands'};
   final i=questions.indexWhere((e)=>e['id']==id);
   if(i>=0)questions[i]=q;else if(questions.length<50)questions.add(q);
   optionKeys.remove(id);openId=id;changed();
  });
 }
 List<String> idsFor(Map<String,dynamic> q,int n){
  final key=q['id'].toString(),ids=optionKeys.putIfAbsent(key,()=>[]);
  while(ids.length<n){ids.add(const Uuid().v4());}
  if(ids.length>n)ids.removeRange(n,ids.length);
  return ids;
 }
 String kind(String s)=>switch(s){
  'text'=>'Văn bản','number'=>'Số','boolean'=>'Có / Không',
  'choice'=>'Chọn một','multi_choice'=>'Chọn nhiều',_=>'Văn bản'};
 String? validate(){
  final name=title.text.trim();
  if(name.length<2||name.length>80)return 'Tên mẫu phải từ 2 đến 80 ký tự.';
  if(questions.isEmpty)return 'Cần ít nhất một câu hỏi.';
  for(var i=0;i<questions.length;i++){
   final q=questions[i],label=q['label']?.toString().trim()??'';
   if(label.isEmpty||label.length>160)return 'Câu '+(i+1).toString()+': nhập nội dung 1–160 ký tự.';
   if(['choice','multi_choice'].contains(q['type'])){
    final options=(q['options'] as List? ?? []).map((v)=>v.toString().trim()).toList();
    if(options.length<2||options.length>50||
       options.any((v)=>v.isEmpty||v.length>120)||options.toSet().length!=options.length)
     return 'Câu '+(i+1).toString()+': cần ít nhất 2 lựa chọn khác nhau.';
   }
  }
  return null;
 }
 Future<void> publish()async{
  if(saving)return;
  final e=validate();
  if(e!=null){setState(()=>error=e);toast(e);return;}
  final name=title.text.trim(),copy=clone(questions);
  for(final q in copy){
   q['label']=q['label'].toString().trim();
   if(['choice','multi_choice'].contains(q['type']))
    q['options']=(q['options'] as List).map((v)=>v.toString().trim()).toList();
  }
  if(widget.version>0&&name==widget.initialTitle&&
     jsonEncode(copy)==jsonEncode(widget.initialQuestions)){
   toast('Không có thay đổi để phát hành.');return;
  }
  final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(
   title:const Text('Phát hành mẫu?'),
   content:Text('Mẫu "'+name+'" · '+copy.length.toString()+' câu · '+
    (widget.province=='*'?'toàn hệ thống':'tỉnh '+widget.province)+
    '. Phiên khảo sát cũ giữ nguyên mẫu đã dùng.'),
   actions:[
    TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Quay lại')),
    FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Phát hành')),
   ]));
  if(ok!=true||!mounted)return;
  setState((){saving=true;error=null;});
  try{
   final uri=widget.service.uri('/api/v1/survey-templates');
   final body=jsonEncode({'client_ref':const Uuid().v4(),'province':widget.province,
    'title':name,'expected_version':widget.version,'questions':copy});
   final r=await (widget.service.client?.post(uri,headers:widget.service.headers,body:body)
      ??http.post(uri,headers:widget.service.headers,body:body))
      .timeout(const Duration(seconds:20));
   decodeApi(r);
   await widget.queue?.cache(draftKey,[]);
   if(!mounted)return;
   dirty=false;Navigator.pop(context,true);
  }catch(e){
   if(mounted){setState(()=>error='Phát hành thất bại: $e');toast('Lưu thất bại; mẫu cũ vẫn được giữ.');}
  }finally{if(mounted)setState(()=>saving=false);}
 }
 void move(int a,int b){
  if(b<0||b>=questions.length)return;
  setState((){final q=questions.removeAt(a);questions.insert(b,q);changed();});
 }
 Widget questionCard(Map<String,dynamic> q,int i){
  final id=q['id'].toString(),expanded=id==openId;
  final type=q['type']?.toString()??'text',catalog=q['catalog_source']=='brands';
  final options=(q['options'] as List? ?? []).cast<dynamic>();
  final keys=idsFor(q,options.length);
  return Card(key:ValueKey('question:$id'),margin:const EdgeInsets.only(bottom:8),
   child:Column(children:[
    ListTile(
     leading:CircleAvatar(radius:15,child:Text((i+1).toString())),
     title:Text((q['label']?.toString().trim().isEmpty??true)?'Câu '+(i+1).toString()
      :q['label'].toString(),maxLines:2,overflow:TextOverflow.ellipsis),
     subtitle:Text(kind(type)+(q['required']==true?' · Bắt buộc':'')),
     trailing:Icon(expanded?Icons.expand_less:Icons.expand_more),
     onTap:()=>setState(()=>openId=expanded?null:id)),
    if(expanded)Padding(padding:const EdgeInsets.fromLTRB(12,0,12,12),
     child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      TextFormField(key:ValueKey('label:$id'),initialValue:q['label']?.toString()??'',
       maxLength:160,decoration:const InputDecoration(labelText:'Nội dung câu hỏi'),
       onChanged:(v){q['label']=v;changed();}),
      const SizedBox(height:8),
      DropdownButtonFormField<String>(
       key:ValueKey('type:$id'),initialValue:type,isExpanded:true,
       decoration:const InputDecoration(labelText:'Kiểu trả lời'),
       items:const [
        DropdownMenuItem(value:'text',child:Text('Văn bản')),
        DropdownMenuItem(value:'number',child:Text('Số')),
        DropdownMenuItem(value:'boolean',child:Text('Có / Không')),
        DropdownMenuItem(value:'choice',child:Text('Chọn một')),
        DropdownMenuItem(value:'multi_choice',child:Text('Chọn nhiều')),
       ],
       onChanged:catalog?null:(v){if(v==null)return;setState((){
        q['type']=v;
        if(['choice','multi_choice'].contains(v)){
         if((q['options'] as List? ?? []).length<2)q['options']=['',''];
        }else{q.remove('options');optionKeys.remove(id);}
        changed();
       });}),
      if(catalog)const Padding(padding:EdgeInsets.only(top:8),
       child:Text('Nhãn hàng lấy từ danh mục chuẩn.')),
      if(['choice','multi_choice'].contains(type))...[
       const SizedBox(height:12),
       Text('Lựa chọn',style:Theme.of(context).textTheme.titleSmall),
       if(catalog)Text(options.length.toString()+' nhãn hàng chuẩn')
       else ...[
        for(var k=0;k<options.length;k++)Padding(
         padding:const EdgeInsets.only(bottom:8),
         child:Row(children:[
          Expanded(child:TextFormField(
           key:ValueKey('option:'+keys[k]),initialValue:options[k].toString(),
           decoration:InputDecoration(labelText:'Lựa chọn '+(k+1).toString()),
           onChanged:(v){options[k]=v;changed();})),
          IconButton(tooltip:'Xóa lựa chọn',icon:const Icon(Icons.close),
           onPressed:options.length<=2?null:()=>setState((){
            options.removeAt(k);keys.removeAt(k);changed();
           })),
         ])),
        OutlinedButton.icon(onPressed:options.length>=50?null:()=>setState((){
         options.add('');keys.add(const Uuid().v4());changed();
        }),icon:const Icon(Icons.add),label:const Text('Thêm lựa chọn')),
       ]
      ],
      SwitchListTile(contentPadding:EdgeInsets.zero,title:const Text('Bắt buộc trả lời'),
       value:q['required']==true,onChanged:(v)=>setState((){
        q['required']=v;changed();
       })),
      Row(children:[
       IconButton(tooltip:'Chuyển lên',icon:const Icon(Icons.arrow_upward),
        onPressed:i>0?()=>move(i,i-1):null),
       IconButton(tooltip:'Chuyển xuống',icon:const Icon(Icons.arrow_downward),
        onPressed:i<questions.length-1?()=>move(i,i+1):null),
       const Spacer(),
       TextButton.icon(onPressed:()async{
        final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(
         title:const Text('Xóa câu hỏi?'),
         actions:[
          TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Hủy')),
          FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Xóa')),
         ]));
        if(ok==true&&mounted)setState((){
         questions.remove(q);optionKeys.remove(id);
         openId=null;changed();
        });
       },icon:const Icon(Icons.delete_outline),label:const Text('Xóa')),
      ]),
     ])),
   ]));
 }
 void preview(){
  final e=validate();if(e!=null){toast(e);return;}
  showDialog<void>(context:context,builder:(c)=>AlertDialog(
   title:Text(title.text.trim()),
   content:SizedBox(width:420,child:ListView(shrinkWrap:true,children:[
    for(var i=0;i<questions.length;i++)ListTile(
     title:Text((i+1).toString()+'. '+questions[i]['label'].toString()),
     subtitle:Text(kind(questions[i]['type'].toString())+
      (questions[i]['required']==true?' · Bắt buộc':''))),
   ])),
   actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('Đóng'))]));
 }
 @override Widget build(BuildContext context)=>WillPopScope(onWillPop:canLeave,
  child:Scaffold(
   appBar:AppBar(title:Text(widget.version==0?'Tạo mẫu làm việc':'Sửa mẫu làm việc'),
    leading:IconButton(tooltip:'Quay lại',onPressed:leave,
     icon:const Icon(Icons.arrow_back)),
    actions:[IconButton(tooltip:'Xem trước',onPressed:preview,
     icon:const Icon(Icons.visibility_outlined))]),
   body:ListView(padding:const EdgeInsets.all(16),children:[
    Text(widget.province=='*'?'Phạm vi: Toàn hệ thống':'Phạm vi: '+widget.province,
     style:Theme.of(context).textTheme.labelLarge),
    const SizedBox(height:8),
    Text('Soạn phiên bản '+(widget.version+1).toString()+
     '. Bản đang áp dụng không thay đổi cho đến khi phát hành.',
     style:Theme.of(context).textTheme.bodySmall),
    const SizedBox(height:16),
    TextFormField(key:const Key('template-title-field'),controller:title,maxLength:80,
     decoration:const InputDecoration(labelText:'Tên mẫu *',
      hintText:'Ví dụ: Khảo sát điểm bán – tháng 11'),
     onChanged:(_)=>changed()),
    const SizedBox(height:8),
    Row(children:[
     Expanded(child:Text('Câu hỏi ('+questions.length.toString()+'/50)',
      style:Theme.of(context).textTheme.titleMedium)),
     TextButton.icon(onPressed:questions.length>=50?null:addQuestion,
      icon:const Icon(Icons.add),label:const Text('Thêm câu')),
    ]),
    const SizedBox(height:6),
    for(var i=0;i<questions.length;i++)questionCard(questions[i],i),
    Wrap(spacing:8,runSpacing:8,children:[
     OutlinedButton.icon(
      onPressed:questions.length>=50||widget.brandOptions.length<2?null:
       ()=>addPreset('brands','Nhãn hàng thị trường',widget.brandOptions,catalog:true),
      icon:const Icon(Icons.sell_outlined),label:const Text('Từ nhãn hàng')),
     if(widget.province!='*')OutlinedButton.icon(
      onPressed:questions.length>=50||widget.supplierOptions.length<2?null:
       ()=>addPreset('supply_source','Nguồn hàng đang lấy',widget.supplierOptions),
      icon:const Icon(Icons.local_shipping_outlined),label:const Text('Nguồn hàng / NPP')),
    ]),
    if(error!=null)Padding(padding:const EdgeInsets.symmetric(vertical:12),
     child:Text(error!,style:TextStyle(color:Theme.of(context).colorScheme.error))),
    const SizedBox(height:12),
    Text('Lưu nháp chỉ lưu trên thiết bị; Phát hành mới áp dụng cho Sales.',
     style:Theme.of(context).textTheme.bodySmall),
    const SizedBox(height:80),
   ]),
   bottomNavigationBar:SafeArea(top:false,child:Padding(
    padding:const EdgeInsets.fromLTRB(16,8,16,12),
    child:Row(children:[
     Expanded(child:OutlinedButton.icon(key:const Key('template-save-draft-button'),
      onPressed:saving?null:saveDraft,icon:const Icon(Icons.save_outlined),
      label:const Text('Lưu nháp'))),
     const SizedBox(width:10),
     Expanded(child:FilledButton.icon(key:const Key('template-publish-button'),
      onPressed:saving?null:publish,icon:const Icon(Icons.publish_outlined),
      label:const Text('Phát hành'))),
    ]),
   )),
  ));
}

