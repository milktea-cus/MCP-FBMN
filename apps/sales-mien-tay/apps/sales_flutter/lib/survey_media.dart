import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:crypto/crypto.dart';

class SurveyMedia{
 final Uint8List image,thumbnail;
 SurveyMedia(this.image,this.thumbnail);
 String get hash=>sha256.convert(image).toString();
 String get thumbnailHash=>sha256.convert(thumbnail).toString();
}
/// Decode and re-encode pixels only, preserving orientation but not EXIF/GPS.
SurveyMedia compressSurveyMedia(Uint8List bytes){
 if(bytes.isEmpty||bytes.length>20*1024*1024)throw StateError('Ảnh nguồn quá 20 MB');
 final decoded=img.decodeImage(bytes);
 if(decoded==null||decoded.width*decoded.height>25000000)throw StateError('Ảnh không hợp lệ hoặc quá lớn');
 final source=img.bakeOrientation(decoded);
 img.Image resize(int max){
  final ratio=source.width>source.height?max/source.width:max/source.height;
  final scaled=ratio<1?img.copyResize(source,width:(source.width*ratio).round().clamp(1,max).toInt(),height:(source.height*ratio).round().clamp(1,max).toInt()):source;
  final clean=img.Image(width:scaled.width,height:scaled.height,numChannels:3);
  img.compositeImage(clean,scaled);
  return clean;
 }
 Uint8List encode(int max,int limit,int quality){
  final clean=resize(max);
  for(var q=quality;q>=35;q-=10){final b=img.encodeJpg(clean,quality:q);if(b.length<=limit)return b;}
  throw StateError('Không nén được ảnh trong giới hạn');
 }
 return SurveyMedia(encode(1600,2*1024*1024,85),encode(320,150*1024,70));
}
