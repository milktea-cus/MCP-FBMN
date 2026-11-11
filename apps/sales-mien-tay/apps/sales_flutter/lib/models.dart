import 'dart:convert';
import 'package:flutter/services.dart';

class RegionCatalog {
  final Map<String, List<String>> districts;
  const RegionCatalog(this.districts);
  List<String> get provinces => districts.keys.toList();
  static Future<RegionCatalog> load() async {
    final raw = await rootBundle.loadString('assets/districts_old.json');
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return RegionCatalog(decoded.map((key, value) =>
      MapEntry(key, (value as List<dynamic>).cast<String>())));
  }
}

class SalesRecord {
  final String id;
  final String kind;
  final int version;
  final String? owner;
  final String? province;
  final String? district;
  final String? customerName;
  final String? periodYm;
  final Map<String, dynamic> data;
  const SalesRecord({required this.id, required this.kind, this.province,
    this.district, this.customerName, this.periodYm, required this.data,this.version=1,this.owner});

  factory SalesRecord.fromJson(Map<String, dynamic> v) => SalesRecord(
    id: '${v['id'] ?? ''}',
    kind: '${v['kind'] ?? ''}',
    owner:v['owner_sub'] as String?,
    version: (v['version'] as num?)?.toInt()??1,
    province: v['province'] as String?, district: v['district'] as String?,
    customerName: v['customer_name'] as String?,
    periodYm: v['period_ym'] as String?,
    data: (v['data'] is Map<String, dynamic>) ? v['data'] as Map<String, dynamic> : {},
  );
  Map<String,dynamic> toJson()=>{'id':id,'owner_sub':owner,'version':version,'kind':kind,'province':province,'district':district,'customer_name':customerName,'period_ym':periodYm,'data':data};
  String get title => (customerName?.isNotEmpty ?? false) ? customerName!
    : (data['title']?.toString().isNotEmpty ?? false) ? data['title'].toString()
    : (periodYm ?? kind);
  String get subtitle => [province, district, periodYm]
    .where((e) => e != null && e.isNotEmpty).join(' · ');
  double get forecastTotal {
    final weekly = data['weekly'];
    if (weekly is! List) return 0;
    return weekly.fold<double>(0, (a, b) => a + (b is num ? b.toDouble() : 0));
  }
}

const moduleKinds = <String>['survey', 'target', 'forecast', 'visit', 'dealer', 'competitor', 'support'];
const moduleLabels = <String, String>{
  'survey': 'Khảo sát điểm bán',
  'target': 'Quản lý Target',
  'forecast': 'Doanh thu dự kiến',
  'visit': 'Lịch di chuyển',
  'dealer': 'Cơ hội đại lý',
  'competitor': 'Thông tin đối thủ',
  'support': 'Đề xuất hỗ trợ',
};