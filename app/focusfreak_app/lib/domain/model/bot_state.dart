import 'session_state.dart';
import 'verification.dart';

/// The device's six screen modes, from `docs/APP_SPEC.md`.
enum BotMode {
  /// D1 — the default. Big clock, date, comfort, next block, a small face.
  ambient,

  /// D2 — someone came within 70 cm. The face grows and looks at them.
  attention,

  /// D3 — a block is playing. Name, countdown, description, category bar.
  task,

  /// D4 — the head was touched. Full-screen happy face.
  pet,

  /// D5 — pairing. QR code and device name.
  pair,

  /// D6 — five minutes idle. Backlight down, small clock.
  dim;

  String get code => switch (this) {
    BotMode.ambient => 'D1',
    BotMode.attention => 'D2',
    BotMode.task => 'D3',
    BotMode.pet => 'D4',
    BotMode.pair => 'D5',
    BotMode.dim => 'D6',
  };

  String get label => switch (this) {
    BotMode.ambient => 'Ambient',
    BotMode.attention => 'Attention',
    BotMode.task => 'Task',
    BotMode.pet => 'Pet',
    BotMode.pair => 'Pair',
    BotMode.dim => 'Dim',
  };
}

/// One eye, parameterised exactly as the firmware `Eye` struct
/// (the firmware).
///
/// Bitmap sprites are never used, on the device or here: one 80×80 eye frame at
/// 16 bpp is 12.8 KB, and eight expressions across two eyes does not fit in
/// flash. Everything is drawn from these numbers, which costs ~2 KB of code and
/// gives unlimited expressions.
///
/// Keeping the app's parameters identical to the firmware's means values tuned
/// by eye here transfer straight into the C.
class EyeParams {
  const EyeParams({
    required this.width,
    required this.height,
    required this.radius,
    this.lidTop = 0,
    this.lidBottom = 0,
    this.slant = 0,
    this.offsetX = 0,
    this.offsetY = 0,
  });

  final double width;
  final double height;

  /// Corner radius. High values give the soft, friendly shape; low values read
  /// as alert or severe.
  final double radius;

  /// Eyelid coverage from the top, 0..1 of the height. Blinking is this going
  /// to 1 and back.
  final double lidTop;

  final double lidBottom;

  /// Inner-corner tilt in radians. Positive reads as angry or focused,
  /// negative as sad.
  final double slant;

  /// Gaze offset, in logical pixels from the resting position.
  final double offsetX;
  final double offsetY;

  EyeParams copyWith({
    double? width,
    double? height,
    double? radius,
    double? lidTop,
    double? lidBottom,
    double? slant,
    double? offsetX,
    double? offsetY,
  }) => EyeParams(
    width: width ?? this.width,
    height: height ?? this.height,
    radius: radius ?? this.radius,
    lidTop: lidTop ?? this.lidTop,
    lidBottom: lidBottom ?? this.lidBottom,
    slant: slant ?? this.slant,
    offsetX: offsetX ?? this.offsetX,
    offsetY: offsetY ?? this.offsetY,
  );

  static EyeParams lerp(EyeParams a, EyeParams b, double t) => EyeParams(
    width: _l(a.width, b.width, t),
    height: _l(a.height, b.height, t),
    radius: _l(a.radius, b.radius, t),
    lidTop: _l(a.lidTop, b.lidTop, t),
    lidBottom: _l(a.lidBottom, b.lidBottom, t),
    slant: _l(a.slant, b.slant, t),
    offsetX: _l(a.offsetX, b.offsetX, t),
    offsetY: _l(a.offsetY, b.offsetY, t),
  );

  static double _l(double a, double b, double t) => a + (b - a) * t;

  /// The resting shape each mood interpolates towards.
  ///
  /// The firmware keeps this as a PROGMEM table; here it is a switch. Same
  /// numbers either way.
  static EyeParams forMood(Mood mood) => switch (mood) {
    // Calm: wide open, soft corners, level. Content and attentive.
    Mood.calm => const EyeParams(width: 58, height: 58, radius: 18),

    // Searching: narrowed and slightly raised, as if scanning the room.
    Mood.searching => const EyeParams(
      width: 54,
      height: 46,
      radius: 14,
      lidTop: 0.12,
    ),

    // Sad: heavily lidded with a downward inner slant. This is the entire
    // punishment mechanism — no buzzer, no red alert.
    Mood.sad => const EyeParams(
      width: 54,
      height: 40,
      radius: 16,
      lidTop: 0.42,
      slant: -0.22,
      offsetY: 6,
    ),

    // Happy: the cat squint. The bottom lid rises rather than the top
    // falling, which is what reads as a smile rather than as sleepiness.
    Mood.happy => const EyeParams(
      width: 60,
      height: 34,
      radius: 17,
      lidBottom: 0.30,
    ),

    // Sleepy: mostly closed, drooping.
    Mood.sleepy => const EyeParams(
      width: 56,
      height: 26,
      radius: 13,
      lidTop: 0.55,
      offsetY: 8,
    ),
  };
}

/// Everything needed to draw the bot at one instant.
///
/// The single model behind the whole feature. It has two producers — the local
/// `VirtualBotEngine`, and the decoder for `0xB0 STATUS` frames from a real
/// device — and one consumer, `BotCanvas`. Connecting hardware swaps the
/// producer and changes nothing else.
class BotState {
  const BotState({
    required this.mode,
    required this.mood,
    required this.now,
    this.blockName = '',
    this.blockDescription = '',
    this.category = 0,
    this.remaining = Duration.zero,
    this.progress = 0,
    this.sessionState = SessionState.idle,
    this.trackEnabled = false,
    this.verification = VerificationSnapshot.none,
    this.nextBlockName,
    this.nextBlockAt,
    this.temperatureC,
    this.humidityPct,
    this.batteryPct,
    this.streak = 0,
    this.verifiedMinutesToday = 0,
    this.gazeX = 0,
    this.gazeY = 0,
    this.blink = 0,
    this.live = false,
    this.deviceName = 'FocusFreak',
    this.eyeShape,
  });

  final BotMode mode;
  final Mood mood;
  final DateTime now;

  final String blockName;
  final String blockDescription;
  final int category;
  final Duration remaining;
  final double progress;
  final SessionState sessionState;
  final bool trackEnabled;
  final VerificationSnapshot verification;

  final String? nextBlockName;
  final DateTime? nextBlockAt;

  /// Null when no sensor reports it. The panel is hidden rather than showing a
  /// plausible-looking guess.
  final double? temperatureC;
  final double? humidityPct;
  final int? batteryPct;

  final int streak;
  final int verifiedMinutesToday;

  /// Gaze direction, −1..1 on each axis.
  final double gazeX;
  final double gazeY;

  /// Blink progress, 0 = open, 1 = shut.
  final double blink;

  /// True when mirroring a physical device rather than simulating one.
  final bool live;

  final String deviceName;

  /// The blended eye shape partway through a mood change.
  ///
  /// Moods do not snap. The producer interpolates over 8 frames — the same
  /// count the firmware uses — and hands the intermediate shape through here.
  /// Without it the mood enum would jump and the transition would be lost.
  final EyeParams? eyeShape;

  static BotState initial(DateTime now) =>
      BotState(mode: BotMode.ambient, mood: Mood.calm, now: now);

  BotState copyWith({
    BotMode? mode,
    Mood? mood,
    DateTime? now,
    String? blockName,
    String? blockDescription,
    int? category,
    Duration? remaining,
    double? progress,
    SessionState? sessionState,
    bool? trackEnabled,
    VerificationSnapshot? verification,
    String? nextBlockName,
    DateTime? nextBlockAt,
    double? temperatureC,
    double? humidityPct,
    int? batteryPct,
    int? streak,
    int? verifiedMinutesToday,
    double? gazeX,
    double? gazeY,
    double? blink,
    bool? live,
    String? deviceName,
    EyeParams? eyeShape,
  }) => BotState(
    mode: mode ?? this.mode,
    mood: mood ?? this.mood,
    now: now ?? this.now,
    blockName: blockName ?? this.blockName,
    blockDescription: blockDescription ?? this.blockDescription,
    category: category ?? this.category,
    remaining: remaining ?? this.remaining,
    progress: progress ?? this.progress,
    sessionState: sessionState ?? this.sessionState,
    trackEnabled: trackEnabled ?? this.trackEnabled,
    verification: verification ?? this.verification,
    nextBlockName: nextBlockName ?? this.nextBlockName,
    nextBlockAt: nextBlockAt ?? this.nextBlockAt,
    temperatureC: temperatureC ?? this.temperatureC,
    humidityPct: humidityPct ?? this.humidityPct,
    batteryPct: batteryPct ?? this.batteryPct,
    streak: streak ?? this.streak,
    verifiedMinutesToday: verifiedMinutesToday ?? this.verifiedMinutesToday,
    gazeX: gazeX ?? this.gazeX,
    gazeY: gazeY ?? this.gazeY,
    blink: blink ?? this.blink,
    live: live ?? this.live,
    deviceName: deviceName ?? this.deviceName,
    eyeShape: eyeShape ?? this.eyeShape,
  );

  /// The eye shape to draw right now: the mood's resting shape, with the blink
  /// and gaze applied on top.
  EyeParams get eyes {
    final base = eyeShape ?? EyeParams.forMood(mood);
    return base.copyWith(
      // A blink squashes the height rather than sliding a lid down — the same
      // trick the firmware uses, and it is both cheaper and more convincing.
      height: base.height * (1 - blink * 0.92),
      offsetX: base.offsetX + gazeX * 10,
      offsetY: base.offsetY + gazeY * 7,
    );
  }
}
