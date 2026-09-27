import 'package:flutter_test/flutter_test.dart';
import 'package:focusfreak_app/domain/engine/session_engine.dart';
import 'package:focusfreak_app/domain/model/session_state.dart';
import 'package:focusfreak_app/domain/model/verification.dart';
import 'package:focusfreak_app/features/sound/alarm_scheduler.dart';
import 'package:focusfreak_app/features/timer/session_controller.dart';
import 'package:focusfreak_app/platform/alarm_notifier.dart';

/// The alarm that outlives the app.
///
/// What is tested here is the *scheduling*: when there is an alarm pending,
/// when there is not, and — the part that matters on a battery — how often it
/// is re-armed.
void main() {
  late RecordingAlarmNotifier notifier;
  late AlarmScheduler scheduler;
  var now = DateTime(2026, 8, 3, 9);

  setUp(() {
    now = DateTime(2026, 8, 3, 9);
    notifier = RecordingAlarmNotifier();
    scheduler = AlarmScheduler(notifier, clock: () => now);
  });

  const block = ActiveBlock(
    id: 'b1',
    name: 'Deep Work 1',
    description: '',
    category: 0,
    duration: Duration(minutes: 90),
    trackEnabled: true,
  );

  const next = ActiveBlock(
    id: 'b2',
    name: 'Break',
    description: '',
    category: 4,
    duration: Duration(minutes: 15),
    trackEnabled: false,
  );

  SessionSnapshot session({
    SessionState state = SessionState.running,
    Duration remaining = const Duration(minutes: 90),
    ActiveBlock? current = block,
    List<ActiveBlock> queue = const <ActiveBlock>[block],
  }) => SessionSnapshot(
    state: state,
    block: current,
    remaining: remaining,
    progress: 0,
    verified: Duration.zero,
    claimed: Duration.zero,
    violations: 0,
    mood: Mood.calm,
    verification: VerificationSnapshot.none,
    queue: queue,
    queueIndex: 0,
  );

  test('a running block arms an alarm at its end', () {
    scheduler.apply(session());

    expect(notifier.pending, isNotNull);
    expect(notifier.pending!.at, now.add(const Duration(minutes: 90)));
    expect(notifier.pending!.title, contains('Deep Work 1'));
  });

  test('the second left in the block is the one it fires on', () {
    scheduler.apply(session(remaining: const Duration(seconds: 42)));
    expect(notifier.pending!.at, now.add(const Duration(seconds: 42)));
  });

  test('ticking does not re-arm it', () {
    // The session publishes every second. Re-arming a system alarm sixty
    // times a minute is a wakelock with a countdown attached.
    for (var i = 0; i < 30; i++) {
      scheduler.apply(session(remaining: Duration(minutes: 90, seconds: -i)));
      now = now.add(const Duration(seconds: 1));
    }
    expect(notifier.scheduled, hasLength(1));
  });

  test('a real change does re-arm it', () {
    scheduler.apply(session());
    // A pause and resume moves the end of the block by more than the drift
    // tolerance, and the alarm has to follow.
    scheduler.apply(session(remaining: const Duration(minutes: 95)));

    expect(notifier.scheduled, hasLength(2));
    expect(notifier.pending!.at, now.add(const Duration(minutes: 95)));
  });

  test('pausing takes the alarm back', () {
    // A paused block has no knowable end: the countdown is frozen, waiting
    // for the user. An alarm then would fire at a moment that means nothing.
    scheduler.apply(session());
    scheduler.apply(session(state: SessionState.paused));

    expect(notifier.cancels, 1);
    expect(scheduler.armedFor, isNull);
  });

  test('finishing takes the alarm back', () {
    scheduler.apply(session());
    scheduler.apply(session(state: SessionState.idle, current: null));
    expect(notifier.cancels, 1);
  });

  test('an idle app never arms anything', () {
    scheduler.apply(session(state: SessionState.idle, current: null));
    expect(notifier.scheduled, isEmpty);
    expect(notifier.cancels, 0, reason: 'there was nothing to cancel');
  });

  test('turning the alarm off takes back what is already armed', () {
    scheduler.apply(session());
    expect(notifier.pending, isNotNull);

    scheduler.enabled = false;
    scheduler.apply(session());

    expect(notifier.cancels, 1);
    expect(scheduler.armedFor, isNull);
  });

  test('the last block says so, and the others name what is next', () {
    scheduler.apply(session(queue: <ActiveBlock>[block, next]));
    expect(notifier.pending!.body, contains('Break'));

    now = now.add(const Duration(hours: 2));
    scheduler.apply(session(queue: <ActiveBlock>[block]));
    expect(notifier.pending!.body, contains('run finished'));
    expect(
      notifier.pending!.title,
      contains('Deep Work 1'),
      reason: 'a notification that says only "done" needs the app opened',
    );
  });

  test('nothing it says is a reprimand', () {
    // The same rule as every other string in the app: an alarm is a fact
    // arriving, not a telling-off.
    scheduler.apply(session(queue: <ActiveBlock>[block, next]));
    final words = '${notifier.pending!.title} ${notifier.pending!.body}'
        .toLowerCase();
    for (final banned in <String>['fail', 'only', 'wasted', 'should', 'lazy']) {
      expect(words, isNot(contains(banned)));
    }
    expect(words, isNot(contains('!')));
  });
}
