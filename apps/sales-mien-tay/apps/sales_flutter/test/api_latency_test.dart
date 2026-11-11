import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sales_mien_tay/api.dart';

void main() {
  test('legacy module list never waits indefinitely for stalled network', () async {
    final never=Completer<http.Response>();
    final client=MockClient((_)=>never.future);
    final api=SalesApi('https://example.test','',
      client:client,listTimeout:const Duration(milliseconds:40));
    final before=DateTime.now();
    await expectLater(api.list('survey'),throwsA(isA<TimeoutException>()));
    expect(DateTime.now().difference(before).inSeconds,lessThan(2));
    client.close();
  });

  test('legacy module list returns immediately for authorized empty set',() async {
    final seen=<Uri>[];
    final client=MockClient((request)async {
      seen.add(request.url);
      return http.Response.bytes(utf8.encode('{"items":[]}'),200,
        headers:{'content-type':'application/json; charset=utf-8'});
    });
    final api=SalesApi('https://example.test','',
      client:client,listTimeout:const Duration(seconds:1));
    expect(await api.list('survey'),isEmpty);
    expect(seen.single.path,'/api/v1/records');
    expect(seen.single.queryParameters['kind'],'survey');
    client.close();
  });
}
