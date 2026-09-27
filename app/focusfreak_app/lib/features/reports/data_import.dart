/// Reading a backup back in.
///
/// The other half of [DataExport], and the reason that file exists: data that
/// lives in one SQLite file on one phone needs a way out *and* a way back.
///
/// **A restore merges; it never deletes.** Rows are matched by their own id —
/// session id, routine id, day, setting key — and written over. Anything on
/// this phone that is not in the file is left alone. The alternative, wiping
/// first, means one mis-tapped file destroys a history that has no other copy.
///
/// Every section is independent. A backup with one unreadable session still
/// restores the routines, and says what it skipped.
library;

import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../data/db/database.dart';

/// What a restore did, in countable terms the screen can show.
class ImportSummary {
  ImportSummary();

  int routines = 0;
  int blocks = 0;
  int tasks = 0;
  int days = 0;
  int sessions = 0;
  int settings = 0;

  /// Sections or rows that could not be read. Never fatal on its own.
  final List<String> skipped = <String>[];

  int get total => routines + blocks + tasks + days + sessions + settings;
  bool get isEmpty => total == 0;

  /// One line, in the user's terms rather than a table of counts.
  String get summary {
    if (isEmpty) return 'Nothing in that file could be restored.';
    final parts = <String>[
      if (routines > 0) '$routines ${_plural(routines, 'routine')}',
      if (tasks > 0) '$tasks ${_plural(tasks, 'task')}',
      if (sessions > 0) '$sessions ${_plural(sessions, 'block')}',
      if (days > 0) '$days ${_plural(days, 'day')}',
      if (settings > 0) 'your settings',
    ];
    return 'Restored ${_list(parts)}.';
  }

  static String _plural(int n, String word) => n == 1 ? word : '${word}s';

  static String _list(List<String> parts) => switch (parts.length) {
    0 => 'nothing',
    1 => parts.first,
    _ => '${parts.take(parts.length - 1).join(', ')} and ${parts.last}',
  };
}

/// The file is not a FocusFreak backup at all.
class NotABackupException implements Exception {
  const NotABackupException(this.message);
  final String message;
  @override
  String toString() => message;
}

class DataImport {
  const DataImport(this._db);

  final AppDatabase _db;

  static const _uuid = Uuid();

  /// The format this build writes. A file from a newer version is read as far
  /// as it can be rather than refused — the fields it does not know are simply
  /// not there for it.
  static const int writtenVersion = 1;

  Future<ImportSummary> restore(String source) async {
    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException {
      throw const NotABackupException('That file is not a FocusFreak backup.');
    }

    if (decoded is! Map<String, Object?> ||
        decoded['format'] != 'focusfreak-export') {
      throw const NotABackupException('That file is not a FocusFreak backup.');
    }

    final summary = ImportSummary();
    await _settings(decoded['settings'], summary);
    await _routines(decoded['routines'], summary);
    await _tasks(decoded['tasks'], summary);
    await _days(decoded['days'], summary);
    await _sessions(decoded['sessions'], summary);
    return summary;
  }

  // -- sections ------------------------------------------------------------------

  Future<void> _settings(Object? raw, ImportSummary out) async {
    final map = _asMap(raw);
    if (map == null) return;
    final values = <String, String>{
      for (final e in map.entries)
        if (e.value != null) e.key: '${e.value}',
    };
    if (values.isEmpty) return;
    await _db.batch((b) {
      for (final e in values.entries) {
        b.insert(
          _db.appSettings,
          AppSettingsCompanion.insert(key: e.key, value: e.value),
          onConflict: DoUpdate(
            (_) => AppSettingsCompanion(value: Value(e.value)),
          ),
        );
      }
    });
    out.settings = values.length;
  }

  Future<void> _routines(Object? raw, ImportSummary out) async {
    for (final item in _asList(raw)) {
      final r = _asMap(item);
      final id = _string(r?['id']);
      final name = _string(r?['name']);
      if (r == null || id.isEmpty || name.isEmpty) {
        out.skipped.add('a routine with no name');
        continue;
      }

      final now = DateTime.now();
      await _db
          .into(_db.routines)
          .insertOnConflictUpdate(
            RoutinesCompanion.insert(
              id: id,
              name: _clamp(name, 60),
              description: Value(_string(r['description'])),
              isBuiltIn: Value(_bool(r['is_built_in'])),
              templateKey: Value(_stringOrNull(r['template_key'])),
              sortOrder: Value(_int(r['sort_order'])),
              archived: Value(_bool(r['archived'])),
              createdAt: _date(r['created_at']) ?? now,
              updatedAt: _date(r['updated_at']) ?? now,
            ),
          );
      out.routines++;

      // Blocks are replaced wholesale rather than merged: they have no stable
      // id in the file, and a routine is its list of blocks in order. Merging
      // by position would leave a stale tail behind when the backup is shorter.
      await (_db.delete(_db.blocks)..where((t) => t.routineId.equals(id))).go();

      var position = 0;
      for (final blockItem in _asList(r['blocks'])) {
        final b = _asMap(blockItem);
        final blockName = _string(b?['name']);
        if (b == null || blockName.isEmpty) {
          out.skipped.add('a block of "$name"');
          continue;
        }
        await _db
            .into(_db.blocks)
            .insert(
              BlocksCompanion.insert(
                id: _uuid.v4(),
                routineId: id,
                position: _int(b['position'], fallback: position),
                name: _clamp(blockName, 16),
                description: Value(_clamp(_string(b['description']), 24)),
                durationMin: _int(b['duration_min'], fallback: 25),
                category: _int(b['category']),
                trackEnabled: Value(_bool(b['track_enabled'])),
                startMin: Value(_int(b['start_min'], fallback: 0xFFFF)),
              ),
            );
        position++;
        out.blocks++;
      }
    }
  }

  Future<void> _tasks(Object? raw, ImportSummary out) async {
    for (final item in _asList(raw)) {
      final t = _asMap(item);
      final title = _string(t?['title']);
      if (t == null || title.isEmpty) {
        out.skipped.add('a task with no title');
        continue;
      }
      await _db
          .into(_db.tasks)
          .insertOnConflictUpdate(
            TasksCompanion.insert(
              id: _stringOrNull(t['id']) ?? _uuid.v4(),
              title: _clamp(title, 200),
              notes: Value(_string(t['notes'])),
              priority: Value(_int(t['priority'])),
              category: Value(_intOrNull(t['category'])),
              dueAt: Value(_date(t['due_at'])),
              completedAt: Value(_date(t['completed_at'])),
              createdAt: _date(t['created_at']) ?? DateTime.now(),
              recurrence: Value(_stringOrNull(t['recurrence'])),
            ),
          );
      out.tasks++;
    }
  }

  Future<void> _days(Object? raw, ImportSummary out) async {
    for (final item in _asList(raw)) {
      final d = _asMap(item);
      final day = _date(d?['day']);
      if (d == null || day == null) {
        out.skipped.add('a day with no date');
        continue;
      }
      await _db
          .into(_db.dayLogs)
          .insertOnConflictUpdate(
            DayLogsCompanion.insert(
              day: DateTime(day.year, day.month, day.day),
              verifiedMin: Value(_int(d['verified_min'])),
              claimedMin: Value(_int(d['claimed_min'])),
              blocksDone: Value(_int(d['blocks_done'])),
              blocksTotal: Value(_int(d['blocks_total'])),
              violations: Value(_int(d['violations'])),
              source: Value(_int(d['source'])),
            ),
          );
      out.days++;
    }
  }

  Future<void> _sessions(Object? raw, ImportSummary out) async {
    for (final item in _asList(raw)) {
      final s = _asMap(item);
      final startedAt = _date(s?['started_at']);
      if (s == null || startedAt == null) {
        out.skipped.add('a block with no start time');
        continue;
      }
      await _db
          .into(_db.sessions)
          .insertOnConflictUpdate(
            SessionsCompanion.insert(
              id: _stringOrNull(s['id']) ?? _uuid.v4(),
              startedAt: startedAt,
              endedAt: Value(_date(s['ended_at'])),
              logicalDay: _date(s['logical_day']) ?? startedAt,
              blockName: _string(s['block_name']),
              category: _int(s['category']),
              plannedSec: _int(s['planned_sec']),
              claimedSec: Value(_int(s['claimed_sec'])),
              verifiedSec: Value(_int(s['verified_sec'])),
              finalState: _int(s['final_state']),
              provenance: _int(s['provenance']),
              factorMask: Value(_int(s['factor_mask'])),
              trackEnabled: Value(_bool(s['track_enabled'])),
              violations: Value(_int(s['violations'])),
            ),
          );
      out.sessions++;
    }
  }

  // -- reading a file written by someone else -------------------------------------
  //
  // Every value is treated as untrusted. A backup can be hand-edited, produced
  // by a newer version, or truncated by whatever copied it, and none of those
  // should be a crash.

  static Map<String, Object?>? _asMap(Object? v) =>
      v is Map<String, Object?> ? v : null;

  static List<Object?> _asList(Object? v) => v is List ? v : const <Object?>[];

  static String _string(Object? v) => v is String ? v : '';

  static String? _stringOrNull(Object? v) =>
      v is String && v.isNotEmpty ? v : null;

  static int _int(Object? v, {int fallback = 0}) => switch (v) {
    final int i => i,
    final num n => n.round(),
    final String s => int.tryParse(s) ?? fallback,
    _ => fallback,
  };

  static int? _intOrNull(Object? v) => v == null ? null : _int(v);

  static bool _bool(Object? v) => v == true || v == 1 || v == 'true';

  static DateTime? _date(Object? v) =>
      v is String && v.isNotEmpty ? DateTime.tryParse(v) : null;

  /// Names are width-limited by the schema — and by the firmware struct behind
  /// it. A backup carrying a longer one is trimmed rather than rejected.
  static String _clamp(String v, int max) =>
      v.length <= max ? v : v.substring(0, max);
}
