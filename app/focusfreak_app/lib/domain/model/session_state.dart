/// The session state machine, shared with the firmware.
///
/// Wire values are the enum indices — see `docs/PROTOCOL.md` §6.
enum SessionState {
  idle,
  armed,
  running,
  paused,
  complete,
  broken;

  int get wire => index;

  static SessionState fromWire(int v) =>
      v >= 0 && v < values.length ? values[v] : SessionState.idle;

  /// The timer only advances in [running]. [paused] deliberately freezes it —
  /// that freeze is the visible consequence of a verification drop-out.
  bool get countsTime => this == SessionState.running;

  bool get isActive =>
      this == SessionState.armed ||
      this == SessionState.running ||
      this == SessionState.paused;

  bool get isFinished =>
      this == SessionState.complete || this == SessionState.broken;

  String get label => switch (this) {
    SessionState.idle => 'Idle',
    SessionState.armed => 'Getting ready',
    SessionState.running => 'Running',
    SessionState.paused => 'Paused',
    SessionState.complete => 'Complete',
    SessionState.broken => 'Broken',
  };
}

/// The bot's five moods. This is the feedback channel — there is deliberately
/// no punishment ladder (`docs/ARCHITECTURE.md`).
enum Mood {
  calm,
  searching,
  sad,
  happy,
  sleepy;

  int get wire => index;

  static Mood fromWire(int v) =>
      v >= 0 && v < values.length ? values[v] : Mood.calm;
}

/// Why a session left [SessionState.running].
enum ViolationReason {
  /// Nobody at the desk.
  absent,

  /// The phone left the dock.
  undocked,

  /// The screen came on during a tracked block.
  screenOn,

  /// A distracting app was opened.
  distractingApp,

  /// No heartbeat from the phone for longer than the timeout.
  heartbeatLost,

  /// The user stopped it themselves.
  cancelled;

  String get label => switch (this) {
    ViolationReason.absent => 'Left the desk',
    ViolationReason.undocked => 'Phone picked up',
    ViolationReason.screenOn => 'Screen unlocked',
    ViolationReason.distractingApp => 'Opened another app',
    ViolationReason.heartbeatLost => 'Lost contact with the phone',
    ViolationReason.cancelled => 'Stopped manually',
  };
}

/// What a session's numbers are actually worth.
///
/// This is recorded per session and surfaced everywhere the numbers are. The
/// entire argument for the hardware existing is the difference between
/// [sensorVerified] and [appVerified]; blurring them would be arguing against
/// our own product.
enum Provenance {
  /// Tracking was off. A plain timer — honest, just not evidence.
  untracked,

  /// Verified by the phone alone: screen state, and optionally stillness and
  /// app usage. Cannot know whether you were at the desk.
  appVerified,

  /// Verified by the bot: presence, dock and screen-lock cross-checked.
  sensorVerified;

  String get label => switch (this) {
    Provenance.untracked => 'Untracked',
    Provenance.appVerified => 'App-verified',
    Provenance.sensorVerified => 'Sensor-verified',
  };

  String get explanation => switch (this) {
    Provenance.untracked =>
      'Tracking was off for this block, so these are elapsed minutes, '
          'not verified ones.',
    Provenance.appVerified =>
      'Verified by your phone only. The app can tell whether the screen '
          'stayed locked, but not whether you stayed at your desk.',
    Provenance.sensorVerified =>
      'Verified by your bot: you were at the desk, the phone was docked, '
          'and the screen stayed locked.',
  };
}
