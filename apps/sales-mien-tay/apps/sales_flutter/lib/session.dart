import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

const productionOrigin = 'https://sales-mien-tay.vercel.app';
const sessionCookieName = '__Host-sales-session';
String get salesOrigin => kIsWeb ? Uri.base.origin : productionOrigin;
Map<String,String> sessionHeaders(String cookie) => {
  'Content-Type':'application/json',
  if (!kIsWeb) 'Origin':productionOrigin,
  if (!kIsWeb && cookie.isNotEmpty) 'Cookie':'$sessionCookieName=$cookie',
};
class ApiFailure implements Exception {
  final int status;
  final String message;
  const ApiFailure(this.status,this.message);
  @override String toString()=>message;
}
VoidCallback? onSessionRejected;
void checkSessionStatus(http.Response r) {
  if(r.statusCode==401 || r.statusCode==403) onSessionRejected?.call();
}
Map<String,dynamic> decodeApi(http.Response r) {
  if(r.statusCode<200 || r.statusCode>=300) {
    checkSessionStatus(r);
    String message='Lỗi kết nối ('+r.statusCode.toString()+')';
    try {message=(jsonDecode(r.body) as Map)['error']?.toString()??message;} catch (_) {}
    throw ApiFailure(r.statusCode,message);
  }
  return jsonDecode(r.body) as Map<String,dynamic>;
}
class SalesSession {
  final _storage=const FlutterSecureStorage();
  String cookie='';
  Uri uri(String path)=>Uri.parse('$salesOrigin$path');
  Future<void> restore() async {
    if(!kIsWeb) cookie=await _storage.read(key:'sales.neon.session.v1')??'';
  }
  Future<Map<String,dynamic>> get(String path) async =>
    decodeApi(await http.get(uri(path),headers:sessionHeaders(cookie)).timeout(const Duration(seconds:20)));
  Future<Map<String,dynamic>> post(String path,Map<String,dynamic> data) async =>
    decodeApi(await http.post(uri(path),headers:sessionHeaders(cookie),body:jsonEncode(data)).timeout(const Duration(seconds:20)));
  Future<void> login(String email,String password) async {
    final r=await http.post(uri('/api/auth/login'),headers:sessionHeaders(cookie),
      body:jsonEncode({'email':email,'password':password})).timeout(const Duration(seconds:20));
    decodeApi(r);
    if(!kIsWeb){
      final value=RegExp(r'__Host-sales-session=([^;\s,]+)').firstMatch(r.headers['set-cookie']??'')?.group(1);
      if(value==null)throw const ApiFailure(502,'Không nhận được phiên đăng nhập');
      cookie=value;
      await _storage.write(key:'sales.neon.session.v1',value:value);
    }
  }
  Future<void> logout() async {
    await post('/api/auth/logout',{});
    await clear();
  }
  Future<void> clear() async {
    cookie='';
    if(!kIsWeb)await _storage.delete(key:'sales.neon.session.v1');
  }
}
