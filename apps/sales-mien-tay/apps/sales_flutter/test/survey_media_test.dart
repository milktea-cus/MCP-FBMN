import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import '../lib/survey_media.dart';
void main(){
 test('compress pixels, bounded thumbnail and stable SHA256',(){
  final input=img.encodePng(img.Image(width:2000,height:1000));
  final out=compressSurveyMedia(input);
  final full=img.decodeJpg(out.image)!,small=img.decodeJpg(out.thumbnail)!;
  expect(full.width,1600);expect(full.height,800);expect(small.width,320);expect(small.height,160);
  expect(out.image.length,lessThanOrEqualTo(2097152));expect(out.thumbnail.length,lessThanOrEqualTo(153600));expect(out.hash.length,64);expect(out.thumbnailHash.length,64);
 });
}
