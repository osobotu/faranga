package com.faranga.app

import android.Manifest
import android.content.pm.PackageManager
import android.net.Uri
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "momo_finance/sms"
    private val SMS_PERMISSION_CODE = 101

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "requestPermission" -> {
                    if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_SMS)
                        == PackageManager.PERMISSION_GRANTED
                    ) {
                        result.success(true)
                    } else {
                        ActivityCompat.requestPermissions(
                            this,
                            arrayOf(Manifest.permission.READ_SMS),
                            SMS_PERMISSION_CODE
                        )
                        // For simplicity, return true and let the next readSms call fail if denied
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
                else -> result.notImplemented()
            }
        }
    }

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
                // Only grab messages that look like MoMo
                if (body != null && (body.contains("*S*") || body.contains("RWF"))) {
                    messages.add(body)
                }
            }
        }

        return messages
    }
}