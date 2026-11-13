import 'package:flutter/material.dart';
import 'session.dart';

// P0-K: administrator grants are explicit per action, never inferred from role or province.
class OrgScopePage extends StatefulWidget {
  final SalesSession session;
  const OrgScopePage({super.key, required this.session});
  @override
  State<OrgScopePage> createState() => _OrgScopePageState();
}

class _OrgScopePageState extends State<OrgScopePage> {
  List<Map<String, dynamic>> staff = [], grants = [], teams = [], chains = [],
      members = [], customers = [], preview = [];
  final search = TextEditingController();
  final territory = TextEditingController();
  final unitName = TextEditingController();
  bool loading = true, busy = false, morePreview = false;
  String? error, selectedStaff, selectedCustomer;
  String kind = 'staff', action = 'view', bindingKind = 'staff';
  String? key, bindingKey;
  String unitKind = 'team';

  static const kinds = {'staff':'Nhân viên / cấp dưới','territory':'Địa bàn',
    'team':'Đội nhóm','chain':'Chuỗi hệ thống','customer':'Khách riêng'};
  static const actions = {'view':'Xem','create':'Tạo','edit':'Sửa',
    'transfer':'Chuyển giao','approve':'Duyệt','target':'Giao Target',
    'actuals':'Doanh số','report':'Báo cáo','export':'Xuất',
    'media':'Ảnh','staff_manage':'Quản lý nhân viên'};
  static const bindingKinds = {'staff':'Nhân viên','territory':'Địa bàn',
    'team':'Đội nhóm','chain':'Chuỗi'};

  @override
  void initState() { super.initState(); refresh(); }
  @override
  void dispose() { search.dispose(); territory.dispose(); unitName.dispose(); super.dispose(); }

  List<Map<String,dynamic>> maps(dynamic raw) =>
      (raw as List? ?? []).map((v)=>Map<String,dynamic>.from(v as Map)).toList();
  String label(Map<String,dynamic> row) =>
      (row['full_name']??row['name']??'').toString();
  Future<void> refresh() async {
    if(mounted)setState(()=>loading=true);
    try {
      final result = await widget.session.get('/api/v1/admin/org');
      final found = await widget.session.get('/api/v1/admin/org/customers?q='+
          Uri.encodeQueryComponent(search.text.trim()));
      if(!mounted)return;
      setState(() {
        staff=maps(result['staff']); grants=maps(result['grants']);
        teams=maps(result['teams']); chains=maps(result['chains']);
        members=maps(result['team_members']); customers=maps(found['items']);
        if(!staff.any((s)=>s['user_sub']==selectedStaff&&s['active']==true&&s['role']!='admin')){
          selectedStaff=null;
        }
        if(!customers.any((c)=>c['id']==selectedCustomer))selectedCustomer=null;
        error=null;
      });
    } catch(e) {
      if(mounted)setState(()=>error=e.toString());
    } finally { if(mounted)setState(()=>loading=false); }
  }

  List<Map<String,dynamic>> get recipients =>staff.where(
      (s)=>s['role']!='admin'&&s['active']==true).toList();
  List<Map<String,dynamic>> get availableKeys {
    if(kind=='staff')return recipients;
    if(kind=='chain')return chains;
    if(kind=='team')return teams;
    if(kind=='customer')return customers;
    return [];
  }
  String rowKey(Map<String,dynamic> row)=>kind=='staff'
      ?row['user_sub'].toString():row['id'].toString();
  String? scopeKey() => kind=='territory'
      ?(territory.text.trim().isEmpty?null:territory.text.trim()):key;
  String? assignedKey() => bindingKind=='territory'
      ?(territory.text.trim().isEmpty?null:territory.text.trim()):bindingKey;
  Widget dropdown(String title,String? value,Map<String,String> choices,
      ValueChanged<String?> changed) {
    final safe=choices.containsKey(value)?value:null;
    return DropdownButtonFormField<String>(
      key:ValueKey(title+':'+(safe??'')),initialValue:safe,
      isExpanded:true,decoration:InputDecoration(labelText:title),
      items:[for(final e in choices.entries)DropdownMenuItem(
          value:e.key,child:Text(e.value,overflow:TextOverflow.ellipsis))],
      onChanged:busy?null:changed,
    );
  }
  Widget personSelect() => dropdown('Cấp quyền cho',selectedStaff,{
    for(final s in recipients)s['user_sub'].toString():
        label(s)+' ('+s['employee_code'].toString()+')'
  },(v)=>setState(()=>selectedStaff=v));

  Widget scopeControl({bool forBinding=false}){
    final type=forBinding?bindingKind:kind;
    if(type=='territory')return TextField(
      controller:territory,enabled:!busy,decoration:const InputDecoration(
        labelText:'Địa bàn',hintText:'Tên tỉnh| hoặc Tên tỉnh|Tên huyện',
        helperText:'Phải trùng địa bàn của khách / nhân viên được giao',
      ));
    final data=type=='staff'?recipients:type=='team'?teams:
        type=='chain'?chains:customers;
    final values={for(final v in data)(type=='staff'
        ?v['user_sub']:v['id']).toString():type=='staff'
        ?label(v):type=='customer'
        ?label(v)+' · '+(v['province']??'').toString():label(v)};
    final current=forBinding?bindingKey:key;
    return dropdown('Đối tượng',current,values,(v)=>setState(() {
      if(forBinding){bindingKey=v;}else{key=v;preview=[];}
    }));
  }

  Future<void> showPreview() async {
    final scope=scopeKey();
    if(scope==null){setState(()=>error='Chọn phạm vi cần xem trước.');return;}
    setState((){busy=true;error=null;});
    try{
      final uri=Uri(queryParameters:{'scope_kind':kind,'scope_key':scope});
      final result=await widget.session.get('/api/v1/admin/org/preview?'+uri.query);
      if(mounted)setState((){preview=maps(result['items']);morePreview=result['has_more']==true;});
    }catch(e){if(mounted)setState(()=>error=e.toString());}
    finally{if(mounted)setState(()=>busy=false);}
  }

  Future<void> grant({bool active=true,String? recipient,String? scopeKind,
      String? scope,String? permission}) async {
    final grantee=recipient??selectedStaff,k=scopeKind??kind,
        value=scope??scopeKey(),act=permission??action;
    if(grantee==null||value==null){setState(()=>error='Chọn người và phạm vi.');return;}
    setState((){busy=true;error=null;});
    try{
      await widget.session.post('/api/v1/admin/org/grants',{
        'grantee_sub':grantee,'scope_kind':k,'scope_key':value,
        'action':act,'active':active});
      await refresh();
    }catch(e){if(mounted)setState(()=>error=e.toString());}
    finally{if(mounted)setState(()=>busy=false);}
  }

  Future<void> binding({required String customerId,required String scopeKind,
      required String scope,required bool active}) async {
    setState((){busy=true;error=null;});
    try {
      await widget.session.post('/api/v1/admin/org/bindings',{
        'customer_id':customerId,'scope_kind':scopeKind,
        'scope_key':scope,'active':active});
      await refresh();
    }catch(e){if(mounted)setState(()=>error=e.toString());}
    finally{if(mounted)setState(()=>busy=false);}
  }
  Future<void> createUnit() async {
    if(unitName.text.trim().length<2){setState(()=>error='Nhập tên đội hoặc chuỗi.');return;}
    setState((){busy=true;error=null;});
    try{
      await widget.session.post('/api/v1/admin/org/units',
          {'kind':unitKind,'name':unitName.text.trim()});
      unitName.clear();
      await refresh();
    }catch(e){if(mounted)setState(()=>error=e.toString());}
    finally{if(mounted)setState(()=>busy=false);}
  }

  Future<void> teamMember(Map<String,dynamic> team,String userId,bool active) async {
    setState((){busy=true;error=null;});
    try {
      await widget.session.post('/api/v1/admin/org/members',{
        'team_id':team['id'],'user_sub':userId,'active':active});
      await refresh();
    }catch(e){if(mounted)setState(()=>error=e.toString());}
    finally{if(mounted)setState(()=>busy=false);}
  }

  Widget section(String title, List<Widget> children)=>Padding(
    padding:const EdgeInsets.only(bottom:22),
    child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      Text(title,style:Theme.of(context).textTheme.titleMedium),
      const SizedBox(height:12),...children,
    ]),
  );

  @override Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('Phân quyền tổ chức'),
      actions:[IconButton(icon:const Icon(Icons.refresh),tooltip:'Tải lại',
          onPressed:busy||loading?null:refresh)]),
    body:loading?const Center(child:CircularProgressIndicator()):SafeArea(
      child:ListView(padding:const EdgeInsets.all(16),children:[
        if(error!=null)Padding(padding:const EdgeInsets.only(bottom:16),
          child:Text(error!,style:TextStyle(color:Theme.of(context).colorScheme.error))),
        section('1. Cấp quyền riêng theo nghiệp vụ',[
          personSelect(),const SizedBox(height:12),
          dropdown('Loại phạm vi',kind,kinds,(v)=>setState((){
            kind=v??'staff';key=null;preview=[];
          })),const SizedBox(height:12),
          scopeControl(),const SizedBox(height:12),
          dropdown('Quyền',action,actions,(v)=>setState(()=>action=v??'view')),
          const SizedBox(height:12),
          Wrap(spacing:8,runSpacing:8,children:[
            OutlinedButton.icon(onPressed:busy?null:showPreview,
              icon:const Icon(Icons.visibility_outlined),label:const Text('Xem trước phạm vi')),
            FilledButton.icon(onPressed:busy?null:()=>grant(),
              icon:const Icon(Icons.security),label:const Text('Cấp quyền')),
          ]),
          if(preview.isNotEmpty||morePreview)Padding(
            padding:const EdgeInsets.only(top:12),child:Column(
            crossAxisAlignment:CrossAxisAlignment.stretch,children:[
              Text('Khách trong phạm vi: '+preview.length.toString()+
                (morePreview?' (còn dữ liệu)':'')),
              for(final c in preview.take(10))Text('• '+c['name'].toString()+
                ' · '+c['province'].toString()),
            ])),
          const SizedBox(height:8),
          const Text('Xem không đồng nghĩa với sửa. Mỗi quyền được cấp và thu hồi độc lập.'),
          for(final g in grants.where((g)=>g['grantee_sub']==selectedStaff&&g['active']==true))
            ListTile(contentPadding:EdgeInsets.zero,dense:true,
              title:Text((kinds[g['scope_kind']]??g['scope_kind']).toString()+
                ' · '+(actions[g['action']]??g['action']).toString()),
              subtitle:Text(g['scope_key'].toString()),
              trailing:IconButton(tooltip:'Thu hồi quyền',icon:const Icon(Icons.remove_circle_outline),
                onPressed:busy?null:()=>grant(active:false,
                  recipient:g['grantee_sub'].toString(),
                  scopeKind:g['scope_kind'].toString(),
                  scope:g['scope_key'].toString(),permission:g['action'].toString()))),
        ]),
        section('2. Giao trách nhiệm khách hàng',[
          TextField(controller:search,textInputAction:TextInputAction.search,
            onSubmitted:(_)=>refresh(),
            decoration:InputDecoration(labelText:'Tìm tên / mã khách',
              suffixIcon:IconButton(tooltip:'Tìm khách',
                onPressed:busy?null:refresh,icon:const Icon(Icons.search)))),
          const SizedBox(height:12),
          dropdown('Khách hàng',selectedCustomer,{
            for(final c in customers)c['id'].toString():
              label(c)+' · '+(c['province']??'').toString()
          },(v)=>setState(()=>selectedCustomer=v)),
          const SizedBox(height:12),
          dropdown('Gắn vào',bindingKind,bindingKinds,(v)=>setState((){
            bindingKind=v??'staff';bindingKey=null;
          })),const SizedBox(height:12),scopeControl(forBinding:true),
          const SizedBox(height:12),
          FilledButton.icon(onPressed:busy?null:(){
            final value=assignedKey();
            if(selectedCustomer==null||value==null){
              setState(()=>error='Chọn khách và nơi nhận trách nhiệm.');return;
            }
            binding(customerId:selectedCustomer!,scopeKind:bindingKind,
              scope:value,active:true);
          },icon:const Icon(Icons.assignment_turned_in_outlined),label:const Text('Giao khách')),
          for(final b in (customers.where((c)=>c['id']==selectedCustomer).isNotEmpty
            ?(customers.firstWhere((c)=>c['id']==selectedCustomer)['bindings'] as List? ?? [])
            :[]))
            if(b['active']==true)ListTile(
              title:Text((bindingKinds[b['scope_kind']]??b['scope_kind']).toString()),
              subtitle:Text(b['scope_key'].toString()),dense:true,
              trailing:IconButton(tooltip:'Thu hồi phân công',
                icon:const Icon(Icons.remove_circle_outline),
                onPressed:busy?null:()=>binding(customerId:selectedCustomer!,
                  scopeKind:b['scope_kind'].toString(),
                  scope:b['scope_key'].toString(),active:false))),
        ]),
        section('3. Đội nhóm và chuỗi',[
          dropdown('Tạo loại',unitKind,{'team':'Đội nhóm','chain':'Chuỗi hệ thống'},
            (v)=>setState(()=>unitKind=v??'team')),
          const SizedBox(height:12),
          TextField(controller:unitName,enabled:!busy,
            decoration:const InputDecoration(labelText:'Tên đội / chuỗi')),
          const SizedBox(height:12),
          OutlinedButton.icon(onPressed:busy?null:createUnit,
            icon:const Icon(Icons.add),label:const Text('Tạo')),
          for(final t in teams)ExpansionTile(title:Text(label(t)),
            subtitle:const Text('Thành viên đội'),
            children:[for(final m in recipients)CheckboxListTile(
              dense:true,title:Text(label(m)),
              value:members.any((x)=>x['team_id']==t['id']&&x['user_sub']==m['user_sub']),
              onChanged:busy?null:(v)=>teamMember(t,m['user_sub'].toString(),v==true))]),
          for(final c in chains)ListTile(dense:true,
            leading:const Icon(Icons.account_tree_outlined),title:Text(label(c))),
        ]),
      ]),
    ),
  );
}
