package com.freakingwaves.focusfreak_app

import android.content.Context
import io.flutter.plugin.common.BinaryMessenger

/**
 * Every hand-written plugin, built once for the life of the engine.
 *
 * Hand-written rather than taken as dependencies — the reasoning is in
 * `BtClassicPlugin` and `docs/PROTOCOL.md` §1. Grouping them here is what makes
 * "once per engine, not once per activity" a single fact rather than five
 * separate ones to get right in [MainActivity].
 */
class FocusFreakPlugins(
    context: Context,
    activity: ActivityHolder,
    messenger: BinaryMessenger,
) {
    val bluetooth = BtClassicPlugin(context, activity, messenger)
    val screen = ScreenPlugin(activity, messenger)
    val phone = PhoneStatePlugin(context, messenger)
    val usage = UsageStatsPlugin(context, messenger)
    val power = PowerSettingsPlugin(context, activity, messenger)

    /**
     * Not called from [MainActivity].
     *
     * There is deliberately no teardown on activity destruction: these outlive
     * the activity on purpose. They die with the process, which is the only
     * thing that also ends the session they are reporting on.
     */
    fun dispose() {
        bluetooth.dispose()
        screen.dispose()
        phone.dispose()
        usage.dispose()
        power.dispose()
    }
}
