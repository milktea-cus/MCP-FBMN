import 'dart:html' as html;
import 'dart:convert';
import 'dart:js_util' as js;

Future<Map<String,dynamic>> pwaCheckVersion(String running)async{
 if(!js.hasProperty(html.window,'fbmnCheckPwaUpdate')){
  throw StateError('Trình quản lý PWA chưa sẵn sàng. Hãy mở lại ứng dụng khi có mạng.');
 }
 final response=await js.promiseToFuture<Object?>(
  js.callMethod(html.window,'fbmnCheckPwaUpdate',[running]));
 final result=jsonDecode(response.toString());
 if(result is! Map)throw StateError('Dữ liệu phiên bản không hợp lệ');
 return Map<String,dynamic>.from(result);
}
Future<void> pwaActivateUpdate()async{
 if(!js.hasProperty(html.window,'fbmnActivatePwaUpdate')){
  throw StateError('Bộ cập nhật PWA chưa được tải');
 }
 await js.promiseToFuture<Object?>(js.callMethod(html.window,'fbmnActivatePwaUpdate',[]));
}
