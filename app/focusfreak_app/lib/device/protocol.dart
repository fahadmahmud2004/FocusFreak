/// Typed messages for the FocusFreak wire protocol.
///
/// Written from `docs/PROTOCOL.md`, which is the contract. The firmware's
/// `proto.cpp` is written from the same document; neither side changes a byte
/// layout without changing that file in the same commit.
///
/// Everything here is pure Dart with no Flutter and no transport knowledge, so
/// the desktop simulator, the unit tests and the app all share one codec.
library;

import 'dart:convert';
import 'dart:typed_data';

import '../core/ff_constants.dart';
import 'crc8.dart';
import 'frame_codec.dart';

/// Command bytes, `docs/PROTOCOL.md` §3. Reply codes have the high bit set.
class FfCmd {
  const FfCmd._();

  // App → device.
  static const int hello = 0x01;
  static const int setTime = 0x10;
  static const int routineBegin = 0x20;
  static const int routineBlock = 0x21;
  static const int routineCommit = 0x22;
  static const int routineGet = 0x23;
  static const int statusReq = 0x30;
  static const int sensorReq = 0x31;
  static const int logReq = 0x40;
  static const int phoneHeartbeat = 0x50;
  static const int configSet = 0x60;
  static const int control = 0x70;
  static const int input = 0x71;
  static const int launch = 0x72;

  // Device → app.
  static const int helloAck = 0x81;
  static const int routineBlockReply = 0xA3;
  static const int status = 0xB0;
  static const int sensors = 0xB1;
  static const int logEntry = 0xC0;
  static const int nack = 0xE0;

  /// Human-readable name for the wire log. Unknown codes are rendered as hex
  /// rather than dropped from the log — an unrecognised command is exactly the
  /// thing you want to see in a trace.
  static String name(int cmd) => switch (cmd) {
    hello => 'HELLO',
    setTime => 'SET_TIME',
    routineBegin => 'ROUTINE_BEGIN',
    routineBlock => 'ROUTINE_BLOCK',
    routineCommit => 'ROUTINE_COMMIT',
    routineGet => 'ROUTINE_GET',
    statusReq => 'STATUS_REQ',
    sensorReq => 'SENSOR_REQ',
    sensors => 'SENSORS',
    input => 'INPUT',
    launch => 'LAUNCH',
    logReq => 'LOG_REQ',
    phoneHeartbeat => 'PHONE_HEARTBEAT',
    configSet => 'CONFIG_SET',
    control => 'CONTROL',
    helloAck => 'HELLO_ACK',
    routineBlockReply => 'ROUTINE_BLOCK(reply)',
    status => 'STATUS',
    logEntry => 'LOG_ENTRY',
    nack => 'NACK',
    _ => '0x${cmd.toRadixString(16).padLeft(2, '0')}',
  };
}

/// A frame that arrived but does not say what it claims to.
///
/// Thrown by the decoders and caught at the dispatch boundary: a malformed
/// frame is a logged, ignored event, never a crash. A phone that dies because
/// a bot sent a short packet is worse than a phone that says "that frame made
/// no sense".
class ProtocolException implements Exception {
  const ProtocolException(this.message);
  final String message;
  @override
  String toString() => 'ProtocolException: $message';
}

// ---------------------------------------------------------------------------
// §4 HELLO_ACK and capabilities
// ---------------------------------------------------------------------------

/// What a bot declares it has, `docs/PROTOCOL.md` §4.
///
/// A bit means **the sensor exists and its driver reported healthy at boot** —
/// not that the firmware was compiled with support for it. That distinction is
/// the whole reason the app can be honest about what it does not know.
enum DeviceCapability {
  presence(0, 0, 'Presence'),
  dock(0, 1, 'Dock'),
  light(0, 2, 'Light'),
  tempHum(0, 3, 'Temperature & humidity'),
  touch(0, 4, 'Touch'),
  ledRing(0, 5, 'LED ring'),
  servo(0, 6, 'Servo'),
  buzzer(0, 7, 'Buzzer'),
  rtc(1, 0, 'Clock'),
  battery(1, 1, 'Battery'),
  sound(1, 2, 'Sound'),
  touchscreen(1, 3, 'Touchscreen'),

  /// Rotary encoder with a push switch.
  encoder(1, 4, 'Rotary encoder'),

  /// A separate push button.
  button(1, 5, 'Button'),

  /// Answers `0x31 SENSOR_REQ` with `0xB1 SENSORS`.
  sensorFrame(1, 6, 'Sensor readings'),

  /// Runs BotOS screens and takes `0x71 INPUT` / `0x72 LAUNCH`.
  botOs(1, 7, 'BotOS');

  const DeviceCapability(this.byte, this.bit, this.label);

  /// 0 for `caps_lo`, 1 for `caps_hi`.
  final int byte;
  final int bit;
  final String label;
}

/// The capability bitmask, decoded.
///
/// The app **masks rather than compares**: reserved bits are zero today, and a
/// firmware that sets one later must not break an app built before it existed.
class DeviceCapabilities {
  const DeviceCapabilities(this.lo, this.hi);

  const DeviceCapabilities.none() : lo = 0, hi = 0;

  factory DeviceCapabilities.of(Iterable<DeviceCapability> caps) {
    var lo = 0;
    var hi = 0;
    for (final c in caps) {
      if (c.byte == 0) {
        lo |= 1 << c.bit;
      } else {
        hi |= 1 << c.bit;
      }
    }
    return DeviceCapabilities(lo, hi);
  }

  final int lo;
  final int hi;

  bool has(DeviceCapability cap) =>
      ((cap.byte == 0 ? lo : hi) & (1 << cap.bit)) != 0;

  Set<DeviceCapability> get present =>
      DeviceCapability.values.where(has).toSet();

  @override
  String toString() => present.map((c) => c.name).join(', ');

  @override
  bool operator ==(Object other) =>
      other is DeviceCapabilities && other.lo == lo && other.hi == hi;

  @override
  int get hashCode => Object.hash(lo, hi);
}

/// `0x81 HELLO_ACK`, 8 bytes. `docs/PROTOCOL.md` §4.
class HelloAck {
  const HelloAck({
    required this.protoVersion,
    required this.fwMajor,
    required this.fwMinor,
    required this.deviceId,
    required this.capabilities,
    required this.eepromLogDays,
    required this.maxBlocks,
  });

  /// The protocol version this app speaks. A mismatch is a banner, not a
  /// disconnect — both sides keep using the commands they share.
  static const int appProtoVersion = 0x01;

  final int protoVersion;
  final int fwMajor;
  final int fwMinor;
  final int deviceId;
  final DeviceCapabilities capabilities;
  final int eepromLogDays;
  final int maxBlocks;

  bool get versionMatches => protoVersion == appProtoVersion;

  String get firmwareVersion => '$fwMajor.$fwMinor';

  factory HelloAck.decode(List<int> p) {
    if (p.length != 8) {
      throw ProtocolException('HELLO_ACK is 8 B, got ${p.length}');
    }
    return HelloAck(
      protoVersion: p[0],
      fwMajor: p[1],
      fwMinor: p[2],
      deviceId: p[3],
      capabilities: DeviceCapabilities(p[4], p[5]),
      // A device that reports 0 is reporting nonsense; fall back to the
      // documented capacity rather than deciding the bot stores no logs.
      eepromLogDays: p[6] == 0 ? FfFirmware.deviceLogDays : p[6],
      maxBlocks: p[7] == 0 ? FfFirmware.maxDeviceBlocks : p[7],
    );
  }

  Uint8List encode() => Uint8List.fromList(<int>[
    protoVersion,
    fwMajor,
    fwMinor,
    deviceId,
    capabilities.lo,
    capabilities.hi,
    eepromLogDays,
    maxBlocks,
  ]);

  Frame toFrame() => Frame(FfCmd.helloAck, encode());
}

// ---------------------------------------------------------------------------
// §5 Block
// ---------------------------------------------------------------------------

/// A routine block in its 48-byte wire form. `docs/PROTOCOL.md` §5.
class WireBlock {
  WireBlock({
    required this.name,
    this.description = '',
    required this.durationMin,
    required this.category,
    this.trackEnabled = false,
    this.startMin = FfFirmware.sequentialStartMin,
  });

  static const int wireSize = 48;

  /// `name` + `desc` + the 1-byte index that `0x21` prefixes.
  static const int frameSize = 49;

  final String name;
  final String description;
  final int durationMin;
  final int category;
  final bool trackEnabled;

  /// Minutes since midnight, or [FfFirmware.sequentialStartMin].
  final int startMin;

  bool get isSequential => startMin == FfFirmware.sequentialStartMin;

  Uint8List encode() {
    final out = Uint8List(wireSize);
    _writeFixed(out, 0, name, FfFirmware.blockNameMaxChars, 'name');
    _writeFixed(out, 16, description, FfFirmware.blockDescMaxChars, 'desc');
    final view = ByteData.sublistView(out);
    view.setUint16(40, durationMin, Endian.little);
    out[42] = category & 0xFF;
    out[43] = trackEnabled ? 0x01 : 0x00;
    view.setUint16(44, startMin, Endian.little);
    view.setUint16(46, 0, Endian.little); // reserved, must be 0
    return out;
  }

  factory WireBlock.decode(List<int> p) {
    if (p.length != wireSize) {
      throw ProtocolException('Block is $wireSize B, got ${p.length}');
    }
    final bytes = Uint8List.fromList(p);
    final view = ByteData.sublistView(bytes);
    return WireBlock(
      name: _readFixed(bytes, 0, 16),
      description: _readFixed(bytes, 16, 24),
      durationMin: view.getUint16(40, Endian.little),
      category: bytes[42],
      trackEnabled: (bytes[43] & 0x01) != 0,
      startMin: view.getUint16(44, Endian.little),
    );
  }

  /// `0x21 ROUTINE_BLOCK`: a 1-byte index followed by the struct.
  Frame toFrame(int index) =>
      Frame(FfCmd.routineBlock, <int>[index & 0xFF, ...encode()]);

  /// Decodes a `0x21`/`0xA3` payload into its index and block.
  static (int index, WireBlock block) fromFrame(List<int> p) {
    if (p.length != frameSize) {
      throw ProtocolException('ROUTINE_BLOCK is $frameSize B, got ${p.length}');
    }
    return (p[0], WireBlock.decode(p.sublist(1)));
  }

  @override
  String toString() =>
      'WireBlock($name, ${durationMin}m, cat $category'
      '${trackEnabled ? ', tracked' : ''})';
}

/// Writes a NUL-padded fixed-width field.
///
/// Over-long strings **throw** rather than truncate. The editor enforces 16/24
/// characters at input time (`docs/PROTOCOL.md` §5), so reaching here with a
/// longer one is a bug, and silently shipping "Deep Work — Mathem" to the
/// device would hide it.
void _writeFixed(
  Uint8List out,
  int offset,
  String value,
  int width,
  String field,
) {
  final bytes = utf8.encode(value);
  if (bytes.length > width) {
    throw ProtocolException(
      '$field is ${bytes.length} B, the wire field holds $width',
    );
  }
  out.setRange(offset, offset + bytes.length, bytes);
}

/// Reads a NUL-padded fixed-width field. Not NUL-*terminated*: a name that
/// exactly fills the field has no terminator, so read to the width and trim.
String _readFixed(Uint8List bytes, int offset, int width) {
  var end = offset + width;
  while (end > offset && bytes[end - 1] == 0) {
    end--;
  }
  if (end == offset) return '';
  try {
    return utf8.decode(bytes.sublist(offset, end));
  } on FormatException {
    // A field cut mid-codepoint by a firmware that truncated bytes rather than
    // characters. Show what is readable instead of failing the whole frame.
    return utf8.decode(bytes.sublist(offset, end), allowMalformed: true);
  }
}

// ---------------------------------------------------------------------------
// §6 STATUS
// ---------------------------------------------------------------------------

/// The device's session state machine. Mirrors the firmware enum.
enum DeviceRunState {
  idle,
  armed,
  running,
  paused,
  complete,
  broken;

  static DeviceRunState fromWire(int v) =>
      v < DeviceRunState.values.length ? DeviceRunState.values[v] : idle;
}

/// The device's mood, `docs/PROTOCOL.md` §6. Same order as the firmware.
enum DeviceMood {
  calm,
  searching,
  sad,
  happy,
  sleepy;

  static DeviceMood fromWire(int v) =>
      v < DeviceMood.values.length ? DeviceMood.values[v] : calm;
}

/// `0xB0 STATUS`, 12 bytes. `docs/PROTOCOL.md` §6.
class DeviceStatus {
  const DeviceStatus({
    required this.state,
    required this.blockIdx,
    required this.secsLeft,
    required this.verifiedToday,
    required this.claimedToday,
    required this.streak,
    required this.mood,
    required this.flags,
    required this.battPct,
  });

  static const int wireSize = 12;
  static const int noBlock = 0xFF;

  // flags bits, §6.
  static const int flagPresent = 1 << 0;
  static const int flagDocked = 1 << 1;
  static const int flagPhoneLocked = 1 << 2;
  static const int flagVerified = 1 << 3;
  static const int flagTrackEnabled = 1 << 4;
  static const int flagCharging = 1 << 5;

  final DeviceRunState state;

  /// [noBlock] when nothing is active.
  final int blockIdx;
  final int secsLeft;
  final int verifiedToday;
  final int claimedToday;
  final int streak;
  final DeviceMood mood;
  final int flags;

  /// null when the device has no battery monitoring (`0xFF` on the wire).
  final int? battPct;

  bool get hasActiveBlock => blockIdx != noBlock;
  bool get present => (flags & flagPresent) != 0;
  bool get docked => (flags & flagDocked) != 0;
  bool get phoneLocked => (flags & flagPhoneLocked) != 0;
  bool get trackEnabled => (flags & flagTrackEnabled) != 0;
  bool get charging => (flags & flagCharging) != 0;

  /// The **device's own** verdict, bit 3.
  ///
  /// The app displays this alongside the three channel bits rather than
  /// recomputing it. If they ever disagree that is a firmware bug worth seeing
  /// rather than hiding (`docs/PROTOCOL.md` §6).
  bool get deviceVerified => (flags & flagVerified) != 0;

  Duration get remaining => Duration(seconds: secsLeft);

  factory DeviceStatus.decode(List<int> p) {
    if (p.length != wireSize) {
      throw ProtocolException('STATUS is $wireSize B, got ${p.length}');
    }
    final bytes = Uint8List.fromList(p);
    final view = ByteData.sublistView(bytes);
    return DeviceStatus(
      state: DeviceRunState.fromWire(bytes[0]),
      blockIdx: bytes[1],
      secsLeft: view.getUint16(2, Endian.little),
      verifiedToday: view.getUint16(4, Endian.little),
      claimedToday: view.getUint16(6, Endian.little),
      streak: bytes[8],
      mood: DeviceMood.fromWire(bytes[9]),
      flags: bytes[10],
      battPct: bytes[11] == 0xFF ? null : bytes[11],
    );
  }

  Uint8List encode() {
    final out = Uint8List(wireSize);
    final view = ByteData.sublistView(out);
    out[0] = state.index;
    out[1] = blockIdx & 0xFF;
    view.setUint16(2, secsLeft, Endian.little);
    view.setUint16(4, verifiedToday, Endian.little);
    view.setUint16(6, claimedToday, Endian.little);
    out[8] = streak & 0xFF;
    out[9] = mood.index;
    out[10] = flags & 0xFF;
    out[11] = battPct ?? 0xFF;
    return out;
  }

  Frame toFrame() => Frame(FfCmd.status, encode());
}

// ---------------------------------------------------------------------------
// §7 LOG_ENTRY
// ---------------------------------------------------------------------------

/// `0xC0 LOG_ENTRY`, 12 bytes. One day of the device's ring buffer.
///
/// The device holds 30 days; the phone is the permanent archive, so the app
/// pulls on every connect and merges by date.
class DeviceLogEntry {
  const DeviceLogEntry({
    required this.dateCode,
    required this.verifiedMin,
    required this.claimedMin,
    required this.blocksDone,
    required this.blocksTotal,
    required this.violations,
  });

  static const int wireSize = 12;

  /// `date_code` counts days from here. Fixed in the firmware.
  static final DateTime epoch = DateTime(2026, 1, 1);

  final int dateCode;
  final int verifiedMin;
  final int claimedMin;
  final int blocksDone;
  final int blocksTotal;
  final int violations;

  DateTime get day => epoch.add(Duration(days: dateCode));

  static int dateCodeFor(DateTime day) =>
      DateTime(day.year, day.month, day.day).difference(epoch).inDays;

  factory DeviceLogEntry.decode(List<int> p) {
    if (p.length != wireSize) {
      throw ProtocolException('LOG_ENTRY is $wireSize B, got ${p.length}');
    }
    final view = ByteData.sublistView(Uint8List.fromList(p));
    return DeviceLogEntry(
      dateCode: view.getUint16(0, Endian.little),
      verifiedMin: view.getUint16(2, Endian.little),
      claimedMin: view.getUint16(4, Endian.little),
      blocksDone: p[6],
      blocksTotal: p[7],
      violations: p[8],
    );
  }

  Uint8List encode() {
    final out = Uint8List(wireSize);
    final view = ByteData.sublistView(out);
    view.setUint16(0, dateCode, Endian.little);
    view.setUint16(2, verifiedMin, Endian.little);
    view.setUint16(4, claimedMin, Endian.little);
    out[6] = blocksDone & 0xFF;
    out[7] = blocksTotal & 0xFF;
    out[8] = violations & 0xFF;
    return out; // bytes 9..11 stay zero: reserved
  }

  Frame toFrame() => Frame(FfCmd.logEntry, encode());
}

// ---------------------------------------------------------------------------
// §8 CONFIG_SET
// ---------------------------------------------------------------------------

/// Config keys, `docs/PROTOCOL.md` §8. Type-length-value, so either side can
/// add a key without breaking the other: unknown keys are skipped using their
/// own length field.
enum ConfigKey {
  brightness(0x01, 1),
  soundEnabled(0x02, 1),
  presenceMinCm(0x03, 1),
  presenceMaxCm(0x04, 1),
  graceRunningS(0x05, 1),
  gracePausedS(0x06, 2),
  ledBrightness(0x07, 1),
  theme(0x08, 1);

  const ConfigKey(this.key, this.width);
  final int key;
  final int width;

  static ConfigKey? fromWire(int key) {
    for (final k in values) {
      if (k.key == key) return k;
    }
    return null;
  }
}

/// Builds a `0x60 CONFIG_SET` payload from a key→value map.
Frame configSetFrame(Map<ConfigKey, int> values) {
  final out = <int>[];
  for (final entry in values.entries) {
    final key = entry.key;
    out
      ..add(key.key)
      ..add(key.width);
    if (key.width == 1) {
      out.add(entry.value & 0xFF);
    } else {
      out
        ..add(entry.value & 0xFF)
        ..add((entry.value >> 8) & 0xFF);
    }
  }
  return Frame(FfCmd.configSet, out);
}

/// Decodes a `0x60` payload, skipping keys this build does not know.
///
/// Skipping by declared length rather than by an assumed width is the whole
/// point of TLV: an older app must survive a newer key without desynchronising
/// on the rest of the message.
Map<ConfigKey, int> decodeConfigSet(List<int> p) {
  final out = <ConfigKey, int>{};
  var i = 0;
  while (i + 1 < p.length) {
    final key = ConfigKey.fromWire(p[i]);
    final len = p[i + 1];
    if (i + 2 + len > p.length) {
      throw ProtocolException('CONFIG_SET truncated at byte $i');
    }
    if (key != null) {
      out[key] = len == 1 ? p[i + 2] : p[i + 2] | (p[i + 3] << 8);
    }
    i += 2 + len;
  }
  return out;
}

// ---------------------------------------------------------------------------
// §9 CONTROL, §10 NACK
// ---------------------------------------------------------------------------

/// `0x70 CONTROL` actions, `docs/PROTOCOL.md` §9.
enum ControlAction {
  pause(0),
  resume(1),
  skip(2),
  stop(3),
  start(4);

  const ControlAction(this.wire);
  final int wire;
}

/// `arg` is the block index for [ControlAction.start] and 0 otherwise.
Frame controlFrame(ControlAction action, {int arg = 0}) =>
    Frame(FfCmd.control, <int>[action.wire, arg & 0xFF]);

/// `0xE0 NACK` reason codes, `docs/PROTOCOL.md` §10.
enum NackReason {
  crcFail(0x01, 'Checksum failed'),
  badLength(0x02, 'Wrong length'),
  unknownCmd(0x03, 'Command not supported'),
  routineSequence(0x04, 'Blocks arrived without a begin'),
  routineCrc(0x05, 'Routine checksum did not match'),
  eepromWriteFail(0x06, 'The device could not save'),
  busy(0x07, 'The device is busy'),
  outOfRange(0x08, 'Value out of range');

  const NackReason(this.wire, this.message);
  final int wire;
  final String message;

  static NackReason? fromWire(int v) {
    for (final r in values) {
      if (r.wire == v) return r;
    }
    return null;
  }
}

Frame nackFrame(NackReason reason) => Frame(FfCmd.nack, <int>[reason.wire]);

// ---------------------------------------------------------------------------
// App → device frame builders
// ---------------------------------------------------------------------------

Frame helloFrame() => Frame(FfCmd.hello);

/// `0x10 SET_TIME`: `yy mm dd hh mm ss dow`.
///
/// The phone's clock is authoritative on connect — a DS3231 that drifted or
/// lost its coin cell would otherwise date every log entry wrongly, and the
/// bot has no other way to know.
Frame setTimeFrame(DateTime t) => Frame(FfCmd.setTime, <int>[
  t.year % 100,
  t.month,
  t.day,
  t.hour,
  t.minute,
  t.second,
  t.weekday % 7, // Dart: Mon=1..Sun=7. Wire: Sun=0..Sat=6.
]);

Frame routineBeginFrame(int blockCount) {
  if (blockCount < 0 || blockCount > FfFirmware.maxDeviceBlocks) {
    throw ProtocolException(
      'block count $blockCount exceeds the device\'s '
      '${FfFirmware.maxDeviceBlocks}',
    );
  }
  return Frame(FfCmd.routineBegin, <int>[blockCount]);
}

/// `0x22 ROUTINE_COMMIT`: CRC-16/XMODEM over the concatenated 48-byte structs
/// in index order.
Frame routineCommitFrame(List<WireBlock> blocks) {
  final all = <int>[for (final b in blocks) ...b.encode()];
  final crc = crc16Xmodem(all);
  return Frame(FfCmd.routineCommit, <int>[crc & 0xFF, (crc >> 8) & 0xFF]);
}

Frame routineGetFrame() => Frame(FfCmd.routineGet);

Frame statusReqFrame() => Frame(FfCmd.statusReq);

Frame sensorReqFrame() => Frame(FfCmd.sensorReq);

/// `0x71 INPUT`: press one of the bot's controls from the phone. The byte is
/// the BotOS key index (`lib/botos/world.dart` `BotKey`).
Frame inputFrame(int key) => Frame(FfCmd.input, <int>[key & 0xFF]);

/// `0x72 LAUNCH`: open a BotOS app (`BotApp` index) with one argument.
Frame launchFrame(int app, {int arg = 0}) =>
    Frame(FfCmd.launch, <int>[app & 0xFF, arg & 0xFF]);

/// `0xB1 SENSORS`, 12 bytes: what the bot's sensors read right now.
///
/// Every field has a "no reading" value, so a bot without a sensor says so
/// rather than sending a zero the app would believe (`docs/PROTOCOL.md` §6a).
class DeviceSensors {
  const DeviceSensors({
    this.tempC,
    this.humidity,
    this.light,
    this.distanceCm,
    this.ir,
    this.dark = false,
    this.phoneParked = false,
    this.rtcTempC,
  });

  static const int wireSize = 12;

  final double? tempC;
  final double? humidity;

  /// 0..1023.
  final int? light;
  final int? distanceCm;

  /// TCRT5000 raw, 0..1023: lower is closer.
  final int? ir;
  final bool dark;
  final bool phoneParked;
  final int? rtcTempC;

  factory DeviceSensors.decode(List<int> p) {
    if (p.length != wireSize) {
      throw ProtocolException('SENSORS is $wireSize B, got ${p.length}');
    }
    final bytes = Uint8List.fromList(p);
    final v = ByteData.sublistView(bytes);
    final temp = v.getInt16(0, Endian.little);
    final hum = v.getUint16(2, Endian.little);
    final light = v.getUint16(4, Endian.little);
    final dist = v.getUint16(6, Endian.little);
    final ir = v.getUint16(8, Endian.little);
    final rtc = v.getInt8(11);
    return DeviceSensors(
      tempC: temp == 0x7FFF ? null : temp / 100,
      humidity: hum == 0xFFFF ? null : hum / 10,
      light: light == 0xFFFF ? null : light,
      distanceCm: dist == 0xFFFF ? null : dist,
      ir: ir == 0xFFFF ? null : ir,
      dark: bytes[10] & 1 != 0,
      phoneParked: bytes[10] & 2 != 0,
      rtcTempC: rtc == 0x7F ? null : rtc,
    );
  }

  Uint8List encode() {
    final out = Uint8List(wireSize);
    final v = ByteData.sublistView(out);
    v.setInt16(
      0,
      tempC == null ? 0x7FFF : (tempC! * 100).round(),
      Endian.little,
    );
    v.setUint16(
      2,
      humidity == null ? 0xFFFF : (humidity! * 10).round(),
      Endian.little,
    );
    v.setUint16(4, light ?? 0xFFFF, Endian.little);
    v.setUint16(6, distanceCm ?? 0xFFFF, Endian.little);
    v.setUint16(8, ir ?? 0xFFFF, Endian.little);
    out[10] = (dark ? 1 : 0) | (phoneParked ? 2 : 0);
    v.setInt8(11, rtcTempC ?? 0x7F);
    return out;
  }

  Frame toFrame() => Frame(FfCmd.sensors, encode());
}

/// `0x40 LOG_REQ`: how many days, 1..30.
Frame logReqFrame(int days) {
  final clamped = days.clamp(1, FfFirmware.deviceLogDays);
  return Frame(FfCmd.logReq, <int>[clamped]);
}

/// `0x50 PHONE_HEARTBEAT`, sent every 10 s **and only while a tracked block is
/// running** — there is nothing to verify otherwise and the radio should stay
/// quiet. No heartbeat for 25 s and the device treats `phone_locked` as false.
Frame heartbeatFrame({required bool screenLocked, int battPct = 0xFF}) =>
    Frame(FfCmd.phoneHeartbeat, <int>[screenLocked ? 1 : 0, battPct & 0xFF]);
