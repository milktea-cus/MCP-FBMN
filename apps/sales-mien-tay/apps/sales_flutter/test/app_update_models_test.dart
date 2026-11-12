import 'package:flutter_test/flutter_test.dart';
import 'package:sales_mien_tay/app_update_models.dart';

void main() {
  final sha=List.filled(64,'a').join();
  final signer=List.filled(64,'b').join();
  final release={
    'versionCode':2,'versionName':'1.0.0-rc.2',
    'packageName':fieldWorkAndroidPackage,'size':12000000,
    'sha256':sha,'signerSha256':signer,
    'notes':'Bản cập nhật an toàn','releasedAt':'2026-11-12T00:00:00Z',
  };
  test('accepts new code only with identical installed package and signing cert',(){
    final installed=AndroidInstalledApp.fromJson({
      'versionCode':1,'versionName':'1.0.0-rc.1',
      'packageName':fieldWorkAndroidPackage,'signerSha256':signer,
    });
    final update=AndroidRelease.fromJson(release);
    expect(update.isNewerThan(installed),isTrue);
    expect(update.canUpgradeSafely(installed),isTrue);
    final wrongSigner=AndroidRelease.fromJson({...release,
      'signerSha256':List.filled(64,'c').join()});
    expect(wrongSigner.canUpgradeSafely(installed),isFalse);
    final sameVersion=AndroidInstalledApp.fromJson({
      'versionCode':2,'versionName':'1.0.0-rc.2',
      'packageName':fieldWorkAndroidPackage,'signerSha256':signer,
    });
    expect(update.canUpgradeSafely(sameVersion),isFalse);
  });
  test('rejects foreign package, broken checksum, size and missing signature',(){
    for(final corrupted in [
      {...release,'packageName':'com.evil.replace'},
      {...release,'sha256':'oops'},
      {...release,'signerSha256':''},
      {...release,'size':0},
      {...release,'size':999999999},
      {...release,'versionCode':-1},
      {...release,'versionName':'not a version'},
    ]){
      expect(()=>AndroidRelease.fromJson(corrupted),throwsFormatException);
    }
  });
  test('ticket accepts only same-origin relative APK path with future expiration',(){
    final time=DateTime.now().millisecondsSinceEpoch~/1000;
    expect(AndroidDownloadTicket.fromJson({
      'url':'/api/v1/app/releases/download?versionCode=2&expires=${time+180}',
      'expires':time+180,
    }).expiresAt.isAfter(DateTime.now()),isTrue);
    for(final bad in [
      'https://external.invalid/evil.apk',
      '//external.invalid/evil.apk',
      '/api/v1/customers/1/photos/private',
    ]){
      expect(()=>AndroidDownloadTicket.fromJson({
        'url':bad,'expires':time+180
      }),throwsFormatException);
    }
    expect(()=>AndroidDownloadTicket.fromJson({
      'url':'/api/v1/app/releases/download?expired=yes','expires':time-10
    }),throwsFormatException);
  });
}
