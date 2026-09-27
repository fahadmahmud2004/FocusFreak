import 'package:flutter_test/flutter_test.dart';
import 'package:focusfreak_app/domain/engine/session_engine.dart';
import 'package:focusfreak_app/domain/model/session_state.dart';
import 'package:focusfreak_app/domain/model/verification.dart';

/// The session machine, pinned to the second.
///
/// The three grace numbers (30 s / 5 min / 15 s) are the behaviour design of
/// the whole product. These tests exist so a refactor cannot quietly move them.
void main() {
  final t0 = DateTime(2026, 8, 2, 9);

  ActiveBlock block({
    Duration duration = const Duration(minutes: 90),
    bool track = true,
  }) => ActiveBlock(
    id: 'b1',
    name: 'Deep Work 1',
    category: 0,
    duration: duration,
    trackEnabled: track,
  );

  /// A 3-factor bot reading.
  VerificationSnapshot sensors({
    bool present = true,
    bool docked = true,
    bool locked = true,
    bool track = true,
  }) => VerificationSnapshot(
    trackEnabled: track,
    factors: <VerificationFactor, FactorState>{
      VerificationFactor.presence: present
          ? FactorState.holding
          : FactorState.violated,
      VerificationFactor.dock: docked
          ? FactorState.holding
          : FactorState.violated,
      VerificationFactor.screenLock: locked
          ? FactorState.holding
          : FactorState.violated,
    },
  );

  group('verification verdict', () {
    test('tracking off is verified regardless of factors', () {
      expect(
        sensors(present: false, docked: false, track: false).isVerified,
        isTrue,
      );
    });

    test('no factors available is NOT verified', () {
      const s = VerificationSnapshot(
        trackEnabled: true,
        factors: <VerificationFactor, FactorState>{},
      );
      expect(
        s.isVerified,
        isFalse,
        reason:
            'claiming verification with zero evidence is the exact '
            'dishonesty this product replaces',
      );
    });

    test('unavailable factors are excluded, not assumed', () {
      // App-only: no presence sensor exists. The screen is locked, so this is
      // a legitimately verified app-only session.
      const s = VerificationSnapshot(
        trackEnabled: true,
        factors: <VerificationFactor, FactorState>{
          VerificationFactor.screenLock: FactorState.holding,
          VerificationFactor.presence: FactorState.unavailable,
        },
      );
      expect(s.isVerified, isTrue);
      expect(s.available, <VerificationFactor>[VerificationFactor.screenLock]);
    });

    test('one violated factor fails the whole verdict', () {
      expect(sensors(present: false).isVerified, isFalse);
      expect(sensors(docked: false).isVerified, isFalse);
      expect(sensors(locked: false).isVerified, isFalse);
    });

    test('availability mask records which factors had a source', () {
      final s = sensors();
      expect(
        s.availabilityMask,
        VerificationFactor.presence.bit |
            VerificationFactor.dock.bit |
            VerificationFactor.screenLock.bit,
      );
    });
  });

  group('arming', () {
    test('does not count time until verification is satisfied', () {
      final e = SessionEngine()..start(block(), t0);
      expect(e.state, SessionState.armed);

      e.tick(t0.add(const Duration(seconds: 10)), sensors(docked: false));
      expect(e.state, SessionState.armed);
      expect(e.claimed, Duration.zero);
    });

    test('starts running the moment conditions are met', () {
      final e = SessionEngine()..start(block(), t0);
      e.tick(t0.add(const Duration(seconds: 5)), sensors());
      expect(e.state, SessionState.running);
    });

    test('falls back to idle after the 15 s arm timeout', () {
      final e = SessionEngine()..start(block(), t0);

      e.tick(t0.add(const Duration(seconds: 14)), sensors(docked: false));
      expect(e.state, SessionState.armed, reason: '14 s is still armed');

      e.tick(t0.add(const Duration(seconds: 15)), sensors(docked: false));
      expect(e.state, SessionState.idle, reason: '15 s times out');
    });
  });

  group('with auto-pause off, as the app runs it', () {
    // On a phone the screen is on whenever you look at the timer. A countdown
    // that froze on that stopped every time someone checked it.
    test('stepping away never stops the countdown', () {
      final e = SessionEngine(autoPause: false)..start(block(), t0);
      final start = t0.add(const Duration(seconds: 1));
      e.tick(start, sensors());
      for (var s = 1; s <= 600; s++) {
        e.tick(start.add(Duration(seconds: s)), sensors(present: false));
      }
      expect(e.state, SessionState.running);
      expect(e.claimed, const Duration(minutes: 10));
      expect(e.verified, Duration.zero, reason: 'time away is not verified');
    });

    test('turning it off releases a pause it caused', () {
      final e = SessionEngine()..start(block(), t0);
      final start = t0.add(const Duration(seconds: 1));
      e.tick(start, sensors());
      e.tick(start.add(const Duration(seconds: 1)), sensors(present: false));
      e.tick(start.add(const Duration(seconds: 40)), sensors(present: false));
      expect(e.state, SessionState.paused);
      e.autoPause = false;
      e.tick(start.add(const Duration(seconds: 41)), sensors(present: false));
      expect(e.state, SessionState.running);
    });

    test('a pause you chose still waits for you', () {
      final e = SessionEngine(autoPause: false)..start(block(), t0);
      final start = t0.add(const Duration(seconds: 1));
      e.tick(start, sensors());
      e.pauseManually(start.add(const Duration(seconds: 5)));
      e.tick(start.add(const Duration(seconds: 6)), sensors());
      expect(e.state, SessionState.paused);
    });
  });

  group('the 30 second running grace', () {
    late SessionEngine e;
    late DateTime runStart;

    setUp(() {
      e = SessionEngine()..start(block(), t0);
      runStart = t0.add(const Duration(seconds: 1));
      e.tick(runStart, sensors());
    });

    test(
      '29 s unverified stays RUNNING — getting water is not a violation',
      () {
        e.tick(
          runStart.add(const Duration(seconds: 1)),
          sensors(present: false),
        );
        e.tick(
          runStart.add(const Duration(seconds: 30)),
          sensors(present: false),
        );
        expect(e.state, SessionState.running);
      },
    );

    test('31 s unverified pauses', () {
      e.tick(runStart.add(const Duration(seconds: 1)), sensors(present: false));
      e.tick(
        runStart.add(const Duration(seconds: 32)),
        sensors(present: false),
      );
      expect(e.state, SessionState.paused);
    });

    test('the boundary is exactly 30 s, inclusive', () {
      final vStart = runStart.add(const Duration(seconds: 1));
      e.tick(vStart, sensors(present: false));

      e.tick(vStart.add(const Duration(seconds: 29)), sensors(present: false));
      expect(e.state, SessionState.running, reason: '29 s: still running');

      e.tick(vStart.add(const Duration(seconds: 30)), sensors(present: false));
      expect(e.state, SessionState.paused, reason: '30 s: pauses');
    });

    test('claimed advances during the grace but verified does not', () {
      final vStart = runStart.add(const Duration(seconds: 10));
      e.tick(vStart, sensors());
      expect(e.verified, const Duration(seconds: 10));
      expect(e.claimed, const Duration(seconds: 10));

      e.tick(vStart.add(const Duration(seconds: 20)), sensors(present: false));
      expect(
        e.claimed,
        const Duration(seconds: 30),
        reason: 'the block timer kept running',
      );
      expect(
        e.verified,
        const Duration(seconds: 10),
        reason: 'but those 20 s were not verified — this gap is the product',
      );
    });

    test('recovering inside the grace resumes verified counting cleanly', () {
      final vStart = runStart.add(const Duration(seconds: 5));
      e.tick(vStart, sensors());
      e.tick(vStart.add(const Duration(seconds: 10)), sensors(present: false));
      e.tick(vStart.add(const Duration(seconds: 20)), sensors());

      expect(e.state, SessionState.running);
      expect(e.unverifiedFor(vStart.add(const Duration(seconds: 20))), isNull);
      expect(e.verified, const Duration(seconds: 15));
      expect(e.claimed, const Duration(seconds: 25));
    });
  });

  group('the 5 minute paused window', () {
    late SessionEngine e;
    late DateTime vStart;

    setUp(() {
      e = SessionEngine()..start(block(), t0);
      e.tick(t0.add(const Duration(seconds: 1)), sensors());
      vStart = t0.add(const Duration(seconds: 2));
      e.tick(vStart, sensors(present: false));
      e.tick(vStart.add(const Duration(seconds: 31)), sensors(present: false));
      expect(e.state, SessionState.paused);
    });

    test('4 min 59 s stays recoverable', () {
      e.tick(
        vStart.add(const Duration(minutes: 4, seconds: 59)),
        sensors(present: false),
      );
      expect(e.state, SessionState.paused);
    });

    test('5 min 01 s breaks the session', () {
      e.tick(
        vStart.add(const Duration(minutes: 5, seconds: 1)),
        sensors(present: false),
      );
      expect(e.state, SessionState.broken);
    });

    test('the boundary is exactly 5 min, inclusive', () {
      e.tick(vStart.add(const Duration(minutes: 5)), sensors(present: false));
      expect(e.state, SessionState.broken);
    });

    test('both timers stay frozen while paused', () {
      final claimedAtPause = e.claimed;
      final verifiedAtPause = e.verified;

      e.tick(vStart.add(const Duration(minutes: 3)), sensors(present: false));

      expect(e.claimed, claimedAtPause, reason: 'the countdown must freeze');
      expect(e.verified, verifiedAtPause);
    });

    test('coming back resumes rather than penalising', () {
      e.tick(vStart.add(const Duration(minutes: 2)), sensors());
      expect(e.state, SessionState.running);

      e.tick(vStart.add(const Duration(minutes: 2, seconds: 10)), sensors());
      expect(e.verified, greaterThan(Duration.zero));
    });
  });

  group('completion', () {
    test('completes when the block duration is reached', () {
      final e = SessionEngine()
        ..start(block(duration: const Duration(minutes: 1)), t0);
      e.tick(t0.add(const Duration(seconds: 1)), sensors());
      final events = e.tick(t0.add(const Duration(seconds: 61)), sensors());

      expect(e.state, SessionState.complete);
      expect(
        e.claimed,
        const Duration(minutes: 1),
        reason: 'claimed is clamped to the block duration',
      );
      expect(events.whereType<SessionCompleted>(), hasLength(1));
    });

    test('an untracked block is a plain timer and always counts', () {
      final e = SessionEngine()
        ..start(block(duration: const Duration(seconds: 30), track: false), t0);
      e.tick(
        t0.add(const Duration(seconds: 1)),
        sensors(present: false, docked: false, track: false),
      );
      expect(e.state, SessionState.running);

      e.tick(
        t0.add(const Duration(seconds: 31)),
        sensors(present: false, docked: false, track: false),
      );
      expect(e.state, SessionState.complete);
      expect(e.verified, e.claimed);
    });

    test('stopping early is recorded as broken, not complete', () {
      final e = SessionEngine()..start(block(), t0);
      e.tick(t0.add(const Duration(seconds: 1)), sensors());

      final events = e.stop(t0.add(const Duration(minutes: 5)));
      expect(e.state, SessionState.broken);
      expect(
        events.whereType<SessionTransition>().single.reason,
        ViolationReason.cancelled,
      );
    });

    test('skipping keeps what was earned', () {
      final e = SessionEngine()..start(block(), t0);
      e.tick(t0.add(const Duration(seconds: 1)), sensors());

      // Tick at a realistic cadence — a single 10-minute jump would be capped
      // by the suspension guard, which is a different behaviour (tested below).
      for (var s = 2; s <= 600; s += 10) {
        e.tick(t0.add(Duration(seconds: s)), sensors());
      }

      e.skip(t0.add(const Duration(minutes: 10)));
      expect(e.state, SessionState.complete);
      expect(e.verified, const Duration(seconds: 591));
      expect(e.verified, e.claimed, reason: 'never left the desk');
    });
  });

  group('violations', () {
    test('records the most explanatory reason', () {
      final e = SessionEngine()..start(block(), t0);
      e.tick(t0.add(const Duration(seconds: 1)), sensors());

      final events = e.tick(
        t0.add(const Duration(seconds: 2)),
        sensors(present: false, docked: false),
      );
      final v = events.whereType<SessionViolation>().single;
      expect(
        v.reason,
        ViolationReason.absent,
        reason: 'leaving the desk explains more than the dock reading',
      );
    });

    test('a continuing violation is not counted repeatedly', () {
      final e = SessionEngine()..start(block(), t0);
      e.tick(t0.add(const Duration(seconds: 1)), sensors());

      for (var i = 2; i < 20; i++) {
        e.tick(t0.add(Duration(seconds: i)), sensors(docked: false));
      }
      expect(e.violations, 1);
    });

    test('a new distinct violation is counted separately', () {
      final e = SessionEngine()..start(block(), t0);
      e.tick(t0.add(const Duration(seconds: 1)), sensors());
      e.tick(t0.add(const Duration(seconds: 2)), sensors(docked: false));
      e.tick(t0.add(const Duration(seconds: 3)), sensors());
      e.tick(t0.add(const Duration(seconds: 4)), sensors(present: false));
      expect(e.violations, 2);
    });
  });

  group('robustness', () {
    test('a suspended process cannot invent focus minutes', () {
      final e = SessionEngine()..start(block(), t0);
      e.tick(t0.add(const Duration(seconds: 1)), sensors());

      // The app was backgrounded for an hour and the next tick is far away.
      e.tick(t0.add(const Duration(hours: 1)), sensors());

      expect(
        e.verified,
        const Duration(minutes: 2),
        reason: 'a gap larger than 2 minutes is capped, not trusted',
      );
    });

    test('a clock that moves backwards does not subtract time', () {
      final e = SessionEngine()..start(block(), t0);
      e.tick(t0.add(const Duration(seconds: 10)), sensors());
      final before = e.verified;

      e.tick(t0.add(const Duration(seconds: 5)), sensors());
      expect(e.verified, before);
    });

    test('ticking an idle engine does nothing', () {
      final e = SessionEngine();
      expect(e.tick(t0, sensors()), isEmpty);
      expect(e.state, SessionState.idle);
    });

    test('manual pause does not escalate to broken', () {
      final e = SessionEngine()..start(block(), t0);
      e.tick(t0.add(const Duration(seconds: 1)), sensors());
      e.pauseManually(t0.add(const Duration(seconds: 2)));

      e.tick(t0.add(const Duration(minutes: 30)), sensors());
      expect(
        e.state,
        isNot(SessionState.broken),
        reason: 'the user chose this; there is nothing to escalate',
      );
    });

    test('a manual pause holds until the user resumes it', () {
      // This test previously asserted the opposite, and the opposite was a
      // bug: one tick later the engine saw a paused session with verification
      // holding and resumed it, so the pause button appeared to do nothing.
      final e = SessionEngine()..start(block(), t0);
      e.tick(t0.add(const Duration(seconds: 1)), sensors());
      e.pauseManually(t0.add(const Duration(seconds: 2)));

      // The very next tick is where it used to come undone.
      e.tick(t0.add(const Duration(seconds: 3)), sensors());
      expect(e.state, SessionState.paused);
      expect(e.isPausedByUser, isTrue);

      e.tick(t0.add(const Duration(minutes: 10)), sensors());
      expect(e.state, SessionState.paused, reason: 'still the user\'s call');

      final frozen = e.remaining;
      e.tick(t0.add(const Duration(minutes: 20)), sensors());
      expect(e.remaining, frozen, reason: 'the countdown stays frozen');

      e.resume(t0.add(const Duration(minutes: 21)));
      expect(e.state, SessionState.running);
      expect(e.isPausedByUser, isFalse);
    });

    test('a verification pause still resumes on its own', () {
      // The distinction that makes the fix safe: only the pause the *user*
      // asked for waits for the user. Sitting back down still resumes.
      final e = SessionEngine()..start(block(), t0);
      e.tick(t0.add(const Duration(seconds: 1)), sensors());
      e.tick(t0.add(const Duration(seconds: 2)), sensors(present: false));
      e.tick(t0.add(const Duration(seconds: 40)), sensors(present: false));
      expect(e.state, SessionState.paused);
      expect(e.isPausedByUser, isFalse);

      e.tick(t0.add(const Duration(seconds: 45)), sensors());
      expect(e.state, SessionState.running);
    });

    test('starting a new block clears a manual pause', () {
      final e = SessionEngine()..start(block(), t0);
      e.tick(t0.add(const Duration(seconds: 1)), sensors());
      e.pauseManually(t0.add(const Duration(seconds: 2)));

      e.start(block(), t0.add(const Duration(minutes: 1)));
      e.tick(t0.add(const Duration(minutes: 1, seconds: 1)), sensors());
      expect(e.state, SessionState.running);
      expect(e.isPausedByUser, isFalse);
    });
  });
}
