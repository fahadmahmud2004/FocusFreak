/// BotOS: the bot's firmware, written once in Dart.
///
/// The app runs it as the virtual bot, and it is the reference the Arduino
/// firmware is ported from: same screens, same controls, same pixels. It is
/// pure Dart with no clock of its own. The host calls [BotOs.tick] 25 times a
/// second with the world as it is (sensors, session, time), feeds it key
/// presses, reads [BotOs.gfx] to show the screen, and carries out the
/// [BotEffect]s it asks for (buzzer, focus timer, saved settings).
library;

import 'dart:math' as math;

import 'eyes.dart';
import 'gfx.dart';
import 'music.dart';
import 'screens.dart';
import 'world.dart';

export 'alarms.dart' show BotAlarm, AlarmRepeat;
export 'gfx.dart';
export 'world.dart';

/// What can be opened on the bot directly, from the app or the `0x72 LAUNCH`
/// command. The index is the wire value.
enum BotApp {
  home,
  menu,
  focusTimer,
  music,
  games,
  dino,
  breakout,
  reaction,
  room,
  settings,
  // Added after the first release. Appended, never inserted: the index is
  // the wire value of `0x72 LAUNCH`.
  snake,
  blocks,
  flap,
  paddle,
  starRaid,
  g2048,
  alarms;

  int get wire => index;

  static BotApp? fromWire(int v) =>
      v >= 0 && v < values.length ? values[v] : null;
}

/// How the music player moves on when a tune ends.
enum PlayMode {
  /// Play the one tune and stop.
  once('Once'),

  /// The same tune, over and over.
  repeat('Repeat'),

  /// Every tune in order, then round again, until stopped.
  all('Play all'),

  /// A random tune each time, until stopped.
  shuffle('Shuffle');

  const PlayMode(this.label);
  final String label;

  PlayMode get next => values[(index + 1) % values.length];

  /// Keeps playing after you leave the player.
  bool get continuous => this != once;
}

/// Saved preferences. Keys are stable strings so the app can persist them.
class BotSettings {
  BotSettings({
    this.sound = true,
    this.brightness = 2,
    this.faceHome = true,
    this.playMode = PlayMode.once,
    Map<String, int>? best,
    List<BotAlarm>? alarms,
  }) : best = best ?? <String, int>{},
       alarms = alarms ?? BotAlarm.defaults();

  bool sound;

  /// 0 low, 1 medium, 2 high.
  int brightness;

  /// Home opens on the face rather than the clock.
  bool faceHome;

  PlayMode playMode;

  /// Best score per game.
  final Map<String, int> best;

  /// The alarm slots. Always [BotAlarm.slots] long.
  final List<BotAlarm> alarms;

  static BotSettings fromMap(Map<String, int> m) => BotSettings(
    sound: (m['sound'] ?? 1) == 1,
    brightness: m['brightness'] ?? 2,
    faceHome: (m['faceHome'] ?? 1) == 1,
    playMode: PlayMode
        .values[(m['playMode'] ?? 0).clamp(0, PlayMode.values.length - 1)],
    best: <String, int>{
      for (final e in m.entries)
        if (e.key.startsWith('best.')) e.key.substring(5): e.value,
    },
    alarms: <BotAlarm>[
      for (var i = 0; i < BotAlarm.slots; i++)
        m['alarm$i'] == null
            ? BotAlarm.defaults()[i]
            : BotAlarm.unpack(m['alarm$i']!),
    ],
  );

  /// Everything, as the `key=value` pairs [fromMap] reads back.
  Map<String, int> toMap() => <String, int>{
    'sound': sound ? 1 : 0,
    'brightness': brightness,
    'faceHome': faceHome ? 1 : 0,
    'playMode': playMode.index,
    for (var i = 0; i < alarms.length; i++) 'alarm$i': alarms[i].pack(),
    for (final e in best.entries) 'best.${e.key}': e.value,
  };
}

class BotOs {
  BotOs({BotSettings? settings, math.Random? random})
    : settings = settings ?? BotSettings(),
      random = random ?? math.Random() {
    eyes = Eyes(random: this.random);
    home = HomeScreen(this);
    _stack.add(home);
    _world = BotWorld(now: DateTime.fromMillisecondsSinceEpoch(0));
  }

  final BotSettings settings;
  final math.Random random;
  final Gfx gfx = Gfx();
  late final Eyes eyes;
  late final HomeScreen home;

  final List<BotScreen> _stack = <BotScreen>[];
  final List<BotEffect> _effects = <BotEffect>[];
  late BotWorld _world;

  /// Frames since start, at 25 fps.
  int frame = 0;

  /// Last frame anyone touched a control or came near.
  int _lastActivity = 0;

  /// A pet or a poke shows the face for a moment over whatever is open, so
  /// touching the bot always gets a reaction, even over the timer.
  int _faceUntil = 0;
  bool get showingFace => frame < _faceUntil;
  bool _wasPresent = false;

  /// When you sat down, from the ultrasonic sensor. A minute or two away (a
  /// glass of water) does not reset it; a real break does.
  DateTime? sittingSince;
  DateTime? _lastSeen;
  int _nudges = 0;

  /// How long you have been at the desk, or null when you are not.
  Duration? get sittingFor {
    final since = sittingSince;
    return since == null ? null : _world.now.difference(since);
  }

  /// A stretch is suggested after this long sitting, and again each time.
  static const Duration sitNudge = Duration(minutes: 50);

  /// Away this long counts as a break.
  static const Duration breakAfter = Duration(minutes: 2);
  String? _sessionKey;

  /// What the buzzer is playing, for the visualiser and status icon.
  Melody? playing;

  /// Where [playing] sits in [Melodies.all], or -1 for anything else (a
  /// session chime, an alarm tone).
  int playingIndex = -1;

  /// Set while an alarm tone is sounding, so the player does not move on to
  /// the next tune after it.
  bool _alarmTone = false;

  /// The last minute the alarms were checked, so each rings once.
  int? _alarmMinute;

  /// When a snoozed alarm rings again, and which one it was.
  DateTime? snoozeUntil;
  int _snoozed = -1;
  List<Note> _notes = const <Note>[];
  int _playStart = 0;
  int _playLength = 0;

  static const int fps = 25;

  /// Five minutes of nobody: the face gets sleepy and the screen dims.
  static const int idleFrames = 5 * 60 * fps;

  BotWorld get world => _world;
  BotScreen get top => _stack.last;
  bool get idle => frame - _lastActivity > idleFrames;

  /// How bright the panel is, 0..1: the setting, lowered at night and when
  /// nobody has been around.
  double get brightness {
    var b = const <double>[0.45, 0.72, 1.0][settings.brightness.clamp(0, 2)];
    if (_world.sensors.dark) b *= 0.6;
    if (idle && _world.session == null) b *= 0.5;
    return b;
  }

  /// Everything asked for since the last call, in order.
  List<BotEffect> takeEffects() {
    final out = List<BotEffect>.of(_effects);
    _effects.clear();
    return out;
  }

  void emit(BotEffect e) => _effects.add(e);

  /// A soft click for a control, if sound is on.
  ///
  /// Silent while music plays: there is one buzzer, and a click on every
  /// detent would chop the tune into pieces.
  void click({int hz = 2600}) {
    if (settings.sound && playing == null) emit(PlayTone(hz, 12));
  }

  void playMelody(Melody m) {
    playing = m;
    playingIndex = Melodies.all.indexOf(m);
    _alarmTone = false;
    _notes = Rtttl.parse(m.rtttl);
    _playStart = frame;
    _playLength = Rtttl.lengthMs(_notes);
    if (settings.sound) emit(PlayMelody(m));
  }

  /// Rings [tone]. Always audible: an alarm that obeys the mute switch is
  /// one you sleep through.
  void playAlarmTone(Melody tone) {
    playing = tone;
    playingIndex = -1;
    _alarmTone = true;
    _notes = Rtttl.parse(tone.rtttl);
    _playStart = frame;
    _playLength = Rtttl.lengthMs(_notes);
    emit(PlayMelody(tone, alarm: true));
  }

  void stopMelody() {
    if (playing == null) return;
    playing = null;
    playingIndex = -1;
    _alarmTone = false;
    emit(const StopSound());
  }

  /// The tune after [from], by the play mode, or null to stop.
  int? nextTrack(int from) {
    final n = Melodies.all.length;
    if (from < 0 || n == 0) return null;
    return switch (settings.playMode) {
      PlayMode.once => null,
      PlayMode.repeat => from,
      PlayMode.all => (from + 1) % n,
      PlayMode.shuffle => n == 1 ? 0 : (from + 1 + random.nextInt(n - 1)) % n,
    };
  }

  /// Whether the alarm tone has finished its current pass.
  bool get alarmToneDone => playing == null || !_alarmTone;

  // --- alarms -----------------------------------------------------------------

  void saveAlarm(int slot) {
    emit(SaveSetting('alarm$slot', settings.alarms[slot].pack()));
  }

  void snooze(int slot, {Duration by = const Duration(minutes: 5)}) {
    snoozeUntil = _world.now.add(by);
    _snoozed = slot;
  }

  void _checkAlarms(DateTime now) {
    final snooze = snoozeUntil;
    if (snooze != null && !now.isBefore(snooze)) {
      snoozeUntil = null;
      _ring(_snoozed);
      return;
    }
    final minute = now.hour * 60 + now.minute;
    if (_alarmMinute == minute) return;
    final first = _alarmMinute == null;
    _alarmMinute = minute;
    // Opening the app at 07:00:40 must not ring the 07:00 alarm a second
    // time: it rang, or it was missed while the app was closed.
    if (first && now.second > 2) return;
    for (var i = 0; i < settings.alarms.length; i++) {
      final a = settings.alarms[i];
      if (!a.ringsAt(now)) continue;
      if (a.once) {
        a.on = false;
        saveAlarm(i);
      }
      _ring(i);
      return;
    }
  }

  void _ring(int slot) {
    if (slot < 0 || slot >= settings.alarms.length) return;
    _lastActivity = frame;
    if (top is AlarmRingScreen) pop();
    push(AlarmRingScreen(this, slot));
  }

  /// How far into the current melody, 0..1, and the note sounding now.
  (double, Note?) get playhead {
    if (playing == null || _playLength == 0) return (0, null);
    final ms = (frame - _playStart) * 1000 ~/ fps;
    var t = 0;
    for (final n in _notes) {
      if (ms < t + n.ms) return (ms / _playLength, n);
      t += n.ms;
    }
    return (1, null);
  }

  // --- navigation -------------------------------------------------------------

  void push(BotScreen s) {
    _stack.add(s);
    s.enter();
  }

  void pop() {
    if (_stack.length <= 1) return;
    _stack.removeLast().exit();
  }

  void popToHome() {
    while (_stack.length > 1) {
      _stack.removeLast().exit();
    }
  }

  void replace(BotScreen s) {
    if (_stack.length > 1) _stack.removeLast().exit();
    push(s);
  }

  /// Open something directly.
  void launch(BotApp app, {int arg = 0}) {
    _lastActivity = frame;
    popToHome();
    switch (app) {
      case BotApp.home:
        break;
      case BotApp.menu:
        push(MenuScreen(this));
      case BotApp.focusTimer:
        push(MenuScreen(this));
        push(TimerSetupScreen(this, minutes: arg > 0 ? arg : 25));
      case BotApp.music:
        push(MenuScreen(this));
        push(MusicScreen(this, autoplay: arg > 0 ? arg - 1 : null));
      case BotApp.games:
        push(MenuScreen(this));
        push(GamesScreen(this));
      case BotApp.dino:
        push(GamesScreen(this));
        push(DinoGame(this));
      case BotApp.breakout:
        push(GamesScreen(this));
        push(BreakoutGame(this));
      case BotApp.reaction:
        push(GamesScreen(this));
        push(ReactionGame(this));
      case BotApp.room:
        push(MenuScreen(this));
        push(RoomScreen(this));
      case BotApp.settings:
        push(MenuScreen(this));
        push(SettingsScreen(this));
      case BotApp.snake:
        push(GamesScreen(this));
        push(SnakeGame(this));
      case BotApp.blocks:
        push(GamesScreen(this));
        push(BlocksGame(this));
      case BotApp.flap:
        push(GamesScreen(this));
        push(FlapGame(this));
      case BotApp.paddle:
        push(GamesScreen(this));
        push(PaddleGame(this));
      case BotApp.starRaid:
        push(GamesScreen(this));
        push(StarRaidGame(this));
      case BotApp.g2048:
        push(GamesScreen(this));
        push(Game2048(this));
      case BotApp.alarms:
        push(MenuScreen(this));
        push(AlarmsScreen(this));
    }
  }

  // --- input ------------------------------------------------------------------

  /// When the last key arrived, as the host saw it. The reaction game needs
  /// better than a 40 ms frame.
  DateTime? lastKeyAt;

  void key(BotKey k, {DateTime? at}) {
    lastKeyAt = at;
    _lastActivity = frame;
    if (top.key(k)) return;
    switch (k) {
      case BotKey.button:
        click(hz: 1900);
        if (_stack.length == 1) {
          push(MenuScreen(this));
        } else {
          pop();
        }
      case BotKey.hold:
        click(hz: 1500);
        popToHome();
      case BotKey.touchLeft:
      case BotKey.touchRight:
        eyes.pet();
        _peek();
        if (settings.sound && playing == null) emit(const PlayTone(3200, 18));
      case BotKey.touchFront:
        eyes.poke();
        _peek();
        if (settings.sound && playing == null) emit(const PlayTone(1800, 22));
      case BotKey.left:
      case BotKey.right:
      case BotKey.press:
        break;
    }
  }

  void _trackSitting(BotWorld w) {
    final now = w.now;
    if (w.sensors.present) {
      sittingSince ??= now;
      _lastSeen = now;
    } else {
      final seen = _lastSeen;
      if (seen != null && now.difference(seen) > breakAfter) {
        sittingSince = null;
        _lastSeen = null;
        _nudges = 0;
      }
    }
    // A gentle nudge, never during a block you chose to sit through.
    final sat = sittingFor;
    if (sat == null || w.session != null) return;
    final due = sat.inMinutes ~/ sitNudge.inMinutes;
    if (due > _nudges) {
      _nudges = due;
      eyes.lookAt(0, -0.6, frames: 60);
      eyes.blink();
      _faceUntil = frame + fps * 3;
      if (settings.sound && playing == null) emit(const PlayTone(1320, 60));
    }
  }

  void _peek() {
    final onFace = top is HomeScreen && home.current == HomePage.face;
    if (!onFace) _faceUntil = frame + fps * 2 + fps ~/ 2;
  }

  // --- the frame --------------------------------------------------------------

  void tick(BotWorld w) {
    frame++;
    _world = w;

    // Someone sat down: wake up and look at them.
    final present = w.sensors.present;
    if (present && !_wasPresent) {
      _lastActivity = frame;
      eyes.lookAt(0, -0.5, frames: 50);
      eyes.blink();
    }
    if (present) _lastActivity = math.max(_lastActivity, frame - fps);
    _wasPresent = present;
    _trackSitting(w);

    // A block starting takes over the screen; one ending hands it back.
    // "Starting" means any change of block: the next one in a routine, or a
    // new routine switched on over a running one. Watching only for the
    // first block would leave the screen on whatever was open before.
    final session = w.session;
    final hasSession = session != null;
    final key = session == null
        ? null
        : session.key.isEmpty
        ? session.name
        : session.key;
    if (hasSession && key != _sessionKey && top is! AlarmRingScreen) {
      _lastActivity = frame;
      popToHome();
      push(FocusScreen(this));
    } else if (!hasSession && _sessionKey != null) {
      if (top is FocusScreen || top is FocusOptionsScreen) popToHome();
    }
    _sessionKey = key;

    _checkAlarms(w.now);

    final sleepy = idle && !hasSession || (w.sensors.dark && idle);
    eyes.setMood(sleepy ? BotMood.sleepy : w.mood);
    eyes.idle = !hasSession;
    eyes.update();

    if (playing != null) {
      final ms = (frame - _playStart) * 1000 ~/ fps;
      if (ms > _playLength + 300) {
        final next = _alarmTone ? null : nextTrack(playingIndex);
        if (next != null) {
          playMelody(Melodies.all[next]);
        } else {
          playing = null;
          playingIndex = -1;
          _alarmTone = false;
        }
      }
    }

    top.update(w);
    gfx.clear();
    gfx.color = 1;
    if (showingFace) {
      eyes.draw(gfx);
    } else {
      top.draw(gfx, w);
    }
  }
}
