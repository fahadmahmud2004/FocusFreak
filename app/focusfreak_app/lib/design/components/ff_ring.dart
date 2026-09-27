import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../ff_theme.dart';
import '../ff_tokens.dart';

/// The progress ring.
///
/// This is the app's echo of the device's WS2812B halo: a ring that depletes
/// as the block burns down, coloured by the block's category, and desaturated
/// the moment verification drops out. Reading it from across the room should
/// tell you the same thing the hardware tells you from across the desk.
class FfRing extends StatelessWidget {
  const FfRing({
    super.key,
    required this.progress,
    this.size = 220,
    this.thickness = 10,
    this.color,
    this.trackColor,
    this.child,
    this.dimmed = false,
    this.startAngle = -math.pi / 2,
    this.cap = StrokeCap.round,
  });

  /// 0.0 → 1.0. Values outside are clamped.
  final double progress;

  final double size;
  final double thickness;
  final Color? color;
  final Color? trackColor;
  final Widget? child;

  /// True while PAUSED — the ring keeps its position but loses its saturation,
  /// so a frozen timer is obvious without reading a word.
  final bool dimmed;

  final double startAngle;
  final StrokeCap cap;

  @override
  Widget build(BuildContext context) {
    final p = context.ff;
    final base = color ?? p.accent;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(
          progress: progress.clamp(0.0, 1.0),
          thickness: thickness,
          color: dimmed ? Color.lerp(base, p.textMuted, 0.65)! : base,
          trackColor: trackColor ?? p.surfaceRaised,
          startAngle: startAngle,
          cap: cap,
          glow: !dimmed && p.isDark,
        ),
        child: child == null ? null : Center(child: child),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.thickness,
    required this.color,
    required this.trackColor,
    required this.startAngle,
    required this.cap,
    required this.glow,
  });

  final double progress;
  final double thickness;
  final Color color;
  final Color trackColor;
  final double startAngle;
  final StrokeCap cap;
  final bool glow;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final centre = rect.center;
    final radius = (math.min(size.width, size.height) - thickness) / 2;
    final arcRect = Rect.fromCircle(center: centre, radius: radius);

    canvas.drawCircle(
      centre,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = thickness
        ..color = trackColor,
    );

    if (progress <= 0) return;

    // A soft outer bloom on dark themes, so the ring reads as emitted light
    // rather than painted plastic. Skipped in light mode, where it just muddies.
    if (glow) {
      canvas.drawArc(
        arcRect,
        startAngle,
        2 * math.pi * progress,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = thickness + 6
          ..strokeCap = cap
          ..color = color.withValues(alpha: 0.18)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }

    canvas.drawArc(
      arcRect,
      startAngle,
      2 * math.pi * progress,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = thickness
        ..strokeCap = cap
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.trackColor != trackColor ||
      old.thickness != thickness ||
      old.glow != glow;
}

/// A slim horizontal progress bar in the same visual language, for lists and
/// timeline rows where a full ring would be too heavy.
class FfProgressBar extends StatelessWidget {
  const FfProgressBar({
    super.key,
    required this.progress,
    this.color,
    this.height = 6,
    this.dimmed = false,
  });

  final double progress;
  final Color? color;
  final double height;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final p = context.ff;
    final base = color ?? p.accent;
    final fill = dimmed ? Color.lerp(base, p.textMuted, 0.65)! : base;
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: Stack(
        children: <Widget>[
          Container(height: height, color: p.surfaceRaised),
          FractionallySizedBox(
            widthFactor: progress.clamp(0.0, 1.0),
            child: AnimatedContainer(
              duration: FfMotion.fast,
              height: height,
              color: fill,
            ),
          ),
        ],
      ),
    );
  }
}
