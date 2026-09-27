/// What the app says out loud, and when.
///
/// Four cues and no more: a block starting, a block ending, the last three
/// seconds, and the alarm when a run is over. Deliberately absent is any sound
/// for a violation — the bot's mood is the feedback channel, and a noise every
/// time you stand up is the punishment ladder `docs/ARCHITECTURE.md`
/// removed.
///
/// Two switches, because the two are different jobs: the *effects* are
/// feedback while you are sitting there, the *alarm* is for when you are not.
/// Someone in a library wants the first off and the second on.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../botos/buzzer.dart';
import '../../botos/music.dart';
import '../../data/repo/settings_repository.dart';
import '../../platform/sound_player.dart';
import '../timer/session_controller.dart';

class SoundCues {
  SoundCues(this._out);

  final SoundOutput _out;

  /// The short cues: start, end, and the final-second ticks.
  bool effectsEnabled = true;

  /// The one that has to carry across a room.
  bool alarmEnabled = true;

  /// Which tone the alarm rings with: 0 is the app's own, anything else is
  /// `AlarmTones.all[alarmTone - 1]`.
  int alarmTone = 0;

  /// The names, in the order [alarmTone] counts them.
  static List<String> get toneNames => <String>[
    'FocusFreak',
    for (final t in AlarmTones.all) t.title,
  ];

  void onCue(SessionCue cue) {
    switch (cue) {
      case SessionCue.blockStarted:
        if (effectsEnabled) unawaited(_out.play(FfSound.blockStart));
      case SessionCue.blockEnded:
        if (effectsEnabled) unawaited(_out.play(FfSound.blockEnd));
      case SessionCue.finalSecond:
        if (effectsEnabled) unawaited(_out.play(FfSound.tick));
      case SessionCue.runCompleted:
        // The end of the last block gets the chime *and* the alarm when both
        // are on: the chime is the punctuation, the alarm is what reaches you
        // in the next room.
        if (effectsEnabled) unawaited(_out.play(FfSound.blockEnd));
        if (alarmEnabled) unawaited(playAlarm());
    }
  }

  /// Also used by the settings screen, to let it be heard before it matters.
  Future<void> playAlarm({int? tone}) {
    final t = tone ?? alarmTone;
    if (t <= 0 || t > AlarmTones.all.length) return _out.play(FfSound.alarm);
    // Three rounds of the tone: long enough to notice from the next room.
    final notes = Rtttl.parse(AlarmTones.all[t - 1].rtttl);
    return _out.playAlarmWave(
      Buzzer.melody(<Note>[...notes, ...notes, ...notes], volume: 0.3),
    );
  }

  Future<void> preview(FfSound sound) => _out.play(sound);

  Future<void> stopAlarm() => _out.stopAlarm();

  Future<void> dispose() => _out.dispose();
}

// -- Providers -----------------------------------------------------------------

/// Overridden in tests with [SilentSoundOutput].
final soundOutputProvider = Provider<SoundOutput>((ref) {
  final out = AudioSoundOutput();
  ref.onDispose(out.dispose);
  return out;
});

final soundEffectsEnabledProvider = StreamProvider<bool>(
  (ref) =>
      ref.watch(settingsRepositoryProvider).watchBool(SettingKey.soundEffects),
);

final alarmToneProvider = StreamProvider<int>(
  (ref) => ref.watch(settingsRepositoryProvider).watchInt(SettingKey.alarmTone),
);

final alarmEnabledProvider = StreamProvider<bool>(
  (ref) =>
      ref.watch(settingsRepositoryProvider).watchBool(SettingKey.alarmEnabled),
);

/// The live wiring, watched by the app shell so it exists for the whole
/// session rather than only while a screen that cares is on top.
final soundCuesProvider = Provider<SoundCues>((ref) {
  final cues = SoundCues(ref.watch(soundOutputProvider));

  final sub = ref
      .watch(sessionControllerProvider.notifier)
      .cues
      .listen(cues.onCue);
  ref.onDispose(sub.cancel);

  // Read once so a cue firing before the first stream event still obeys the
  // saved settings, then follow.
  void follow<T>(
    ProviderListenable<AsyncValue<T>> provider,
    void Function(T value) apply,
  ) {
    final current = ref.read(provider);
    if (current.hasValue) apply(current.requireValue);
    ref.listen<AsyncValue<T>>(provider, (_, next) {
      if (next.hasValue) apply(next.requireValue);
    });
  }

  follow<bool>(soundEffectsEnabledProvider, (v) => cues.effectsEnabled = v);
  follow<bool>(alarmEnabledProvider, (v) => cues.alarmEnabled = v);
  follow<int>(alarmToneProvider, (v) => cues.alarmTone = v);

  return cues;
});
