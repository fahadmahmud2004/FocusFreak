/// The phone standing in as the bot.
///
/// * Upright, it is the bot itself: the same device as the Bot tab, screen,
///   knob, button and pads, large on black with nothing else around it.
/// * Sideways, the bot's screen fills the phone. Tap to pet, swipe to turn
///   the page; the gamepad button opens the controls down the side.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../botos/world.dart';
import '../../design/ff_tokens.dart';
import '../../platform/screen_channel.dart';
import 'bot_device.dart';
import 'botos_host.dart';
import 'oled_display.dart';

/// The panel's own palette: the OLED's white on black.
///
/// Deliberately not the app's theme. In this mode the phone *is* the device,
/// and it looks the same in every app theme. Near-black also costs almost
/// nothing on an OLED phone that may stay lit for a 90-minute block.
class _Mono {
  const _Mono._();
  static const Color bg = Color(0xFF000000);
  static const Color ink = OledDisplay.pixel;
  static const Color dim = Color(0x99E9F3FF);
  static const Color line = Color(0x55E9F3FF);
  static const Color faint = Color(0x26E9F3FF);
  static const Color well = Color(0xFF0A0B0D);
}

class BotFullscreenScreen extends ConsumerStatefulWidget {
  const BotFullscreenScreen({super.key, this.screen = const ScreenChannel()});

  final ScreenChannel screen;

  @override
  ConsumerState<BotFullscreenScreen> createState() =>
      _BotFullscreenScreenState();
}

/// How the panel handles the phone being turned over.
enum _Rotation {
  follow(Icons.screen_rotation_rounded, 'Rotation follows the phone'),
  upright(Icons.stay_current_portrait_rounded, 'Staying upright'),
  sideways(Icons.stay_current_landscape_rounded, 'Staying sideways');

  const _Rotation(this.icon, this.label);

  final IconData icon;
  final String label;

  _Rotation get next => _Rotation.values[(index + 1) % _Rotation.values.length];

  List<DeviceOrientation> get orientations => switch (this) {
    _Rotation.follow => DeviceOrientation.values,
    _Rotation.upright => const <DeviceOrientation>[
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ],
    _Rotation.sideways => const <DeviceOrientation>[
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ],
  };
}

class _BotFullscreenScreenState extends ConsumerState<BotFullscreenScreen> {
  _Rotation _rotation = _Rotation.follow;
  bool _controls = false;
  final Set<BotKey> _lit = <BotKey>{};
  DateTime _lastTouch = DateTime.now();
  Timer? _idle;
  bool _resting = false;
  double _dx = 0;

  /// After this long untouched the corner buttons fade almost away.
  static const Duration _restAfter = Duration(seconds: 4);

  /// A swipe this long is one turn of the knob.
  static const double _step = 44;

  @override
  void initState() {
    super.initState();
    // Immersive rather than edge-to-edge: a status bar full of notification
    // icons is exactly the distraction this screen exists to remove.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    widget.screen.setKeepAwake(keep: true);
    _idle = Timer.periodic(const Duration(seconds: 1), (_) {
      final rest = DateTime.now().difference(_lastTouch) > _restAfter;
      if (rest != _resting && mounted) setState(() => _resting = rest);
    });
  }

  @override
  void dispose() {
    _idle?.cancel();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    // Whatever this screen locked, the rest of the app gets back.
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    widget.screen.setKeepAwake(keep: false);
    super.dispose();
  }

  void _touched() {
    _lastTouch = DateTime.now();
    if (_resting) setState(() => _resting = false);
  }

  void _key(BotKey k) {
    _touched();
    ref.read(botOsProvider.notifier).key(k);
    unawaited(HapticFeedback.selectionClick());
    setState(() => _lit.add(k));
    Future<void>.delayed(const Duration(milliseconds: 150), () {
      if (mounted) setState(() => _lit.remove(k));
    });
  }

  void _pet() => _key(BotKey.touchLeft);

  void _cycleRotation() {
    final next = _rotation.next;
    SystemChrome.setPreferredOrientations(next.orientations);
    setState(() => _rotation = next);
    _touched();
  }

  void _toggleControls() {
    setState(() => _controls = !_controls);
    _touched();
  }

  @override
  Widget build(BuildContext context) {
    // Tap to pet, swipe to turn: on the screen itself in both modes, and on
    // the whole display when the controls are closed.
    Widget touchable(Widget child) => GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _pet,
      onHorizontalDragStart: (_) => _dx = 0,
      onHorizontalDragUpdate: (d) {
        _dx += d.delta.dx;
        while (_dx.abs() >= _step) {
          _key(_dx > 0 ? BotKey.left : BotKey.right);
          _dx -= _step * _dx.sign;
        }
      },
      child: child,
    );

    return Scaffold(
      backgroundColor: _Mono.bg,
      body: Listener(
        onPointerDown: (_) => _touched(),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, c) {
              final wide = c.maxWidth > c.maxHeight;
              final screen = touchable(const _Screen());
              final dock = _Dock(lit: _lit, onKey: _key, height: c.maxHeight);
              final Widget body;
              if (wide) {
                body = _controls
                    ? Row(
                        children: <Widget>[
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                FfSpace.xxl,
                                FfSpace.lg,
                                FfSpace.md,
                                FfSpace.lg,
                              ),
                              child: Center(child: screen),
                            ),
                          ),
                          dock,
                        ],
                      )
                    : touchable(
                        const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: FfSpace.xxxl,
                            vertical: FfSpace.lg,
                          ),
                          child: Center(child: _Screen()),
                        ),
                      );
              } else {
                // Upright: the bot, as on the Bot tab, as large as it fits.
                body = Padding(
                  padding: const EdgeInsets.fromLTRB(
                    FfSpace.lg,
                    FfSpace.xxxl + FfSpace.sm,
                    FfSpace.lg,
                    FfSpace.lg,
                  ),
                  child: Center(
                    // Laid out at the Bot tab's own width, then scaled to fill
                    // the phone, so it is the same bot, only bigger.
                    child: const FittedBox(
                      child: SizedBox(width: 400, child: BotDevice()),
                    ),
                  ),
                );
              }
              return Stack(
                children: <Widget>[
                  Positioned.fill(child: body),
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: AnimatedOpacity(
                      opacity: _resting && !_controls ? 0.35 : 0.9,
                      duration: FfMotion.slow,
                      child: _Corners(
                        rotation: _rotation,
                        controls: _controls,
                        showControlsButton: wide,
                        onRotate: _cycleRotation,
                        onControls: _toggleControls,
                        onClose: () => Navigator.of(context).maybePop(),
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

class _Corners extends StatelessWidget {
  const _Corners({
    required this.rotation,
    required this.controls,
    required this.showControlsButton,
    required this.onRotate,
    required this.onControls,
    required this.onClose,
  });

  final _Rotation rotation;
  final bool controls;
  final bool showControlsButton;
  final VoidCallback onRotate;
  final VoidCallback onControls;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(FfSpace.xs),
      child: Row(
        children: <Widget>[
          IconButton(
            tooltip: 'Leave full screen',
            icon: const Icon(Icons.close_rounded, color: _Mono.ink),
            onPressed: onClose,
          ),
          const Spacer(),
          if (showControlsButton)
            IconButton(
              tooltip: controls ? 'Hide controls' : 'Show controls',
              isSelected: controls,
              icon: const Icon(Icons.sports_esports_outlined, color: _Mono.ink),
              selectedIcon: const Icon(Icons.sports_esports, color: _Mono.ink),
              onPressed: onControls,
            ),
          IconButton(
            tooltip: rotation.label,
            icon: Icon(rotation.icon, color: _Mono.ink),
            onPressed: onRotate,
          ),
        ],
      ),
    );
  }
}

/// The bot's screen, as large as it will go.
class _Screen extends ConsumerWidget {
  const _Screen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Semantics(
      label: 'Bot screen. Tap to pet, swipe to turn the page',
      child: OledDisplay(frame: ref.watch(botOsProvider)),
    );
  }
}

// --- the controls -------------------------------------------------------------

/// The bot's controls down the right edge, for the phone held sideways: a jog
/// wheel for the knob and small buttons for the menu, back, pet and poke.
class _Dock extends StatelessWidget {
  const _Dock({required this.lit, required this.onKey, required this.height});

  final Set<BotKey> lit;
  final ValueChanged<BotKey> onKey;
  final double height;

  @override
  Widget build(BuildContext context) {
    Widget button(BotKey k, IconData icon, String label) => _IconKey(
      icon: icon,
      label: label,
      lit: lit.contains(k),
      onTap: () => onKey(k),
    );
    final menu = button(BotKey.button, Icons.menu_rounded, 'Menu');
    final pet = button(BotKey.touchLeft, Icons.favorite_border_rounded, 'Pet');
    final poke = button(BotKey.touchFront, Icons.touch_app_outlined, 'Poke');
    final back = button(BotKey.hold, Icons.undo_rounded, 'Back home');

    final jog = (height * 0.42).clamp(96.0, 150.0);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        FfSpace.sm,
        FfSpace.xxxl,
        FfSpace.xl,
        FfSpace.md,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              menu,
              const SizedBox(width: FfSpace.md),
              back,
            ],
          ),
          const SizedBox(height: FfSpace.md),
          _Jog(size: jog, lit: lit.contains(BotKey.press), onKey: onKey),
          const SizedBox(height: FfSpace.md),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              pet,
              const SizedBox(width: FfSpace.md),
              poke,
            ],
          ),
        ],
      ),
    );
  }
}

class _IconKey extends StatelessWidget {
  const _IconKey({
    required this.icon,
    required this.label,
    required this.lit,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool lit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        label: label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => onTap(),
          child: AnimatedContainer(
            duration: FfMotion.fast,
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: lit ? _Mono.ink : _Mono.bg,
              border: Border.all(color: _Mono.line),
            ),
            child: Icon(icon, size: 20, color: lit ? _Mono.bg : _Mono.ink),
          ),
        ),
      ),
    );
  }
}

/// The rotary encoder, as a jog wheel: circle a thumb round it to turn, tap
/// the middle to press, hold to go back. The touch is grabbed the moment it
/// lands, so a turn is never mistaken for anything else.
class _Jog extends StatefulWidget {
  const _Jog({required this.size, required this.lit, required this.onKey});

  final double size;
  final bool lit;
  final ValueChanged<BotKey> onKey;

  @override
  State<_Jog> createState() => _JogState();
}

class _JogState extends State<_Jog> {
  /// One detent every 22.5 degrees: a big wheel wants fewer steps per turn.
  static const double _detent = math.pi / 8;

  double _angle = 0;
  double? _last;
  double _accum = 0;
  Offset _down = Offset.zero;
  double _travel = 0;
  bool _turned = false;
  bool _held = false;
  Timer? _hold;

  Offset get _centre => Offset(widget.size / 2, widget.size / 2);

  void _start(Offset p) {
    _down = p;
    _travel = 0;
    _turned = false;
    _held = false;
    _last = null;
    _accum = 0;
    _hold?.cancel();
    _hold = Timer(const Duration(milliseconds: 550), () {
      if (_turned || _travel > 12) return;
      _held = true;
      widget.onKey(BotKey.hold);
    });
    _track(p);
  }

  void _track(Offset p) {
    _travel = math.max(_travel, (p - _down).distance);
    final v = p - _centre;
    if (v.distance < widget.size * 0.14) {
      _last = null;
      return;
    }
    final a = math.atan2(v.dy, v.dx);
    final last = _last;
    _last = a;
    if (last == null) return;
    var d = a - last;
    if (d > math.pi) d -= 2 * math.pi;
    if (d < -math.pi) d += 2 * math.pi;
    _accum += d;
    setState(() => _angle += d);
    while (_accum.abs() >= _detent) {
      _turned = true;
      widget.onKey(_accum > 0 ? BotKey.right : BotKey.left);
      _accum -= _detent * _accum.sign;
    }
  }

  void _end() {
    _hold?.cancel();
    if (!_turned && !_held && _travel < 14) widget.onKey(BotKey.press);
  }

  @override
  void dispose() {
    _hold?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Knob. Circle to turn, tap to press, hold to go back',
      button: true,
      onTap: () => widget.onKey(BotKey.press),
      onLongPress: () => widget.onKey(BotKey.hold),
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
                    _hold?.cancel();
                  }),
              ),
        },
        child: SizedBox.square(
          dimension: widget.size,
          child: CustomPaint(
            painter: _JogPainter(angle: _angle, lit: widget.lit),
          ),
        ),
      ),
    );
  }
}

class _JogPainter extends CustomPainter {
  _JogPainter({required this.angle, required this.lit});

  final double angle;
  final bool lit;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 1;
    canvas.drawCircle(c, r, Paint()..color = _Mono.well);
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = _Mono.line;
    canvas.drawCircle(c, r, ring);

    // Fine knurling that turns with the thumb.
    final tick = Paint()
      ..color = _Mono.faint
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 60; i++) {
      final a = angle + i * math.pi / 30;
      final dir = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(c + dir * (r - 8), c + dir * (r - 3), tick);
    }
    // The pointer.
    final dot = Offset(
      math.cos(angle - math.pi / 2),
      math.sin(angle - math.pi / 2),
    );
    canvas.drawCircle(c + dot * (r - 15), 2.5, Paint()..color = _Mono.ink);

    // The centre: press here.
    final inner = r * 0.34;
    canvas.drawCircle(c, inner, Paint()..color = lit ? _Mono.ink : _Mono.bg);
    canvas.drawCircle(c, inner, ring);
    canvas.drawCircle(
      c,
      inner * 0.18,
      Paint()..color = lit ? _Mono.bg : _Mono.dim,
    );
  }

  @override
  bool shouldRepaint(_JogPainter old) => old.angle != angle || old.lit != lit;
}
