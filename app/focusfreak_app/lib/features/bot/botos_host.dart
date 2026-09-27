import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../botos/buzzer.dart';
import '../../botos/music.dart';
import '../../botos/os.dart';
import '../../botos/routines.dart';
import '../../data/repo/settings_repository.dart';
import '../../device/protocol.dart';
import '../../domain/engine/session_engine.dart';
import '../../domain/model/session_state.dart';
import '../dashboard/today_providers.dart';
import '../device/device_controller.dart';
import '../sound/sound_cues.dart';
import '../timer/session_controller.dart';
import 'device_mirror.dart';

/// The room the virtual bot sits in.
///
/// Its sensors read this instead of pins. The Bot tab lets you change it, so
/// every reaction the real bot has (a warm room, a dark desk, someone leaving,
/// the phone picked up) can be seen before the hardware exists.
class VirtualRoom {
  const VirtualRoom({
    this.tempC = 28.4,
    this.humidity = 64,
    this.light = 620,
    this.distanceCm = 55,
    this.phoneParked = true,
  });

  final double tempC;
  final double humidity;
  final int light;

  /// Null when nobody is in front of the bot.
  final int? distanceCm;
  final bool phoneParked;

  bool get present => distanceCm != null && distanceCm! <= 90;

  VirtualRoom copyWith({
    double? tempC,
    double? humidity,
    int? light,
    int? distanceCm,
    bool clearDistance = false,
    bool? phoneParked,
  }) => VirtualRoom(
    tempC: tempC ?? this.tempC,
    humidity: humidity ?? this.humidity,
    light: light ?? this.light,
    distanceCm: clearDistance ? null : distanceCm ?? this.distanceCm,
    phoneParked: phoneParked ?? this.phoneParked,
  );
}

/// What the bot's sensors read, refreshed once a second: the virtual room, or
/// a connected bot's `0xB1 SENSORS`.
final botSensorsProvider = StateProvider<BotSensors>((_) => const BotSensors());

/// How long you have been at the desk, from the ultrasonic sensor; null when
/// you are not. Refreshed once a second.
final botSittingProvider = StateProvider<Duration?>((_) => null);

final virtualRoomProvider = StateProvider<VirtualRoom>(
  (_) => const VirtualRoom(),
);

/// One frame of the bot's screen, for the widgets that draw it.
class BotFrame {
  const BotFrame(this.pixels, this.brightness, this.frame, {this.live = false});

  /// 128 × 64, one byte per pixel.
  final Uint8List pixels;
  final double brightness;
  final int frame;

  /// Mirroring a connected bot rather than running the virtual one.
  final bool live;
}

/// Runs BotOS for the app: the virtual bot, and the local picture of a real
/// one.
///
/// 25 frames a second, the firmware's own rate. Each frame it builds the
/// world from the session, the room (or a connected bot's sensor frames) and
/// today's numbers, ticks BotOS, and publishes the screen. What BotOS asks for
/// comes back out as effects: buzzer sound on the phone's speaker, focus
/// blocks started and paused through the session controller, settings saved.
///
/// With a real bot connected, keys go to the bot as `0x71 INPUT` as well, so
/// the knob on the screen turns the knob on the desk.
class BotOsHost extends StateNotifier<BotFrame> {
  /// [run] false builds a host that never ticks on its own, for tests of
  /// the widgets that draw it.
  BotOsHost(this._ref, {bool run = true})
    : super(BotFrame(Uint8List(Gfx.width * Gfx.height), 1, 0)) {
    if (!run) return;
    _loadSettings();
    _ticker = Timer.periodic(
      const Duration(milliseconds: 1000 ~/ BotOs.fps),
      (_) => _tick(),
    );
    _sensorPoll = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _pollSensors(),
    );
  }

  final Ref _ref;
  final BotOs os = BotOs();
  Timer? _ticker;
  Timer? _sensorPoll;
  DeviceSensors? _deviceSensors;
  final math.Random _noise = math.Random();
  double _drift = 0;

  /// A real bot on the desk. The virtual bot is this BotOS itself, so while
  /// it is the one connected the phone plays the sound and runs the timer.
  bool get _live => _ref.read(realBotConnectedProvider);

  // --- input ------------------------------------------------------------------

  void key(BotKey k) {
    os.key(k, at: DateTime.now());
    if (_live) {
      unawaited(_ref.read(deviceControllerProvider.notifier).sendInput(k.wire));
    }
    _tick();
  }

  void launch(BotApp app, {int arg = 0}) {
    os.launch(app, arg: arg);
    if (_live) {
      unawaited(
        _ref.read(deviceControllerProvider.notifier).launch(app.wire, arg: arg),
      );
    }
    _tick();
  }

  // --- the frame --------------------------------------------------------------

  void _tick() {
    if (!mounted) return;
    final world = _world();
    os.tick(world);
    // The app's own screens read the sensors once a second, not 25 times.
    if (os.frame % BotOs.fps == 1) {
      _ref.read(botSensorsProvider.notifier).state = world.sensors;
      _ref.read(botSittingProvider.notifier).state = os.sittingFor;
    }
    for (final e in os.takeEffects()) {
      _apply(e);
    }
    state = BotFrame(
      Uint8List.fromList(os.gfx.pixels),
      os.brightness,
      os.frame,
      live: _live,
    );
  }

  BotWorld _world() {
    final now = DateTime.now();
    final live = _live;
    final session = _session(live);
    final mirror = _ref.read(botStateProvider);
    final seconds = _ref.read(todaySecondsProvider).valueOrNull;
    final streak = _ref.read(streakProvider).valueOrNull;

    return BotWorld(
      now: now,
      sensors: live ? _fromDevice(_deviceSensors) : _fromRoom(),
      session: session,
      mood: BotMood.values.byName(mirror.mood.name),
      linked: live,
      verifiedMinutesToday: (seconds?.verified ?? 0) ~/ 60,
      streak: streak?.current ?? 0,
    );
  }

  BotSession? _session(bool live) {
    if (live) {
      final b = _ref.read(botStateProvider);
      if (!b.sessionState.isActive || b.blockName.isEmpty) return null;
      return BotSession(
        key: '${b.blockName}|${b.nextBlockName}',
        name: b.blockName,
        description: b.blockDescription,
        remaining: b.remaining,
        progress: b.progress,
        paused: b.sessionState == SessionState.paused,
        armed: b.sessionState == SessionState.armed,
        tracked: b.trackEnabled,
        verified: b.verification.isVerified,
        nextName: b.nextBlockName,
      );
    }
    final s = _ref.read(sessionControllerProvider);
    final block = s.block;
    if (!s.isActive || block == null) return null;
    return BotSession(
      key: '${block.id}#${s.queueIndex}',
      name: block.name,
      description: block.description,
      remaining: s.remaining,
      progress: s.progress,
      paused: s.state == SessionState.paused,
      armed: s.state == SessionState.armed,
      tracked: block.trackEnabled,
      verified: s.verification.isVerified,
      nextName: s.nextBlock?.name,
      index: s.autoMode ? s.queueIndex + 1 : null,
      count: s.autoMode ? s.queue.length : null,
    );
  }

  /// The virtual room, with the small wander real sensors have. A reading that
  /// never moves looks dead.
  BotSensors _fromRoom() {
    final r = _ref.read(virtualRoomProvider);
    if (os.frame % 25 == 0) {
      _drift = (_drift + (_noise.nextDouble() - 0.5) * 0.08).clamp(-0.3, 0.3);
    }
    return BotSensors(
      tempC: r.tempC + _drift,
      humidity: r.humidity + _drift * 4,
      light: r.light,
      dark: r.light < 150,
      distanceCm: r.distanceCm,
      phoneParked: r.phoneParked,
      rtcTempC: r.tempC + 0.75,
    );
  }

  static BotSensors _fromDevice(DeviceSensors? d) => d == null
      ? const BotSensors()
      : BotSensors(
          tempC: d.tempC,
          humidity: d.humidity,
          light: d.light,
          dark: d.dark,
          distanceCm: d.distanceCm,
          phoneParked: d.ir == null ? null : d.phoneParked,
          rtcTempC: d.rtcTempC?.toDouble(),
        );

  Future<void> _pollSensors() async {
    if (!_live) {
      _deviceSensors = null;
      return;
    }
    _deviceSensors = await _ref
        .read(deviceControllerProvider.notifier)
        .readSensors();
  }

  // --- effects ----------------------------------------------------------------

  void _apply(BotEffect e) {
    final live = _live;
    final sound = _ref.read(soundOutputProvider);
    final session = _ref.read(sessionControllerProvider.notifier);
    switch (e) {
      // A real bot makes its own sound; the phone only voices the virtual one.
      case PlayMelody(:final melody, :final alarm):
        final wave = Buzzer.melody(
          Rtttl.parse(melody.rtttl),
          volume: alarm ? 0.3 : 0.22,
        );
        // Alarms live on the phone, so they ring with a bot connected too.
        if (alarm) {
          unawaited(sound.playAlarmWave(wave));
        } else if (!live) {
          unawaited(sound.playWave(wave));
        }
      case PlayTone(:final hz, :final ms):
        if (!live) unawaited(sound.playFx(Buzzer.tone(hz, ms)));
      case StopSound():
        unawaited(sound.stopWave());
        unawaited(sound.stopAlarm());
      // A real bot runs its own timer and tells the app through STATUS.
      case StartFocus(:final minutes):
        if (!live) {
          unawaited(
            session.startBlock(
              ActiveBlock(
                id: 'bot-${DateTime.now().millisecondsSinceEpoch}',
                name: 'Focus',
                category: 0,
                duration: Duration(minutes: minutes),
                trackEnabled: true,
              ),
            ),
          );
        }
      case StartRoutine(:final index):
        if (!live && index >= 0 && index < BotRoutines.keys.length) {
          unawaited(session.startTemplate(BotRoutines.all[index]));
        }
      case PauseFocus():
        if (!live) session.pause();
      case ResumeFocus():
        if (!live) session.resume();
      case SkipBlock():
        if (!live) unawaited(session.skip());
      case StopFocus():
        if (!live) unawaited(session.stop());
      case SaveSetting():
        unawaited(_saveSettings());
    }
  }

  // --- settings ---------------------------------------------------------------

  Future<void> _loadSettings() async {
    final raw = await _ref
        .read(settingsRepositoryProvider)
        .getString(SettingKey.botOsSettings);
    final map = <String, int>{};
    for (final pair in raw.split(';')) {
      final kv = pair.split('=');
      if (kv.length == 2) {
        final v = int.tryParse(kv[1]);
        if (v != null) map[kv[0]] = v;
      }
    }
    if (!mounted) return;
    if (map.isNotEmpty) {
      final loaded = BotSettings.fromMap(map);
      os.settings
        ..sound = loaded.sound
        ..brightness = loaded.brightness
        ..faceHome = loaded.faceHome
        ..playMode = loaded.playMode
        ..best.addAll(loaded.best);
      for (var i = 0; i < loaded.alarms.length; i++) {
        os.settings.alarms[i] = loaded.alarms[i];
      }
    }
    _publishAlarms();
  }

  Future<void> _saveSettings() async {
    _publishAlarms();
    final pairs = <String>[
      for (final e in os.settings.toMap().entries) '${e.key}=${e.value}',
    ];
    await _ref
        .read(settingsRepositoryProvider)
        .setString(SettingKey.botOsSettings, pairs.join(';'));
  }

  // --- alarms -----------------------------------------------------------------

  /// Changes one alarm from the app. The bot shows it at once.
  void setAlarm(int slot, BotAlarm alarm) {
    if (slot < 0 || slot >= os.settings.alarms.length) return;
    os.settings.alarms[slot] = alarm.copy();
    unawaited(_saveSettings());
  }

  /// Hear a tone, from the app's alarm editor.
  void previewAlarmTone(int tone) {
    if (tone < 0 || tone >= AlarmTones.all.length) return;
    os.playAlarmTone(AlarmTones.all[tone]);
    _tick();
  }

  void stopSound() {
    os.stopMelody();
    _tick();
  }

  void _publishAlarms() {
    if (!mounted) return;
    _ref.read(botAlarmsProvider.notifier).state = <BotAlarm>[
      for (final a in os.settings.alarms) a.copy(),
    ];
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _sensorPoll?.cancel();
    super.dispose();
  }
}

final botOsProvider = StateNotifierProvider<BotOsHost, BotFrame>(BotOsHost.new);

/// The alarm slots as last saved, for the app's alarm screen and the system
/// alarms that ring while the app is closed.
final botAlarmsProvider = StateProvider<List<BotAlarm>>(
  (_) => BotAlarm.defaults(),
);
