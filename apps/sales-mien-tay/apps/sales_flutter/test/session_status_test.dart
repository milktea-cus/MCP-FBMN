import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:sales_mien_tay/session.dart';

http.Response apiResponse(String value, int status) =>
    http.Response.bytes(utf8.encode(value), status,
      headers: const {'content-type': 'application/json; charset=utf-8'});

void main() {
  tearDown(() => onSessionRejected = null);

  test('403 permission denial does not reject the login session', () {
    var count = 0;
    onSessionRejected = () => count++;
    expect(() => decodeApi(apiResponse('{"error":"Không có quyền"}', 403)),
        throwsA(isA<ApiFailure>()));
    expect(count, 0);
    expect(() => decodeApi(apiResponse('{"error":"Chưa đăng nhập"}', 401)),
        throwsA(isA<ApiFailure>()));
    expect(count, 1);
  });

  test('network 503 does not revoke the session', () {
    var count = 0;
    onSessionRejected = () => count++;
    expect(() => decodeApi(apiResponse('{"error":"Mất kết nối"}', 503)),
        throwsA(isA<ApiFailure>()));
    expect(count, 0);
  });

  test('unexpected HTML response gives a readable recovery error', () {
    expect(() => decodeApi(http.Response('<html>Unexpected rewrite</html>', 200)),
      throwsA(isA<ApiFailure>().having((e) => e.status, 'status', 502)));
  });
}
