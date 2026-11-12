import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_update_driver.dart';
import 'app_update_factory.dart';
import 'app_update_models.dart';
import 'session.dart';

/// Only accessible on native Android. The installed package and signer are
/// checked by Android PackageManager, not inferred from the PWA user agent.
class AppUpdatePage extends StatefulWidget {
  final SalesSession session;
  final AppUpdateDriver? driver;
  const AppUpdatePage({super.key,required this.session,this.driver});
  @override State<AppUpdatePage> createState()=>_AppUpdatePageState();
}

class _AppUpdatePageState extends State<AppUpdatePage> {
  late final AppUpdateDriver driver;
  AndroidInstalledApp? installed;
  AndroidRelease? release;
  String? error,notice,readyApk;
  bool checking=false,downloading=false,installing=false;
  bool cancelRequested=false;
  int received=0;

  @override void initState(){
    super.initState();
    driver=widget.driver??createAppUpdateDriver();
    unawaited(checkUpdate());
  }
  @override void dispose(){
    cancelRequested=true;
    driver.cancel();
    super.dispose();
  }
  String describe(Object e){
    if(e is ApiFailure)return e.message;
    if(e is PlatformException)return e.message??'Android không cho phép thao tác này.';
    if(e is FormatException)return e.message;
    if(e is UpdateCanceled)return 'Đã hủy tải bản cập nhật.';
    return 'Không thực hiện được. Kiểm tra mạng và dung lượng rồi thử lại.';
  }

  Future<void> checkUpdate()async{
    if(checking||downloading||installing)return;
    setState((){checking=true;error=null;notice=null;});
    try{
      final current=await driver.installed();
      final response=await widget.session.get('/api/v1/app/releases/latest');
      AndroidRelease? newest;
      if(response['available']==true){
        newest=AndroidRelease.fromJson(Map<String,dynamic>.from(response['release'] as Map));
      }
      if(!mounted)return;
      setState((){
        installed=current;release=newest;
        readyApk=null;received=0;
        if(newest==null)notice='Chưa có bản cập nhật mới.';
        else if(!newest.isNewerThan(current))notice='Ứng dụng đang ở phiên bản mới nhất.';
        else if(!newest.canUpgradeSafely(current)){
          error='APK đang phát hành có chữ ký khác bản anh đang cài. '
            'Không gỡ ứng dụng khi còn dữ liệu chưa đồng bộ. '
            'Cần kiểm tra chữ ký và sao lưu trước khi chuyển sang bản release.';
        }
      });
    }catch(e){
      if(mounted)setState(()=>error=describe(e));
    }finally{if(mounted)setState(()=>checking=false);}
  }

  Future<void> download()async{
    final current=installed,update=release;
    if(downloading||installing||current==null||update==null||
       !update.canUpgradeSafely(current))return;
    setState((){
      downloading=true;cancelRequested=false;
      received=0;error=null;notice=null;readyApk=null;
    });
    try{
      final response=await widget.session.post('/api/v1/app/releases/ticket',
        {'versionCode':update.versionCode});
      final ticket=AndroidDownloadTicket.fromJson(response);
      final path=await driver.download(
        session:widget.session,release:update,ticket:ticket,
        canceled:()=>cancelRequested,
        onProgress:(done,total){
          if(mounted&&!cancelRequested)setState(()=>received=done);
        });
      if(cancelRequested)throw const UpdateCanceled();
      await driver.inspect(path,update);
      if(mounted)setState((){
        readyApk=path;
        notice='Đã kiểm tra dung lượng, SHA-256, package và chữ ký. Sẵn sàng cài đè.';
      });
    }catch(e){
      if(mounted)setState(()=>error=describe(e));
    }finally{if(mounted)setState(()=>downloading=false);}
  }

  Future<void> install()async{
    final file=readyApk,update=release;
    if(file==null||update==null||installing||downloading)return;
    setState((){installing=true;error=null;notice=null;});
    try{
      final opened=await driver.install(file,update);
      if(mounted)setState(()=>notice=opened
        ?'Trình cài đặt Android đã mở. Xác nhận cài đè; không gỡ ứng dụng.'
        :'Hãy bật quyền cài ứng dụng cho Field Work trong Android rồi bấm Cài đặt lần nữa.');
    }catch(e){if(mounted)setState(()=>error=describe(e));}
    finally{if(mounted)setState(()=>installing=false);}
  }

  Widget line(String label,String value)=>Padding(
    padding:const EdgeInsets.symmetric(vertical:5),
    child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Expanded(child:Text(label,style:Theme.of(context).textTheme.bodySmall)),
      Expanded(flex:2,child:Text(value,textAlign:TextAlign.end,
        maxLines:2,overflow:TextOverflow.ellipsis)),
    ]),
  );

  @override Widget build(BuildContext context){
    final current=installed,next=release;
    final safe=next!=null&&current!=null&&next.canUpgradeSafely(current);
    final newer=next!=null&&current!=null&&next.isNewerThan(current);
    final busy=checking||downloading||installing;
    final size=next==null?'—':'${(next.size/1024/1024).toStringAsFixed(1)} MB';
    return Scaffold(
      appBar:AppBar(title:const Text('Cập nhật ứng dụng')),
      body:ListView(padding:const EdgeInsets.all(16),children:[
        Card(child:Padding(padding:const EdgeInsets.all(14),
          child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
            Text('Field Work · Android',style:Theme.of(context).textTheme.titleMedium),
            const SizedBox(height:10),
            line('Đang cài',current==null?'Đang kiểm tra…':
              '${current.versionName} (${current.versionCode})'),
            line('Bản mới',next==null?'Chưa có':'${next.versionName} (${next.versionCode})'),
            line('Dung lượng',size),
            if(next!=null&&next.notes.trim().isNotEmpty)...[
              const Divider(),Text(next.notes,style:Theme.of(context).textTheme.bodyMedium),
            ],
            if(downloading)...[
              const SizedBox(height:12),
              LinearProgressIndicator(value:next==null||next.size==0?null:
                (received/next.size).clamp(0.0,1.0)),
              const SizedBox(height:6),
              Text('${(received/1024/1024).toStringAsFixed(1)} / $size'),
            ],
          ]))),
        const SizedBox(height:12),
        if(error!=null)Padding(padding:const EdgeInsets.only(bottom:12),
          child:Text(error!,style:TextStyle(color:Theme.of(context).colorScheme.error))),
        if(notice!=null)Padding(padding:const EdgeInsets.only(bottom:12),
          child:Text(notice!)),
        Wrap(spacing:8,runSpacing:8,children:[
          OutlinedButton.icon(
            onPressed:busy?null:checkUpdate,
            icon:const Icon(Icons.refresh),
            label:Text(checking?'Đang kiểm tra…':'Kiểm tra')),
          if(safe&&readyApk==null&&!downloading)
            FilledButton.icon(
              onPressed:busy?null:download,
              icon:const Icon(Icons.download_outlined),
              label:Text(error==null?'Tải':'Thử lại')),
          if(downloading)OutlinedButton.icon(
            onPressed:(){
              cancelRequested=true;
              driver.cancel();
            },
            icon:const Icon(Icons.close),
            label:const Text('Hủy')),
          if(readyApk!=null)
            FilledButton.icon(
              onPressed:busy?null:install,
              icon:const Icon(Icons.install_mobile_outlined),
              label:Text(installing?'Đang mở…':'Cài đặt')),
        ]),
        const SizedBox(height:12),
        if(newer&&!safe)Text('Bản cập nhật đang bị chặn để bảo vệ dữ liệu trên máy.',
          style:Theme.of(context).textTheme.bodySmall),
        const Text('Android sẽ yêu cầu xác nhận cài đặt. '
          'Không tự gỡ ứng dụng hoặc xóa dữ liệu SQLite/đơn nháp. '
          'Chỉ cập nhật khi đã đồng bộ các thay đổi quan trọng.'),
      ]),
    );
  }
}
