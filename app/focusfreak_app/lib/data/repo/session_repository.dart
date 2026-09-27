import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/ff_format.dart';
import '../../domain/engine/session_engine.dart';
import '../../domain/engine/streak_engine.dart';
import '../../domain/model/session_state.dart';
import '../../domain/model/verification.dart';
import '../db/database.dart';

/// Persists sessions, their events, and the day rollups built from them.
class SessionRepository {
  SessionRepository(this._db, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final AppDatabase _db;
  final Uuid _uuid;

  // --- writing a session -----------------------------------------------------

  /// Open a row as soon as a block is armed, so a crash mid-session still
  /// leaves evidence that it happened.
  Future<String> begin({
    required ActiveBlock block,
    required DateTime startedAt,
  }) async {
    final id = _uuid.v4();
    await _db
        .into(_db.sessions)
        .insert(
          SessionsCompanion.insert(
            id: id,
            startedAt: startedAt,
            logicalDay: FfDates.logicalDay(startedAt),
            routineId: Value(block.routineId),
            blockId: Value(block.id),
            taskId: Value(block.taskId),
            blockName: block.name,
            category: block.category,
            plannedSec: block.planned.inSeconds,
            finalState: SessionState.armed.index,
            provenance: Provenance.untracked.index,
            trackEnabled: Value(block.trackEnabled),
          ),
        );
    return id;
  }

  /// Update the running totals. Called on a slow cadence — every second would
  /// be a write per second for 90 minutes and would chew through flash for no
  /// benefit, since the engine holds the authoritative values in memory.
  Future<void> progress(
    String sessionId, {
    required Duration verified,
    required Duration claimed,
    required SessionState state,
    required int violations,
    required int factorMask,
  }) => (_db.update(_db.sessions)..where((t) => t.id.equals(sessionId))).write(
    SessionsCompanion(
      verifiedSec: Value(verified.inSeconds),
      claimedSec: Value(claimed.inSeconds),
      finalState: Value(state.index),
      violations: Value(violations),
      factorMask: Value(factorMask),
    ),
  );

  /// Close the session and refresh its day's rollup.
  Future<void> finish(
    String sessionId, {
    required DateTime endedAt,
    required Duration verified,
    required Duration claimed,
    required SessionState state,
    required int violations,
    required int factorMask,
    required bool trackEnabled,
  }) async {
    await _db.transaction(() async {
      await (_db.update(
        _db.sessions,
      )..where((t) => t.id.equals(sessionId))).write(
        SessionsCompanion(
          endedAt: Value(endedAt),
          verifiedSec: Value(verified.inSeconds),
          claimedSec: Value(claimed.inSeconds),
          finalState: Value(state.index),
          violations: Value(violations),
          factorMask: Value(factorMask),
          provenance: Value(
            provenanceFor(
              trackEnabled: trackEnabled,
              factorMask: factorMask,
            ).index,
          ),
        ),
      );
      await rebuildDay(FfDates.logicalDay(endedAt));
    });
  }

  Future<void> logEvent(String sessionId, SessionEvent event) async {
    final (
      int kind,
      int? from,
      int? to,
      int? reason,
      int mask,
    ) = switch (event) {
      SessionTransition e => (0, e.from.index, e.to.index, e.reason?.index, 0),
      SessionViolation e => (
        1,
        null,
        null,
        e.reason.index,
        e.factors.fold(0, (m, f) => m | f.bit),
      ),
      _ => (2, null, null, null, 0),
    };

    await _db
        .into(_db.sessionEvents)
        .insert(
          SessionEventsCompanion.insert(
            id: _uuid.v4(),
            sessionId: sessionId,
            at: event.at,
            kind: kind,
            fromState: Value(from),
            toState: Value(to),
            reason: Value(reason),
            factorMask: Value(mask),
          ),
        );
  }

  /// What a session's numbers are worth.
  ///
  /// Presence is the discriminator: it is the one factor a phone physically
  /// cannot supply, so its presence in the mask is exactly what separates
  /// "the bot vouched for this" from "my phone's screen was off".
  static Provenance provenanceFor({
    required bool trackEnabled,
    required int factorMask,
  }) {
    if (!trackEnabled) return Provenance.untracked;
    if (factorMask & VerificationFactor.presence.bit != 0) {
      return Provenance.sensorVerified;
    }
    if (factorMask == 0) return Provenance.untracked;
    return Provenance.appVerified;
  }

  // --- reading ---------------------------------------------------------------

  Stream<List<Session>> watchDay(DateTime day) {
    final logical = FfDates.startOfDay(day);
    return (_db.select(_db.sessions)
          ..where((t) => t.logicalDay.equals(logical))
          ..orderBy(<OrderClauseGenerator<$SessionsTable>>[
            (t) => OrderingTerm(expression: t.startedAt),
          ]))
        .watch();
  }

  /// Every block ever recorded, oldest first. For the backup file and the
  /// milestone counts, both of which are about the whole record rather than a
  /// window of it.
  Future<List<Session>> allSessions() =>
      (_db.select(_db.sessions)..orderBy(<OrderClauseGenerator<$SessionsTable>>[
            (t) => OrderingTerm(expression: t.startedAt),
          ]))
          .get();

  Future<List<Session>> range(DateTime from, DateTime to) =>
      (_db.select(_db.sessions)
            ..where(
              (t) => t.logicalDay.isBetweenValues(
                FfDates.startOfDay(from),
                FfDates.startOfDay(to),
              ),
            )
            ..orderBy(<OrderClauseGenerator<$SessionsTable>>[
              (t) => OrderingTerm(expression: t.startedAt),
            ]))
          .get();

  Future<List<SessionEventRow>> eventsOf(String sessionId) async {
    final rows =
        await (_db.select(_db.sessionEvents)
              ..where((t) => t.sessionId.equals(sessionId))
              ..orderBy(<OrderClauseGenerator<$SessionEventsTable>>[
                (t) => OrderingTerm(expression: t.at),
              ]))
            .get();
    return rows;
  }

  /// Every violation in a range, newest first — the violation log.
  Future<List<SessionEventRow>> violations(DateTime from, DateTime to) =>
      (_db.select(_db.sessionEvents)
            ..where(
              (t) =>
                  t.kind.equals(1) &
                  t.at.isBiggerOrEqualValue(FfDates.startOfDay(from)) &
                  t.at.isSmallerThanValue(
                    FfDates.startOfDay(to).add(const Duration(days: 1)),
                  ),
            )
            ..orderBy(<OrderClauseGenerator<$SessionEventsTable>>[
              (t) => OrderingTerm(expression: t.at, mode: OrderingMode.desc),
            ]))
          .get();

  // --- day rollups -----------------------------------------------------------

  /// Recompute one day from its sessions.
  ///
  /// Derived rather than incremented, so an edited or deleted session can never
  /// leave the day totals disagreeing with the sessions they claim to summarise.
  Future<void> rebuildDay(DateTime day) async {
    final logical = FfDates.startOfDay(day);
    final rows = await (_db.select(
      _db.sessions,
    )..where((t) => t.logicalDay.equals(logical))).get();

    var verified = 0;
    var claimed = 0;
    var done = 0;
    var violations = 0;

    for (final s in rows) {
      verified += s.verifiedSec;
      claimed += s.claimedSec;
      violations += s.violations;
      if (s.finalState == SessionState.complete.index) done++;
    }

    final existing = await (_db.select(
      _db.dayLogs,
    )..where((t) => t.day.equals(logical))).getSingleOrNull();

    // A day the device also reported becomes "merged" rather than overwriting
    // either side's figure.
    final source = existing == null || existing.source == 0 ? 0 : 2;

    await _db
        .into(_db.dayLogs)
        .insertOnConflictUpdate(
          DayLogsCompanion.insert(
            day: logical,
            verifiedMin: Value(verified ~/ 60),
            claimedMin: Value(claimed ~/ 60),
            blocksDone: Value(done),
            blocksTotal: Value(rows.length),
            violations: Value(violations),
            source: Value(source),
          ),
        );
  }

  Stream<List<DayLog>> watchDays(DateTime from, DateTime to) =>
      (_db.select(_db.dayLogs)
            ..where(
              (t) => t.day.isBetweenValues(
                FfDates.startOfDay(from),
                FfDates.startOfDay(to),
              ),
            )
            ..orderBy(<OrderClauseGenerator<$DayLogsTable>>[
              (t) => OrderingTerm(expression: t.day),
            ]))
          .watch();

  Future<List<DayLog>> allDays() =>
      (_db.select(_db.dayLogs)..orderBy(<OrderClauseGenerator<$DayLogsTable>>[
            (t) => OrderingTerm(expression: t.day),
          ]))
          .get();

  Stream<DayLog?> watchToday() {
    final today = FfDates.logicalDay(DateTime.now());
    return (_db.select(
      _db.dayLogs,
    )..where((t) => t.day.equals(today))).watchSingleOrNull();
  }

  /// Merge a `0xC0 LOG_ENTRY` pulled from the device.
  ///
  /// The app's own figures win where they exist — the phone saw the whole
  /// session, the device only saw its own 30-day ring buffer. The device fills
  /// gaps, it does not overwrite.
  Future<void> mergeDeviceLog({
    required DateTime day,
    required int verifiedMin,
    required int claimedMin,
    required int blocksDone,
    required int blocksTotal,
    required int violations,
  }) async {
    final logical = FfDates.startOfDay(day);
    final existing = await (_db.select(
      _db.dayLogs,
    )..where((t) => t.day.equals(logical))).getSingleOrNull();

    if (existing == null) {
      await _db
          .into(_db.dayLogs)
          .insert(
            DayLogsCompanion.insert(
              day: logical,
              verifiedMin: Value(verifiedMin),
              claimedMin: Value(claimedMin),
              blocksDone: Value(blocksDone),
              blocksTotal: Value(blocksTotal),
              violations: Value(violations),
              source: const Value(1),
            ),
          );
      return;
    }

    await (_db.update(_db.dayLogs)..where((t) => t.day.equals(logical))).write(
      DayLogsCompanion(
        verifiedMin: Value(
          existing.verifiedMin > verifiedMin
              ? existing.verifiedMin
              : verifiedMin,
        ),
        claimedMin: Value(
          existing.claimedMin > claimedMin ? existing.claimedMin : claimedMin,
        ),
        blocksDone: Value(
          existing.blocksDone > blocksDone ? existing.blocksDone : blocksDone,
        ),
        blocksTotal: Value(
          existing.blocksTotal > blocksTotal
              ? existing.blocksTotal
              : blocksTotal,
        ),
        violations: Value(
          existing.violations > violations ? existing.violations : violations,
        ),
        source: const Value(2),
      ),
    );
  }

  /// Day summaries for the streak engine.
  Future<List<DaySummary>> daySummaries() async {
    final rows = await allDays();
    return <DaySummary>[
      for (final d in rows)
        DaySummary(
          day: d.day,
          verifiedMin: d.verifiedMin,
          claimedMin: d.claimedMin,
          blocksDone: d.blocksDone,
          blocksTotal: d.blocksTotal,
          violations: d.violations,
        ),
    ];
  }
}
