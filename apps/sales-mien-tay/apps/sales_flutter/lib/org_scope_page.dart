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
      members = [], customers = [], preview = [], assignments = [];
  final search = TextEditingController();
  final territory = TextEditingController();
  final unitName = TextEditingController();
  final provinceName=TextEditingController(),districtName=TextEditingController();
  bool loading = true, busy = false, morePreview = false;
  String? error, selectedStaff, selectedCustomer;
  String kind = 'staff', action = 'edit', bindingKind = 'chain', assignmentKind = 'chain';
  String? key, bindingKey, assignmentKey;
  String unitKind = 'chain';

  static const kinds = {'staff':'Nhân viên / cấp dưới','territory':'Địa bàn',
    'team':'Đội nhóm','chain':'Chuỗi hệ thống','customer':'Khách riêng'};
  static const actions = {'view':'Xem','create':'Tạo','edit':'Sửa',
    'transfer':'Chuyển giao','approve':'Duyệt','target':'Giao Target',
    'actuals':'Doanh số','report':'Báo cáo','export':'Xuất',
    'media':'Ảnh','staff_manage':'Quản lý nhân viên'};

  @override
  void initState() { super.initState(); refresh(); }
  @override
  void dispose() { search.dispose(); territory.dispose(); unitName.dispose();provinceName.dispose();districtName.dispose(); super.dispose(); }

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
        members=maps(result['team_members']); customers=maps(found['items']); assignments=maps(result['assignments']);
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

  Future<void> createTerritory() async {
    final province=provinceName.text.trim(),district=districtName.text.trim();
    if(province.length<2||(!district.isEmpty&&district.length<2)){
      setState(()=>error='Nhập tên tỉnh và tên huyện (nếu có).');return;
    }
    setState((){busy=true;error=null;});
    try{
      await widget.session.post('/api/v1/admin/org/territories',{
        'level':district.isEmpty?'province':'district',
        'name':district.isEmpty?province:district,
        if(district.isNotEmpty)'province':province,
      });
      if(mounted){await refresh();ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content:Text('Đã cập nhật địa bàn. Mở lại sửa nhân viên để chọn địa bàn mới.')));}
    }catch(e){if(mounted)setState(()=>error=e.toString());}
    finally{if(mounted)setState(()=>busy=false);}
  }

  Future<void> setBusinessAssignment(String staffId,String scopeKind,String scopeKey,bool enabled) async {
    setState(() {busy=true;error=null;});
    try {
      await widget.session.post('/api/v1/admin/org/assignments',{
        'user_sub':staffId,'scope_kind':scopeKind,'scope_key':scopeKey,'active':enabled});
      await refresh();
    } catch(e) {if(mounted)setState(()=>error=e.toString());}
    finally {if(mounted)setState(()=>busy=false);}
  }

  List<Map<String,dynamic>> get treeRows {
    final ordered=<Map<String,dynamic>>[];
    final seen=<String>{};
    final ids={for(final p in staff)p['user_sub'].toString():p};
    void visit(Map<String,dynamic> person,int depth){
      final id=person['user_sub'].toString();
      if(!seen.add(id))return;
      ordered.add({...person,'_depth':depth});
      for(final member in staff.where((x)=>x['manager_sub']==id)) {visit(member,depth+1);}
    }
    for(final p in staff.where((x)=>x['manager_sub']==null||!ids.containsKey(x['manager_sub'].toString()))) {visit(p,0);}
    for(final p in staff) {visit(p,0);}
    return ordered;
  }

  Widget issueNotice() => error==null?const SizedBox.shrink():
    Padding(padding:const EdgeInsets.only(bottom:12),
      child:Text(error!,style:TextStyle(color:Theme.of(context).colorScheme.error)));

  Widget businessTarget() {
    final options=assignmentKind=='chain'?chains:customers;
    return dropdown('Hệ thống / khách được giao',assignmentKey,{
      for(final r in options)r['id'].toString():label(r)
    },(v)=>setState(()=>assignmentKey=v));
  }

  Widget section(String title, List<Widget> children)=>Padding(
    padding:const EdgeInsets.only(bottom:22),
    child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      Text(title,style:Theme.of(context).textTheme.titleMedium),
      const SizedBox(height:12),...children,
    ]),
  );

  @override Widget build(BuildContext context)=>DefaultTabController(
    length:3,
    child:Scaffold(
      appBar:AppBar(
        title:const Text('Cơ cấu & phân công'),
        actions:[IconButton(tooltip:'Tải lại',icon:const Icon(Icons.refresh),
          onPressed:busy||loading?null:refresh)],
        bottom:const TabBar(isScrollable:true,tabs:[
          Tab(icon:Icon(Icons.account_tree_outlined),text:'Cây nhân sự'),
          Tab(icon:Icon(Icons.assignment_ind_outlined),text:'Phân công kinh doanh'),
          Tab(icon:Icon(Icons.admin_panel_settings_outlined),text:'Quyền thao tác')
        ]),
      ),
      body:loading?const Center(child:CircularProgressIndicator()):
      TabBarView(children:[
        ListView(padding:const EdgeInsets.all(16),children:[
          issueNotice(),
          const Text('Ai là cấp trên của ai. Mỗi cấp trên tự thấy dữ liệu của toàn bộ cấp dưới; không cần tạo đội nhóm hoặc cấp quyền Xem từng người.'),
          const SizedBox(height:12),
          for(final m in treeRows)Card(child:ListTile(
            contentPadding:EdgeInsets.only(left:12.0+16.0*(m['_depth'] as int),right:12),
            leading:Icon((m['_depth'] as int)==0?Icons.account_circle_outlined:Icons.subdirectory_arrow_right),
            title:Text(label(m)+' · '+(m['job_title']?.toString().isNotEmpty==true?m['job_title'].toString():m['role'].toString())),
            subtitle:Text(m['employee_code'].toString()+' · '+(m['active']==true?'Hoạt động':'Đã khóa')+
              ' · Cấp dưới trực tiếp: '+staff.where((x)=>x['manager_sub']==m['user_sub']).length.toString()),
            isThreeLine:false,
          )),
          const SizedBox(height:12),
          const Text('Để đổi cấp trên hoặc chức danh: quay về Quản lý nhân viên và chạm vào hồ sơ cần sửa. Phạm vi phụ trách không làm thay đổi cây nhân sự.'),
          const SizedBox(height:8),
          OutlinedButton.icon(onPressed:()=>Navigator.pop(context),
            icon:const Icon(Icons.people_outline),label:const Text('Quay lại hồ sơ nhân viên')),
        ]),
        ListView(padding:const EdgeInsets.all(16),children:[
          issueNotice(),
          const Text('Mỗi nhân viên được giao riêng địa bàn, chuỗi và khách hàng, không phụ thuộc chức danh hay cấp trên.'),
          const SizedBox(height:16),
          personSelect(),
          if(selectedStaff!=null)...[
            const SizedBox(height:12),
            const Text('Địa bàn trực tiếp',style:TextStyle(fontWeight:FontWeight.w600)),
            for(final p in staff.where((p)=>p['user_sub']==selectedStaff))
              Text(((p['scopes'] as List?)??[]).isEmpty?'Chưa giao địa bàn':
                ((p['scopes'] as List).map((x)=>x['province'].toString()+
                  (x['district']==''?'':' / '+x['district'].toString())).join(' · '))),
            TextButton(onPressed:()=>Navigator.pop(context),
              child:const Text('Sửa địa bàn trong hồ sơ nhân viên')),
            const SizedBox(height:12),
            const Text('Chuỗi / khách giao trực tiếp',style:TextStyle(fontWeight:FontWeight.w600)),
            for(final a in assignments.where((a)=>a['user_sub']==selectedStaff&&a['active']==true))
              ListTile(dense:true,title:Text((a['scope_kind']=='chain'?'Chuỗi: ':'Khách: ')+
                (a['scope_kind']=='chain'
                  ?chains.where((x)=>x['id'].toString()==a['scope_key']).map(label).firstOrNull??'Chuỗi đã đổi tên'
                  :customers.where((x)=>x['id'].toString()==a['scope_key']).map(label).firstOrNull??'Khách đã giao')),
                trailing:IconButton(tooltip:'Ngừng phụ trách',icon:const Icon(Icons.remove_circle_outline),
                  onPressed:busy?null:()=>setBusinessAssignment(selectedStaff!,
                    a['scope_kind'].toString(),a['scope_key'].toString(),false))),
            const SizedBox(height:12),
            dropdown('Giao theo',assignmentKind,{'chain':'Chuỗi / hệ thống','customer':'Khách hàng riêng'},
              (v)=>setState((){assignmentKind=v??'chain';assignmentKey=null;})),
            const SizedBox(height:12),
            businessTarget(),
            const SizedBox(height:12),
            FilledButton.icon(icon:const Icon(Icons.add_task),
              label:const Text('Giao phạm vi kinh doanh'),
              onPressed:busy||assignmentKey==null?null:()=>setBusinessAssignment(
                selectedStaff!,assignmentKind,assignmentKey!,true)),
          ],
          const Divider(height:36),
          section('Danh mục chuỗi / hệ thống',[
            TextField(controller:unitName,enabled:!busy,
              decoration:const InputDecoration(labelText:'Tên chuỗi mới')),
            const SizedBox(height:10),
            OutlinedButton.icon(icon:const Icon(Icons.add),label:const Text('Tạo chuỗi'),
              onPressed:busy?null:(){unitKind='chain';createUnit();}),
          ]),
          section('Gắn khách hàng vào chuỗi',[
            TextField(controller:search,textInputAction:TextInputAction.search,
              onSubmitted:(_)=>refresh(),
              decoration:InputDecoration(labelText:'Tìm tên / mã khách',
                suffixIcon:IconButton(tooltip:'Tìm khách',onPressed:busy?null:refresh,icon:const Icon(Icons.search)))),
            const SizedBox(height:10),
            dropdown('Khách hàng',selectedCustomer,{
              for(final c in customers)c['id'].toString():label(c)
            },(v)=>setState(()=>selectedCustomer=v)),
            const SizedBox(height:10),
            dropdown('Chuỗi',bindingKey,{
              for(final c in chains)c['id'].toString():label(c)
            },(v)=>setState(()=>bindingKey=v)),
            const SizedBox(height:10),
            FilledButton.icon(icon:const Icon(Icons.link_outlined),label:const Text('Gắn khách vào chuỗi'),
              onPressed:busy||selectedCustomer==null||bindingKey==null?null:()=>binding(
                customerId:selectedCustomer!,scopeKind:'chain',scope:bindingKey!,active:true)),
            if(selectedCustomer!=null)
              for(final b in (customers.firstWhere((c)=>c['id']==selectedCustomer)['bindings'] as List? ?? []))
                if(b['active']==true&&b['scope_kind']=='chain')ListTile(
                  title:Text(chains.where((x)=>x['id'].toString()==b['scope_key']).map(label).firstOrNull??'Chuỗi'),
                  trailing:IconButton(tooltip:'Bỏ khỏi chuỗi',icon:const Icon(Icons.link_off_outlined),
                    onPressed:busy?null:()=>binding(customerId:selectedCustomer!,
                      scopeKind:'chain',scope:b['scope_key'].toString(),active:false))),
          ]),
          section('Mở rộng địa bàn',[
            TextField(controller:provinceName,decoration:const InputDecoration(labelText:'Tỉnh / thành phố')),
            const SizedBox(height:10),
            TextField(controller:districtName,decoration:const InputDecoration(labelText:'Huyện (để trống khi thêm tỉnh)')),
            const SizedBox(height:10),
            OutlinedButton.icon(icon:const Icon(Icons.add_location_alt_outlined),
              label:const Text('Lưu địa bàn'),onPressed:busy?null:createTerritory)
          ]),
        ]),
        ListView(padding:const EdgeInsets.all(16),children:[
          issueNotice(),
          const Text('Quyền Xem tự tính từ cây cấp trên, phạm vi trực tiếp và vùng giao nhau của hai Manager cùng cấp. Chỉ cấu hình các thao tác được phép thêm.'),
          const SizedBox(height:16),
          personSelect(),const SizedBox(height:12),
          dropdown('Đối tượng áp dụng',kind,{
            'staff':'Nhân viên / cấp dưới','territory':'Địa bàn',
            'chain':'Chuỗi hệ thống','customer':'Khách hàng riêng'
          },(v)=>setState((){kind=v??'staff';key=null;preview=[];})),
          const SizedBox(height:12),
          scopeControl(),
          const SizedBox(height:12),
          dropdown('Quyền thao tác',action,{
            for(final e in actions.entries)if(e.key!='view')e.key:e.value
          },(v)=>setState(()=>action=v??'edit')),
          const SizedBox(height:12),
          Wrap(spacing:8,runSpacing:8,children:[
            OutlinedButton.icon(icon:const Icon(Icons.visibility_outlined),
              label:const Text('Xem trước'),onPressed:busy?null:showPreview),
            FilledButton.icon(icon:const Icon(Icons.security),label:const Text('Cấp quyền'),
              onPressed:busy?null:()=>grant()),
          ]),
          for(final c in preview.take(10))Text('• '+label(c)),
          if(morePreview)const Text('Còn các khách khác trong phạm vi.'),
          const Divider(height:32),
          const Text('Quyền đã cấp (bấm nút trừ để thu hồi)',style:TextStyle(fontWeight:FontWeight.w600)),
          for(final g in grants.where((g)=>g['grantee_sub']==selectedStaff&&g['active']==true))
            ListTile(dense:true,
              title:Text((kinds[g['scope_kind']]??g['scope_kind']).toString()+
                ' · '+(actions[g['action']]??g['action']).toString()),
              subtitle:Text(g['scope_key'].toString()),
              trailing:IconButton(tooltip:'Thu hồi quyền',icon:const Icon(Icons.remove_circle_outline),
                onPressed:busy?null:()=>grant(active:false,
                  recipient:g['grantee_sub'].toString(),scopeKind:g['scope_kind'].toString(),
                  scope:g['scope_key'].toString(),permission:g['action'].toString()))),
        ]),
      ]),
    ),
  );
}
