import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusfreak_app/data/db/database.dart';
import 'package:focusfreak_app/data/repo/session_repository.dart';
import 'package:focusfreak_app/domain/engine/session_engine.dart';
import 'package:focusfreak_app/domain/engine/verification_source.dart';
import 'package:focusfreak_app/domain/model/session_state.dart';
import 'package:focusfreak_app/domain/model/verification.dart';
import 'package:focusfreak_app/features/timer/session_controller.dart';

/// Auto mode: running a whole routine as one unit.
void main() {
  late AppDatabase db;
  late SessionRepository repo;
  late ManualVerificationSource source;
  late SessionController controller;

  Block block(int i, String name, int minutes, {bool track = true}) => Block(
    id: 'b$i',
    routineId: 'r1',
    position: i,
    name: name,
    description: '',
    durationMin: minutes,
    category: 0,
    trackEnabled: track,
    startMin: 0xFFFF,
  );

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = SessionRepository(db);
    source = ManualVerificationSource(
      provides: <VerificationFactor>{
        VerificationFactor.presence,
        VerificationFactor.dock,
        VerificationFactor.screenLock,
      },
    );
    controller = SessionController(repo, source);
  });

  tearDown(() async {
    controller.dispose();
    await source.dispose();
    await db.close();
  });

  group('single block', () {
    test('starts armed and becomes running once verification holds', () async {
      await controller.startBlock(
        const ActiveBlock(
          id: 'q1',
          name: 'Focus',
          category: 0,
          duration: Duration(minutes: 25),
          trackEnabled: true,
        ),
      );

      expect(controller.state.block?.name, 'Focus');
      expect(controller.state.isActive, isTrue);
      expect(controller.state.autoMode, isFalse);
      expect(controller.state.queue, hasLength(1));
    });

    test('an untracked block starts even with every factor violated', () async {
      source.setAll(false);
      await controller.startBlock(
        const ActiveBlock(
          id: 'q1',
          name: 'Plain',
          category: 2,
          duration: Duration(minutes: 10),
          trackEnabled: false,
        ),
      );
      expect(controller.state.isVerified, isTrue);
    });

    test('a session row is written as soon as the block is armed', () async {
      await controller.startBlock(
        const ActiveBlock(
          id: 'q1',
          name: 'Focus',
          category: 0,
          duration: Duration(minutes: 25),
          trackEnabled: true,
        ),
      );

      final rows = await db.select(db.sessions).get();
      expect(
        rows,
        hasLength(1),
        reason: 'a crash mid-session must still leave evidence',
      );
      expect(rows.single.blockName, 'Focus');
      expect(rows.single.endedAt, isNull);
    });
  });

  group('auto mode', () {
    final blocks = <Block>[
      block(0, 'Deep Work 1', 90),
      block(1, 'Break', 15, track: false),
      block(2, 'Deep Work 2', 90),
    ];

    test('queues the whole routine and starts at the chosen block', () async {
      await controller.startRoutine(blocks, routineId: 'r1', from: 1);

      expect(controller.state.autoMode, isTrue);
      expect(controller.state.queue, hasLength(3));
      expect(controller.state.queueIndex, 1);
      expect(controller.state.block?.name, 'Break');
      expect(controller.state.nextBlock?.name, 'Deep Work 2');
    });

    test('finishing a block arms the next one automatically', () async {
      await controller.startRoutine(blocks, routineId: 'r1');
      expect(controller.state.block?.name, 'Deep Work 1');

      await controller.skip();

      expect(
        controller.state.block?.name,
        'Break',
        reason: 'auto mode is what turns a list into an operating system',
      );
      expect(controller.state.queueIndex, 1);
      expect(controller.state.isActive, isTrue);
    });

    test('the last block ends the routine rather than looping', () async {
      await controller.startRoutine(blocks, routineId: 'r1', from: 2);
      await controller.skip();

      expect(controller.state.isActive, isFalse);
      expect(controller.state.state, SessionState.idle);
    });

    test('every completed block leaves its own session row', () async {
      await controller.startRoutine(blocks, routineId: 'r1');
      await controller.skip();
      await controller.skip();
      await controller.skip();

      final rows = await db.select(db.sessions).get();
      expect(rows, hasLength(3));
      expect(rows.map((r) => r.blockName), <String>[
        'Deep Work 1',
        'Break',
        'Deep Work 2',
      ]);
      expect(rows.every((r) => r.endedAt != null), isTrue);
      expect(rows.every((r) => r.routineId == 'r1'), isTrue);
    });

    test('stopping ends the routine, it does not skip ahead', () async {
      await controller.startRoutine(blocks, routineId: 'r1');
      await controller.stop();

      expect(controller.state.isActive, isFalse);
      final rows = await db.select(db.sessions).get();
      expect(
        rows,
        hasLength(1),
        reason: 'stopping must not silently start the next block',
      );
      expect(rows.single.finalState, SessionState.broken.index);
    });

    test('starting a new routine closes the previous session', () async {
      await controller.startRoutine(blocks, routineId: 'r1');
      await controller.startRoutine(<Block>[
        block(9, 'Other', 30),
      ], routineId: 'r2');

      final rows = await db.select(db.sessions).get();
      expect(rows, hasLength(2));
      final first = rows.firstWhere((r) => r.blockName == 'Deep Work 1');
      expect(
        first.endedAt,
        isNotNull,
        reason: 'an abandoned session must not stay open forever',
      );
    });

    test('day totals are rebuilt as blocks finish', () async {
      await controller.startRoutine(blocks, routineId: 'r1');
      await controller.skip();

      final days = await repo.allDays();
      expect(days, hasLength(1));
      expect(days.single.blocksTotal, greaterThan(0));
    });
  });

  group('provenance', () {
    test('a three-factor session is recorded as sensor-verified', () async {
      await controller.startBlock(
        const ActiveBlock(
          id: 'q1',
          name: 'Focus',
          category: 0,
          duration: Duration(minutes: 25),
          trackEnabled: true,
        ),
      );
      await controller.skip();

      final row = (await db.select(db.sessions).get()).single;
      expect(row.provenance, Provenance.sensorVerified.index);
      expect(row.factorMask & VerificationFactor.presence.bit, isNonZero);
    });

    test('a phone-only session is recorded as app-verified', () async {
      final phoneOnly = ManualVerificationSource(
        provides: <VerificationFactor>{VerificationFactor.screenLock},
      );
      final c = SessionController(repo, phoneOnly);
      addTearDown(() async {
        c.dispose();
        await phoneOnly.dispose();
      });

      await c.startBlock(
        const ActiveBlock(
          id: 'q2',
          name: 'Focus',
          category: 0,
          duration: Duration(minutes: 25),
          trackEnabled: true,
        ),
      );
      await c.skip();

      final row = (await db.select(db.sessions).get()).single;
      expect(
        row.provenance,
        Provenance.appVerified.index,
        reason:
            'without a presence sensor this cannot claim to be '
            'sensor-verified',
      );
    });
  });
}
