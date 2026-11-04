package com.example.spendtracker

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.widget.RemoteViews

// Use the user's supplied artwork directly, independently of the app theme.
object NotificationBranding {
    fun content(context: Context, title: String, body: String, expanded: Boolean = false): RemoteViews {
        return RemoteViews(context.packageName, R.layout.spendtracker_notification).apply {
            setImageViewBitmap(R.id.notification_logo, walletLogo(context))
            setTextViewText(R.id.notification_title, title)
            setTextViewText(R.id.notification_message, body)
            setInt(R.id.notification_message, "setMaxLines", if (expanded) 6 else 1)
        }
    }

    private fun walletLogo(context: Context): Bitmap {
        val original = BitmapFactory.decodeResource(context.resources, R.drawable.spendtracker_app_logo)
        return Bitmap.createScaledBitmap(original, 192, 192, true)
    }
}
