package com.freakingwaves.focusfreak_app

import android.app.Activity
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * The two settings that decide whether tracking survives an hour in a pocket.
 *
 * Stock Android is handled by the battery-optimisation exemption. The Chinese
 * OEM ROMs — Xiaomi, Oppo, Vivo, Realme, Huawei — are not: they run their own
 * "autostart" whitelist on top, and an app missing from it has its foreground
 * service killed within minutes regardless of what Android itself allows. There
 * is no API for this, only a set of undocumented settings activities, so the
 * honest implementation is to offer the user a shortcut to the right screen and
 * let them make the change.
 *
 * **Every intent is checked with `resolveActivity` before it is started.** These
 * component names differ between ROM versions and vanish without notice; an
 * unguarded start is an `ActivityNotFoundException` crash on someone's phone
 * instead of a button that quietly is not there.
 */
class PowerSettingsPlugin(
    private val context: Context,
    private val activities: ActivityHolder,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {

    /**
     * Null when no UI is on screen. Everything here either opens a settings
     * screen or reports whether one exists, and both are meaningless without a
     * user looking at the app — so a null activity is answered honestly with
     * "could not", never by launching something from the background.
     */
    private val activity: Activity?
        get() = activities.activity

    companion object {
        private const val CHANNEL = "focusfreak/power"

        /**
         * Known autostart screens, newest ROM first within each vendor.
         *
         * More than one entry per vendor on purpose: MIUI moved this activity
         * twice, and trying the list in order is what keeps the button working
         * across ROM versions rather than only on the one phone it was tested on.
         */
        private val AUTOSTART_INTENTS = listOf(
            "com.miui.securitycenter" to
                "com.miui.permcenter.autostart.AutoStartManagementActivity",
            "com.letv.android.letvsafe" to
                "com.letv.android.letvsafe.AutobootManageActivity",
            "com.coloros.safecenter" to
                "com.coloros.safecenter.permission.startup.StartupAppListActivity",
            "com.coloros.safecenter" to
                "com.coloros.safecenter.startupapp.StartupAppListActivity",
            "com.oppo.safe" to
                "com.oppo.safe.permission.startup.StartupAppListActivity",
            "com.iqoo.secure" to
                "com.iqoo.secure.ui.phoneoptimize.AddWhiteListActivity",
            "com.iqoo.secure" to
                "com.iqoo.secure.ui.phoneoptimize.BgStartUpManager",
            "com.vivo.permissionmanager" to
                "com.vivo.permissionmanager.activity.BgStartUpManagerActivity",
            "com.huawei.systemmanager" to
                "com.huawei.systemmanager.optimize.process.ProtectActivity",
            "com.huawei.systemmanager" to
                "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity",
            "com.samsung.android.lool" to
                "com.samsung.android.sm.ui.battery.BatteryActivity",
        )
    }

    private val channel = MethodChannel(messenger, CHANNEL)

    init {
        channel.setMethodCallHandler(this)
    }

    private val power: PowerManager?
        get() = context.getSystemService(Context.POWER_SERVICE) as? PowerManager

    private fun isExempt(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true
        return power?.isIgnoringBatteryOptimizations(context.packageName) ?: false
    }

    /**
     * Starts a settings screen, if there is a UI to return to and the screen
     * exists on this ROM.
     *
     * The `resolveActivity` check is not defensive padding: OEM component names
     * differ between ROM versions and disappear without notice, and an
     * unguarded start is an `ActivityNotFoundException` on a user's phone rather
     * than a button that is simply absent.
     */
    private fun launch(intent: Intent): Boolean {
        val host = activity ?: return false
        if (intent.resolveActivity(context.packageManager) == null) return false
        host.startActivity(intent)
        return true
    }

    /**
     * Asks for the battery-optimisation exemption.
     *
     * `ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` shows a system dialog the
     * user can decline, which is the correct shape: the app works without the
     * exemption, it just cannot promise that a 90-minute block survives being
     * put in a pocket.
     */
    private fun requestExemption(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true
        if (isExempt()) return true
        return launch(
            Intent(
                Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                Uri.parse("package:${context.packageName}"),
            )
        )
    }

    /** The first autostart screen this ROM actually has, or null. */
    private fun autostartIntent(): Intent? {
        for ((pkg, cls) in AUTOSTART_INTENTS) {
            val intent = Intent().setComponent(ComponentName(pkg, cls))
            if (intent.resolveActivity(context.packageManager) != null) {
                return intent
            }
        }
        return null
    }

    private fun openAppSettings(): Boolean = launch(
        Intent(
            Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
            Uri.parse("package:${context.packageName}"),
        )
    )

    override fun onMethodCall(
        call: io.flutter.plugin.common.MethodCall,
        result: MethodChannel.Result,
    ) {
        when (call.method) {
            "isIgnoringBatteryOptimizations" -> result.success(isExempt())

            "requestIgnoreBatteryOptimizations" ->
                result.success(requestExemption())

            // Whether to offer the autostart button at all. On a stock phone
            // there is no such screen and the card should not mention one.
            "hasAutostartSettings" -> result.success(autostartIntent() != null)

            "openAutostartSettings" -> {
                val intent = autostartIntent()
                result.success(if (intent == null) false else launch(intent))
            }

            "openAppSettings" -> result.success(openAppSettings())

            "manufacturer" -> result.success(Build.MANUFACTURER ?: "")

            else -> result.notImplemented()
        }
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
    }
}
