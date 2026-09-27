/// A 128 × 64 one-bit framebuffer with U8g2's drawing calls.
///
/// This is the bot's screen as the firmware sees it. Every call here has a
/// U8g2 twin with the same arguments (`drawBox`, `drawRBox`, `drawStr` with a
/// baseline y, draw colour 0/1/2), so a screen written against [Gfx] ports to
/// the Arduino line for line, and the phone shows exactly the pixels the
/// SSD1309 will.
library;

import 'dart:math' as math;
import 'dart:typed_data';

part 'fonts.g.dart';

/// One glyph as U8g2 stores it: a bitmap plus its offset from the baseline.
class BotGlyph {
  const BotGlyph(this.w, this.h, this.x, this.y, this.dx, this.rows);

  final int w;
  final int h;

  /// Offset of the bitmap's left edge from the cursor.
  final int x;

  /// Offset of the bitmap's bottom edge above the baseline.
  final int y;

  /// Cursor advance.
  final int dx;

  /// One int per row, bit 0 is the leftmost pixel.
  final List<int> rows;
}

class BotFont {
  const BotFont({
    required this.ascent,
    required this.descent,
    required this.glyphs,
  });

  final int ascent;
  final int descent;
  final Map<int, BotGlyph> glyphs;
}

/// The fonts the firmware uses, by role.
class BotFonts {
  const BotFonts._();

  /// Bold titles. `helvB08`.
  static const BotFont primary = _primary;

  /// Small readable text. `haxrcorp4089`.
  static const BotFont secondary = _secondary;

  /// Monospace, for readings that should not jitter. `profont11`.
  static const BotFont mono = _mono;

  /// 4 × 6, for the status bar and captions.
  static const BotFont tiny = _tiny;

  /// 6 × 10, the plain workhorse.
  static const BotFont body = _body;

  /// Numerals only.
  static const BotFont big16 = _big16;
  static const BotFont big24 = _big24;
  static const BotFont big32 = _big32;
}

class Gfx {
  Gfx() : pixels = Uint8List(width * height);

  static const int width = 128;
  static const int height = 64;

  /// Row-major, one byte per pixel, 0 or 1.
  final Uint8List pixels;

  /// U8g2's draw colour: 1 sets, 0 clears, 2 inverts.
  int color = 1;

  void clear() => pixels.fillRange(0, pixels.length, 0);

  bool get(int x, int y) =>
      x >= 0 && y >= 0 && x < width && y < height && pixels[y * width + x] != 0;

  void pixel(int x, int y) {
    if (x < 0 || y < 0 || x >= width || y >= height) return;
    final i = y * width + x;
    pixels[i] = switch (color) {
      0 => 0,
      2 => pixels[i] ^ 1,
      _ => 1,
    };
  }

  void hLine(int x, int y, int w) {
    for (var i = 0; i < w; i++) {
      pixel(x + i, y);
    }
  }

  void vLine(int x, int y, int h) {
    for (var i = 0; i < h; i++) {
      pixel(x, y + i);
    }
  }

  void box(int x, int y, int w, int h) {
    for (var j = 0; j < h; j++) {
      hLine(x, y + j, w);
    }
  }

  void frame(int x, int y, int w, int h) {
    if (w <= 0 || h <= 0) return;
    hLine(x, y, w);
    if (h > 1) hLine(x, y + h - 1, w);
    if (h > 2) {
      vLine(x, y + 1, h - 2);
      if (w > 1) vLine(x + w - 1, y + 1, h - 2);
    }
  }

  /// Filled box with corners of radius [r].
  void rBox(int x, int y, int w, int h, int r) {
    if (w <= 0 || h <= 0) return;
    r = math.min(r, math.min(w, h) ~/ 2);
    for (var j = 0; j < h; j++) {
      final inset = _cornerInset(j, h, r);
      hLine(x + inset, y + j, w - 2 * inset);
    }
  }

  /// Outline box with corners of radius [r]: the edge pixels of [rBox].
  void rFrame(int x, int y, int w, int h, int r) {
    if (w <= 0 || h <= 0) return;
    r = math.min(r, math.min(w, h) ~/ 2);
    bool inside(int i, int j) {
      if (i < 0 || j < 0 || i >= w || j >= h) return false;
      final inset = _cornerInset(j, h, r);
      return i >= inset && i < w - inset;
    }

    for (var j = 0; j < h; j++) {
      for (var i = 0; i < w; i++) {
        if (inside(i, j) &&
            (!inside(i - 1, j) ||
                !inside(i + 1, j) ||
                !inside(i, j - 1) ||
                !inside(i, j + 1))) {
          pixel(x + i, y + j);
        }
      }
    }
  }

  static int _cornerInset(int j, int h, int r) {
    if (r <= 0) return 0;
    final d = j < r ? r - j : (j >= h - r ? j - (h - r - 1) : 0);
    if (d <= 0) return 0;
    final dy = d - 0.5;
    return (r - math.sqrt(math.max(0, r * r - dy * dy))).round();
  }

  void disc(int cx, int cy, int r) {
    for (var dy = -r; dy <= r; dy++) {
      final dx = math.sqrt(r * r - dy * dy).round();
      hLine(cx - dx, cy + dy, 2 * dx + 1);
    }
  }

  /// Filled ellipse, U8g2's `drawFilledEllipse`.
  void ellipse(int cx, int cy, int rx, int ry) {
    if (rx <= 0 || ry <= 0) return;
    for (var dy = -ry; dy <= ry; dy++) {
      final t = 1 - (dy * dy) / (ry * ry);
      final dx = (rx * math.sqrt(math.max(0, t))).round();
      hLine(cx - dx, cy + dy, 2 * dx + 1);
    }
  }

  void circle(int cx, int cy, int r) {
    var x = r;
    var y = 0;
    var err = 1 - r;
    while (x >= y) {
      for (final p in <(int, int)>[
        (x, y), (y, x), (-y, x), (-x, y), //
        (-x, -y), (-y, -x), (y, -x), (x, -y),
      ]) {
        pixel(cx + p.$1, cy + p.$2);
      }
      y++;
      if (err < 0) {
        err += 2 * y + 1;
      } else {
        x--;
        err += 2 * (y - x) + 1;
      }
    }
  }

  void line(int x0, int y0, int x1, int y1) {
    final dx = (x1 - x0).abs();
    final dy = -(y1 - y0).abs();
    final sx = x0 < x1 ? 1 : -1;
    final sy = y0 < y1 ? 1 : -1;
    var err = dx + dy;
    while (true) {
      pixel(x0, y0);
      if (x0 == x1 && y0 == y1) break;
      final e2 = 2 * err;
      if (e2 >= dy) {
        err += dy;
        x0 += sx;
      }
      if (e2 <= dx) {
        err += dx;
        y0 += sy;
      }
    }
  }

  /// Filled triangle, scanline by scanline.
  void triangle(int x0, int y0, int x1, int y1, int x2, int y2) {
    final minY = math.max(0, math.min(y0, math.min(y1, y2)));
    final maxY = math.min(height - 1, math.max(y0, math.max(y1, y2)));
    for (var y = minY; y <= maxY; y++) {
      final xs = <double>[];
      void edge(int ax, int ay, int bx, int by) {
        if (ay == by) return;
        final lo = math.min(ay, by);
        final hi = math.max(ay, by);
        if (y < lo || y > hi) return;
        xs.add(ax + (bx - ax) * (y - ay) / (by - ay));
      }

      edge(x0, y0, x1, y1);
      edge(x1, y1, x2, y2);
      edge(x2, y2, x0, y0);
      if (xs.isEmpty) continue;
      final a = xs.reduce(math.min).round();
      final b = xs.reduce(math.max).round();
      hLine(a, y, b - a + 1);
    }
  }

  // --- text -------------------------------------------------------------------

  /// Draws [text] with its baseline at [y], as U8g2's `drawStr` does, and
  /// returns the width it took.
  int str(BotFont font, int x, int y, String text) {
    var cx = x;
    for (final code in text.codeUnits) {
      final g = font.glyphs[code] ?? font.glyphs[63];
      if (g == null) continue;
      final top = y - (g.h + g.y);
      for (var r = 0; r < g.h; r++) {
        final bits = g.rows[r];
        if (bits == 0) continue;
        for (var c = 0; c < g.w; c++) {
          if ((bits >> c) & 1 == 1) pixel(cx + g.x + c, top + r);
        }
      }
      cx += g.dx;
    }
    return cx - x;
  }

  static int strWidth(BotFont font, String text) {
    var w = 0;
    for (final code in text.codeUnits) {
      w += (font.glyphs[code] ?? font.glyphs[63])?.dx ?? 0;
    }
    return w;
  }

  /// Centred on [cx].
  int strCenter(BotFont font, int cx, int y, String text) =>
      str(font, cx - strWidth(font, text) ~/ 2, y, text);

  /// Right-aligned to end at [right].
  int strRight(BotFont font, int right, int y, String text) =>
      str(font, right - strWidth(font, text), y, text);

  /// Cuts [text] with an ellipsis so it fits in [maxWidth].
  static String fit(BotFont font, String text, int maxWidth) {
    if (strWidth(font, text) <= maxWidth) return text;
    var t = text;
    while (t.isNotEmpty && strWidth(font, '$t..') > maxWidth) {
      t = t.substring(0, t.length - 1);
    }
    return '${t.trimRight()}..';
  }

  // --- bitmaps ----------------------------------------------------------------

  /// Draws a bitmap given as rows of '#' and '.'.
  void bitmap(int x, int y, List<String> rows) {
    for (var r = 0; r < rows.length; r++) {
      final row = rows[r];
      for (var c = 0; c < row.length; c++) {
        if (row.codeUnitAt(c) == 35) pixel(x + c, y + r);
      }
    }
  }

  /// A dotted rule, the separator Flipper-style screens use.
  void dottedH(int x, int y, int w) {
    for (var i = 0; i < w; i += 2) {
      pixel(x + i, y);
    }
  }
}
