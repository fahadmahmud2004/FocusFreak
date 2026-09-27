import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/ff_format.dart';
import '../../domain/engine/streak_engine.dart';

/// Streak, computed from the full day history.
final streakProvider = FutureProvider<StreakResult>((ref) async {
  // Recomputed when today's log changes, which is the only thing that can move
  // a streak forward.
  ref.watch(todayLogProvider);
  final days = await ref.watch(sessionRepositoryProvider).daySummaries();
  return const StreakEngine().compute(days);
});

/// Today's totals, summed from the sessions in seconds.
///
/// The day rollup keeps whole minutes, so a run switched off after forty
/// seconds added nothing there. Every second a block actually ran counts here.
final todaySecondsProvider = StreamProvider<({int verified, int claimed})>(
  (ref) => ref
      .watch(sessionRepositoryProvider)
      .watchDay(FfDates.logicalDay(DateTime.now()))
      .map(
        (rows) => (
          verified: rows.fold(0, (sum, s) => sum + s.verifiedSec),
          claimed: rows.fold(0, (sum, s) => sum + s.claimedSec),
        ),
      ),
);
