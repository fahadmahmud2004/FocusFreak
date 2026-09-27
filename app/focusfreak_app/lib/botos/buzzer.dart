/// The passive buzzer's sound, as a WAV the phone can play.
///
/// `tone()` drives the buzzer with a square wave, so that is what this makes:
/// a square at the note's frequency, softened by a couple of milliseconds at
/// each edge so notes do not click, and cut to 90 % of its length so repeated
/// notes are heard as separate, the way Arduino melody players do it.
library;

import 'dart:typed_data';

import 'music.dart';

class Buzzer {
  const Buzzer._();

  static const int rate = 22050;

  /// A whole melody.
  static Uint8List melody(List<Note> notes, {double volume = 0.22}) =>
      _wav(notes, volume);

  /// One short tone, for clicks and game sounds.
  static Uint8List tone(int hz, int ms, {double volume = 0.18}) =>
      _wav(<Note>[Note(hz, ms)], volume, staccato: false);

  static Uint8List _wav(
    List<Note> notes,
    double volume, {
    bool staccato = true,
  }) {
    final total = notes.fold<int>(0, (s, n) => s + n.ms * rate ~/ 1000);
    final data = Int16List(total);
    final amp = (32767 * volume).round();
    const fade = rate * 3 ~/ 1000;
    var i = 0;
    for (final n in notes) {
      final len = n.ms * rate ~/ 1000;
      final sounding = staccato ? len * 9 ~/ 10 : len;
      if (n.hz > 0) {
        final period = rate / n.hz;
        for (var k = 0; k < sounding; k++) {
          final high = (k % period) < period / 2;
          var a = amp;
          if (k < fade) a = a * k ~/ fade;
          if (sounding - k < fade) a = a * (sounding - k) ~/ fade;
          data[i + k] = high ? a : -a;
        }
      }
      i += len;
    }

    final bytes = data.buffer.asUint8List();
    final out = BytesBuilder();
    void u32(int v) => out.add(
      (ByteData(4)..setUint32(0, v, Endian.little)).buffer.asUint8List(),
    );
    void u16(int v) => out.add(
      (ByteData(2)..setUint16(0, v, Endian.little)).buffer.asUint8List(),
    );
    out.add('RIFF'.codeUnits);
    u32(36 + bytes.length);
    out.add('WAVEfmt '.codeUnits);
    u32(16);
    u16(1); // PCM
    u16(1); // mono
    u32(rate);
    u32(rate * 2);
    u16(2);
    u16(16);
    out.add('data'.codeUnits);
    u32(bytes.length);
    out.add(bytes);
    return out.toBytes();
  }
}
