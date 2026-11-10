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
import 'dart:async';

void main() => runApp(const SalesApp());

class SalesApp extends StatelessWidget {
  const SalesApp({super.key});
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Filed Work',
    theme: SalesTheme.build(width: constraints.maxWidth),
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

class _SalesHomeState extends State<SalesHome> {
  final List<SalesRecord> _items = [];
  late final OfflineQueue _queue;
  int _lastPending=0;
  void _queueChanged(){if(!mounted)return;final count=_queue.pending.length;if(_lastPending>count)unawaited(_refresh());_lastPending=count;setState((){});}
  @override void dispose(){_queue.removeListener(_queueChanged);_queue.dispose();super.dispose();}
  RegionCatalog get _catalog => widget.catalog;
  String get _apiUrl => salesOrigin;
  String get _accessToken => widget.session.cookie;
  String _province = '';
  bool _loading = false;
  int _selectedIndex = 0;
  String? _message;

  List<String> get _sections => ['Tổng quan', 'Khách hàng / Điểm bán', ...moduleKinds.map((e) => moduleLabels[e]!)];
  List<IconData> get _icons => const [
    Icons.dashboard_outlined, Icons.storefront_outlined, Icons.store_outlined, Icons.flag_outlined,
    Icons.payments_outlined, Icons.route_outlined, Icons.handshake_outlined,
    Icons.policy_outlined, Icons.support_agent_outlined,
  ];

  @override
  void initState() {
    super.initState();
    _queue=OfflineQueue(widget.session,widget.me['identity'].toString(),widget.me['scope_revision'].toString());
    _queue.addListener(_queueChanged);unawaited(_queue.start());
    _refresh();
  }

  void _notify(String message) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      final api = SalesApi(_apiUrl, _accessToken,identity:_queue.identity,revision:_queue.revision);
      final lists = await Future.wait(moduleKinds.map((kind) async {try{final items=await api.list(kind);await _queue.cache('records:$kind',items.map((r)=>r.toJson()).toList());return items;}catch(e){if(e is ApiFailure&&(e.status==401||e.status==403))rethrow;return (await _queue.cached('records:$kind')).map(SalesRecord.fromJson).toList();}}));
      if (!mounted) return;
      setState(() {
        _items..clear()..addAll(lists.expand((list) => list));
        _message = null;
      });
      _notify('Đã đồng bộ ${_items.length} bản ghi');
    } catch (error) {
      if (mounted) setState(() { _message = 'Lỗi đồng bộ: $error'; });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _profile() async {
    await showDialog<void>(context:context,builder:(c)=>AlertDialog(title:const Text('Hồ sơ nhân viên'),content:Text(widget.me['full_name'].toString()+'\n'+widget.me['email'].toString()+'\nVai trò: '+widget.me['role'].toString()+'\nĐịa bàn: '+_catalog.provinces.join(', ')),actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('Đóng')),FilledButton(onPressed:(){Navigator.pop(c);widget.onLogout();},child:const Text('Đăng xuất'))]));
  }

  Future<void> _addRecord(String kind) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => RecordEditor(
      kind: kind, catalog: _catalog, onSave: (record) async {
        await _queue.enqueue('/api/v1/records',record);
        _notify('Đã lưu trên máy · chờ đồng bộ');
      },
    )));
  }

  String _money(num value) {
    final digits = value.round().toString();
    return '${digits.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.')} đ';
  }
  List<SalesRecord> _ofKind(String kind) => _items.where((e) => e.kind == kind && (_province.isEmpty || e.province == _province)).toList();

  Widget _stat(String label, String value, IconData icon) => Card(
    child: Padding(padding: const EdgeInsets.all(18), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: SalesTheme.brand),
        const SizedBox(height: 14),
        Text(value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ])),
  );

  Widget _coverageTable(List<SalesRecord> surveys) {
    final provinces = _catalog.provinces.where((p)=>_province.isEmpty||p==_province).toList();
    bool has(SalesRecord r, String property, String label) {
      final value = r.data[property];
      return value is List && value.contains(label);
    }
    int count(List<SalesRecord> rows, String key, String value) =>
      rows.where((r) => has(r, key, value)).length;
    final rows = provinces.map((province) {
      final records = surveys.where((r) => r.province == province).toList();
      final td = count(records, 'brands', 'Thành Đạt (đối thủ)');
      int distributors(SalesRecord r) =>
        (r.data['distributors'] is List ? (r.data['distributors'] as List).length : 0)
        + ((r.data['otherDistributor']?.toString().trim().isNotEmpty ?? false) ? 1 : 0);
      return DataRow(cells: [
        DataCell(Text(province)), DataCell(Text('${records.length}')),
        DataCell(Text('${count(records, 'distributors', 'Thanh Đạt')}')),
        DataCell(Text('${count(records, 'distributors', 'Liên Hiệp')}')),
        DataCell(Text('${count(records, 'distributors', 'Hồng Ân')}')),
        DataCell(Text('${records.where((r) => distributors(r) >= 2).length}')),
        for (final brand in const ['MGP', 'HH', 'Hoa Sen', 'Thành Đạt (đối thủ)', 'Bút Cầu', 'Bến Nghé'])
          DataCell(Text('${count(records, 'brands', brand)}')),
        DataCell(Text('${records.where((r) => (r.data['brands'] is List
          && (r.data['brands'] as List).isNotEmpty) ||
          (r.data['otherBrand']?.toString().trim().isNotEmpty ?? false)).length}')),
        DataCell(Text('${records.where((r) => (r.data['otherDistributor']?.toString().trim().isNotEmpty ?? false)).length}')),
        DataCell(Text('${records.where((r) => (r.data['otherBrand']?.toString().trim().isNotEmpty ?? false)).length}')),
        DataCell(Text(records.isEmpty ? '0%' : '${(td * 100 / records.length).toStringAsFixed(1)}%')),
      ]);
    }).toList();
    return Card(child: Padding(padding: const EdgeInsets.all(8), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.all(10), child: Text('Hiện diện theo 13 tỉnh/TP cũ',
        style: Theme.of(context).textTheme.titleMedium)),
      const Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text(
        'Mỗi điểm bán tính một lần trong cột khảo sát; NPP/nhãn có thể trùng trên cùng khách.',
        style: TextStyle(fontSize: 12))),
      SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(
        columnSpacing: 22,
        columns: const [
          DataColumn(label: Text('Tỉnh/TP')), DataColumn(label: Text('KH')),
          DataColumn(label: Text('NPP Thanh Đạt')), DataColumn(label: Text('Liên Hiệp')),
          DataColumn(label: Text('Hồng Ân')), DataColumn(label: Text('≥2 NPP')),
          DataColumn(label: Text('MGP')), DataColumn(label: Text('HH')),
          DataColumn(label: Text('Hoa Sen')), DataColumn(label: Text('Thành Đạt (đối thủ)')),
          DataColumn(label: Text('Bút Cầu')), DataColumn(label: Text('Bến Nghé')),
          DataColumn(label: Text('≥1 nhãn')), DataColumn(label: Text('NPP khác')),
          DataColumn(label: Text('Nhãn khác')), DataColumn(label: Text('% Thành Đạt')),
        ], rows: rows)),
    ])));
  }

  Widget _overview() {
    final surveys = _ofKind('survey');
    final targets = _ofKind('target');
    final forecasts = _ofKind('forecast');
    final planned = forecasts.fold<double>(0, (sum, e) => sum + e.forecastTotal);
    final target = targets.fold<double>(0, (sum, e) => sum +
        ((e.data['monthlyTarget'] is num) ? (e.data['monthlyTarget'] as num).toDouble() : 0));
    final countTD = surveys.where((e) =>
      (e.data['brands'] is List && (e.data['brands'] as List).contains('Thành Đạt (đối thủ)'))).length;
    return ListView(padding: const EdgeInsets.all(18), children: [
      Text('Tổng quan thị trường', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 7),
      const Text('Quản lý khảo sát điểm bán và kế hoạch Sales 13 tỉnh miền Tây (địa giới cũ).'),
      const SizedBox(height: 16),
      LayoutBuilder(builder: (context, constraints) {
        final columns = constraints.maxWidth > 900 ? 4 : constraints.maxWidth > 550 ? 2 : 1;
        return GridView.count(crossAxisCount: columns, childAspectRatio: columns == 1 ? 2.15 : 1.55,
          mainAxisSpacing: 8, crossAxisSpacing: 8, shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(), children: [
            _stat('Điểm bán đã khảo sát', '${surveys.length}', Icons.store_outlined),
            _stat('Chỉ tiêu đã đăng ký', _money(target), Icons.flag_outlined),
            _stat('Doanh thu dự kiến', _money(planned), Icons.payments_outlined),
            _stat('Điểm bán có nhãn Thành Đạt', '$countTD', Icons.analytics_outlined),
          ]);
      }),
      const SizedBox(height: 12),
      Card(child: ListTile(leading: const Icon(Icons.storefront_outlined),
        title: const Text('Danh bạ khách hàng / Điểm bán'),
        subtitle: const Text('Ảnh • vị trí GPS • check-in • lịch sử'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => setState(() => _selectedIndex = 1))),
      const SizedBox(height: 20),
      _coverageTable(surveys),
      const SizedBox(height: 22),
      Text('Phân hệ nghiệp vụ', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      for (var i = 0; i < moduleKinds.length; i++) Card(
        child: ListTile(
          leading: Icon(_icons[i+2], color: SalesTheme.brand),
          title: Text(moduleLabels[moduleKinds[i]]!),
          subtitle: Text('${_ofKind(moduleKinds[i]).length} bản ghi'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => setState(() => _selectedIndex = i + 2),
        ),
      ),
      const SizedBox(height: 10),
      const Text('Chỉ tính nhãn/NPP được đánh dấu hiện diện. Một điểm bán có thể mang nhiều NPP và nhãn.'),
      const SizedBox(height: 14),
    ]);
  }

  Widget _records(String kind) {
    final items = _ofKind(kind);
    return Column(children: [
      Padding(padding: const EdgeInsets.fromLTRB(18, 16, 18, 6), child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(moduleLabels[kind]!, style: Theme.of(context).textTheme.headlineSmall),
          Text('${items.length} bản ghi', style: Theme.of(context).textTheme.bodySmall),
        ])),
        FilledButton.icon(onPressed: () => _addRecord(kind),
          icon: const Icon(Icons.add), label: const Text('Thêm mới')),
      ])),
      Expanded(child: items.isEmpty
        ? Center(child: Padding(padding: const EdgeInsets.all(30), child: Column(
          mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.inbox_outlined, size: 52, color: Colors.grey),
            const SizedBox(height: 12),
            const Text('Chưa có dữ liệu'),
            const SizedBox(height: 10),
            FilledButton.tonal(onPressed: () => _addRecord(kind),
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
              trailing: const Icon(Icons.cloud_done_outlined),
            ));
          })),
    ]);
  }

  Widget _navItem(int i) => ListTile(
    leading: Icon(_icons[i]), title: Text(_sections[i]),
    selected: _selectedIndex == i,
    onTap: () { Navigator.maybePop(context); setState(() => _selectedIndex = i); },
  );

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.of(context).size.width < 850;
    return Scaffold(
      appBar: AppBar(
        title: Row(mainAxisSize:MainAxisSize.min,children:[Image.asset('assets/fbmn-transparent-logo.webp',height:28),const SizedBox(width:8),const Text('Filed Work',style:TextStyle(fontWeight:FontWeight.w700))]),
        actions: [
          if (_loading) const Padding(padding: EdgeInsets.all(16),
            child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))),
          IconButton(onPressed: _loading ? null : (){unawaited(_queue.sync());_refresh();},
            tooltip: 'Tải lại dữ liệu', icon: const Icon(Icons.sync)),
          if(widget.me['role']=='admin') IconButton(tooltip:'Quản lý nhân viên',icon:const Icon(Icons.manage_accounts_outlined),onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>StaffPage(session:widget.session)))),
          IconButton(onPressed: _profile,tooltip:'Hồ sơ nhân viên',icon:const Icon(Icons.account_circle_outlined)),
        ],
      ),
      bottomNavigationBar: narrow ? NavigationBar(
        selectedIndex: const [0,1,2,5].contains(_selectedIndex)?const [0,1,2,5].indexOf(_selectedIndex):4,
        onDestinationSelected:(i){if(i==4){_profile();}else{setState(()=>_selectedIndex=const [0,1,2,5][i]);}},
        destinations:const [NavigationDestination(icon:Icon(Icons.dashboard_outlined),label:'Tổng quan'),NavigationDestination(icon:Icon(Icons.storefront_outlined),label:'Khách hàng'),NavigationDestination(icon:Icon(Icons.assignment_outlined),label:'Khảo sát'),NavigationDestination(icon:Icon(Icons.route_outlined),label:'Lịch trình'),NavigationDestination(icon:Icon(Icons.person_outline),label:'Tài khoản')],
      ):null,
      drawer: narrow ? Drawer(child: SafeArea(child: ListView(children: [
        const ListTile(title: Text('PHÂN HỆ SALES')),
        for (var i = 0; i < _sections.length; i++) _navItem(i),
      ]))) : null,
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
          Padding(padding:const EdgeInsets.all(12),child:DropdownButtonFormField<String>(initialValue:_province,isExpanded:true,decoration:const InputDecoration(labelText:'Địa bàn'),items:[const DropdownMenuItem(value:'',child:Text('Tất cả địa bàn của tôi')),for(final p in _catalog.provinces)DropdownMenuItem(value:p,child:Text(p))],onChanged:(p)=>setState(()=>_province=p??''))),
          if(_queue.pending.isNotEmpty||_queue.quarantined>0||_queue.error!=null) Material(color:SalesTheme.tableHeader,child:ListTile(leading:const Icon(Icons.cloud_upload_outlined,color:SalesTheme.brand),title:Text('Chờ đồng bộ: ${_queue.pending.length} · Cách ly: ${_queue.quarantined}'),subtitle:Text(_queue.error??(_queue.syncing?'Đang đồng bộ':'Đã lưu trên máy')),trailing:IconButton(tooltip:'Đồng bộ ngay',onPressed:_queue.syncing?null:()=>unawaited(_queue.sync()),icon:const Icon(Icons.sync)),onTap:()=>showDialog<void>(context:context,builder:(c)=>AlertDialog(title:const Text('Hàng đợi đồng bộ'),content:SizedBox(width:420,child:ListView(shrinkWrap:true,children:[for(final r in _queue.pending)ListTile(title:Text((r['payload'] as Map)['name']?.toString()??(r['payload'] as Map)['customer_name']?.toString()??(r['payload'] as Map)['kind'].toString()),subtitle:Text(r['error']?.toString()??'Đã lưu máy · chờ đồng bộ'))])),actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('Đóng'))])))),
          if (_message != null) Material(color: const Color(0xFFFBE8E7),
            child: Padding(padding: const EdgeInsets.all(10), child: Text(_message!))),
          Expanded(child: _selectedIndex == 0 ? _overview() : _selectedIndex == 1
              ? CustomerDirectoryPage(key:ValueKey('$_province:${_queue.pending.length}'),service:CustomerService(_apiUrl,_accessToken,province:_province,identity:_queue.identity,revision:_queue.revision),regions:_catalog,queue:_queue)
              : _records(moduleKinds[_selectedIndex - 2])),
        ])),
      ]),
    );
  }
}