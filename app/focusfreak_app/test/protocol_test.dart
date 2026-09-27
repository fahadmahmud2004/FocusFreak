import 'package:flutter_test/flutter_test.dart';
import 'package:focusfreak_app/core/ff_constants.dart';
import 'package:focusfreak_app/device/crc8.dart';
import 'package:focusfreak_app/device/protocol.dart';

void main() {
  group('HELLO_ACK', () {
    test('decodes all 8 fields', () {
      final ack = HelloAck.decode(<int>[0x01, 1, 4, 7, 0x03, 0x01, 30, 16]);
      expect(ack.protoVersion, 0x01);
      expect(ack.firmwareVersion, '1.4');
      expect(ack.deviceId, 7);
      expect(ack.eepromLogDays, 30);
      expect(ack.maxBlocks, 16);
      expect(ack.versionMatches, isTrue);
    });

    test('round-trips through a frame', () {
      const ack = HelloAck(
        protoVersion: 1,
        fwMajor: 2,
        fwMinor: 3,
        deviceId: 9,
        capabilities: DeviceCapabilities(0xFF, 0x0F),
        eepromLogDays: 30,
        maxBlocks: 16,
      );
      final parsed = HelloAck.decode(ack.toFrame().payload);
      expect(parsed.capabilities, ack.capabilities);
      expect(parsed.fwMinor, 3);
    });

    test('rejects a wrong length rather than reading past the end', () {
      expect(
        () => HelloAck.decode(<int>[1, 2, 3, 4]),
        throwsA(isA<ProtocolException>()),
      );
    });

    test('a version mismatch is reported, not fatal', () {
      final ack = HelloAck.decode(<int>[0x02, 1, 0, 1, 0, 0, 30, 16]);
      expect(ack.versionMatches, isFalse);
    });

    test(
      'a device reporting zero capacity falls back to the documented one',
      () {
        final ack = HelloAck.decode(<int>[1, 1, 0, 1, 0, 0, 0, 0]);
        expect(ack.maxBlocks, FfFirmware.maxDeviceBlocks);
        expect(ack.eepromLogDays, FfFirmware.deviceLogDays);
      },
    );
  });

  group('capabilities', () {
    test('bit positions match §4', () {
      const caps = DeviceCapabilities(0x01 | 0x02, 0x02);
      expect(caps.has(DeviceCapability.presence), isTrue);
      expect(caps.has(DeviceCapability.dock), isTrue);
      expect(caps.has(DeviceCapability.light), isFalse);
      expect(caps.has(DeviceCapability.battery), isTrue);
      expect(caps.has(DeviceCapability.rtc), isFalse);
    });

    test('an absent capability is absent, never a failure', () {
      const none = DeviceCapabilities.none();
      expect(none.present, isEmpty);
      for (final c in DeviceCapability.values) {
        expect(none.has(c), isFalse);
      }
    });

    test('the BotOS bits decode from what was reserved in v1', () {
      // caps_hi bits 4..7 were reserved in v1 and now name the bot's controls
      // and sensor frame. An older app masks them away; this one reads them.
      const caps = DeviceCapabilities(0x01, 0xF0);
      expect(caps.present, <DeviceCapability>{
        DeviceCapability.presence,
        DeviceCapability.encoder,
        DeviceCapability.button,
        DeviceCapability.sensorFrame,
        DeviceCapability.botOs,
      });
    });

    test('of() builds the same mask it decodes', () {
      final caps = DeviceCapabilities.of(<DeviceCapability>{
        DeviceCapability.presence,
        DeviceCapability.battery,
      });
      expect(caps.lo, 0x01);
      expect(caps.hi, 0x02);
    });
  });

  group('Block', () {
    test('is exactly 48 bytes with the documented offsets', () {
      final bytes = WireBlock(
        name: 'Deep Work',
        description: 'Phone in the drawer',
        durationMin: 90,
        category: 0,
        trackEnabled: true,
        startMin: 330,
      ).encode();

      expect(bytes, hasLength(48));
      expect(bytes.sublist(0, 9), 'Deep Work'.codeUnits);
      expect(bytes[9], 0, reason: 'NUL padded, not terminated');
      expect(bytes[40] | (bytes[41] << 8), 90, reason: 'little-endian');
      expect(bytes[42], 0);
      expect(bytes[43], 0x01);
      expect(bytes[44] | (bytes[45] << 8), 330);
      expect(bytes.sublist(46), <int>[0, 0], reason: 'reserved must be 0');
    });

    test('round-trips', () {
      final block = WireBlock(
        name: 'Salat',
        description: 'Dhuhr',
        durationMin: 20,
        category: 3,
        startMin: FfFirmware.sequentialStartMin,
      );
      final back = WireBlock.decode(block.encode());
      expect(back.name, 'Salat');
      expect(back.description, 'Dhuhr');
      expect(back.durationMin, 20);
      expect(back.category, 3);
      expect(back.trackEnabled, isFalse);
      expect(back.isSequential, isTrue);
    });

    test('a name that exactly fills the field survives the round trip', () {
      // 16 chars means no NUL terminator on the wire. Reading to the width
      // rather than to a terminator is the only thing that gets this right.
      final block = WireBlock(
        name: 'ABCDEFGHIJKLMNOP',
        durationMin: 5,
        category: 1,
      );
      expect(WireBlock.decode(block.encode()).name, 'ABCDEFGHIJKLMNOP');
    });

    test('an over-long name throws rather than truncating silently', () {
      // The editor enforces the limit at input time. Reaching here is a bug,
      // and shipping a quietly-cut name to the device would hide it.
      expect(
        () => WireBlock(
          name: 'A really long block name',
          durationMin: 5,
          category: 0,
        ).encode(),
        throwsA(isA<ProtocolException>()),
      );
    });

    test('the 0x21 frame is 49 B: index then struct', () {
      final block = WireBlock(name: 'Nap', durationMin: 20, category: 4);
      final frame = block.toFrame(3);
      expect(frame.cmd, FfCmd.routineBlock);
      expect(frame.length, WireBlock.frameSize);

      final (idx, back) = WireBlock.fromFrame(frame.payload);
      expect(idx, 3);
      expect(back.name, 'Nap');
    });
  });

  group('STATUS', () {
    DeviceStatus decoded(int flags, {int batt = 0xFF}) => DeviceStatus.decode(
      <int>[2, 1, 0x2C, 0x01, 90, 0, 120, 0, 5, 3, flags, batt],
    );

    test('decodes the 12-byte layout', () {
      final s = decoded(0x1F);
      expect(s.state, DeviceRunState.running);
      expect(s.blockIdx, 1);
      expect(s.secsLeft, 300);
      expect(s.remaining, const Duration(minutes: 5));
      expect(s.verifiedToday, 90);
      expect(s.claimedToday, 120);
      expect(s.streak, 5);
      expect(s.mood, DeviceMood.happy);
    });

    test('flag bits map to the three channels plus the device verdict', () {
      final all = decoded(0x3F);
      expect(all.present, isTrue);
      expect(all.docked, isTrue);
      expect(all.phoneLocked, isTrue);
      expect(all.deviceVerified, isTrue);
      expect(all.trackEnabled, isTrue);
      expect(all.charging, isTrue);

      final none = decoded(0x00);
      expect(none.present, isFalse);
      expect(none.deviceVerified, isFalse);
    });

    test('the device verdict is carried, never recomputed', () {
      // Presence and dock hold but the device says unverified. The app must
      // report what the device said: a disagreement is a firmware bug worth
      // seeing rather than hiding.
      final odd = decoded(DeviceStatus.flagPresent | DeviceStatus.flagDocked);
      expect(odd.present, isTrue);
      expect(odd.docked, isTrue);
      expect(odd.deviceVerified, isFalse);
    });

    test('0xFF battery means no battery monitoring, not 255%', () {
      expect(decoded(0).battPct, isNull);
      expect(decoded(0, batt: 84).battPct, 84);
    });

    test('0xFF block index means nothing is active', () {
      final idle = DeviceStatus.decode(<int>[
        0,
        0xFF,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0xFF,
      ]);
      expect(idle.hasActiveBlock, isFalse);
      expect(idle.state, DeviceRunState.idle);
    });

    test('an out-of-range enum falls back rather than throwing', () {
      // Newer firmware, older app. Degrade, do not crash.
      final s = DeviceStatus.decode(<int>[
        99,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        99,
        0,
        0xFF,
      ]);
      expect(s.state, DeviceRunState.idle);
      expect(s.mood, DeviceMood.calm);
    });

    test('round-trips', () {
      final s = decoded(0x0D, batt: 42);
      expect(DeviceStatus.decode(s.encode()).flags, s.flags);
      expect(DeviceStatus.decode(s.encode()).battPct, 42);
    });
  });

  group('LOG_ENTRY', () {
    test('date_code counts days from 2026-01-01', () {
      expect(DeviceLogEntry.dateCodeFor(DateTime(2026, 1, 1)), 0);
      expect(DeviceLogEntry.dateCodeFor(DateTime(2026, 8, 2)), 213);

      const entry = DeviceLogEntry(
        dateCode: 213,
        verifiedMin: 240,
        claimedMin: 300,
        blocksDone: 6,
        blocksTotal: 8,
        violations: 2,
      );
      expect(entry.day, DateTime(2026, 8, 2));
      expect(DeviceLogEntry.decode(entry.encode()).verifiedMin, 240);
    });

    test('reserved bytes are zero', () {
      const entry = DeviceLogEntry(
        dateCode: 1,
        verifiedMin: 1,
        claimedMin: 1,
        blocksDone: 1,
        blocksTotal: 1,
        violations: 1,
      );
      expect(entry.encode().sublist(9), <int>[0, 0, 0]);
    });
  });

  group('CONFIG_SET', () {
    test('is type-length-value', () {
      final frame = configSetFrame(<ConfigKey, int>{
        ConfigKey.brightness: 200,
        ConfigKey.gracePausedS: 300,
      });
      expect(frame.payload, <int>[0x01, 1, 200, 0x06, 2, 0x2C, 0x01]);
      expect(decodeConfigSet(frame.payload), <ConfigKey, int>{
        ConfigKey.brightness: 200,
        ConfigKey.gracePausedS: 300,
      });
    });

    test('an unknown key is skipped by its own length', () {
      // The whole point of TLV: an older app must survive a newer key without
      // desynchronising on the keys it does understand.
      final wire = <int>[0x7F, 3, 1, 2, 3, 0x01, 1, 128];
      expect(decodeConfigSet(wire), <ConfigKey, int>{
        ConfigKey.brightness: 128,
      });
    });

    test('a truncated value is rejected', () {
      expect(
        () => decodeConfigSet(<int>[0x06, 2, 0x2C]),
        throwsA(isA<ProtocolException>()),
      );
    });
  });

  group('app → device frames', () {
    test('SET_TIME maps Sunday to 0', () {
      // Dart weekday is Mon=1..Sun=7; the DS3231 wants Sun=0..Sat=6.
      expect(setTimeFrame(DateTime(2026, 8, 2, 21, 5, 30)).payload, <int>[
        26,
        8,
        2,
        21,
        5,
        30,
        0,
      ]);
      expect(setTimeFrame(DateTime(2026, 8, 3)).payload.last, 1);
      expect(setTimeFrame(DateTime(2026, 8, 8)).payload.last, 6);
    });

    test('ROUTINE_BEGIN refuses more blocks than the device holds', () {
      expect(routineBeginFrame(16).payload, <int>[16]);
      expect(() => routineBeginFrame(17), throwsA(isA<ProtocolException>()));
    });

    test('ROUTINE_COMMIT carries a little-endian CRC-16 over the structs', () {
      final blocks = <WireBlock>[
        WireBlock(name: 'A', durationMin: 10, category: 0),
        WireBlock(name: 'B', durationMin: 20, category: 1),
      ];
      final expected = crc16Xmodem(<int>[
        for (final b in blocks) ...b.encode(),
      ]);
      final payload = routineCommitFrame(blocks).payload;
      expect(payload, hasLength(2));
      expect(payload[0] | (payload[1] << 8), expected);
    });

    test('LOG_REQ clamps to the device ring buffer', () {
      expect(logReqFrame(7).payload, <int>[7]);
      expect(logReqFrame(90).payload, <int>[FfFirmware.deviceLogDays]);
      expect(logReqFrame(0).payload, <int>[1]);
    });

    test('CONTROL carries action and arg', () {
      expect(controlFrame(ControlAction.pause).payload, <int>[0, 0]);
      expect(controlFrame(ControlAction.start, arg: 4).payload, <int>[4, 4]);
    });

    test('HEARTBEAT reports lock state and battery', () {
      expect(heartbeatFrame(screenLocked: true, battPct: 63).payload, <int>[
        1,
        63,
      ]);
      expect(heartbeatFrame(screenLocked: false).payload, <int>[0, 0xFF]);
    });
  });

  group('NACK', () {
    test('every reason survives the wire', () {
      for (final reason in NackReason.values) {
        expect(NackReason.fromWire(nackFrame(reason).payload.first), reason);
        expect(reason.message, isNotEmpty);
      }
    });

    test('an unknown reason decodes to null rather than throwing', () {
      expect(NackReason.fromWire(0x7F), isNull);
    });
  });

  group('command names', () {
    test('known commands are named and unknown ones are shown as hex', () {
      expect(FfCmd.name(FfCmd.helloAck), 'HELLO_ACK');
      expect(FfCmd.name(0x9E), '0x9e');
    });
  });
}
