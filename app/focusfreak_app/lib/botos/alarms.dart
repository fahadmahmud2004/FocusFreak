/// Alarms: the bot as a desk clock that wakes you.
///
/// Four slots, each with a time, the days it repeats on and a tone. Set them
/// on the bot with the knob, or from the app. When one rings the screen shows
/// it and the tone repeats until you press the knob (stop) or touch a pad
/// (snooze five minutes).
library;

import 'icons.dart';
import 'music.dart';
import 'os.dart';
import 'screens.dart';
import 'ui.dart';

/// One alarm slot.
class BotAlarm {
  BotAlarm({
    this.on = false,
    this.hour = 7,
    this.minute = 0,
    this.tone = 0,
    this.days = 0,
  });

  bool on;
  int hour;
  int minute;

  /// Index into [AlarmTones.all].
  int tone;

  /// Bit 0 is Monday through bit 6 Sunday, as `DateTime.weekday - 1`. Zero
  /// means ring once and switch off.
  int days;

  static const int slots = 4;

  static List<BotAlarm> defaults() => <BotAlarm>[
    BotAlarm(hour: 6, minute: 30, days: 0x7F),
    BotAlarm(hour: 7, minute: 30, days: AlarmRepeat.sunToThu),
    BotAlarm(hour: 14),
    BotAlarm(hour: 22),
  ];

  bool get once => days == 0;

  bool ringsOn(int weekday) => days == 0 || (days >> (weekday - 1)) & 1 == 1;

  bool ringsAt(DateTime t) =>
      on && t.hour == hour && t.minute == minute && ringsOn(t.weekday);

  /// The next time this alarm rings after [t], or null when it is off.
  DateTime? nextAfter(DateTime t) {
    if (!on) return null;
    for (var d = 0; d <= 7; d++) {
      final day = DateTime(t.year, t.month, t.day + d, hour, minute);
      if (day.isAfter(t) && ringsOn(day.weekday)) return day;
    }
    return null;
  }

  String get time =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  String get repeatLabel => AlarmRepeat.label(days);

  /// Packed into one int so it rides in the bot's `key=value` settings.
  int pack() =>
      (on ? 1 : 0) |
      (hour & 0x1F) << 1 |
      (minute & 0x3F) << 6 |
      (tone & 0xF) << 12 |
      (days & 0x7F) << 16;

  static BotAlarm unpack(int v) => BotAlarm(
    on: v & 1 == 1,
    hour: ((v >> 1) & 0x1F).clamp(0, 23),
    minute: ((v >> 6) & 0x3F).clamp(0, 59),
    tone: ((v >> 12) & 0xF).clamp(0, AlarmTones.all.length - 1),
    days: (v >> 16) & 0x7F,
  );

  BotAlarm copy() =>
      BotAlarm(on: on, hour: hour, minute: minute, tone: tone, days: days);
}

/// The day patterns the knob steps through. The app can set any mix of days.
class AlarmRepeat {
  const AlarmRepeat._();

  static const int everyDay = 0x7F;
  static const int sunToThu = 0x4F;
  static const int monToFri = 0x1F;
  static const int friSat = 0x30;
  static const int satSun = 0x60;

  static const List<int> presets = <int>[
    0,
    everyDay,
    sunToThu,
    monToFri,
    friSat,
    satSun,
  ];

  static const List<String> dayNames = <String>[
    'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun', //
  ];

  static String label(int days) {
    switch (days) {
      case 0:
        return 'Once';
      case everyDay:
        return 'Every day';
      case sunToThu:
        return 'Sun to Thu';
      case monToFri:
        return 'Mon to Fri';
      case friSat:
        return 'Fri and Sat';
      case satSun:
        return 'Sat and Sun';
    }
    return <String>[
      for (var i = 0; i < 7; i++)
        if ((days >> i) & 1 == 1) dayNames[i],
    ].join(' ');
  }
}

// --- the list -----------------------------------------------------------------

class AlarmsScreen extends ListScreen {
  AlarmsScreen(super.os);

  @override
  int get count => BotAlarm.slots;

  @override
  String get title => 'Alarms';

  @override
  void drawRow(Gfx g, int i, int y, bool selected) {
    final a = os.settings.alarms[i];
    BotUi.listRow(
      g,
      y: y,
      label: a.time,
      icon: a.on ? BotIcons.bell : BotIcons.bellOff,
      value: a.on ? a.repeatLabel : 'Off',
      selected: selected,
    );
  }

  @override
  void select(int i) => os.push(AlarmEditScreen(os, i));
}

// --- editing ------------------------------------------------------------------

enum _Field { hour, minute, on, repeat, tone }

/// Turn to pick a field, press to change it, turn to set, press again to
/// keep it. Back saves.
class AlarmEditScreen extends BotScreen {
  AlarmEditScreen(super.os, this.slot);

  final int slot;
  int _field = 0;
  bool _editing = false;

  BotAlarm get _a => os.settings.alarms[slot];
  _Field get _current => _Field.values[_field];

  @override
  bool key(BotKey k) {
    switch (k) {
      case BotKey.left:
      case BotKey.right:
        final d = k == BotKey.right ? 1 : -1;
        if (_editing) {
          _change(d);
        } else {
          _field = (_field + d) % _Field.values.length;
        }
        os.click();
        return true;
      case BotKey.press:
        os.click(hz: 3000);
        if (_current == _Field.on) {
          _a.on = !_a.on;
          os.saveAlarm(slot);
        } else {
          _editing = !_editing;
          if (!_editing) {
            os.saveAlarm(slot);
            os.stopMelody();
          }
        }
        return true;
      default:
        return false;
    }
  }

  void _change(int d) {
    final a = _a;
    switch (_current) {
      case _Field.hour:
        a.hour = (a.hour + d) % 24;
      case _Field.minute:
        a.minute = (a.minute + d) % 60;
      case _Field.on:
        a.on = !a.on;
      case _Field.repeat:
        final presets = AlarmRepeat.presets;
        final at = presets.indexOf(a.days);
        a.days = presets[((at < 0 ? 0 : at) + d) % presets.length];
      case _Field.tone:
        a.tone = (a.tone + d) % AlarmTones.all.length;
        os.playAlarmTone(AlarmTones.all[a.tone]);
    }
    // Setting a time is a sign you want it to ring.
    if (_current != _Field.on) a.on = true;
  }

  @override
  void exit() {
    os.saveAlarm(slot);
    os.stopMelody();
  }

  @override
  void draw(Gfx g, BotWorld w) {
    final a = _a;
    BotUi.statusBar(g, w, title: 'Alarm ${slot + 1}');

    // The time, large, with the hour or minute marked.
    final hh = a.hour.toString().padLeft(2, '0');
    final mm = a.minute.toString().padLeft(2, '0');
    final hw = Gfx.strWidth(BotFonts.big24, hh);
    final cw = Gfx.strWidth(BotFonts.big24, ':');
    final mw = Gfx.strWidth(BotFonts.big24, mm);
    var x = 64 - (hw + cw + mw) ~/ 2;
    const base = 36;
    _timePart(g, x, base, hh, hw, _Field.hour);
    x += hw;
    g.str(BotFonts.big24, x, base, ':');
    x += cw;
    _timePart(g, x, base, mm, mw, _Field.minute);

    // On, repeat and tone along the bottom.
    final cells = <(_Field, String)>[
      (_Field.on, a.on ? 'ON' : 'OFF'),
      (_Field.repeat, a.repeatLabel),
      (_Field.tone, AlarmTones.all[a.tone].title),
    ];
    const y = 44;
    const widths = <int>[24, 52, 48];
    var cx = 1;
    for (var i = 0; i < cells.length; i++) {
      final (field, text) = cells[i];
      final wv = widths[i];
      final selected = _current == field;
      if (selected && _editing) {
        g.rBox(cx, y, wv - 2, 11, 3);
        g.color = 0;
      } else if (selected) {
        g.rFrame(cx, y, wv - 2, 11, 3);
      }
      g.strCenter(
        BotFonts.secondary,
        cx + (wv - 2) ~/ 2,
        y + 8,
        Gfx.fit(BotFonts.secondary, text, wv - 6),
      );
      g.color = 1;
      cx += wv;
    }

    g.str(
      BotFonts.tiny,
      1,
      63,
      _editing ? 'TURN TO SET, PRESS TO KEEP' : 'TURN TO PICK, PRESS TO EDIT',
    );
  }

  void _timePart(Gfx g, int x, int base, String text, int w, _Field field) {
    final selected = _current == field;
    if (selected && _editing) {
      g.rBox(x - 2, base - 19, w + 3, 22, 3);
      g.color = 0;
      g.str(BotFonts.big24, x, base, text);
      g.color = 1;
      return;
    }
    g.str(BotFonts.big24, x, base, text);
    if (selected) g.box(x, base + 3, w - 1, 2);
  }
}

// --- ringing ------------------------------------------------------------------

class AlarmRingScreen extends BotScreen {
  AlarmRingScreen(super.os, this.slot);

  final int slot;
  late final int _startFrame = os.frame;

  /// Ten minutes of ringing is enough; after that it snoozes on its own.
  static const int _maxFrames = 10 * 60 * BotOs.fps;

  BotAlarm get _a => os.settings.alarms[slot];

  @override
  void enter() {
    os.eyes.lookAt(0, -0.4, frames: 60);
    os.playAlarmTone(AlarmTones.all[_a.tone]);
  }

  @override
  bool key(BotKey k) {
    switch (k) {
      case BotKey.touchLeft:
      case BotKey.touchRight:
      case BotKey.touchFront:
        os.snooze(slot);
        _close();
      case BotKey.left:
      case BotKey.right:
        break;
      default:
        os.snoozeUntil = null;
        _close();
    }
    return true;
  }

  void _close() {
    os.stopMelody();
    os.pop();
  }

  @override
  void update(BotWorld w) {
    if (os.frame - _startFrame > _maxFrames) {
      os.snooze(slot);
      _close();
      return;
    }
    // Round again once the tone has played through.
    if (os.alarmToneDone) os.playAlarmTone(AlarmTones.all[_a.tone]);
  }

  @override
  void draw(Gfx g, BotWorld w) {
    final f = os.frame - _startFrame;
    // The bell rocks, and the whole screen flashes once a second.
    final rock = const <int>[0, -2, 0, 2][(f ~/ 3) % 4];
    g.bitmap(8 + rock, 14, BotIcons.bellBig);
    if (f % 25 < 3) {
      g.frame(0, 0, 128, 64);
      g.frame(1, 1, 126, 62);
    }
    final t = w.now;
    final text =
        '${t.hour.toString().padLeft(2, '0')}:'
        '${t.minute.toString().padLeft(2, '0')}';
    g.strCenter(BotFonts.big24, 76, 34, text);
    g.strCenter(BotFonts.primary, 76, 46, 'Alarm ${slot + 1}');
    BotUi.hint(g, 'Touch: snooze');
    BotUi.hint(g, 'Press: stop', right: true);
  }
}
