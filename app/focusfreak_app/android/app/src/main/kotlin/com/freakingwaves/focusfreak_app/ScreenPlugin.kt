package com.freakingwaves.focusfreak_app

import android.app.Activity
import android.view.WindowManager
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * Keeps the screen on while the phone is being used *as* the bot.
 *
 * A dock display that blanks after 30 seconds is not a dock display. This is
 * `FLAG_KEEP_SCREEN_ON`, which the system clears the moment the activity leaves
 * the foreground — so a forgotten flag cannot quietly drain the battery the way
 * a wake lock can.
 *
 * Hand-written for the same reason as `BtClassicPlugin`: it is twenty lines,
 * and a dependency for twenty lines is a dependency to upgrade forever.
 */
class ScreenPlugin(
    private val activities: ActivityHolder,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {

    private val activity: Activity?
        get() = activities.activity

    companion object {
        private const val CHANNEL = "focusfreak/screen"
    }

    private val channel = MethodChannel(messenger, CHANNEL)

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(
        call: io.flutter.plugin.common.MethodCall,
        result: MethodChannel.Result,
    ) {
        when (call.method) {
            "setKeepAwake" -> {
                val keep = call.argument<Boolean>("keep") ?: false
                // No activity means no window on screen, and a screen that is
                // not showing does not need keeping awake.
                val current = activity
                current?.runOnUiThread {
                    if (keep) {
                        current.window.addFlags(
                            WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
                        )
                    } else {
                        current.window.clearFlags(
                            WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
                        )
                    }
                }
                result.success(null)
            }

            else -> result.notImplemented()
        }
    }

    fun dispose() {
        activity?.window
            ?.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        channel.setMethodCallHandler(null)
    }
}
