import 'package:drift/drift.dart';

/// The on-disk schema.
///
/// This database is the user's only copy of their history — there is no cloud
/// and no account to restore from. Every change needs a migration step, and
/// `AppDatabase.migration` is not allowed to drop a table that has ever
/// shipped.

/// A named, ordered set of blocks. Built-in templates live here too, flagged
/// read-only rather than kept in a separate list, so "duplicate to edit"
/// is a plain row copy.
class Routines extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 60)();
  TextColumn get description => text().withDefault(const Constant(''))();

  /// True for the shipped templates. The editor refuses to mutate these.
  BoolColumn get isBuiltIn => boolean().withDefault(const Constant(false))();

  /// Stable key for a built-in (`standard`, `earlyBird`, `nightOwl`, …), so a
  /// template can be re-seeded or upgraded without duplicating the user's copy.
  TextColumn get templateKey => text().nullable()();

  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => <Column>{id};
}

/// One block of a routine. Field widths mirror the firmware struct
/// (`docs/PROTOCOL.md` §5) so any block is pushable without transformation.
class Blocks extends Table {
  TextColumn get id => text()();
  TextColumn get routineId =>
      text().references(Routines, #id, onDelete: KeyAction.cascade)();

  IntColumn get position => integer()();

  /// `char name[16]` on the wire.
  TextColumn get name => text().withLength(min: 1, max: 16)();

  /// `char desc[24]` on the wire.
  TextColumn get description =>
      text().withLength(max: 24).withDefault(const Constant(''))();

  IntColumn get durationMin => integer()();

  /// 0..5 — the index is the wire value and the colour index.
  IntColumn get category => integer()();

  /// Per-block opt-in. Always-on tracking makes the device a tyrant; opt-in
  /// makes it a tool.
  BoolColumn get trackEnabled => boolean().withDefault(const Constant(false))();

  /// Minutes since midnight, or 0xFFFF for "run after the previous block".
  IntColumn get startMin => integer().withDefault(const Constant(0xFFFF))();

  @override
  Set<Column> get primaryKey => <Column>{id};
}

class Tasks extends Table {
  TextColumn get id => text()();
  TextColumn get title => text().withLength(min: 1, max: 200)();
  TextColumn get notes => text().withDefault(const Constant(''))();

  /// 0 none · 1 low · 2 medium · 3 high
  IntColumn get priority => integer().withDefault(const Constant(0))();

  IntColumn get category => integer().nullable()();
  DateTimeColumn get dueAt => dateTime().nullable()();
  DateTimeColumn get completedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  IntColumn get estimatedPomodoros =>
      integer().withDefault(const Constant(0))();
  IntColumn get completedPomodoros =>
      integer().withDefault(const Constant(0))();

  /// iCal-ish recurrence string, or null for a one-off.
  TextColumn get recurrence => text().nullable()();

  /// Optional link to the block this task is meant to be done in.
  TextColumn get blockId => text().nullable()();

  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => <Column>{id};
}

class Subtasks extends Table {
  TextColumn get id => text()();
  TextColumn get taskId =>
      text().references(Tasks, #id, onDelete: KeyAction.cascade)();
  TextColumn get title => text().withLength(min: 1, max: 200)();
  BoolColumn get done => boolean().withDefault(const Constant(false))();
  IntColumn get position => integer()();

  @override
  Set<Column> get primaryKey => <Column>{id};
}

class Tags extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 40)();
  IntColumn get colorIndex => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => <Column>{id};
}

class TaskTags extends Table {
  TextColumn get taskId =>
      text().references(Tasks, #id, onDelete: KeyAction.cascade)();
  TextColumn get tagId =>
      text().references(Tags, #id, onDelete: KeyAction.cascade)();

  @override
  Set<Column> get primaryKey => <Column>{taskId, tagId};
}

/// One run of one block. The unit everything in Stats is built from.
class Sessions extends Table {
  TextColumn get id => text()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get endedAt => dateTime().nullable()();

  /// The logical day (04:00 rollover applied), stored so day queries are a
  /// plain index lookup rather than arithmetic over every row.
  DateTimeColumn get logicalDay => dateTime()();

  TextColumn get routineId => text().nullable()();
  TextColumn get blockId => text().nullable()();
  TextColumn get taskId => text().nullable()();

  /// Denormalised on purpose: a session must still read correctly after its
  /// block has been edited or its routine deleted. History is not allowed to
  /// change retroactively.
  TextColumn get blockName => text()();
  IntColumn get category => integer()();

  IntColumn get plannedSec => integer()();
  IntColumn get claimedSec => integer().withDefault(const Constant(0))();
  IntColumn get verifiedSec => integer().withDefault(const Constant(0))();

  /// Terminal [SessionState] index.
  IntColumn get finalState => integer()();

  /// [Provenance] index — untracked / app-verified / sensor-verified.
  IntColumn get provenance => integer()();

  /// Bitmask of [VerificationFactor]s that had a source. Without it, a report
  /// would compare a 3-factor day against a 1-factor day and say nothing.
  IntColumn get factorMask => integer().withDefault(const Constant(0))();

  BoolColumn get trackEnabled => boolean().withDefault(const Constant(false))();
  IntColumn get violations => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => <Column>{id};
}

/// Everything that happened inside a session, with reasons. This is what makes
/// the violation log honest rather than a bare count.
///
/// The row class is named explicitly: Drift would otherwise generate
/// `SessionEvent`, which collides with the engine's in-memory event type.
@DataClassName('SessionEventRow')
class SessionEvents extends Table {
  TextColumn get id => text()();
  TextColumn get sessionId =>
      text().references(Sessions, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get at => dateTime()();

  /// 0 transition · 1 violation · 2 note
  IntColumn get kind => integer()();

  IntColumn get fromState => integer().nullable()();
  IntColumn get toState => integer().nullable()();

  /// [ViolationReason] index.
  IntColumn get reason => integer().nullable()();

  /// Bitmask of the factors that were violating.
  IntColumn get factorMask => integer().withDefault(const Constant(0))();

  TextColumn get detail => text().withDefault(const Constant(''))();

  @override
  Set<Column> get primaryKey => <Column>{id};
}

/// A day's rollup. Mirrors the firmware `DayLog` (`docs/PROTOCOL.md` §7) so
/// device logs and app-computed days merge into one table by `day`.
class DayLogs extends Table {
  DateTimeColumn get day => dateTime()();
  IntColumn get verifiedMin => integer().withDefault(const Constant(0))();
  IntColumn get claimedMin => integer().withDefault(const Constant(0))();
  IntColumn get blocksDone => integer().withDefault(const Constant(0))();
  IntColumn get blocksTotal => integer().withDefault(const Constant(0))();
  IntColumn get violations => integer().withDefault(const Constant(0))();

  /// 0 app · 1 device · 2 merged. Kept so a device pull never silently
  /// overwrites richer app-side data.
  IntColumn get source => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => <Column>{day};
}

/// A bot this phone has talked to, and what it declared it has.
class DeviceProfiles extends Table {
  TextColumn get address => text()();
  TextColumn get name => text()();
  IntColumn get protoVersion => integer().withDefault(const Constant(0))();
  IntColumn get fwMajor => integer().withDefault(const Constant(0))();
  IntColumn get fwMinor => integer().withDefault(const Constant(0))();
  IntColumn get deviceId => integer().withDefault(const Constant(0))();
  IntColumn get capsLo => integer().withDefault(const Constant(0))();
  IntColumn get capsHi => integer().withDefault(const Constant(0))();
  IntColumn get eepromLogDays => integer().withDefault(const Constant(30))();
  IntColumn get maxBlocks => integer().withDefault(const Constant(16))();
  DateTimeColumn get lastSeenAt => dateTime().nullable()();
  BoolColumn get autoConnect => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => <Column>{address};
}

/// Key/value settings. A table rather than SharedPreferences so settings land
/// in the same backup file as everything else.
class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => <Column>{key};
}

/// Named explicitly for the same reason as [SessionEvents]: Drift would
/// generate `Achievement`, which collides with the domain enum of that name in
/// `domain/engine/achievement_engine.dart`.
@DataClassName('AchievementRow')
class Achievements extends Table {
  TextColumn get key => text()();
  IntColumn get progress => integer().withDefault(const Constant(0))();
  DateTimeColumn get unlockedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => <Column>{key};
}
