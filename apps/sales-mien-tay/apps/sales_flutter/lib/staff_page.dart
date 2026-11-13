import 'package:flutter/material.dart';
import 'models.dart';
import 'session.dart';
import 'org_scope_page.dart';

class StaffPage extends StatefulWidget {
 final SalesSession session;
 const StaffPage({super.key,required this.session});
 @override State<StaffPage> createState()=>_StaffPageState();
}
class _StaffPageState extends State<StaffPage>{
 List<Map<String,dynamic>> items=[];
 bool loading=true;
 String? error;
 @override void initState(){super.initState();load();}
 Future<void> load() async{
  setState(()=>loading=true);
  try{final r=await widget.session.get('/api/v1/admin/staff');if(mounted)setState((){items=(r['items'] as List).cast<Map<String,dynamic>>();error=null;});}
  catch(e){if(mounted)setState((){items=[];error=e.toString();});}
  finally{if(mounted)setState(()=>loading=false);}
 }
 Future<void> edit([Map<String,dynamic>? row]) async{
  final catalog=await RegionCatalog.load();
  final territories=await widget.session.get('/api/v1/admin/org/territories');
  final combined=<String,List<String>>{for(final e in catalog.districts.entries)e.key:[...e.value]};
  for(final item in (territories['items'] as List)){
    if(item['level']=='province')combined.putIfAbsent(item['name'].toString(),()=>[]);
  }
  for(final item in (territories['items'] as List)){
    if(item['level']=='district'){
      final p=item['province']?.toString()??'',d=item['name'].toString();
      if(combined.containsKey(p)&&!combined[p]!.contains(d))combined[p]!.add(d);
    }
  }
  final nationwide=RegionCatalog(combined);
  if(!mounted)return;
  final saved=await showDialog<bool>(context:context,barrierDismissible:false,builder:(_)=>StaffEditor(session:widget.session,catalog:nationwide,staff:row,allStaff:items));
  if(saved==true&&mounted){await load();if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Đã lưu nhân viên và địa bàn.')));}
 }
 List<Map<String,dynamic>> get orderedStaff {
  final rows=<Map<String,dynamic>>[];
  final seen=<String>{};
  final byId={for(final m in items)m['user_sub'].toString():m};
  void visit(Map<String,dynamic> m,int level){
    final id=m['user_sub'].toString();
    if(!seen.add(id))return;
    rows.add({...m,'_level':level});
    for(final child in items.where((e)=>e['manager_sub']==id)){
      visit(child,level+1);
    }
  }
  for(final m in items.where((e)=>e['manager_sub']==null||!byId.containsKey(e['manager_sub'].toString()))){
    visit(m,0);
  }
  for(final m in items){visit(m,0);}
  return rows;
 }
 String description(Map<String,dynamic> m){
  final areas=(m['scopes'] as List).map((s)=>s['province'].toString()+' / '+(s['district']==''?'Toàn tỉnh':s['district'].toString())).join(' • ');
  return m['email'].toString()+' · '+m['role'].toString()+' · '+(m['job_title']?.toString().isNotEmpty==true?m['job_title'].toString()+' · ':'')+(m['active']==true?'Hoạt động':'Đã khóa')+'\n'+areas;
 }
 @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Quản lý nhân viên'),actions:[IconButton(onPressed:loading?null:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>OrgScopePage(session:widget.session))),tooltip:'Cơ cấu & phân công',icon:const Icon(Icons.admin_panel_settings_outlined)),IconButton(onPressed:loading?null:load,tooltip:'Tải lại',icon:const Icon(Icons.refresh)),IconButton(onPressed:loading?null:()=>edit(),tooltip:'Thêm nhân viên',icon:const Icon(Icons.person_add_alt_1))]),body:loading?const Center(child:CircularProgressIndicator()):error!=null?Center(child:Text(error!)):items.isEmpty?Center(child:FilledButton(onPressed:()=>edit(),child:const Text('Thêm nhân viên'))):ListView(padding:const EdgeInsets.all(12),children:[const Padding(padding:EdgeInsets.only(bottom:12),child:Text('Cấp trên → cấp dưới. Chạm nhân viên để sửa cấp trên, chức danh và địa bàn.')),for(final m in orderedStaff)Card(child:ListTile(contentPadding:EdgeInsets.only(left:12.0+16.0*(m['_level'] as int),right:12),leading:Icon((m['_level'] as int)>0?Icons.subdirectory_arrow_right:Icons.account_tree_outlined),title:Text(m['employee_code'].toString()+' · '+m['full_name'].toString()),subtitle:Text(description(m)),isThreeLine:true,trailing:const Icon(Icons.edit_outlined),onTap:()=>edit(m)))]));
}
class StaffEditor extends StatefulWidget {
 final SalesSession session;
 final RegionCatalog catalog;
 final Map<String,dynamic>? staff;
 final List<Map<String,dynamic>> allStaff;
 const StaffEditor({super.key,required this.session,required this.catalog,
   required this.staff,required this.allStaff});
 @override State<StaffEditor> createState()=>_StaffEditorState();
}

class _StaffEditorState extends State<StaffEditor> {
 late final TextEditingController subject,code,name,phone,email,jobTitle;
 late final Set<String> reports;
 late String role;
 late bool active;
 String? manager,error;
 String provinceFilter='';
 bool busy=false;
 final Map<String,Set<String>> scopes={};

 @override void initState(){
  super.initState();
  final s=widget.staff??<String,dynamic>{};
  subject=TextEditingController(text:s['user_sub']?.toString()??'');
  code=TextEditingController(text:s['employee_code']?.toString()??'');
  name=TextEditingController(text:s['full_name']?.toString()??'');
  phone=TextEditingController(text:s['phone']?.toString()??'');
  email=TextEditingController(text:s['email']?.toString()??'');
  jobTitle=TextEditingController(text:s['job_title']?.toString()??'');
  role=s['role']?.toString()??'sales';
  active=s['active']!=false;
  manager=s['manager_sub']?.toString();
  reports={
    if(widget.staff!=null)
      for(final m in widget.allStaff)
        if(m['manager_sub']==widget.staff!['user_sub'])m['user_sub'].toString()
  };
  for(final a in (s['scopes'] as List? ?? [])){
   scopes.putIfAbsent(a['province'].toString(),()=>{}).add(a['district'].toString());
  }
 }
 @override void dispose(){
  subject.dispose();code.dispose();name.dispose();phone.dispose();
  email.dispose();jobTitle.dispose();super.dispose();
 }

 Map<String,dynamic>? findStaff(String id){
  for(final row in widget.allStaff){
   if(row['user_sub']==id)return row;
  }
  return null;
 }
 String staffName(String id)=>findStaff(id)?['full_name']?.toString()??'Nhân viên đã đổi';
 bool isAncestor(String id){
  var parent=widget.staff?['manager_sub']?.toString();
  final seen=<String>{};
  while(parent!=null&&parent.isNotEmpty&&seen.add(parent)){
   if(parent==id)return true;
   parent=findStaff(parent)?['manager_sub']?.toString();
  }
  return false;
 }
 bool isDescendant(String id){
  var parent=findStaff(id)?['manager_sub']?.toString();
  final seen=<String>{};
  while(parent!=null&&parent.isNotEmpty&&seen.add(parent)){
   if(parent==subject.text)return true;
   parent=findStaff(parent)?['manager_sub']?.toString();
  }
  return false;
 }
 List<Map<String,dynamic>> get availableSupervisors =>
   widget.allStaff.where((m)=>m['role']=='manager'&&m['active']==true&&
      m['user_sub']!=subject.text&&!isDescendant(m['user_sub'].toString())).toList();
 int get assignedAreas=>scopes.values.where((set)=>set.isNotEmpty).length;
 List<Map<String,dynamic>> get reportChanges{
  final current=<String>{
   if(widget.staff!=null)
    for(final m in widget.allStaff)
      if(m['manager_sub']==widget.staff!['user_sub'])m['user_sub'].toString()
  };
  final changed=current.union(reports).where((id)=>current.contains(id)!=reports.contains(id));
  return [
   for(final id in changed)
    if(findStaff(id)!=null)
     {'user_sub':id,'assigned':reports.contains(id),
      'scope_revision':findStaff(id)!['scope_revision'].toString()}
  ];
 }

 Future<void> chooseReports() async {
  if(role!='manager'||busy)return;
  final draft=<String>{...reports};
  var query='';
  await showModalBottomSheet<void>(
   context:context,isScrollControlled:true,useSafeArea:true,
   builder:(sheetContext)=>StatefulBuilder(builder:(sheetContext,setModalState){
    final candidates=widget.allStaff.where((m)=>
      m['role']!='admin'&&(m['active']==true||reports.contains(m['user_sub'].toString()))&&m['user_sub']!=subject.text&&
      !isAncestor(m['user_sub'].toString())).toList();
    candidates.sort((a,b){
     final av=draft.contains(a['user_sub'])?0:1,bv=draft.contains(b['user_sub'])?0:1;
     return av!=bv?av.compareTo(bv):
       a['full_name'].toString().compareTo(b['full_name'].toString());
    });
    final filtered=candidates.where((m)=>
      (m['full_name'].toString()+' '+m['employee_code'].toString())
        .toLowerCase().contains(query.trim().toLowerCase())).toList();
    return SizedBox(height:MediaQuery.sizeOf(sheetContext).height*0.78,
      child:Column(children:[
       Padding(padding:const EdgeInsets.fromLTRB(16,16,16,10),
        child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
         Text('Chọn nhân viên cấp dưới',style:Theme.of(sheetContext).textTheme.titleLarge),
         const SizedBox(height:6),
         Text('Đã chọn '+draft.length.toString()+' người. Có thể chuyển nhân viên từ cấp trên khác.',
           style:Theme.of(sheetContext).textTheme.bodySmall),
         const SizedBox(height:12),
         TextField(decoration:const InputDecoration(prefixIcon:Icon(Icons.search),
            labelText:'Tìm tên hoặc mã nhân viên'),onChanged:(s)=>setModalState(()=>query=s)),
        ])),
       Expanded(child:filtered.isEmpty?
         const Center(child:Text('Không tìm thấy nhân viên phù hợp')):
         ListView.builder(itemCount:filtered.length,itemBuilder:(ctx,index){
          final m=filtered[index];
          final id=m['user_sub'].toString();
          final otherManager=m['manager_sub']?.toString();
          final note=otherManager==null?'Chưa có cấp trên':
            (otherManager==subject.text?'Đang trực thuộc nhân viên này':
             'Cấp trên hiện tại: '+staffName(otherManager));
          return CheckboxListTile(
            value:draft.contains(id),dense:true,
            title:Text(m['full_name'].toString()+' · '+m['employee_code'].toString()),
            subtitle:Text(note),controlAffinity:ListTileControlAffinity.leading,
            onChanged:(v)=>setModalState((){
             if(v==true){draft.add(id);}else{draft.remove(id);}
            }),
          );
         })),
       Padding(padding:const EdgeInsets.fromLTRB(16,8,16,16),child:Row(children:[
        Expanded(child:OutlinedButton(onPressed:()=>Navigator.pop(sheetContext),
          child:const Text('Hủy'))),
        const SizedBox(width:12),
        Expanded(child:FilledButton(onPressed:(){
          setState((){reports..clear()..addAll(draft);error=null;});
          Navigator.pop(sheetContext);
         },child:Text('Chọn '+draft.length.toString()+' người'))),
       ]))
      ]));
   })
  );
 }

 Future<void> save() async {
  if(busy)return;
  if(code.text.trim().isEmpty||name.text.trim().isEmpty||email.text.trim().isEmpty){
   setState(()=>error='Anh nhập họ tên, email và mã nhân viên trước khi lưu.');return;
  }
  if(!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email.text.trim())){
   setState(()=>error='Email không hợp lệ.');return;
  }
  if(jobTitle.text.trim().length>120){
   setState(()=>error='Chức danh tối đa 120 ký tự.');return;
  }
  if(role!='manager'&&reports.isNotEmpty){
   setState(()=>error='Muốn đổi vai trò, anh cần chuyển hết cấp dưới khi vẫn ở vai trò Manager trước.');return;
  }
  if(role=='manager'&&!active&&reports.isNotEmpty){
   setState(()=>error='Muốn khóa Manager, anh cần chuyển cấp dưới sang người khác trước.');return;
  }
  setState((){busy=true;error=null;});
  try{
   if(subject.text.trim().isEmpty){
    final created=await widget.session.post('/api/v1/admin/identity',{
      'email':email.text.trim(),'name':name.text.trim()});
    final id=created['user_sub']?.toString();
    if(id==null||id.isEmpty)throw const ApiFailure(502,'Không nhận được tài khoản xác thực.');
    subject.text=id;
   }
   await widget.session.post('/api/v1/admin/staff',{
    'user_sub':subject.text.trim(),
    'email':email.text.trim(),
    'employee_code':code.text.trim(),
    'full_name':name.text.trim(),
    'phone':phone.text.trim(),
    'job_title':jobTitle.text.trim(),
    'role':role,'active':active,
    'manager_sub':role=='admin'?null:manager,
    'scope_revision':widget.staff?['scope_revision']?.toString()??'0',
    'scopes':[for(final e in scopes.entries)for(final d in e.value)
      {'province':e.key,'district':d}],
    'report_changes':reportChanges
   });
   if(mounted)Navigator.pop(context,true);
  }catch(e){
   if(mounted)setState(()=>error=e.toString());
  }finally{
   if(mounted)setState(()=>busy=false);
  }
 }

 Widget field(TextEditingController controller,String label,{
   TextInputType? keyboardType,bool readOnly=false,TextCapitalization capitalization=TextCapitalization.none
 })=>Padding(padding:const EdgeInsets.only(bottom:12),
  child:TextField(controller:controller,enabled:!busy,readOnly:readOnly,
    keyboardType:keyboardType,textCapitalization:capitalization,
    decoration:InputDecoration(labelText:label)));

 Widget heading(String title,String subtitle,IconData icon)=>Padding(
  padding:const EdgeInsets.only(top:16,bottom:10),
  child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
   Icon(icon,color:Theme.of(context).colorScheme.primary,size:20),
   const SizedBox(width:10),
   Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Text(title,style:Theme.of(context).textTheme.titleMedium),
    Text(subtitle,style:Theme.of(context).textTheme.bodySmall)
   ])),
  ]));

 Widget get form=>ListView(padding:const EdgeInsets.fromLTRB(16,4,16,28),
  keyboardDismissBehavior:ScrollViewKeyboardDismissBehavior.onDrag,children:[
  heading('Thông tin nhân viên','Tài khoản đăng nhập bằng email / mã OTP.',Icons.badge_outlined),
  field(name,'Họ tên',capitalization:TextCapitalization.words),
  field(email,'Email đăng nhập',keyboardType:TextInputType.emailAddress,
    readOnly:widget.staff==null&&subject.text.isNotEmpty),
  Row(children:[
    Expanded(child:field(code,'Mã nhân viên')),
    const SizedBox(width:10),
    Expanded(child:field(phone,'Điện thoại',keyboardType:TextInputType.phone)),
  ]),
  field(jobTitle,'Chức danh (tự đặt, ví dụ: Mekong-Supervisor)'),
  DropdownButtonFormField<String>(
    key:ValueKey('role:'+role),initialValue:role,
    decoration:const InputDecoration(labelText:'Vai trò hệ thống'),
    items:const [
     DropdownMenuItem(value:'admin',child:Text('Admin')),
     DropdownMenuItem(value:'manager',child:Text('Manager')),
     DropdownMenuItem(value:'sales',child:Text('Sales'))
    ],onChanged:busy?null:(v)=>setState(()=>role=v??'sales')),
  const SizedBox(height:8),
  SwitchListTile(contentPadding:EdgeInsets.zero,
    title:const Text('Tài khoản hoạt động'),
    value:active,onChanged:busy?null:(v)=>setState(()=>active=v)),
  const Divider(),
  heading('Quan hệ nhân sự','Cấp trên và cấp dưới, không phải phạm vi địa bàn.',Icons.account_tree_outlined),
  if(role!='admin')...[
   DropdownButtonFormField<String>(
    key:ValueKey('supervisor:'+manager.toString()),
    initialValue:availableSupervisors.any((m)=>m['user_sub']==manager)?manager:'',
    isExpanded:true,
    decoration:const InputDecoration(labelText:'Cấp trên trực tiếp',
      helperText:'Người trực tiếp quản lý nhân viên này'),
    items:[
     const DropdownMenuItem(value:'',child:Text('Chưa có cấp trên')),
     for(final m in availableSupervisors)
       DropdownMenuItem(value:m['user_sub'].toString(),
         child:Text(m['full_name'].toString(),overflow:TextOverflow.ellipsis)),
    ],
    onChanged:busy?null:(v)=>setState(()=>manager=v==''?null:v)),
   const SizedBox(height:16),
  ],
  if(role=='manager')...[
   OutlinedButton.icon(onPressed:busy?null:chooseReports,
     icon:const Icon(Icons.group_add_outlined),
     label:Text('Chọn nhân viên cấp dưới ('+reports.length.toString()+')')),
   if(reports.isNotEmpty)Padding(padding:const EdgeInsets.only(top:8),
    child:Wrap(spacing:6,runSpacing:4,children:[
      for(final id in reports)
       InputChip(label:Text(staffName(id)),onDeleted:busy?null:()=>setState(()=>reports.remove(id)))
    ])),
   const SizedBox(height:8),
   Text('Có thể chọn nhiều người cùng lúc. Nhân viên chuyển sang cấp trên mới vẫn giữ địa bàn/chuỗi riêng.',
     style:Theme.of(context).textTheme.bodySmall),
  ]else if(widget.staff!=null&&widget.allStaff.any((m)=>m['manager_sub']==subject.text))...[
   const Text('Nhân viên này đang có cấp dưới. Chuyển cấp dưới sang người khác trước khi hạ vai trò.'),
  ],
  const Divider(height:32),
  ExpansionTile(
   tilePadding:EdgeInsets.zero,childrenPadding:EdgeInsets.zero,
   leading:const Icon(Icons.map_outlined),
   title:const Text('Địa bàn phụ trách riêng'),
   subtitle:Text(assignedAreas==0?'Chưa giao địa bàn · Không bắt buộc':
       'Đang phụ trách '+assignedAreas.toString()+' tỉnh / khu vực'),
   children:[
    Padding(padding:const EdgeInsets.only(bottom:12),
     child:TextField(decoration:const InputDecoration(prefixIcon:Icon(Icons.search),
       labelText:'Tìm tỉnh / thành phố'),
       onChanged:(v)=>setState(()=>provinceFilter=v))),
    for(final p in widget.catalog.provinces.where(
      (p)=>p.toLowerCase().contains(provinceFilter.trim().toLowerCase())))
     ExpansionTile(key:PageStorageKey('province:'+p),
      title:Text(p),
      subtitle:Text(scopes[p]?.contains('')==true?'Toàn tỉnh':
        ((scopes[p]?.where((d)=>d.isNotEmpty).length??0).toString()+' huyện')),
      children:[
       CheckboxListTile(dense:true,title:const Text('Toàn tỉnh'),
         value:scopes[p]?.contains('')??false,
         onChanged:busy?null:(v)=>setState(()=>scopes[p]=v==true?{''}:<String>{})),
       for(final d in widget.catalog.districts[p]!)
        CheckboxListTile(dense:true,title:Text(d),
          value:scopes[p]?.contains('')==true||scopes[p]?.contains(d)==true,
          onChanged:busy||scopes[p]?.contains('')==true?null:(v)=>setState((){
           final chosen=scopes.putIfAbsent(p,()=>{});
           if(v==true){chosen.add(d);}else{chosen.remove(d);}
          })),
      ]),
    const SizedBox(height:8),
    Text('Địa bàn này chỉ giao trực tiếp cho nhân viên, không tự chuyển sang cấp trên.',
      style:Theme.of(context).textTheme.bodySmall),
   ],
  ),
  Padding(padding:const EdgeInsets.only(top:12),
   child:Text('Chuỗi / hệ thống và khách hàng riêng được giao ở mục Cơ cấu & phân công sau khi lưu hồ sơ.',
    style:Theme.of(context).textTheme.bodySmall)),
 ]);

 Widget get footer=>SafeArea(top:false,child:Padding(
  padding:const EdgeInsets.fromLTRB(12,8,12,12),
  child:Column(mainAxisSize:MainAxisSize.min,children:[
   if(error!=null)Padding(padding:const EdgeInsets.only(bottom:8),
    child:Semantics(liveRegion:true,child:Text(error!,
     style:TextStyle(color:Theme.of(context).colorScheme.error)))),
   Row(children:[
    Expanded(child:OutlinedButton(onPressed:busy?null:()=>Navigator.pop(context),
      child:const Text('Hủy'))),
    const SizedBox(width:12),
    Expanded(child:FilledButton(onPressed:busy?null:save,
      child:Text(busy?'Đang lưu...':'Lưu nhân viên'))),
   ]),
  ])));

 @override Widget build(BuildContext context){
  final narrow=MediaQuery.sizeOf(context).width<600;
  final title=widget.staff==null?'Thêm nhân viên':'Sửa nhân viên';
  if(narrow){
   return Dialog.fullscreen(child:Scaffold(
    appBar:AppBar(title:Text(title),leading:IconButton(
     tooltip:'Đóng',icon:const Icon(Icons.close),
     onPressed:busy?null:()=>Navigator.pop(context))),
    body:form,bottomNavigationBar:footer,
   ));
  }
  return Dialog(child:ConstrainedBox(
   constraints:BoxConstraints(maxWidth:660,maxHeight:MediaQuery.sizeOf(context).height*0.87),
   child:Column(children:[
    Padding(padding:const EdgeInsets.fromLTRB(20,16,20,8),
      child:Align(alignment:Alignment.centerLeft,
        child:Text(title,style:Theme.of(context).textTheme.headlineSmall))),
    Expanded(child:form),
    footer,
   ])));
 }
}
