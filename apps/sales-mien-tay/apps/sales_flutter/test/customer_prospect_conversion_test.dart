import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sales_mien_tay/customers.dart';

Map<String,dynamic> customerJson() => {
  'id':'beedb9d3-8941-483f-bb7a-e6a70fe602d1',
  'client_ref':'2b82ba78-88f6-496b-b8eb-ad2e0a6cf28a',
  'owner_sub':'sales-test',
  'name':'Nhà sách Mai Thảo',
  'address_line':'15 Trần Nhân Tôn',
  'province':'TP Hồ Chí Minh',
  'district':'Quận 10',
  'category':'nha_sach',
  'status':'active',
  'is_selling':false,
  'version':1,
};

void main(){
  test('normal customer creation remains a 201 without prospect flags',()async{
    final mock=MockClient((request)async{
      expect(request.method,'POST');
      expect(request.url.path,'/api/v1/customers');
      return http.Response(jsonEncode({'item':customerJson(),
        'idempotent':false,'converted_from_prospect':null,'reused_existing':false}),
        201,headers:{'content-type':'application/json'});
    });
    final service=CustomerService('https://api.example.test','token',client:mock);
    final created=await service.add({'client_ref':'2b82ba78-88f6-496b-b8eb-ad2e0a6cf28a'});
    expect(created.id,customerJson()['id']);
    expect(created.reconciledProspect,isFalse);
    expect(created.reusedExisting,isFalse);
  });

  test('auto-promoted prospect is shown as one customer with a promotion flag',()async{
    final mock=MockClient((_)async=>http.Response(jsonEncode({
      'item':customerJson(),
      'idempotent':false,
      'converted_from_prospect':'c6f66598-62ec-48ac-badb-1ac62d8d03c9',
      'reused_existing':false,
    }),201,headers:{'content-type':'application/json'}));
    final service=CustomerService('https://api.example.test','token',client:mock);
    final created=await service.add({'client_ref':'2b82ba78-88f6-496b-b8eb-ad2e0a6cf28a'});
    expect(created.reconciledProspect,isTrue);
    expect(created.reusedExisting,isFalse);
    expect(created.isSelling,isFalse);
  });

  test('an already-converted prospect returns the existing customer with HTTP 200',()async{
    final mock=MockClient((_)async=>http.Response(jsonEncode({
      'item':customerJson(),
      'idempotent':false,
      'converted_from_prospect':'c6f66598-62ec-48ac-badb-1ac62d8d03c9',
      'reused_existing':true,
    }),200,headers:{'content-type':'application/json'}));
    final service=CustomerService('https://api.example.test','token',client:mock);
    final existing=await service.add({'client_ref':'3c6614f7-3f45-4d7b-ae14-194909a1e975'});
    expect(existing.id,customerJson()['id']);
    expect(existing.reusedExisting,isTrue);
    expect(existing.reconciledProspect,isTrue);
  });
}
