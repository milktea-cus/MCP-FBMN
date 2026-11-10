import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sales_mien_tay/inventory_import.dart';
void main(){
 test('Excel text codes, zero, numeric rejection and duplicate',(){
  final book=Excel.createExcel();final sheet=book['Sheet1'];
  sheet.appendRow([TextCellValue('Mã'),TextCellValue('Tồn')]);
  sheet.appendRow([TextCellValue('000123'),IntCellValue(0)]);
  sheet.appendRow([IntCellValue(123),IntCellValue(1)]);
  sheet.appendRow([TextCellValue('000123'),IntCellValue(2)]);
  sheet.appendRow([TextCellValue('X'),DoubleCellValue(1.5)]);
  final parsed=parseInventory(sheet,0,0,1);
  expect(parsed.rows.single['company_code'],'000123');
  expect(parsed.rows.single['quantity'],0);
  expect(parsed.errors.length,3);
 });
}
