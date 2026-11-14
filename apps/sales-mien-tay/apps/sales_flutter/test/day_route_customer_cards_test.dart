import 'package:flutter_test/flutter_test.dart';
import 'package:sales_mien_tay/day_route.dart';

void main(){
 test('area customers appear without preselecting planned stops',(){
  final cards=dayRouteCustomerCards([],[
   {'id':'a','name':'Nhà sách A','category':'nha_sach','district':'Bình Đại'},
   {'id':'b','name':'Đại lý B','category':'dai_ly','district':'Giồng Trôm'},
  ],[]);
  expect(cards.length,2);
  expect(cards.map((e)=>e['source']),everyElement('scope'));
  expect(cards.first['category'],'nha_sach');
 });
 test('scheduled and assigned sources do not duplicate customers',(){
  final cards=dayRouteCustomerCards([
   {'id':'stop-a','stop_kind':'customer','customer_id':'a',
    'customer_name':'Nhà sách A','category':'nha_sach','sequence':1}
  ],[
   {'id':'a','name':'Nhà sách A'},
   {'id':'b','name':'NPP B','category':'npp'},
  ],[
   {'payload':{'client_ref':'stop-b','stop_kind':'customer','customer_id':'b'},
    'status':'pending','key':'b'},
  ]);
  expect(cards.length,2);
  expect(cards[0]['source'],'planned');
  expect(cards[1]['source'],'pending');
  expect(cards[1]['category'],'npp');
 });
 test('offline newly created customer is named and categorized immediately',(){
  final rows=dayRouteCustomerCards([],[],[
   {'payload':{'client_ref':'stop-c','stop_kind':'customer','customer_id':'c'},
    'status':'pending','key':'k'},
  ],localCustomers:{
   'c':{'name':'VPP mới','category':'van_phong_pham','district':'Ba Tri'}
  });
  expect(rows.single['customer_name'],'VPP mới');
  expect(rows.single['category'],'van_phong_pham');
  expect(rows.single['customer_district'],'Ba Tri');
 });
 test('search by name, code and district preserves full scope',(){
  final customers=[{'id':'a','name':'Khách A','code':'AA01','district':'Bình Đại'},
   {'id':'b','name':'Khách B','code':'BB02','district':'Chợ Lách'}];
  expect(dayRouteCustomerCards([],customers,[],query:'bb02').single['customer_id'],'b');
  expect(dayRouteCustomerCards([],customers,[],query:'Bình Đại').single['customer_id'],'a');
  expect(dayRouteCustomerCards([],customers,[]).length,2);
 });
}
