import 'dart:js_util' as js;

Object get _bridge=>js.getProperty(js.globalThis,'FieldWorkPush');
bool supported(){try{return js.callMethod(_bridge,'supported',[])==true;}catch(_){return false;}}
Future<bool> subscribed() async{
 try{return await js.promiseToFuture<bool>(js.callMethod(_bridge,'subscribed',[]));}
 catch(_){return false;}
}
Future<String> enable(String key) async=>
 (await js.promiseToFuture<Object?>(js.callMethod(_bridge,'enable',[key])))?.toString()??'';
Future<String> disable() async=>
 (await js.promiseToFuture<Object?>(js.callMethod(_bridge,'disable',[])))?.toString()??'';
void badge(int count){try{js.callMethod(_bridge,'badge',[count]);}catch(_){}}
