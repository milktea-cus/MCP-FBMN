import 'dart:convert';
import 'dart:js_interop';

// Browser calls are provided by the versioned offline shell in index.html.
// No storage is cleared: the service worker only upgrades its own app shell.
@JS('fbmnCheckPwaUpdate')
external JSPromise<JSString> _checkPwaUpdate(JSString running);
@JS('fbmnActivatePwaUpdate')
external JSPromise<JSBoolean> _activatePwaUpdate();

Future<Map<String,dynamic>> pwaCheckVersion(String running)async{
 final value=await _checkPwaUpdate(running.toJS).toDart;
 final decoded=jsonDecode(value.toDart);
 if(decoded is! Map)throw StateError('Dữ liệu phiên bản không hợp lệ');
 return Map<String,dynamic>.from(decoded);
}
Future<void> pwaActivateUpdate()async{
 await _activatePwaUpdate().toDart;
}
