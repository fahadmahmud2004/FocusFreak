package com.freakingwaves.focusfreak_app

import android.app.KeyguardManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.os.SystemClock
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import kotlin.math.abs
import kotlin.math.sqrt

/**
 * The phone's own verification factors: screen lock, and stillness as a dock
 * proxy.
 *
 * The contract this file exists to keep is the one in `docs/ARCHITECTURE.md`: **never fake
 * a sensor reading.** A factor appears in the emitted map only when something is
 * actually watching it. Anything not being watched is *absent* from the map, and
 * the Dart side reads absence as `unavailable` — not as holding. Before this
 * plugin existed the app declared `screenLock` and never set it, so every
 * session on a phone reported LOCK as holding with nothing behind it.
 *
 * Hand-written for the same reason as `BtClassicPlugin`: two receivers and one
 * sensor listener is not worth a dependency to upgrade forever.
 */
class PhoneStatePlugin(
    private val context: Context,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    companion object {
        private const val METHOD_CHANNEL = "focusfreak/phone"
        private const val EVENT_CHANNEL = "focusfreak/phone/events"

        /** Factor keys. These match `VerificationFactor.name` on the Dart side. */
        private const val SCREEN_LOCK = "screenLock"
        private const val DOCK = "dock"

        private const val HOLDING = "holding"
        private const val VIOLATED = "violated"

        /**
         * Movement, in m/s², that counts as the phone being handled rather than
         * as sensor noise. A phone flat on a desk sits well under this even on a
         * table someone is typing on; picking it up clears it immediately.
         */
        private const val MOVEMENT_THRESHOLD = 0.65f

        /**
         * How long the phone must be still before the dock factor goes back to
         * holding.
         *
         * Deliberately asymmetric with the threshold above: movement violates
         * *instantly*, stillness only heals after a delay. Verification must be
         * the strict reading, and the alternative — a factor that flickers back
         * to holding between two samples of someone scrolling — would thrash the
         * session engine's grace windows.
         */
        private const val STILL_MS = 4_000L

        /**
         * Z acceleration, in m/s², below which the phone is lying screen-down.
         *
         * `docs/APP_SPEC.md` §4 defines the app-only dock as *still and
         * face-down*, and the second half is what makes it evidence rather than
         * a guess: a phone lying face-up on the desk is equally still while you
         * read every notification that arrives on it. Face-down is a deliberate
         * act, which is exactly what the reed switch detects on a real bot.
         */
        private const val FACE_DOWN_Z = -6.5f
    }

    private val main = Handler(Looper.getMainLooper())
    private val methodChannel = MethodChannel(messenger, METHOD_CHANNEL)
    private val eventChannel = EventChannel(messenger, EVENT_CHANNEL)

    private var events: EventChannel.EventSink? = null

    /** Whether anything is being observed at all. */
    private var running = false

    /** Whether stillness is allowed to stand in for the dock reed switch. */
    private var stillnessEnabled = false

    private var screenLocked: Boolean? = null

    private var lastMagnitude: Float? = null
    private var lastMovementAt: Long = 0L
    private var stillnessSeen = false
    private var faceDown = false

    init {
        methodChannel.setMethodCallHandler(this)
        eventChannel.setStreamHandler(this)
    }

    private val keyguard: KeyguardManager?
        get() = context.getSystemService(Context.KEYGUARD_SERVICE) as? KeyguardManager

    private val power: PowerManager?
        get() = context.getSystemService(Context.POWER_SERVICE) as? PowerManager

    private val sensors: SensorManager?
        get() = context.getSystemService(Context.SENSOR_SERVICE) as? SensorManager

    // -- Screen ---------------------------------------------------------------

    /**
     * Registered at runtime, never in the manifest.
     *
     * `ACTION_SCREEN_ON`, `ACTION_SCREEN_OFF` and `ACTION_USER_PRESENT` are
     * delivered *only* to runtime registrations — a manifest `<receiver>` for
     * these three is silently never called, which is the classic first attempt
     * at this feature.
     */
    private val screenReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            when (intent?.action) {
                Intent.ACTION_SCREEN_OFF -> setScreenLocked(true)
                Intent.ACTION_SCREEN_ON, Intent.ACTION_USER_PRESENT ->
                    setScreenLocked(readScreenLocked())
            }
        }
    }

    /**
     * The screen counts as locked when it is not interactive, or when the
     * keyguard is up.
     *
     * Both halves matter: a phone whose screen has timed out but which has no
     * lock set is still "put down", and a phone woken to the lock screen has not
     * been unlocked yet.
     */
    private fun readScreenLocked(): Boolean {
        val interactive = power?.isInteractive ?: return true
        if (!interactive) return true
        return keyguard?.isKeyguardLocked ?: false
    }

    private fun setScreenLocked(locked: Boolean) {
        if (screenLocked == locked) return
        screenLocked = locked
        emit()
    }

    // -- Stillness ------------------------------------------------------------

    private val accelerometer = object : SensorEventListener {
        override fun onSensorChanged(event: SensorEvent?) {
            val values = event?.values ?: return
            if (values.size < 3) return

            val magnitude = sqrt(
                values[0] * values[0] + values[1] * values[1] + values[2] * values[2]
            )
            val previous = lastMagnitude
            lastMagnitude = magnitude
            val wasFaceDown = faceDown
            faceDown = values[2] < FACE_DOWN_Z
            if (previous == null) {
                if (wasFaceDown != faceDown) emit()
                // The first sample has nothing to compare against. Treat it as
                // movement so the phone has to prove it is still, rather than
                // being assumed docked the instant a block starts.
                lastMovementAt = SystemClock.elapsedRealtime()
                return
            }

            val wasStill = stillnessSeen
            if (abs(magnitude - previous) > MOVEMENT_THRESHOLD) {
                lastMovementAt = SystemClock.elapsedRealtime()
                stillnessSeen = false
            } else {
                stillnessSeen =
                    SystemClock.elapsedRealtime() - lastMovementAt >= STILL_MS
            }
            if (wasStill != stillnessSeen || wasFaceDown != faceDown) emit()
        }

        override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) = Unit
    }

    private fun startStillness() {
        val manager = sensors ?: return
        val sensor = manager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER) ?: return
        lastMagnitude = null
        stillnessSeen = false
        faceDown = false
        lastMovementAt = SystemClock.elapsedRealtime()
        manager.registerListener(
            accelerometer, sensor, SensorManager.SENSOR_DELAY_NORMAL
        )
    }

    private fun stopStillness() {
        sensors?.unregisterListener(accelerometer)
        lastMagnitude = null
        stillnessSeen = false
        faceDown = false
    }

    /** True only when this phone can actually answer the stillness question. */
    private fun hasAccelerometer(): Boolean =
        sensors?.getDefaultSensor(Sensor.TYPE_ACCELEROMETER) != null

    // -- Observation ----------------------------------------------------------

    /**
     * Begins observing, and raises the foreground service that keeps the
     * observation alive.
     *
     * The two are one call because they are one lifetime: a receiver and a
     * sensor listener with no foreground service behind them stop delivering
     * within minutes of the screen going off, which is precisely the window
     * this evidence is for. See [FocusTrackingService].
     */
    private fun start(useStillness: Boolean, title: String, body: String) {
        if (running) {
            configure(useStillness)
            return
        }
        running = true
        FocusTrackingService.start(context, title, body)

        // `ContextCompat` rather than the bare call: API 34 requires an
        // export flag on runtime registrations. All three of these are
        // protected system broadcasts, so NOT_EXPORTED still receives them.
        ContextCompat.registerReceiver(
            context,
            screenReceiver,
            IntentFilter().apply {
                addAction(Intent.ACTION_SCREEN_ON)
                addAction(Intent.ACTION_SCREEN_OFF)
                addAction(Intent.ACTION_USER_PRESENT)
            },
            ContextCompat.RECEIVER_NOT_EXPORTED,
        )
        // Seeded rather than waiting for the first transition: a block started
        // with the screen already off must not sit unavailable until the user
        // happens to press the power button.
        screenLocked = readScreenLocked()

        stillnessEnabled = useStillness && hasAccelerometer()
        if (stillnessEnabled) startStillness()
        emit()
    }

    private fun configure(useStillness: Boolean) {
        val wanted = useStillness && hasAccelerometer()
        if (wanted == stillnessEnabled) return
        stillnessEnabled = wanted
        if (!running) return
        if (wanted) startStillness() else stopStillness()
        emit()
    }

    private fun stop() {
        if (!running) return
        running = false
        FocusTrackingService.stop(context)
        try {
            context.unregisterReceiver(screenReceiver)
        } catch (_: IllegalArgumentException) {
            // Already gone. Nothing to undo.
        }
        stopStillness()
        screenLocked = null
        emit()
    }

    /**
     * The current reading.
     *
     * A factor is present in this map only when it is genuinely being observed.
     * Absence is how "no source" reaches the Dart side, and it is the whole
     * reason this returns a sparse map rather than a fixed-shape one.
     */
    private fun snapshot(): Map<String, Any?> {
        val factors = mutableMapOf<String, String>()
        if (running) {
            screenLocked?.let { factors[SCREEN_LOCK] = if (it) HOLDING else VIOLATED }
            if (stillnessEnabled) {
                factors[DOCK] =
                    if (stillnessSeen && faceDown) HOLDING else VIOLATED
            }
        }
        return mapOf("running" to running, "factors" to factors)
    }

    private fun emit() {
        val payload = snapshot()
        main.post { events?.success(payload) }
    }

    // -- Channels -------------------------------------------------------------

    override fun onMethodCall(
        call: io.flutter.plugin.common.MethodCall,
        result: MethodChannel.Result,
    ) {
        when (call.method) {
            "hasAccelerometer" -> result.success(hasAccelerometer())

            "start" -> {
                start(
                    call.argument<Boolean>("useStillness") ?: false,
                    call.argument<String>("title") ?: "Focus block running",
                    call.argument<String>("body") ?: "Tracking your session.",
                )
                result.success(snapshot())
            }

            "configure" -> {
                configure(call.argument<Boolean>("useStillness") ?: false)
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
