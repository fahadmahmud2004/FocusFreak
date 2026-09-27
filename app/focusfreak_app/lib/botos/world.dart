/// What BotOS reads and what it asks for.
///
/// Pure data, no Flutter. The firmware fills the same fields from its pins
/// (`firmware/hardware_test/pins.h`); the app fills them from the virtual room
/// or from a connected bot's `0xB1 SENSORS` frames.
library;

/// Every physical control on the bot. The index is the wire value of
/// `0x71 INPUT` (`docs/PROTOCOL.md`).
enum BotKey {
  /// Rotary encoder, one detent anticlockwise (D18/D19).
  left,

  /// One detent clockwise.
  right,

  /// Encoder pushed in (D32): select.
  press,

  /// Encoder held for 0.6 s: back / options.
  hold,

  /// The push button (D34): menu and back.
  button,

  /// Top-left touch pad (D28).
  touchLeft,

  /// Top-right touch pad (D30).
  touchRight,

  /// Front touch pad (D42).
  touchFront;

  int get wire => index;

  static BotKey? fromWire(int v) =>
      v >= 0 && v < values.length ? values[v] : null;
}

/// The room, as the sensors report it. Null means that sensor has no reading,
/// and screens show it as missing rather than guessing.
class BotSensors {
  const BotSensors({
    this.tempC,
    this.humidity,
    this.light,
    this.dark = false,
    this.distanceCm,
    this.phoneParked,
    this.rtcTempC,
  });

  /// SHT21, °C.
  final double? tempC;

  /// SHT21, % relative humidity.
  final double? humidity;

  /// LDR analog level, 0 (dark) .. 1023 (bright).
  final int? light;

  /// LDR digital output: below the threshold set on the module's knob.
  final bool dark;

  /// HC-SR04, cm. Null when nothing echoes back.
  final int? distanceCm;

  /// TCRT5000 under the phone spot. Null when there is no IR sensor.
  final bool? phoneParked;

  /// The DS3231's own temperature sensor, a backup for the SHT21.
  final double? rtcTempC;

  /// Someone at the desk: the same 20..90 cm window the firmware uses.
  bool get present {
    final d = distanceCm;
    return d != null && d >= 20 && d <= 90;
  }
}

/// The block running, if any, as BotOS needs to draw it.
class BotSession {
  const BotSession({
    required this.name,
    required this.remaining,
    required this.progress,
    this.description = '',
    this.paused = false,
    this.armed = false,
    this.tracked = false,
    this.verified = false,
    this.nextName,
    this.index,
    this.count,
    this.key = '',
  });

  /// Changes whenever a different block starts, including the next block of
  /// a routine and a new routine replacing a running one. The screen follows
  /// every change, not just the first block after an idle bot.
  final String key;

  final String name;
  final String description;
  final Duration remaining;
  final double progress;
  final bool paused;

  /// Waiting for the phone to be locked or parked before it counts.
  final bool armed;
  final bool tracked;
  final bool verified;
  final String? nextName;

  /// Position in a routine, 1-based, when running one.
  final int? index;
  final int? count;
}

/// The bot's mood, from the session: the feedback channel, never a buzzer.
enum BotMood { calm, happy, sad, sleepy, searching }

/// Everything BotOS is told each frame.
class BotWorld {
  const BotWorld({
    required this.now,
    this.sensors = const BotSensors(),
    this.session,
    this.mood = BotMood.calm,
    this.linked = false,
    this.verifiedMinutesToday = 0,
    this.streak = 0,
  });

  final DateTime now;
  final BotSensors sensors;
  final BotSession? session;
  final BotMood mood;

  /// A phone is connected over Bluetooth (HC-05 STATE, D26).
  final bool linked;
  final int verifiedMinutesToday;
  final int streak;
}

/// Something BotOS wants done outside the screen.
sealed class BotEffect {
  const BotEffect();
}

/// Play a melody on the passive buzzer (D38).
class PlayMelody extends BotEffect {
  const PlayMelody(this.melody, {this.alarm = false});
  final Melody melody;

  /// An alarm ringing. Played at alarm volume, and by the phone even while a
  /// real bot is connected, because the alarm lives on the phone.
  final bool alarm;
}

/// A short tone on the passive buzzer, for clicks and game sounds.
class PlayTone extends BotEffect {
  const PlayTone(this.hz, this.ms);
  final int hz;
  final int ms;
}

/// Silence the buzzers.
class StopSound extends BotEffect {
  const StopSound();
}

/// Start a focus block of [minutes], from the bot's own timer menu.
class StartFocus extends BotEffect {
  const StartFocus(this.minutes);
  final int minutes;
}

/// Start one of the bot's own routines, by its index in [BotRoutines.all].
class StartRoutine extends BotEffect {
  const StartRoutine(this.index);
  final int index;
}

class PauseFocus extends BotEffect {
  const PauseFocus();
}

class ResumeFocus extends BotEffect {
  const ResumeFocus();
}

class SkipBlock extends BotEffect {
  const SkipBlock();
}

class StopFocus extends BotEffect {
  const StopFocus();
}

/// A settings value changed and should be saved.
class SaveSetting extends BotEffect {
  const SaveSetting(this.key, this.value);
  final String key;
  final int value;
}

/// A tune in RTTTL, the ringtone format Arduino buzzer players have read for
/// twenty years: `name:d=4,o=5,b=120:c,e,g,2c6`.
class Melody {
  const Melody(this.title, this.rtttl, {this.by = ''});

  final String title;
  final String rtttl;

  /// Composer or origin, for the list.
  final String by;
}
