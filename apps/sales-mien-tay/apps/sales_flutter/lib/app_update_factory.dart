import 'app_update_driver.dart';
import 'app_update_driver_stub.dart'
  if (dart.library.io) 'app_update_driver_native.dart' as platform;
AppUpdateDriver createAppUpdateDriver()=>platform.createAppUpdateDriver();
