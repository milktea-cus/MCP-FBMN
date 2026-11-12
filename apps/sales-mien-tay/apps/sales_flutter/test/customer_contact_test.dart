import 'package:flutter_test/flutter_test.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sales_mien_tay/customers.dart';

void main(){
  test('tel links sanitize phone input, rejecting arbitrary URLs',(){
    expect(customerCallUri('090 123-4567')?.toString(),'tel:0901234567');
    expect(customerCallUri('+84 (90) 123 4567')?.toString(),'tel:+84901234567');
    for(final value in <String?>[null,'','abc','https://evil.test','0123',
      '0901234567?x=1','000000000000000000000']){
      expect(customerCallUri(value),isNull,reason:'$value');
    }
  });
  test('Zalo link requires Vietnamese mobile, not a landline',(){
    expect(customerZaloUri('090 123 4567')?.toString(),'https://zalo.me/0901234567');
    expect(customerZaloUri('+84 90 123 4567')?.toString(),'https://zalo.me/0901234567');
    expect(customerZaloUri('84901234567')?.toString(),'https://zalo.me/0901234567');
    for(final value in <String?>[null,'','12345678','02812345678',
      'https://zalo.me/0901234567','123abc','+33123456789']){
      expect(customerZaloUri(value),isNull,reason:'$value');
    }
  });
  test('Zalo tries external handler then browser fallback, reports failures',()async{
    final uri=customerZaloUri('0901234567')!;
    final modes=<LaunchMode>[];
    final ok=await launchCustomerZalo(uri,opener:(target,mode)async{
      expect(target,uri);
      modes.add(mode);
      if(mode==LaunchMode.externalApplication)throw StateError('not installed');
      return mode==LaunchMode.platformDefault;
    });
    expect(ok,isTrue);
    expect(modes,[LaunchMode.externalApplication,LaunchMode.platformDefault]);
    modes.clear();
    expect(await launchCustomerZalo(uri,opener:(target,mode)async{
      modes.add(mode);
      return false;
    }),isFalse);
    expect(modes,[LaunchMode.externalApplication,LaunchMode.platformDefault]);
  });
}
