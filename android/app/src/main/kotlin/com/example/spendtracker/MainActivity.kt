package com.example.spendtracker

import android.app.Activity
import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.content.Intent
import android.graphics.Paint
import android.graphics.pdf.PdfDocument
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.IOException
import java.io.OutputStream
import java.security.MessageDigest
import org.json.JSONObject

// Android's document picker lets the user choose the destination without broad storage permissions.
class MainActivity : FlutterActivity() {
    private var pendingReply: MethodChannel.Result? = null
    private var pendingExport: Map<*, *>? = null
    private val createDocument = 8101
    private val openDocument = 8102
    private var notificationReply: MethodChannel.Result? = null
    private val notificationPermission = 8103
    private var requestedNotificationChannel = "payment_followups"

    private fun accountKey(args: Map<*, *>?): String? {
        val values = args ?: return null
        val server = values["server"] as? String ?: return null
        val email = values["email"] as? String ?: return null
        val digest = MessageDigest.getInstance("SHA-256").digest("$server\n$email".toByteArray(Charsets.UTF_8))
        return "account_" + digest.joinToString("") { (it.toInt() and 255).toString(16).padStart(2, '0') }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        BillReminderScheduler.sync(this)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "spendtracker/storage").setMethodCallHandler { call, reply ->
            val preferences = getSharedPreferences("spendtracker", MODE_PRIVATE)
            when (call.method) {
                "archiveLocalData" -> {
                    if (!preferences.getBoolean("live_accounts_enabled", false) && !preferences.contains("legacy_device_backup")) {
                        preferences.getString("data", null)?.let { preferences.edit().putString("legacy_device_backup", it).commit() }
                    }
                    reply.success(null)
                }
                "setActiveAccount" -> {
                    val key = accountKey(call.arguments as? Map<*, *>)
                    val editor = preferences.edit().putBoolean("live_accounts_enabled", true).putBoolean("account_active", false)
                    if (key == null) editor.remove("active_account_key") else {
                        editor.putString("active_account_key", key)
                        if (preferences.contains("legacy_device_backup") && !preferences.contains("legacy_backup_owner")) editor.putString("legacy_backup_owner", key)
                    }
                    editor.commit()
                    BillReminderScheduler.sync(this)
                    reply.success(null)
                }
                "loadAccountData" -> {
                    val key = accountKey(call.arguments as? Map<*, *>)
                    reply.success(if (key == null) null else preferences.getString(key, null))
                }
                "saveAccountData" -> {
                    val args = call.arguments as? Map<*, *>
                    val key = accountKey(args)
                    val document = args?.get("data") as? String
                    if (key == null || document == null) reply.error("INVALID_DATA", "Missing account data.", null)
                    else {
                        val cache = JSONObject().put("data", document).put("revision", args?.get("revision")).put("dirty", args?.get("dirty"))
                        val editor = preferences.edit().putString(key, cache.toString())
                        if (preferences.getString("active_account_key", null) == key) editor.putString("data", document).putBoolean("account_active", true)
                        if (!editor.commit()) reply.error("SAVE_FAILED", "Could not save the device copy.", null)
                        else { BillReminderScheduler.sync(this); reply.success(null) }
                    }
                }
                "readLegacyData" -> reply.success(if (preferences.getString("active_account_key", null) == preferences.getString("legacy_backup_owner", "")) preferences.getString("legacy_device_backup", null) else null)
                "loadData" -> reply.success(preferences.getString("data", null))
                "saveData" -> {
                    val content = call.arguments as? String
                    if (content == null) reply.error("INVALID_DATA", "No data supplied.", null)
                    else if (preferences.edit().putString("data", content).commit()) {
                        BillReminderScheduler.sync(this)
                        reply.success(null)
                    }
                    else reply.error("SAVE_FAILED", "Records could not be saved on this device.", null)
                }
                "requestNotifications" -> {
                    BillReminderScheduler.createChannel(this)
                    val channel = if (call.arguments == "expenses") ExpenseAlertNotifier.channelId else "payment_followups"
                    if (Build.VERSION.SDK_INT >= 33 && checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                        if (notificationReply != null) reply.error("BUSY", "Finish the notification permission request first.", null)
                        else {
                            requestedNotificationChannel = channel
                            notificationReply = reply
                            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), notificationPermission)
                        }
                    } else reply.success(BillReminderScheduler.allowed(this, channel))
                }
                "exportData" -> {
                    if (pendingReply != null) reply.error("BUSY", "Finish the current file selection first.", null)
                    else {
                        val args = call.arguments as? Map<*, *>
                        if (args == null || args["content"] !is String) reply.error("INVALID_DATA", "No export data supplied.", null)
                        else {
                            val mime = when (args["format"]) { "pdf" -> "application/pdf"; "csv" -> "text/csv"; else -> "application/json" }
                            pendingReply = reply
                            pendingExport = args
                            try {
                                startActivityForResult(Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                                    addCategory(Intent.CATEGORY_OPENABLE)
                                    type = mime
                                    putExtra(Intent.EXTRA_TITLE, args["name"] as? String ?: "spendtracker.json")
                                }, createDocument)
                            } catch (error: Exception) { pendingReply = null; pendingExport = null; reply.error("FILE_PICKER", "A document picker is not available.", null) }
                        }
                    }
                }
                "readBackup" -> {
                    if (pendingReply != null) reply.error("BUSY", "Finish the current file selection first.", null)
                    else {
                        pendingReply = reply
                        try {
                            startActivityForResult(Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                                addCategory(Intent.CATEGORY_OPENABLE)
                                type = "*/*"
                                putExtra(Intent.EXTRA_MIME_TYPES, arrayOf("application/json", "text/plain", "application/octet-stream"))
                            }, openDocument)
                        } catch (error: Exception) { pendingReply = null; reply.error("FILE_PICKER", "A document picker is not available.", null) }
                    }
                }
                else -> reply.notImplemented()
            }
        }
    }

    override fun onResume() {
        super.onResume()
        BillReminderScheduler.sync(this)
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == notificationPermission) {
            val reply = notificationReply
            notificationReply = null
            BillReminderScheduler.sync(this)
            reply?.success(BillReminderScheduler.allowed(this, requestedNotificationChannel))
        }
    }

    @Deprecated("Uses the activity result bridge supplied by FlutterActivity")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != createDocument && requestCode != openDocument) return
        val reply = pendingReply ?: return
        val export = pendingExport
        pendingReply = null
        pendingExport = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) { reply.success(if (requestCode == createDocument) false else null); return }
        Thread {
            try {
                if (requestCode == createDocument) {
                    val content = export?.get("content") as? String ?: throw IOException("No export content.")
                    contentResolver.openOutputStream(uri)?.use { output ->
                        if (export?.get("format") == "pdf") writePdf(content, output)
                        else output.write(content.toByteArray(Charsets.UTF_8))
                    } ?: throw IOException("The selected file could not be opened.")
                    runOnUiThread { reply.success(true) }
                } else {
                    val content = contentResolver.openInputStream(uri)?.use { input ->
                        val buffer = ByteArray(8192)
                        val bytes = ByteArrayOutputStream()
                        while (true) {
                            val count = input.read(buffer)
                            if (count < 0) break
                            if (bytes.size() + count > 10 * 1024 * 1024) throw IOException("Backup files must be smaller than 10 MB.")
                            bytes.write(buffer, 0, count)
                        }
                        bytes.toString("UTF-8")
                    } ?: throw IOException("The selected backup could not be opened.")
                    runOnUiThread { reply.success(content) }
                }
            } catch (error: Exception) { runOnUiThread { reply.error("FILE_ERROR", error.message ?: "The file operation failed.", null) } }
        }.start()
    }

    private fun writePdf(content: String, output: OutputStream) {
        val pdf = PdfDocument()
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply { textSize = 11f; color = android.graphics.Color.rgb(25, 33, 52) }
        var number = 1
        var page = pdf.startPage(PdfDocument.PageInfo.Builder(595, 842, number).create())
        var y = 44f
        try {
            for (line in content.lines()) {
                var remaining = line
                do {
                    if (y > 790f) {
                        page.canvas.drawText("Page $number", 40f, 815f, paint)
                        pdf.finishPage(page)
                        number++
                        page = pdf.startPage(PdfDocument.PageInfo.Builder(595, 842, number).create())
                        y = 44f
                    }
                    val count = if (remaining.isEmpty()) 0 else paint.breakText(remaining, true, 510f, null).coerceAtLeast(1)
                    page.canvas.drawText(remaining.take(count), 40f, y, paint)
                    y += 16f
                    remaining = remaining.drop(count)
                } while (remaining.isNotEmpty())
            }
            page.canvas.drawText("Page $number", 40f, 815f, paint)
            pdf.finishPage(page)
            pdf.writeTo(output)
        } finally { pdf.close() }
    }
}
