import 'package:flutter/material.dart';
import 'api.dart';
import 'editor.dart';
import 'models.dart';
import 'theme.dart';

void main() => runApp(const SalesApp());

class SalesApp extends StatelessWidget {
  const SalesApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Sales Miền Tây',
    theme: SalesTheme.build(),
    home: const SalesHome(),
  );
}

class SalesHome extends StatefulWidget {
  const SalesHome({super.key});
  @override
  State<SalesHome> createState() => _SalesHomeState();
}

class _SalesHomeState extends State<SalesHome> {
  static const initialApiUrl = String.fromEnvironment('API_BASE_URL');
  final List<SalesRecord> _items = [];
  RegionCatalog? _catalog;
  String _apiUrl = initialApiUrl;
  String _accessToken = '';
  bool _loading = false;
  int _selectedIndex = 0;
  String? _message;

  bool get _online => _apiUrl.trim().isNotEmpty && _accessToken.trim().isNotEmpty;
  List<String> get _sections => ['Tổng quan', ...moduleKinds.map((e) => moduleLabels[e]!)];
  List<IconData> get _icons => const [
    Icons.dashboard_outlined, Icons.store_outlined, Icons.flag_outlined,
    Icons.payments_outlined, Icons.route_outlined, Icons.handshake_outlined,
    Icons.policy_outlined, Icons.support_agent_outlined,
  ];

  @override
  void initState() {
    super.initState();
    RegionCatalog.load().then((catalog) {
      if (mounted) setState(() => _catalog = catalog);
    }).catchError((Object error) {
      if (mounted) setState(() => _message = 'Không tải được danh mục địa bàn: $error');
    });
  }

  void _notify(String message) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _refresh() async {
    if (!_online) return;
    setState(() => _loading = true);
    try {
      final api = SalesApi(_apiUrl, _accessToken);
      final lists = await Future.wait(moduleKinds.map(api.list));
      if (!mounted) return;
      setState(() {
        _items..clear()..addAll(lists.expand((list) => list));
        _message = null;
      });
      _notify('Đã đồng bộ ${_items.length} bản ghi');
    } catch (error) {
      if (mounted) setState(() => _message = 'Lỗi đồng bộ: $error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _settings() async {
    final base = TextEditingController(text: _apiUrl);
    final token = TextEditingController(text: _accessToken);
    final confirmed = await showDialog<bool>(context: context, builder: (dialogContext) =>
      AlertDialog(
        title: const Text('Kết nối Cloudflare API'),
        content: SizedBox(width: 460, child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Mẫu kết nối dành cho kiểm thử. Token chỉ tồn tại trong RAM; '
              'bản production cần đăng nhập OIDC/PKCE thực thụ.'),
          const SizedBox(height: 16),
          TextField(controller: base, decoration: const InputDecoration(
            labelText: 'API URL', hintText: 'https://field-sales-api...workers.dev')),
          const SizedBox(height: 12),
          TextField(controller: token, obscureText: true, decoration:
            const InputDecoration(labelText: 'Access token kiểm thử')),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Hủy')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Kết nối')),
        ],
      ));
    if (confirmed == true) {
      setState(() {
        _apiUrl = base.text.trim();
        _accessToken = token.text.trim();
      });
      if (_online) await _refresh();
    }
    base.dispose(); token.dispose();
  }

  Future<void> _addRecord(String kind) async {
    if (_catalog == null) return;
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => RecordEditor(
      kind: kind, catalog: _catalog!, onSave: (record) async {
        if (_online) {
          final saved = await SalesApi(_apiUrl, _accessToken).create(record);
          if (mounted) setState(() => _items.insert(0, saved));
        } else {
          // Bản nháp demo trong bộ nhớ, không lưu số điện thoại lên storage web.
          final demoRecord = SalesRecord.fromJson({...record,
            'id': 'demo-${DateTime.now().microsecondsSinceEpoch}'});
          if (mounted) setState(() => _items.insert(0, demoRecord));
        }
      },
    )));
    if (!_online) _notify('Bản ghi chỉ nằm trong RAM (demo), sẽ mất khi thoát app');
  }

  String _money(num value) {
    final digits = value.round().toString();
    return '${digits.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.')} đ';
  }
  List<SalesRecord> _ofKind(String kind) => _items.where((e) => e.kind == kind).toList();

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
    final provinces = _catalog?.provinces ?? <String>[];
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
      const SizedBox(height: 20),
      _coverageTable(surveys),
      const SizedBox(height: 22),
      Text('Phân hệ nghiệp vụ', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      for (var i = 0; i < moduleKinds.length; i++) Card(
        child: ListTile(
          leading: Icon(_icons[i+1], color: SalesTheme.brand),
          title: Text(moduleLabels[moduleKinds[i]]!),
          subtitle: Text('${_ofKind(moduleKinds[i]).length} bản ghi'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => setState(() => _selectedIndex = i + 1),
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
        FilledButton.icon(onPressed: _catalog == null ? null : () => _addRecord(kind),
          icon: const Icon(Icons.add), label: const Text('Thêm mới')),
      ])),
      Expanded(child: items.isEmpty
        ? Center(child: Padding(padding: const EdgeInsets.all(30), child: Column(
          mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.inbox_outlined, size: 52, color: Colors.grey),
            const SizedBox(height: 12),
            const Text('Chưa có dữ liệu'),
            const SizedBox(height: 10),
            FilledButton.tonal(onPressed: _catalog == null ? null : () => _addRecord(kind),
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
              trailing: record.id.startsWith('demo-')
                ? const Tooltip(message: 'Chỉ lưu tạm trong RAM', child: Icon(Icons.cloud_off_outlined))
                : const Icon(Icons.cloud_done_outlined),
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
        title: const Text('Sales Miền Tây', style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          if (_loading) const Padding(padding: EdgeInsets.all(16),
            child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))),
          IconButton(onPressed: _online ? _refresh : null,
            tooltip: 'Tải lại dữ liệu', icon: const Icon(Icons.sync)),
          IconButton(onPressed: _settings,
            tooltip: 'Kết nối API', icon: const Icon(Icons.settings_outlined)),
        ],
      ),
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
          Material(color: _online ? const Color(0xFFE3F4EC) : const Color(0xFFFFF1DB),
            child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(children: [
                Icon(_online ? Icons.cloud_done_outlined : Icons.info_outline, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(_online
                  ? 'Kết nối API — xác thực tạm cho thử nghiệm'
                  : 'Chế độ demo: dữ liệu chỉ ở RAM, KHÔNG lưu bền; không nhập dữ liệu khách thật.',
                  style: const TextStyle(fontSize: 12))),
              ]))),
          if (_message != null) Material(color: const Color(0xFFFBE8E7),
            child: Padding(padding: const EdgeInsets.all(10), child: Text(_message!))),
          Expanded(child: _catalog == null
            ? const Center(child: CircularProgressIndicator())
            : _selectedIndex == 0 ? _overview() : _records(moduleKinds[_selectedIndex - 1])),
        ])),
      ]),
    );
  }
}