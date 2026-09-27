import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusfreak_app/data/db/database.dart';
import 'package:focusfreak_app/data/repo/session_repository.dart';
import 'package:focusfreak_app/domain/engine/session_engine.dart';
import 'package:focusfreak_app/domain/engine/verification_source.dart';
import 'package:focusfreak_app/domain/model/verification.dart';
import 'package:focusfreak_app/features/sound/sound_cues.dart';
import 'package:focusfreak_app/features/timer/session_controller.dart';
import 'package:focusfreak_app/platform/sound_player.dart';

/// The claim this file defends: the app makes a noise at the four moments it
/// should, and at no other — in particular, never when a block breaks.
void main() {
  group('SoundCues', () {
    late SilentSoundOutput out;
    late SoundCues cues;

    setUp(() {
      out = SilentSoundOutput();
      cues = SoundCues(out);
    });

    test('each cue has its own sound', () {
      cues
        ..onCue(SessionCue.blockStarted)
        ..onCue(SessionCue.finalSecond)
        ..onCue(SessionCue.blockEnded);

      expect(out.played, <FfSound>[
        FfSound.blockStart,
        FfSound.tick,
        FfSound.blockEnd,
      ]);
    });

    test('the end of a run rings as well as chimes', () {
      cues.onCue(SessionCue.runCompleted);
      expect(out.played, <FfSound>[FfSound.blockEnd, FfSound.alarm]);
    });

    test('effects off still leaves the alarm', () {
      // The library case: no ticking, but the thing that reaches you in the
      // next room still works.
      cues.effectsEnabled = false;
      cues
        ..onCue(SessionCue.blockStarted)
        ..onCue(SessionCue.finalSecond)
        ..onCue(SessionCue.runCompleted);

      expect(out.played, <FfSound>[FfSound.alarm]);
    });

    test('alarm off leaves the chime', () {
      cues.alarmEnabled = false;
      cues.onCue(SessionCue.runCompleted);
      expect(out.played, <FfSound>[FfSound.blockEnd]);
    });

    test('both off is silent', () {
      cues
        ..effectsEnabled = false
        ..alarmEnabled = false
        ..onCue(SessionCue.runCompleted)
        ..onCue(SessionCue.blockStarted);
      expect(out.played, isEmpty);
    });
  });

  group('what the session announces', () {
    late AppDatabase db;
    late SessionRepository repo;
    late ManualVerificationSource source;
    late SessionController controller;
    late List<SessionCue> heard;

    Block block(int i, String name, int minutes) => Block(
      id: 'b$i',
      routineId: 'r1',
      position: i,
      name: name,
      description: '',
      durationMin: minutes,
      category: 0,
      trackEnabled: true,
      startMin: 0xFFFF,
    );

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = SessionRepository(db);
      source = ManualVerificationSource(
        provides: <VerificationFactor>{VerificationFactor.screenLock},
      )..set(VerificationFactor.screenLock, true);
      controller = SessionController(repo, source);
      heard = <SessionCue>[];
      controller.cues.listen(heard.add);
    });

    tearDown(() async {
      controller.dispose();
      await source.dispose();
      await db.close();
    });

    test('every block in a routine announces its own start and end', () async {
      // In auto mode the next block replaces the finished one before anything
      // outside the controller sees a `complete`, which is exactly why these
      // are emitted rather than inferred from the state.
      await controller.startRoutine(<Block>[
        block(0, 'Deep Work', 90),
        block(1, 'Break', 15),
      ], routineId: 'r1');
      await Future<void>.delayed(Duration.zero);
      expect(heard, <SessionCue>[SessionCue.blockStarted]);

      heard.clear();
      await controller.skip();
      await Future<void>.delayed(Duration.zero);
      expect(heard, <SessionCue>[
        SessionCue.blockEnded,
        SessionCue.blockStarted,
      ]);

      heard.clear();
      await controller.skip();
      await Future<void>.delayed(Duration.zero);
      expect(heard, <SessionCue>[
        SessionCue.runCompleted,
      ], reason: 'the last block ends the run, it does not hand over');
    });

    test('stopping a block makes no sound at all', () async {
      // A noise when something breaks is the punishment ladder rebuilt.
      await controller.startRoutine(<Block>[
        block(0, 'Deep Work', 90),
      ], routineId: 'r1');
      await Future<void>.delayed(Duration.zero);
      heard.clear();

      await controller.stop();
      await Future<void>.delayed(Duration.zero);
      expect(heard, isEmpty);
    });

    test('the last seconds tick, once each', () async {
      // Real time: the countdown is driven by the controller's own 1 s ticker,
      // so this is the one cue that cannot be tested by skipping ahead.
      await controller.startBlock(
        const ActiveBlock(
          id: 'q1',
          name: 'Short',
          category: 0,
          duration: Duration(seconds: 2),
          trackEnabled: true,
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 3400));

      final ticks = heard.where((c) => c == SessionCue.finalSecond).length;
      expect(
        ticks,
        inInclusiveRange(1, 3),
        reason: 'one tick per second, not one per verification ping',
      );
      expect(heard.last, SessionCue.runCompleted);
    });
  });
}
