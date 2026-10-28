package com.example.spendtracker

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import org.json.JSONObject
import java.text.NumberFormat
import java.util.Calendar
import java.util.Currency
import java.util.Locale

object ExpenseAlertNotifier {
    const val channelId = "expense_alerts"
    private const val notificationId = 50_001
    private const val refreshId = 50_002

    fun createChannel(context: Context) {
        if (Build.VERSION.SDK_INT >= 26) {
            (context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
                .createNotificationChannel(NotificationChannel(channelId, "Expense alerts", NotificationManager.IMPORTANCE_DEFAULT).apply {
                    description = "Alerts when monthly spending reaches your saved limit"
                })
        }
    }

    fun sync(context: Context) {
        createChannel(context)
        val prefs = context.getSharedPreferences("spendtracker", Context.MODE_PRIVATE)
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val alarms = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val refresh = PendingIntent.getBroadcast(context, refreshId, Intent(context, ExpenseAlertRefreshReceiver::class.java), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        alarms.cancel(refresh)
        val now = Calendar.getInstance()
        val month = String.format(Locale.ROOT, "%04d-%02d", now.get(Calendar.YEAR), now.get(Calendar.MONTH) + 1)
        val today = String.format(Locale.ROOT, "%s-%02d", month, now.get(Calendar.DAY_OF_MONTH))
        // Keep only this month's delivery keys, so restoring or reopening never repeats an alert.
        val sent = (prefs.getStringSet("expense_alerts_sent", emptySet()) ?: emptySet()).filter { it.startsWith("$month|") }.toMutableSet()
        if (prefs.getString("expense_alert_month", "") != month) manager.cancel(notificationId)
        prefs.edit().putString("expense_alert_month", month).putStringSet("expense_alerts_sent", sent).commit()
        try {
            val source = JSONObject(prefs.getString("data", "{}") ?: "{}")
            val settings = source.optJSONObject("settings") ?: JSONObject()
            if (!prefs.getBoolean("account_active", true) || !settings.optBoolean("notificationsEnabled", true) || !settings.optBoolean("expenseAlerts", false)) {
                manager.cancel(notificationId)
                return
            }
            // Recheck at local midnight: future-dated expenses become current, and a new month resets the total.
            val midnight = now.clone() as Calendar
            midnight.add(Calendar.DAY_OF_MONTH, 1)
            midnight.set(Calendar.HOUR_OF_DAY, 0)
            midnight.set(Calendar.MINUTE, 0)
            midnight.set(Calendar.SECOND, 0)
            midnight.set(Calendar.MILLISECOND, 0)
            alarms.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, midnight.timeInMillis, refresh)
            val limit = settings.optDouble("expenseAlertAmount", 10_000.0)
            val expenses = source.optJSONArray("expenses")
            var spent = 0.0
            if (expenses != null) for (i in 0 until expenses.length()) {
                val expense = expenses.getJSONObject(i)
                val date = expense.optString("date").take(10)
                if (date.startsWith("$month-") && date <= today) spent += expense.optDouble("amount", 0.0)
            }
            if (!limit.isFinite() || limit <= 0 || !spent.isFinite() || spent < limit) {
                manager.cancel(notificationId)
                return
            }
            val currencyCode = settings.optString("currency", "PHP")
            val owner = prefs.getString("active_account_key", "device")
            val token = "$month|$owner|$currencyCode|$limit"
            val alreadySent = token in sent
            if (!BillReminderScheduler.allowed(context, channelId)) return
            // Update an existing alert silently, but do not repost one the user dismissed.
            if (alreadySent && manager.activeNotifications.none { it.id == notificationId }) return
            val money = NumberFormat.getCurrencyInstance(Locale("en", "PH")).apply { currency = Currency.getInstance(currencyCode) }
            val body = "${money.format(spent)} spent this month. Your limit is ${money.format(limit)}."
            val open = PendingIntent.getActivity(context, notificationId,
                Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            @Suppress("DEPRECATION")
            val notification = (if (Build.VERSION.SDK_INT >= 26) Notification.Builder(context, channelId) else Notification.Builder(context))
                .setSmallIcon(android.R.drawable.ic_dialog_info)
                .setContentTitle("Monthly spending limit reached")
                .setContentText(body)
                .setStyle(Notification.BigTextStyle().bigText(body))
                .setVisibility(Notification.VISIBILITY_PRIVATE)
                .setContentIntent(open)
                .setAutoCancel(true)
                .setOnlyAlertOnce(alreadySent)
                .build()
            manager.notify(notificationId, notification)
            sent.add(token)
            prefs.edit().putStringSet("expense_alerts_sent", sent).commit()
        } catch (_: Exception) {
            // A rejected permission or invalid stored record must never crash a save or receiver.
            manager.cancel(notificationId)
        }
    }
}

class ExpenseAlertRefreshReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) = ExpenseAlertNotifier.sync(context)
}
