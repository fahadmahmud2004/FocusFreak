package com.freakingwaves.focusfreak_app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder

/**
 * Keeps the phone's verification factors alive while nobody is looking.
 *
 * This is the load-bearing piece of app-only verification, and the reason is
 * worth stating plainly: a tracked block is *most* interesting exactly when the
 * app is not in front of you. With the activity backgrounded and the screen off,
 * Android freezes the process within minutes — the screen receiver stops firing
 * and the accelerometer listener stops delivering. Without this service the app
 * would go quiet at the moment someone walked away and report the last thing it
 * saw, which reads as "still holding". That is the dishonest reading this
 * product exists to replace, so the service is not an optimisation.
 *
 * It is started when a tracked block starts and stopped the moment one stops.
 * Nothing is tracked outside a block, so nothing runs outside one.
 */
class FocusTrackingService : Service() {

    companion object {
        const val ACTION_START = "com.freakingwaves.focusfreak_app.TRACKING_START"
        const val ACTION_STOP = "com.freakingwaves.focusfreak_app.TRACKING_STOP"
        const val EXTRA_TITLE = "title"
        const val EXTRA_BODY = "body"

        /**
         * Its own channel, deliberately not the alarm's.
         *
         * A channel's importance and sound are fixed when it is *created* and
         * Android will not change them afterwards — the same rule that decided
         * the alarm-track question. Reusing the alarm
         * channel would make this ongoing notice play the alarm tone, once, for
         * every block someone starts.
         */
        private const val CHANNEL_ID = "focusfreak_tracking"
        private const val NOTIFICATION_ID = 0xFF01

        fun start(context: Context, title: String, body: String) {
            val intent = Intent(context, FocusTrackingService::class.java)
                .setAction(ACTION_START)
                .putExtra(EXTRA_TITLE, title)
                .putExtra(EXTRA_BODY, body)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            context.stopService(
                Intent(context, FocusTrackingService::class.java)
                    .setAction(ACTION_STOP)
            )
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopSelf()
            return START_NOT_STICKY
        }

        val title = intent?.getStringExtra(EXTRA_TITLE) ?: "Focus block running"
        val body = intent?.getStringExtra(EXTRA_BODY) ?: "Tracking your session."
        ensureChannel()
        startForeground(NOTIFICATION_ID, buildNotification(title, body))

        // Not START_STICKY: a service the system restarts after killing the app
        // would come back with no session behind it and sit in the shade
        // claiming to track a block that is not running.
        return START_NOT_STICKY
    }

    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(Context.NOTIFICATION_SERVICE)
                as? NotificationManager ?: return
        if (manager.getNotificationChannel(CHANNEL_ID) != null) return

        // IMPORTANCE_LOW: visible in the shade, silent, and no heads-up. This
        // notification is a legal requirement of running in the foreground, not
        // something anyone wants to be told about every 25 minutes.
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Focus tracking",
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "Shown while a block is being tracked."
            setShowBadge(false)
            enableVibration(false)
            setSound(null, null)
        }
        manager.createNotificationChannel(channel)
    }

    private fun buildNotification(title: String, body: String): Notification {
        val open = packageManager.getLaunchIntentForPackage(packageName)?.let {
            PendingIntent.getActivity(
                this,
                0,
                it,
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
            )
        }

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }

        return builder
            .setContentTitle(title)
            .setContentText(body)
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .apply { open?.let { setContentIntent(it) } }
            .build()
    }

    override fun onDestroy() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        super.onDestroy()
    }
}
