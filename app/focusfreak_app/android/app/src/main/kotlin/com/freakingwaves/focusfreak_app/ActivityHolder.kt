package com.freakingwaves.focusfreak_app

import android.app.Activity

/**
 * The current activity, or null when there isn't one.
 *
 * The engine now outlives the activity — see [MainActivity.provideFlutterEngine]
 * — so a plugin that captured an `Activity` in its constructor would be holding
 * a destroyed one the first time a user swiped the app away and came back. Every
 * plugin that genuinely needs an activity (a window to flag, a permission
 * dialog, a settings screen to launch) reads it through this instead, and does
 * nothing when it is null.
 *
 * Nothing here is a fallback for laziness: a null activity means there is no UI
 * on screen, and every caller below has a sensible answer for that case.
 */
class ActivityHolder {
    var activity: Activity? = null
}
