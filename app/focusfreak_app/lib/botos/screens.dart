/// The bot's screens.
///
/// Controls, everywhere:
///
/// * turn the knob: move between pages or items
/// * press the knob: select, or pause and resume a block
/// * hold the knob: options, or back to home
/// * push button: open the menu, or go back
/// * top pads: pet the bot (left and right in games)
/// * front pad: poke the bot (jump and tap in games)
library;

import 'dart:math' as math;

import 'alarms.dart';
import 'arcade.dart';
import 'games.dart';
import 'icons.dart';
import 'music.dart';
import 'os.dart';
import 'routines.dart';
import 'ui.dart';

export 'alarms.dart';
export 'arcade.dart';
export 'games.dart';

abstract class BotScreen {
  BotScreen(this.os);

  final BotOs os;

  /// Return true when the screen used the key. Unused keys fall through to the
  /// global rules in [BotOs.key].
  bool key(BotKey k) => false;

  void update(BotWorld w) {}

  void draw(Gfx g, BotWorld w);

  void enter() {}

  void exit() {}
}

// --- home ---------------------------------------------------------------------

enum HomePage { focus, face, clock, room, desk, today }

class HomeScreen extends BotScreen {
  HomeScreen(super.os);

  int page = 0;
  int _pageShownAt = -999;

  /// While a block runs it is the first page, so turning the knob from
  /// anywhere on home always comes back round to it.
  List<HomePage> get pages => <HomePage>[
    if (os.world.session != null) HomePage.focus,
    if (os.settings.faceHome) ...<HomePage>[
      HomePage.face,
      HomePage.clock,
    ] else ...<HomePage>[HomePage.clock, HomePage.face],
    HomePage.room,
    HomePage.desk,
    HomePage.today,
  ];

  HomePage get current {
    final all = pages;
    return all[page.clamp(0, all.length - 1)];
  }

  void show(HomePage p) {
    final i = pages.indexOf(p);
    page = i < 0 ? 0 : i;
  }

  @override
  bool key(BotKey k) {
    switch (k) {
      case BotKey.left:
      case BotKey.right:
        final n = pages.length;
        page = (page.clamp(0, n - 1) + (k == BotKey.right ? 1 : -1)) % n;
        _pageShownAt = os.frame;
        os.click();
        return true;
      case BotKey.touchLeft:
      case BotKey.touchRight:
      case BotKey.touchFront:
        // A touch always shows the face it is touching.
        show(HomePage.face);
        return false;
      case BotKey.press:
        if (current == HomePage.face) {
          os.eyes.pet();
          return true;
        }
        if (current == HomePage.focus) {
          os.click(hz: 3000);
          os.push(FocusScreen(os));
          return true;
        }
        return false;
      default:
        return false;
    }
  }

  @override
  void draw(Gfx g, BotWorld w) {
    switch (current) {
      case HomePage.focus:
        _focus(g, w);
      case HomePage.face:
        os.eyes.draw(g);
        // Page dots fade in for a moment after turning the knob.
        if (os.frame - _pageShownAt < 40) _dots(g, 61);
      case HomePage.clock:
        _clock(g, w);
      case HomePage.room:
        _room(g, w);
      case HomePage.desk:
        _desk(g, w);
      case HomePage.today:
        _today(g, w);
    }
  }

  /// The running block, in brief. Press to open it.
  void _focus(Gfx g, BotWorld w) {
    final s = w.session;
    if (s == null) return;
    _bar(
      g,
      w,
      s.index != null && s.count != null
          ? 'Block ${s.index}/${s.count}'
          : 'Now',
    );
    g.strCenter(
      BotFonts.primary,
      64,
      21,
      Gfx.fit(BotFonts.primary, s.name, 120),
    );
    final text = BotUi.clock(s.remaining);
    g.strCenter(
      text.length > 5 ? BotFonts.big16 : BotFonts.big24,
      64,
      44,
      text,
    );
    BotUi.progress(g, 6, 47, 116, 5, s.progress);
    if (s.paused) {
      g.bitmap(2, 55, BotIcons.pause.take(7).toList());
    }
    g.strCenter(
      BotFonts.tiny,
      64,
      62,
      s.paused ? 'PAUSED. PRESS TO OPEN' : 'PRESS TO OPEN',
    );
  }

  void _dots(Gfx g, int y) {
    final n = pages.length;
    var x = 64 - (n * 5 - 2) ~/ 2;
    for (var i = 0; i < n; i++) {
      if (i == page.clamp(0, n - 1)) {
        g.box(x, y - 1, 3, 3);
      } else {
        g.pixel(x + 1, y);
      }
      x += 5;
    }
  }

  void _bar(Gfx g, BotWorld w, String title) => BotUi.statusBar(
    g,
    w,
    title: title,
    pages: pages.length,
    page: page,
    playing: os.playing != null,
  );

  /// The desk clock: the RTC's time and date, and the room at a glance.
  void _clock(Gfx g, BotWorld w) {
    final t = w.now;
    final session = w.session;
    _bar(
      g,
      w,
      session == null
          ? BotUi.date(t)
          : '${BotUi.date(t)}  ${BotUi.clock(session.remaining)}',
    );
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    final ss = t.second.toString().padLeft(2, '0');
    final timeW =
        Gfx.strWidth(BotFonts.big32, '$hh:$mm') +
        2 +
        Gfx.strWidth(BotFonts.secondary, ss);
    var x = 64 - timeW ~/ 2;
    x += g.str(BotFonts.big32, x, 44, hh);
    // The colon breathes with the seconds.
    final colonW = Gfx.strWidth(BotFonts.big32, ':');
    if (t.second.isEven) g.str(BotFonts.big32, x, 44, ':');
    x += colonW;
    x += g.str(BotFonts.big32, x, 44, mm);
    g.str(BotFonts.secondary, x + 2, 44, ss);

    // The room along the bottom: temperature, humidity, light, you.
    g.dottedH(0, 50, 128);
    final s = w.sensors;
    var cx = 0;
    void cell(List<String> icon, String? value, int width) {
      g.bitmap(cx, 55, icon);
      g.str(BotFonts.secondary, cx + 10, 63, value ?? '--');
      cx += width;
    }

    cell(BotIcons.thermometer, s.tempC?.toStringAsFixed(1), 36);
    if (s.tempC != null) {
      BotUi.degree(
        g,
        10 + Gfx.strWidth(BotFonts.secondary, s.tempC!.toStringAsFixed(1)) + 1,
        56,
      );
    }
    cell(
      BotIcons.drop,
      s.humidity == null ? null : '${s.humidity!.round()}%',
      30,
    );
    cell(
      s.dark ? BotIcons.moon : BotIcons.sun,
      s.light == null ? null : '${(s.light! / 10.23).round()}%',
      32,
    );
    cell(BotIcons.person, s.present ? '${s.distanceCm}' : 'away', 30);
  }

  void _room(Gfx g, BotWorld w) {
    _bar(g, w, 'Room');
    final s = w.sensors;
    if (s.tempC == null && s.humidity == null) {
      g.strCenter(BotFonts.secondary, 64, 34, 'No climate sensor');
      return;
    }
    // Temperature, left.
    g.bitmap(2, 16, BotIcons.thermometer);
    if (s.tempC != null) {
      final v = s.tempC!.toStringAsFixed(1);
      final vw = g.str(BotFonts.big16, 13, 30, v);
      BotUi.degree(g, 15 + vw, 14);
      g.str(BotFonts.tiny, 19 + vw, 20, 'C');
    }
    // Humidity, right.
    g.bitmap(70, 16, BotIcons.drop);
    if (s.humidity != null) {
      final vw = g.str(BotFonts.big16, 81, 30, '${s.humidity!.round()}');
      g.str(BotFonts.secondary, 83 + vw, 30, '%');
    }

    final verdict = comfort(s.tempC, s.humidity);
    g.strCenter(BotFonts.primary, 64, 45, verdict.$1);

    // A comfort scale from cold to hot, with a marker where the room is.
    const x0 = 10;
    const width = 108;
    for (var x = x0; x <= x0 + width; x += 3) {
      g.pixel(x, 55);
    }
    g.str(BotFonts.tiny, 0, 58, 'C');
    g.str(BotFonts.tiny, 124, 58, 'H');
    final pos = x0 + (width * verdict.$2).round();
    g.triangle(pos - 3, 50, pos + 3, 50, pos, 54);
    g.vLine(pos, 54, 4);
    g.str(BotFonts.tiny, 50, 63, 'COMFY');
    g.pixel(64 - 1, 58);
  }

  /// A verdict and a 0..1 position on the cold-to-hot scale.
  static (String, double) comfort(double? t, double? h) {
    if (t == null) return ('No temperature', 0.5);
    // Apparent temperature: humid air feels hotter above ~26 C.
    final feels = h != null && t > 26 ? t + (h - 40).clamp(0, 60) / 12 : t;
    final pos = ((feels - 16) / 20).clamp(0.0, 1.0);
    final String text;
    if (feels < 18) {
      text = 'Too cold';
    } else if (feels < 21) {
      text = 'A bit cool';
    } else if (feels <= 27) {
      text = h != null && h > 70 ? 'Comfy, but humid' : 'Comfortable';
    } else if (feels <= 31) {
      text = 'Warm, get a fan on';
    } else {
      text = 'Too hot to focus';
    }
    return (text, pos);
  }

  void _desk(Gfx g, BotWorld w) {
    _bar(g, w, 'Desk');
    final s = w.sensors;

    // Light.
    final light = s.light;
    g.bitmap(2, 13, s.dark ? BotIcons.moon : BotIcons.sun);
    g.str(BotFonts.primary, 13, 20, 'Light');
    if (light != null) {
      final pct = (light / 1023 * 100).round();
      g.strRight(BotFonts.secondary, 126, 20, lightVerdict(light));
      BotUi.progress(g, 13, 23, 113, 6, pct / 100);
    }

    // You.
    final d = s.distanceCm;
    g.bitmap(2, 33, BotIcons.person);
    g.str(BotFonts.primary, 13, 40, 'You');
    g.strRight(
      BotFonts.secondary,
      126,
      40,
      d == null
          ? 'Away'
          : d < 30
          ? '$d cm, sit back'
          : s.present
          ? '$d cm'
          : 'Away',
    );

    // How long you have been sitting.
    g.bitmap(2, 48, BotIcons.clock);
    g.str(BotFonts.primary, 13, 56, 'Sitting');
    g.strRight(BotFonts.secondary, 126, 56, sittingLabel(os.sittingFor));
  }

  static String sittingLabel(Duration? sat) {
    if (sat == null) return 'Not now';
    final m = sat.inMinutes;
    final text = m < 60 ? '$m min' : '${m ~/ 60} h ${m % 60} min';
    return sat >= BotOs.sitNudge ? '$text, stretch' : text;
  }

  static String lightVerdict(int light) {
    if (light < 150) return 'Dark';
    if (light < 350) return 'Too dim';
    if (light < 850) return 'Good';
    return 'Bright';
  }

  void _today(Gfx g, BotWorld w) {
    _bar(g, w, 'Today');
    final m = w.verifiedMinutesToday;
    final text = '${m ~/ 60}:${(m % 60).toString().padLeft(2, '0')}';
    final tw = g.str(BotFonts.big24, 4, 40, text);
    g.str(BotFonts.secondary, 8 + tw, 40, 'verified');
    g.dottedH(4, 47, 120);
    g.bitmap(4, 51, BotIcons.bolt);
    g.str(
      BotFonts.secondary,
      15,
      59,
      w.streak == 0 ? 'Start a streak today' : '${w.streak} day streak',
    );
  }
}

// --- focus --------------------------------------------------------------------

class FocusScreen extends BotScreen {
  FocusScreen(super.os);

  bool _faceView = false;

  @override
  bool key(BotKey k) {
    final s = os.world.session;
    switch (k) {
      case BotKey.left:
      case BotKey.right:
        _faceView = !_faceView;
        os.click();
        return true;
      case BotKey.press:
        if (s == null || s.armed) return true;
        os.click();
        os.emit(s.paused ? const ResumeFocus() : const PauseFocus());
        return true;
      case BotKey.hold:
        os.push(FocusOptionsScreen(os));
        return true;
      case BotKey.button:
        // Back from a running block is home, with the block still running.
        // The face, with the block one turn of the knob away.
        os.popToHome();
        os.home.show(HomePage.face);
        return true;
      default:
        return false;
    }
  }

  @override
  void draw(Gfx g, BotWorld w) {
    final s = w.session;
    if (s == null) {
      g.strCenter(BotFonts.secondary, 64, 34, 'Nothing running');
      return;
    }
    if (_faceView) {
      os.eyes.draw(g);
      g.strRight(BotFonts.tiny, 127, 6, BotUi.time(w.now));
      final text = BotUi.clock(s.remaining);
      final tw = Gfx.strWidth(BotFonts.primary, text) + 10;
      g.rBox(64 - tw ~/ 2, 53, tw, 11, 4);
      g.color = 0;
      g.strCenter(BotFonts.primary, 64, 62, text);
      g.color = 1;
      return;
    }

    final title = s.index != null && s.count != null
        ? 'Block ${s.index}/${s.count}'
        : 'Focus';
    BotUi.statusBar(g, w, title: title, playing: os.playing != null);

    g.strCenter(
      BotFonts.primary,
      64,
      20,
      Gfx.fit(BotFonts.primary, s.name, 120),
    );
    final text = BotUi.clock(s.remaining);
    final font = text.length > 5 ? BotFonts.big16 : BotFonts.big24;
    g.strCenter(font, 64, text.length > 5 ? 40 : 46, text);
    BotUi.progress(g, 6, 49, 116, 6, s.progress);

    final String status;
    List<String>? icon;
    if (s.armed) {
      status = 'Lock your phone to start';
    } else if (s.paused) {
      status = 'Paused. Press to resume';
      icon = BotIcons.pause;
    } else if (s.tracked && s.verified) {
      // What the block is for says more than what comes after it.
      status = s.description.isNotEmpty ? s.description : 'Verified';
      icon = BotIcons.check;
    } else if (s.description.isNotEmpty) {
      status = s.description;
      icon = BotIcons.play;
    } else if (s.tracked) {
      status = 'Not verified right now';
    } else {
      status = 'Running';
      icon = BotIcons.play;
    }
    var x =
        64 -
        (Gfx.strWidth(BotFonts.secondary, status) + (icon == null ? 0 : 10)) ~/
            2;
    if (icon != null) {
      g.bitmap(x, 56, icon.take(7).toList());
      x += 10;
    }
    g.str(BotFonts.secondary, x, 63, Gfx.fit(BotFonts.secondary, status, 120));
  }
}

class FocusOptionsScreen extends BotScreen {
  FocusOptionsScreen(super.os);

  int _i = 0;
  static const List<String> _items = <String>['Skip block', 'Stop', 'Back'];

  @override
  bool key(BotKey k) {
    switch (k) {
      case BotKey.left:
      case BotKey.right:
        _i = (_i + (k == BotKey.right ? 1 : -1)) % _items.length;
        os.click();
        return true;
      case BotKey.press:
        os.click();
        switch (_i) {
          case 0:
            os.emit(const SkipBlock());
          case 1:
            os.emit(const StopFocus());
        }
        os.pop();
        return true;
      default:
        return false;
    }
  }

  @override
  void draw(Gfx g, BotWorld w) {
    BotUi.statusBar(g, w, title: 'Block options');
    for (var i = 0; i < _items.length; i++) {
      BotUi.listRow(g, y: 13 + i * 15, label: _items[i], selected: i == _i);
    }
  }
}

// --- menu ---------------------------------------------------------------------

class _Item {
  const _Item(this.label, this.icon, this.open);
  final String label;
  final List<String> icon;
  final BotScreen Function(BotOs os) open;
}

/// A scrolling list: the pattern every list on the bot uses.
abstract class ListScreen extends BotScreen {
  ListScreen(super.os);

  int index = 0;
  int _first = 0;
  static const int visible = 4;

  int get count;
  String get title;
  void drawRow(Gfx g, int i, int y, bool selected);
  void select(int i);

  @override
  bool key(BotKey k) {
    switch (k) {
      case BotKey.left:
      case BotKey.right:
        index = (index + (k == BotKey.right ? 1 : -1)).clamp(0, count - 1);
        os.click();
        return true;
      case BotKey.press:
        os.click(hz: 3000);
        select(index);
        return true;
      default:
        return false;
    }
  }

  @override
  void draw(Gfx g, BotWorld w) {
    BotUi.statusBar(g, w, title: title, playing: os.playing != null);
    if (index < _first) _first = index;
    if (index >= _first + visible) _first = index - visible + 1;
    for (var r = 0; r < visible && _first + r < count; r++) {
      drawRow(g, _first + r, 11 + r * 13, _first + r == index);
    }
    BotUi.scrollbar(g, index, count);
  }
}

class MenuScreen extends ListScreen {
  MenuScreen(super.os);

  List<_Item> get _items => <_Item>[
    if (os.world.session != null)
      _Item('Now running', BotIcons.play, (os) => FocusScreen(os))
    else
      _Item('Focus timer', BotIcons.timer, (os) => TimerSetupScreen(os)),
    _Item('Routines', BotIcons.clock, (os) => RoutinesScreen(os)),
    _Item('Music', BotIcons.note, (os) => MusicScreen(os)),
    _Item('Games', BotIcons.game, (os) => GamesScreen(os)),
    _Item('Alarms', BotIcons.bell, (os) => AlarmsScreen(os)),
    _Item('Room', BotIcons.gauge, (os) => RoomScreen(os)),
    _Item('Settings', BotIcons.gear, (os) => SettingsScreen(os)),
  ];

  @override
  int get count => _items.length;

  @override
  String get title => 'Menu';

  @override
  void drawRow(Gfx g, int i, int y, bool selected) => BotUi.listRow(
    g,
    y: y,
    label: _items[i].label,
    icon: _items[i].icon,
    selected: selected,
  );

  @override
  void select(int i) => os.push(_items[i].open(os));
}

class TimerSetupScreen extends BotScreen {
  TimerSetupScreen(super.os, {this.minutes = 25});

  int minutes;

  @override
  bool key(BotKey k) {
    switch (k) {
      case BotKey.left:
      case BotKey.right:
        final step = minutes < 10 || (minutes == 10 && k == BotKey.left)
            ? 1
            : 5;
        minutes = (minutes + (k == BotKey.right ? step : -step)).clamp(1, 180);
        os.click();
        return true;
      case BotKey.press:
        os.click(hz: 3000);
        os.popToHome();
        os.emit(StartFocus(minutes));
        return true;
      default:
        return false;
    }
  }

  @override
  void draw(Gfx g, BotWorld w) {
    BotUi.statusBar(g, w, title: 'Focus timer');
    final text = '$minutes';
    final tw = Gfx.strWidth(BotFonts.big32, text);
    final x = 64 - (tw + 22) ~/ 2;
    g.str(BotFonts.big32, x, 46, text);
    g.str(BotFonts.primary, x + tw + 4, 46, 'min');
    // Turn hints either side.
    g.triangle(6, 30, 12, 24, 12, 36);
    g.triangle(121, 30, 115, 24, 115, 36);
    BotUi.hint(g, 'Back');
    BotUi.hint(g, 'Start', right: true);
  }
}

// --- routines -----------------------------------------------------------------

/// The routines the bot carries, so a study day runs with no phone.
class RoutinesScreen extends ListScreen {
  RoutinesScreen(super.os);

  @override
  int get count => BotRoutines.keys.length;

  @override
  String get title => 'Routines';

  @override
  void drawRow(Gfx g, int i, int y, bool selected) {
    final t = BotRoutines.all[i];
    BotUi.listRow(
      g,
      y: y,
      label: t.name,
      icon: BotIcons.clock,
      value: BotRoutines.length(t),
      selected: selected,
    );
  }

  @override
  void select(int i) {
    os.popToHome();
    os.emit(StartRoutine(i));
  }
}

// --- music --------------------------------------------------------------------

class MusicScreen extends ListScreen {
  MusicScreen(super.os, {int? autoplay}) : _autoplay = autoplay;

  final int? _autoplay;

  /// Rows before the tunes: the play mode, then Stop while something plays.
  int get _head => os.playing != null && os.playingIndex >= 0 ? 2 : 1;

  @override
  void enter() {
    final a = _autoplay;
    if (a != null && a >= 0 && a < Melodies.all.length) {
      index = a + _head;
      _play(a);
    }
  }

  @override
  int get count => Melodies.all.length + _head;

  @override
  String get title => 'Music';

  @override
  void drawRow(Gfx g, int i, int y, bool selected) {
    if (i == 0) {
      BotUi.listRow(
        g,
        y: y,
        label: 'Mode',
        icon: _modeIcon(os.settings.playMode),
        value: os.settings.playMode.label,
        selected: selected,
      );
      return;
    }
    if (i == 1 && _head == 2) {
      BotUi.listRow(
        g,
        y: y,
        label: 'Stop music',
        icon: BotIcons.pause,
        selected: selected,
      );
      return;
    }
    final m = i - _head;
    BotUi.listRow(
      g,
      y: y,
      label: Melodies.all[m].title,
      icon: os.playingIndex == m ? BotIcons.play : BotIcons.note,
      selected: selected,
    );
  }

  @override
  void select(int i) {
    if (i == 0) {
      os.settings.playMode = os.settings.playMode.next;
      os.emit(SaveSetting('playMode', os.settings.playMode.index));
      return;
    }
    if (i == 1 && _head == 2) {
      os.stopMelody();
      index = 0;
      return;
    }
    _play(i - _head);
  }

  void _play(int m) {
    os.playMelody(Melodies.all[m]);
    os.push(NowPlayingScreen(os, m));
  }
}

List<String> _modeIcon(PlayMode m) => switch (m) {
  PlayMode.once => BotIcons.play,
  PlayMode.repeat => BotIcons.repeat,
  PlayMode.all => BotIcons.infinity,
  PlayMode.shuffle => BotIcons.shuffle,
};

/// Turn for the next or previous tune, press to stop or play, hold to change
/// the play mode. In any mode but Once the music carries on after you leave.
class NowPlayingScreen extends BotScreen {
  NowPlayingScreen(super.os, this.index);

  int index;
  final List<int> _bars = List<int>.filled(16, 0);
  int _modeShownAt = -999;

  @override
  bool key(BotKey k) {
    switch (k) {
      case BotKey.left:
      case BotKey.right:
        index = (index + (k == BotKey.right ? 1 : -1)) % Melodies.all.length;
        os.playMelody(Melodies.all[index]);
        return true;
      case BotKey.press:
        if (os.playing != null) {
          os.stopMelody();
        } else {
          os.playMelody(Melodies.all[index]);
        }
        return true;
      case BotKey.hold:
        os.settings.playMode = os.settings.playMode.next;
        os.emit(SaveSetting('playMode', os.settings.playMode.index));
        _modeShownAt = os.frame;
        return true;
      default:
        return false;
    }
  }

  @override
  void update(BotWorld w) {
    // Follow the player when it moves on by itself.
    if (os.playingIndex >= 0) index = os.playingIndex;
    // A spectrum-ish visualiser from the note sounding now.
    final (_, note) = os.playhead;
    for (var i = 0; i < _bars.length; i++) {
      _bars[i] = math.max(0, _bars[i] - 2);
    }
    if (note != null && note.hz > 0) {
      final band = ((math.log(note.hz / 200) / math.ln2) * 4).round().clamp(
        0,
        15,
      );
      for (var i = 0; i < _bars.length; i++) {
        final peak = 22 - (i - band).abs() * 5 + os.random.nextInt(4);
        _bars[i] = math.max(_bars[i], peak.clamp(0, 22));
      }
    }
  }

  @override
  void draw(Gfx g, BotWorld w) {
    final m = Melodies.all[index];
    final mode = os.settings.playMode;
    BotUi.statusBar(g, w, title: 'Now playing', playing: os.playing != null);
    g.str(BotFonts.primary, 2, 20, Gfx.fit(BotFonts.primary, m.title, 112));
    g.bitmap(118, 13, _modeIcon(mode));
    g.str(BotFonts.secondary, 2, 29, m.by);
    if (os.frame - _modeShownAt < 40) {
      g.strRight(BotFonts.secondary, 126, 29, mode.label);
    }
    for (var i = 0; i < _bars.length; i++) {
      final h = _bars[i];
      if (h > 0) g.box(4 + i * 7 + 1, 52 - h, 5, h);
      g.pixel(4 + i * 7 + 3, 52);
    }
    final (pos, _) = os.playhead;
    BotUi.progress(g, 2, 55, 90, 6, os.playing == null ? 0 : pos);
    g.bitmap(98, 55, os.playing == null ? BotIcons.play : BotIcons.pause);
    g.str(BotFonts.tiny, 108, 62, '${index + 1}/${Melodies.all.length}');
  }

  @override
  void exit() {
    if (!os.settings.playMode.continuous) os.stopMelody();
  }
}

// --- games --------------------------------------------------------------------

class GamesScreen extends ListScreen {
  GamesScreen(super.os);

  /// Title, the key its best score is saved under, and how to open it.
  static final List<(String, String, BotScreen Function(BotOs))> games =
      <(String, String, BotScreen Function(BotOs))>[
        ('Snake', 'snake', SnakeGame.new),
        ('Blocks', 'blocks', BlocksGame.new),
        ('Dino Run', 'dino', DinoGame.new),
        ('Flap', 'flap', FlapGame.new),
        ('Star Raid', 'raid', StarRaidGame.new),
        ('Breakout', 'breakout', BreakoutGame.new),
        ('Paddle', 'paddle', PaddleGame.new),
        ('2048', '2048', Game2048.new),
        ('Reaction', 'reaction', ReactionGame.new),
      ];

  @override
  int get count => games.length;

  @override
  String get title => 'Games';

  @override
  void drawRow(Gfx g, int i, int y, bool selected) {
    final (label, id, _) = games[i];
    final best = os.settings.best[id];
    BotUi.listRow(
      g,
      y: y,
      label: label,
      icon: BotIcons.game,
      value: best == null
          ? null
          : id == 'reaction'
          ? '${best}ms'
          : '$best',
      selected: selected,
    );
  }

  @override
  void select(int i) {
    // One buzzer: a game needs it for its own sounds.
    os.stopMelody();
    os.push(games[i].$3(os));
  }
}

// --- room ---------------------------------------------------------------------

class RoomScreen extends ListScreen {
  RoomScreen(super.os);

  List<(String, List<String>, String)> _rows(BotWorld w) {
    final s = w.sensors;
    String or(Object? v, String Function() f) => v == null ? '--' : f();
    return <(String, List<String>, String)>[
      (
        'Temperature',
        BotIcons.thermometer,
        or(s.tempC, () => '${s.tempC!.toStringAsFixed(1)} C'),
      ),
      (
        'Humidity',
        BotIcons.drop,
        or(s.humidity, () => '${s.humidity!.round()}%'),
      ),
      ('Light', BotIcons.sun, or(s.light, () => '${s.light} / 1023')),
      ('Dark room', BotIcons.moon, s.dark ? 'Yes' : 'No'),
      (
        'Distance',
        BotIcons.person,
        or(s.distanceCm, () => '${s.distanceCm} cm'),
      ),
      ('Sitting', BotIcons.person, HomeScreen.sittingLabel(os.sittingFor)),
      (
        'Clock temp',
        BotIcons.clock,
        or(s.rtcTempC, () => '${s.rtcTempC!.toStringAsFixed(1)} C'),
      ),
      ('Bluetooth', BotIcons.bluetooth, w.linked ? 'Linked' : 'Waiting'),
    ];
  }

  @override
  int get count => 8;

  @override
  String get title => 'Room';

  @override
  void drawRow(Gfx g, int i, int y, bool selected) {
    final r = _rows(os.world)[i];
    BotUi.listRow(
      g,
      y: y,
      label: r.$1,
      icon: r.$2,
      value: r.$3,
      selected: selected,
    );
  }

  @override
  void select(int i) {}
}

// --- settings -----------------------------------------------------------------

class SettingsScreen extends ListScreen {
  SettingsScreen(super.os);

  @override
  int get count => 4;

  @override
  String get title => 'Settings';

  @override
  void drawRow(Gfx g, int i, int y, bool selected) {
    final s = os.settings;
    final (label, value) = switch (i) {
      0 => ('Sound', s.sound ? 'On' : 'Off'),
      1 => ('Brightness', const <String>['Low', 'Mid', 'High'][s.brightness]),
      2 => ('Home shows', s.faceHome ? 'Face' : 'Clock'),
      _ => ('BotOS', '1.2'),
    };
    BotUi.listRow(g, y: y, label: label, value: value, selected: selected);
  }

  @override
  void select(int i) {
    final s = os.settings;
    switch (i) {
      case 0:
        s.sound = !s.sound;
        os.emit(SaveSetting('sound', s.sound ? 1 : 0));
      case 1:
        s.brightness = (s.brightness + 1) % 3;
        os.emit(SaveSetting('brightness', s.brightness));
      case 2:
        s.faceHome = !s.faceHome;
        os.home.page = 0;
        os.emit(SaveSetting('faceHome', s.faceHome ? 1 : 0));
    }
  }
}
