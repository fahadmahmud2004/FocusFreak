import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusfreak_app/data/db/database.dart';
import 'package:focusfreak_app/data/repo/achievement_repository.dart';
import 'package:focusfreak_app/domain/engine/achievement_engine.dart';
import 'package:focusfreak_app/domain/engine/streak_engine.dart';
import 'package:focusfreak_app/domain/model/session_state.dart';

/// The claim this file defends: a milestone is *counted*, never awarded — and
/// once reached, never taken back.
void main() {
  const engine = AchievementEngine();

  BlockFacts block({
    DateTime? at,
    int verifiedSec = 3600,
    SessionState state = SessionState.complete,
    Provenance provenance = Provenance.appVerified,
    int category = 0,
  }) => BlockFacts(
    startedAt: at ?? DateTime(2026, 8, 3, 9),
    verifiedSec: verifiedSec,
    finalState: state,
    provenance: provenance,
    trackEnabled: true,
    category: category,
  );

  DaySummary day(int n, {int verified = 60}) => DaySummary(
    day: DateTime(2026, 8, n),
    verifiedMin: verified,
    claimedMin: verified,
    blocksDone: 1,
    blocksTotal: 1,
  );

  List<AchievementStatus> run({
    List<DaySummary> days = const <DaySummary>[],
    List<BlockFacts> blocks = const <BlockFacts>[],
    StreakResult streak = StreakResult.empty,
    int tasksCompleted = 0,
  }) => engine.evaluate(
    days: days,
    blocks: blocks,
    streak: streak,
    tasksCompleted: tasksCompleted,
  );

  AchievementStatus find(List<AchievementStatus> all, String key) =>
      all.firstWhere(
        (s) => s.achievement.key == key,
        orElse: () => throw StateError('no milestone "$key"'),
      );

  group('counting', () {
    test('an empty record unlocks nothing and shames nobody', () {
      final all = run();
      expect(all.every((a) => !a.unlocked), isTrue);
      expect(all.every((a) => a.fraction == 0), isTrue);
      for (final a in all) {
        // The copy rule applies here too: a locked milestone is something
        // ahead of you, not something you failed.
        final words = '${a.achievement.title} ${a.achievement.detail}'
            .toLowerCase();
        for (final banned in <String>['fail', 'only', 'lazy', 'should']) {
          expect(words, isNot(contains(banned)));
        }
      }
    });

    test('one finished block is the first milestone', () {
      final all = run(blocks: <BlockFacts>[block()]);
      expect(find(all, 'blocks_1').unlocked, isTrue);
      expect(find(all, 'blocks_10').unlocked, isFalse);
      expect(find(all, 'blocks_10').progress, 1);
    });

    test('a block that broke is not a finished block', () {
      final all = run(blocks: <BlockFacts>[block(state: SessionState.broken)]);
      expect(find(all, 'blocks_1').unlocked, isFalse);
    });

    test('hours come from verified minutes, not claimed ones', () {
      // The whole product claim. A milestone counted from claimed time would
      // be a participation trophy.
      final all = run(
        days: <DaySummary>[for (var i = 1; i <= 10; i++) day(i, verified: 60)],
      );
      expect(find(all, 'hours_600').unlocked, isTrue);
      expect(find(all, 'hours_6000').progress, 600);
      expect(find(all, 'hours_6000').label, '10 of 100 hours');
    });

    test('the best day is a single day, not a total', () {
      final all = run(
        days: <DaySummary>[day(1, verified: 200), day(2, verified: 200)],
      );
      expect(
        find(all, 'bestday_240').unlocked,
        isFalse,
        reason: 'two good days are not one four-hour day',
      );
      expect(find(all, 'bestday_240').progress, 200);
    });

    test('streak milestones use the best streak, so a gap cannot undo one', () {
      final all = run(
        streak: const StreakResult(
          current: 1,
          best: 9,
          lastQualifyingDay: null,
          freezesUsed: 0,
        ),
      );
      expect(find(all, 'streak_7').unlocked, isTrue);
      expect(find(all, 'streak_30').progress, 9);
    });

    test('early and late are about when the block started', () {
      final all = run(
        blocks: <BlockFacts>[
          block(at: DateTime(2026, 8, 3, 5, 30)),
          block(at: DateTime(2026, 8, 3, 23, 10)),
        ],
      );
      expect(find(all, 'early_1').unlocked, isTrue);
      expect(find(all, 'late_1').unlocked, isTrue);
    });

    test('only the bot can unlock the bot milestone', () {
      final phoneOnly = run(blocks: <BlockFacts>[block()]);
      expect(
        find(phoneOnly, 'sensor_1').unlocked,
        isFalse,
        reason: 'a phone-only block cannot claim the bot vouched for it',
      );

      final withBot = run(
        blocks: <BlockFacts>[block(provenance: Provenance.sensorVerified)],
      );
      expect(find(withBot, 'sensor_1').unlocked, isTrue);
    });

    test('category hours are counted per category', () {
      final all = run(
        blocks: <BlockFacts>[
          block(category: 0, verifiedSec: 3600),
          block(category: 0, verifiedSec: 3600),
          block(category: 2, verifiedSec: 3600),
        ],
      );
      expect(find(all, 'cat0_60').unlocked, isTrue);
      expect(find(all, 'cat0_300').progress, 120);
      expect(find(all, 'cat2_60').unlocked, isTrue);
      expect(
        find(all, 'cat5_60').unlocked,
        isFalse,
        reason: 'nothing was recorded against Sleep',
      );
    });

    test('tasks are their own family', () {
      final all = run(tasksCompleted: 30);
      expect(find(all, 'tasks_25').unlocked, isTrue);
      expect(find(all, 'tasks_50').unlocked, isFalse);
    });

    test('recorded days are not the same as a streak', () {
      // Three days with gaps between them is three days on the record and a
      // streak of one. The two families must not read each other's number.
      final all = run(days: <DaySummary>[day(1), day(5), day(20)]);
      expect(find(all, 'days_1').unlocked, isTrue);
      expect(find(all, 'days_7').progress, 3);
      expect(find(all, 'streak_2').unlocked, isFalse);
    });
  });

  group('the catalogue', () {
    test('there are a hundred, and every key is distinct', () {
      expect(AchievementCatalogue.total, 100);
      final keys = Achievement.values.map((a) => a.key).toSet();
      expect(keys, hasLength(100));
    });

    test('every tier list rises', () {
      // A family whose tiers were out of order would show "next" as one the
      // user had already passed.
      for (final family in AchievementCatalogue.families) {
        for (var i = 1; i < family.tiers.length; i++) {
          expect(
            family.tiers[i],
            greaterThan(family.tiers[i - 1]),
            reason: family.id,
          );
        }
      }
    });

    test('every milestone has a title, a detail and a family', () {
      for (final a in Achievement.values) {
        expect(a.title, isNotEmpty, reason: a.key);
        expect(a.detail, isNotEmpty, reason: a.key);
        expect(a.familyLabel, isNotEmpty, reason: a.key);
        expect(a.target, greaterThan(0), reason: a.key);
      }
    });

    test('no title reads as a reprimand or a boast', () {
      for (final a in Achievement.values) {
        final words = '${a.title} ${a.detail}'.toLowerCase();
        for (final banned in <String>[
          'fail',
          'only',
          'lazy',
          'should',
          'must',
          'wasted',
          'crushed',
          'amazing',
          'great job',
        ]) {
          expect(words, isNot(contains(banned)), reason: a.key);
        }
        expect(a.title, isNot(contains('!')), reason: a.key);
      }
    });
  });

  group('remembering', () {
    late AppDatabase db;
    late AchievementRepository repo;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = AchievementRepository(db);
    });
    tearDown(() => db.close());

    test('stamps the date the first time, and only the first time', () async {
      final first = DateTime(2026, 8, 3, 10);
      var fresh = await repo.record(<String, ({int progress, bool unlocked})>{
        'first_block': (progress: 1, unlocked: true),
      }, now: first);
      expect(fresh, <String>['first_block']);
      expect((await repo.unlockedDates())['first_block'], first);

      fresh = await repo.record(<String, ({int progress, bool unlocked})>{
        'first_block': (progress: 9, unlocked: true),
      }, now: DateTime(2026, 9, 1));
      expect(fresh, isEmpty, reason: 'it is not reached twice');
      expect(
        (await repo.unlockedDates())['first_block'],
        first,
        reason: 'the date it happened does not move',
      );
    });

    test('a later recount cannot take a milestone back', () async {
      // Deleting a session or correcting a day must not revoke something the
      // user was already told they had reached.
      final at = DateTime(2026, 8, 3);
      await repo.record(<String, ({int progress, bool unlocked})>{
        'ten_blocks': (progress: 10, unlocked: true),
      }, now: at);
      await repo.record(<String, ({int progress, bool unlocked})>{
        'ten_blocks': (progress: 2, unlocked: false),
      });

      expect((await repo.unlockedDates())['ten_blocks'], at);
    });

    test('progress is kept for milestones not yet reached', () async {
      await repo.record(<String, ({int progress, bool unlocked})>{
        'hundred_blocks': (progress: 42, unlocked: false),
      });
      expect((await repo.unlockedDates()), isEmpty);
      final rows = await db.select(db.achievements).get();
      expect(rows.single.progress, 42);
    });
  });
}
