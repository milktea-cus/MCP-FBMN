import 'package:flutter_test/flutter_test.dart';
import 'package:sales_mien_tay/customers.dart';
import 'package:sales_mien_tay/order_picker.dart';

void main(){
 test('Sales code is read-only server identity, distinct from optional ERP customer code',(){
  final customer=FieldCustomer.fromJson({
   'id':'11111111-1111-4111-8111-111111111111',
   'owner_sub':'sales-1','name':'Nhà sách Minh Tâm',
   'field_code':'TGMT01','code':null,'address_line':'12 Lê Lợi',
   'province':'Tiền Giang','district':'Thành phố Mỹ Tho',
   'category':'nha_sach','status':'active','version':1,
  });
  expect(customer.fieldCode,'TGMT01');
  expect(customer.code,isNull);
  final stored=customer.toJson();
  expect(stored['field_code'],'TGMT01');
  expect(stored['code'],isNull);
  expect(orderPickerMatches({'name':customer.name,'field_code':customer.fieldCode,
   'export_code':null},'TGMT01',products:false),isTrue);
  expect(orderPickerMatches({'name':customer.name,'field_code':customer.fieldCode,
   'export_code':null},'CTY',products:false),isFalse);
 });
}
