import 'dart:convert';
import 'package:http/http.dart' as http;
import 'models.dart';
import 'session.dart';

/// Requests use an HttpOnly web cookie or native secure session cookie.
class SalesApi {
  final String baseUrl;
  final String accessToken;
  final String? identity,revision;
  const SalesApi(this.baseUrl, this.accessToken,{this.identity,this.revision});

  Uri _uri(String path, [Map<String, String>? params]) {
    final base = baseUrl.replaceAll(RegExp(r'/$'), '');
    final uri = Uri.parse('$base$path');
    if (!(uri.scheme == 'https' || uri.host == 'localhost' || uri.host == '127.0.0.1')) {
      throw StateError('API phải dùng HTTPS');
    }
    return uri.replace(queryParameters: params);
  }
  Map<String, String> get _headers => {...sessionHeaders(accessToken),if(identity!=null)'X-Sync-Identity':identity!,if(revision!=null)'X-Sync-Revision':revision!};
  Future<List<SalesRecord>> list(String kind) async {
    final res = await http.get(_uri('/api/v1/records', {'kind': kind}), headers: _headers);
    final data = decodeApi(res);
    if (res.statusCode != 200) throw StateError('${data['error'] ?? 'API lỗi'}');
    return (data['items'] as List<dynamic>)
        .map((e) => SalesRecord.fromJson(e as Map<String, dynamic>)).toList();
  }
  Future<SalesRecord> create(Map<String, dynamic> record) async {
    final res = await http.post(_uri('/api/v1/records'),
      headers: _headers, body: jsonEncode(record));
    final data = decodeApi(res);
    if (res.statusCode != 201) throw StateError('${data['error'] ?? 'Không lưu được'}');
    return SalesRecord.fromJson(data['item'] as Map<String, dynamic>);
  }
}