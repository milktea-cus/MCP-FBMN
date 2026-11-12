/// APK metadata is untrusted until both R2 metadata and the native Android
/// PackageManager agree with this app's identity and signing certificate.
const fieldWorkAndroidPackage='com.example.sales_mien_tay';

class AndroidInstalledApp {
  final String packageName,versionName,signerSha256;
  final int versionCode;
  const AndroidInstalledApp({required this.packageName,required this.versionName,
    required this.signerSha256,required this.versionCode});
  factory AndroidInstalledApp.fromJson(Map<dynamic,dynamic> data) {
    final code=data['versionCode'],hash=data['signerSha256'];
    if(data['packageName']!=fieldWorkAndroidPackage||code is! int||code<1||
       hash is! String||!RegExp(r'^[a-f0-9]{64}$').hasMatch(hash))
      throw const FormatException('Thông tin ứng dụng trên máy không hợp lệ');
    return AndroidInstalledApp(packageName:fieldWorkAndroidPackage,
      versionName:data['versionName']?.toString()??'',versionCode:code,signerSha256:hash);
  }
}

class AndroidRelease {
  final String packageName,versionName,sha256,signerSha256,notes,releasedAt;
  final int versionCode,size;
  const AndroidRelease({required this.packageName,required this.versionName,
    required this.versionCode,required this.size,required this.sha256,
    required this.signerSha256,required this.notes,required this.releasedAt});

  factory AndroidRelease.fromJson(Map<String,dynamic> json) {
    final code=json['versionCode'],size=json['size'];
    final sha=json['sha256'],signer=json['signerSha256'];
    if(json['packageName']!=fieldWorkAndroidPackage ||
       code is! int||code<2||code>100000000||
       size is! int||size<4096||size>250*1024*1024||
       sha is! String||!RegExp(r'^[a-f0-9]{64}$').hasMatch(sha)||
       signer is! String||!RegExp(r'^[a-f0-9]{64}$').hasMatch(signer)||
       json['versionName'] is! String||json['versionName'].toString().length>48||
       !RegExp(r'^[0-9]+\.[0-9]+\.[0-9]+(?:-[A-Za-z0-9.]+)?$')
           .hasMatch(json['versionName'] as String)||
       json['notes'] is! String||json['notes'].toString().length>2000)
      throw const FormatException('Thông tin APK từ máy chủ chưa hợp lệ');
    return AndroidRelease(
      packageName:fieldWorkAndroidPackage,versionName:json['versionName'],
      versionCode:code,size:size,sha256:sha,signerSha256:signer,
      notes:json['notes'],releasedAt:json['releasedAt']?.toString()??'');
  }
  bool isNewerThan(AndroidInstalledApp installed)=>versionCode>installed.versionCode;
  bool canUpgradeSafely(AndroidInstalledApp installed)=>
    isNewerThan(installed)&&packageName==installed.packageName&&
    signerSha256==installed.signerSha256;
}

class AndroidDownloadTicket {
  final String path;
  final DateTime expiresAt;
  const AndroidDownloadTicket(this.path,this.expiresAt);
  factory AndroidDownloadTicket.fromJson(Map<String,dynamic> json) {
    final p=json['url'],exp=json['expires'];
    if(p is! String||!p.startsWith('/api/v1/app/releases/download?')||
       p.length>700||Uri.tryParse(p)?.hasAuthority==true||
       exp is! int||DateTime.fromMillisecondsSinceEpoch(exp*1000).isBefore(DateTime.now()))
      throw const FormatException('Liên kết tải APK không hợp lệ');
    return AndroidDownloadTicket(p,DateTime.fromMillisecondsSinceEpoch(exp*1000));
  }
}
