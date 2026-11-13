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
  final saved=await showDialog<bool>(context:context,barrierDismissible:false,builder:(_)=>StaffEditor(session:widget.session,catalog:nationwide,staff:row,managers:items.where((m)=>m['role']=='manager'&&m['active']==true).toList()));
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
 @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Quản lý nhân viên'),actions:[IconButton(onPressed:loading?null:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>OrgScopePage(session:widget.session))),tooltip:'Phân quyền tổ chức',icon:const Icon(Icons.admin_panel_settings_outlined)),IconButton(onPressed:loading?null:load,tooltip:'Tải lại',icon:const Icon(Icons.refresh)),IconButton(onPressed:loading?null:()=>edit(),tooltip:'Thêm nhân viên',icon:const Icon(Icons.person_add_alt_1))]),body:loading?const Center(child:CircularProgressIndicator()):error!=null?Center(child:Text(error!)):items.isEmpty?Center(child:FilledButton(onPressed:()=>edit(),child:const Text('Thêm nhân viên'))):ListView(padding:const EdgeInsets.all(12),children:[const Padding(padding:EdgeInsets.only(bottom:12),child:Text('Cấp trên → cấp dưới. Chạm nhân viên để sửa cấp trên, chức danh và địa bàn.')),for(final m in orderedStaff)Card(child:ListTile(contentPadding:EdgeInsets.only(left:12.0+16.0*(m['_level'] as int),right:12),leading:Icon((m['_level'] as int)>0?Icons.subdirectory_arrow_right:Icons.account_tree_outlined),title:Text(m['employee_code'].toString()+' · '+m['full_name'].toString()),subtitle:Text(description(m)),isThreeLine:true,trailing:const Icon(Icons.edit_outlined),onTap:()=>edit(m)))]));
}
class StaffEditor extends StatefulWidget{
 final SalesSession session;
 final RegionCatalog catalog;
 final Map<String,dynamic>? staff;
 final List<Map<String,dynamic>> managers;
 const StaffEditor({super.key,required this.session,required this.catalog,required this.staff,required this.managers});
 @override State<StaffEditor> createState()=>_StaffEditorState();
}
class _StaffEditorState extends State<StaffEditor>{
 late final TextEditingController subject,code,name,phone,email,jobTitle;
 late String role;
 late bool active;
 String? manager,error;
 bool busy=false;
 final Map<String,Set<String>> scopes={};
 @override void initState(){
  super.initState();final s=widget.staff??{};
  subject=TextEditingController(text:s['user_sub']?.toString()??'');code=TextEditingController(text:s['employee_code']?.toString()??'');name=TextEditingController(text:s['full_name']?.toString()??'');phone=TextEditingController(text:s['phone']?.toString()??'');
  email=TextEditingController(text:s['email']?.toString()??'');
  jobTitle=TextEditingController(text:s['job_title']?.toString()??'');
  role=s['role']?.toString()??'sales';active=s['active']!=false;manager=s['manager_sub']?.toString();
  for(final a in (s['scopes'] as List? ?? [])){scopes.putIfAbsent(a['province'].toString(),()=>{}).add(a['district'].toString());}
 }
 @override void dispose(){subject.dispose();email.dispose();code.dispose();name.dispose();phone.dispose();jobTitle.dispose();super.dispose();}
 Future<void> save() async{
  if(busy)return;
  if(code.text.trim().isEmpty||name.text.trim().isEmpty||email.text.trim().isEmpty){setState(()=>error='Vui lòng nhập họ tên, email và mã nhân viên.');return;}
  if(!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email.text.trim())){setState(()=>error='Email không hợp lệ.');return;}
  // Managers responsible for teams or chains may have no territory. Scope grants are configured separately.
  setState((){busy=true;error=null;});
  try{
   if(subject.text.trim().isEmpty){
    final r=await widget.session.post('/api/v1/admin/identity',{'email':email.text.trim(),'name':name.text.trim()});
    final id=r['user_sub']?.toString();
    if(id==null||id.isEmpty)throw const ApiFailure(502,'Chưa nhận được tài khoản xác thực.');
    if(!mounted)return;
    setState(()=>subject.text=id);
   }
   await widget.session.post('/api/v1/admin/staff',{'user_sub':subject.text.trim(),'email':email.text.trim(),'employee_code':code.text.trim(),'full_name':name.text.trim(),'phone':phone.text.trim(),'job_title':jobTitle.text.trim(),'role':role,'active':active,'manager_sub':role!='admin'?manager:null,'scope_revision':widget.staff?['scope_revision']?.toString()??'0','scopes':[for(final e in scopes.entries)for(final d in e.value){'province':e.key,'district':d}]});
   if(mounted)Navigator.pop(context,true);
  }catch(e){if(mounted)setState(()=>error=e.toString());}
  finally{if(mounted)setState(()=>busy=false);}
 }
 Widget field(TextEditingController c,String label,{bool readOnly=false})=>Padding(padding:const EdgeInsets.only(bottom:12),child:TextField(controller:c,enabled:!busy,readOnly:readOnly,decoration:InputDecoration(labelText:label)));
 @override Widget build(BuildContext context)=>AlertDialog(
  title:Text(widget.staff==null?'Thêm nhân viên':'Sửa nhân viên'),
  content:SizedBox(width:560,child:SingleChildScrollView(child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
   const Text('Vai trò chỉ là Admin / Manager / Sales. Chức danh tự đặt, không giới hạn tầng. Cấp trên theo cây nhân sự; địa bàn phụ trách được giao riêng. Đăng nhập bằng email/OTP.'),const SizedBox(height:12),
   field(name,'Họ tên'),field(email,'Email nhân viên',readOnly:widget.staff==null&&subject.text.isNotEmpty),
   field(code,'Mã nhân viên'),field(phone,'Điện thoại'),field(jobTitle,'Chức danh tự đặt (Giám đốc, ASM, Sales...)'),
   DropdownButtonFormField<String>(initialValue:role,decoration:const InputDecoration(labelText:'Vai trò'),items:const [DropdownMenuItem(value:'admin',child:Text('Admin')),DropdownMenuItem(value:'manager',child:Text('Manager')),DropdownMenuItem(value:'sales',child:Text('Sales'))],onChanged:busy?null:(v)=>setState(()=>role=v??'sales')),
   if(role!='admin')DropdownButtonFormField<String>(initialValue:widget.managers.any((m)=>m['user_sub']==manager)?manager:'',decoration:const InputDecoration(labelText:'Quản lý trực tiếp'),items:[const DropdownMenuItem(value:'',child:Text('Chưa phân quản lý')),for(final m in widget.managers.where((m)=>m['user_sub']!=widget.staff?['user_sub']))DropdownMenuItem(value:m['user_sub'].toString(),child:Text(m['full_name'].toString()))],onChanged:busy?null:(v)=>setState(()=>manager=v==''?null:v)),
   SwitchListTile(title:const Text('Tài khoản hoạt động'),value:active,onChanged:busy?null:(v)=>setState(()=>active=v)),
   const Text('Địa bàn (không bắt buộc nếu phụ trách đội/chuỗi)',style:TextStyle(fontWeight:FontWeight.bold)),
   for(final p in widget.catalog.provinces)ExpansionTile(title:Text(p),subtitle:Text(scopes[p]?.contains('')==true?'Toàn tỉnh':(scopes[p]?.length??0).toString()+' huyện'),children:[
    CheckboxListTile(title:const Text('Toàn tỉnh'),value:scopes[p]?.contains('')??false,onChanged:busy?null:(v)=>setState(()=>scopes[p]=v==true?{''}:<String>{})),
    for(final d in widget.catalog.districts[p]!)CheckboxListTile(title:Text(d),value:scopes[p]?.contains('')==true||scopes[p]?.contains(d)==true,onChanged:busy||scopes[p]?.contains('')==true?null:(v)=>setState((){final set=scopes.putIfAbsent(p,()=>{});if(v==true){set.add(d);}else{set.remove(d);}})),
   ]),
  ]))),
  actions:[if(error!=null) SizedBox(width:560,child:Padding(padding:const EdgeInsets.only(bottom:8),child:Semantics(liveRegion:true,child:Text(error!,style:TextStyle(color:Theme.of(context).colorScheme.error))))),TextButton(onPressed:busy?null:()=>Navigator.pop(context),child:const Text('Hủy')),FilledButton(onPressed:busy?null:save,child:Text(busy?'Đang lưu...':'Lưu nhân viên'))]);
}
