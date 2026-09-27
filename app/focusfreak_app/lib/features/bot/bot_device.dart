import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../botos/world.dart';
import '../../design/ff_theme.dart';
import '../../design/ff_tokens.dart';
import '../../design/ff_typography.dart';
import 'botos_host.dart';
import 'oled_display.dart';

/// The bot, drawn as the object on the desk, and every control on it works.
///
/// Two touch pads on top, the OLED, the ultrasonic sensor and the front pad
/// on the face, the push button, and the rotary encoder: drag around it, use
/// a scroll wheel, or the arrow keys. Press it to select, hold it to go back.
/// With a real bot connected, the same presses reach the real one.
class BotDevice extends ConsumerStatefulWidget {
  const BotDevice({super.key});

  @override
  ConsumerState<BotDevice> createState() => _BotDeviceState();
}

class _BotDeviceState extends ConsumerState<BotDevice> {
  final FocusNode _focus = FocusNode(debugLabel: 'bot');
  final Set<BotKey> _lit = <BotKey>{};
  double _knobAngle = 0;

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _press(BotKey k) {
    ref.read(botOsProvider.notifier).key(k);
    unawaited(HapticFeedback.selectionClick());
    setState(() {
      _lit.add(k);
      if (k == BotKey.left) _knobAngle -= math.pi / 10;
      if (k == BotKey.right) _knobAngle += math.pi / 10;
    });
    Future<void>.delayed(const Duration(milliseconds: 160), () {
      if (mounted) setState(() => _lit.remove(k));
    });
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final k = switch (e.logicalKey) {
      LogicalKeyboardKey.arrowLeft || LogicalKeyboardKey.arrowUp => BotKey.left,
      LogicalKeyboardKey.arrowRight ||
      LogicalKeyboardKey.arrowDown => BotKey.right,
      LogicalKeyboardKey.enter || LogicalKeyboardKey.space => BotKey.press,
      LogicalKeyboardKey.escape ||
      LogicalKeyboardKey.backspace => BotKey.button,
      LogicalKeyboardKey.keyH => BotKey.hold,
      LogicalKeyboardKey.digit1 => BotKey.touchLeft,
      LogicalKeyboardKey.digit2 => BotKey.touchRight,
      LogicalKeyboardKey.digit3 || LogicalKeyboardKey.keyF => BotKey.touchFront,
      _ => null,
    };
    if (k == null) return KeyEventResult.ignored;
    _press(k);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final frame = ref.watch(botOsProvider);
    final p = context.ff;

    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: LayoutBuilder(
            builder: (context, c) {
              final w = c.maxWidth;
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  // The two top pads sit on the top edge of the body.
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: w * 0.14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        _TopPad(
                          lit: _lit.contains(BotKey.touchLeft),
                          label: 'Pet left',
                          onTap: () => _press(BotKey.touchLeft),
                        ),
                        _TopPad(
                          lit: _lit.contains(BotKey.touchRight),
                          label: 'Pet right',
                          onTap: () => _press(BotKey.touchRight),
                        ),
                      ],
                    ),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: <Color>[Color(0xFF26282E), Color(0xFF15161A)],
                      ),
                      border: Border.all(color: p.borderStrong),
                      boxShadow: const <BoxShadow>[
                        BoxShadow(
                          color: Color(0x66000000),
                          blurRadius: 30,
                          offset: Offset(0, 14),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        FfSpace.lg,
                        FfSpace.lg,
                        FfSpace.lg,
                        FfSpace.md,
                      ),
                      child: Column(
                        children: <Widget>[
                          _Screen(
                            frame: frame,
                            onTap: () => _press(BotKey.touchLeft),
                          ),
                          const SizedBox(height: FfSpace.md),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: <Widget>[
                              _PushButton(
                                lit: _lit.contains(BotKey.button),
                                onTap: () => _press(BotKey.button),
                              ),
                              const Spacer(),
                              _FrontFace(
                                lit: _lit.contains(BotKey.touchFront),
                                onTap: () => _press(BotKey.touchFront),
                              ),
                              const Spacer(),
                              _Knob(
                                angle: _knobAngle,
                                lit:
                                    _lit.contains(BotKey.press) ||
                                    _lit.contains(BotKey.hold),
                                onTurn: (right) =>
                                    _press(right ? BotKey.right : BotKey.left),
                                onPress: () => _press(BotKey.press),
                                onHold: () => _press(BotKey.hold),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Screen extends StatelessWidget {
  const _Screen({required this.frame, required this.onTap});

  final BotFrame frame;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(FfSpace.sm),
        decoration: BoxDecoration(
          color: const Color(0xFF050607),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF30333A), width: 1.5),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Stack(
            children: <Widget>[
              OledDisplay(frame: frame),
              // The glass: a faint diagonal sheen over the panel.
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: <Color>[
                          Colors.white.withValues(alpha: 0.05),
                          Colors.transparent,
                          Colors.transparent,
                        ],
                        stops: const <double>[0, 0.35, 1],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopPad extends StatelessWidget {
  const _TopPad({required this.lit, required this.label, required this.onTap});

  final bool lit;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.ff;
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTapDown: (_) => onTap(),
        child: AnimatedContainer(
          duration: FfMotion.fast,
          width: 64,
          height: 14,
          margin: const EdgeInsets.only(bottom: 2),
          decoration: BoxDecoration(
            color: lit ? p.accent : const Color(0xFF2E3037),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            border: Border.all(color: lit ? p.accent : p.borderStrong),
            boxShadow: lit
                ? <BoxShadow>[
                    BoxShadow(
                      color: p.accent.withValues(alpha: 0.5),
                      blurRadius: 14,
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Container(
            width: 22,
            height: 3,
            decoration: BoxDecoration(
              color: lit ? Colors.black26 : p.textMuted.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    );
  }
}

/// The ultrasonic sensor's two transducers, with the front touch pad between
/// them.
class _FrontFace extends StatelessWidget {
  const _FrontFace({required this.lit, required this.onTap});

  final bool lit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.ff;
    Widget transducer() => Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          colors: <Color>[Color(0xFF3A3D45), Color(0xFF16171B)],
        ),
        border: Border.all(color: const Color(0xFF474A53), width: 2),
      ),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            transducer(),
            const SizedBox(width: FfSpace.sm),
            Semantics(
              button: true,
              label: 'Front touch pad',
              child: GestureDetector(
                onTapDown: (_) => onTap(),
                child: AnimatedContainer(
                  duration: FfMotion.fast,
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: lit ? p.accent : const Color(0xFF24262C),
                    border: Border.all(color: lit ? p.accent : p.borderStrong),
                    boxShadow: lit
                        ? <BoxShadow>[
                            BoxShadow(
                              color: p.accent.withValues(alpha: 0.55),
                              blurRadius: 16,
                            ),
                          ]
                        : null,
                  ),
                  child: Icon(
                    Icons.fingerprint_rounded,
                    size: 18,
                    color: lit ? Colors.black54 : p.textMuted,
                  ),
                ),
              ),
            ),
            const SizedBox(width: FfSpace.sm),
            transducer(),
          ],
        ),
        const SizedBox(height: FfSpace.xs),
        Text('TOUCH', style: FfType.overline.copyWith(color: p.textMuted)),
      ],
    );
  }
}

class _PushButton extends StatelessWidget {
  const _PushButton({required this.lit, required this.onTap});

  final bool lit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.ff;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Semantics(
          button: true,
          label: 'Menu button',
          child: GestureDetector(
            onTapDown: (_) => onTap(),
            child: AnimatedContainer(
              duration: FfMotion.fast,
              width: 40,
              height: 40,
              padding: EdgeInsets.all(lit ? 7 : 5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF0E0F12),
                border: Border.all(color: p.borderStrong),
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    center: const Alignment(-0.3, -0.4),
                    colors: lit
                        ? <Color>[p.accentBright, p.accent]
                        : const <Color>[Color(0xFF4A4D56), Color(0xFF26282E)],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: FfSpace.xs),
        Text('MENU', style: FfType.overline.copyWith(color: p.textMuted)),
      ],
    );
  }
}

/// The rotary encoder: turn by dragging around it, by scrolling, or with
/// the arrow keys; tap to press, long-press to hold.
///
/// The drag claims the finger the moment it lands. Before, the page's scroll
/// won any drag that started even slightly up or down, so turning the knob
/// scrolled the Bot tab unless you hit the rim exactly. The touch area is
/// also wider than the knob, and the drag keeps turning when the finger
/// wanders off it.
class _Knob extends StatefulWidget {
  const _Knob({
    required this.angle,
    required this.lit,
    required this.onTurn,
    required this.onPress,
    required this.onHold,
  });

  final double angle;
  final bool lit;
  final ValueChanged<bool> onTurn;
  final VoidCallback onPress;
  final VoidCallback onHold;

  @override
  State<_Knob> createState() => _KnobState();
}

class _KnobState extends State<_Knob> {
  static const double size = 76;

  /// The finger can land this far outside the knob and still turn it.
  static const double reach = 14;

  /// One detent every 20 degrees.
  static const double detent = math.pi / 9;

  double? _lastAngle;
  double _accum = 0;
  Offset _down = Offset.zero;
  double _travel = 0;
  bool _turned = false;
  bool _held = false;
  Timer? _holdTimer;

  static const Offset _centre = Offset(size / 2 + reach, size / 2 + reach);

  void _start(Offset local) {
    _down = local;
    _travel = 0;
    _turned = false;
    _held = false;
    _lastAngle = null;
    _accum = 0;
    _holdTimer?.cancel();
    _holdTimer = Timer(const Duration(milliseconds: 550), () {
      if (_turned || _travel > 10) return;
      _held = true;
      widget.onHold();
    });
    _track(local);
  }

  void _track(Offset local) {
    _travel = math.max(_travel, (local - _down).distance);
    final v = local - _centre;
    // Too close to the centre and the angle jumps about.
    if (v.distance < 10) {
      _lastAngle = null;
      return;
    }
    final a = math.atan2(v.dy, v.dx);
    final last = _lastAngle;
    _lastAngle = a;
    if (last == null) return;
    var d = a - last;
    if (d > math.pi) d -= 2 * math.pi;
    if (d < -math.pi) d += 2 * math.pi;
    _accum += d;
    while (_accum.abs() >= detent) {
      _turned = true;
      widget.onTurn(_accum > 0);
      _accum -= detent * _accum.sign;
    }
  }

  void _end() {
    _holdTimer?.cancel();
    if (!_turned && !_held && _travel < 12) widget.onPress();
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.ff;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Listener(
          onPointerSignal: (e) {
            if (e is PointerScrollEvent) widget.onTurn(e.scrollDelta.dy > 0);
          },
          child: Semantics(
            label: 'Rotary knob. Turn to browse, press to select',
            button: true,
            onTap: widget.onPress,
            onLongPress: widget.onHold,
            child: RawGestureDetector(
              behavior: HitTestBehavior.opaque,
              gestures: <Type, GestureRecognizerFactory>{
                GrabPanRecognizer:
                    GestureRecognizerFactoryWithHandlers<GrabPanRecognizer>(
                      GrabPanRecognizer.new,
                      (r) => r
                        ..dragStartBehavior = DragStartBehavior.down
                        ..onStart = ((d) {
                          _start(d.localPosition);
                        })
                        ..onUpdate = ((d) {
                          _track(d.localPosition);
                        })
                        ..onEnd = ((_) {
                          _end();
                        })
                        ..onCancel = (() {
                          _holdTimer?.cancel();
                        }),
                    ),
              },
              child: SizedBox(
                width: size + reach * 2,
                height: size + reach * 2,
                child: Padding(
                  padding: const EdgeInsets.all(reach),
                  child: CustomPaint(
                    painter: _KnobPainter(
                      angle: widget.angle,
                      lit: widget.lit,
                      accent: p.accent,
                      edge: p.borderStrong,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Text(
          'TURN · PRESS',
          style: FfType.overline.copyWith(color: p.textMuted),
        ),
      ],
    );
  }
}

/// A pan that wins the gesture arena as soon as the finger lands, so the
/// scrolling page underneath never gets the drag. Shared with the
/// full-screen bot's jog wheel.
class GrabPanRecognizer extends PanGestureRecognizer {
  GrabPanRecognizer({super.debugOwner});

  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    resolvePointer(event.pointer, GestureDisposition.accepted);
  }
}

class _KnobPainter extends CustomPainter {
  _KnobPainter({
    required this.angle,
    required this.lit,
    required this.accent,
    required this.edge,
  });

  final double angle;
  final bool lit;
  final Color accent;
  final Color edge;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;

    // Knurled rim.
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = const RadialGradient(
          colors: <Color>[Color(0xFF3B3E46), Color(0xFF1A1B20)],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    final ridge = Paint()
      ..color = const Color(0xFF55585F)
      ..strokeWidth = 1.2;
    for (var i = 0; i < 36; i++) {
      final a = angle + i * math.pi / 18;
      canvas.drawLine(
        c + Offset(math.cos(a), math.sin(a)) * (r - 5),
        c + Offset(math.cos(a), math.sin(a)) * (r - 1),
        ridge,
      );
    }
    // Cap.
    canvas.drawCircle(
      c,
      r - 7,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.45),
          colors: lit
              ? <Color>[accent, accent.withValues(alpha: 0.7)]
              : const <Color>[Color(0xFF50535B), Color(0xFF24262B)],
        ).createShader(Rect.fromCircle(center: c, radius: r - 7)),
    );
    canvas.drawCircle(
      c,
      r - 7,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = edge,
    );
    // The pointer notch turns with the knob.
    final tip =
        c +
        Offset(math.cos(angle - math.pi / 2), math.sin(angle - math.pi / 2)) *
            (r - 12);
    canvas.drawLine(
      c +
          Offset(math.cos(angle - math.pi / 2), math.sin(angle - math.pi / 2)) *
              (r - 20),
      tip,
      Paint()
        ..color = lit ? Colors.black54 : const Color(0xFFD7DAE0)
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_KnobPainter old) =>
      old.angle != angle || old.lit != lit || old.accent != accent;
}
