import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/providers.dart';
import 'app/router.dart';
import 'core/ff_constants.dart';
import 'data/repo/settings_repository.dart';
import 'design/ff_theme.dart';
import 'features/device/device_controller.dart';
import 'features/device/routine_device_sync.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/settings/theme_controller.dart';
import 'features/sound/alarm_scheduler.dart';
import 'features/sound/sound_cues.dart';
import 'features/timer/phone_tracking.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: FocusFreakApp()));
}

class FocusFreakApp extends ConsumerWidget {
  const FocusFreakApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeControllerProvider);

    // Install any templates this version ships that the user does not have.
    // Watched rather than awaited: the app is usable while it runs, and a seed
    // failure must not block the UI.
    ref.watch(bootstrapProvider);

    // Sound follows the session, not a screen: a block ending has to be heard
    // whether or not the timer is the page in front of you — and, through the
    // scheduler, whether or not the app is still running.
    ref.watch(soundCuesProvider);
    ref.watch(alarmSchedulerProvider);
    ref.watch(wakeAlarmSyncProvider);

    // And so does verification. The phone's sensors have to be observing for
    // as long as a tracked block runs — not for as long as a screen that cares
    // about them is on top, which is never when it matters.
    ref.watch(phoneTrackerProvider);

    // And the bot comes back on its own, the way a Bluetooth speaker does.
    // Watched here rather than on the device screen so it happens once at
    // launch instead of every time that screen is opened.
    ref.watch(deviceAutoConnectProvider);

    // And a connected bot follows the running routine, 16 blocks at a time,
    // whichever tab is open.
    ref.watch(routineDeviceSyncProvider);

    // First run gets the welcome flow instead of the router.
    //
    // A whole separate app rather than a route with a redirect: the redirect
    // would have to answer "has this finished?" synchronously, and the answer
    // lives in the database. Swapping the top-level widget when the setting
    // flips is the honest version of the same thing, and it means the router
    // never has to know onboarding exists.
    final done = ref.watch(onboardingDoneProvider).valueOrNull;

    // The app drives its own light/dark choice rather than following the OS:
    // the three looks are distinct designs, and "AMOLED black" has no system
    // setting to follow.
    final theme = FfTheme.of(mode);

    if (done == null) {
      // One frame or two while the setting is read. Themed, so it does not
      // flash white on the way into a dark app.
      return MaterialApp(
        title: FfApp.name,
        debugShowCheckedModeBanner: false,
        theme: theme,
        home: const Scaffold(body: SizedBox.shrink()),
      );
    }

    if (!done) {
      return MaterialApp(
        title: FfApp.name,
        debugShowCheckedModeBanner: false,
        theme: theme,
        home: const OnboardingScreen(),
      );
    }

    return MaterialApp.router(
      title: FfApp.name,
      debugShowCheckedModeBanner: false,
      theme: theme,
      routerConfig: appRouter,
    );
  }
}

/// Whether the welcome flow has been through once.
///
/// Watched rather than read, so finishing the flow swaps the app over without
/// anything having to navigate.
final onboardingDoneProvider = StreamProvider<bool>(
  (ref) => ref
      .watch(settingsRepositoryProvider)
      .watchBool(SettingKey.onboardingDone),
);
