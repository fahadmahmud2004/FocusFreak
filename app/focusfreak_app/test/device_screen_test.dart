import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusfreak_app/app/providers.dart';
import 'package:focusfreak_app/data/db/database.dart';
import 'package:focusfreak_app/design/components/ff_badge.dart';
import 'package:focusfreak_app/design/ff_theme.dart';
import 'package:focusfreak_app/features/device/device_controller.dart';
import 'package:focusfreak_app/features/device/device_screen.dart';

/// What the connect screen shows, with fixed data.
///
/// Two traps live in this file and both cost real time:
///
/// 1. **Connecting must happen inside `tester.runAsync`.** The link waits on a
///    `Future.delayed` for its transport latency, and under the fake clock
///    that timer only fires while the test pumps — which it cannot do while it
///    is awaiting the connect. The result is a deadlock, not a failure.
/// 2. **`pumpAndSettle` never returns once a bot is connected.** A live link
///    holds two periodic timers — the status poll and the parser's resync tick
///    — so there is no idle frame to settle on. Pump single frames instead.
/// 3. **A test that leaves the link open fails on pending timers.** Every test
///    that connects also disconnects, which is a fair reflection of what the
///    app must do too.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() async => db.close());

  Routine routine(String id, String name) => Routine(
    id: id,
    name: name,
    description: 'A day',
    isBuiltIn: false,
    sortOrder: 0,
    archived: false,
    createdAt: DateTime(2026, 8, 1),
    updatedAt: DateTime(2026, 8, 1),
  );

  Widget host() => ProviderScope(
    overrides: <Override>[
      // Without this the screen's repositories build a real on-disk
      // database, whose timers outlive the test.
      databaseProvider.overrideWithValue(db),
      routinesProvider.overrideWith(
        (ref) => Stream<List<Routine>>.value(<Routine>[
          routine('r1', 'Standard'),
          routine('r2', 'Exam Cram'),
        ]),
      ),
      // A `MethodChannel` reply needs a real event loop, so under the
      // fake clock this future would never complete and the Bluetooth
      // section would render nothing at all. Feed the answer in: there is
      // no plugin in a test binding, which is the same answer the web
      // build gets.
      bluetoothAvailableProvider.overrideWith((ref) async => false),
    ],
    child: MaterialApp(
      theme: FfTheme.of(FfThemeMode.dark),
      home: const DeviceScreen(),
    ),
  );

  DeviceController controllerOf(WidgetTester tester) =>
      ProviderScope.containerOf(
        tester.element(find.byType(DeviceScreen)),
      ).read(deviceControllerProvider.notifier);

  /// Connects the virtual bot in the real async zone, then pumps a frame.
  Future<DeviceController> connect(WidgetTester tester) async {
    final controller = controllerOf(tester);
    await tester.runAsync(
      () => controller.connectVirtual(latency: Duration.zero),
    );
    await tester.pump();
    return controller;
  }

  Future<void> refresh(WidgetTester tester, DeviceController controller) async {
    await tester.runAsync(controller.refreshStatus);
    await tester.pump();
  }

  Future<void> close(WidgetTester tester, DeviceController controller) async {
    await tester.runAsync(controller.disconnect);
    await tester.pump();
  }

  Map<String, FfBadgeState> badges(WidgetTester tester) =>
      <String, FfBadgeState>{
        for (final b in tester.widgetList<FfBadge>(find.byType(FfBadge)))
          b.label: b.state,
      };

  testWidgets('leads with finding a real bot, not the simulated one', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    expect(find.text('No bot connected'), findsOneWidget);
    // The screen a customer sees first is about their hardware. The virtual
    // bot is still here and still works, but it is the fallback now — someone
    // who has just unboxed a bot should not have to scroll past a simulation
    // of it.
    expect(find.text('Connect your bot'), findsOneWidget);
    expect(find.text('No bot yet?'), findsOneWidget);

    // No Bluetooth plugin in a test binding, and the screen says so plainly
    // rather than showing an empty list or a stack trace.
    expect(find.textContaining('no Bluetooth'), findsOneWidget);
    expect(find.textContaining('Nothing yet'), findsOneWidget);
  });

  testWidgets('the virtual bot is still one tap away', (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    // Demoted, not removed: a demo has to survive the hardware dying on the
    // day, which is the reason it exists at all.
    //
    // The tap itself is not driven here — `connectVirtual` under the fake
    // clock is trap 1 in this file's header — so this asserts the tile is
    // present and enabled, and `connect()` covers what the tap does.
    final tile = tester.widget<ListTile>(
      find.ancestor(
        of: find.text('No bot yet?'),
        matching: find.byType(ListTile),
      ),
    );
    expect(tile.onTap, isNotNull);
  });

  testWidgets('a connected bot shows what it has and what it does not', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    final controller = await connect(tester);

    expect(find.text('Connected to Virtual bot'), findsOneWidget);
    expect(find.text('What this bot has'), findsOneWidget);

    // This build has no battery gauge and no sound sensor. Both must read
    // unavailable — never as a sensor that failed.
    final byLabel = badges(tester);
    expect(byLabel['Presence'], FfBadgeState.on);
    expect(byLabel['Dock'], FfBadgeState.on);
    expect(byLabel['Battery'], FfBadgeState.unavailable);
    expect(byLabel['Sound'], FfBadgeState.unavailable);

    await close(tester, controller);
  });

  testWidgets('with nothing tracked, VERIFIED reads unavailable not failed', (
    tester,
  ) async {
    // An untracked block is not a failed verification, and an amber badge
    // would say that it was.
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    final controller = await connect(tester);
    await refresh(tester, controller);

    final byLabel = badges(tester);
    expect(byLabel['VERIFIED'], FfBadgeState.unavailable);
    expect(byLabel['TRACK'], FfBadgeState.unavailable);

    await close(tester, controller);
  });

  testWidgets('leaving the desk shows HERE dropping out', (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    final controller = await connect(tester);
    await refresh(tester, controller);
    expect(badges(tester)['HERE'], FfBadgeState.on);

    controller.simulated!.present = false;
    await refresh(tester, controller);
    expect(badges(tester)['HERE'], FfBadgeState.off);

    await close(tester, controller);
  });

  testWidgets('the routine list is offered for pushing once connected', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    expect(find.text('Send a routine'), findsNothing);

    final controller = await connect(tester);
    await tester.pump(); // the routine stream's first value
    expect(find.text('Send a routine'), findsOneWidget);
    expect(find.text('Standard'), findsOneWidget);
    expect(find.text('Exam Cram'), findsOneWidget);

    await close(tester, controller);
  });

  testWidgets('the wire log fills with both directions', (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    final controller = await connect(tester);

    expect(find.textContaining('>> HELLO'), findsWidgets);
    expect(find.textContaining('<< HELLO_ACK'), findsWidgets);

    await close(tester, controller);
  });

  testWidgets('the virtual sensor switches move when tapped', (tester) async {
    // They did not: the section read the controller instead of watching it,
    // so flipping a switch changed the bot and left the switch where it was.
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    final controller = await connect(tester);
    await refresh(tester, controller);

    final atTheDesk = find.ancestor(
      of: find.text('At the desk'),
      matching: find.byType(SwitchListTile),
    );
    expect(tester.widget<SwitchListTile>(atTheDesk).value, isTrue);

    // Scrolled into view first: the section sits below the fold on a phone,
    // and a tap on an off-screen widget lands nowhere.
    await tester.ensureVisible(atTheDesk);
    await tester.pump();
    await tester.tap(atTheDesk);
    await tester.pump();
    await refresh(tester, controller);

    expect(controller.simulated!.present, isFalse);
    expect(
      tester.widget<SwitchListTile>(atTheDesk).value,
      isFalse,
      reason: 'the switch has to follow the sensor it just changed',
    );
    expect(badges(tester)['HERE'], FfBadgeState.off);

    await close(tester, controller);
  });

  testWidgets('nothing overflows at a small phone size', (tester) async {
    // Every silent layout failure in this codebase has been a sizing bug, and
    // a narrow screen is where they show up first.
    tester.view.physicalSize = const Size(360 * 3, 640 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    final controller = await connect(tester);
    await refresh(tester, controller);

    expect(tester.takeException(), isNull);
    await close(tester, controller);
  });
}
