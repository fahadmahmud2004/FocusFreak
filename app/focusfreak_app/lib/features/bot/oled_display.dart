import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../botos/gfx.dart';
import 'botos_host.dart';

/// The bot's 2.42" SSD1309, drawn from BotOS's framebuffer.
///
/// Pixel for pixel: every lit square here is a lit pixel on the panel. The
/// soft bloom around them and the faint gaps between them are what make a real
/// OLED look like light rather than a picture of one.
class OledDisplay extends StatelessWidget {
  const OledDisplay({super.key, required this.frame});

  final BotFrame frame;

  /// The lit colour of a white SSD1309 module.
  static const Color pixel = Color(0xFFE9F3FF);

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: Gfx.width / Gfx.height,
      child: RepaintBoundary(child: CustomPaint(painter: _OledPainter(frame))),
    );
  }
}

class _OledPainter extends CustomPainter {
  _OledPainter(this.frame);

  final BotFrame frame;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF020304),
    );

    final cell = size.width / Gfx.width;
    final px = frame.pixels;
    var lit = 0;
    for (final p in px) {
      lit += p;
    }
    if (lit == 0) return;

    final points = Float32List(lit * 2);
    var i = 0;
    for (var y = 0; y < Gfx.height; y++) {
      final row = y * Gfx.width;
      for (var x = 0; x < Gfx.width; x++) {
        if (px[row + x] != 0) {
          points[i++] = (x + 0.5) * cell;
          points[i++] = (y + 0.5) * cell;
        }
      }
    }

    final b = frame.brightness.clamp(0.15, 1.0);

    // Bloom first, under the pixels.
    canvas.drawRawPoints(
      ui.PointMode.points,
      points,
      Paint()
        ..color = OledDisplay.pixel.withValues(alpha: 0.22 * b)
        ..strokeWidth = cell * 1.6
        ..strokeCap = StrokeCap.round
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, cell * 1.1),
    );

    // The pixels: square, with the hairline gap a real panel has.
    canvas.drawRawPoints(
      ui.PointMode.points,
      points,
      Paint()
        ..color = OledDisplay.pixel.withValues(alpha: b)
        ..strokeWidth = cell < 2.5 ? cell * 1.02 : cell * 0.84
        ..strokeCap = StrokeCap.square,
    );
  }

  @override
  bool shouldRepaint(_OledPainter old) => old.frame.frame != frame.frame;
}
