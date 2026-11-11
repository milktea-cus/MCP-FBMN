import 'package:flutter_test/flutter_test.dart';
import '../lib/targets.dart';
void main(){
 test('month quarter year rollup and independent allocation dimensions',(){
  expect(targetMonths('quarter',5),[4,5,6]);expect(targetMonths('year',1).length,12);
  final rows=<Map<String,dynamic>>[
   {'month':4,'dimension':'employee','amount':'100'},
   {'month':5,'dimension':'employee','amount':'200'},
   {'month':4,'dimension':'customer','entity_id':'c','amount':'80'},
   {'month':4,'dimension':'product','entity_id':'p','amount':'90'},
  ];
  expect(targetTotal(rows,[4,5,6],'employee'),300);
  expect(targetTotal(rows,[4],'customer'),80);
  expect(targetTotal(rows,[4],'product'),90);
  expect(targetMoney(1000000),'1.000.000 đ');
 });
}
