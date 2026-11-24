package com.example.sales_mien_tay

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.provider.Settings
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import com.google.firebase.messaging.FirebaseMessaging
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.UUID

internal object FieldPushState {
    const val channel = "field_work_updates"
    const val tag = "field_work_push"
    fun prefs(context: Context) = context.getSharedPreferences("field_work_fcm", Context.MODE_PRIVATE)
    fun createChannel(context: Context) {
        if (Build.VERSION.SDK_INT >= 26) {
            (context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).createNotificationChannel(
                NotificationChannel(channel, "Thông báo Field Work", NotificationManager.IMPORTANCE_HIGH).apply {
                    description = "Thông báo nghiệp vụ mới. Không hiển thị thông tin khách hàng."
                    lockscreenVisibility = android.app.Notification.VISIBILITY_PRIVATE
                    setSound(RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION),
                        AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_NOTIFICATION).setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION).build())
                    enableVibration(true)
                })
        }
    }
    fun allowed(context: Context): Boolean {
        if (Build.VERSION.SDK_INT >= 33 &&
            ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) return false
        if (!NotificationManagerCompat.from(context).areNotificationsEnabled()) return false
        return Build.VERSION.SDK_INT < 26 ||
            (context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).getNotificationChannel(channel)?.importance != NotificationManager.IMPORTANCE_NONE
    }
    fun clear(context: Context): String? {
        val p = prefs(context)
        val old = p.getString("binding", null)
        p.edit().clear().commit()
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= 23) manager.activeNotifications.filter { it.tag == tag }.forEach { manager.cancel(tag, it.id) }
        else manager.cancel(tag, 1)
        runCatching { FirebaseMessaging.getInstance().isAutoInitEnabled = false }
        return old
    }
}

internal class FieldPushBridge(private val activity: MainActivity) {
    private val prefs = FieldPushState.prefs(activity)
    private var permissionResult: MethodChannel.Result? = null
    private var permissionOwner: String? = null

    private fun token(owner: String, binding: String, result: MethodChannel.Result) {
        try {
            FirebaseMessaging.getInstance().token.addOnCompleteListener { task ->
                if (prefs.getString("owner", null) != owner || prefs.getString("binding", null) != binding) {
                    result.error("FCM_CANCELLED", "Đã đổi tài khoản hoặc tắt thông báo", null)
                } else if (task.isSuccessful && !task.result.isNullOrBlank()) {
                    result.success(mapOf("token" to task.result, "binding" to binding))
                } else result.error("FCM_TOKEN", "Không đăng ký được thiết bị FCM. Kiểm tra mạng và Google Play Services.", null)
            }
        } catch (_: Exception) {
            result.error("FCM_UNAVAILABLE", "FCM chưa sẵn sàng trên thiết bị", null)
        }
    }

    private fun prepare(owner: String, result: MethodChannel.Result) {
        if (!FieldPushState.allowed(activity)) {
            result.error("FCM_PERMISSION", "Hãy cho phép thông báo Field Work trong cài đặt Android", null)
            return
        }
        if (prefs.getString("owner", null) != owner) FieldPushState.clear(activity)
        val binding = prefs.getString("binding", null) ?: UUID.randomUUID().toString()
        prefs.edit().putString("owner", owner).putString("binding", binding).putBoolean("enabled", false).commit()
        token(owner, binding, result)
    }

    fun onCall(call: MethodCall, result: MethodChannel.Result) {
        FieldPushState.createChannel(activity)
        val owner = call.argument<String>("owner")
        when (call.method) {
            "status" -> {
                if (owner.isNullOrBlank()) { result.success(null); return }
                if (prefs.getString("owner", null) != owner) {
                    FieldPushState.clear(activity); result.success(null); return
                }
                val binding = prefs.getString("binding", null)
                if (!prefs.getBoolean("enabled", false) || binding == null) { result.success(null); return }
                if (!FieldPushState.allowed(activity)) {
                    FieldPushState.clear(activity); result.success(null); return
                }
                token(owner, binding, result)
            }
            "prepare" -> {
                if (owner.isNullOrBlank()) { result.error("FCM_OWNER", "Thiếu tài khoản", null); return }
                if (permissionResult != null) { result.error("FCM_BUSY", "Đang xin quyền thông báo", null); return }
                if (Build.VERSION.SDK_INT >= 33 && ContextCompat.checkSelfPermission(activity,
                        Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                    permissionResult = result
                    permissionOwner = owner
                    activity.requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 5074)
                } else prepare(owner, result)
            }
            "activate" -> {
                val binding = call.argument<String>("binding")
                if (owner.isNullOrBlank() || binding.isNullOrBlank() ||
                    prefs.getString("owner", null) != owner || prefs.getString("binding", null) != binding ||
                    !FieldPushState.allowed(activity)) {
                    result.error("FCM_CANCELLED", "Không thể bật thông báo cho phiên này", null); return
                }
                try {
                    FirebaseMessaging.getInstance().isAutoInitEnabled = true
                    prefs.edit().putBoolean("enabled", true).commit()
                    result.success(true)
                } catch (_: Exception) {
                    FieldPushState.clear(activity)
                    result.error("FCM_UNAVAILABLE", "FCM chưa sẵn sàng", null)
                }
            }
            "diagnostics" -> {
                val manager = activity.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                val ch = if (Build.VERSION.SDK_INT >= 26) manager.getNotificationChannel(FieldPushState.channel) else null
                val same = prefs.getString("owner", null) == owner
                result.success(mapOf(
                    "allowed" to FieldPushState.allowed(activity),
                    "sound" to (ch == null || ch.sound != null),
                    "importance" to (ch?.importance ?: NotificationManager.IMPORTANCE_HIGH),
                    "receivedAt" to (if (same) prefs.getLong("last_received", 0L) else 0L),
                    "displayedAt" to (if (same) prefs.getLong("last_displayed", 0L) else 0L)))
            }
            "settings" -> {
                val intent = if (Build.VERSION.SDK_INT >= 26)
                    Intent(Settings.ACTION_CHANNEL_NOTIFICATION_SETTINGS)
                        .putExtra(Settings.EXTRA_APP_PACKAGE, activity.packageName)
                        .putExtra(Settings.EXTRA_CHANNEL_ID, FieldPushState.channel)
                else Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, android.net.Uri.parse("package:"+activity.packageName))
                try { activity.startActivity(intent); result.success(true) }
                catch (_: Exception) { result.error("SETTINGS", "Không mở được cài đặt thông báo", null) }
            }
            "localTest" -> {
                if (owner.isNullOrBlank() || prefs.getString("owner", null) != owner ||
                    !prefs.getBoolean("enabled", false) || !FieldPushState.allowed(activity)) {
                    result.error("FCM_PERMISSION", "Hãy bật thông báo trước", null); return
                }
                NotificationManagerCompat.from(activity).cancel(FieldPushState.tag, 1)
                if (FieldPushDisplay.show(activity, 1, "Thử âm thanh trên máy")) result.success(true)
                else result.error("FCM_PERMISSION", "Android không hiển thị thông báo", null)
            }
            "disable" -> {
                // Always stop display locally, even if the server is unreachable.
                val pending = permissionResult
                permissionResult = null
                permissionOwner = null
                pending?.error("FCM_CANCELLED", "Đã tắt thông báo", null)
                val binding = if (prefs.getString("owner", null) == owner) FieldPushState.clear(activity) else null
                result.success(binding)
            }
            else -> result.notImplemented()
        }
    }

    fun onPermission(requestCode: Int): Boolean {
        if (requestCode != 5074) return false
        val result = permissionResult
        val owner = permissionOwner
        permissionResult = null
        permissionOwner = null
        if (result != null && owner != null) prepare(owner, result)
        return true
    }
}

internal object FieldPushDisplay {
    @android.annotation.SuppressLint("MissingPermission")
    fun show(context: Context, id: Int, description: String): Boolean {
        FieldPushState.createChannel(context)
        if (!FieldPushState.allowed(context)) return false
        val launch = Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        val intent = PendingIntent.getActivity(context, 1, launch, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val notification = NotificationCompat.Builder(context, FieldPushState.channel)
            .setSmallIcon(R.drawable.ic_stat_field_work)
            .setContentTitle("Field Work")
            .setContentText(description)
            .setContentIntent(intent)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setDefaults(NotificationCompat.DEFAULT_ALL)
            .setCategory(NotificationCompat.CATEGORY_MESSAGE)
            .setVisibility(NotificationCompat.VISIBILITY_PRIVATE)
            .setAutoCancel(true)
            .setOnlyAlertOnce(true)
            .build()
        return try { NotificationManagerCompat.from(context).notify(FieldPushState.tag, id, notification); true }
        catch (_: SecurityException) { false }
    }
}
class FieldMessagingService : FirebaseMessagingService() {
    override fun onMessageReceived(message: RemoteMessage) {
        val p = FieldPushState.prefs(this)
        val binding = p.getString("binding", null) ?: return
        if (!p.getBoolean("enabled", false) || message.data["kind"] != "field_notification" ||
            message.data["binding"] != binding) return
        p.edit().putLong("last_received", System.currentTimeMillis()).commit()
        val id = (message.messageId ?: message.sentTime.toString()).hashCode().let { if (it == 1) 2 else it }
        if (p.getBoolean("enabled", false) && p.getString("binding", null) == binding &&
            FieldPushDisplay.show(this, id, "Bạn có thông báo mới."))
            p.edit().putLong("last_displayed", System.currentTimeMillis()).apply()
    }
}
