import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusfreak_app/core/ff_constants.dart';
import 'package:focusfreak_app/core/ff_format.dart';
import 'package:focusfreak_app/data/db/database.dart';
import 'package:focusfreak_app/data/repo/routine_repository.dart';
import 'package:focusfreak_app/data/repo/session_repository.dart';
import 'package:focusfreak_app/data/repo/settings_repository.dart';
import 'package:focusfreak_app/data/repo/task_repository.dart';
import 'package:focusfreak_app/domain/engine/session_engine.dart';
import 'package:focusfreak_app/domain/model/session_state.dart';
import 'package:focusfreak_app/domain/model/template.dart';
import 'package:focusfreak_app/domain/model/verification.dart';

void main() {
  late AppDatabase db;
  late RoutineRepository routines;
  late SessionRepository sessions;
  late TaskRepository tasks;
  late SettingsRepository settings;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    routines = RoutineRepository(db);
    sessions = SessionRepository(db);
    tasks = TaskRepository(db);
    settings = SettingsRepository(db);
  });

  tearDown(() async => db.close());

  group('templates', () {
    test('every shipped block fits the firmware field widths', () {
      for (final t in Templates.all) {
        for (final b in t.blocks) {
          expect(
            b.name.length,
            lessThanOrEqualTo(FfFirmware.blockNameMaxChars),
            reason: '${t.name} / "${b.name}"',
          );
          expect(
            b.description.length,
            lessThanOrEqualTo(FfFirmware.blockDescMaxChars),
            reason: '${t.name} / "${b.description}"',
          );
          // The bot's font is ASCII. A Bangla name would reach it as boxes.
          expect(
            RegExp(r'^[\x20-\x7E]*$').hasMatch(b.name + b.description),
            isTrue,
            reason: '${t.name} / "${b.name}" is not plain ASCII',
          );
          expect(b.category, inInclusiveRange(0, 5));
          expect(b.durationMin, greaterThan(0));
        }
      }
    });

    test('every full day fills 24 hours with no gaps or overlaps', () {
      // FW's verifyRoutines(). A day can total 1440 and still be wrong if one
      // block ends before the next one starts.
      final days = Templates.all.where((t) => t.isClockAnchored).toList();
      expect(days, hasLength(25));
      for (final t in days) {
        expect(
          t.totalMinutes,
          24 * 60,
          reason: '${t.name} does not add up to a whole day',
        );
        for (var i = 0; i < t.blocks.length; i++) {
          final b = t.blocks[i];
          final next = t.blocks[(i + 1) % t.blocks.length];
          final endsAt = (b.startMin! + b.durationMin) % 1440;
          expect(
            endsAt,
            next.startMin,
            reason:
                '${t.name}: "${b.name}" ends at $endsAt but '
                '"${next.name}" starts at ${next.startMin}',
          );
        }
      }
    });

    test('salah blocks start on their season\'s clock', () {
      // The bug the whole FW engine exists to prevent: the old hand-timed
      // templates shipped a 3 PM Maghrib.
      const at = <RoutineSeason, Map<String, int>>{
        RoutineSeason.summer: <String, int>{
          'Fajr': 285, 'Dhuhr': 780, 'Asr': 1005, 'Maghrib': 1110,
          'Isha': 1220, //
        },
        RoutineSeason.winter: <String, int>{
          'Fajr': 320, 'Dhuhr': 780, 'Asr': 975, 'Maghrib': 1085,
          'Isha': 1160, //
        },
        RoutineSeason.ramadan: <String, int>{
          'Dhuhr': 750, 'Asr': 980, 'Isha': 1160, //
        },
      };
      var checked = 0;
      for (final t in Templates.all.where((t) => t.season != null)) {
        for (final b in t.blocks) {
          for (final salah in at[t.season]!.entries) {
            if (!b.name.startsWith(salah.key)) continue;
            expect(
              b.startMin,
              salah.value,
              reason:
                  '${t.name}: "${b.name}" is off the ${t.season!.label} '
                  '${salah.key} time',
            );
            checked++;
          }
        }
      }
      expect(checked, greaterThan(50));
    });

    test('every full day keeps at least three hours of night sleep', () {
      for (final t in Templates.all.where((t) => t.isClockAnchored)) {
        final sleep = t.blocks.where((b) => b.category == 5);
        expect(
          sleep.any((b) => b.durationMin >= 180),
          isTrue,
          reason: '${t.name} has no real night of sleep',
        );
      }
    });

    test('every summer day has a winter twin', () {
      for (final t in Templates.all.where(
        (t) => t.season == RoutineSeason.summer,
      )) {
        final twin = Templates.byKey('${t.key}Winter');
        expect(twin, isNotNull, reason: '${t.name} has no winter variant');
        expect(twin!.season, RoutineSeason.winter);
      }
    });

    test('sprints have no clock times and run from when they start', () {
      final sprints = Templates.all.where((t) => t.season == null).toList();
      expect(sprints.map((t) => t.key), <String>[
        'deepWork',
        'ultradian',
        'pomodoro',
        'fiftyTwo',
      ]);
      for (final t in sprints) {
        expect(t.blocks.every((b) => b.startMin == null), isTrue);
      }
    });

    test('the season picks the right variant', () {
      expect(RoutineSeason.of(DateTime(2026, 9, 26)), RoutineSeason.summer);
      expect(RoutineSeason.of(DateTime(2026, 11, 1)), RoutineSeason.winter);
      expect(RoutineSeason.of(DateTime(2027, 2, 28)), RoutineSeason.winter);
      expect(RoutineSeason.of(DateTime(2027, 3, 1)), RoutineSeason.summer);
      expect(
        Templates.keyFor('nightOwl', RoutineSeason.winter),
        'nightOwlWinter',
      );
      expect(
        Templates.keyFor('nightOwlWinter', RoutineSeason.summer),
        'nightOwl',
      );
      expect(
        Templates.keyFor('pomodoro', RoutineSeason.winter),
        'pomodoro',
        reason: 'a sprint has no seasons to switch between',
      );
    });

    test('template keys are unique', () {
      final keys = Templates.all.map((t) => t.key).toList();
      expect(keys.toSet().length, keys.length);
    });

    test('study is tracked by default, breaks and sleep are not', () {
      for (final t in Templates.all) {
        for (final b in t.blocks) {
          if (b.category == 0) {
            expect(b.track, isTrue, reason: '${t.name} / ${b.name}');
          }
          if (b.category == 4 || b.category == 5) {
            expect(
              b.track,
              isFalse,
              reason:
                  '${t.name} / ${b.name} must not be tracked — '
                  'a nap is not a violation',
            );
          }
        }
      }
    });
  });

  group('routine seeding', () {
    test('seeds every shipped template with its blocks', () async {
      await routines.seedTemplates();
      final all = await routines.watchAll().first;
      expect(all, hasLength(Templates.all.length));

      final standard = all.firstWhere(
        (r) => r.templateKey == Templates.standard.key,
      );
      final loaded = await routines.load(standard.id);
      final n = Templates.standard.blocks.length;
      expect(loaded!.blocks, hasLength(n));
      expect(loaded.blocks.first.name, 'Wake & Fajr');
      expect(loaded.blocks.map((b) => b.position), List.generate(n, (i) => i));
    });

    test('rewrites a built-in whose shipped blocks changed', () async {
      // A phone keeps whatever the first version it ran shipped, unless the
      // seed brings built-ins forward. They are read-only, so nothing of the
      // user's is lost.
      await routines.seedTemplates();
      final standard = (await routines.watchAll().first).firstWhere(
        (r) => r.templateKey == Templates.standard.key,
      );
      final first = (await routines.load(standard.id))!.blocks.first;
      await (db.update(db.blocks)..where((t) => t.id.equals(first.id))).write(
        const BlocksCompanion(name: Value('Wake & Freshen')),
      );
      await routines.archive(standard.id);

      await routines.seedTemplates();

      final after = await routines.load(standard.id);
      expect(after!.blocks.first.name, 'Wake & Fajr');
      expect(after.blocks, hasLength(Templates.standard.blocks.length));
      expect(
        after.routine.archived,
        isTrue,
        reason: 'a template the user hid stays hidden',
      );
    });

    test('removes built-ins this version no longer ships', () async {
      await routines.seedTemplates();
      final now = DateTime(2026, 8, 1);
      await db
          .into(db.routines)
          .insert(
            RoutinesCompanion.insert(
              id: 'old',
              name: 'Deload Day',
              isBuiltIn: const Value(true),
              templateKey: const Value('deload'),
              createdAt: now,
              updatedAt: now,
            ),
          );
      final mine = await routines.create(name: 'Mine');

      await routines.seedTemplates();

      expect(await routines.load('old'), isNull);
      expect(
        await routines.load(mine),
        isNotNull,
        reason: 'a user routine is never touched by seeding',
      );
    });

    test('is idempotent — running it twice does not duplicate', () async {
      await routines.seedTemplates();
      await routines.seedTemplates();
      final all = await routines.watchAll().first;
      expect(all, hasLength(Templates.all.length));
    });

    test(
      'adds only newly shipped templates, leaving existing ones alone',
      () async {
        await routines.seedTemplates();
        final before = await routines.watchAll().first;
        final standard = before.firstWhere(
          (r) => r.templateKey == Templates.standard.key,
        );

        // Simulate a template that was removed from the user's install.
        await (db.delete(
          db.routines,
        )..where((t) => t.id.equals(standard.id))).go();
        await routines.seedTemplates();

        final after = await routines.watchAll().first;
        expect(after, hasLength(Templates.all.length));
      },
    );
  });

  group('routine editing', () {
    late String id;

    setUp(() async {
      id = await routines.create(name: 'My Routine');
      await routines.addBlock(
        id,
        name: 'A',
        durationMin: 30,
        category: 0,
        trackEnabled: true,
      );
      await routines.addBlock(id, name: 'B', durationMin: 15, category: 4);
      await routines.addBlock(id, name: 'C', durationMin: 45, category: 2);
    });

    test('blocks keep contiguous positions', () async {
      final r = await routines.load(id);
      expect(r!.blocks.map((b) => b.name), <String>['A', 'B', 'C']);
      expect(r.blocks.map((b) => b.position), <int>[0, 1, 2]);
    });

    test('reorder renumbers everything', () async {
      await routines.reorder(id, 2, 0);
      final r = await routines.load(id);
      expect(r!.blocks.map((b) => b.name), <String>['C', 'A', 'B']);
      expect(r.blocks.map((b) => b.position), <int>[0, 1, 2]);
    });

    test('deleting a block closes the gap in positions', () async {
      final r0 = await routines.load(id);
      await routines.deleteBlock(r0!.blocks[1].id);

      final r = await routines.load(id);
      expect(r!.blocks.map((b) => b.name), <String>['A', 'C']);
      expect(
        r.blocks.map((b) => b.position),
        <int>[0, 1],
        reason: 'a gap here would break the device push, which is indexed',
      );
    });

    test('inserting at a position shifts the rest down', () async {
      await routines.addBlock(
        id,
        name: 'New',
        durationMin: 10,
        category: 1,
        position: 1,
      );
      final r = await routines.load(id);
      expect(r!.blocks.map((b) => b.name), <String>['A', 'New', 'B', 'C']);
      expect(r.blocks.map((b) => b.position), <int>[0, 1, 2, 3]);
    });

    test('over-long names are clamped to the firmware width', () async {
      await routines.addBlock(
        id,
        name: 'This name is far too long for the struct',
        durationMin: 10,
        category: 0,
      );
      final r = await routines.load(id);
      expect(r!.blocks.last.name.length, FfFirmware.blockNameMaxChars);
    });

    test('duplicate copies the blocks but not the identity', () async {
      final copyId = await routines.duplicate(id);
      expect(copyId, isNot(id));

      final copy = await routines.load(copyId);
      expect(copy!.blocks.map((b) => b.name), <String>['A', 'B', 'C']);
      expect(
        copy.blocks.first.id,
        isNot((await routines.load(id))!.blocks.first.id),
        reason: 'blocks must be new rows, not shared ones',
      );
    });

    test('deleting a built-in archives it instead', () async {
      await routines.seedTemplates();
      final all = await routines.watchAll().first;
      final builtIn = all.firstWhere((r) => r.isBuiltIn);

      await routines.delete(builtIn.id);

      expect(
        await routines.load(builtIn.id),
        isNotNull,
        reason: 'a shipped template is part of the app, not user data',
      );
      final visible = await routines.watchAll().first;
      expect(visible.map((r) => r.id), isNot(contains(builtIn.id)));
    });

    test('restoring brings back every hidden template', () async {
      // The dead end this fixes: hide them all, and the empty screen offers
      // "Install templates" — which does nothing, because none are missing.
      // They are all still there, archived.
      await routines.seedTemplates();
      for (final r in (await routines.watchAll().first).where(
        (r) => r.isBuiltIn,
      )) {
        await routines.delete(r.id);
      }
      Future<Iterable<Routine>> visibleTemplates() async =>
          (await routines.watchAll().first).where((r) => r.isBuiltIn);

      expect(await visibleTemplates(), isEmpty);

      await routines.seedTemplates();
      expect(
        await visibleTemplates(),
        isEmpty,
        reason: 'seeding alone cannot fix this — nothing is missing',
      );

      await routines.restoreTemplates();
      final back = await routines.watchAll().first;
      expect(back.where((r) => r.isBuiltIn), hasLength(Templates.all.length));
    });

    test('a hidden template can be brought back', () async {
      // Hiding was a one-way door for a while: the tile left the list and
      // nothing in the app could restore it. Anything one tap removes, one
      // tap has to be able to return.
      await routines.seedTemplates();
      final builtIn = (await routines.watchAll().first).firstWhere(
        (r) => r.isBuiltIn,
      );

      await routines.delete(builtIn.id);
      final hidden = (await routines.watchAll(includeArchived: true).first)
          .where((r) => r.archived);
      expect(hidden.map((r) => r.id), contains(builtIn.id));

      await routines.archive(builtIn.id, archived: false);

      final visible = await routines.watchAll().first;
      expect(visible.map((r) => r.id), contains(builtIn.id));
      final restored = await routines.load(builtIn.id);
      expect(
        restored!.blocks,
        isNotEmpty,
        reason: 'its blocks were never deleted, only hidden with it',
      );
    });
  });

  group('timed routines', () {
    late String id;

    // A small day on the clock: 08:00 A (60) · 09:00 B (30) · 09:30 C (45).
    setUp(() async {
      id = await routines.create(name: 'Day');
      await routines.addBlock(
        id,
        name: 'A',
        durationMin: 60,
        category: 0,
        startMin: 480,
      );
      await routines.addBlock(id, name: 'B', durationMin: 30, category: 4);
      await routines.addBlock(id, name: 'C', durationMin: 45, category: 2);
    });

    Future<List<int>> starts() async =>
        (await routines.load(id))!.blocks.map((b) => b.startMin).toList();

    test('every block is timed from the one before it', () async {
      expect(await starts(), <int>[480, 540, 570]);
    });

    test('changing a duration moves everything after it', () async {
      final b = (await routines.load(id))!.blocks[0];
      await routines.updateBlock(b.id, durationMin: 90);
      expect(await starts(), <int>[480, 570, 600]);
    });

    test('moving the first block moves the whole routine', () async {
      final a = (await routines.load(id))!.blocks[0];
      await routines.updateBlock(a.id, startMin: 420);
      expect(await starts(), <int>[420, 480, 510]);
    });

    test('moving a later block stretches the one before it', () async {
      // "Start C at 10:00" means B runs 30 minutes longer.
      final c = (await routines.load(id))!.blocks[2];
      await routines.updateBlock(c.id, startMin: 600);
      final r = await routines.load(id);
      expect(r!.blocks.map((b) => b.durationMin), <int>[60, 60, 45]);
      expect(await starts(), <int>[480, 540, 600]);
    });

    test('a start across midnight is a short move, not a day', () async {
      // A at 22:25 puts C at 23:55. "Start C at 00:05" is ten minutes later,
      // not twenty-three hours and fifty minutes earlier.
      final a = (await routines.load(id))!.blocks[0];
      await routines.updateBlock(a.id, startMin: 1345);
      final c = (await routines.load(id))!.blocks[2];
      expect(c.startMin, 1435);
      await routines.updateBlock(c.id, startMin: 5);
      final r = await routines.load(id);
      expect(r!.blocks[1].durationMin, 40);
      expect(await starts(), <int>[1345, 1405, 5]);
    });

    test('reordering keeps the routine\'s start', () async {
      await routines.reorder(id, 0, 2);
      final r = await routines.load(id);
      expect(r!.blocks.map((b) => b.name), <String>['B', 'C', 'A']);
      expect(await starts(), <int>[480, 510, 555]);
    });

    test('deleting the first block keeps the start too', () async {
      final a = (await routines.load(id))!.blocks[0];
      await routines.deleteBlock(a.id);
      expect(await starts(), <int>[480, 510]);
    });

    test('a sequential routine stays sequential', () async {
      final seq = await routines.create(name: 'Sprint');
      await routines.addBlock(seq, name: 'X', durationMin: 25, category: 0);
      await routines.addBlock(seq, name: 'Y', durationMin: 5, category: 4);
      final r = await routines.load(seq);
      expect(
        r!.blocks.every((b) => b.startMin == FfFirmware.sequentialStartMin),
        isTrue,
      );
      expect(r.isTimed, isFalse);
    });
  });

  group('device window', () {
    test('a long routine goes to the bot sixteen blocks at a time', () async {
      final id = await routines.create(name: 'Long');
      for (var i = 0; i < 20; i++) {
        await routines.addBlock(
          id,
          name: 'Block $i',
          durationMin: 10,
          category: 0,
        );
      }
      final r = await routines.load(id);
      expect(r!.blocks, hasLength(20));
      expect(r.fitsDevice, isFalse);
      expect(r.overflowCount, 4);
      expect(r.pushable, hasLength(FfFirmware.maxDeviceBlocks));
      expect(r.pushable.last.name, 'Block 15');
      expect(
        r.windowFrom(10).map((b) => b.name).toList(),
        <String>['Block 10', for (var i = 11; i < 20; i++) 'Block $i'],
        reason: 'near the end, the window is what is left',
      );
    });
  });

  group('sessions', () {
    final t0 = DateTime(2026, 8, 2, 9);

    ActiveBlock block({bool track = true}) => ActiveBlock(
      id: 'b1',
      name: 'Deep Work 1',
      category: 0,
      duration: const Duration(minutes: 90),
      trackEnabled: track,
    );

    test('records a session and rebuilds its day', () async {
      final id = await sessions.begin(block: block(), startedAt: t0);
      await sessions.finish(
        id,
        endedAt: t0.add(const Duration(minutes: 90)),
        verified: const Duration(minutes: 82),
        claimed: const Duration(minutes: 90),
        state: SessionState.complete,
        violations: 2,
        factorMask:
            VerificationFactor.presence.bit |
            VerificationFactor.dock.bit |
            VerificationFactor.screenLock.bit,
        trackEnabled: true,
      );

      final days = await sessions.allDays();
      expect(days, hasLength(1));
      expect(days.single.verifiedMin, 82);
      expect(days.single.claimedMin, 90);
      expect(days.single.blocksDone, 1);
      expect(days.single.violations, 2);
    });

    test(
      'day rollups are derived, so a deleted session cannot orphan them',
      () async {
        final a = await sessions.begin(block: block(), startedAt: t0);
        await sessions.finish(
          a,
          endedAt: t0.add(const Duration(minutes: 60)),
          verified: const Duration(minutes: 60),
          claimed: const Duration(minutes: 60),
          state: SessionState.complete,
          violations: 0,
          factorMask: VerificationFactor.presence.bit,
          trackEnabled: true,
        );

        await (db.delete(db.sessions)..where((t) => t.id.equals(a))).go();
        await sessions.rebuildDay(FfDates.logicalDay(t0));

        final days = await sessions.allDays();
        expect(days.single.verifiedMin, 0);
        expect(days.single.blocksTotal, 0);
      },
    );

    test(
      'the 04:00 rollover keeps a late-night session on the previous day',
      () async {
        final lateNight = DateTime(2026, 8, 3, 1, 30);
        final id = await sessions.begin(block: block(), startedAt: lateNight);
        await sessions.finish(
          id,
          endedAt: lateNight.add(const Duration(minutes: 45)),
          verified: const Duration(minutes: 45),
          claimed: const Duration(minutes: 45),
          state: SessionState.complete,
          violations: 0,
          factorMask: VerificationFactor.screenLock.bit,
          trackEnabled: true,
        );

        final days = await sessions.allDays();
        expect(
          days.single.day,
          DateTime(2026, 8, 2),
          reason: 'a Night Owl studying at 01:30 is still having yesterday',
        );
      },
    );

    group('provenance', () {
      test('presence in the mask means the bot vouched for it', () {
        expect(
          SessionRepository.provenanceFor(
            trackEnabled: true,
            factorMask:
                VerificationFactor.presence.bit | VerificationFactor.dock.bit,
          ),
          Provenance.sensorVerified,
        );
      });

      test('screen-lock alone is app-verified, never sensor-verified', () {
        expect(
          SessionRepository.provenanceFor(
            trackEnabled: true,
            factorMask: VerificationFactor.screenLock.bit,
          ),
          Provenance.appVerified,
        );
      });

      test('tracking off is untracked regardless of what was available', () {
        expect(
          SessionRepository.provenanceFor(
            trackEnabled: false,
            factorMask: VerificationFactor.presence.bit,
          ),
          Provenance.untracked,
        );
      });

      test('no factors at all is untracked, not verified', () {
        expect(
          SessionRepository.provenanceFor(trackEnabled: true, factorMask: 0),
          Provenance.untracked,
        );
      });
    });

    test('device logs fill gaps but never overwrite richer app data', () async {
      final id = await sessions.begin(block: block(), startedAt: t0);
      await sessions.finish(
        id,
        endedAt: t0.add(const Duration(minutes: 90)),
        verified: const Duration(minutes: 82),
        claimed: const Duration(minutes: 90),
        state: SessionState.complete,
        violations: 2,
        factorMask: VerificationFactor.presence.bit,
        trackEnabled: true,
      );

      // The device reports a smaller figure for the same day.
      await sessions.mergeDeviceLog(
        day: t0,
        verifiedMin: 40,
        claimedMin: 50,
        blocksDone: 1,
        blocksTotal: 1,
        violations: 0,
      );

      final same = (await sessions.allDays()).single;
      expect(same.verifiedMin, 82, reason: 'the phone saw the whole session');
      expect(same.source, 2, reason: 'flagged as merged');

      // A day the app knows nothing about is taken as-is.
      await sessions.mergeDeviceLog(
        day: t0.subtract(const Duration(days: 3)),
        verifiedMin: 120,
        claimedMin: 150,
        blocksDone: 2,
        blocksTotal: 3,
        violations: 1,
      );
      final all = await sessions.allDays();
      expect(all, hasLength(2));
      expect(all.first.verifiedMin, 120);
      expect(all.first.source, 1);
    });

    test('violations are queryable with their reasons', () async {
      final id = await sessions.begin(block: block(), startedAt: t0);
      await sessions.logEvent(
        id,
        SessionViolation(
          t0.add(const Duration(minutes: 5)),
          ViolationReason.absent,
          <VerificationFactor>{VerificationFactor.presence},
        ),
      );
      await sessions.logEvent(
        id,
        SessionTransition(
          t0.add(const Duration(minutes: 6)),
          SessionState.running,
          SessionState.paused,
          reason: ViolationReason.absent,
        ),
      );

      final v = await sessions.violations(t0, t0);
      expect(v, hasLength(1), reason: 'transitions are not violations');
      expect(v.single.reason, ViolationReason.absent.index);
      expect(v.single.factorMask, VerificationFactor.presence.bit);

      expect(await sessions.eventsOf(id), hasLength(2));
    });
  });

  group('tasks', () {
    test(
      'completing a recurring task rolls it forward instead of closing it',
      () async {
        final due = DateTime(2026, 8, 2, 9);
        final id = await tasks.create(
          title: 'Revise formulas',
          dueAt: due,
          recurrence: 'daily',
        );
        await tasks.addSubtask(id, 'Chapter 1');

        await tasks.setDone(id, true);

        final t = await tasks.load(id);
        expect(
          t!.task.completedAt,
          isNull,
          reason: 'a daily habit is never finished',
        );
        expect(t.task.dueAt, DateTime(2026, 8, 3, 9));
        expect(
          t.subtasks.single.done,
          isFalse,
          reason: 'the checklist resets for the next occurrence',
        );
      },
    );

    test('weekday recurrence skips the weekend', () async {
      // 2026-08-07 is a Friday.
      final friday = DateTime(2026, 8, 7, 9);
      final id = await tasks.create(
        title: 'Standup',
        dueAt: friday,
        recurrence: 'weekdays',
      );
      await tasks.setDone(id, true);

      final t = await tasks.load(id);
      expect(t!.task.dueAt!.weekday, DateTime.monday);
    });

    test('monthly recurrence clamps to the end of a short month', () async {
      final jan31 = DateTime(2026, 1, 31, 9);
      final id = await tasks.create(
        title: 'Monthly review',
        dueAt: jan31,
        recurrence: 'monthly',
      );
      await tasks.setDone(id, true);

      final t = await tasks.load(id);
      expect(t!.task.dueAt!.month, 2);
      expect(t.task.dueAt!.day, 28, reason: 'must not roll into March');
    });

    test('a one-off task completes normally', () async {
      final id = await tasks.create(title: 'Buy resistors');
      await tasks.setDone(id, true);
      expect((await tasks.load(id))!.task.completedAt, isNotNull);
    });

    test('deleting a task takes its subtasks with it', () async {
      final id = await tasks.create(title: 'Parent');
      await tasks.addSubtask(id, 'Child');
      await tasks.delete(id);
      expect(
        await db.select(db.subtasks).get(),
        isEmpty,
        reason: 'foreign keys must be enabled for the cascade to fire',
      );
    });

    test('undated tasks sort after dated ones', () async {
      await tasks.create(title: 'No date');
      await tasks.create(title: 'Due today', dueAt: DateTime.now());
      final list = await tasks.watch(TaskFilter.all).first;
      expect(list.first.title, 'Due today');
    });
  });

  group('settings', () {
    test('unset keys return their declared default', () async {
      expect(await settings.getString(SettingKey.themeMode), 'dark');
      expect(await settings.getInt(SettingKey.dailyGoalMinutes), 240);
      expect(await settings.getBool(SettingKey.onboardingDone), isFalse);
    });

    test('round-trips values', () async {
      await settings.setInt(SettingKey.dailyGoalMinutes, 300);
      await settings.setBool(SettingKey.onboardingDone, true);
      expect(await settings.getInt(SettingKey.dailyGoalMinutes), 300);
      expect(await settings.getBool(SettingKey.onboardingDone), isTrue);
    });

    test('import keeps keys it does not recognise', () async {
      await settings.importAll(<String, String>{
        'theme_mode': 'amoled',
        'a_key_from_a_newer_version': '42',
      });
      expect(await settings.getString(SettingKey.themeMode), 'amoled');
      final all = await settings.exportAll();
      expect(
        all['a_key_from_a_newer_version'],
        '42',
        reason: 'a backup from a newer build must survive a round trip',
      );
    });

    test('setting keys are unique', () {
      final keys = SettingKey.values.map((k) => k.key).toList();
      expect(keys.toSet().length, keys.length);
    });
  });
}
