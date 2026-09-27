import 'dart:convert';

import '../../core/ff_format.dart';
import '../../data/db/database.dart';
import '../../domain/model/session_state.dart';
import '../../domain/model/verification.dart';

/// Plain-text exports of everything the app holds.
///
/// This exists because FocusFreak has no cloud and no account. Data that only
/// lives in one SQLite file on one phone needs a way out, or a lost phone means
/// a lost record. The formats are deliberately dull and documented so they can
/// be opened in a spreadsheet or parsed by anything.
class DataExport {
  const DataExport();

  /// One row per block. The complete record the PDF's block table caps.
  String sessionsCsv(List<Session> sessions) {
    final rows = <List<String>>[
      <String>[
        'date',
        'started_at',
        'ended_at',
        'block',
        'category_id',
        'category',
        'planned_sec',
        'claimed_sec',
        'verified_sec',
        'verified_ratio',
        'final_state',
        'evidence',
        'factors_available',
        'tracked',
        'violations',
      ],
      for (final s in sessions)
        <String>[
          FfFormat.shortDate(s.logicalDay),
          s.startedAt.toIso8601String(),
          s.endedAt?.toIso8601String() ?? '',
          s.blockName,
          '${s.category}',
          _categoryName(s.category),
          '${s.plannedSec}',
          '${s.claimedSec}',
          '${s.verifiedSec}',
          s.claimedSec == 0
              ? ''
              : (s.verifiedSec / s.claimedSec).toStringAsFixed(3),
          SessionState.fromWire(s.finalState).name,
          Provenance.values[s.provenance].name,
          _factorNames(s.factorMask),
          s.trackEnabled ? 'yes' : 'no',
          '${s.violations}',
        ],
    ];
    return _csv(rows);
  }

  /// One row per day.
  String daysCsv(List<DayLog> days) {
    final rows = <List<String>>[
      <String>[
        'date',
        'verified_min',
        'claimed_min',
        'verified_ratio',
        'blocks_done',
        'blocks_total',
        'violations',
        'source',
      ],
      for (final d in days)
        <String>[
          FfFormat.shortDate(d.day),
          '${d.verifiedMin}',
          '${d.claimedMin}',
          d.claimedMin == 0
              ? ''
              : (d.verifiedMin / d.claimedMin).toStringAsFixed(3),
          '${d.blocksDone}',
          '${d.blocksTotal}',
          '${d.violations}',
          switch (d.source) {
            1 => 'device',
            2 => 'merged',
            _ => 'app',
          },
        ],
    ];
    return _csv(rows);
  }

  /// Everything, as JSON. Intended for re-import, so it keeps raw values
  /// rather than formatted ones.
  String fullJson({
    required List<Session> sessions,
    required List<DayLog> days,
    required List<Routine> routines,
    required List<Block> blocks,
    required List<Task> tasks,
    required Map<String, String> settings,
  }) {
    final payload = <String, Object?>{
      'format': 'focusfreak-export',
      'version': 1,
      'exported_at': DateTime.now().toIso8601String(),
      'settings': settings,
      'routines': <Map<String, Object?>>[
        for (final r in routines)
          <String, Object?>{
            'id': r.id,
            'name': r.name,
            'description': r.description,
            'is_built_in': r.isBuiltIn,
            'template_key': r.templateKey,
            'archived': r.archived,
            'sort_order': r.sortOrder,
            'created_at': r.createdAt.toIso8601String(),
            'updated_at': r.updatedAt.toIso8601String(),
            'blocks': <Map<String, Object?>>[
              for (final b in blocks.where((b) => b.routineId == r.id))
                <String, Object?>{
                  'position': b.position,
                  'name': b.name,
                  'description': b.description,
                  'duration_min': b.durationMin,
                  'category': b.category,
                  'track_enabled': b.trackEnabled,
                  'start_min': b.startMin,
                },
            ],
          },
      ],
      'tasks': <Map<String, Object?>>[
        for (final t in tasks)
          <String, Object?>{
            'id': t.id,
            'title': t.title,
            'notes': t.notes,
            'priority': t.priority,
            'category': t.category,
            'due_at': t.dueAt?.toIso8601String(),
            'completed_at': t.completedAt?.toIso8601String(),
            'created_at': t.createdAt.toIso8601String(),
            'recurrence': t.recurrence,
          },
      ],
      'days': <Map<String, Object?>>[
        for (final d in days)
          <String, Object?>{
            'day': d.day.toIso8601String(),
            'verified_min': d.verifiedMin,
            'claimed_min': d.claimedMin,
            'blocks_done': d.blocksDone,
            'blocks_total': d.blocksTotal,
            'violations': d.violations,
            'source': d.source,
          },
      ],
      'sessions': <Map<String, Object?>>[
        for (final s in sessions)
          <String, Object?>{
            'id': s.id,
            'started_at': s.startedAt.toIso8601String(),
            'ended_at': s.endedAt?.toIso8601String(),
            'logical_day': s.logicalDay.toIso8601String(),
            'block_name': s.blockName,
            'category': s.category,
            'planned_sec': s.plannedSec,
            'claimed_sec': s.claimedSec,
            'verified_sec': s.verifiedSec,
            'final_state': s.finalState,
            'provenance': s.provenance,
            'factor_mask': s.factorMask,
            'track_enabled': s.trackEnabled,
            'violations': s.violations,
          },
      ],
    };

    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  static String _categoryName(int id) => switch (id) {
    0 => 'Deep Work',
    1 => 'Active Work',
    2 => 'Output',
    3 => 'Routine',
    4 => 'Nap + Buffer',
    5 => 'Sleep',
    _ => 'Unknown',
  };

  /// Which verification channels were available, so a reader can tell a
  /// three-factor session from a one-factor one.
  static String _factorNames(int mask) {
    final names = <String>[
      for (final f in VerificationFactor.values)
        if (mask & f.bit != 0) f.name,
    ];
    return names.join('|');
  }

  /// RFC 4180: quote when the value contains a delimiter, quote or newline,
  /// and escape embedded quotes by doubling them. A block name with a comma in
  /// it must not shift every later column.
  static String _csv(List<List<String>> rows) {
    final buffer = StringBuffer();
    for (final row in rows) {
      buffer.writeln(row.map(_cell).join(','));
    }
    return buffer.toString();
  }

  static String _cell(String value) {
    final needsQuotes =
        value.contains(',') ||
        value.contains('"') ||
        value.contains('\n') ||
        value.contains('\r');
    if (!needsQuotes) return value;
    return '"${value.replaceAll('"', '""')}"';
  }
}
