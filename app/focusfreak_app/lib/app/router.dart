import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/bot/bot_fullscreen.dart';
import '../features/bot/bot_screen.dart';
import '../features/dashboard/home_screen.dart';
import '../features/achievements/achievements_screen.dart';
import '../features/dev/gallery_screen.dart';
import '../features/device/device_screen.dart';
import '../features/reports/backup_screen.dart';
import '../features/routines/build_routine_screen.dart';
import '../features/routines/plan_screen.dart';
import '../features/routines/routine_editor_screen.dart';
import '../features/settings/more_screen.dart';
import '../features/sound/alarms_screen.dart';
import '../features/stats/stats_screen.dart';
import 'ff_shell.dart';

/// Routes.
///
/// A [StatefulShellRoute] rather than a plain shell, so each tab keeps its own
/// navigation stack and scroll position. Switching to Stats mid-way through
/// editing a routine and coming back should land you where you left off.
final GoRouter appRouter = GoRouter(
  initialLocation: FfTab.home.path,
  routes: <RouteBase>[
    // Outside the shell: the phone standing in as the bot. No tab bar, no
    // status bar, nothing to wander off into — the same reason /focus is out
    // here.
    GoRoute(
      path: '/bot/fullscreen',
      pageBuilder: (_, state) => const MaterialPage<void>(
        fullscreenDialog: true,
        child: BotFullscreenScreen(),
      ),
    ),
    // Every timer and routine runs on the Bot tab and nowhere else. The old
    // full-screen focus page is gone; anything still pointing here (an alarm
    // notification, an old link) lands on the Bot tab.
    GoRoute(path: '/focus', redirect: (_, __) => FfTab.bot.path),
    // Today became Home; old links still land.
    GoRoute(path: '/today', redirect: (_, __) => FfTab.home.path),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) => FfShell(
        currentIndex: navigationShell.currentIndex,
        location: state.uri.path,
        onSelect: (i) => navigationShell.goBranch(
          i,
          // Tapping the active tab pops that branch back to its root.
          initialLocation: i == navigationShell.currentIndex,
        ),
        child: navigationShell,
      ),
      branches: <StatefulShellBranch>[
        StatefulShellBranch(
          routes: <RouteBase>[
            GoRoute(
              path: FfTab.home.path,
              builder: (_, __) => const HomeScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: <RouteBase>[
            GoRoute(
              path: FfTab.plan.path,
              builder: (_, __) => const PlanScreen(),
              routes: <RouteBase>[
                GoRoute(
                  path: 'build',
                  builder: (_, __) => const BuildRoutineScreen(),
                ),
                GoRoute(
                  path: 'routine/:id',
                  builder: (_, state) => RoutineEditorScreen(
                    routineId: state.pathParameters['id']!,
                  ),
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: <RouteBase>[
            GoRoute(
              path: FfTab.bot.path,
              builder: (_, __) => const BotScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: <RouteBase>[
            GoRoute(
              path: FfTab.stats.path,
              builder: (_, __) => const StatsScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: <RouteBase>[
            GoRoute(
              path: FfTab.more.path,
              builder: (_, __) => const MoreScreen(),
              routes: <RouteBase>[
                GoRoute(
                  path: 'device',
                  builder: (_, __) => const DeviceScreen(),
                ),
                GoRoute(path: 'data', builder: (_, __) => const BackupScreen()),
                GoRoute(
                  path: 'alarms',
                  builder: (_, __) => const AlarmsScreen(),
                ),
                GoRoute(
                  path: 'achievements',
                  builder: (_, __) => const AchievementsScreen(),
                ),
                GoRoute(
                  path: 'gallery',
                  builder: (_, __) => const GalleryScreen(),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  ],
  errorBuilder: (context, state) =>
      Scaffold(body: Center(child: Text('No route for ${state.uri}'))),
);
