import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

const productionOrigin = 'https://sales-mien-tay.vercel.app';
const sessionCookieName = '__Host-sales-session';
String get salesOrigin => kIsWeb ? Uri.base.origin : productionOrigin;
Map<String,String> sessionHeaders(String cookie) => {
  'Content-Type':'application/json',
  // Cloudflare Browser Integrity Check must not see the Dart HTTP default UA.
  // Browsers forbid overriding User-Agent; include this on native only.
  if (!kIsWeb) 'User-Agent':'FieldWork-Android/1.0',
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
  // 403 may be a permission/scope denial, not an invalid login session.
  // /api/v1/me is still handled explicitly by AuthGate.revalidate().
  if(r.statusCode==401) onSessionRejected?.call();
}
Map<String,dynamic> decodeApi(http.Response r) {
  if(r.statusCode<200 || r.statusCode>=300) {
    checkSessionStatus(r);
    String message='Lỗi kết nối ('+r.statusCode.toString()+')';
    try {message=(jsonDecode(r.body) as Map)['error']?.toString()??message;} catch (_) {}
    throw ApiFailure(r.statusCode,message);
  }
  try {
    return jsonDecode(r.body) as Map<String,dynamic>;
  } on FormatException {
    throw const ApiFailure(502,'Máy chủ trả dữ liệu không hợp lệ. Hãy thử lại.');
  }
}
/// A transient 401 from a gateway must be confirmed by the authoritative
/// /me endpoint before destroying the encrypted Android session. An actual
/// revoked or expired session continues to fail on the second independent
/// request, and is then handled by AuthGate as a security rejection.
Future<Map<String,dynamic>> probeAuthenticatedSession(
  Future<Map<String,dynamic>> Function() probe,{
  Duration retryDelay=const Duration(milliseconds:450),
}) async {
  try {
    return await probe();
  } on ApiFailure catch (e) {
    if(e.status!=401)rethrow;
    if(retryDelay>Duration.zero)await Future<void>.delayed(retryDelay);
    return await probe();
  }
}

/// Authentication secrets only: never use SQLite, SharedPreferences or logs for
/// the session cookie. A distinct encrypted Android store is used for new logins.
abstract class SessionSecretStore {
  Future<String?> read();
  Future<void> write(String value);
  Future<void> delete();
}

class EncryptedSessionSecretStore implements SessionSecretStore {
  static const key='sales.neon.session.v2';
  static const legacyKey='sales.neon.session.v1';
  final FlutterSecureStorage _current;
  final FlutterSecureStorage _legacy;
  const EncryptedSessionSecretStore({
    FlutterSecureStorage current=const FlutterSecureStorage(
      aOptions:AndroidOptions(encryptedSharedPreferences:true)),
    FlutterSecureStorage legacy=const FlutterSecureStorage(),
  }):_current=current,_legacy=legacy;

  @override Future<String?> read() async {
    final saved=await _current.read(key:key);
    if(saved!=null&&saved.isNotEmpty)return saved;
    // Read the original v9 storage only when the new store has no credential.
    // The old value is never erased until a new encrypted copy is verified.
    String? old;
    try { old=await _legacy.read(key:legacyKey); }
    catch (_) {
      // A restored Android Keystore may be unable to unwrap the old key.
      // Keep the unreadable legacy storage intact; a fresh login writes v2.
      return null;
    }
    if(old==null||old.isEmpty)return null;
    await write(old);
    return old;
  }
  @override Future<void> write(String value) async {
    if(value.isEmpty)throw ArgumentError('Empty authentication session');
    await _current.write(key:key,value:value);
    if(await _current.read(key:key)!=value){
      throw StateError('Secure session write verification failed');
    }
  }
  @override Future<void> delete() async {
    await _current.delete(key:key);
    // A corrupt old keystore must not prevent deleting the current session.
    try { await _legacy.delete(key:legacyKey); }catch(_){}
  }
}

class SalesSession {
  final SessionSecretStore _store;
  SalesSession({SessionSecretStore? store}):_store=store??const EncryptedSessionSecretStore();
  String cookie='';
  Uri uri(String path)=>Uri.parse('$salesOrigin$path');
  Future<void> restore() async {
    if(kIsWeb)return;
    try {
      cookie=await _store.read()??'';
    } catch (_) {
      // Allow one transient Android Keystore / first-unlock failure to settle.
      await Future<void>.delayed(const Duration(milliseconds:350));
      cookie=await _store.read()??'';
    }
  }
  Future<Map<String,dynamic>> get(String path) async {
    try {
      return decodeApi(await http.get(uri(path),headers:sessionHeaders(cookie))
          .timeout(const Duration(seconds:15)));
    } on TimeoutException {
      throw const ApiFailure(504,'Kết nối máy chủ quá chậm. Vui lòng thử lại.');
    }
  }
  Future<Map<String,dynamic>> post(String path,Map<String,dynamic> data) async {
    try {
      return decodeApi(await http.post(uri(path),headers:sessionHeaders(cookie),
          body:jsonEncode(data)).timeout(const Duration(seconds:15)));
    } on TimeoutException {
      throw const ApiFailure(504,'Kết nối máy chủ quá chậm. Vui lòng thử lại.');
    }
  }
  /// Sending mail can require two provider calls: draft creation, then send.
  /// Keep the business API's existing 15-second timeout unchanged.
  Future<Map<String,dynamic>> postMail(String path,Map<String,dynamic> data) async {
    if(!path.startsWith('/api/v1/mail/'))throw ArgumentError('Invalid mail path');
    try{
      return decodeApi(await http.post(uri(path),headers:sessionHeaders(cookie),
        body:jsonEncode(data)).timeout(const Duration(seconds:60)));
    } on TimeoutException {
      throw const ApiFailure(504,'Chưa xác nhận gửi thư thành công; không soạn lại trước khi kiểm tra thư nháp.');
    }
  }
  Future<void> requestOtp(String email) async { await post('/api/auth/otp/request',{'email':email}); }
  Future<void> login(String email,String password,{bool otp=false}) async {
    late final http.Response r;
    try {
      r=await http.post(uri(otp?'/api/auth/otp/login':'/api/auth/login'),
        headers:sessionHeaders(cookie),
        body:jsonEncode({'email':email,otp?'otp':'password':password}))
        .timeout(const Duration(seconds:15));
    } on TimeoutException {
      throw const ApiFailure(504,'Đăng nhập quá thời gian. Kiểm tra mạng và thử lại.');
    }
    decodeApi(r);
    if(!kIsWeb){
      final value=RegExp(r'__Host-sales-session=([^;\s,]+)').firstMatch(r.headers['set-cookie']??'')?.group(1);
      if(value==null)throw const ApiFailure(502,'Không nhận được phiên đăng nhập');
      // Do not enter SalesHome until the credential is durably readable.
      await _store.write(value);
      cookie=value;
    }
  }
  Future<void> logout() async {
    await post('/api/auth/logout',{});
    await clear();
  }
  Future<void> clear() async {
    cookie='';
    if(!kIsWeb)await _store.delete();
  }
}
