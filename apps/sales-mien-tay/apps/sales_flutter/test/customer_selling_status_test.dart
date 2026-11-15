import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:idb_shim/idb_shim.dart';
import 'package:sales_mien_tay/customer_categories.dart';
import 'package:sales_mien_tay/customers.dart';
import 'package:sales_mien_tay/models.dart';
import 'package:sales_mien_tay/offline_queue.dart';
import 'package:sales_mien_tay/session.dart';

const customerId='11111111-1111-4111-8111-111111111111';
Map<String,dynamic> record({bool selling=false,String owner='sales-1',int version=1})=>{
  'id':customerId,'owner_sub':owner,'name':'VPP Hồng Phấn',
  'field_code':'BTHP01','category':'van_phong_pham',
  'province':'Bến Tre','district':'Huyện Bình Đại',
  'address_line':'Phú Thuận','status':'active','version':version,
  'is_selling':selling,
};

class OfflineSalesSession extends SalesSession{
  @override Future<Map<String,dynamic>> get(String path)async=>
    {'identity':'sales-1','scope_revision':'rev-1'};
}

class SellingService extends CustomerService{
  SellingService():super('https://example.test','token',identity:'sales-1');
  bool? lastValue;
  @override Future<List<Map<String,dynamic>>> media(String id)async=>[];
  @override Future<List<Map<String,dynamic>>> visits(String id)async=>[];
  @override Future<FieldCustomer> update(FieldCustomer customer,Map<String,dynamic> data)async{
    lastValue=data['is_selling'] as bool?;
    return FieldCustomer.fromJson(record(selling:lastValue??false,version:2));
  }
}

void main(){
  test('new and legacy customers remain unconfirmed until explicitly marked',(){
    final newRecord=FieldCustomer.fromJson(record());
    final legacy=FieldCustomer.fromJson({...record()}..remove('is_selling'));
    expect(newRecord.isSelling,isFalse);
    expect(legacy.isSelling,isFalse);
    expect(newRecord.status,'active');
    expect(newRecord.toJson()['is_selling'],isFalse);
    final enabled=FieldCustomer.fromJson(record(selling:true));
    expect(enabled.isSelling,isTrue);
    expect(enabled.toJson()['status'],'active');
  });

  testWidgets('customer dot is green for selling and yellow for unconfirmed',(tester)async{
    await tester.pumpWidget(const MaterialApp(home:Scaffold(body:Column(children:[
      CustomerSellingDot(isSelling:true),
      CustomerSellingDot(isSelling:false),
    ]))));
    final decorations=tester.widgetList<Container>(
       find.byKey(const Key('customer-selling-dot'))).toList();
    expect((decorations[0].decoration as BoxDecoration).color,
      CustomerSellingDot.sellingColor);
    expect((decorations[1].decoration as BoxDecoration).color,
      CustomerSellingDot.unconfirmedColor);
  });

  testWidgets('profile switch under active status updates only owned customer',(tester)async{
    final service=SellingService();
    await tester.pumpWidget(MaterialApp(home:CustomerDetail(
      service:service,customer:FieldCustomer.fromJson(record()),
      regions:const RegionCatalog({}))));
    await tester.pump();
    expect(find.text('Đang hoạt động'),findsOneWidget);
    expect(find.text('Chưa bán'),findsOneWidget);
    final control=find.byKey(const Key('customer-selling-switch'));
    expect(tester.widget<Switch>(control).value,isFalse);
    await tester.tap(control);
    await tester.pump();
    expect(service.lastValue,isTrue);
    expect(find.text('Đang bán'),findsOneWidget);
    expect(tester.widget<Switch>(control).value,isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('customer without edit permission cannot toggle selling',(tester)async{
    final service=SellingService();
    await tester.pumpWidget(MaterialApp(home:CustomerDetail(
      service:service,customer:FieldCustomer.fromJson(record(owner:'other')),
      regions:const RegionCatalog({}))));
    await tester.pump();
    final control=tester.widget<Switch>(
      find.byKey(const Key('customer-selling-switch')));
    expect(control.onChanged,isNull);
    expect(service.lastValue,isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test('offline selling patch persists, acknowledges, and reopens customer cache',()async{
    final factory=newIdbFactoryMemory();
    final client=MockClient((request)async{
      expect(request.method,'PATCH');
      expect(request.url.path,'/api/v1/customers/$customerId');
      final body=jsonDecode(request.body) as Map<String,dynamic>;
      expect(body['is_selling'],true);
      expect(body['version'],1);
      return http.Response(jsonEncode({
        'item':record(selling:true,version:2),
      }),200,headers:{'content-type':'application/json'});
    });
    final session=OfflineSalesSession();
    final queue=OfflineQueue(session,'sales-1','rev-1',
      factory:factory,networkClient:client);
    await queue.cache('customers:',[record()]);
    await queue.cache('customers:Bến Tre',[record()]);
    await queue.enqueue('/api/v1/customers/$customerId',{
      'client_ref':'55555555-5555-4555-8555-555555555555',
      'is_selling':true,'version':1,
    },method:'PATCH');
    expect(queue.pending.length,1);
    expect(customerSellingForDisplay(FieldCustomer.fromJson(record()),queue),true);
    await queue.sync(manual:true);
    expect(queue.pending,isEmpty);
    expect((await queue.cached('customers:')).single['is_selling'],true);
    expect((await queue.cached('customers:Bến Tre')).single['version'],2);
    queue.dispose();
    final reopened=OfflineQueue(session,'sales-1','rev-1',factory:factory);
    expect((await reopened.cached('customers:')).single['is_selling'],true);
    expect((await reopened.cached('customers:Bến Tre')).single['is_selling'],true);
    reopened.dispose();
    client.close();
  });
}
