import 'package:flutter/material.dart';
import 'api.dart';
import 'customers.dart';
import 'editor.dart';
import 'models.dart';
import 'theme.dart';
import 'session.dart';
import 'auth_gate.dart';
import 'staff_page.dart';
import 'offline_queue.dart';
import 'notifications.dart';
import 'field_work.dart';
import 'performance.dart';
import 'orders.dart';
import 'surveys.dart';
import 'catalog.dart';
import 'stock.dart';
import 'targets.dart';
import 'dart:async';

void main() => runApp(const SalesApp());

class SalesApp extends StatefulWidget {
  const SalesApp({super.key});
  @override
  State<SalesApp> createState() => _SalesAppState();
}

class _SalesAppState extends State<SalesApp> {
  @override
  void initState() {
    super.initState();
    SalesThemePreference.mode.addListener(_themeChanged);
    unawaited(SalesThemePreference.restore());
  }

  void _themeChanged() { if (mounted) setState(() {}); }

  @override
  void dispose() {
    SalesThemePreference.mode.removeListener(_themeChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Field Work',
      theme: SalesTheme.build(width: constraints.maxWidth),
      darkTheme: SalesTheme.build(width: constraints.maxWidth, brightness: Brightness.dark),
      themeMode: SalesThemePreference.mode.value,
      home: const AuthGate(),
    ),
  );
}

class SalesHome extends StatefulWidget {
  final SalesSession session;
  final Map<String,dynamic> me;
  final RegionCatalog catalog;
  final Future<void> Function() onLogout;
  const SalesHome({super.key,required this.session,required this.me,required this.catalog,required this.onLogout});
  @override
  State<SalesHome> createState() => _SalesHomeState();
}

class _SalesHomeState extends State<SalesHome> with WidgetsBindingObserver {
  final List<SalesRecord> _items = [];
  late final OfflineQueue _queue;
  late final FieldNotificationStore _notifications;
  Timer? _notificationsTimer;
  void _notificationChanged(){if(mounted)setState((){});}
  @override void didChangeAppLifecycleState(AppLifecycleState state){
    if(state==AppLifecycleState.resumed){
      unawaited(_queue.sync());unawaited(_notifications.refresh());
    }
  }
  int _lastPending=0;
  void _queueChanged(){if(!mounted)return;final count=_queue.pending.length;if(_lastPending>count)unawaited(_refresh());_lastPending=count;setState((){});}
  @override void dispose(){
    WidgetsBinding.instance.removeObserver(this);_notificationsTimer?.cancel();
    _notifications.removeListener(_notificationChanged);_notifications.dispose();
    _queue.removeListener(_queueChanged);_queue.dispose();super.dispose();
  }
  RegionCatalog get _catalog => widget.catalog;
  String get _apiUrl => salesOrigin;
  String get _accessToken => widget.session.cookie;
  String _province = '';
  bool _loading = false;
  int _selectedIndex = 0;
  String? _message;

  List<String> get _sections => ['Tổng quan', 'Khách hàng / Điểm bán', ...moduleKinds.map((e) => moduleLabels[e]!), 'Báo cáo tháng', 'Danh mục SKU', 'Tra tồn', 'Ra đơn'];
  List<IconData> get _icons => const [
    Icons.dashboard_outlined, Icons.storefront_outlined, Icons.store_outlined, Icons.flag_outlined,
    Icons.payments_outlined, Icons.route_outlined, Icons.handshake_outlined,
    Icons.policy_outlined, Icons.support_agent_outlined, Icons.analytics_outlined, Icons.inventory_2_outlined, Icons.inventory_outlined,Icons.shopping_cart_outlined,
  ];

  @override
  void initState() {
    super.initState();
    _queue=OfflineQueue(widget.session,widget.me['identity'].toString(),widget.me['scope_revision'].toString());
    WidgetsBinding.instance.addObserver(this);
    _queue.addListener(_queueChanged);unawaited(_queue.start());
    _notifications=FieldNotificationStore(widget.session,_queue);
    _notifications.addListener(_notificationChanged);
    unawaited(_notifications.start());
    _notificationsTimer=Timer.periodic(const Duration(seconds:60),
      (_)=>unawaited(_notifications.refresh()));
    _refresh();
  }

  void _notify(String message) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      final api = SalesApi(_apiUrl, _accessToken,identity:_queue.identity,revision:_queue.revision);
      bool cachedRead=false;
      final lists = await Future.wait(moduleKinds.map((kind) async {try{final items=await api.list(kind);await _queue.cache('records:$kind',items.map((r)=>r.toJson()).toList());return items;}catch(e){if(e is ApiFailure&&(e.status==401||e.status==403))rethrow;cachedRead=true;return (await _queue.cached('records:$kind')).map(SalesRecord.fromJson).toList();}}));
      if (!mounted) return;
      setState(() {
        _items..clear()..addAll(lists.expand((list) => list));
        _message = cachedRead?'Đang dùng dữ liệu đã lưu trên máy. Chưa cập nhật từ máy chủ.':null;
      });
      if(!cachedRead)_notify('Đã đồng bộ ${_items.length} bản ghi');
    } catch (error) {
      if (mounted) setState(() { _message = 'Lỗi đồng bộ: $error'; });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _profile() async {
    await showDialog<void>(context:context,builder:(c)=>AlertDialog(title:const Text('Hồ sơ nhân viên'),content:Text(widget.me['full_name'].toString()+'\n'+widget.me['email'].toString()+'\nVai trò: '+widget.me['role'].toString()+'\nĐịa bàn: '+_catalog.provinces.join(', ')),actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('Đóng')),FilledButton(onPressed:()async{
      Navigator.pop(c);
      if(_notifications.pushEnabled)await _notifications.disablePush();
      await widget.onLogout();
    },child:const Text('Đăng xuất'))]));
  }

  Future<void> _addRecord(String kind) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => RecordEditor(
      kind: kind, catalog: _catalog, onSave: (record) async {
        await _queue.enqueue('/api/v1/records',record);
        _notify('Đã lưu trên máy · chờ đồng bộ');
      },
    )));
  }

  Future<void> _editPlan(SalesRecord record)async{
    await Navigator.push(context,MaterialPageRoute(builder:(_)=>RecordEditor(kind:record.kind,catalog:_catalog,initial:record,onSave:(data)async{
      await _queue.enqueue('/api/v1/records/${record.id}',{'data':data['data'],'version':record.version},method:'PATCH');_notify('Đã lưu thay đổi trên máy · chờ đồng bộ');
    })));
  }
  String _money(num value) {
    final digits = value.round().toString();
    return '${digits.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.')} đ';
  }
  List<SalesRecord> _ofKind(String kind) => _items.where((e) => e.kind == kind && (_province.isEmpty || e.province == _province)).toList();

  Widget _coverageTable(List<SalesRecord> surveys) => SalesBrandCoverageTable(
    surveys: surveys,
    provinces: _catalog.provinces.where((p) => _province.isEmpty || p == _province).toList(),
  );

  Widget _overview() {
    final surveys = _ofKind('survey');
    final forecasts = _ofKind('forecast');
    final planned = forecasts.fold<double>(0, (sum, e) => sum + e.forecastTotal);
    final countTD = surveys.where((e) =>
      (e.data['brands'] is List && (e.data['brands'] as List).contains('Thành Đạt (đối thủ)'))).length;
    return ListView(padding: const EdgeInsets.all(18), children: [
      Text('Tổng quan thị trường', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 7),
      const Text('Quản lý khảo sát điểm bán và kế hoạch Sales 13 tỉnh miền Tây (địa giới cũ).'),
      const SizedBox(height: 16),
      SalesOverviewKpis(
        surveyed: surveys.length,
        planned: _money(planned),
        brandPresence: countTD,
        onTarget: () => setState(() => _selectedIndex = 3),
      ),
      const SizedBox(height: 18),
      Text('Phân hệ nghiệp vụ', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 10),
      SalesModuleGrid(
        sections: _sections,
        icons: _icons,
        onSelect: (index) => setState(() => _selectedIndex = index),
      ),
      const SizedBox(height: 20),
      _coverageTable(surveys),
      const SizedBox(height: 10),
      const Text('Chỉ tính nhãn hàng được ghi nhận hiện diện. Một điểm bán có thể có nhiều nhãn hàng.'),
      const SizedBox(height: 14),
    ]);
  }

  Widget _records(String kind,{bool readOnly=false}) {
    final items = _ofKind(kind);
    return Column(children: [
      Padding(padding: const EdgeInsets.fromLTRB(18, 16, 18, 6), child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(moduleLabels[kind]!, style: Theme.of(context).textTheme.headlineSmall),
          Text('${items.length} bản ghi', style: Theme.of(context).textTheme.bodySmall),
        ])),
        if(!readOnly)FilledButton.icon(onPressed: () => _addRecord(kind),
          icon: const Icon(Icons.add), label: const Text('Thêm mới')),
      ])),
      Expanded(child: items.isEmpty
        ? Center(child: Padding(padding: const EdgeInsets.all(30), child: Column(
          mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.inbox_outlined, size: 52, color: Colors.grey),
            const SizedBox(height: 12),
            const Text('Chưa có dữ liệu'),
            const SizedBox(height: 10),
            if(!readOnly)FilledButton.tonal(onPressed: () => _addRecord(kind),
              child: const Text('Nhập biểu mẫu đầu tiên')),
          ])))
        : ListView.builder(padding: const EdgeInsets.all(12), itemCount: items.length,
          itemBuilder: (context, index) {
            final record = items[index];
            String detail = record.subtitle;
            if (kind == 'forecast') detail = '${_money(record.forecastTotal)} · $detail';
            if (kind == 'survey') {
              detail = 'NPP: ${record.data['distributorCount'] ?? 0} · '
                  'Nhãn: ${record.data['brandCount'] ?? 0} · $detail';
            }
            return Card(child: ListTile(
              title: Text(record.title),
              subtitle: Text(detail.isEmpty ? (record.data['notes']?.toString() ?? 'Chưa có ghi chú') : detail),
              leading: Icon(_icons[_selectedIndex], color: SalesTheme.brand),
              trailing: ['target','forecast'].contains(kind)&&record.owner==_queue.identity?IconButton(tooltip:'Sửa kế hoạch',icon:const Icon(Icons.edit_outlined),onPressed:()=>_editPlan(record)):const Icon(Icons.cloud_done_outlined),
            ));
          })),
    ]);
  }

  CustomerService get _customerService=>CustomerService(_apiUrl,_accessToken,province:_province,identity:_queue.identity,revision:_queue.revision);

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.of(context).size.width < 850;
    return Scaffold(
      appBar: SalesHomeBar(
        loading:_loading,
        unreadCount:_notifications.unread,
        onNotifications:()=>Navigator.push(context,MaterialPageRoute(
          builder:(_)=>FieldNotificationInbox(store:_notifications))),
      ),
      bottomNavigationBar: narrow ? NavigationBar(
        selectedIndex: const [0,1,2,5,9].contains(_selectedIndex)?const [0,1,2,5,9].indexOf(_selectedIndex):0,
        onDestinationSelected:(i)=>setState(()=>_selectedIndex=const [0,1,2,5,9][i]),
        destinations:const [NavigationDestination(icon:Icon(Icons.dashboard_outlined),label:'Tổng quan'),NavigationDestination(icon:Icon(Icons.storefront_outlined),label:'Khách hàng'),NavigationDestination(icon:Icon(Icons.assignment_outlined),label:'Khảo sát'),NavigationDestination(icon:Icon(Icons.route_outlined),label:'Lịch trình'),NavigationDestination(icon:Icon(Icons.analytics_outlined),label:'Báo cáo')],
      ):null,
      drawer: SalesHomeDrawer(
        admin:widget.me['role']=='admin', loading:_loading, selectedIndex:_selectedIndex,
        sections:_sections, icons:_icons,
        onSection:(i)=>setState(()=>_selectedIndex=i),
        onRefresh:(){unawaited(_queue.sync());_refresh();},
        onStaff:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>StaffPage(session:widget.session))),
        onProfile:_profile,
        themeMode: SalesThemePreference.mode.value,
        onThemeModeChanged: (value) => unawaited(SalesThemePreference.select(value)),
      ),
      body: Row(children: [
        if (!narrow) NavigationRail(
          scrollable: true,
          extended: MediaQuery.of(context).size.width > 1200,
          selectedIndex: _selectedIndex,
          onDestinationSelected: (i) => setState(() => _selectedIndex = i),
          labelType: MediaQuery.of(context).size.width > 1200 ? NavigationRailLabelType.none
            : NavigationRailLabelType.selected,
          destinations: [for (var i = 0; i < _sections.length; i++)
            NavigationRailDestination(icon: Icon(_icons[i]), label: Text(_sections[i]))],
        ),
        Expanded(child: Column(children: [
          if(_selectedIndex!=3&&_selectedIndex!=10&&_selectedIndex!=11&&_selectedIndex!=12)Padding(padding:const EdgeInsets.all(12),child:DropdownButtonFormField<String>(initialValue:_province,isExpanded:true,decoration:const InputDecoration(labelText:'Địa bàn'),items:[const DropdownMenuItem(value:'',child:Text('Tất cả địa bàn của tôi')),for(final p in _catalog.provinces)DropdownMenuItem(value:p,child:Text(p))],onChanged:(p)=>setState(()=>_province=p??''))),
          if(_queue.pending.isNotEmpty||_queue.quarantined>0||_queue.error!=null) Material(color:Theme.of(context).colorScheme.primaryContainer,child:ListTile(leading:Icon(Icons.cloud_upload_outlined,color:Theme.of(context).colorScheme.onPrimaryContainer),title:Text('Chờ đồng bộ: ${_queue.pending.length} · Cách ly: ${_queue.quarantined}'),subtitle:Text(_queue.error??(_queue.syncing?'Đang đồng bộ':'Đã lưu trên máy')),trailing:IconButton(tooltip:'Đồng bộ ngay',onPressed:_queue.syncing?null:()=>unawaited(_queue.sync()),icon:const Icon(Icons.sync)),onTap:()=>showDialog<void>(context:context,builder:(c)=>AlertDialog(title:const Text('Hàng đợi đồng bộ'),content:SizedBox(width:420,child:ListView(shrinkWrap:true,children:[for(final r in _queue.pending)ListTile(title:Text((r['payload'] as Map)['name']?.toString()??(r['payload'] as Map)['customer_name']?.toString()??(r['payload'] as Map)['kind'].toString()),subtitle:Text(r['error']?.toString()??'Đã lưu máy · chờ đồng bộ'),
    trailing:r['status']=='blocked'?IconButton(
      tooltip:'Thử gửi lại mục bị lỗi',
      onPressed:()=>unawaited(_queue.retryBlocked(r['key'] as String)),
      icon:const Icon(Icons.refresh)):null)])),actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('Đóng'))])))),
          if (_message != null) Material(color: const Color(0xFFFBE8E7),
            child: Padding(padding: const EdgeInsets.all(10), child: Text(_message!))),
          Expanded(child: _selectedIndex == 0 ? _overview() : _selectedIndex == 1
              ? CustomerDirectoryPage(key:ValueKey('customers:${_queue.namespace}:$_province'),service:CustomerService(_apiUrl,_accessToken,province:_province,identity:_queue.identity,revision:_queue.revision),regions:_catalog,queue:_queue)
              : _selectedIndex==2?SurveyPage(key:ValueKey('survey:$_province'),queue:_queue,service:_customerService,regions:_catalog,admin:widget.me['role']=='admin',legacy:(_)=>Scaffold(appBar:AppBar(title:const Text('Biểu mẫu khảo sát cũ')),body:_records('survey',readOnly:true)))
              : _selectedIndex==3?TargetPage(key:ValueKey('target:${_queue.namespace}'),queue:_queue)
              : _selectedIndex==12?OrdersPage(key:ValueKey('orders:${_queue.namespace}'),queue:_queue,admin:widget.me['role']=='admin')
              : _selectedIndex==11?StockPage(key:ValueKey('stock:${_queue.namespace}'),queue:_queue,service:CustomerService(_apiUrl,_accessToken,identity:_queue.identity,revision:_queue.revision))
              : _selectedIndex==10?CatalogPage(queue:_queue,service:CustomerService(_apiUrl,_accessToken,identity:_queue.identity,revision:_queue.revision),admin:widget.me['role']=='admin')
              : _selectedIndex==9?PerformancePage(key:ValueKey('report:${_queue.namespace}'),queue:_queue,regions:_catalog,service:_customerService)
              : _selectedIndex==5?FieldWorkPage(key:ValueKey('field:$_province'),queue:_queue,regions:_catalog,service:_customerService):_records(moduleKinds[_selectedIndex - 2])),
        ])),
      ]),
    );
  }
}



const _surveyBrands = ['MGP', 'HH', 'Hoa Sen', 'Thành Đạt (đối thủ)', 'Bút Cầu', 'Bến Nghé'];

/// Compact KPI tiles; fixed row extents prevent giant single-column cards on phones.
class SalesOverviewKpis extends StatelessWidget {
  final int surveyed,brandPresence;
  final String planned;
  final VoidCallback onTarget;
  const SalesOverviewKpis({super.key, required this.surveyed, required this.planned,
    required this.brandPresence, required this.onTarget});

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, size) {
    final columns = size.maxWidth >= 900 ? 4 : size.maxWidth >= 285 ? 2 : 1;
    final items = <Widget>[
      const _KpiTile(label: 'Điểm bán đã khảo sát', value: '', icon: Icons.store_outlined),
      _KpiTile(label: 'Quản lý Target', value: 'Xem chỉ tiêu', icon: Icons.flag_outlined,
        onTap: onTarget),
      _KpiTile(label: 'Doanh thu dự kiến', value: planned, icon: Icons.payments_outlined),
      _KpiTile(label: 'Có nhãn Thành Đạt', value: '$brandPresence', icon: Icons.analytics_outlined),
    ];
    items[0] = _KpiTile(label: 'Điểm bán đã khảo sát', value: '$surveyed', icon: Icons.store_outlined);
    return GridView.count(
      crossAxisCount: columns,
      mainAxisSpacing: 8, crossAxisSpacing: 8,
      mainAxisExtent: 124,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: items,
    );
  });
}

class _KpiTile extends StatelessWidget {
  final String label,value;
  final IconData icon;
  final VoidCallback? onTap;
  const _KpiTile({required this.label,required this.value,required this.icon,this.onTap});
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: const EdgeInsets.all(11),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, color: colors.primary, size: 19),
            const SizedBox(height: 5),
            SizedBox(height: 29, width: double.infinity,
              child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft,
                child: Text(value, maxLines: 1, softWrap: false,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)))),
            const SizedBox(height: 4),
            Flexible(child: Text(label, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall)),
          ])),
      ),
    );
  }
}

/// Brand counts only. Distributor fields remain available in survey records.
class SalesBrandCoverageTable extends StatelessWidget {
  final List<SalesRecord> surveys;
  final List<String> provinces;
  const SalesBrandCoverageTable({super.key,required this.surveys,required this.provinces});

  @override
  Widget build(BuildContext context) {
    bool hasBrand(SalesRecord record,String brand) {
      final v=record.data['brands'];
      return v is List && v.contains(brand);
    }
    final rows=provinces.map((province) {
      final records=surveys.where((r)=>r.province==province).toList();
      final td=records.where((r)=>hasBrand(r,'Thành Đạt (đối thủ)')).length;
      return DataRow(cells:[
        DataCell(Text(province)),
        DataCell(Text('${records.length}')),
        for(final brand in _surveyBrands)
          DataCell(Text('${records.where((r)=>hasBrand(r,brand)).length}')),
        DataCell(Text('${records.where((r) =>
          (r.data['brands'] is List && (r.data['brands'] as List).isNotEmpty) ||
          (r.data['otherBrand']?.toString().trim().isNotEmpty ?? false)).length}')),
        DataCell(Text('${records.where((r) =>
          r.data['otherBrand']?.toString().trim().isNotEmpty ?? false).length}')),
        DataCell(Text(records.isEmpty ? '0%' : '${(td*100/records.length).toStringAsFixed(1)}%')),
      ]);
    }).toList();
    return Card(child:Padding(padding:const EdgeInsets.all(8),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Padding(padding:const EdgeInsets.all(10),
          child:Text('Hiện diện nhãn hàng theo 13 tỉnh/TP cũ',
            style:Theme.of(context).textTheme.titleMedium)),
        const Padding(padding:EdgeInsets.symmetric(horizontal:10),
          child:Text('Mỗi điểm bán tính một lần trong cột KH; các nhãn hàng có thể cùng xuất hiện tại một điểm bán.',
            style:TextStyle(fontSize:12))),
        SingleChildScrollView(scrollDirection:Axis.horizontal,
          child:DataTable(columnSpacing:22,columns:[
            const DataColumn(label:Text('Tỉnh/TP')),const DataColumn(label:Text('KH')),
            for(final brand in _surveyBrands)DataColumn(label:Text(brand)),
            const DataColumn(label:Text('≥1 nhãn')),
            const DataColumn(label:Text('Nhãn khác')),const DataColumn(label:Text('% Thành Đạt')),
          ],rows:rows)),
      ])));
  }
}


/// Responsive home shortcuts. All routes retain their original indices.
class SalesModuleGrid extends StatelessWidget {
  final List<String> sections;
  final List<IconData> icons;
  final ValueChanged<int> onSelect;
  const SalesModuleGrid({super.key, required this.sections, required this.icons,
    required this.onSelect});

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, size) {
    final columns = size.maxWidth >= 1000 ? 6
      : size.maxWidth >= 650 ? 4 : size.maxWidth >= 315 ? 3 : 2;
    return GridView.builder(
      primary: false,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: sections.length - 1,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns, mainAxisSpacing: 10, crossAxisSpacing: 10,
        mainAxisExtent: 110,
      ),
      itemBuilder: (context, slot) {
        final index = slot + 1;
        final label = index == 1 ? 'Khách hàng'
          : index == 9 ? 'Báo cáo' : sections[index];
        return Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: ValueKey('module-grid-$index'),
            onTap: () => onSelect(index),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 9),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(icons[index], color: Theme.of(context).colorScheme.primary, size: 28),
                const SizedBox(height: 9),
                Text(label, textAlign: TextAlign.center, maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        );
      },
    );
  });
}

class SalesHomeBar extends StatelessWidget implements PreferredSizeWidget {
  final bool loading;
  final int unreadCount;
  final VoidCallback onNotifications;
  const SalesHomeBar({super.key,required this.loading,required this.onNotifications,
    this.unreadCount=0});
  @override Size get preferredSize=>Size.fromHeight(kToolbarHeight+(loading?2:0));
  @override Widget build(BuildContext context)=>AppBar(
    centerTitle:false, titleSpacing:0,
    title:Row(mainAxisSize:MainAxisSize.min,children:[
      Image.asset('assets/fbmn-transparent-logo.webp',height:28,width:88,fit:BoxFit.contain,
        semanticLabel:'Futurebook'),
      const SizedBox(width:6),
      const Flexible(child:Text('Field Work',maxLines:1,overflow:TextOverflow.ellipsis,
        style:TextStyle(fontWeight:FontWeight.w700,fontSize:18))),
    ]),
    bottom:loading?const PreferredSize(preferredSize:Size.fromHeight(2),
      child:LinearProgressIndicator(minHeight:2)):null,
    actions:[IconButton(
      tooltip:'Thông báo',
      icon:unreadCount>0?Badge.count(
        count:unreadCount>99?99:unreadCount,
        backgroundColor:Theme.of(context).colorScheme.error,
        child:const Icon(Icons.notifications_none_outlined),
      ):const Icon(Icons.notifications_none_outlined),
      onPressed:onNotifications)],
  );
}

/// All secondary actions live in the same navigation drawer on every width.
class SalesHomeDrawer extends StatelessWidget {
  final bool admin,loading;
  final int selectedIndex;
  final List<String> sections;
  final List<IconData> icons;
  final ValueChanged<int> onSection;
  final VoidCallback onRefresh,onStaff,onProfile;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode>? onThemeModeChanged;
  const SalesHomeDrawer({super.key,required this.admin,required this.loading,
    required this.selectedIndex,required this.sections,required this.icons,
    required this.onSection,required this.onRefresh,required this.onStaff,required this.onProfile,
    this.themeMode = ThemeMode.light, this.onThemeModeChanged});
  @override Widget build(BuildContext context){
    void run(VoidCallback action){Navigator.of(context).pop();action();}
    Widget section(int i)=>ListTile(leading:Icon(icons[i]),title:Text(sections[i]),
      selected:selectedIndex==i,onTap:()=>run(()=>onSection(i)));
    return Drawer(child:SafeArea(child:ListView(padding:EdgeInsets.zero,children:[
      const ListTile(title:Text('PHÂN HỆ SALES')),
      if(admin)ListTile(leading:const Icon(Icons.manage_accounts_outlined),
        title:const Text('Quản lý nhân viên'),onTap:()=>run(onStaff)),
      ListTile(leading:const Icon(Icons.account_circle_outlined),
        title:const Text('Hồ sơ / Đăng xuất'),onTap:()=>run(onProfile)),
      if (onThemeModeChanged != null) SwitchListTile(
        secondary: Icon(themeMode == ThemeMode.dark ? Icons.dark_mode_outlined : Icons.light_mode_outlined),
        title: const Text('Chế độ tối'),
        value: themeMode == ThemeMode.dark,
        onChanged: (enabled) => onThemeModeChanged!(
          enabled ? ThemeMode.dark : ThemeMode.light)),
      ListTile(leading:const Icon(Icons.sync),title:const Text('Tải lại dữ liệu'),
        enabled:!loading,onTap:loading?null:()=>run(onRefresh)),
      const Divider(),
      for(final i in [10,11,12])section(i),
      const Divider(),
      for(var i=0;i<sections.length;i++)if(i!=10&&i!=11&&i!=12)section(i),
    ])));
  }
}
