import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusfreak_app/app/providers.dart';
import 'package:focusfreak_app/core/ff_constants.dart';
import 'package:focusfreak_app/data/db/database.dart';
import 'package:focusfreak_app/data/repo/routine_repository.dart';
import 'package:focusfreak_app/design/components/ff_card.dart';
import 'package:focusfreak_app/design/ff_colors.dart';
import 'package:focusfreak_app/design/ff_theme.dart';
import 'package:focusfreak_app/features/routines/routine_editor_screen.dart';
import 'package:focusfreak_app/features/routines/widgets/routine_card.dart';

/// Widget tests for the editor.
///
/// These deliberately feed the screen a fixed [RoutineWithBlocks] rather than a
/// live database. Drift's async work does not complete inside `testWidgets`'
/// fake-async zone, so a DB-backed widget test hangs rather than fails — and
/// the database behaviour is already covered directly in `repository_test.dart`.
/// What is worth testing here is the layout, which is where the real bug was.
void main() {
  Routine routine({bool builtIn = false}) => Routine(
    id: 'r1',
    name: 'Test Routine',
    description: 'A routine',
    isBuiltIn: builtIn,
    templateKey: builtIn ? 'standard' : null,
    sortOrder: 0,
    archived: false,
    createdAt: DateTime(2026, 8, 2),
    updatedAt: DateTime(2026, 8, 2),
  );

  Block block(
    int i,
    String name,
    int minutes,
    int category, {
    bool track = false,
  }) => Block(
    id: 'b$i',
    routineId: 'r1',
    position: i,
    name: name,
    description: '',
    durationMin: minutes,
    category: category,
    trackEnabled: track,
    startMin: FfFirmware.sequentialStartMin,
  );

  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() async => db.close());

  Widget host(RoutineWithBlocks? detail) => ProviderScope(
    overrides: <Override>[
      // Without this the screen's `ref.read(routineRepositoryProvider)`
      // builds a real on-disk database, whose timers outlive the test.
      databaseProvider.overrideWithValue(db),
      routineDetailProvider(
        'r1',
      ).overrideWith((ref) => Stream<RoutineWithBlocks?>.value(detail)),
    ],
    child: MaterialApp(
      theme: FfTheme.of(FfThemeMode.dark),
      home: const RoutineEditorScreen(routineId: 'r1'),
    ),
  );

  testWidgets('lists every block, with its summary and shape bar', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        RoutineWithBlocks(routine(), <Block>[
          block(0, 'Deep Work 1', 90, 0, track: true),
          block(1, 'Deep Work 2', 60, 0, track: true),
          block(2, 'Break', 15, 4),
          block(3, 'Practice', 45, 2),
        ]),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);

    expect(find.text('3h 30m'), findsOneWidget, reason: 'total');
    expect(find.text('2h 30m'), findsOneWidget, reason: 'deep work only');
    expect(find.byType(RoutineShapeBar), findsOneWidget);

    expect(find.text('Deep Work 1'), findsOneWidget);
    expect(find.text('Deep Work 2'), findsOneWidget);
    expect(find.text('Break'), findsOneWidget);
    expect(find.text('Practice'), findsOneWidget);
    // The category label "Output" also appears on that block's metadata row.
    expect(find.text('Output'), findsOneWidget);
  });

  testWidgets('block cards have real height — the accent rail must not '
      'collapse them', (tester) async {
    await tester.pumpWidget(
      host(
        RoutineWithBlocks(routine(), <Block>[
          block(0, 'Deep Work 1', 90, 0, track: true),
        ]),
      ),
    );
    await tester.pump();

    // The regression this guards: an accent rail built as a stretched Row child
    // sits in an unbounded vertical context and collapses the card to zero
    // height, so the list renders as blank space with no error.
    final card = tester.getSize(find.byType(FfCard).first);
    expect(card.height, greaterThan(40));
    expect(card.width, greaterThan(100));
  });

  testWidgets('the shape bar actually paints its segments', (tester) async {
    await tester.pumpWidget(
      host(
        RoutineWithBlocks(routine(), <Block>[
          block(0, 'Deep Work 1', 90, 0),
          block(1, 'Core Sleep', 360, 5),
        ]),
      ),
    );
    await tester.pump();

    final bar = tester.getSize(find.byType(RoutineShapeBar));
    expect(bar.height, 10);
    expect(bar.width, greaterThan(100));

    // Checking the bar's own size is not enough. A ColoredBox has no intrinsic
    // height, so under a Row's default centre alignment each segment collapses
    // to zero while the bar still reports the correct size — the bar measures
    // right and paints nothing. Assert on the segments themselves.
    final segments = find.descendant(
      of: find.byType(RoutineShapeBar),
      matching: find.byType(ColoredBox),
    );
    expect(segments, findsNWidgets(2));

    for (var i = 0; i < 2; i++) {
      final size = tester.getSize(segments.at(i));
      expect(size.height, 10, reason: 'segment $i collapsed');
      expect(size.width, greaterThan(0), reason: 'segment $i has no width');
    }

    // Widths are proportional to duration: 90 vs 360 is 1:4.
    final deep = tester.getSize(segments.at(0)).width;
    final sleep = tester.getSize(segments.at(1)).width;
    expect(sleep / deep, closeTo(4, 0.01));
  });

  testWidgets('an empty routine shows its empty state, not a blank screen', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(RoutineWithBlocks(routine(), const <Block>[])),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('No blocks yet'), findsOneWidget);
  });

  testWidgets('a missing routine says so rather than showing nothing', (
    tester,
  ) async {
    await tester.pumpWidget(host(null));
    await tester.pump();

    expect(find.text('Routine not found'), findsOneWidget);
  });

  testWidgets('a built-in template is read-only and offers Duplicate', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        RoutineWithBlocks(routine(builtIn: true), <Block>[
          block(0, 'Wake & Freshen', 30, 3),
        ]),
      ),
    );
    await tester.pump();

    expect(find.text('Duplicate'), findsOneWidget);
    expect(find.textContaining('Duplicate it to make changes'), findsOneWidget);

    // Read-only means "not editable", not "not usable": a template must be
    // runnable as shipped, so it gets the Start button but no Add-block button.
    expect(find.widgetWithText(FloatingActionButton, 'Start'), findsOneWidget);
    expect(
      find.byIcon(Icons.add_rounded),
      findsNothing,
      reason: 'a shipped template must not be editable in place',
    );
  });

  testWidgets('a routine longer than the bot holds stays whole in the app', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        RoutineWithBlocks(routine(), <Block>[
          for (var i = 0; i < 18; i++) block(i, 'Block $i', 30, i % 6),
        ]),
      ),
    );
    await tester.pump();

    // Said up front, so the bot showing only part of the day is no surprise.
    expect(
      find.textContaining('The bot holds 16 blocks at a time'),
      findsOneWidget,
    );

    // Every block is still here and still a normal block: the bot gets the
    // later ones as the day reaches them, not never.
    await tester.scrollUntilVisible(find.text('Block 17'), 300);
    await tester.pump();
    expect(find.text('Block 17'), findsOneWidget);
  });

  testWidgets('the category rail uses the firmware colour', (tester) async {
    await tester.pumpWidget(
      host(
        RoutineWithBlocks(routine(), <Block>[block(0, 'Deep Work 1', 90, 0)]),
      ),
    );
    await tester.pump();

    final card = tester.widget<FfCard>(find.byType(FfCard).first);
    expect(card.accent, FfColors.category(0));
  });
}
