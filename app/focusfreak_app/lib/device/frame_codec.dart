/// The wire frame and its receive state machine.
///
/// Written from `docs/PROTOCOL.md` §2. Pure Dart, no Flutter, no transport
/// knowledge: the same parser runs over Bluetooth Classic, over TCP to the
/// desktop simulator, and over the in-process loopback.
library;

import 'dart:typed_data';

import 'crc8.dart';

/// Frame preamble. Two bytes, because one is not enough — `0xAA` alone occurs
/// often enough in packed little-endian payloads to cause false starts.
const int kPreamble0 = 0xAA;
const int kPreamble1 = 0x55;

/// `LEN` is a single byte but the firmware's receive buffer is 64 B. Anything
/// larger is corruption, not a long frame.
const int kMaxPayload = 64;

/// A byte gap this long anywhere past the preamble means the sender died
/// mid-frame. Without this rule one corrupt byte wedges the parser until a
/// power cycle, and the link merely *looks* dead. See `docs/PROTOCOL.md` §2.
const Duration kInterByteTimeout = Duration(milliseconds: 200);

/// One protocol frame: a command byte and its payload.
///
/// The preamble and CRC exist only on the wire; nothing above this class ever
/// sees them.
class Frame {
  Frame(this.cmd, [List<int>? payload])
    : payload = Uint8List.fromList(payload ?? const <int>[]) {
    if (this.payload.length > kMaxPayload) {
      throw ArgumentError.value(
        this.payload.length,
        'payload',
        'exceeds the $kMaxPayload B frame limit',
      );
    }
  }

  final int cmd;
  final Uint8List payload;

  int get length => payload.length;

  /// Serialises to `AA 55 CMD LEN PAYLOAD CRC8`.
  Uint8List encode() {
    final out = Uint8List(5 + payload.length);
    out[0] = kPreamble0;
    out[1] = kPreamble1;
    out[2] = cmd & 0xFF;
    out[3] = payload.length;
    out.setRange(4, 4 + payload.length, payload);
    out[out.length - 1] = crc8(out.sublist(2, out.length - 1));
    return out;
  }

  @override
  String toString() =>
      'Frame(0x${cmd.toRadixString(16).padLeft(2, '0')}, '
      '${payload.length} B${payload.isEmpty ? '' : ': ${hexDump(payload)}'})';

  @override
  bool operator ==(Object other) {
    if (other is! Frame || other.cmd != cmd || other.length != length) {
      return false;
    }
    for (var i = 0; i < length; i++) {
      if (other.payload[i] != payload[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(cmd, Object.hashAll(payload));
}

/// Why a partially-received frame was thrown away.
///
/// These are surfaced rather than swallowed: a link that silently drops one
/// frame in fifty is the hardest kind of bug to find at 2 a.m. in week 4.
enum FrameDropReason {
  /// `LEN` exceeded [kMaxPayload].
  badLength,

  /// The trailing CRC8 did not match the computed one.
  crcMismatch,

  /// No byte arrived for [kInterByteTimeout] while mid-frame.
  interByteTimeout,
}

enum _RxState { waitAa, wait55, readCmd, readLen, readPayload, readCrc }

/// The receive state machine from `docs/PROTOCOL.md` §2.
///
/// Synchronous by design — [feed] returns the frames that chunk completed —
/// so tests can drive it byte by byte without a fake clock or an event loop.
/// Framing is the layer where a heisenbug costs the most, so it is the layer
/// that gets to be boring.
class FrameParser {
  FrameParser({
    DateTime Function()? clock,
    void Function(FrameDropReason reason, String detail)? onDrop,
  }) : _clock = clock ?? DateTime.now,
       _onDrop = onDrop;

  final DateTime Function() _clock;
  final void Function(FrameDropReason, String)? _onDrop;

  _RxState _state = _RxState.waitAa;
  int _cmd = 0;
  int _len = 0;
  final List<int> _payload = <int>[];
  DateTime? _lastByteAt;

  /// True while a frame is partially received. Exposed for the resync timer.
  bool get isMidFrame => _state != _RxState.waitAa;

  /// Feeds received bytes and returns whatever frames they completed.
  ///
  /// A chunk may complete none, one, or several frames — a Bluetooth read
  /// boundary has nothing to do with a frame boundary, and assuming otherwise
  /// is the classic serial-parser bug.
  List<Frame> feed(List<int> bytes) {
    final out = <Frame>[];
    for (final raw in bytes) {
      final now = _clock();
      _expireIfStale(now);
      _lastByteAt = now;

      final byte = raw & 0xFF;
      switch (_state) {
        case _RxState.waitAa:
          if (byte == kPreamble0) _state = _RxState.wait55;
        case _RxState.wait55:
          // A second 0xAA keeps us waiting for 0x55 rather than resetting:
          // `AA AA 55 …` is a legitimate resync after a dropped byte.
          if (byte == kPreamble1) {
            _state = _RxState.readCmd;
          } else if (byte != kPreamble0) {
            _state = _RxState.waitAa;
          }
        case _RxState.readCmd:
          _cmd = byte;
          _state = _RxState.readLen;
        case _RxState.readLen:
          if (byte > kMaxPayload) {
            _drop(FrameDropReason.badLength, 'LEN=$byte');
            break;
          }
          _len = byte;
          _payload.clear();
          _state = _len == 0 ? _RxState.readCrc : _RxState.readPayload;
        case _RxState.readPayload:
          _payload.add(byte);
          if (_payload.length == _len) _state = _RxState.readCrc;
        case _RxState.readCrc:
          final expected = crc8(<int>[_cmd, _len, ..._payload]);
          if (byte == expected) {
            out.add(Frame(_cmd, List<int>.of(_payload)));
            _reset();
          } else {
            _drop(
              FrameDropReason.crcMismatch,
              'cmd=0x${_cmd.toRadixString(16)} '
              'got=0x${byte.toRadixString(16)} '
              'want=0x${expected.toRadixString(16)}',
            );
          }
      }
    }
    return out;
  }

  /// Resets the parser if it has been stuck mid-frame past the timeout.
  ///
  /// [feed] applies the same rule per byte, but a sender that dies mid-frame
  /// sends no further bytes to trigger it. Drive this from a periodic timer so
  /// the parser recovers on its own rather than waiting for traffic.
  bool resyncIfStale([DateTime? now]) => _expireIfStale(now ?? _clock());

  bool _expireIfStale(DateTime now) {
    final last = _lastByteAt;
    if (last == null || _state == _RxState.waitAa) return false;
    if (now.difference(last) < kInterByteTimeout) return false;
    _drop(
      FrameDropReason.interByteTimeout,
      '${now.difference(last).inMilliseconds} ms mid-frame',
    );
    return true;
  }

  void _drop(FrameDropReason reason, String detail) {
    _onDrop?.call(reason, detail);
    _reset();
  }

  void _reset() {
    _state = _RxState.waitAa;
    _cmd = 0;
    _len = 0;
    _payload.clear();
    _lastByteAt = null;
  }
}
