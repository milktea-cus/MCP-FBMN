import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class AndroidPushBridge {
 static const _channel=MethodChannel('field_work/android_push');
 static bool get supported=>!kIsWeb&&defaultTargetPlatform==TargetPlatform.android;
 static Future<Map<String,dynamic>?> status(String owner)async{
  final result=await _channel.invokeMapMethod<String,dynamic>('status',{'owner':owner});
  return result;
 }
 static Future<Map<String,dynamic>> prepare(String owner)async{
  final result=await _channel.invokeMapMethod<String,dynamic>('prepare',{'owner':owner});
  if(result==null||result['token'] is! String||result['binding'] is! String)throw StateError('Thiết bị chưa đăng ký được FCM');
  return result;
 }
 static Future<void> activate(String owner,String binding)async{
  await _channel.invokeMethod<bool>('activate',{'owner':owner,'binding':binding});
 }
 static Future<Map<String,dynamic>> diagnostics(String owner)async=>(await _channel.invokeMapMethod<String,dynamic>('diagnostics',{'owner':owner}))??{};
 static Future<void> settings()async{await _channel.invokeMethod<bool>('settings');}
 static Future<void> localTest(String owner)async{await _channel.invokeMethod<bool>('localTest',{'owner':owner});}
 static Future<String?> disable(String owner)async=>_channel.invokeMethod<String>('disable',{'owner':owner});
}
