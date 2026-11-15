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

  test('a single 401 is not enough to invalidate a saved Android login',()async{
    var calls=0;
    final result=await probeAuthenticatedSession(()async{
      calls++;
      if(calls==1)throw const ApiFailure(401,'Gateway temporarily rejected');
      return {'identity':'staff-1','scope_revision':'1'};
    },retryDelay:Duration.zero);
    expect(calls,2);
    expect(result['identity'],'staff-1');
  });

  test('two separate 401 responses are definitive session rejection',()async{
    var calls=0;
    await expectLater(probeAuthenticatedSession(()async{
      calls++;
      throw const ApiFailure(401,'Session revoked');
    },retryDelay:Duration.zero),throwsA(isA<ApiFailure>()
      .having((e)=>e.status,'status',401)));
    expect(calls,2);
  });

  test('401 followed by 503 is an outage, not a confirmed revoked session',()async{
    var calls=0;
    await expectLater(probeAuthenticatedSession(()async{
      calls++;
      throw ApiFailure(calls==1?401:503,'Provider throttled or unavailable');
    },retryDelay:Duration.zero),throwsA(isA<ApiFailure>()
      .having((e)=>e.status,'status',503)));
    expect(calls,2);
  });

  test('403 account revocation is fail-closed without retry',()async{
    var calls=0;
    await expectLater(probeAuthenticatedSession(()async{
      calls++;
      throw const ApiFailure(403,'Account disabled');
    },retryDelay:Duration.zero),throwsA(isA<ApiFailure>()
      .having((e)=>e.status,'status',403)));
    expect(calls,1);
  });

  test('503 provider failure does not recheck and never modifies the cookie',()async{
    var calls=0;
    await expectLater(probeAuthenticatedSession(()async{
      calls++;
      throw const ApiFailure(503,'Provider temporarily unavailable');
    },retryDelay:Duration.zero),throwsA(isA<ApiFailure>()
      .having((e)=>e.status,'status',503)));
    expect(calls,1);
  });

  test('unexpected HTML response gives a readable recovery error', () {
    expect(() => decodeApi(http.Response('<html>Unexpected rewrite</html>', 200)),
      throwsA(isA<ApiFailure>().having((e) => e.status, 'status', 502)));
  });
}
