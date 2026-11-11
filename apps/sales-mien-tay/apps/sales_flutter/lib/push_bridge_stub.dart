/// Android native requires FCM. Web Push must never report support on native.
bool supported()=>false;
Future<bool> subscribed() async=>false;
Future<String> enable(String publicKey) async=>throw UnsupportedError('Web Push chỉ hỗ trợ PWA');
Future<String> disable() async=>'';
void badge(int unread) {}
