/// Checksums shared with the firmware.
///
/// Written from `docs/PROTOCOL.md` §13. The C reference implementation is in
/// that section and the test vectors are asserted on both sides — if these two
/// functions and `proto.cpp` ever disagree, every frame on the link is rejected
/// and the device looks broken rather than mismatched.
library;

import 'dart:typed_data';

/// CRC-8, polynomial `0x07`, init `0x00`, no reflection, no final XOR.
///
/// Covers `CMD + LEN + PAYLOAD` of a frame — deliberately *not* the
/// `0xAA 0x55` preamble, so a resync that lands mid-frame cannot produce a
/// checksum that happens to pass.
int crc8(List<int> data) {
  var c = 0x00;
  for (final byte in data) {
    c ^= byte & 0xFF;
    for (var i = 0; i < 8; i++) {
      c = (c & 0x80) != 0 ? ((c << 1) ^ 0x07) & 0xFF : (c << 1) & 0xFF;
    }
  }
  return c;
}

/// CRC-16/XMODEM, polynomial `0x1021`, init `0x0000`.
///
/// Used by one thing only: `0x22 ROUTINE_COMMIT`, over the concatenated
/// 48-byte block structs in index order. A per-frame CRC8 catches a corrupt
/// byte; this catches a *missing block* — a push that lost frame 7 of 12 would
/// otherwise commit a routine with a hole in it.
int crc16Xmodem(List<int> data) {
  var crc = 0x0000;
  for (final byte in data) {
    crc ^= (byte & 0xFF) << 8;
    for (var i = 0; i < 8; i++) {
      crc = (crc & 0x8000) != 0
          ? ((crc << 1) ^ 0x1021) & 0xFFFF
          : (crc << 1) & 0xFFFF;
    }
  }
  return crc;
}

/// Hex dump in the format both logs use, so an app log and a Logcat `FF-WIRE`
/// line can be diffed literally. See `docs/PROTOCOL.md` §14.
String hexDump(List<int> bytes) =>
    bytes.map((b) => (b & 0xFF).toRadixString(16).padLeft(2, '0')).join(' ');

/// Parses a hex dump back into bytes. Test and simulator convenience.
Uint8List parseHex(String hex) => Uint8List.fromList(
  hex
      .split(RegExp(r'[\s,]+'))
      .where((s) => s.isNotEmpty)
      .map((s) => int.parse(s, radix: 16))
      .toList(growable: false),
);
