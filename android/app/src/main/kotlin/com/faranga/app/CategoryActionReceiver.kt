package com.faranga.app

import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.database.sqlite.SQLiteDatabase

class CategoryActionReceiver : BroadcastReceiver() {
    companion object {
        var onCategorySelected: ((Int, String) -> Unit)? = null
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != "CATEGORIZE") return

        val dbId = intent.getIntExtra("dbId", 0)
        val category = intent.getStringExtra("category") ?: return

        // Forward to Flutter if running
        onCategorySelected?.invoke(dbId, category)

        // Also update DB directly as fallback (in case Flutter isn't running)
        try {
            val dbPath = context.getDatabasePath("momo_finance.db").absolutePath
            val db = SQLiteDatabase.openDatabase(dbPath, null, SQLiteDatabase.OPEN_READWRITE)
            db.execSQL(
                "UPDATE transactions SET category = ? WHERE id = ?",
                arrayOf<Any>(category, dbId)
            )
            db.close()
        } catch (e: Exception) {
            // DB might not exist yet, that's fine
        }

        // Dismiss the notification
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.cancel(dbId)
    }
}

