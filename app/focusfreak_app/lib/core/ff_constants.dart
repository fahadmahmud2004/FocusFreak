/// Constants shared with the firmware.
///
/// These are not app preferences. Every value here also exists in the
/// FocusFreak firmware (`firmware/focusfreak/pins.h`) and
/// the two copies must agree, or the app's virtual bot will behave differently
/// from the physical one and the demo will contradict itself.
///
/// `test/firmware_parity_test.dart` asserts these values. If you change one,
/// change the firmware in the same commit and update that test.
class FfFirmware {
  const FfFirmware._();

  // -- Presence (HC-SR04 ultrasonic, cm) --------------------------------------

  /// Closer than this and it is the desk edge or a book, not a person.
  static const int presenceMinCm = 20;

  /// Further than this and the chair is empty.
  static const int presenceMaxCm = 90;

  /// Approaching this close wakes the face into Attention mode.
  static const int attentionCm = 70;

  // -- Verification grace periods ---------------------------------------------
  //
  // The shape of these three numbers is the whole behaviour design: a short
  // forgiving window, a long recoverable window, then an honest break.

  /// Unverified for less than this: keep RUNNING. Getting a glass of water is
  /// not a violation.
  static const Duration graceRunning = Duration(seconds: 30);

  /// Unverified past [graceRunning] and up to this: PAUSED, timer frozen,
  /// mood goes SEARCHING. Restoring the conditions resumes cleanly.
  static const Duration gracePaused = Duration(minutes: 5);

  /// ARMED but never confirmed within this window falls back to IDLE.
  static const Duration armTimeout = Duration(seconds: 15);

  /// No `0x50 PHONE_HEARTBEAT` for this long means the phone is no longer a
  /// trustworthy verification channel.
  static const Duration heartbeatTimeout = Duration(seconds: 25);

  /// How often the app sends `0x50 PHONE_HEARTBEAT` while a tracked block runs.
  static const Duration heartbeatInterval = Duration(seconds: 10);

  /// How often the app polls `0x30 STATUS_REQ`.
  static const Duration statusPollInterval = Duration(seconds: 5);

  // -- Screen behaviour --------------------------------------------------------

  static const Duration attentionHold = Duration(seconds: 8);
  static const Duration petDisplay = Duration(seconds: 3);
  static const Duration dimAfter = Duration(minutes: 5);

  /// The device animates at 25 fps. The virtual bot matches it rather than
  /// running at 60, so what you tune in the app transfers to the firmware.
  static const int faceFps = 25;

  // -- Device capacity ---------------------------------------------------------

  /// EEPROM holds 16 × 48-byte blocks. Routines in the app may be longer, but
  /// only this many can be pushed.
  static const int maxDeviceBlocks = 16;

  /// Fixed-size `char name[16]` in the firmware `Block` struct.
  static const int blockNameMaxChars = 16;

  /// Fixed-size `char desc[24]`.
  static const int blockDescMaxChars = 24;

  /// The device's DayLog ring buffer. Past this, history exists only on the
  /// phone — which is why the app pulls logs on every connect.
  static const int deviceLogDays = 30;

  /// `start_min` sentinel meaning "run straight after the previous block"
  /// rather than at a wall-clock time.
  static const int sequentialStartMin = 0xFFFF;

  // -- Link ---------------------------------------------------------------------

  /// HC-05 serial rate. A full 16-block routine push is ~0.8 s at this speed.
  static const int baudRate = 9600;

  /// Bluetooth Classic Serial Port Profile.
  static const String sppUuid = '00001101-0000-1000-8000-00805F9B34FB';

  static const List<String> deviceNameHints = <String>['FocusFreak', 'HC-05'];
}

/// App-level constants that have no firmware counterpart.
class FfApp {
  const FfApp._();

  static const String name = 'Focus Freak';
  static const String tagline = 'Your daily focus buddy';

  /// Where the footer's link goes.
  static const String siteUrl = 'https://fahadmahmud.com';

  /// Bumped whenever the on-disk schema changes.
  static const int dbSchemaVersion = 1;

  /// A day "rolls over" at this hour, not at midnight — a Night Owl session
  /// that starts at 01:00 belongs to the previous day's log.
  static const int dayRolloverHour = 4;

  static const Duration defaultDailyGoal = Duration(hours: 4);
}
