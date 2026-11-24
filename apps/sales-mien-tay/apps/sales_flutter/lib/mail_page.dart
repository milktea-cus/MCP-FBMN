import 'dart:async';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import 'session.dart';

/// This page intentionally never stores mail in the offline business queue.
class StaffMailPage extends StatefulWidget {
 final SalesSession session;
 final String? initialThreadId;
 const StaffMailPage({super.key,required this.session,this.initialThreadId});
 @override State<StaffMailPage> createState()=>_StaffMailPageState();
}

class _StaffMailPageState extends State<StaffMailPage>{
 bool busy=true;
 int generation=0;
 String? error,mailbox,selectedFolder,selectedThread,threadCursor,messageCursor;
 List<Map<String,dynamic>> threads=[],messages=[];
 Map<String,dynamic>? selectedMail;
 bool current(int token)=>mounted&&generation==token;
 List<Map<String,dynamic>> rows(dynamic value)=>(value as List? ?? [])
   .whereType<Map>().map((v)=>Map<String,dynamic>.from(v)).toList();
 List<Map<String,dynamic>> merge(List<Map<String,dynamic>> old,List<Map<String,dynamic>> fresh)=>
   {for(final row in [...old,...fresh])row['id'].toString():row}.values.toList();
 String? cursor(Map<String,dynamic> result,List<Map<String,dynamic>> page,String? previous){
  if(result['has_more']!=true||page.isEmpty)return null;
  final next=result['next_cursor']?.toString()??page.last['id']?.toString();
  return next==null||next==previous?null:next;
 }
 @override void initState(){super.initState();unawaited(_loadInitial());}
 Future<void> _loadInitial()async{
  final first=generation+1;
  await load();
  final thread=widget.initialThreadId;
  if(current(first)&&thread!=null&&RegExp(r'^[0-9a-f-]{36}$',caseSensitive:false).hasMatch(thread))
   await openThread(thread);
 }
 Future<void> load({String folder='inbox',bool more=false})async{
  if(!mounted||more&&(busy||threadCursor==null||selectedThread!=null))return;
  final after=more?threadCursor:null,token=++generation;
  setState((){
   busy=true;error=null;selectedFolder=folder;selectedThread=null;selectedMail=null;
   messages=[];messageCursor=null;
   if(!more){threads=[];threadCursor=null;}
  });
  try{
   final me=mailbox==null?await widget.session.get('/api/v1/mail/me'):null;
   final result=await widget.session.get('/api/v1/mail/threads?folder=$folder'+(after==null?'':'&after=$after'));
   if(!current(token))return;
   final page=rows(result['items']);
   setState((){
    if(me!=null)mailbox=me['mailbox']?.toString();
    threads=merge(more?threads:[],page);
    threadCursor=cursor(result,page,after);
   });
  }catch(e){if(current(token))setState(()=>error=e.toString());}
  finally{if(current(token))setState(()=>busy=false);}
 }
 Future<void> openThread(String id,{bool more=false})async{
  if(!mounted||more&&(busy||messageCursor==null||selectedThread!=id))return;
  final after=more?messageCursor:null,token=++generation;
  setState((){
   busy=true;error=null;selectedThread=id;selectedMail=null;
   if(!more){messages=[];messageCursor=null;}
  });
  try{
   final result=await widget.session.get('/api/v1/mail/threads/$id'+(after==null?'':'?after=$after'));
   if(!current(token))return;
   final page=rows(result['emails']);
   setState((){
    messages=merge(more?messages:[],page);
    messageCursor=cursor(result,page,after);
   });
  }catch(e){if(current(token))setState(()=>error=e.toString());}
  finally{if(current(token))setState(()=>busy=false);}
 }
 Future<void> openMessage(String id)async{
  final thread=selectedThread;
  if(!mounted||thread==null)return;
  final token=++generation;
  setState((){busy=true;error=null;selectedMail=null;});
  try{
   final result=await widget.session.get('/api/v1/mail/threads/$thread/emails/$id');
   if(!current(token))return;
   final item=Map<String,dynamic>.from(result['item'] as Map);
   if(item['id']?.toString()!=id)throw StateError('Máy chủ trả nhầm email.');
   setState(()=>selectedMail=item);
   try{
    await widget.session.post('/api/v1/mail/threads/$thread/read',{});
    if(current(token))setState((){
     threads=[for(final row in threads)if(row['id']==thread){...row,'read':true}else row];
    });
   }catch(_){/* Reading remains possible if the receipt fails. */}
  }catch(e){if(current(token))setState(()=>error=e.toString());}
  finally{if(current(token))setState(()=>busy=false);}
 }
 Future<void> reply()async{
  final thread=selectedThread,id=selectedMail?['id']?.toString();
  if(busy||thread==null||id==null)return;
  final token=generation;
  final sent=await showDialog<bool>(context:context,barrierDismissible:false,builder:(context)=>
   _MailComposer(session:widget.session,mailbox:mailbox??'',
    threadId:thread,emailId:id,
    replyTo:selectedMail?['from']?.toString()));
  if(sent==true&&current(token))await openThread(thread);
 }
 void backWithinMail(){
  if(!mounted)return;
  if(selectedMail!=null){
   generation++;setState((){selectedMail=null;busy=false;error=null;});
  }else if(selectedThread!=null){
   generation++;setState((){selectedThread=null;messages=[];messageCursor=null;busy=false;error=null;});
  }else{
   Navigator.of(context).maybePop();
  }
 }
 Future<void> downloadAttachment(Map<String,dynamic> item)async{
  if(selectedThread==null||selectedMail?['id']==null||item['id']==null)return;
  try{
   final path='/api/v1/mail/threads/$selectedThread/emails/${selectedMail!['id']}/attachments/${item['id']}';
   if(kIsWeb){
    // Open directly from the click gesture to avoid popup blockers.
    final uri=widget.session.uri('$path/download');
    if(!await launchUrl(uri,mode:LaunchMode.platformDefault))
     throw StateError('Trình duyệt chặn cửa sổ tải tệp');
   }else{
    // Native external browsers don't carry the app's encrypted session cookie.
    final result=await widget.session.get(path);
    final uri=Uri.tryParse(result['url']?.toString()??'');
    if(uri==null||uri.scheme!='https')throw StateError('Đường dẫn tệp không hợp lệ');
    if(!await launchUrl(uri,mode:LaunchMode.externalApplication))
     throw StateError('Không mở được tệp');
   }
  }catch(e){if(mounted)setState(()=>error='Không tải được tệp: $e');}
 }
 Future<void> compose()async{
  final sent=await showDialog<bool>(context:context,barrierDismissible:false,builder:(context)=>
   _MailComposer(session:widget.session,mailbox:mailbox??''));
  if(sent==true&&mounted)await load(folder:'sent');
 }
 @override Widget build(BuildContext context){
  final theme=Theme.of(context);
  return Scaffold(appBar:AppBar(
   leading:selectedThread!=null?IconButton(icon:const Icon(Icons.arrow_back),
    tooltip:selectedMail!=null?'Về hội thoại':'Về danh sách thư',
    onPressed:backWithinMail):null,
   title:Text(selectedMail!=null?'Đọc email':selectedThread!=null?'Hội thoại':'Email'),
   actions:[
    if(selectedMail!=null)
     IconButton(tooltip:'Trả lời thư này',onPressed:busy?null:reply,
      icon:const Icon(Icons.reply_outlined)),
    IconButton(tooltip:'Làm mới',onPressed:busy?null:()=>
       load(folder:selectedFolder??'inbox'),icon:const Icon(Icons.refresh))
   ]),
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
       Wrap(spacing:8,runSpacing:4,alignment:WrapAlignment.spaceBetween,children:[
        TextButton.icon(onPressed:busy?null:backWithinMail,
         icon:const Icon(Icons.arrow_back),label:const Text('Về hội thoại')),
        FilledButton.tonalIcon(onPressed:busy?null:reply,
          icon:const Icon(Icons.reply_outlined),label:const Text('Trả lời')),
       ]),
       const SizedBox(height:8),
       Text(selectedMail?['subject']?.toString()??'',style:theme.textTheme.titleLarge),
       const SizedBox(height:12),
       Text('Từ: ${selectedMail?['from']??''}'),
       Text('Đến: ${selectedMail?['to']??''}'),
       const Divider(height:30),
       SelectableText(selectedMail?['text']?.toString()??'(Email không có bản văn bản thuần)'),
       if(selectedMail?['attachments'] is List && (selectedMail!['attachments'] as List).isNotEmpty)...[
        const Divider(height:30),
        Text('Tệp đính kèm',style:theme.textTheme.titleMedium),
        for(final raw in (selectedMail!['attachments'] as List))
         if(raw is Map) ListTile(
          contentPadding:EdgeInsets.zero,
          leading:const Icon(Icons.attach_file),
          title:Text(raw['filename']?.toString()??'Tệp đính kèm'),
          subtitle:Text(raw['size'] is num?'${((raw['size'] as num)/1024).toStringAsFixed(0)} KB':''),
          trailing:const Icon(Icons.download_outlined),
          onTap:()=>downloadAttachment(Map<String,dynamic>.from(raw))
         ),
       ],
       const SizedBox(height:18),
       Align(alignment:Alignment.centerRight,child:FilledButton.tonalIcon(
        onPressed:busy?null:reply,icon:const Icon(Icons.reply_outlined),
        label:const Text('Trả lời'))),
      ]):
      selectedThread!=null?
       ListView(children:[
        ListTile(leading:const Icon(Icons.arrow_back),title:const Text('Về danh sách'),
         onTap:backWithinMail),
        for(final item in messages)ListTile(
         leading:const Icon(Icons.email_outlined),
         title:Text(item['subject']?.toString()??'Không có tiêu đề'),
         subtitle:Text(item['from']?.toString()??''),
         onTap:()=>openMessage(item['id'].toString())),
        if(messageCursor!=null)TextButton(onPressed:busy?null:()=>openThread(selectedThread!,more:true),child:const Text('Tải thêm thư')),
       ]):
       threads.isEmpty&&!busy?Center(child:Text(error==null?'Chưa có email':'Không tải được hộp thư')):
       ListView.builder(itemCount:threads.length+(threadCursor==null?0:1),itemBuilder:(context,index){
        if(index==threads.length)return TextButton(onPressed:busy?null:()=>load(folder:selectedFolder??'inbox',more:true),child:const Text('Tải thêm hội thoại'));
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
 final String? threadId,emailId,replyTo;
 const _MailComposer({required this.session,required this.mailbox,
   this.threadId,this.emailId,this.replyTo});
 @override State<_MailComposer> createState()=>_MailComposerState();
}
class _MailComposerState extends State<_MailComposer>{
 final to=TextEditingController(),subject=TextEditingController(),text=TextEditingController();
 bool busy=false,picking=false;String? error;
 final List<Map<String,dynamic>> attachments=[];
 late final String requestId=const Uuid().v4();
 static const maxAttachmentBytes=5*1024*1024;
 static const allowedExtensions=['pdf','png','jpg','jpeg','webp','txt','csv','docx','xlsx','pptx'];
 Future<void> pickAttachments()async{
  if(busy||picking)return;
  setState(()=>picking=true);
  try{
   final picked=await FilePicker.platform.pickFiles(type:FileType.custom,
     allowedExtensions:allowedExtensions,allowMultiple:true,withData:true);
   if(picked==null||!mounted)return;
   final selected=<Map<String,dynamic>>[...attachments];
   for(final file in picked.files){
    if(selected.length>=4)throw StateError('Tối đa 4 tệp đính kèm.');
    final bytes=file.bytes;
    if(bytes==null||bytes.isEmpty)throw StateError('Không đọc được ${file.name}.');
    if(file.name.length>120||file.name.contains('/')||file.name.contains('\\'))
     throw StateError('Tên tệp không hợp lệ.');
    final size=selected.fold<int>(0,(n,f)=>n+(f['size'] as int))+bytes.length;
    if(size>maxAttachmentBytes)throw StateError('Tổng tệp tối đa 5 MB.');
    selected.add({'filename':file.name,'content':base64Encode(bytes),'size':bytes.length});
   }
   if(mounted)setState((){attachments..clear()..addAll(selected);error=null;});
  }catch(e){if(mounted)setState(()=>error='Không thêm được tệp: $e');}
  finally{if(mounted)setState(()=>picking=false);}
 }

 @override void dispose(){to.dispose();subject.dispose();text.dispose();super.dispose();}
 Future<void> send()async{
  if(busy||picking)return;
  if((widget.threadId==null&&(!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(to.text.trim())||subject.text.trim().isEmpty))||text.text.trim().isEmpty){
    setState(()=>error='Nhập đầy đủ người nhận, tiêu đề và nội dung.');return;
  }
  setState((){busy=true;error=null;});
  try{
   if(widget.threadId!=null&&widget.emailId!=null){
    await widget.session.postMail('/api/v1/mail/threads/${widget.threadId}/emails/${widget.emailId}/reply',{
      'request_id':requestId,'text':text.text.trim(),
      'attachments':attachments.map((f)=>{'filename':f['filename'],'content':f['content']}).toList()});
   }else{
    await widget.session.postMail('/api/v1/mail/send',{
      'request_id':requestId,'to':to.text.trim(),
      'subject':subject.text.trim(),'text':text.text.trim(),
      'attachments':attachments.map((f)=>{'filename':f['filename'],'content':f['content']}).toList()});
   }
   if(mounted)Navigator.of(context).pop(true);
  }catch(e){if(mounted)setState(()=>error=e.toString());}
  finally{if(mounted)setState(()=>busy=false);}
 }
 @override Widget build(BuildContext context)=>AlertDialog(
  title:Text(widget.threadId==null?'Soạn thư · ${widget.mailbox}':'Trả lời · ${widget.mailbox}'),
  content:SizedBox(width:480,child:SingleChildScrollView(child:Column(
   mainAxisSize:MainAxisSize.min,children:[
    if(widget.threadId==null)...[
      TextField(controller:to,enabled:!busy,decoration:const InputDecoration(labelText:'Đến')),
      TextField(controller:subject,enabled:!busy,decoration:const InputDecoration(labelText:'Tiêu đề'),maxLength:200),
    ]else Padding(padding:const EdgeInsets.symmetric(vertical:8),
      child:Align(alignment:Alignment.centerLeft,child:Text('Trả lời đến: ${widget.replyTo??'người gửi'}'))),
    TextField(controller:text,enabled:!busy,decoration:const InputDecoration(labelText:'Nội dung'),
     maxLines:8,minLines:4,maxLength:12000),
    const SizedBox(height:8),
    Align(alignment:Alignment.centerLeft,child:TextButton.icon(
     onPressed:busy||picking?null:pickAttachments,icon:const Icon(Icons.attach_file),
     label:const Text('Đính kèm tệp (4 tệp, tổng 5 MB)'))),
    for(var i=0;i<attachments.length;i++)
     ListTile(dense:true,contentPadding:EdgeInsets.zero,
      leading:const Icon(Icons.insert_drive_file_outlined),
      title:Text(attachments[i]['filename'].toString(),maxLines:1,overflow:TextOverflow.ellipsis),
      subtitle:Text('${((attachments[i]['size'] as int)/1024).toStringAsFixed(0)} KB'),
      trailing:IconButton(tooltip:'Bỏ tệp',icon:const Icon(Icons.close),
       onPressed:busy||picking?null:()=>setState(()=>attachments.removeAt(i)))),
    if(error!=null)Text(error!,style:TextStyle(color:Theme.of(context).colorScheme.error))
   ]))),
  actions:[
   TextButton(onPressed:busy?null:()=>Navigator.pop(context,false),child:const Text('Hủy')),
   FilledButton.icon(onPressed:busy||picking?null:send,icon:const Icon(Icons.send_outlined),
    label:Text(busy?'Đang gửi...':'Gửi email')),
  ]);
}

