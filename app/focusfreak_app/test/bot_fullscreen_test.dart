import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusfreak_app/botos/world.dart';
import 'package:focusfreak_app/features/bot/bot_device.dart';
import 'package:focusfreak_app/features/bot/bot_fullscreen.dart';
import 'package:focusfreak_app/features/bot/botos_host.dart';
import 'package:focusfreak_app/features/bot/oled_display.dart';
import 'package:focusfreak_app/platform/screen_channel.dart';

/// A host that records keys instead of running BotOS, which would need the
/// database.
class _KeyRecorder extends BotOsHost {
  _KeyRecorder(super.ref) : super(run: false);

  final List<BotKey> keys = <BotKey>[];

  @override
  void key(BotKey k) => keys.add(k);
}

/// The phone-as-bot screen: BotOS's own pixels, full size, with the bot's
/// controls. The screen keeps a one-second timer for the controls' fade, so
/// these pump fixed frames rather than settling.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<MethodCall> screenCalls;
  late List<MethodCall> chromeCalls;

  setUp(() {
    screenCalls = <MethodCall>[];
    chromeCalls = <MethodCall>[];

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('focusfreak/screen'), (
          call,
        ) async {
          screenCalls.add(call);
          return null;
        });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          chromeCalls.add(call);
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      ..setMockMethodCallHandler(const MethodChannel('focusfreak/screen'), null)
      ..setMockMethodCallHandler(SystemChannels.platform, null);
  });

  late _KeyRecorder recorder;

  final wheelFinder = find.byWidgetPredicate(
    (w) =>
        w is CustomPaint && w.painter.runtimeType.toString() == '_JogPainter',
  );

  Widget host() => ProviderScope(
    overrides: <Override>[
      botOsProvider.overrideWith((ref) => recorder = _KeyRecorder(ref)),
    ],
    child: const MaterialApp(
      home: BotFullscreenScreen(screen: ScreenChannel()),
    ),
  );

  Future<void> open(WidgetTester tester, {Size? size}) async {
    if (size != null) {
      tester.view.physicalSize = size * 3;
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
    }
    await tester.pumpWidget(host());
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('keeps the screen awake while it is open, and stops after', (
    tester,
  ) async {
    // A dock display that blanks after 30 seconds is not a dock display.
    await open(tester);
    expect(screenCalls.map((c) => c.arguments['keep']), contains(true));

    screenCalls.clear();
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pump();

    expect(
      screenCalls.map((c) => c.arguments['keep']),
      contains(false),
      reason: 'leaving must hand the screen timeout back to Android',
    );
  });

  testWidgets('hides the system bars, and restores them on the way out', (
    tester,
  ) async {
    await open(tester);
    final entering = chromeCalls
        .where((c) => c.method == 'SystemChrome.setEnabledSystemUIMode')
        .map((c) => c.arguments as String)
        .toList();
    expect(entering, contains('SystemUiMode.immersiveSticky'));

    chromeCalls.clear();
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pump();

    expect(
      chromeCalls
          .where((c) => c.method == 'SystemChrome.setEnabledSystemUIMode')
          .map((c) => c.arguments as String),
      contains('SystemUiMode.edgeToEdge'),
    );
  });

  testWidgets('lays out in portrait without overflowing', (tester) async {
    await open(tester, size: const Size(360, 640));
    expect(tester.takeException(), isNull);
    expect(find.byType(CustomPaint), findsWidgets);
  });

  testWidgets('lays out in landscape without overflowing', (tester) async {
    // The pose that matters: phone on its side in a stand, being read from
    // across the desk.
    await open(tester, size: const Size(740, 360));
    expect(tester.takeException(), isNull);
    expect(find.byType(CustomPaint), findsWidgets);
  });

  testWidgets('survives a very short screen', (tester) async {
    await open(tester, size: const Size(320, 480));
    expect(tester.takeException(), isNull);
  });

  testWidgets('there is always a way out', (tester) async {
    // A bot screen you cannot leave is a kiosk, not a tool. The control fades
    // but never disappears.
    await open(tester, size: const Size(360, 640));
    expect(find.byTooltip('Leave full screen'), findsOneWidget);

    // Live even while faded — the fade is the point, not a disabled state.
    final control = tester.widget<IconButton>(
      find.ancestor(
        of: find.byTooltip('Leave full screen'),
        matching: find.byType(IconButton),
      ),
    );
    expect(control.onPressed, isNotNull);
  });

  testWidgets('rotation can be locked either way, and unlocked again', (
    tester,
  ) async {
    // The layout already follows the phone. This is for a phone lying flat, or
    // one whose owner turned system rotation off.
    await open(tester, size: const Size(360, 640));
    chromeCalls.clear();

    List<String> orientations() => chromeCalls
        .where((c) => c.method == 'SystemChrome.setPreferredOrientations')
        .map((c) => (c.arguments as List<Object?>).join(','))
        .toList();

    expect(find.byTooltip('Rotation follows the phone'), findsOneWidget);

    await tester.tap(find.byTooltip('Rotation follows the phone'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byTooltip('Staying upright'), findsOneWidget);
    expect(orientations().last, contains('portraitUp'));
    expect(orientations().last, isNot(contains('landscapeLeft')));

    await tester.tap(find.byTooltip('Staying upright'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byTooltip('Staying sideways'), findsOneWidget);
    expect(orientations().last, contains('landscapeLeft'));

    await tester.tap(find.byTooltip('Staying sideways'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byTooltip('Rotation follows the phone'), findsOneWidget);
    expect(orientations().last, contains('portraitUp'));
    expect(orientations().last, contains('landscapeLeft'));
  });

  testWidgets('a lock does not outlive the screen', (tester) async {
    await open(tester, size: const Size(360, 640));
    await tester.tap(find.byTooltip('Rotation follows the phone'));
    await tester.pump(const Duration(milliseconds: 100));
    chromeCalls.clear();

    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pump();

    expect(
      chromeCalls
          .where((c) => c.method == 'SystemChrome.setPreferredOrientations')
          .map((c) => (c.arguments as List<Object?>).join(','))
          .last,
      contains('landscapeLeft'),
      reason: 'the rest of the app must not inherit this screen\'s lock',
    );
  });

  testWidgets('upright, it is the bot itself, controls and all', (
    tester,
  ) async {
    await open(tester, size: const Size(390, 844));
    expect(find.byType(BotDevice), findsOneWidget);
    expect(find.byType(OledDisplay), findsOneWidget);
    expect(find.text('MENU'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('upright, the device controls reach the bot', (tester) async {
    await open(tester, size: const Size(390, 844));
    // The button sits just above its label.
    await tester.tapAt(
      tester.getCenter(find.text('MENU')) - const Offset(0, 30),
    );
    await tester.tap(find.byType(OledDisplay));
    await tester.pump(const Duration(milliseconds: 200));
    expect(
      recorder.keys,
      containsAll(<BotKey>[BotKey.button, BotKey.touchLeft]),
    );
  });

  testWidgets('upright, on a small phone, nothing overflows', (tester) async {
    await open(tester, size: const Size(320, 568));
    expect(tester.takeException(), isNull);
  });

  testWidgets('sideways, only the screen until the controls are asked for', (
    tester,
  ) async {
    await open(tester, size: const Size(844, 390));
    expect(find.byType(BotDevice), findsNothing);
    expect(wheelFinder, findsNothing);
    expect(find.byTooltip('Show controls'), findsOneWidget);
  });

  testWidgets('sideways, a touch pets and a swipe turns the page', (
    tester,
  ) async {
    await open(tester, size: const Size(844, 390));
    await tester.tap(find.byType(OledDisplay));
    await tester.drag(find.byType(OledDisplay), const Offset(-160, 0));
    await tester.pump(const Duration(milliseconds: 200));
    expect(recorder.keys, contains(BotKey.touchLeft));
    expect(recorder.keys, contains(BotKey.right));
  });

  Future<void> openControls(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Show controls'));
    await tester.pump(const Duration(milliseconds: 200));
  }

  testWidgets('sideways, the controls reach the bot', (tester) async {
    await open(tester, size: const Size(844, 390));
    await openControls(tester);
    expect(tester.takeException(), isNull);
    for (final label in <String>['Menu', 'Poke', 'Pet', 'Back home']) {
      await tester.tap(find.byTooltip(label));
    }
    await tester.tap(wheelFinder);
    await tester.pump(const Duration(milliseconds: 200));
    expect(
      recorder.keys,
      containsAll(<BotKey>[
        BotKey.button,
        BotKey.touchFront,
        BotKey.touchLeft,
        BotKey.hold,
        BotKey.press,
      ]),
    );
  });

  testWidgets('circling the wheel turns the knob', (tester) async {
    await open(tester, size: const Size(844, 390));
    await openControls(tester);
    final c = tester.getCenter(wheelFinder);
    final r = tester.getSize(wheelFinder).width * 0.4;
    final gesture = await tester.startGesture(c + Offset(r, 0));
    for (var i = 1; i <= 12; i++) {
      final a = i * 0.25;
      await gesture.moveTo(c + Offset(r * cos(a), r * sin(a)));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 200));
    expect(
      recorder.keys.where((k) => k == BotKey.right).length,
      greaterThan(3),
    );
    expect(recorder.keys, isNot(contains(BotKey.press)));
  });
}
