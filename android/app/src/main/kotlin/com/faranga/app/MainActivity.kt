package com.faranga.app

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val SMS_CHANNEL = "faranga/sms"
    private val SMS_EVENTS = "faranga/sms_events"
    private val NOTIFICATION_CHANNEL_ID = "faranga_transactions"
    private val SMS_PERMISSION_CODE = 101

    private var eventSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        createNotificationChannel()

        // ── Method channel: read SMS, request permissions, show notifications ──
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SMS_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "requestPermission" -> {
                    if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_SMS)
                        == PackageManager.PERMISSION_GRANTED
                    ) {
                        result.success(true)
                    } else {
                        ActivityCompat.requestPermissions(
                            this,
                            arrayOf(
                                Manifest.permission.READ_SMS,
                                Manifest.permission.RECEIVE_SMS,
                                Manifest.permission.POST_NOTIFICATIONS,
                            ),
                            SMS_PERMISSION_CODE
                        )
                        result.success(true)
                    }
                }
                "readSms" -> {
                    try {
                        val messages = readAllSms()
                        result.success(messages)
                    } catch (e: SecurityException) {
                        result.error("PERMISSION_DENIED", "SMS permission not granted", null)
                    }
                }
                "showTransactionNotification" -> {
                    val amount = call.argument<String>("amount") ?: ""
                    val recipient = call.argument<String>("recipient") ?: ""
                    val txId = call.argument<Int>("dbId") ?: 0
                    val categories = call.argument<List<String>>("categories")
                        ?: listOf("Transport", "Groceries", "Food & Dining")
                    showCategoryNotification(amount, recipient, txId, categories)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        // ── Event channel: stream incoming SMS to Flutter in real time ──
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, SMS_EVENTS).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                    SmsReceiver.onSmsReceived = { smsBody ->
                        runOnUiThread {
                            eventSink?.success(smsBody)
                        }
                    }
                }
                override fun onCancel(arguments: Any?) {
                    eventSink = null
                    SmsReceiver.onSmsReceived = null
                }
            }
        )

        // ── Listen for notification category taps ──
        CategoryActionReceiver.onCategorySelected = { dbId, category ->
            // Forward to Flutter so it can refresh the UI
            runOnUiThread {
                MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SMS_CHANNEL)
                    .invokeMethod("onCategorized", mapOf("dbId" to dbId, "category" to category))
            }
        }
    }

    // ── Read all MoMo SMS from inbox ──

    private fun readAllSms(): List<String> {
        val messages = mutableListOf<String>()
        val cursor = contentResolver.query(
            Uri.parse("content://sms/inbox"),
            arrayOf("body"),
            null, null,
            "date DESC"
        )
        cursor?.use {
            val bodyIndex = it.getColumnIndex("body")
            while (it.moveToNext()) {
                val body = it.getString(bodyIndex)
                if (body != null && (body.contains("*S*") || body.contains("RWF"))) {
                    messages.add(body)
                }
            }
        }
        return messages
    }

    // ── Notification channel setup ──

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                NOTIFICATION_CHANNEL_ID,
                "Transactions",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "New MoMo transaction alerts"
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }

    // ── Show notification with category action buttons ──

    private fun showCategoryNotification(
        amount: String,
        recipient: String,
        dbId: Int,
        categories: List<String>
    ) {
        val builder = NotificationCompat.Builder(this, NOTIFICATION_CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle("$amount RWF → $recipient")
            .setContentText("Tap to categorize this transaction")
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)

        // Add up to 3 category action buttons
        for (category in categories.take(3)) {
            val intent = Intent(this, CategoryActionReceiver::class.java).apply {
                action = "CATEGORIZE"
                putExtra("dbId", dbId)
                putExtra("category", category)
            }
            val pending = PendingIntent.getBroadcast(
                this, category.hashCode() + dbId, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            builder.addAction(0, category, pending)
        }

        // Tapping the notification body opens the app
        val openIntent = packageManager.getLaunchIntentForPackage(packageName)
        val openPending = PendingIntent.getActivity(
            this, 0, openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        builder.setContentIntent(openPending)

        if (ActivityCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS)
            == PackageManager.PERMISSION_GRANTED
        ) {
            NotificationManagerCompat.from(this).notify(dbId, builder.build())
        }
    }
}