/// Shared pieces of the bot's screens, so every screen looks like one device.
///
/// The visual language borrows from Flipper Zero, the most refined 128 × 64
/// one-bit UI in wide use: a quiet status line, bold titles, inverted rounded
/// selection bars, a dotted scrollbar, and key hints in the bottom corners.
library;

import 'gfx.dart';
import 'icons.dart';
import 'world.dart';

class BotUi {
  const BotUi._();

  /// Height of the status line, including its rule.
  static const int statusH = 10;

  /// Title or date on the left, live icons on the right, page dots in the
  /// middle when there are pages.
  static void statusBar(
    Gfx g,
    BotWorld w, {
    String? title,
    int pages = 0,
    int page = 0,
    bool playing = false,
  }) {
    g.color = 1;
    final t = w.now;
    final left =
        title ??
        '${t.hour.toString().padLeft(2, '0')}:'
            '${t.minute.toString().padLeft(2, '0')}';
    g.str(BotFonts.tiny, 1, 6, left.toUpperCase());

    var x = 127;
    void icon(List<String> rows) {
      x -= 9;
      g.bitmap(x, 0, rows.take(7).toList());
    }

    if (w.linked) icon(BotIcons.bluetooth);
    if (playing) icon(BotIcons.note);

    // The time, always: when the title takes the left, it sits on the right.
    if (title != null) {
      g.strRight(BotFonts.tiny, x - 2, 6, time(t));
    }

    if (pages > 1) {
      final width = pages * 4 - 1;
      var dx = 64 - width ~/ 2;
      for (var i = 0; i < pages; i++) {
        if (i == page) {
          g.box(dx, 2, 3, 3);
        } else {
          g.pixel(dx + 1, 3);
        }
        dx += 4;
      }
    }
    g.dottedH(0, 8, 128);
  }

  /// A row of a list: icon, label, optional value on the right.
  static void listRow(
    Gfx g, {
    required int y,
    required String label,
    List<String>? icon,
    String? value,
    bool selected = false,
    int width = 122,
  }) {
    const h = 13;
    g.color = 1;
    if (selected) g.rBox(0, y, width, h, 3);
    g.color = selected ? 0 : 1;
    var x = 4;
    if (icon != null) {
      g.bitmap(x, y + 3, icon);
      x += 12;
    }
    final valueW = value == null ? 0 : Gfx.strWidth(BotFonts.secondary, value);
    g.str(
      BotFonts.primary,
      x,
      y + 10,
      Gfx.fit(BotFonts.primary, label, width - x - valueW - 6),
    );
    if (value != null) {
      g.strRight(BotFonts.secondary, width - 4, y + 10, value);
    }
    g.color = 1;
  }

  /// The dotted track and solid thumb on the right edge.
  static void scrollbar(Gfx g, int index, int count, {int top = 11}) {
    if (count <= 1) return;
    final h = Gfx.height - top;
    for (var y = top; y < Gfx.height; y += 2) {
      g.pixel(126, y);
    }
    final thumb = (h / count).clamp(4, h).round();
    final y = top + ((h - thumb) * index / (count - 1)).round();
    g.box(125, y, 3, thumb);
  }

  /// A labelled key hint in a bottom corner, like `< Menu` or `OK >`.
  static void hint(Gfx g, String text, {bool right = false}) {
    final w = Gfx.strWidth(BotFonts.tiny, text) + 6;
    final x = right ? 128 - w : 0;
    g.color = 1;
    g.rBox(x, 56, w, 8, 2);
    g.color = 0;
    g.str(BotFonts.tiny, x + 3, 62, text);
    g.color = 1;
  }

  /// Rounded progress bar.
  static void progress(Gfx g, int x, int y, int w, int h, double value) {
    g.color = 1;
    g.rFrame(x, y, w, h, h ~/ 2);
    final fill = ((w - 4) * value.clamp(0.0, 1.0)).round();
    if (fill > 0) g.rBox(x + 2, y + 2, fill, h - 4, (h - 4) ~/ 2);
  }

  /// A small degree sign, which the ASCII fonts do not have.
  static void degree(Gfx g, int x, int y) {
    g.pixel(x + 1, y);
    g.pixel(x, y + 1);
    g.pixel(x + 2, y + 1);
    g.pixel(x + 1, y + 2);
  }

  /// The wall clock, `HH:MM`, from the RTC.
  static String time(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}';

  static String clock(Duration d) {
    final s = d.inSeconds < 0 ? 0 : d.inSeconds;
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    final sec = s % 60;
    String two(int v) => v.toString().padLeft(2, '0');
    return h > 0 ? '$h:${two(m)}:${two(sec)}' : '${two(m)}:${two(sec)}';
  }

  static const List<String> _days = <String>[
    'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN', //
  ];
  static const List<String> _months = <String>[
    'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', //
    'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
  ];

  static String date(DateTime t) =>
      '${_days[t.weekday - 1]} ${t.day} ${_months[t.month - 1]}';
}
