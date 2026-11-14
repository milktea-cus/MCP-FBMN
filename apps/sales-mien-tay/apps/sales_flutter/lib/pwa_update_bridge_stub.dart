Future<Map<String,dynamic>> pwaCheckVersion(String running)async=>{'supported':false,'running':running};
Future<void> pwaActivateUpdate()async=>throw UnsupportedError('Chỉ hỗ trợ PWA');
