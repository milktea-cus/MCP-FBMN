import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sales_mien_tay/inventory_import.dart';
import 'package:sales_mien_tay/xlsx_reader.dart';
void main(){
 test('XLSX text codes, zero, numeric rejection and duplicate',(){
  final a=Archive();
  void add(String path,String s){final bytes=utf8.encode(s);a.addFile(ArchiveFile(path,bytes.length,bytes));}
  add('xl/workbook.xml','<workbook xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="Sheet1" r:id="rId1"/></sheets></workbook>');
  add('xl/_rels/workbook.xml.rels','<Relationships><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/></Relationships>');
  add('xl/sharedStrings.xml','<sst><si><t>000123</t></si></sst>');
  add('xl/worksheets/sheet1.xml','<worksheet><sheetData><row r="1"><c r="A1" t="inlineStr"><is><t>Mã</t></is></c><c r="B1" t="inlineStr"><is><t>Tồn</t></is></c></row><row r="2"><c r="A2" t="s"><v>0</v></c><c r="B2"><v>0</v></c></row><row r="3"><c r="A3"><v>123</v></c><c r="B3"><v>1</v></c></row><row r="4"><c r="A4" t="s"><v>0</v></c><c r="B4"><v>2</v></c></row><row r="5"><c r="A5" t="inlineStr"><is><t>X</t></is></c><c r="B5"><v>1.5</v></c></row><row r="6"><c r="A6" t="inlineStr"><is><t>Y</t></is></c><c r="B6"><f>1+1</f><v>2</v></c></row></sheetData></worksheet>');
  final book=decodeInventoryWorkbook(Uint8List.fromList(ZipEncoder().encode(a)));
  final parsed=parseInventory(book.tables['Sheet1']!,0,0,1);
  expect(parsed.rows.single['company_code'],'000123');expect(parsed.rows.single['quantity'],0);expect(parsed.errors.length,4);
 });
}
