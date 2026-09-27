/// A Dart model of the firmware, speaking the real wire protocol.
///
/// This exists so the whole device layer — connect flow, routine push, status
/// mirror, log merge, error handling — can be built and tested with no
/// hardware, and so app work and firmware work proceed in parallel rather than
/// serially. `manual-src.md` §6.2 calls that out as where three-person projects
/// lose the most time.
///
/// It is a *model*, not a mock: it parses real frames, replies with real
/// frames, enforces the same sequence rules, and NACKs the same way. The
/// desktop simulator (`tools/sim.py`) and [LoopbackTransport] both drive it.
library;

import 'dart:typed_data';

import '../core/ff_constants.dart';
import 'crc8.dart';
import 'frame_codec.dart';
import 'protocol.dart';

/// How the simulated bot behaves and what it claims to have.
class SimulatedDeviceConfig {
  const SimulatedDeviceConfig({
    this.protoVersion = HelloAck.appProtoVersion,
    this.fwMajor = 1,
    this.fwMinor = 0,
    this.deviceId = 1,
    this.capabilities = defaultCapabilities,
    this.maxBlocks = FfFirmware.maxDeviceBlocks,
    this.logDays = FfFirmware.deviceLogDays,
  });

  /// The built hardware: HC-SR04 presence, TCRT5000 IR dock, LDR, AHT21
  /// temp/humidity, TTP223 touch, WS2812B ring, SG90 servo, buzzer, DS3231
  /// RTC, and the TFT touchscreen. No battery gauge and no sound sensor — so
  /// the app must render neither.
  ///
  /// The parts are named here rather than described generically because this
  /// list and `buying-list-src.md` have to agree: "reed dock" sat here for a
  /// while against a build that has no reed switch and no magnet in it.
  static const DeviceCapabilities defaultCapabilities = DeviceCapabilities(
    // HC-SR04 presence, TCRT5000 phone spot, LDR, SHT21, 3 touch pads, buzzers.
    // The real firmware declares 0xDD (no phone spot, plus the SG90 ear);
    // this model keeps the dock so the dock paths stay covered by tests.
    0x9F,
    // DS3231 clock, rotary encoder, push button, sensor frame, BotOS.
    0xF1,
  );

  final int protoVersion;
  final int fwMajor;
  final int fwMinor;
  final int deviceId;
  final DeviceCapabilities capabilities;
  final int maxBlocks;
  final int logDays;
}

/// The firmware's behaviour, in Dart.
class SimulatedDevice {
  SimulatedDevice({
    SimulatedDeviceConfig config = const SimulatedDeviceConfig(),
    void Function(String direction, Frame frame)? onWire,
  }) : _config = config,
       _onWire = onWire {
    _parser = FrameParser(
      onDrop: (reason, detail) => _log('drop', '${reason.name} $detail'),
    );
  }

  final SimulatedDeviceConfig _config;
  final void Function(String, Frame)? _onWire;
  late final FrameParser _parser;

  /// Where replies go. The transport wires this to the app's receive stream.
  void Function(Uint8List bytes)? onSend;

  /// Trace hook, mirroring the firmware's `FF-WIRE` log.
  void Function(String tag, String message)? onLog;

  // -- Persistent state (the firmware's EEPROM) -------------------------------

  final List<WireBlock> _routine = <WireBlock>[];
  final List<DeviceLogEntry> _logs = <DeviceLogEntry>[];
  final Map<ConfigKey, int> config = <ConfigKey, int>{};

  /// Blocks received since `ROUTINE_BEGIN`, held in RAM.
  ///
  /// **Nothing is written to [_routine] until COMMIT verifies.** A half-written
  /// routine is a corrupt device whose only recovery is a factory reset, so the
  /// model enforces the same rule the firmware must (`docs/PROTOCOL.md` §12).
  List<WireBlock?>? _staging;

  // -- Live state -------------------------------------------------------------

  DeviceRunState runState = DeviceRunState.idle;
  int blockIdx = DeviceStatus.noBlock;
  int secsLeft = 0;
  int verifiedToday = 0;
  int claimedToday = 0;
  int streak = 0;
  DeviceMood mood = DeviceMood.calm;

  bool present = true;
  bool docked = true;
  bool phoneLocked = true;

  // The room, for `0xB1 SENSORS`.
  double tempC = 28.4;
  double humidity = 64;
  int light = 610;
  bool dark = false;
  int rtcTempC = 29;

  /// Keys pressed from the phone with `0x71 INPUT`, in order.
  final List<int> inputs = <int>[];

  /// The last `0x72 LAUNCH`, as (app, arg).
  (int, int)? launched;

  DeviceSensors get sensors => DeviceSensors(
    tempC: tempC,
    humidity: humidity,
    light: light,
    distanceCm: present ? 55 : null,
    ir: docked ? 140 : 880,
    dark: dark,
    phoneParked: docked,
    rtcTempC: rtcTempC,
  );
  DateTime? lastHeartbeatAt;
  DateTime? deviceTime;

  List<WireBlock> get routine => List<WireBlock>.unmodifiable(_routine);

  void seedLogs(Iterable<DeviceLogEntry> entries) {
    _logs
      ..clear()
      ..addAll(entries);
  }

  void seedRoutine(Iterable<WireBlock> blocks) {
    _routine
      ..clear()
      ..addAll(blocks);
  }

  /// True when every factor the device can actually measure is holding.
  ///
  /// A capability the bot does not have is never counted — neither for nor
  /// against. That is the same three-state rule the app uses, enforced on the
  /// device side so the two verdicts can be compared honestly.
  bool get verified {
    final caps = _config.capabilities;
    if (!trackEnabled) return false;
    var any = false;
    if (caps.has(DeviceCapability.presence)) {
      any = true;
      if (!present) return false;
    }
    if (caps.has(DeviceCapability.dock)) {
      any = true;
      if (!docked) return false;
    }
    if (lastHeartbeatAt != null) {
      any = true;
      if (!phoneLocked) return false;
    }
    return any;
  }

  bool get trackEnabled =>
      runState == DeviceRunState.running &&
      blockIdx != DeviceStatus.noBlock &&
      blockIdx < _routine.length &&
      _routine[blockIdx].trackEnabled;

  DeviceStatus get status => DeviceStatus(
    state: runState,
    blockIdx: blockIdx,
    secsLeft: secsLeft,
    verifiedToday: verifiedToday,
    claimedToday: claimedToday,
    streak: streak,
    mood: mood,
    flags:
        (present ? DeviceStatus.flagPresent : 0) |
        (docked ? DeviceStatus.flagDocked : 0) |
        (phoneLocked ? DeviceStatus.flagPhoneLocked : 0) |
        (verified ? DeviceStatus.flagVerified : 0) |
        (trackEnabled ? DeviceStatus.flagTrackEnabled : 0),
    // No battery gauge in the build, so the device reports "unknown"
    // rather than a made-up percentage.
    battPct: _config.capabilities.has(DeviceCapability.battery) ? 100 : null,
  );

  // -- Receive ----------------------------------------------------------------

  /// Feeds bytes from the app. Chunk boundaries are arbitrary.
  void receive(List<int> bytes) {
    for (final frame in _parser.feed(bytes)) {
      _onWire?.call('A→D', frame);
      _dispatch(frame);
    }
  }

  void _dispatch(Frame f) {
    switch (f.cmd) {
      case FfCmd.hello:
        _reply(
          HelloAck(
            protoVersion: _config.protoVersion,
            fwMajor: _config.fwMajor,
            fwMinor: _config.fwMinor,
            deviceId: _config.deviceId,
            capabilities: _config.capabilities,
            eepromLogDays: _config.logDays,
            maxBlocks: _config.maxBlocks,
          ).toFrame(),
        );

      case FfCmd.setTime:
        if (f.length != 7) return _nack(NackReason.badLength);
        final p = f.payload;
        deviceTime = DateTime(2000 + p[0], p[1], p[2], p[3], p[4], p[5]);

      case FfCmd.routineBegin:
        if (f.length != 1) return _nack(NackReason.badLength);
        final n = f.payload[0];
        if (n > _config.maxBlocks) return _nack(NackReason.outOfRange);
        _staging = List<WireBlock?>.filled(n, null);

      case FfCmd.routineBlock:
        final staging = _staging;
        if (staging == null) return _nack(NackReason.routineSequence);
        if (f.length != WireBlock.frameSize) {
          return _nack(NackReason.badLength);
        }
        final (idx, block) = WireBlock.fromFrame(f.payload);
        if (idx >= staging.length) return _nack(NackReason.outOfRange);
        staging[idx] = block;

      case FfCmd.routineCommit:
        final staging = _staging;
        if (staging == null || f.length != 2) {
          return _nack(
            staging == null ? NackReason.routineSequence : NackReason.badLength,
          );
        }
        final want = f.payload[0] | (f.payload[1] << 8);
        // A block that never arrived cannot be checksummed, so a gap fails
        // here rather than silently committing a routine with a hole in it.
        if (staging.any((b) => b == null)) return _nack(NackReason.routineCrc);
        final blocks = staging.cast<WireBlock>();
        final got = crc16Xmodem(<int>[for (final b in blocks) ...b.encode()]);
        if (got != want) return _nack(NackReason.routineCrc);
        _routine
          ..clear()
          ..addAll(blocks);
        _staging = null;
        _log('eeprom', 'committed ${blocks.length} blocks');
        _reply(status.toFrame());

      case FfCmd.routineGet:
        for (var i = 0; i < _routine.length; i++) {
          _reply(
            Frame(FfCmd.routineBlockReply, <int>[i, ..._routine[i].encode()]),
          );
        }

      case FfCmd.statusReq:
        _reply(status.toFrame());

      case FfCmd.sensorReq:
        _reply(sensors.toFrame());

      case FfCmd.input:
        if (f.length != 1) return _nack(NackReason.badLength);
        inputs.add(f.payload[0]);

      case FfCmd.launch:
        if (f.length != 2) return _nack(NackReason.badLength);
        launched = (f.payload[0], f.payload[1]);

      case FfCmd.logReq:
        if (f.length != 1) return _nack(NackReason.badLength);
        final days = f.payload[0].clamp(1, _config.logDays);
        final take = _logs.length < days ? _logs.length : days;
        for (final entry in _logs.sublist(_logs.length - take)) {
          _reply(entry.toFrame());
        }

      case FfCmd.phoneHeartbeat:
        if (f.length != 2) return _nack(NackReason.badLength);
        phoneLocked = f.payload[0] != 0;
        lastHeartbeatAt = deviceTime ?? DateTime.now();

      case FfCmd.configSet:
        config.addAll(decodeConfigSet(f.payload));

      case FfCmd.control:
        if (f.length != 2) return _nack(NackReason.badLength);
        _control(f.payload[0], f.payload[1]);
        _reply(status.toFrame());

      default:
        // Forward compatibility: an unknown command is logged and ignored,
        // never an error. The NACK is informational — a newer app talking to
        // older firmware degrades instead of failing (`docs/PROTOCOL.md` §2).
        _log('rx', 'unknown cmd ${FfCmd.name(f.cmd)}, ignored');
        _nack(NackReason.unknownCmd);
    }
  }

  void _control(int action, int arg) {
    switch (action) {
      case 0: // pause
        if (runState == DeviceRunState.running) {
          runState = DeviceRunState.paused;
          mood = DeviceMood.searching;
        }
      case 1: // resume
        if (runState == DeviceRunState.paused) {
          runState = DeviceRunState.running;
          mood = DeviceMood.calm;
        }
      case 2: // skip
        _startBlock(blockIdx + 1);
      case 3: // stop
        runState = DeviceRunState.idle;
        blockIdx = DeviceStatus.noBlock;
        secsLeft = 0;
        mood = DeviceMood.calm;
      case 4: // start
        _startBlock(arg);
      default:
        _log('rx', 'unknown control action $action, ignored');
    }
  }

  void _startBlock(int index) {
    if (index < 0 || index >= _routine.length) {
      runState = DeviceRunState.complete;
      blockIdx = DeviceStatus.noBlock;
      secsLeft = 0;
      return;
    }
    blockIdx = index;
    secsLeft = _routine[index].durationMin * 60;
    runState = DeviceRunState.running;
    mood = DeviceMood.calm;
  }

  // -- Time -------------------------------------------------------------------

  /// Advances the simulated clock. Drive this from a timer for a live demo, or
  /// call it directly in tests.
  void advance(Duration by) {
    var seconds = by.inSeconds;
    while (seconds > 0 && runState == DeviceRunState.running) {
      final step = seconds < secsLeft ? seconds : secsLeft;
      secsLeft -= step;
      seconds -= step;
      if (trackEnabled) {
        claimedToday += step ~/ 60;
        if (verified) verifiedToday += step ~/ 60;
      }
      if (secsLeft == 0) _startBlock(blockIdx + 1);
    }
    deviceTime = (deviceTime ?? DateTime.now()).add(by);
  }

  // -- Send -------------------------------------------------------------------

  void _reply(Frame f) {
    _onWire?.call('D→A', f);
    onSend?.call(f.encode());
  }

  void _nack(NackReason reason) {
    _log('tx', 'NACK ${reason.name}');
    _reply(nackFrame(reason));
  }

  void _log(String tag, String message) => onLog?.call(tag, message);
}
