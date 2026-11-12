import 'app_update_models.dart';
import 'session.dart';

typedef DownloadProgress=void Function(int received,int total);

abstract class AppUpdateDriver {
  Future<AndroidInstalledApp> installed();
  Future<String> download({
    required SalesSession session,
    required AndroidRelease release,
    required AndroidDownloadTicket ticket,
    required DownloadProgress onProgress,
    required bool Function() canceled,
  });
  Future<void> inspect(String path,AndroidRelease release);
  Future<bool> install(String path,AndroidRelease release);
  void cancel();
}

class UpdateCanceled implements Exception {
  const UpdateCanceled();
  @override String toString() => 'Đã hủy tải bản cập nhật';
}
