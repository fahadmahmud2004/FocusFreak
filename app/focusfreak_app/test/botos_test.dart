import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:focusfreak_app/botos/buzzer.dart';
import 'package:focusfreak_app/botos/music.dart';
import 'package:focusfreak_app/botos/os.dart';
import 'package:focusfreak_app/botos/routines.dart';
import 'package:focusfreak_app/botos/screens.dart';
import 'package:focusfreak_app/device/frame_codec.dart';
import 'package:focusfreak_app/device/protocol.dart';
import 'package:focusfreak_app/device/simulated_device.dart';

/// BotOS is the bot's firmware, written once. These pin down the behaviour
/// the C port has to match.
void main() {
  final now = DateTime(2026, 9, 26, 11, 24, 10);
  const room = BotSensors(
    tempC: 28.4,
    humidity: 64,
    light: 610,
    distanceCm: 55,
    phoneParked: true,
  );
  BotWorld world({BotSession? session, BotSensors sensors = room}) =>
      BotWorld(now: now, sensors: sensors, session: session);

  BotOs boot() => BotOs(random: math.Random(7));

  int lit(Gfx g) => g.pixels.fold(0, (s, p) => s + p);

  group('drawing', () {
    test('text is U8g2 text: baseline placement and real widths', () {
      final g = Gfx();
      final w = g.str(BotFonts.primary, 0, 10, 'Focus');
      expect(w, Gfx.strWidth(BotFonts.primary, 'Focus'));
      expect(w, greaterThan(20));
      // Nothing is drawn below the baseline for letters without descenders.
      for (var x = 0; x < w; x++) {
        expect(g.get(x, 11), isFalse);
      }
      expect(lit(g), greaterThan(30));
    });

    test('rounded boxes are symmetric and fill inside their bounds', () {
      final g = Gfx()..rBox(10, 10, 30, 20, 8);
      for (var y = 0; y < 64; y++) {
        for (var x = 0; x < 128; x++) {
          if (g.get(x, y)) {
            expect(x >= 10 && x < 40 && y >= 10 && y < 30, isTrue);
            expect(g.get(49 - x, y), isTrue, reason: 'mirror of $x,$y');
          }
        }
      }
      expect(g.get(10, 10), isFalse, reason: 'the corner is rounded off');
      expect(g.get(25, 20), isTrue);
    });

    test('draw colour 2 inverts, as U8g2 XOR does', () {
      final g = Gfx()..box(0, 0, 10, 10);
      g.color = 2;
      g.box(5, 0, 10, 10);
      expect(g.get(2, 2), isTrue);
      expect(g.get(7, 2), isFalse);
      expect(g.get(12, 2), isTrue);
    });

    test('long text is cut with an ellipsis to fit', () {
      final t = Gfx.fit(BotFonts.primary, 'A really long block name', 50);
      expect(t.endsWith('..'), isTrue);
      expect(Gfx.strWidth(BotFonts.primary, t), lessThanOrEqualTo(50));
    });
  });

  group('the face', () {
    test('every single tap on the head gets an immediate reaction', () {
      final os = boot();
      for (var i = 0; i < 40; i++) {
        os.tick(world());
      }
      final before = List<int>.of(os.gfx.pixels);
      for (var tap = 0; tap < 4; tap++) {
        os.key(BotKey.touchLeft);
        os.tick(world());
        expect(
          os.gfx.pixels,
          isNot(equals(before)),
          reason: 'tap $tap changed nothing on screen',
        );
        for (var i = 0; i < 3; i++) {
          os.tick(world());
        }
      }
    });

    test('a touch on another home page goes back to the face', () {
      final os = boot();
      os.key(BotKey.right);
      expect(os.home.current, isNot(HomePage.face));
      os.key(BotKey.touchRight);
      expect(os.home.current, HomePage.face);
    });

    test('happy squints: fewer lit pixels than calm', () {
      final calm = boot();
      final happy = boot();
      for (var i = 0; i < 30; i++) {
        calm.tick(world());
        happy.tick(BotWorld(now: now, sensors: room, mood: BotMood.happy));
      }
      expect(lit(happy.gfx), lessThan(lit(calm.gfx)));
    });
  });

  group('routines', () {
    test('the menu starts one of the bot\'s own routines', () {
      final os = boot();
      os.key(BotKey.button);
      os.key(BotKey.right);
      os.key(BotKey.press);
      expect(os.top, isA<RoutinesScreen>());
      os.key(BotKey.right);
      os.takeEffects();
      os.key(BotKey.press);
      final started = os.takeEffects().whereType<StartRoutine>().toList();
      expect(started, hasLength(1));
      expect(started.single.index, 1);
      expect(os.top, isA<HomeScreen>());
    });

    test('every routine fits on the bot and runs without a clock', () {
      for (final t in BotRoutines.all) {
        expect(t.blocks.length, lessThanOrEqualTo(16), reason: t.key);
        expect(t.blocks.every((b) => b.startMin == null), isTrue, reason: t.key);
      }
      expect(BotRoutines.length(BotRoutines.all.first), '4h 10m');
    });

    test('the firmware carries the same routines, in the same order', () {
      final script = File('../tools/make_firmware_assets.py').readAsStringSync();
      final line = RegExp(r'ROUTINE_KEYS = \[(.*?)\]').firstMatch(script)!;
      final keys = RegExp(r'"(\w+)"')
          .allMatches(line.group(1)!)
          .map((m) => m.group(1))
          .toList();
      expect(keys, BotRoutines.keys);
    });
  });

  group('navigation', () {
    test('button opens the menu and goes back; hold goes home', () {
      final os = boot();
      os.key(BotKey.button);
      expect(os.top, isA<MenuScreen>());
      os.key(BotKey.right);
      os.key(BotKey.right);
      os.key(BotKey.right);
      os.key(BotKey.press);
      expect(os.top, isA<GamesScreen>());
      os.key(BotKey.button);
      expect(os.top, isA<MenuScreen>());
      os.key(BotKey.press);
      os.key(BotKey.hold);
      expect(os.top, isA<HomeScreen>());
    });

    test('the knob turns through the home pages and wraps', () {
      final os = boot();
      final pages = os.home.pages.length;
      for (var i = 0; i < pages; i++) {
        os.key(BotKey.right);
      }
      expect(os.home.page, 0);
      os.key(BotKey.left);
      expect(os.home.page, pages - 1);
    });

    test('launch opens an app directly, with Back leading somewhere sane', () {
      final os = boot()..launch(BotApp.dino);
      expect(os.top, isA<DinoGame>());
      os.key(BotKey.button);
      expect(os.top, isA<GamesScreen>());
    });
  });

  group('focus', () {
    const session = BotSession(
      name: 'Deep Work',
      remaining: Duration(minutes: 20),
      progress: 0.2,
      tracked: true,
      verified: true,
    );

    test('a block starting takes the screen, and ending gives it back', () {
      final os = boot();
      os.key(BotKey.button);
      os.tick(world(session: session));
      expect(os.top, isA<FocusScreen>());
      os.tick(world());
      expect(os.top, isA<HomeScreen>());
    });

    test('the next block takes the screen back, wherever you were', () {
      // A routine rolling on to its next block, or a new routine switched on
      // over a running one, must show on the bot, not only the first block.
      final os = boot();
      os.tick(
        world(
          session: const BotSession(
            key: 'a#0',
            name: 'Read',
            remaining: Duration(minutes: 5),
            progress: 0,
          ),
        ),
      );
      expect(os.top, isA<FocusScreen>());
      os.key(BotKey.button); // back to the face
      os.key(BotKey.button); // into the menu
      expect(os.top, isA<MenuScreen>());
      os.tick(
        world(
          session: const BotSession(
            key: 'a#0',
            name: 'Read',
            remaining: Duration(minutes: 4),
            progress: 0.2,
          ),
        ),
      );
      expect(os.top, isA<MenuScreen>(), reason: 'same block: leave it be');
      os.tick(
        world(
          session: const BotSession(
            key: 'b#1',
            name: 'Walk',
            remaining: Duration(minutes: 10),
            progress: 0,
          ),
        ),
      );
      expect(os.top, isA<FocusScreen>());
    });

    test('a running block is always one turn away on home', () {
      final os = boot()..tick(world(session: session));
      os.key(BotKey.button); // back to the face, block still running
      expect(os.top, isA<HomeScreen>());
      expect(os.home.current, HomePage.face);
      os.key(BotKey.left);
      os.tick(world(session: session));
      expect(os.home.current, HomePage.focus);
      os.key(BotKey.press);
      expect(os.top, isA<FocusScreen>());
    });

    test('the menu offers the running block first', () {
      final os = boot()..tick(world(session: session));
      os.key(BotKey.button);
      os.key(BotKey.button);
      os.key(BotKey.press);
      expect(os.top, isA<FocusScreen>());
    });

    test('pressing the knob pauses and resumes', () {
      final os = boot()..tick(world(session: session));
      os.takeEffects();
      os.key(BotKey.press);
      expect(os.takeEffects().whereType<PauseFocus>(), hasLength(1));
      os.tick(
        world(
          session: const BotSession(
            name: 'Deep Work',
            remaining: Duration(minutes: 20),
            progress: 0.2,
            paused: true,
          ),
        ),
      );
      os.key(BotKey.press);
      expect(os.takeEffects().whereType<ResumeFocus>(), hasLength(1));
    });

    test('the bot\'s own timer starts a block of the chosen length', () {
      final os = boot()..launch(BotApp.focusTimer);
      os.key(BotKey.right); // 25 -> 30
      os.key(BotKey.press);
      final start = os.takeEffects().whereType<StartFocus>().single;
      expect(start.minutes, 30);
    });
  });

  group('music', () {
    test('RTTTL parses to the notes tone() would play', () {
      final notes = Rtttl.parse('t:d=4,o=5,b=120:c,e,g,8p,2a4');
      expect(notes.map((n) => n.hz), <int>[523, 659, 784, 0, 440]);
      expect(notes.first.ms, 500);
      expect(notes[3].ms, 250);
      expect(notes.last.ms, 1000);
    });

    test('every shipped melody parses to real notes', () {
      for (final m in Melodies.all) {
        final notes = Rtttl.parse(m.rtttl);
        expect(notes.length, greaterThan(8), reason: m.title);
        expect(
          notes.every((n) => n.hz == 0 || (n.hz > 100 && n.hz < 5000)),
          isTrue,
          reason: m.title,
        );
      }
    });

    test('the buzzer wave is a valid WAV of the right length', () {
      final wav = Buzzer.tone(1000, 100);
      expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
      expect(String.fromCharCodes(wav.sublist(8, 12)), 'WAVE');
      expect(wav.length, 44 + Buzzer.rate * 100 ~/ 1000 * 2);
    });

    test('playing a tune asks for the melody and silence when left', () {
      final os = boot()..launch(BotApp.music, arg: 1);
      expect(os.takeEffects().whereType<PlayMelody>(), hasLength(1));
      os.key(BotKey.button);
      expect(os.takeEffects().whereType<StopSound>(), hasLength(1));
    });
  });

  group('the desk', () {
    test('counts how long you have sat, and a real break resets it', () {
      final os = boot();
      final t0 = DateTime(2026, 9, 27, 9);
      os.tick(BotWorld(now: t0, sensors: room));
      os.tick(
        BotWorld(now: t0.add(const Duration(minutes: 30)), sensors: room),
      );
      expect(os.sittingFor, const Duration(minutes: 30));
      // A minute away for water does not count as a break.
      os.tick(BotWorld(now: t0.add(const Duration(minutes: 31))));
      expect(os.sittingFor, isNotNull);
      os.tick(BotWorld(now: t0.add(const Duration(minutes: 35))));
      expect(os.sittingFor, isNull);
    });

    test('after 50 minutes the bot looks up and suggests a stretch', () {
      final os = boot();
      final t0 = DateTime(2026, 9, 27, 9);
      os.tick(BotWorld(now: t0, sensors: room));
      os.takeEffects();
      os.tick(
        BotWorld(now: t0.add(const Duration(minutes: 51)), sensors: room),
      );
      expect(os.showingFace, isTrue);
      expect(os.takeEffects().whereType<PlayTone>(), hasLength(1));
      expect(HomeScreen.sittingLabel(os.sittingFor), contains('stretch'));
    });

    test('a pet shows the face over the timer, then gives it back', () {
      const session = BotSession(
        name: 'Deep Work',
        remaining: Duration(minutes: 20),
        progress: 0.2,
      );
      final os = boot()..tick(world(session: session));
      expect(os.top, isA<FocusScreen>());
      os.key(BotKey.touchLeft);
      expect(os.showingFace, isTrue);
      for (var i = 0; i < BotOs.fps * 3; i++) {
        os.tick(world(session: session));
      }
      expect(os.showingFace, isFalse);
      expect(os.top, isA<FocusScreen>());
    });
  });

  group('music modes', () {
    test('play all moves on to the next tune by itself', () {
      final os = boot()..settings.playMode = PlayMode.all;
      os.launch(BotApp.music, arg: 1);
      expect(os.playingIndex, 0);
      final ms = Rtttl.lengthMs(Rtttl.parse(Melodies.all[0].rtttl));
      for (var i = 0; i < (ms + 500) * BotOs.fps ~/ 1000; i++) {
        os.tick(world());
      }
      expect(os.playingIndex, 1);
    });

    test('in an auto mode the music carries on after leaving the player', () {
      final os = boot()..settings.playMode = PlayMode.repeat;
      os.launch(BotApp.music, arg: 3);
      os.takeEffects();
      os.key(BotKey.button);
      expect(os.takeEffects().whereType<StopSound>(), isEmpty);
      expect(os.playing, isNotNull);
    });

    test('clicks stay quiet while a tune plays', () {
      final os = boot()..settings.playMode = PlayMode.all;
      os.launch(BotApp.music, arg: 1);
      os.key(BotKey.button);
      os.takeEffects();
      os.key(BotKey.right);
      expect(os.takeEffects().whereType<PlayTone>(), isEmpty);
    });

    test('the play mode survives a save', () {
      final s = BotSettings(playMode: PlayMode.shuffle);
      expect(BotSettings.fromMap(s.toMap()).playMode, PlayMode.shuffle);
    });
  });

  group('alarms', () {
    test('an alarm packs and unpacks to itself', () {
      final a = BotAlarm(on: true, hour: 5, minute: 45, tone: 3, days: 0x4F);
      final b = BotAlarm.unpack(a.pack());
      expect((b.on, b.hour, b.minute, b.tone, b.days), (true, 5, 45, 3, 0x4F));
    });

    test('rings at its minute, on its days, and a press stops it', () {
      final os = boot();
      os.settings.alarms[0] = BotAlarm(
        on: true,
        hour: 6,
        minute: 30,
        days: AlarmRepeat.everyDay,
      );
      os.tick(BotWorld(now: DateTime(2026, 9, 27, 6, 29, 58)));
      expect(os.top, isNot(isA<AlarmRingScreen>()));
      os.tick(BotWorld(now: DateTime(2026, 9, 27, 6, 30, 0)));
      expect(os.top, isA<AlarmRingScreen>());
      expect(
        os.takeEffects().whereType<PlayMelody>().where((m) => m.alarm),
        isNotEmpty,
      );
      os.key(BotKey.press);
      expect(os.top, isNot(isA<AlarmRingScreen>()));
      expect(os.snoozeUntil, isNull);
    });

    test('a touch snoozes it for five minutes', () {
      final os = boot();
      os.settings.alarms[0] = BotAlarm(
        on: true,
        hour: 7,
        minute: 0,
        days: AlarmRepeat.everyDay,
      );
      os.tick(BotWorld(now: DateTime(2026, 9, 27, 7, 0, 1)));
      os.key(BotKey.touchFront);
      expect(os.top, isNot(isA<AlarmRingScreen>()));
      os.tick(BotWorld(now: DateTime(2026, 9, 27, 7, 4, 59)));
      expect(os.top, isNot(isA<AlarmRingScreen>()));
      os.tick(BotWorld(now: DateTime(2026, 9, 27, 7, 5, 2)));
      expect(os.top, isA<AlarmRingScreen>());
    });

    test('a one-off alarm switches itself off after ringing', () {
      final os = boot();
      os.settings.alarms[2] = BotAlarm(on: true, hour: 14, minute: 0);
      os.tick(BotWorld(now: DateTime(2026, 9, 27, 14, 0, 0)));
      expect(os.top, isA<AlarmRingScreen>());
      expect(os.settings.alarms[2].on, isFalse);
    });

    test('skips days it is not set for', () {
      // 27 September 2026 is a Sunday.
      final a = BotAlarm(
        on: true,
        hour: 8,
        minute: 0,
        days: AlarmRepeat.monToFri,
      );
      expect(a.ringsAt(DateTime(2026, 9, 27, 8)), isFalse);
      expect(a.nextAfter(DateTime(2026, 9, 27, 9)), DateTime(2026, 9, 28, 8));
    });

    test('every tone parses to real notes', () {
      expect(AlarmTones.all.length, lessThanOrEqualTo(16), reason: '4 bits');
      for (final t in AlarmTones.all) {
        expect(Rtttl.parse(t.rtttl), isNotEmpty, reason: t.title);
      }
    });
  });

  group('games', () {
    test('every game survives a minute of button mashing', () {
      // Random keys for 1500 frames: nothing throws, and each one draws.
      for (final app in <BotApp>[
        BotApp.snake,
        BotApp.blocks,
        BotApp.flap,
        BotApp.paddle,
        BotApp.starRaid,
        BotApp.g2048,
        BotApp.dino,
        BotApp.breakout,
      ]) {
        final os = boot()..launch(app);
        final rnd = math.Random(app.index);
        final keys = <BotKey>[
          BotKey.left,
          BotKey.right,
          BotKey.press,
          BotKey.touchLeft,
          BotKey.touchRight,
          BotKey.touchFront,
        ];
        var drew = 0;
        for (var i = 0; i < 1500; i++) {
          if (rnd.nextInt(4) == 0) os.key(keys[rnd.nextInt(keys.length)]);
          os.tick(world());
          if (i % 100 == 0 && lit(os.gfx) > 20) drew++;
        }
        expect(drew, greaterThan(10), reason: app.name);
      }
    });

    test('Snake steers round in a loop with the knob and lives', () {
      final os = boot()..launch(BotApp.snake);
      final game = os.top as SnakeGame;
      os.key(BotKey.press); // start
      for (var i = 0; i < 400; i++) {
        // Circle in a small square: never hits a wall or itself.
        if (i % 24 == 0) os.key(BotKey.right);
        os.tick(world());
      }
      expect(os.top, same(game));
    });

    test('Blocks plays to the end and saves a score', () {
      final os = boot()..launch(BotApp.blocks);
      os.key(BotKey.press); // start
      // Hard-drop pieces until a line clears or the game ends.
      for (var i = 0; i < 300; i++) {
        os.key(i.isEven ? BotKey.left : BotKey.right);
        os.key(BotKey.left);
        os.key(BotKey.touchFront);
        os.tick(world());
      }
      expect(os.settings.best['blocks'], isNotNull);
    });

    test('Dino jumps on a tap and a crash saves the best score', () {
      final os = boot()..launch(BotApp.dino);
      os.key(BotKey.touchFront); // start
      for (var i = 0; i < 600; i++) {
        os.tick(world());
      }
      expect(
        os.settings.best['dino'],
        isNotNull,
        reason: 'with nobody jumping, a cactus ends the run',
      );
      expect(os.takeEffects().whereType<SaveSetting>(), isNotEmpty);
    });

    test('Reaction: tapping before the flash is too soon', () {
      final os = boot()..launch(BotApp.reaction);
      os.key(BotKey.touchFront);
      os.tick(world());
      os.key(BotKey.touchFront);
      os.tick(world());
      expect(lit(os.gfx), greaterThan(0));
      expect(os.settings.best['reaction'], isNull);
    });

    test('Reaction: the time is measured from the flash to the tap', () {
      final os = boot()..launch(BotApp.reaction);
      os.key(BotKey.touchFront);
      var t = now;
      // Tick until the screen flashes (the whole panel lights up).
      for (var i = 0; i < 200 && lit(os.gfx) < 6000; i++) {
        t = t.add(const Duration(milliseconds: 40));
        os.tick(BotWorld(now: t, sensors: room));
      }
      expect(lit(os.gfx), greaterThan(6000));
      os.key(BotKey.touchFront, at: t.add(const Duration(milliseconds: 212)));
      expect(os.settings.best['reaction'], 212);
    });
  });

  group('protocol', () {
    test('SENSORS round-trips, with missing sensors staying missing', () {
      const s = DeviceSensors(
        tempC: 28.45,
        humidity: 63.5,
        light: 612,
        distanceCm: 54,
        ir: 130,
        phoneParked: true,
        rtcTempC: 29,
      );
      final back = DeviceSensors.decode(s.encode());
      expect(back.tempC, closeTo(28.45, 0.01));
      expect(back.humidity, closeTo(63.5, 0.01));
      expect(back.light, 612);
      expect(back.distanceCm, 54);
      expect(back.phoneParked, isTrue);
      expect(back.rtcTempC, 29);

      final none = DeviceSensors.decode(const DeviceSensors().encode());
      expect(none.tempC, isNull);
      expect(none.humidity, isNull);
      expect(none.light, isNull);
      expect(none.distanceCm, isNull);
      expect(none.ir, isNull);
    });

    test('the simulated bot answers SENSOR_REQ and takes INPUT and LAUNCH', () {
      final dev = SimulatedDevice();
      final replies = <Frame>[];
      final parser = FrameParser();
      dev.onSend = (bytes) => replies.addAll(parser.feed(bytes));
      dev.receive(sensorReqFrame().encode());
      expect(replies.single.cmd, FfCmd.sensors);
      dev.receive(inputFrame(BotKey.press.wire).encode());
      dev.receive(launchFrame(BotApp.dino.wire).encode());
      expect(dev.inputs, <int>[BotKey.press.wire]);
      expect(dev.launched, (BotApp.dino.wire, 0));
    });
  });
}
