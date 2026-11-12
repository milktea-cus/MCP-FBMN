import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sales_mien_tay/app_update_driver.dart';
import 'package:sales_mien_tay/app_update_models.dart';
import 'package:sales_mien_tay/app_update_page.dart';
import 'package:sales_mien_tay/session.dart';

class UpdateSession extends SalesSession {
  final String signer;
  UpdateSession(this.signer);
  @override Future<Map<String,dynamic>> get(String path)async{
    expect(path,'/api/v1/app/releases/latest');
    return {'available':true,'release':{
      'versionCode':2,'versionName':'1.0.0-rc.2','size':12000000,
      'packageName':fieldWorkAndroidPackage,
      'sha256':List.filled(64,'a').join(),'signerSha256':signer,
      'notes':'Sửa lỗi và tăng tốc','releasedAt':'2026-11-12T00:00:00Z',
    }};
  }
  @override Future<Map<String,dynamic>> post(String path,Map<String,dynamic> data)async{
    expect(path,'/api/v1/app/releases/ticket');
    expect(data['versionCode'],2);
    final expiry=DateTime.now().millisecondsSinceEpoch~/1000+300;
    return {'url':'/api/v1/app/releases/download?versionCode=2&expires=$expiry',
      'expires':expiry};
  }
}

class UpdateProbe implements AppUpdateDriver {
  final String signer;
  int installs=0,downloads=0,inspections=0;
  UpdateProbe(this.signer);
  @override Future<AndroidInstalledApp> installed()async=>
    AndroidInstalledApp.fromJson({'versionCode':1,'versionName':'1.0.0-rc.1',
      'packageName':fieldWorkAndroidPackage,'signerSha256':signer});
  @override Future<String> download({required SalesSession session,
      required AndroidRelease release,required AndroidDownloadTicket ticket,
      required DownloadProgress onProgress,required bool Function() canceled})async{
    downloads++;onProgress(release.size,release.size);
    return '/private/cache/field-work-2.apk';
  }
  @override Future<void> inspect(String path,AndroidRelease release)async{
    inspections++;expect(path,contains('field-work-2.apk'));
  }
  @override Future<bool> install(String path,AndroidRelease release)async{
    installs++;return true;
  }
  @override void cancel(){}
}

void main(){
  for(final width in [360.0,390.0,430.0]){
    testWidgets('native update flow fits ${width.toInt()}px dark/light', (tester)async{
      tester.view.devicePixelRatio=1;
      tester.view.physicalSize=Size(width,844);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final signer=List.filled(64,'b').join(),probe=UpdateProbe(List.filled(64,'b').join());
      await tester.pumpWidget(MaterialApp(
        theme:ThemeData(useMaterial3:true),
        home:AppUpdatePage(session:UpdateSession(signer),driver:probe),
      ));
      await tester.pumpAndSettle();
      expect(find.textContaining('1.0.0-rc.1'),findsOneWidget);
      expect(find.textContaining('1.0.0-rc.2'),findsOneWidget);
      await tester.tap(find.text('Tải'));
      await tester.pumpAndSettle();
      expect(probe.downloads,1);
      expect(probe.inspections,1);
      expect(find.text('Cài đặt'),findsOneWidget);
      await tester.tap(find.text('Cài đặt'));
      await tester.pumpAndSettle();
      expect(probe.installs,1);
      expect(tester.takeException(),isNull);
    });
  }
  testWidgets('different signing certificate blocks APK download', (tester)async{
    final probe=UpdateProbe(List.filled(64,'a').join());
    await tester.pumpWidget(MaterialApp(home:AppUpdatePage(
      session:UpdateSession(List.filled(64,'b').join()),driver:probe)));
    await tester.pumpAndSettle();
    expect(find.textContaining('chữ ký khác'),findsWidgets);
    expect(find.text('Tải'),findsNothing);
    expect(probe.downloads,0);
    expect(tester.takeException(),isNull);
  });
}
