import 'dart:js_interop';

@JS('FieldWorkPush.supported')
external JSBoolean _supported();
@JS('FieldWorkPush.subscribed')
external JSPromise<JSBoolean> _subscribed();
@JS('FieldWorkPush.existing')
external JSPromise<JSString> _existing();
@JS('FieldWorkPush.enable')
external JSPromise<JSString> _enable(JSString publicKey);
@JS('FieldWorkPush.disable')
external JSPromise<JSString> _disable();
@JS('FieldWorkPush.badge')
external void _badge(JSNumber unread);

bool supported(){try{return _supported().toDart;}catch(_){return false;}}
Future<bool> subscribed() async{
 try{return (await _subscribed().toDart).toDart;}
 catch(_){return false;}
}
Future<String> existing() async=>(await _existing().toDart).toDart;
Future<String> enable(String key) async=>(await _enable(key.toJS).toDart).toDart;
Future<String> disable() async=>(await _disable().toDart).toDart;
void badge(int unread){try{_badge(unread.toJS);}catch(_){}}
