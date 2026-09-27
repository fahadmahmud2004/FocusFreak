/// Music for the passive buzzer.
///
/// Melodies are RTTTL, the ringtone text format Arduino buzzer sketches have
/// used for two decades: small enough for PROGMEM, and `tone()` plays it note
/// by note. The phone plays the same notes as a square wave, the buzzer's own
/// timbre, so the virtual bot sounds like the real one.
library;

import 'dart:math' as math;

import 'world.dart';

/// One note: [hz] 0 is a rest.
class Note {
  const Note(this.hz, this.ms);
  final int hz;
  final int ms;
}

class Rtttl {
  const Rtttl._();

  static const List<String> _names = <String>[
    'c', 'c#', 'd', 'd#', 'e', 'f', 'f#', 'g', 'g#', 'a', 'a#', 'b', //
  ];

  /// Parses `name:d=4,o=5,b=120:c,8e.,2g6,p`.
  static List<Note> parse(String rtttl) {
    final parts = rtttl.split(':');
    if (parts.length < 3) return const <Note>[];
    var d = 4;
    var o = 6;
    var bpm = 63;
    for (final kv in parts[1].split(',')) {
      final pair = kv.trim().split('=');
      if (pair.length != 2) continue;
      final v = int.tryParse(pair[1].trim());
      if (v == null) continue;
      switch (pair[0].trim()) {
        case 'd':
          d = v;
        case 'o':
          o = v;
        case 'b':
          bpm = v;
      }
    }
    final whole = 60000 * 4 ~/ bpm;
    final notes = <Note>[];
    for (final raw in parts.sublist(2).join(':').split(',')) {
      final t = raw.trim().toLowerCase();
      if (t.isEmpty) continue;
      final m = RegExp(r'^(\d+)?([a-gp]#?)(\.?)(\d)?(\.?)$').firstMatch(t);
      if (m == null) continue;
      final dur = int.tryParse(m.group(1) ?? '') ?? d;
      var ms = whole ~/ dur;
      if (m.group(3) == '.' || m.group(5) == '.') ms += ms ~/ 2;
      final name = m.group(2)!;
      if (name == 'p') {
        notes.add(Note(0, ms));
        continue;
      }
      final octave = int.tryParse(m.group(4) ?? '') ?? o;
      final semis = octave * 12 + _names.indexOf(name);
      // A4 = 440 Hz is semitone 57 counting from C0.
      final hz = (440 * math.pow(2, (semis - 57) / 12)).round();
      notes.add(Note(hz, ms));
    }
    return notes;
  }

  static int lengthMs(List<Note> notes) =>
      notes.fold(0, (sum, n) => sum + n.ms);
}

/// The built-in library. Public-domain works and traditional tunes only.
class Melodies {
  const Melodies._();

  static const List<Melody> all = <Melody>[
    Melody(
      'Fur Elise',
      'furelise:d=8,o=5,b=125:32p,e6,d#6,e6,d#6,e6,b,d6,c6,4a.,32p,c,e,a,'
          '4b.,32p,e,g#,b,4c.6,32p,e,e6,d#6,e6,d#6,e6,b,d6,c6,4a.,32p,c,e,a,'
          '4b.,32p,d,c6,b,2a',
      by: 'Beethoven',
    ),
    Melody(
      'Ode to Joy',
      'odetojoy:d=4,o=5,b=140:e,e,f,g,g,f,e,d,c,c,d,e,e.,8d,2d,e,e,f,g,g,f,'
          'e,d,c,c,d,e,d.,8c,2c',
      by: 'Beethoven',
    ),
    Melody(
      'Korobeiniki',
      'korobeiniki:d=4,o=5,b=160:e6,8b,8c6,8d6,16e6,16d6,8c6,8b,a,8a,8c6,'
          'e6,8d6,8c6,b,8b,8c6,d6,e6,c6,a,2a,8p,d6,8f6,a6,8g6,8f6,e6,8e6,8c6,'
          'e6,8d6,8c6,b,8b,8c6,d6,e6,c6,a,a',
      by: 'Russian folk',
    ),
    Melody(
      'The Entertainer',
      'entertainer:d=4,o=5,b=140:8d,8d#,8e,c6,8e,c6,8e,2c.6,8c6,8d6,8d#6,'
          '8e6,8c6,8d6,e6,8b,d6,2c6,p,8d,8d#,8e,c6,8e,c6,8e,2c.6,8p,8a,8g,'
          '8f#,8a,8c6,e6,8d6,8c6,8a,2d6',
      by: 'Scott Joplin',
    ),
    Melody(
      'Mountain King',
      'mountainking:d=8,o=5,b=160:a4,b4,c,d,e,c,4e,d#,b4,4d#,d,a#4,4d,a4,'
          'b4,c,d,e,c,e,a,g,e,c,e,2g',
      by: 'Grieg',
    ),
    Melody(
      'Minuet in G',
      'minuet:d=4,o=5,b=140:d6,8g,8a,8b,8c6,d6,g,g,e6,8c6,8d6,8e6,8f#6,g6,'
          'g,g,c6,8d6,8c6,8b,8a,b,8c6,8b,8a,8g,f#,8g,8a,8b,8g,2a',
      by: 'Petzold',
    ),
    Melody(
      'Canon in D',
      'canon:d=4,o=5,b=90:f#6,e6,d6,c#6,b,a,b,c#6,d6,c#6,b,a,g,f#,g,e,'
          '8d,8f#,8a,8g,8f#,8d,8f#,8e,8d,8b4,8d,8a,8g,8b,8a,8g,2f#',
      by: 'Pachelbel',
    ),
    Melody(
      'Greensleeves',
      'greensleeves:d=4,o=5,b=140:g,2a#,c6,d.6,8d#6,d6,2c6,a,f.,8g,a#,2g,'
          'g,g.,8f#,g,2a,f#,2d,g,2a#,c6,d.6,8e6,d6,2c6,a,f.,8g,a#,g.,8f#,g,'
          'a.,8g,f#,2g.',
      by: 'Traditional',
    ),
    Melody(
      'Brahms Lullaby',
      'lullaby:d=4,o=5,b=90:8e,8e,g.,8e,8e,g,8e,8g,c6,b.,8a,a,g,8d,8e,f,d,'
          '8d,8e,f,2p,8d,8f,b,8a,g,b,2c6',
      by: 'Brahms',
    ),
    Melody(
      'Twinkle Twinkle',
      'twinkle:d=4,o=5,b=120:c,c,g,g,a,a,2g,f,f,e,e,d,d,2c,g,g,f,f,e,e,2d,'
          'g,g,f,f,e,e,2d,c,c,g,g,a,a,2g,f,f,e,e,d,d,2c',
      by: 'Traditional',
    ),
    Melody(
      'Jingle Bells',
      'jinglebells:d=8,o=5,b=140:e,e,4e,e,e,4e,e,g,c.,16d,2e,f,f,f.,16f,f,'
          'e,e,16e,16e,e,d,d,e,4d,4g',
      by: 'Pierpont',
    ),
    Melody(
      'Happy Birthday',
      'birthday:d=4,o=5,b=125:8g.,16g,a,g,c6,2b,8g.,16g,a,g,d6,2c6,8g.,'
          '16g,g6,e6,c6,b,a,8f6.,16f6,e6,c6,d6,2c6',
      by: 'Hill sisters',
    ),
    Melody(
      'Turkish March',
      'turkish:d=16,o=5,b=112:b,a,g#,a,4c6,d6,c6,b,c6,4e6,f6,e6,d#6,e6,b6,a6,'
          'g#6,a6,b6,a6,g#6,a6,4c7,8a6,8c7,8b6,8a6,8g6,8a6,8b6,8a6,8g6,8a6,'
          '8b6,8a6,8g6,8f#6,4e6',
      by: 'Mozart',
    ),
    Melody(
      'Eine kleine Nachtmusik',
      'nachtmusik:d=8,o=5,b=130:4g,p,d,4g,p,d,g,d,g,b,4d6,p,4c6,p,a,4c6,p,a,'
          'c6,a,f#,a,4d,p,4g',
      by: 'Mozart',
    ),
    Melody(
      'William Tell',
      'williamtell:d=16,o=5,b=150:e,e,8e,e,e,8e,e,e,8a,8b,4c6,e,e,8e,e,e,8e,'
          'e,e,8a,8c6,4b,e,e,8e,e,e,8e,e,e,8a,8b,8c6,8a,8c6,8e6,2d6',
      by: 'Rossini',
    ),
    Melody(
      'Swan Lake',
      'swanlake:d=4,o=5,b=100:2f#,8b4,8c#,8d,8e,2f#.,8d,2f#.,8d,2f#.,8b4,8d,'
          '8b4,8g4,2b4',
      by: 'Tchaikovsky',
    ),
    Melody(
      'Blue Danube',
      'bluedanube:d=4,o=5,b=160:d,d,f#,a,2a,p,a6,a6,p,f#6,f#6,p,d,d,f#,a,2a,'
          'p,a6,a6,p,g6,g6,p,c#,c#,e,b,2b,p,b6,b6,p,g6,g6,p,c#,c#,e,b,2b,p,'
          'b6,b6,p,f#6,f#6',
      by: 'Strauss',
    ),
    Melody(
      'Can-Can',
      'cancan:d=8,o=5,b=180:4c,d,f,e,d,4g,4g,4g,a,e,f,d,4g,4g,4g,a,e,f,d,g,'
          'f,e,d,c,c6,b,a,g,f,e,d,4c',
      by: 'Offenbach',
    ),
    Melody(
      'Morning Mood',
      'morning:d=8,o=5,b=110:g,e,d,c,d,e,g,e,d,c,16d,16e,16d,16e,g,e,g,a,e,'
          'a,g,e,d,4c',
      by: 'Grieg',
    ),
    Melody(
      'Spring',
      'spring:d=8,o=5,b=120:4e,g#,g#,g#,f#,e,2b,b,a,g#,g#,g#,f#,e,2b,b,a,g#,'
          'a,b,a,4g#,4e',
      by: 'Vivaldi',
    ),
    Melody(
      'Prelude in C',
      'preludec:d=16,o=5,b=100:c,e,g,c6,e6,g,c6,e6,c,e,g,c6,e6,g,c6,e6,c,d,a,'
          'd6,f6,a,d6,f6,c,d,a,d6,f6,a,d6,f6,b4,d,g,d6,f6,g,d6,f6,b4,d,g,d6,'
          'f6,g,d6,f6,c,e,g,c6,e6,g,c6,e6,c,e,g,c6,e6,g,c6,e6',
      by: 'Bach',
    ),
    Melody(
      'Toccata',
      'toccata:d=16,o=6,b=90:a,g,2a,p,g,f,e,d,4c#,2d,4p,a5,g5,2a5,p,e5,f5,'
          'c#5,2d5',
      by: 'Bach',
    ),
    Melody(
      'Moonlight Sonata',
      'moonlight:d=8,o=5,b=180:g#4,c#,e,g#4,c#,e,g#4,c#,e,g#4,c#,e,a4,c#,e,'
          'a4,c#,e,a4,d,f#,a4,d,f#,g#4,c,f#,g#4,c#,e,g#4,c#,d#,f#4,c,d#',
      by: 'Beethoven',
    ),
    Melody(
      'Amazing Grace',
      'amazinggrace:d=4,o=5,b=100:d,2g,8b,8g,2b,a,2g,e,2d,d,2g,8b,8g,2b,8a,'
          '8b,2d.6',
      by: 'Traditional',
    ),
    Melody(
      'Silent Night',
      'silentnight:d=4,o=5,b=90:g.,8a,g,2e.,g.,8a,g,2e.,2d6,d6,2b.,2c6,c6,'
          '2g.',
      by: 'Gruber',
    ),
    Melody(
      'Auld Lang Syne',
      'auldlangsyne:d=4,o=5,b=110:c,f.,8f,f,a,g.,8f,g,a,f.,8f,a,c6,2d6.',
      by: 'Traditional',
    ),
    Melody(
      'Oh Susanna',
      'susanna:d=8,o=5,b=160:c,d,4e,4g,4g,a,4g,4e,4c.,d,4e,4e,4d,4c,2d,c,d,'
          '4e,4g,4g.,a,4g,4e,4c.,d,4e,4e,4d,4d,2c',
      by: 'Foster',
    ),
    Melody(
      'When the Saints',
      'saints:d=4,o=5,b=180:c,e,f,1g,c,e,f,1g,c,e,f,2g,2e,2c,2e,1d',
      by: 'Traditional',
    ),
    Melody(
      'Frere Jacques',
      'frerejacques:d=4,o=5,b=140:c,d,e,c,c,d,e,c,e,f,2g,e,f,2g,8g,8a,8g,8f,'
          'e,c,8g,8a,8g,8f,e,c,c,g4,2c,c,g4,2c',
      by: 'Traditional',
    ),
    Melody(
      'Yankee Doodle',
      'yankee:d=8,o=5,b=180:c,c,d,e,c,e,d,g4,c,c,d,e,4c,4b4,c,c,d,e,f,e,d,c,'
          'b4,g4,a4,b4,4c,4c',
      by: 'Traditional',
    ),
  ];

  /// Played when a focus block starts, finishes, and when the day is done.
  static const Melody start = Melody('Start', 'start:d=16,o=6,b=180:c,e,g,4c7');
  static const Melody done = Melody(
    'Done',
    'done:d=16,o=6,b=160:g,e,c,8e,8g,4c7',
  );
}

/// What an alarm can ring with. Short loops, written to be heard across a
/// room: each one repeats until the alarm is stopped.
class AlarmTones {
  const AlarmTones._();

  static const List<Melody> all = <Melody>[
    Melody(
      'Classic',
      'classic:d=16,o=6,b=180:a,p,a,p,a,p,a,4p,a,p,a,p,a,p,a,4p',
    ),
    Melody('Sunrise', 'sunrise:d=8,o=5,b=140:c,e,g,c6,e6,g6,4c7,4p'),
    Melody('Chimes', 'chimes:d=4,o=5,b=100:e6,c6,d6,g,2p,g,d6,e6,2c6,2p'),
    Melody('Rooster', 'rooster:d=16,o=6,b=200:g,g,4b,8a,2g,4p'),
    Melody(
      'Digital',
      'digital:d=32,o=7,b=200:c,e,c,e,c,e,c,e,8p,c,e,c,e,c,e,4p',
    ),
    Melody('Marimba', 'marimba:d=8,o=6,b=160:c,g5,c,e,g,e,c,g5,4p'),
    Melody('Gentle', 'gentle:d=4,o=5,b=80:c,e,g,2c6,p,g,e,2c,p'),
    Melody('Siren', 'siren:d=16,o=6,b=180:c,d,e,f,g,a,b,c7,b,a,g,f,e,d,c,8p'),
    Melody(
      'Reveille',
      'reveille:d=8,o=5,b=160:g,c6,16e6,16c6,g,e6,c6,e6,16c6,16e6,g6,e6,c6,'
          'e6,16c6,16e6,g,c6,4c6,4p',
    ),
    Melody(
      'Birdsong',
      'birds:d=32,o=7,b=160:e,g,e,g,e,8p,d,f#,d,f#,4p,c,e,c,e,c,e,4p',
    ),
    Melody('Bells', 'bells:d=4,o=6,b=120:c,g5,a5,e5,f5,c5,f5,g5,2p'),
    Melody(
      'Pulse',
      'pulse:d=16,o=5,b=180:c6,p,c6,p,c6,p,c6,p,g6,p,g6,p,g6,p,g6,4p',
    ),
  ];
}
