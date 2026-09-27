package com.freakingwaves.focusfreak_app

import android.content.Context
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor

/**
 * The one activity, and a Dart isolate that deliberately outlives it.
 *
 * A stock `FlutterActivity` builds its engine in `onCreate` and destroys it in
 * `onDestroy`, which would defeat [FocusTrackingService] entirely: swiping the
 * app away destroys the activity, the engine goes with it, and the session
 * engine counting the block stops existing while a notification in the shade
 * still claims it is tracking. So the engine is cached and the activity attaches
 * to it, rather than owning it.
 *
 * The engine is still created lazily, on first launch of the UI — not in
 * `Application.onCreate` — so a cold process start does not run `main()` before
 * anyone has asked to see the app.
 */
class MainActivity : FlutterActivity() {

    companion object {
        private const val ENGINE_ID = "focusfreak_engine"

        /** Registered once per engine, not once per activity. */
        private var plugins: FocusFreakPlugins? = null
        private val activityHolder = ActivityHolder()
    }

    override fun provideFlutterEngine(context: Context): FlutterEngine {
        FlutterEngineCache.getInstance().get(ENGINE_ID)?.let { return it }

        val engine = FlutterEngine(applicationContext)
        engine.dartExecutor.executeDartEntrypoint(
            DartExecutor.DartEntrypoint.createDefault()
        )
        FlutterEngineCache.getInstance().put(ENGINE_ID, engine)
        return engine
    }

    /** The cache owns it now; letting the host destroy it is the bug above. */
    override fun shouldDestroyEngineWithHost(): Boolean = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        activityHolder.activity = this

        // Guarded because this runs on every attach, and a second set of
        // plugins would leave the first set's receivers and sensor listeners
        // registered with nothing left to unregister them.
        if (plugins == null) {
            plugins = FocusFreakPlugins(
                applicationContext,
                activityHolder,
                flutterEngine.dartExecutor.binaryMessenger,
            )
        }
    }

    override fun onDestroy() {
        // Only the activity goes. The plugins and the engine stay, which is
        // what lets a block keep counting after a swipe-away.
        if (activityHolder.activity === this) activityHolder.activity = null
        super.onDestroy()
    }
}
