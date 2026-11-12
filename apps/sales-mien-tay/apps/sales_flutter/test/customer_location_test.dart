import 'package:flutter_test/flutter_test.dart';
import 'package:idb_shim/idb_shim.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sales_mien_tay/customer_location.dart';
import 'package:sales_mien_tay/offline_queue.dart';
import 'package:sales_mien_tay/session.dart';

class OfflineSession extends SalesSession {
  @override Future<Map<String,dynamic>> get(String path) async=>
    throw const ApiFailure(503,'offline');
}

void main(){
  test('manual latitude longitude accept zero and reject malformed numbers',(){
    expect(customerManualPoint('0','0')?.label,'0.000000, 0.000000');
    expect(customerManualPoint('-90','180')?.label,'-90.000000, 180.000000');
    expect(customerManualPoint('10.36025','106.36012')?.latitude,10.36025);
    for(final pair in [('91','106'),('-91','106'),('10','181'),
      ('foo','106'),('10,2','106'),('NaN','106'),('','106')]){
      expect(customerManualPoint(pair.$1,pair.$2),isNull,reason:'$pair');
    }
  });
  test('map URL parser accepts exact coordinate formats',(){
    final urls={
      'https://www.google.com/maps?q=10.36025%2C106.36012':'10.360250, 106.360120',
      'https://maps.google.com/?q=0%2C0':'0.000000, 0.000000',
      'https://www.google.com/maps/dir/?api=1&destination=10.1%2C106.2':'10.100000, 106.200000',
      'https://www.google.com/maps/place/Test/@10.333,106.222,17z':'10.333000, 106.222000',
      'https://www.google.com/maps/place/Test/data=!3m1!4b1!3d10.22!4d106.56':'10.220000, 106.560000',
      'https://www.google.com/maps/search/?api=1&query=-10.1%2C-106.5':'-10.100000, -106.500000',
      'https://maps.apple.com/?ll=10.3%2C106.4':'10.300000, 106.400000',
      'geo:10.24,106.44':'10.240000, 106.440000',
    };
    for(final row in urls.entries){
      expect(parseCustomerMapLink(row.key).label,row.value,reason:row.key);
    }
  });
  test('short, untrusted, misleading and non-coordinate URLs are rejected',(){
    final bad=[
      'https://maps.app.goo.gl/abc123','https://goo.gl/maps/abc',
      'https://www.google.com/maps/place/SomeShop',
      'https://www.google.com/url?q=https://www.google.com/maps',
      'https://www.google.com.evil.example/maps?q=10,106',
      'https://evil.example/maps?q=10,106','http://www.google.com/maps?q=10,106',
      'https://user:password@www.google.com/maps?q=10,106',
      'https://www.google.com:8443/maps?q=10,106',
      'https://www.google.com/maps?q=95,106',
      'https://www.google.com/maps?q=10,181','geo:abc,def',
      '',List.filled(2050,'x').join(),
    ];
    for(final url in bad){
      expect(()=>parseCustomerMapLink(url),throwsFormatException,reason:url);
    }
  });
  test('directions use driving GPS and address-only fallback, never check-in',(){
    final gps=customerDirectionsUri(
      point:const CustomerMapPoint(0,106.4),address:'Một địa chỉ');
    expect(gps.scheme,'https');
    expect(gps.host,'www.google.com');
    expect(gps.path,'/maps/dir/');
    expect(gps.queryParameters['destination'],'0.000000, 106.400000');
    expect(gps.queryParameters['travelmode'],'driving');
    final address=customerDirectionsUri(address:'1 Lê Lợi, Mỹ Tho, Việt Nam');
    expect(address.queryParameters['destination'],'1 Lê Lợi, Mỹ Tho, Việt Nam');
    expect(customerPreviewUri(const CustomerMapPoint(10,106)).queryParameters['query'],
      '10.000000, 106.000000');
  });
  test('open directions tries installed Maps, falls back to browser on refusal',()async{
    final modes=<LaunchMode>[];
    final uri=customerDirectionsUri(address:'Mỹ Tho');
    final ok=await launchCustomerMap(uri,opener:(url,mode)async{
      expect(url,uri);
      modes.add(mode);
      return mode==LaunchMode.platformDefault;
    });
    expect(ok,isTrue);
    expect(modes,[LaunchMode.externalApplication,LaunchMode.platformDefault]);
    modes.clear();
    expect(await launchCustomerMap(uri,opener:(url,mode)async{
      modes.add(mode);
      if(mode==LaunchMode.externalApplication)throw StateError('no Maps app');
      return false;
    }),isFalse);
    expect(modes,[LaunchMode.externalApplication,LaunchMode.platformDefault]);
  });
  test('PWA IndexedDB/native SQLite outbox payload preserves provenance per account',()async{
    final factory=newIdbFactoryMemory();
    final queue=OfflineQueue(OfflineSession(),'sales-a','scope-a',factory:factory);
    await queue.enqueue('/api/v1/customers/11111111-1111-4111-8111-111111111111',{
      'version':3,'location_source':'map_link','latitude':10.3,
      'longitude':106.2,'location_accuracy_m':null,
      'location_consent':true,'location_override_confirmed':true,
    },method:'PATCH');
    final restored=OfflineQueue(OfflineSession(),'sales-a','scope-a',factory:factory);
    await restored.reload();
    expect(restored.pending.single['method'],'PATCH');
    expect(restored.pending.single['payload']['location_source'],'map_link');
    expect(restored.pending.single['payload']['longitude'],106.2);
    final other=OfflineQueue(OfflineSession(),'sales-b','scope-a',factory:factory);
    await other.reload();
    expect(other.pending,isEmpty);
    final revoked=OfflineQueue(OfflineSession(),'sales-a','scope-b',factory:factory);
    await revoked.reload();
    expect(revoked.pending,isEmpty);
    queue.dispose();restored.dispose();other.dispose();revoked.dispose();
  });
}
