package com.freakingwaves.focusfreak_app

import android.app.AppOpsManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.Process
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * The `appUsage` factor: whether you opened something else.
 *
 * `docs/APP_SPEC.md` §4 lists this as app-only, and the violation copy already
 * written in `session_state.dart` is "Opened another app" — so the rule here is
 * exactly that literal, and no curated blocklist is involved. A blocklist would
 * mean deciding on the user's behalf that a PDF reader is study and a browser is
 * not, which is a judgement this product has no business making.
 *
 * Two things are deliberately excluded from counting as "another app": the
 * launcher, because passing through the home screen is not using an app, and
 * FocusFreak itself.
 *
 * **Strictly opt-in.** `PACKAGE_USAGE_STATS` is an appops grant that the user
 * has to give on a system settings screen, and without it this reports nothing
 * at all rather than assuming the foreground is clean.
 */
class UsageStatsPlugin(
    private val context: Context,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    companion object {
        private const val METHOD_CHANNEL = "focusfreak/usage"
        private const val EVENT_CHANNEL = "focusfreak/usage/events"

        private const val APP_USAGE = "appUsage"
        private const val HOLDING = "holding"
        private const val VIOLATED = "violated"

        /**
         * How often the foreground app is checked.
         *
         * `UsageStatsManager` has no push API — there is no broadcast for "the
         * foreground app changed" available to a normal app — so this is a poll,
         * and its period is chosen against the engine's 30 s running grace in
         * `FfFirmware.graceRunning`: slow enough to be free, fast enough that a
         * violation is seen well inside the window that forgives it.
         */
        private const val POLL_MS = 5_000L

        /**
         * How far back each poll looks.
         *
         * Wider than [POLL_MS] on purpose: `queryEvents` windows are inclusive
         * of neither edge in practice, and a gap between two windows would lose
         * the one event that mattered.
         */
        private const val LOOKBACK_MS = 15_000L
    }

    private val main = Handler(Looper.getMainLooper())
    private val methodChannel = MethodChannel(messenger, METHOD_CHANNEL)
    private val eventChannel = EventChannel(messenger, EVENT_CHANNEL)

    private var events: EventChannel.EventSink? = null
    private var running = false

    /** The last foreground package seen, or null before the first poll. */
    private var foreground: String? = null
    private var violated = false

    private val poll = object : Runnable {
        override fun run() {
            if (!running) return
            sample()
            main.postDelayed(this, POLL_MS)
        }
    }

    init {
        methodChannel.setMethodCallHandler(this)
        eventChannel.setStreamHandler(this)
    }

    private val usage: UsageStatsManager?
        get() = context.getSystemService(Context.USAGE_STATS_SERVICE)
                as? UsageStatsManager

    // -- The appops grant ------------------------------------------------------

    /**
     * Whether usage access has been granted.
     *
     * Checked through `AppOpsManager` rather than `checkSelfPermission`:
     * `PACKAGE_USAGE_STATS` is signature-level and is never "granted" in the
     * runtime-permission sense, so the ordinary check always says no.
     */
    private fun hasAccess(): Boolean {
        val ops = context.getSystemService(Context.APP_OPS_SERVICE)
                as? AppOpsManager ?: return false
        // `unsafeCheckOpNoThrow` only exists from API 29; this app ships to 24.
        @Suppress("DEPRECATION")
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            ops.unsafeCheckOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                context.packageName,
            )
        } else {
            ops.checkOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                context.packageName,
            )
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }

    /**
     * Opens the system screen where the grant lives.
     *
     * Guarded by `resolveActivity`: this screen is absent on some stripped ROMs,
     * and an unguarded start is an `ActivityNotFoundException` on a user's phone
     * rather than a feature they can simply decline.
     */
    private fun openSettings(): Boolean {
        val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        if (intent.resolveActivity(context.packageManager) == null) return false
        context.startActivity(intent)
        return true
    }

    // -- Polling ---------------------------------------------------------------

    /** The launcher, which is a route between apps rather than an app. */
    private fun launcherPackage(): String? {
        val home = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME)
        return home.resolveActivity(context.packageManager)?.packageName
    }

    private fun sample() {
        val manager = usage ?: return
        if (!hasAccess()) {
            // The grant can be revoked while a block is running. When it goes,
            // the factor goes with it — it must not freeze at its last value and
            // keep vouching.
            if (foreground != null || violated) {
                foreground = null
                violated = false
                emit()
            }
            return
        }

        val now = System.currentTimeMillis()
        val events = manager.queryEvents(now - LOOKBACK_MS, now)
        val event = UsageEvents.Event()
        var latest: String? = null
        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            if (event.eventType == UsageEvents.Event.MOVE_TO_FOREGROUND) {
                latest = event.packageName
            }
        }
        if (latest != null) foreground = latest

        val current = foreground
        val next = current != null &&
            current != context.packageName &&
            current != launcherPackage()
        if (next != violated) {
            violated = next
            emit()
        }
    }

    private fun start() {
        if (running) return
        running = true
        foreground = null
        violated = false
        main.post(poll)
        emit()
    }

    private fun stop() {
        if (!running) return
        running = false
        main.removeCallbacks(poll)
        foreground = null
        violated = false
        emit()
    }

    /**
     * The current reading, sparse like [PhoneStatePlugin]'s.
     *
     * `appUsage` is present only while observing *and* granted. Absence is how
     * "no source" reaches Dart, and it is the difference between "you opened
     * nothing" and "nobody was watching".
     */
    private fun snapshot(): Map<String, Any?> {
        val factors = mutableMapOf<String, String>()
        val granted = hasAccess()
        if (running && granted) {
            factors[APP_USAGE] = if (violated) VIOLATED else HOLDING
        }
        return mapOf(
            "running" to running,
            "granted" to granted,
            "factors" to factors,
        )
    }

    private fun emit() {
        val payload = snapshot()
        main.post { events?.success(payload) }
    }

    // -- Channels --------------------------------------------------------------

    override fun onMethodCall(
        call: io.flutter.plugin.common.MethodCall,
        result: MethodChannel.Result,
    ) {
        when (call.method) {
            "hasAccess" -> result.success(hasAccess())

            "openSettings" -> result.success(openSettings())

            "start" -> {
                start()
                result.success(snapshot())
            }

            "stop" -> {
                stop()
                result.success(null)
            }

            "read" -> result.success(snapshot())

            else -> result.notImplemented()
        }
    }

    override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) {
        events = sink
        emit()
    }

    override fun onCancel(arguments: Any?) {
        events = null
    }

    fun dispose() {
        stop()
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
    }
}
