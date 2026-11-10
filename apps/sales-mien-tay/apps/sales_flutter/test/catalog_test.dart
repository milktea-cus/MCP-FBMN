import 'package:flutter_test/flutter_test.dart';
import 'package:sales_mien_tay/catalog.dart';
void main(){
 test('packaging must be positive and consistent',(){
  expect(packagingError({'unitsPerCarton':120,'unitsPerPack':12,'packsPerCarton':10}),isNull);
  expect(packagingError({'unitsPerCarton':100,'unitsPerPack':12,'packsPerCarton':10}),isNotNull);
  expect(packagingError({'unitsPerPack':0}),isNotNull);
  expect(packagingError({'unitsPerPack':'12'}),isNotNull);
  expect(specSummary({'unitsPerPack':12,'packsPerCarton':10,'pieceUnit':'quyển'}),contains('120 SP/thùng'));
 });
}
