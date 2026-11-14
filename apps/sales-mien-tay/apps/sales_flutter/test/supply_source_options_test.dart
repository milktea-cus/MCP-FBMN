import 'package:flutter_test/flutter_test.dart';
import 'package:sales_mien_tay/surveys.dart';
import 'package:sales_mien_tay/customers.dart';

void main(){
 test('supplier choices contain NPP customers only, no duplicate',(){
  FieldCustomer item(String id,String name,String category)=>
   FieldCustomer.fromJson({'id':id,'name':name,'address_line':'X',
    'province':'Bến Tre','district':'Ba Tri','category':category,'status':'active'});
  final options=supplySourceOptions([
   item('1','NPP Tây Nam','npp'),item('2','NPP Tây Nam','npp'),
   item('3','Nhà sách','nha_sach'),item('4','NPP Hòa Bình','npp'),
  ]);
  expect(options,contains('Mua trực tiếp công ty'));
  expect(options,contains('NPP Hòa Bình'));
  expect(options.where((x)=>x=='NPP Tây Nam'),hasLength(1));
  expect(options, isNot(contains('Nhà sách')));
 });
}
