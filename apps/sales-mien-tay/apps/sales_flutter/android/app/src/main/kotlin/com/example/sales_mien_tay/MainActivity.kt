package com.example.sales_mien_tay

import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.security.MessageDigest

/** Android-only APK validation. All downloads stay inside this app's cache. */
class MainActivity : FlutterActivity() {
    private val channelName = "field_work/app_update"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "installedInfo" -> {
                        try { result.success(installedInfo()) }
                        catch (_: Exception) { result.error("PACKAGE_ERROR", "Không đọc được phiên bản đang cài", null) }
                    }
                    "inspectApk", "installApk" -> {
                        val path = call.argument<String>("path")
                        val hash = call.argument<String>("sha256")
                        val signer = call.argument<String>("signerSha256")
                        val version = call.argument<Number>("versionCode")?.toLong()
                        Thread {
                            try {
                                val details = inspect(path, hash, signer, version)
                                runOnUiThread {
                                    if (call.method == "inspectApk") result.success(details)
                                    else installVerified(path!!, result)
                                }
                            } catch (e: Exception) {
                                runOnUiThread {
                                    result.error("APK_REJECTED", e.message ?: "APK không hợp lệ", null)
                                }
                            }
                        }.start()
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun apkVersion(info: PackageInfo): Long =
        if (Build.VERSION.SDK_INT >= 28) info.longVersionCode else info.versionCode.toLong()

    @Suppress("DEPRECATION")
    private fun readPackage(path: String?): PackageInfo {
        val pm = packageManager
        val flags = if (Build.VERSION.SDK_INT >= 28)
            PackageManager.GET_SIGNING_CERTIFICATES else PackageManager.GET_SIGNATURES
        return if (path == null) pm.getPackageInfo(packageName, flags)
        else pm.getPackageArchiveInfo(path, flags)
            ?: throw SecurityException("Không đọc được gói APK")
    }

    @Suppress("DEPRECATION")
    private fun signerHash(info: PackageInfo): String {
        val signatures = if (Build.VERSION.SDK_INT >= 28)
            info.signingInfo?.apkContentsSigners else info.signatures
        if (signatures == null || signatures.size != 1)
            throw SecurityException("Không xác minh được chữ ký ứng dụng")
        return sha256(signatures[0].toByteArray())
    }

    private fun sha256(bytes: ByteArray): String =
        MessageDigest.getInstance("SHA-256").digest(bytes)
            .joinToString("") { "%02x".format(it) }

    private fun sha256(file: File): String {
        val digest = MessageDigest.getInstance("SHA-256")
        FileInputStream(file).use { input ->
            val buffer = ByteArray(256 * 1024)
            while (true) {
                val read = input.read(buffer)
                if (read < 0) break
                digest.update(buffer, 0, read)
            }
        }
        return digest.digest().joinToString("") { "%02x".format(it) }
    }

    private fun apkInCache(path: String?): File {
        if (path == null || !path.endsWith(".apk"))
            throw SecurityException("Đường dẫn APK không hợp lệ")
        val file = File(path).canonicalFile
        val root = cacheDir.canonicalFile.path + File.separator
        if (!file.path.startsWith(root) || !file.isFile || file.length() < 4096 ||
            file.length() > 250L * 1024 * 1024)
            throw SecurityException("Chỉ cho phép APK đã tải vào bộ nhớ tạm của ứng dụng")
        return file
    }

    private fun installedInfo(): Map<String, Any> {
        val own = readPackage(null)
        return mapOf(
            "packageName" to packageName,
            "versionCode" to apkVersion(own),
            "versionName" to (own.versionName ?: ""),
            "signerSha256" to signerHash(own)
        )
    }

    private fun inspect(path: String?, expectedHash: String?,
                        expectedSigner: String?, expectedVersion: Long?): Map<String, Any> {
        if (expectedHash == null || !expectedHash.matches(Regex("^[a-f0-9]{64}$")) ||
            expectedSigner == null || !expectedSigner.matches(Regex("^[a-f0-9]{64}$")) ||
            expectedVersion == null || expectedVersion <= 0)
            throw SecurityException("Thiếu dữ liệu xác minh APK")
        val apk = apkInCache(path)
        val own = readPackage(null)
        val candidate = readPackage(apk.path)
        if (candidate.packageName != packageName)
            throw SecurityException("APK không thuộc ứng dụng Field Work đang cài")
        val currentCode = apkVersion(own)
        val newCode = apkVersion(candidate)
        if (newCode <= currentCode || newCode != expectedVersion)
            throw SecurityException("Phiên bản APK không mới hơn bản đang cài")
        val currentSigner = signerHash(own)
        val apkSigner = signerHash(candidate)
        if (apkSigner != currentSigner)
            throw SecurityException("Chữ ký APK khác ứng dụng đang cài. Không gỡ app khi còn dữ liệu chưa đồng bộ.")
        if (apkSigner != expectedSigner)
            throw SecurityException("Chữ ký APK không khớp bản phát hành")
        if (sha256(apk) != expectedHash)
            throw SecurityException("Tệp APK lỗi hoặc không khớp mã SHA-256")
        return mapOf(
            "packageName" to candidate.packageName,
            "versionCode" to newCode,
            "versionName" to (candidate.versionName ?: ""),
            "signerSha256" to apkSigner
        )
    }

    private fun installVerified(path: String, result: MethodChannel.Result) {
        try {
            if (Build.VERSION.SDK_INT >= 26 && !packageManager.canRequestPackageInstalls()) {
                val settings = Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                    Uri.parse("package:$packageName"))
                startActivity(settings)
                result.success(mapOf("permissionRequested" to true))
                return
            }
            val apk = apkInCache(path)
            val uri = FileProvider.getUriForFile(
                this, "$packageName.apkprovider", apk)
            val intent = Intent(Intent.ACTION_VIEW)
                .setDataAndType(uri, "application/vnd.android.package-archive")
                .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
            result.success(mapOf("installerOpened" to true))
        } catch (_: ActivityNotFoundException) {
            result.error("INSTALLER_UNAVAILABLE", "Không tìm được trình cài APK trên thiết bị", null)
        } catch (_: Exception) {
            result.error("INSTALLER_ERROR", "Không mở được trình cài đặt Android", null)
        }
    }
}
