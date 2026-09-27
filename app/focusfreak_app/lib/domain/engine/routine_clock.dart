import '../../core/ff_constants.dart';

/// The two numbers of a block that time depends on.
typedef TimedBlock = ({int startMin, int durationMin});

/// How a routine is switched on. Every entry point offers the same three.
enum RoutineStartMode {
  /// The first block starts now and each block runs its full length. The
  /// times written in the routine are ignored.
  now,

  /// Follow the times written in the routine: whatever block the clock says
  /// is on right now starts, part-way through, with only its remaining time.
  clock,

  /// A block the user picks starts now with its full length, and the rest
  /// follow in order. For coming back to a routine mid-day without either
  /// restarting it or being dropped into the middle of a block.
  fromBlock,
}

/// Where the clock lands inside a routine.
class ClockHit {
  const ClockHit(this.index, this.elapsed, this.startMin);

  final int index;

  /// How far into the block the clock already is.
  final Duration elapsed;

  /// When the block started, in minutes since midnight.
  final int startMin;
}

/// What a start resolves to: the block to begin with, and how much of it has
/// already gone.
class RoutineStart {
  const RoutineStart(this.index, [this.offset = Duration.zero]);

  final int index;
  final Duration offset;
}

/// Routine time, as pure functions of the blocks and an explicit `now`.
///
/// Ported from FW Mentorship's tracking engine. The rule everything rests on:
/// **a block's start is derived from the durations before it**, never kept
/// alongside them, so a routine cannot have a clock that disagrees with its
/// own lengths. `startMin` on a stored block is either an anchor or the
/// firmware's "run after the previous one" sentinel.
class RoutineClock {
  const RoutineClock._();

  static const int dayMinutes = 24 * 60;
  static const int _daySeconds = dayMinutes * 60;

  /// A routine this long is a whole day, and following the clock is the
  /// natural way to run it. Anything shorter is a session you start when you
  /// sit down.
  static const int fullDayMinutes = 20 * 60;

  /// Shortest and longest a block may be stretched to by a start-time edit.
  static const int minBlockMinutes = 5;
  static const int maxBlockMinutes = 12 * 60;

  static bool isSequential(int startMin) =>
      startMin == FfFirmware.sequentialStartMin;

  static int totalMinutes(List<TimedBlock> blocks) =>
      blocks.fold(0, (sum, b) => sum + b.durationMin);

  static bool isFullDay(List<TimedBlock> blocks) =>
      totalMinutes(blocks) >= fullDayMinutes;

  /// The wall-clock start of every block, or null when the routine has no
  /// anchor to hang times on.
  ///
  /// A block with its own time keeps it; a sequential block starts where the
  /// previous one ends. The first block has to carry a time for any of this to
  /// mean anything.
  static List<int>? starts(List<TimedBlock> blocks) {
    if (blocks.isEmpty || isSequential(blocks.first.startMin)) return null;
    final out = <int>[];
    var t = 0;
    for (final b in blocks) {
      t = isSequential(b.startMin) ? t : b.startMin;
      out.add(t % dayMinutes);
      t += b.durationMin;
    }
    return out;
  }

  /// The block the wall clock says is on at [now], or null if none is.
  ///
  /// Resolved to the second, because the countdown shows seconds. Blocks may
  /// wrap past midnight (sleep 22:30 → 04:45), so each is tested by its offset
  /// modulo a day rather than a plain range. A full-day routine always matches
  /// something.
  static ClockHit? blockAt(List<TimedBlock> blocks, DateTime now) {
    final at = starts(blocks);
    if (at == null) return null;
    final nowSec = now.hour * 3600 + now.minute * 60 + now.second;
    for (var i = 0; i < blocks.length; i++) {
      final offset =
          ((nowSec - at[i] * 60) % _daySeconds + _daySeconds) % _daySeconds;
      if (offset < blocks[i].durationMin * 60) {
        return ClockHit(i, Duration(seconds: offset), at[i]);
      }
    }
    return null;
  }

  /// Which option the start sheet highlights.
  static RoutineStartMode recommended(List<TimedBlock> blocks, DateTime now) =>
      isFullDay(blocks) && blockAt(blocks, now) != null
      ? RoutineStartMode.clock
      : RoutineStartMode.now;

  /// Resolve a start. Returns null only for [RoutineStartMode.clock] when
  /// nothing is scheduled at [now].
  static RoutineStart? plan(
    RoutineStartMode mode,
    List<TimedBlock> blocks,
    DateTime now, {
    int index = 0,
  }) {
    if (blocks.isEmpty) return null;
    switch (mode) {
      case RoutineStartMode.now:
        return const RoutineStart(0);
      case RoutineStartMode.fromBlock:
        return RoutineStart(index.clamp(0, blocks.length - 1));
      case RoutineStartMode.clock:
        final hit = blockAt(blocks, now);
        return hit == null ? null : RoutineStart(hit.index, hit.elapsed);
    }
  }

  /// Recompute every block's time from [anchor] and the durations.
  ///
  /// Run after every edit to a timed routine, so adding, deleting, reordering
  /// or resizing a block moves everything after it together.
  static List<int> retime(List<int> durations, int anchor) {
    final out = <int>[];
    var t = anchor;
    for (final d in durations) {
      out.add(t % dayMinutes);
      t += d;
    }
    return out;
  }

  /// The signed difference between two clock times, wrapped into
  /// (-720, +720] so 23:50 → 00:10 reads as +20, not −1420.
  static int deltaMinutes(int to, int from) {
    var d = (to - from) % dayMinutes;
    if (d > dayMinutes ~/ 2) d -= dayMinutes;
    return d;
  }

  /// The run of blocks the bot should hold when the app is on block [from].
  ///
  /// The bot holds [FfFirmware.maxDeviceBlocks] and a full day holds up to 35,
  /// so it gets the next stretch of the day and the app sends the following
  /// one when that runs out.
  static ({int start, int end}) deviceWindow(
    int length,
    int from, {
    int capacity = FfFirmware.maxDeviceBlocks,
  }) {
    final start = from.clamp(0, length);
    final end = (start + capacity).clamp(start, length);
    return (start: start, end: end);
  }
}
