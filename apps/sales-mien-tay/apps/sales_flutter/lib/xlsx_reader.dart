import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

class XlsxCell {
 final String text;
 final String type;
 const XlsxCell(this.text,this.type);
}
class XlsxSheet {
 final List<List<XlsxCell?>> rows;
 const XlsxSheet(this.rows);
 int get maxRows=>rows.length;
}
class XlsxBook {
 final Map<String,XlsxSheet> tables;
 const XlsxBook(this.tables);
}
Iterable<XmlElement> elements(XmlNode n,String local)=>n.descendants.whereType<XmlElement>().where((e)=>e.name.local==local);
String richText(XmlNode n)=>elements(n,'t').map((e)=>e.innerText).join();
String? attr(XmlElement e,String local)=>e.attributes.where((a)=>a.name.local==local).firstOrNull?.value;
int columnIndex(String ref){
 final m=RegExp(r'^([A-Z]{1,3})[1-9][0-9]*$').firstMatch(ref);
 if(m==null)throw FormatException('Ô Excel không hợp lệ: $ref');
 var n=0;for(final c in m[1]!.codeUnits){n=n*26+c-64;}return n-1;
}
/// Restricted XLSX reader: only workbook relationships, strings and cell values.
XlsxBook decodeInventoryWorkbook(Uint8List bytes){
 if(bytes.isEmpty||bytes.length>5*1024*1024)throw const FormatException('File tối đa 5 MB');
 final archive=ZipDecoder().decodeBytes(bytes);
 if(archive.files.length>1000||archive.files.fold<int>(0,(sum,f)=>sum+f.size)>30*1024*1024)throw const FormatException('File Excel giải nén quá lớn');
 final files=<String,ArchiveFile>{};
 for(final f in archive.files){if(f.isFile){if(files.containsKey(f.name))throw const FormatException('File ZIP trùng tên');files[f.name]=f;}}
 XmlDocument doc(String path){
  final f=files[path];if(f==null||f.size>15*1024*1024)throw FormatException('Thiếu hoặc quá lớn: $path');
  final raw=utf8.decode(f.content);
  if(raw.contains('<!DOCTYPE')||raw.contains('<!ENTITY'))throw const FormatException('XML không được chứa DTD');
  return XmlDocument.parse(raw);
 }
 final workbook=doc('xl/workbook.xml'),rels=doc('xl/_rels/workbook.xml.rels');
 final targets=<String,String>{};
 for(final e in elements(rels,'Relationship')){
  final id=attr(e,'Id'),target=attr(e,'Target'),type=attr(e,'Type');
  if(id==null||target==null||type==null||!type.endsWith('/worksheet')||attr(e,'TargetMode')=='External')continue;
  final resolved=Uri.parse('xl/workbook.xml').resolve(target).path.replaceFirst(RegExp(r'^/'),'');
  if(!resolved.startsWith('xl/')||resolved.contains('..'))throw const FormatException('Đường dẫn sheet không hợp lệ');
  targets[id]=resolved;
 }
 final shared=files.containsKey('xl/sharedStrings.xml')?elements(doc('xl/sharedStrings.xml'),'si').map(richText).toList():<String>[];
 final sheets=<String,XlsxSheet>{};
 for(final e in elements(workbook,'sheet')){
  final name=attr(e,'name'),id=attr(e,'id');if(name==null||id==null||!targets.containsKey(id))continue;
  if(sheets.length>=20)throw const FormatException('Tối đa 20 sheet');
  final rows=<List<XlsxCell?>>[],xml=doc(targets[id]!);
  for(final row in elements(xml,'row')){
   final rn=int.tryParse(attr(row,'r')??'')??rows.length+1;
   if(rn<1||rn>10000)throw const FormatException('Sheet vượt 10.000 dòng');
   while(rows.length<rn){rows.add(<XlsxCell?>[]);}
   final cells=rows[rn-1];
   for(final c in row.children.whereType<XmlElement>().where((e)=>e.name.local=='c')){
    final col=columnIndex(attr(c,'r')??'');if(col>=256)throw const FormatException('Sheet vượt 256 cột');
    final type=attr(c,'t')??'n',val=elements(c,'v').firstOrNull?.innerText??'';
    XlsxCell? cell;
    if(elements(c,'f').isNotEmpty){cell=const XlsxCell('Công thức','formula');}
    else if(type=='s'){final n=int.tryParse(val);if(n==null||n<0||n>=shared.length)throw const FormatException('Shared string không hợp lệ');cell=XlsxCell(shared[n],'text');}
    else if(type=='inlineStr'){cell=XlsxCell(richText(c),'text');}
    else if(type=='str'){cell=XlsxCell(val,'formula');}
    else if(val.isNotEmpty){cell=XlsxCell(val,type=='n'?'number':'other');}
    while(cells.length<=col){cells.add(null);}cells[col]=cell;
   }
  }
  sheets[name]=XlsxSheet(rows);
 }
 if(sheets.isEmpty)throw const FormatException('File không có sheet đọc được');
 return XlsxBook(sheets);
}
