import 'package:url_launcher/url_launcher.dart';

/// A geographic position supplied for the store profile, not a verified visit.
class CustomerMapPoint {
  final double latitude;
  final double longitude;
  const CustomerMapPoint(this.latitude,this.longitude);
  String get label => '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';
}

bool customerCoordinatesValid(double? lat,double? lon) =>
  lat!=null && lon!=null && lat.isFinite && lon.isFinite &&
  lat>=-90 && lat<=90 && lon>=-180 && lon<=180;

CustomerMapPoint? customerManualPoint(String lat,String lon) {
  // No locale heuristics: decimal point is required for fractional coordinates.
  final a=double.tryParse(lat.trim()),b=double.tryParse(lon.trim());
  return customerCoordinatesValid(a,b)?CustomerMapPoint(a!,b!):null;
}

final _numericPair=RegExp(
  r'^\s*([-+]?(?:\d+(?:\.\d+)?|\.\d+))\s*,\s*([-+]?(?:\d+(?:\.\d+)?|\.\d+))\s*$');
final _atPair=RegExp(
  r'@([-+]?(?:\d+(?:\.\d+)?|\.\d+)),([-+]?(?:\d+(?:\.\d+)?|\.\d+))');
final _googlePlace=RegExp(
  r'!3d([-+]?(?:\d+(?:\.\d+)?|\.\d+))!4d([-+]?(?:\d+(?:\.\d+)?|\.\d+))');

CustomerMapPoint? _pair(String value){
  final match=_numericPair.firstMatch(value);
  if(match==null)return null;
  return customerManualPoint(match.group(1)!,match.group(2)!);
}

/// Parses only allowlisted map URL formats, without fetching a redirect or page.
/// A map center is a proposed point, not proof of the shop's GPS position.
CustomerMapPoint parseCustomerMapLink(String text){
  final raw=text.trim();
  if(raw.isEmpty||raw.length>2048)throw const FormatException('Link bản đồ trống hoặc quá dài');
  final uri=Uri.tryParse(raw);
  if(uri==null)throw const FormatException('Link bản đồ không hợp lệ');
  if(uri.scheme=='geo'&&!uri.hasAuthority){
    final point=_pair(uri.path.split('?').first);
    if(point!=null)return point;
    throw const FormatException('Liên kết geo không có tọa độ hợp lệ');
  }
  if(uri.scheme!='https'||uri.userInfo.isNotEmpty||uri.hasPort||uri.host.isEmpty){
    throw const FormatException('Chỉ hỗ trợ liên kết bản đồ HTTPS');
  }
  final host=uri.host.toLowerCase();
  if(host=='maps.app.goo.gl'||host=='goo.gl'){
    throw const FormatException('Link rút gọn không chứa tọa độ. Hãy mở Maps, sao chép link đầy đủ hoặc nhập tọa độ.');
  }
  final google=<String>{'google.com','www.google.com','maps.google.com',
    'google.com.vn','www.google.com.vn','maps.google.com.vn'};
  final apple=host=='maps.apple.com';
  if(!google.contains(host)&&!apple){
    throw const FormatException('Chỉ hỗ trợ Google Maps, Apple Maps hoặc liên kết geo');
  }
  if(google.contains(host)&&
    !(uri.path.startsWith('/maps')||host.startsWith('maps.')&&uri.path=='/')){
    throw const FormatException('Đường dẫn không phải Google Maps');
  }
  // URL directions and search parameters contain exact coordinates.
  for(final field in const ['destination','query','q','ll','center','daddr']){
    final value=uri.queryParameters[field];
    if(value!=null){
      final point=_pair(value);
      if(point!=null)return point;
    }
  }
  if(apple){
    final a=uri.queryParameters['mlat'],b=uri.queryParameters['mlon'];
    if(a!=null&&b!=null){
      final point=customerManualPoint(a,b);
      if(point!=null)return point;
    }
  }else{
    // Google place position (!3d...!4d...) has priority over viewport (@lat,lon).
    final place=_googlePlace.firstMatch(uri.path);
    if(place!=null){
      final point=customerManualPoint(place.group(1)!,place.group(2)!);
      if(point!=null)return point;
    }
    final view=_atPair.firstMatch(uri.path);
    if(view!=null){
      final point=customerManualPoint(view.group(1)!,view.group(2)!);
      if(point!=null)return point;
    }
  }
  throw const FormatException('Link không chứa tọa độ đọc được. Hãy nhập vĩ độ, kinh độ hoặc sao chép link đầy đủ.');
}

Uri customerDirectionsUri({CustomerMapPoint? point,required String address}){
  final destination=point?.label??address.trim();
  if(destination.isEmpty)throw const FormatException('Khách chưa có địa chỉ hoặc tọa độ');
  return Uri.https('www.google.com','/maps/dir/',{
    'api':'1','destination':destination,'travelmode':'driving',
  });
}
Uri customerPreviewUri(CustomerMapPoint point)=>
  Uri.https('www.google.com','/maps/search/',{'api':'1','query':point.label});

/// Try the installed Maps handler first and use the platform/browser fallback.
Future<bool> launchCustomerMap(Uri url,{
  Future<bool> Function(Uri,LaunchMode)? opener,
})async{
  final open=opener??((uri,mode)=>launchUrl(uri,mode:mode));
  try{if(await open(url,LaunchMode.externalApplication))return true;}catch(_){}
  try{return await open(url,LaunchMode.platformDefault);}catch(_){return false;}
}
