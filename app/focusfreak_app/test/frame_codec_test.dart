import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:focusfreak_app/device/crc8.dart';
import 'package:focusfreak_app/device/frame_codec.dart';

void main() {
  group('CRC8', () {
    // docs/PROTOCOL.md §13. These are asserted on the firmware side too; if
    // one of these fails the two implementations have diverged and every
    // frame on the link will be rejected.
    test('matches the protocol test vectors', () {
      expect(crc8(<int>[]), 0x00);
      expect(crc8(<int>[0x00]), 0x00);
      expect(crc8(<int>[0x01]), 0x07);
      expect(crc8('123456789'.codeUnits), 0xF4);
      expect(crc8(<int>[0x01, 0x00]), 0x15);
    });

    test('stays inside a byte for long inputs', () {
      final crc = crc8(List<int>.generate(512, (i) => i & 0xFF));
      expect(crc, inInclusiveRange(0, 255));
    });
  });

  group('CRC-16/XMODEM', () {
    test('matches the standard check value', () {
      expect(crc16Xmodem('123456789'.codeUnits), 0x31C3);
    });

    test('detects a missing block', () {
      final full = List<int>.generate(96, (i) => i & 0xFF);
      final short = full.sublist(0, 48);
      expect(crc16Xmodem(full), isNot(crc16Xmodem(short)));
    });
  });

  group('Frame encoding', () {
    test('lays out AA 55 CMD LEN PAYLOAD CRC', () {
      final bytes = Frame(0x01).encode();
      expect(bytes.sublist(0, 4), <int>[0xAA, 0x55, 0x01, 0x00]);
      expect(bytes.last, crc8(<int>[0x01, 0x00]));
      expect(bytes.length, 5);
    });

    test('the CRC excludes the preamble', () {
      final bytes = Frame(0x30, <int>[1, 2, 3]).encode();
      expect(bytes.last, crc8(<int>[0x30, 3, 1, 2, 3]));
      expect(bytes.last, isNot(crc8(bytes.sublist(0, bytes.length - 1))));
    });

    test('rejects a payload past the 64 B frame limit', () {
      expect(() => Frame(0x21, List<int>.filled(65, 0)), throwsArgumentError);
      expect(Frame(0x21, List<int>.filled(64, 0)).length, 64);
    });
  });

  group('FrameParser', () {
    test('round-trips a frame', () {
      final parser = FrameParser();
      final frames = parser.feed(Frame(0xB0, <int>[1, 2, 3]).encode());
      expect(frames, hasLength(1));
      expect(frames.single.cmd, 0xB0);
      expect(frames.single.payload, <int>[1, 2, 3]);
    });

    test('reassembles a frame split one byte per read', () {
      // A Bluetooth read boundary has nothing to do with a frame boundary.
      final parser = FrameParser();
      final wire = Frame(0xC0, List<int>.generate(12, (i) => i)).encode();
      final out = <Frame>[];
      for (final byte in wire) {
        out.addAll(parser.feed(<int>[byte]));
      }
      expect(out, hasLength(1));
      expect(out.single.payload, hasLength(12));
    });

    test('returns several frames from one chunk', () {
      final parser = FrameParser();
      final wire = <int>[
        ...Frame(0x01).encode(),
        ...Frame(0x30).encode(),
        ...Frame(0xB0, <int>[7]).encode(),
      ];
      expect(parser.feed(wire).map((f) => f.cmd), <int>[0x01, 0x30, 0xB0]);
    });

    test('drops a frame whose CRC does not match, then recovers', () {
      final drops = <FrameDropReason>[];
      final parser = FrameParser(onDrop: (r, _) => drops.add(r));

      final bad = Frame(0xB0, <int>[9]).encode();
      bad[bad.length - 1] ^= 0xFF;
      expect(parser.feed(bad), isEmpty);
      expect(drops, <FrameDropReason>[FrameDropReason.crcMismatch]);

      // The very next good frame must still arrive: one corrupt frame may not
      // wedge the link.
      expect(parser.feed(Frame(0x30).encode()), hasLength(1));
    });

    test('treats LEN > 64 as corruption and resyncs', () {
      final drops = <FrameDropReason>[];
      final parser = FrameParser(onDrop: (r, _) => drops.add(r));
      expect(parser.feed(<int>[0xAA, 0x55, 0x21, 200, 0, 0]), isEmpty);
      expect(drops, <FrameDropReason>[FrameDropReason.badLength]);
      expect(parser.feed(Frame(0x30).encode()), hasLength(1));
    });

    test('ignores noise before the preamble', () {
      final parser = FrameParser();
      final wire = <int>[0x00, 0xFF, 0x55, 0xAA, ...Frame(0x30).encode()];
      expect(parser.feed(wire), hasLength(1));
    });

    test('a doubled 0xAA still syncs', () {
      // AA AA 55 … is what a dropped byte looks like on the way in. Resetting
      // on the second 0xAA would throw away the frame that follows it.
      final parser = FrameParser();
      final good = Frame(0x30).encode();
      expect(parser.feed(<int>[0xAA, ...good]), hasLength(1));
    });

    test('resyncs after a 200 ms gap mid-frame', () {
      var now = DateTime(2026, 8, 2, 12);
      final drops = <FrameDropReason>[];
      final parser = FrameParser(
        clock: () => now,
        onDrop: (r, _) => drops.add(r),
      );

      final wire = Frame(0xB0, <int>[1, 2, 3]).encode();
      parser.feed(wire.sublist(0, 4)); // stops mid-frame
      expect(parser.isMidFrame, isTrue);

      now = now.add(const Duration(milliseconds: 250));
      expect(parser.resyncIfStale(), isTrue);
      expect(drops, <FrameDropReason>[FrameDropReason.interByteTimeout]);
      expect(parser.isMidFrame, isFalse);

      // And the parser is usable again, which is the point of the rule.
      expect(parser.feed(Frame(0x30).encode()), hasLength(1));
    });

    test('a gap shorter than the timeout does not resync', () {
      var now = DateTime(2026, 8, 2, 12);
      final parser = FrameParser(clock: () => now);
      final wire = Frame(0xB0, <int>[1, 2, 3]).encode();

      parser.feed(wire.sublist(0, 4));
      now = now.add(const Duration(milliseconds: 150));
      expect(parser.resyncIfStale(), isFalse);
      expect(parser.feed(wire.sublist(4)), hasLength(1));
    });

    test('feeding a stale byte expires the partial frame first', () {
      var now = DateTime(2026, 8, 2, 12);
      final parser = FrameParser(clock: () => now);
      parser.feed(Frame(0xB0, <int>[1, 2, 3]).encode().sublist(0, 4));

      now = now.add(const Duration(seconds: 1));
      expect(parser.feed(Frame(0x30).encode()), hasLength(1));
    });

    test('an unknown command still parses — dispatch decides, not framing', () {
      final parser = FrameParser();
      final frames = parser.feed(Frame(0x9E, <int>[1]).encode());
      expect(frames.single.cmd, 0x9E);
    });
  });

  group('hex helpers', () {
    test('round-trip', () {
      final bytes = Uint8List.fromList(<int>[0xAA, 0x55, 0x01, 0x00, 0x15]);
      expect(hexDump(bytes), 'aa 55 01 00 15');
      expect(parseHex('aa 55 01 00 15'), bytes);
    });
  });
}
