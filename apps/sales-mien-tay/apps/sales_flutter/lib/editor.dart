import 'package:flutter/material.dart';
import 'models.dart';

class RecordEditor extends StatefulWidget {
  final String kind;
  final RegionCatalog catalog;
  final Future<void> Function(Map<String, dynamic>) onSave;
  final Map<String,dynamic>? linkedCustomer;
  final SalesRecord? initial;
  const RecordEditor({super.key, required this.kind, required this.catalog, required this.onSave,this.linkedCustomer,this.initial});
  @override
  State<RecordEditor> createState() => _RecordEditorState();
}

class _RecordEditorState extends State<RecordEditor> {
  final _form = GlobalKey<FormState>();
  final Map<String, TextEditingController> _inputs = {};
  final Set<String> _distributors = {};
  final Set<String> _brands = {};
  String? _province, _district;
  String _potential = 'Trung bình';
  String _stage = 'Chưa tiếp cận';
  bool _busy = false;

  TextEditingController _ctrl(String name) =>
      _inputs.putIfAbsent(name, () => TextEditingController());
  @override
  void initState() {
    super.initState();
    _ctrl('period').text = '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}';
    _ctrl('surveyDate').text = DateTime.now().toIso8601String().substring(0, 10);
    final old=widget.initial;if(old!=null){for(final entry in old.data.entries){if(entry.value is String||entry.value is num)_ctrl(entry.key).text=entry.value.toString();}final weeks=old.data['weekly'];if(weeks is List){for(var i=0;i<weeks.length&&i<5;i++){_ctrl('week${i+1}').text=weeks[i].toString();}}_ctrl('period').text=old.periodYm??'';_ctrl('customerName').text=old.customerName??'';_province=old.province;_district=old.district;}
    final c=widget.linkedCustomer;if(c!=null){_ctrl('customerName').text=c['name'].toString();_province=c['province'].toString();_district=c['district'].toString();}
  }
  @override
  void dispose() {
    for (final c in _inputs.values) { c.dispose(); }
    super.dispose();
  }
  Widget _field(String name, String label, {bool required = false, bool numeric = false,
    bool multi = false, String? hint}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: _ctrl(name),
        readOnly: (widget.linkedCustomer!=null&&name=='customerName')||(widget.initial!=null&&['customerName','period'].contains(name)),
        keyboardType: numeric ? const TextInputType.numberWithOptions(decimal: true)
            : (multi ? TextInputType.multiline : TextInputType.text),
        maxLines: multi ? 3 : 1,
        decoration: InputDecoration(labelText: label, hintText: hint),
        validator: (value) => required && (value?.trim().isEmpty ?? true) ? 'Vui lòng nhập $label' : null,
      ),
    );
  }
  Widget _title(String title) => Padding(
    padding: const EdgeInsets.only(top: 12, bottom: 10),
    child: Text(title, style: Theme.of(context).textTheme.titleMedium),
  );
  Widget _locations() {
    if(widget.linkedCustomer!=null||widget.initial!=null)return Padding(padding:const EdgeInsets.all(12),child:Text('Địa bàn điểm bán: $_district, $_province'));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _title('Địa bàn theo địa giới cũ (trước 2025)'),
      DropdownButtonFormField<String>(
        value: _province,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Tỉnh / Thành phố cũ'),
        items: widget.catalog.provinces.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
        onChanged: (v) => setState(() { _province = v; _district = null; }),
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        // Key làm mới dropdown khi tỉnh thay đổi.
        key: ValueKey(_province),
        value: _district,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Huyện / Quận cũ'),
        items: (widget.catalog.districts[_province] ?? <String>[])
            .map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
        onChanged: _province == null ? null : (v) => setState(() => _district = v),
      ),
      const SizedBox(height: 12),
    ]);
  }
  Widget _choiceChips(String label, List<String> names, Set<String> selection) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _title(label),
      Wrap(spacing: 8, runSpacing: 6, children: names.map((name) => FilterChip(
        label: Text(name),
        selected: selection.contains(name),
        onSelected: (value) => setState(() => value ? selection.add(name) : selection.remove(name)),
      )).toList()),
      const SizedBox(height: 8),
    ]);
  }
  Widget _survey() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    _field('customerName', 'Tên cửa hàng / điểm bán', required: true),
    _field('pointType', 'Loại điểm bán'),
    _locations(),
    _field('ward', 'Xã / Phường cũ'),
    _field('address', 'Địa chỉ chi tiết'),
    _field('contact', 'Người liên hệ'),
    _field('phone', 'Số điện thoại'),
    _choiceChips('Nhà phân phối đang lấy hàng',
      const ['Thanh Đạt', 'Liên Hiệp', 'Hồng Ân'], _distributors),
    _field('otherDistributor', 'Nhà phân phối khác (ghi tên)'),
    _choiceChips('Nhãn hàng hiện diện tại điểm bán',
      const ['MGP', 'HH', 'Hoa Sen', 'Thành Đạt (đối thủ)', 'Bút Cầu', 'Bến Nghé'], _brands),
    _field('otherBrand', 'Nhãn hàng khác (ghi tên)'),
    _field('strongestBrand', 'Nhãn bán mạnh nhất'),
    _field('volume', 'Sản lượng ước tính (quyển/tháng)', numeric: true),
    const SizedBox(height: 4),
    DropdownButtonFormField<String>(
      value: _potential, decoration: const InputDecoration(labelText: 'Tiềm năng'),
      items: const ['Cao', 'Trung bình', 'Thấp', 'Chưa rõ']
        .map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
      onChanged: (v) => setState(() => _potential = v ?? _potential),
    ),
    const SizedBox(height: 12),
    DropdownButtonFormField<String>(
      value: _stage, decoration: const InputDecoration(labelText: 'Trạng thái tiếp cận'),
      items: const ['Chưa tiếp cận', 'Đã tiếp cận', 'Đang chăm sóc', 'Có cơ hội', 'Không phù hợp']
        .map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
      onChanged: (v) => setState(() => _stage = v ?? _stage),
    ),
    const SizedBox(height: 12),
    _field('owner', 'Sales phụ trách'),
    _field('surveyDate', 'Ngày khảo sát (YYYY-MM-DD)'),
    _field('notes', 'Ghi chú nguồn hàng / cơ hội', multi: true),
  ]);
  Widget _target() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    _field('period', 'Tháng kế hoạch (YYYY-MM)', required: true),
    _field('area', 'Khu vực'),
    _field('monthlyTarget', 'Target tháng (đ)', numeric: true, required: true),
    _title('Đăng ký doanh thu theo tuần (đ)'),
    for (var i = 1; i <= 5; i++) _field('week$i', 'Tuần $i', numeric: true),
    _field('notes', 'Đầu việc trọng tâm / ghi chú', multi: true),
  ]);
  Widget _forecast() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    _field('customerName', 'Khách hàng / điểm bán', required: true),
    _locations(),
    _field('period', 'Tháng dự kiến (YYYY-MM)', required: true),
    _field('customerType', 'Phân loại khách hàng'),
    _field('productGroup', 'Nhóm hàng'),
    _field('forecastStatus', 'Trạng thái dự kiến'),
    _title('Doanh thu dự kiến theo 5 tuần (đ)'),
    for (var i = 1; i <= 5; i++) _field('week$i', 'Tuần $i', numeric: true),
    _field('monthlyActions', 'Việc cần làm trong tháng', multi: true),
  ]);
  Widget _visit() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    _field('customerName', 'Khách hàng / điểm ghé', required: true),
    _locations(),
    _field('weekNumber', 'Tuần (1-5)', numeric: true),
    _field('plannedDate', 'Ngày dự kiến (YYYY-MM-DD)', required: true),
    _field('route', 'Tuyến / khu vực'),
    _field('purpose', 'Mục đích'),
    _field('expectedOutcome', 'Kết quả cần đạt', multi: true),
    _field('notes', 'Ghi chú', multi: true),
  ]);
  Widget _dealer() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    _field('customerName', 'Điểm bán / đơn vị', required: true),
    _locations(),
    _field('contact', 'Người liên hệ'),
    _field('phone', 'Số điện thoại'),
    _field('coverage', 'Lợi thế / độ phủ', multi: true),
    _field('signingPotential', 'Khả năng ký'),
    _field('targetWeek', 'Tuần dự kiến'),
    _field('terms', 'Điều kiện để ký', multi: true),
    _field('nextStep', 'Bước tiếp theo'),
    _field('expectedSales', 'Doanh số kỳ vọng (đ)', numeric: true),
    _field('status', 'Trạng thái'),
  ]);
  Widget _competitor() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    _field('title', 'Tên nhãn hàng', required: true),
    _locations(),
    _field('program', 'Chương trình chính', multi: true),
    _field('discount', 'Chiết khấu / thưởng'),
    _field('pricing', 'Giá / chính sách giá'),
    _field('effectivePeriod', 'Thời gian áp dụng'),
    _field('source', 'Nguồn thông tin / trạng thái xác minh'),
    _field('recommendation', 'Nhận định / đề xuất', multi: true),
  ]);
  Widget _support() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    _field('title', 'Vấn đề / cơ hội', required: true),
    _locations(),
    _field('requestedHelp', 'Hỗ trợ đề nghị', multi: true),
    _field('expectedOutcome', 'Kết quả mong đợi'),
    _field('priority', 'Mức ưu tiên'),
    _field('dueDate', 'Hạn cần (YYYY-MM-DD)'),
    _field('status', 'Trạng thái'),
    _field('department', 'Bộ phận phối hợp'),
    _field('notes', 'Ghi chú', multi: true),
  ]);
  Widget _content() => switch (widget.kind) {
    'survey' => _survey(), 'target' => _target(), 'forecast' => _forecast(),
    'visit' => _visit(), 'dealer' => _dealer(),
    'competitor' => _competitor(), 'support' => _support(),
    _ => const Text('Biểu mẫu không tồn tại'),
  };
  double _money(String key) {
    final raw = _ctrl(key).text.trim().replaceAll(',', '').replaceAll(' ', '');
    final value = double.tryParse(raw);
    if (value == null || !value.isFinite || value < 0) return 0;
    return value;
  }
  String _value(String key) => _ctrl(key).text.trim();
  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    if ((widget.kind == 'target' || widget.kind == 'forecast') &&
        !RegExp(r'^\d{4}-(0[1-9]|1[0-2])$').hasMatch(_value('period'))) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tháng phải có dạng YYYY-MM')));
      return;
    }
    if (widget.kind != 'target' && _province == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng chọn tỉnh/thành cũ')));
      return;
    }
    if (_province != null && _district == null && widget.kind != 'competitor') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng chọn huyện thuộc tỉnh đã chọn')));
      return;
    }
    final numericKeys = <String>[
      if (widget.kind == 'survey') 'volume',
      if (widget.kind == 'target') 'monthlyTarget',
      if (widget.kind == 'dealer') 'expectedSales',
      if (widget.kind == 'target' || widget.kind == 'forecast')
        for (var i = 1; i <= 5; i++) 'week$i',
    ];
    for (final key in numericKeys) {
      final raw = _value(key).replaceAll(',', '').replaceAll(' ', '');
      final number = double.tryParse(raw);
      if (raw.isNotEmpty && (number == null || !number.isFinite || number < 0)) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Số không hợp lệ: $key')));
        return;
      }
    }
    final details = <String, dynamic>{
      ...?widget.initial?.data,
      for (final entry in _inputs.entries) entry.key: entry.value.text.trim(),
    };
    if(widget.linkedCustomer!=null)details['customerId']=widget.linkedCustomer!['id'];
    if (widget.kind == 'survey') {
      details.addAll({
        'distributors': _distributors.toList(),
        'brands': _brands.toList(),
        'distributorCount': _distributors.length + (_value('otherDistributor').isNotEmpty ? 1 : 0),
        'brandCount': _brands.length + (_value('otherBrand').isNotEmpty ? 1 : 0),
        'potential': _potential,
        'stage': _stage,
      });
      details['volume'] = _money('volume');
    }
    if (widget.kind == 'target' || widget.kind == 'forecast') {
      details['weekly'] = [for (var i = 1; i <= 5; i++) _money('week$i')];
      details['monthTotal'] = (details['weekly'] as List<double>).fold<double>(0, (a,b) => a+b);
      if (widget.kind == 'target') details['monthlyTarget'] = _money('monthlyTarget');
    }
    if (widget.kind == 'dealer') details['expectedSales'] = _money('expectedSales');
    final record = <String, dynamic>{
      'kind': widget.kind,
      'province': _province, 'district': _district,
      'customer_name': _value('customerName').isNotEmpty ? _value('customerName') : null,
      'period_ym': widget.kind == 'target' || widget.kind == 'forecast' ? _value('period') : null,
      'data': details,
    };
    setState(() => _busy = true);
    try {
      await widget.onSave(record);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không lưu được: $error')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(moduleLabels[widget.kind] ?? 'Biểu mẫu')),
      body: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Form(key: _form, child: ListView(padding: const EdgeInsets.all(18), children: [
          _title('Nhập liệu'),
          const Text('Các trường theo 2 biểu mẫu Excel; danh mục địa bàn trước sáp nhập 2025.'),
          const SizedBox(height: 14),
          _content(),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _busy ? null : _submit,
            icon: _busy ? const SizedBox(width: 17, height: 17, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.save_outlined),
            label: const Text('Lưu biểu mẫu'),
          ),
          const SizedBox(height: 30),
        ])),
      )),
    );
  }
}