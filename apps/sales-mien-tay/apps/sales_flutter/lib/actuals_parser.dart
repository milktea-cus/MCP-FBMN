import 'xlsx_reader.dart';
const actualAttributes=<String,String>{
 'ignore':'Bỏ qua',
 'sale_date':'Ngày doanh số',
 'employee_code':'Mã nhân viên',
 'customer_code':'Mã khách hàng',
 'company_code':'Mã CTY (sản phẩm)',
 'quantity':'Số lượng',
 'amount':'Doanh số (VNĐ)',
 'external_ref':'Mã chứng từ/giao dịch',
 'line_ref':'Mã dòng chứng từ (tùy chọn)',
};
const actualRequired=['sale_date','employee_code','customer_code','company_code','quantity','amount','external_ref'];
class ActualParse{
 final List<Map<String,dynamic>> rows;final List<String> errors;
 const ActualParse(this.rows,this.errors);
}
String actualColumn(int i){var n=i+1,s='';while(n>0){n--;s=String.fromCharCode(65+n%26)+s;n~/=26;}return s;}
XlsxCell? actualCell(List<XlsxCell?> row,int index)=>index>=0&&index<row.length?row[index]:null;
String? actualText(XlsxCell? cell,{int max=120}){
 if(cell?.type!='text')return null;
 final v=cell!.text.replaceAll(RegExp(r'[\u200B-\u200D\uFEFF]'),'').trim();
 return v.isNotEmpty&&v.length<=max?v:null;
}
int? actualInteger(XlsxCell? cell,{required int min,required int max}){
 if(cell==null)return null;
 final raw=cell.text.trim();
 if(cell.type=='formula'||cell.type=='other'||raw.isEmpty)return null;
 final normalized=cell.type=='text'&&RegExp(r'^\d{1,3}([.,]\d{3})+$').hasMatch(raw)?raw.replaceAll(RegExp(r'[.,]'),''):raw;
 if(!RegExp(r'^\d+$').hasMatch(normalized))return null;
 final n=int.tryParse(normalized);
 return n!=null&&n>=min&&n<=max?n:null;
}
String? actualDate(XlsxCell? cell){
 if(cell==null||cell.type=='formula'||cell.type=='other')return null;
 final s=cell.text.trim();DateTime? date;
 if(cell.type=='number'){
  final n=int.tryParse(s);
  if(n==null||n<36526||n>73415)return null;
  date=DateTime.utc(1899,12,30).add(Duration(days:n));
 }else{
  final iso=RegExp(r'^(20\d{2}|2100)[-/](\d{1,2})[-/](\d{1,2})$').firstMatch(s);
  final vn=RegExp(r'^(\d{1,2})/(\d{1,2})/(20\d{2}|2100)$').firstMatch(s);
  if(iso!=null)date=DateTime.utc(int.parse(iso[1]!),int.parse(iso[2]!),int.parse(iso[3]!));
  else if(vn!=null)date=DateTime.utc(int.parse(vn[3]!),int.parse(vn[2]!),int.parse(vn[1]!));
  else return null;
  // DateTime normalizes invalid days. Reject them instead of changing the sale date.
  final expected=iso!=null?[int.parse(iso[1]!),int.parse(iso[2]!),int.parse(iso[3]!)]:[int.parse(vn![3]!),int.parse(vn[2]!),int.parse(vn[1]!)];
  if(date.year!=expected[0]||date.month!=expected[1]||date.day!=expected[2])return null;
 }
 if(date.year<2000||date.year>2100)return null;
 return '${date.year.toString().padLeft(4,'0')}-${date.month.toString().padLeft(2,'0')}-${date.day.toString().padLeft(2,'0')}';
}
ActualParse parseActualSheet(XlsxSheet sheet,int header,Map<int,String> mapping){
 final errors=<String>[],output=<Map<String,dynamic>>[],keys=<String>{};
 final chosen=mapping.entries.where((e)=>e.value!='ignore').toList();
 if(chosen.map((e)=>e.value).toSet().length!=chosen.length||actualRequired.any((k)=>!chosen.any((e)=>e.value==k)))
  return const ActualParse([],['Cần ánh xạ đủ 7 cột bắt buộc (ngày, mã NV, mã khách, mã CTY, số lượng, doanh số, mã chứng từ) và không chọn trùng.']);
 if(header<0||header>=sheet.rows.length)return const ActualParse([],['Dòng tiêu đề không hợp lệ']);
 final byKey={for(final e in chosen)e.value:e.key};
 for(var i=header+1;i<sheet.rows.length;i++){
  final row=sheet.rows[i];
  if(row.every((c)=>c?.text.trim().isEmpty??true))continue;
  XlsxCell? at(String key)=>byKey[key]==null?null:actualCell(row,byKey[key]!);
  final date=actualDate(at('sale_date')),emp=actualText(at('employee_code'),max:80);
  final customer=actualText(at('customer_code'),max:80),product=actualText(at('company_code'),max:80);
  final qty=actualInteger(at('quantity'),min:1,max:1000000000),amount=actualInteger(at('amount'),min:0,max:1000000000000);
  final external=actualText(at('external_ref')),line=byKey.containsKey('line_ref')?actualText(at('line_ref'),max:80):product;
  if(date==null||emp==null||customer==null||product==null||qty==null||amount==null||external==null||line==null){
   errors.add('Dòng ${i+1}: ngày, mã text, số lượng, doanh số hoặc mã chứng từ sai/thiếu');
   continue;
  }
  final key='${external.length}:$external|${line.length}:$line';
  if(!keys.add(key)){errors.add('Dòng ${i+1}: trùng mã chứng từ và mã dòng (cùng mã CTY phải có mã dòng riêng)');continue;}
  output.add({'sale_date':date,'employee_code':emp,'customer_code':customer,
   'company_code':product,'quantity':qty,'amount':amount,'external_ref':external,
   'line_ref':line,'row_number':i+1});
 }
 if(output.isEmpty)errors.add('Không có dòng doanh số hợp lệ');
 if(output.length>1000)errors.add('Tối đa 1.000 dòng mỗi lần nhập');
 return ActualParse(output,errors);
}
