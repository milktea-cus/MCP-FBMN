import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'app_update_driver.dart';
import 'app_update_models.dart';
import 'session.dart';

AppUpdateDriver createAppUpdateDriver()=>NativeAppUpdateDriver();

class NativeAppUpdateDriver implements AppUpdateDriver {
  static const platform=MethodChannel('field_work/app_update');
  http.Client? _downloadClient;

  @override Future<AndroidInstalledApp> installed()async{
    if(Platform.isAndroid!=true)throw UnsupportedError('Chỉ hỗ trợ Android');
    final data=await platform.invokeMapMethod<dynamic,dynamic>('installedInfo');
    if(data==null)throw const FormatException('Không đọc được phiên bản Android');
    return AndroidInstalledApp.fromJson(data);
  }

  @override Future<String> download({
    required SalesSession session,
    required AndroidRelease release,
    required AndroidDownloadTicket ticket,
    required DownloadProgress onProgress,
    required bool Function() canceled,
  })async{
    if(!Platform.isAndroid)throw UnsupportedError('Chỉ hỗ trợ Android');
    if(ticket.expiresAt.isBefore(DateTime.now()))throw const FormatException('Liên kết tải đã hết hạn');
    final destination=session.uri(ticket.path);
    if(destination.origin!=salesOrigin||
       destination.path!='/api/v1/app/releases/download'||
       destination.scheme!='https')throw const FormatException('Nguồn tải không được phép');

    final dir=await getTemporaryDirectory();
    final partial=File('${dir.path}/field-work-${release.versionCode}.apk.part');
    final ready=File('${dir.path}/field-work-${release.versionCode}.apk');
    if(await ready.exists()){
      if(await ready.length()==release.size&&
         (await sha256.bind(ready.openRead()).first).toString()==release.sha256){
        onProgress(release.size,release.size);
        return ready.path;
      }
      await ready.delete();
    }
    var offset=await partial.exists()?await partial.length():0;
    if(offset>release.size){
      await partial.delete();offset=0;
    }
    if(offset==release.size&&offset>0){
      final hash=(await sha256.bind(partial.openRead()).first).toString();
      if(hash==release.sha256){
        await partial.rename(ready.path);
        onProgress(release.size,release.size);
        return ready.path;
      }
      await partial.delete();offset=0;
    }
    final client=http.Client();
    _downloadClient=client;
    RandomAccessFile? target;
    try{
      if(canceled())throw const UpdateCanceled();
      final request=http.Request('GET',destination);
      request.headers.addAll(sessionHeaders(session.cookie));
      if(offset>0)request.headers['Range']='bytes=$offset-';
      final stream=await client.send(request).timeout(const Duration(seconds:25));
      if(stream.statusCode==401||stream.statusCode==403)
        throw const ApiFailure(403,'Phiên tải hết hạn. Hãy bấm Tải lại.');
      if(stream.statusCode!=200&&stream.statusCode!=206)
        throw ApiFailure(stream.statusCode,'Không tải được bản cập nhật. Vui lòng thử lại.');
      if(stream.statusCode==206){
        final expected='bytes $offset-${release.size-1}/${release.size}';
        if(offset<=0||stream.headers['content-range']!=expected)
          throw const FormatException('Máy chủ trả sai phần dữ liệu tiếp tục');
      }else if(offset>0){
        // Fail closed if the server unexpectedly ignores Range; restart safely.
        await partial.delete();
        offset=0;
      }
      target=await partial.open(mode:offset>0?FileMode.append:FileMode.write);
      var written=offset;
      onProgress(written,release.size);
      await for(final chunk in stream.stream.timeout(const Duration(seconds:30))){
        if(canceled())throw const UpdateCanceled();
        await target.writeFrom(chunk);
        written+=chunk.length;
        if(written>release.size)throw const FormatException('Tệp APK vượt dung lượng dự kiến');
        onProgress(written,release.size);
      }
      await target.flush();
      await target.close();target=null;
      if(canceled())throw const UpdateCanceled();
      if(written!=release.size)throw const FormatException('APK tải chưa đủ dung lượng');
      final actual=(await sha256.bind(partial.openRead()).first).toString();
      if(actual!=release.sha256){
        await partial.delete();
        throw const FormatException('APK không khớp SHA-256, đã xóa tệp lỗi');
      }
      await partial.rename(ready.path);
      onProgress(release.size,release.size);
      return ready.path;
    }on UpdateCanceled{
      if(target!=null){await target.close();target=null;}
      if(await partial.exists())await partial.delete();
      rethrow;
    }on FileSystemException{
      throw const FileSystemException('Không ghi được APK. Kiểm tra dung lượng bộ nhớ.');
    }finally{
      if(target!=null)await target.close();
      client.close();
      if(identical(_downloadClient,client))_downloadClient=null;
    }
  }

  Map<String,dynamic> _params(String path,AndroidRelease release)=> {
    'path':path,
    'versionCode':release.versionCode,
    'sha256':release.sha256,
    'signerSha256':release.signerSha256,
  };

  @override Future<void> inspect(String path,AndroidRelease release)async{
    final values=await platform.invokeMapMethod<dynamic,dynamic>(
      'inspectApk',_params(path,release));
    if(values==null||values['versionCode']!=release.versionCode||
       values['packageName']!=release.packageName||
       values['signerSha256']!=release.signerSha256)
      throw const FormatException('Android không xác minh được bản cập nhật');
  }

  @override Future<bool> install(String path,AndroidRelease release)async{
    // The native side repeats package, cert, code, hash validation just before
    // handing the file to Android's OS-controlled installer.
    final values=await platform.invokeMapMethod<dynamic,dynamic>(
      'installApk',_params(path,release));
    return values?['installerOpened']==true;
  }

  @override void cancel(){_downloadClient?.close();}
}
