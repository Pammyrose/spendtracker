package com.example.spendtracker

import android.Manifest
import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import org.json.JSONArray
import org.json.JSONObject
import kotlin.math.max

// Inexact, user-requested alarms continue after the app closes and are restored on reboot.
object BillReminderScheduler {
    private const val channelId = "payment_followups"
    private const val plansKey = "payment_reminder_plans"
    private const val day = 86_400_000L

    private fun preferences(context: Context) = context.getSharedPreferences("spendtracker", Context.MODE_PRIVATE)
    private fun notificationManager(context: Context) = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    private fun alarmManager(context: Context) = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

    fun createChannel(context: Context) {
        ExpenseAlertNotifier.createChannel(context)
        if (Build.VERSION.SDK_INT >= 26) {
            notificationManager(context).createNotificationChannel(NotificationChannel(channelId, "Payment follow-ups", NotificationManager.IMPORTANCE_DEFAULT).apply {
                description = "Reminders for bills you plan to pay later"
            })
        }
    }

    fun allowed(context: Context, requestedChannel: String = channelId): Boolean {
        if (Build.VERSION.SDK_INT >= 33 && context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) return false
        if (!notificationManager(context).areNotificationsEnabled()) return false
        return Build.VERSION.SDK_INT < 26 || notificationManager(context).getNotificationChannel(requestedChannel)?.importance != NotificationManager.IMPORTANCE_NONE
    }

    private fun readPlans(context: Context): JSONArray = try { JSONArray(preferences(context).getString(plansKey, "[]")) } catch (_: Exception) { JSONArray() }
    private fun alarmIntent(context: Context, id: Int): PendingIntent = PendingIntent.getBroadcast(context, id,
        Intent(context, PaymentReminderReceiver::class.java).putExtra("reminder_id", id), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)

    fun nextTrigger(at: Long, lastFired: Long, interval: Long, now: Long): Long? {
        if (at > now) return at
        if (lastFired == 0L) return now + 60_000L
        if (interval == 0L) return null
        val aligned = at + ((now - at) / interval + 1) * interval
        return max(aligned, lastFired + interval)
    }

    private fun schedule(context: Context, plan: JSONObject) {
        if (!allowed(context)) return
        val next = nextTrigger(plan.getLong("at"), plan.optLong("lastFired"), plan.getLong("interval"), System.currentTimeMillis()) ?: return
        alarmManager(context).setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, next, alarmIntent(context, plan.getInt("id")))
    }

    fun sync(context: Context) {
        createChannel(context)
        ExpenseAlertNotifier.sync(context)
        val prefs = preferences(context)
        val oldPlans = readPlans(context)
        val previousOwner = oldPlans.optJSONObject(0)?.optString("owner", "") ?: ""
        if (previousOwner.isNotEmpty()) prefs.edit().putString("reminder_history_$previousOwner", oldPlans.toString()).commit()
        val owner = prefs.getString("active_account_key", "device") ?: "device"
        val history = try { JSONArray(prefs.getString("reminder_history_$owner", "[]")) } catch (_: Exception) { JSONArray() }
        val historyById = mutableMapOf<Int, JSONObject>()
        for (i in 0 until history.length()) { val plan = history.getJSONObject(i); historyById[plan.getInt("id")] = plan }
        val oldById = mutableMapOf<Int, JSONObject>()
        for (i in 0 until oldPlans.length()) { val plan = oldPlans.getJSONObject(i); oldById[plan.getInt("id")] = plan }
        var newPlans = JSONArray()
        try {
            val source = JSONObject(prefs.getString("data", "{}") ?: "{}")
            val settings = source.optJSONObject("settings") ?: JSONObject()
            if (prefs.getBoolean("account_active", true) && settings.optBoolean("notificationsEnabled", true) && settings.optBoolean("billReminders", true)) {
                val bills = source.optJSONArray("bills") ?: JSONArray()
                for (i in 0 until bills.length()) {
                    val bill = bills.getJSONObject(i)
                    val at = bill.optLong("paymentPlanAtMillis", 0)
                    if (bill.optBoolean("paid", false) || at <= 0) continue
                    val interval = when (bill.optString("followUpRepeat", "Daily")) { "Daily" -> day; "Every 2 days" -> day * 2; "Weekly" -> day * 7; else -> 0L }
                    val id = 10_000 + i
                    val name = bill.optString("name", "Bill")
                    val reason = bill.optString("paymentReason", "")
                    val signature = JSONArray(listOf(name, reason, at, interval)).toString()
                    val old = oldById[id]?.takeIf { it.optString("owner", "device") == owner } ?: historyById[id]
                    val lastFired = if (old?.optString("signature") == signature) old.optLong("lastFired") else 0L
                    newPlans.put(JSONObject().put("id", id).put("owner", owner).put("name", name).put("reason", reason).put("at", at).put("interval", interval).put("lastFired", lastFired).put("signature", signature))
                }
            }
        } catch (_: Exception) { newPlans = JSONArray() /* Invalid data never creates an alarm. */ }
        val newById = mutableMapOf<Int, JSONObject>()
        for (i in 0 until newPlans.length()) { val plan = newPlans.getJSONObject(i); newById[plan.getInt("id")] = plan }
        for ((id, old) in oldById) {
            val pending = alarmIntent(context, id)
            alarmManager(context).cancel(pending)
            pending.cancel()
            if (newById[id]?.optString("signature") != old.optString("signature")) notificationManager(context).cancel(id)
        }
        prefs.edit().putString(plansKey, newPlans.toString()).commit()
        if (prefs.getBoolean("account_active", true)) prefs.edit().putString("reminder_history_$owner", newPlans.toString()).commit()
        for (i in 0 until newPlans.length()) schedule(context, newPlans.getJSONObject(i))
    }

    fun deliver(context: Context, id: Int) {
        val plans = readPlans(context)
        val plan = (0 until plans.length()).map { plans.getJSONObject(it) }.firstOrNull { it.getInt("id") == id } ?: return
        if (!allowed(context)) return
        val now = System.currentTimeMillis()
        val interval = plan.getLong("interval")
        val last = plan.optLong("lastFired")
        if (now < plan.getLong("at") || last > 0 && (interval == 0L || now < last + interval - 60_000L)) { schedule(context, plan); return }
        val launch = Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        val open = PendingIntent.getActivity(context, id, launch, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val body = "This bill is still unpaid. ${plan.optString("reason")}".trim()
        @Suppress("DEPRECATION")
        val notification = (if (Build.VERSION.SDK_INT >= 26) Notification.Builder(context, channelId) else Notification.Builder(context))
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle("Payment reminder: ${plan.getString("name")}")
            .setContentText(body)
            .setStyle(Notification.BigTextStyle().bigText(body))
            .setVisibility(Notification.VISIBILITY_PRIVATE)
            .setContentIntent(open)
            .setAutoCancel(true)
            .build()
        notificationManager(context).notify(id, notification)
        plan.put("lastFired", now)
        preferences(context).edit().putString(plansKey, plans.toString()).commit()
        if (interval > 0) schedule(context, plan)
    }
}

class PaymentReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val id = intent.getIntExtra("reminder_id", -1)
        if (id >= 0) BillReminderScheduler.deliver(context, id)
    }
}

class PaymentReminderBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action in listOf(Intent.ACTION_BOOT_COMPLETED, Intent.ACTION_TIME_CHANGED, Intent.ACTION_TIMEZONE_CHANGED)) BillReminderScheduler.sync(context)
    }
}
