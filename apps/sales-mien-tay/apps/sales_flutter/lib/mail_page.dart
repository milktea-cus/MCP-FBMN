import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'session.dart';

/// This page intentionally never stores mail in the offline business queue.
class StaffMailPage extends StatefulWidget {
 final SalesSession session;
 const StaffMailPage({super.key,required this.session});
 @override State<StaffMailPage> createState()=>_StaffMailPageState();
}

class _StaffMailPageState extends State<StaffMailPage>{
 bool busy=true;
 String? error,mailbox,selectedFolder,selectedThread;
 List<Map<String,dynamic>> threads=[],messages=[];
 Map<String,dynamic>? selectedMail;
 @override void initState(){super.initState();load();}
 Future<void> load({String folder='inbox'})async{
  if(!mounted)return;
  setState((){busy=true;error=null;selectedFolder=folder;});
  try{
   final me=await widget.session.get('/api/v1/mail/me');
   final result=await widget.session.get('/api/v1/mail/threads?folder=$folder');
   if(mounted)setState((){
    mailbox=me['mailbox']?.toString();
    threads=(result['items'] as List? ?? []).whereType<Map>()
      .map((v)=>Map<String,dynamic>.from(v)).toList();
   });
  }catch(e){if(mounted)setState(()=>error=e.toString());}
  finally{if(mounted)setState(()=>busy=false);}
 }
 Future<void> openThread(String id)async{
  setState((){busy=true;error=null;selectedThread=id;messages=[];selectedMail=null;});
  try{
   final result=await widget.session.get('/api/v1/mail/threads/$id');
   if(mounted)setState(()=>messages=(result['emails'] as List? ?? [])
      .whereType<Map>().map((v)=>Map<String,dynamic>.from(v)).toList());
  }catch(e){if(mounted)setState(()=>error=e.toString());}
  finally{if(mounted)setState(()=>busy=false);}
 }
 Future<void> openMessage(String id)async{
  if(selectedThread==null)return;
  setState(()=>busy=true);
  try{
   final result=await widget.session.get('/api/v1/mail/threads/$selectedThread/emails/$id');
   if(mounted)setState(()=>selectedMail=Map<String,dynamic>.from(result['item'] as Map));
  }catch(e){if(mounted)setState(()=>error=e.toString());}
  finally{if(mounted)setState(()=>busy=false);}
 }
 Future<void> compose()async{
  final sent=await showDialog<bool>(context:context,builder:(context)=>
   _MailComposer(session:widget.session,mailbox:mailbox??''));
  if(sent==true&&mounted)await load(folder:'sent');
 }
 @override Widget build(BuildContext context){
  final theme=Theme.of(context);
  return Scaffold(appBar:AppBar(title:const Text('Email'),
   actions:[IconButton(tooltip:'Làm mới',onPressed:busy?null:()=>
       load(folder:selectedFolder??'inbox'),icon:const Icon(Icons.refresh))]),
   body:Column(children:[
    if(mailbox!=null)Padding(padding:const EdgeInsets.fromLTRB(16,12,16,4),
     child:Row(children:[const Icon(Icons.lock_outline,size:16),
      const SizedBox(width:8),Expanded(child:Text('Hộp thư của tôi: $mailbox',
       style:theme.textTheme.bodyMedium))])),
    Padding(padding:const EdgeInsets.symmetric(horizontal:12,vertical:8),
     child:Row(children:[
      Expanded(child:OutlinedButton.icon(onPressed:busy?null:()=>load(),
       icon:const Icon(Icons.inbox_outlined),label:const Text('Thư đến'))),
      const SizedBox(width:8),
      Expanded(child:OutlinedButton.icon(onPressed:busy?null:()=>load(folder:'sent'),
       icon:const Icon(Icons.outbox_outlined),label:const Text('Đã gửi'))),
      const SizedBox(width:8),
      IconButton.filledTonal(onPressed:busy||mailbox==null?null:compose,
       tooltip:'Soạn email',icon:const Icon(Icons.edit_outlined)),
     ])),
    if(error!=null)Padding(padding:const EdgeInsets.all(12),
       child:SelectableText(error!,style:TextStyle(color:theme.colorScheme.error))),
    if(busy)const LinearProgressIndicator(),
    Expanded(child:selectedMail!=null?
      ListView(padding:const EdgeInsets.all(16),children:[
       Text(selectedMail?['subject']?.toString()??'',style:theme.textTheme.titleLarge),
       const SizedBox(height:12),
       Text('Từ: ${selectedMail?['from']??''}'),
       Text('Đến: ${selectedMail?['to']??''}'),
       const Divider(height:30),
       SelectableText(selectedMail?['text']?.toString()??'(Email không có bản văn bản thuần)'),
      ]):
      selectedThread!=null?
       ListView(children:[
        ListTile(leading:const Icon(Icons.arrow_back),title:const Text('Về danh sách'),
         onTap:()=>setState((){selectedThread=null;selectedMail=null;})),
        for(final item in messages)ListTile(
         leading:const Icon(Icons.email_outlined),
         title:Text(item['subject']?.toString()??'Không có tiêu đề'),
         subtitle:Text(item['from']?.toString()??''),
         onTap:()=>openMessage(item['id'].toString())),
       ]):
       threads.isEmpty&&!busy?Center(child:Text(error==null?'Chưa có email':'Không tải được hộp thư')):
       ListView.builder(itemCount:threads.length,itemBuilder:(context,index){
        final item=threads[index];
        return ListTile(
         leading:Icon(item['read']==false?Icons.mark_email_unread_outlined:Icons.mail_outline),
         title:Text(item['subject']?.toString()??'Không có tiêu đề'),
         subtitle:Text(item['from']?.toString()??''),
         trailing:const Icon(Icons.chevron_right),
         onTap:()=>openThread(item['id'].toString()));
       })),
   ]));
 }
}

class _MailComposer extends StatefulWidget{
 final SalesSession session;
 final String mailbox;
 const _MailComposer({required this.session,required this.mailbox});
 @override State<_MailComposer> createState()=>_MailComposerState();
}
class _MailComposerState extends State<_MailComposer>{
 final to=TextEditingController(),subject=TextEditingController(),text=TextEditingController();
 bool busy=false;String? error;
 @override void dispose(){to.dispose();subject.dispose();text.dispose();super.dispose();}
 Future<void> send()async{
  if(busy)return;
  if(!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(to.text.trim())||
   subject.text.trim().isEmpty||text.text.trim().isEmpty){
    setState(()=>error='Nhập đầy đủ người nhận, tiêu đề và nội dung.');return;
  }
  setState((){busy=true;error=null;});
  try{
   await widget.session.post('/api/v1/mail/send',{
    'request_id':const Uuid().v4(),
    'to':to.text.trim(),'subject':subject.text.trim(),'text':text.text.trim()
   });
   if(mounted)Navigator.of(context).pop(true);
  }catch(e){if(mounted)setState(()=>error=e.toString());}
  finally{if(mounted)setState(()=>busy=false);}
 }
 @override Widget build(BuildContext context)=>AlertDialog(
  title:Text('Soạn thư · ${widget.mailbox}'),
  content:SizedBox(width:480,child:SingleChildScrollView(child:Column(
   mainAxisSize:MainAxisSize.min,children:[
    TextField(controller:to,decoration:const InputDecoration(labelText:'Đến')),
    TextField(controller:subject,decoration:const InputDecoration(labelText:'Tiêu đề'),
     maxLength:200),
    TextField(controller:text,decoration:const InputDecoration(labelText:'Nội dung'),
     maxLines:8,minLines:4,maxLength:12000),
    if(error!=null)Text(error!,style:TextStyle(color:Theme.of(context).colorScheme.error))
   ]))),
  actions:[
   TextButton(onPressed:busy?null:()=>Navigator.pop(context,false),child:const Text('Hủy')),
   FilledButton.icon(onPressed:busy?null:send,icon:const Icon(Icons.send_outlined),
    label:Text(busy?'Đang gửi...':'Gửi email')),
  ]);
}
