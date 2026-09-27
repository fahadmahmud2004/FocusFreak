import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:focusfreak_app/data/db/database.dart';
import 'package:focusfreak_app/domain/model/session_state.dart';
import 'package:focusfreak_app/domain/model/verification.dart';
import 'package:focusfreak_app/features/reports/data_export.dart';

void main() {
  const export = DataExport();
  final day = DateTime(2026, 8, 2);

  Session session({
    String name = 'Deep Work 1',
    int verifiedSec = 4920,
    int claimedSec = 5400,
    int factorMask = 7,
    Provenance provenance = Provenance.sensorVerified,
    int violations = 2,
  }) => Session(
    id: 's1',
    startedAt: DateTime(2026, 8, 2, 9),
    endedAt: DateTime(2026, 8, 2, 10, 30),
    logicalDay: day,
    blockName: name,
    category: 0,
    plannedSec: 5400,
    claimedSec: claimedSec,
    verifiedSec: verifiedSec,
    finalState: SessionState.complete.index,
    provenance: provenance.index,
    factorMask: factorMask,
    trackEnabled: true,
    violations: violations,
  );

  group('sessions CSV', () {
    test('has a header and one row per session', () {
      final csv = export.sessionsCsv(<Session>[session(), session()]);
      final lines = const LineSplitter().convert(csv);

      expect(lines, hasLength(3));
      expect(lines.first, startsWith('date,started_at'));
      expect(lines[1], contains('Deep Work 1'));
    });

    test('records which verification channels were available', () {
      final csv = export.sessionsCsv(<Session>[
        session(
          factorMask:
              VerificationFactor.presence.bit |
              VerificationFactor.dock.bit |
              VerificationFactor.screenLock.bit,
        ),
      ]);
      expect(csv, contains('presence|dock|screenLock'));
      expect(csv, contains('sensorVerified'));
    });

    test('a one-factor session is distinguishable from a three-factor one', () {
      final csv = export.sessionsCsv(<Session>[
        session(
          factorMask: VerificationFactor.screenLock.bit,
          provenance: Provenance.appVerified,
        ),
      ]);
      expect(csv, contains(',screenLock,'));
      expect(csv, contains('appVerified'));
      expect(csv, isNot(contains('presence')));
    });

    test('a comma in a block name does not shift the columns', () {
      final csv = export.sessionsCsv(<Session>[
        session(name: 'Math, Physics, Chem'),
      ]);
      final row = const LineSplitter().convert(csv)[1];

      expect(row, contains('"Math, Physics, Chem"'));
      // Header and data must still agree on column count.
      final header = const LineSplitter().convert(csv).first.split(',').length;
      expect(_countCsvFields(row), header);
    });

    test('a quote in a block name is escaped by doubling', () {
      final csv = export.sessionsCsv(<Session>[
        session(name: 'The "hard" one'),
      ]);
      expect(csv, contains('"The ""hard"" one"'));
    });

    test('the verified ratio is blank rather than a divide by zero', () {
      final csv = export.sessionsCsv(<Session>[
        session(verifiedSec: 0, claimedSec: 0),
      ]);
      expect(csv, isNot(contains('NaN')));
      expect(csv, isNot(contains('Infinity')));
    });
  });

  group('days CSV', () {
    test('labels the source of each day', () {
      final csv = export.daysCsv(<DayLog>[
        DayLog(
          day: day,
          verifiedMin: 82,
          claimedMin: 90,
          blocksDone: 1,
          blocksTotal: 1,
          violations: 0,
          source: 0,
        ),
        DayLog(
          day: day.subtract(const Duration(days: 1)),
          verifiedMin: 40,
          claimedMin: 60,
          blocksDone: 1,
          blocksTotal: 1,
          violations: 1,
          source: 2,
        ),
      ]);
      expect(csv, contains(',app'));
      expect(csv, contains(',merged'));
    });
  });

  group('full JSON', () {
    test('round-trips through a JSON parser', () {
      final json = export.fullJson(
        sessions: <Session>[session()],
        days: <DayLog>[
          DayLog(
            day: day,
            verifiedMin: 82,
            claimedMin: 90,
            blocksDone: 1,
            blocksTotal: 1,
            violations: 0,
            source: 0,
          ),
        ],
        routines: <Routine>[
          Routine(
            id: 'r1',
            name: 'My Routine',
            description: '',
            isBuiltIn: false,
            sortOrder: 0,
            archived: false,
            createdAt: day,
            updatedAt: day,
          ),
        ],
        blocks: <Block>[
          Block(
            id: 'b1',
            routineId: 'r1',
            position: 0,
            name: 'Deep Work 1',
            description: '',
            durationMin: 90,
            category: 0,
            trackEnabled: true,
            startMin: 0xFFFF,
          ),
        ],
        tasks: <Task>[
          Task(
            id: 't1',
            title: 'Revise',
            notes: '',
            priority: 0,
            createdAt: day,
            estimatedPomodoros: 0,
            completedPomodoros: 0,
            sortOrder: 0,
          ),
        ],
        settings: <String, String>{'theme_mode': 'dark'},
      );

      final decoded = jsonDecode(json) as Map<String, dynamic>;
      expect(decoded['format'], 'focusfreak-export');
      expect(decoded['version'], 1);
      expect((decoded['sessions'] as List<dynamic>), hasLength(1));
      expect(
        (decoded['routines'] as List<dynamic>).first['blocks'],
        hasLength(1),
      );
      expect(decoded['settings'], <String, String>{'theme_mode': 'dark'});
    });

    test('is self-describing enough to re-import', () {
      final json = export.fullJson(
        sessions: const <Session>[],
        days: const <DayLog>[],
        routines: const <Routine>[],
        blocks: const <Block>[],
        tasks: const <Task>[],
        settings: const <String, String>{},
      );
      final decoded = jsonDecode(json) as Map<String, dynamic>;

      // A backup with no format marker cannot be safely restored by a later
      // version, so these keys are part of the contract.
      expect(decoded.containsKey('format'), isTrue);
      expect(decoded.containsKey('version'), isTrue);
      expect(decoded.containsKey('exported_at'), isTrue);
    });
  });
}

/// Count RFC 4180 fields, respecting quoting.
int _countCsvFields(String row) {
  var count = 1;
  var inQuotes = false;
  for (var i = 0; i < row.length; i++) {
    final c = row[i];
    if (c == '"') {
      inQuotes = !inQuotes;
    } else if (c == ',' && !inQuotes) {
      count++;
    }
  }
  return count;
}
