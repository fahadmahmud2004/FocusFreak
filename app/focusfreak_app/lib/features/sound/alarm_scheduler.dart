/// Keeping one scheduled alarm in step with the running block.
///
/// `SoundCues` rings while the app is alive; this rings when it is not. Both
/// obey the same switch, because to the user they are one feature: "tell me
/// when the block is over".
///
/// The only real work here is *not* rescheduling. The session publishes every
/// second, and re-arming a system alarm sixty times a minute would be a
/// wakelock with a countdown attached.
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../botos/alarms.dart';
import '../../domain/model/session_state.dart';
import '../../platform/alarm_notifier.dart';
import '../bot/botos_host.dart';
import '../timer/session_controller.dart';
import 'sound_cues.dart';

class AlarmScheduler {
  AlarmScheduler(this._notifier, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final AlarmNotifier _notifier;
  final DateTime Function() _clock;

  /// Follows the same switch as the in-app alarm.
  bool enabled = true;

  /// A block ends when it ends; the odd second of drift between the engine's
  /// countdown and the system clock is not worth re-arming the alarm for.
  static const Duration _tolerance = Duration(seconds: 5);

  DateTime? _armedFor;
  String? _armedBlock;

  /// What is currently scheduled, for tests and for the settings screen.
  DateTime? get armedFor => _armedFor;

  /// Called on every session emit.
  void apply(SessionSnapshot session) {
    if (!enabled) {
      _clear();
      return;
    }

    // Only a *running* block has a knowable end time. A paused one is waiting
    // for the user — scheduling an alarm for a countdown that is not counting
    // would fire at a moment that means nothing.
    if (session.state != SessionState.running || session.block == null) {
      _clear();
      return;
    }

    final block = session.block!;
    final target = _clock().add(session.remaining);
    final moved =
        _armedFor == null ||
        target.difference(_armedFor!).abs() > _tolerance ||
        _armedBlock != block.id;
    if (!moved) return;

    _armedFor = target;
    _armedBlock = block.id;

    // The block is always named: a notification that says only "done" is one
    // you have to open the app to understand.
    final last = session.nextBlock == null;
    unawaited(
      _notifier.schedule(
        ScheduledAlarm(
          at: target,
          title: '${block.name} is done',
          body: last
              ? 'That is the run finished.'
              : 'Next up: ${session.nextBlock!.name}',
        ),
      ),
    );
  }

  void _clear() {
    if (_armedFor == null && _armedBlock == null) return;
    _armedFor = null;
    _armedBlock = null;
    unawaited(_notifier.cancel());
  }

  /// Nothing should outlive the app with an alarm still pending for a block
  /// that is no longer running.
  Future<void> dispose() => _notifier.cancel();
}

// -- Providers -----------------------------------------------------------------

/// Overridden in tests with [RecordingAlarmNotifier].
final alarmNotifierProvider = Provider<AlarmNotifier>(
  (ref) => LocalAlarmNotifier(),
);

/// Live wiring, watched by the app so it exists for the whole session.
final alarmSchedulerProvider = Provider<AlarmScheduler>((ref) {
  final scheduler = AlarmScheduler(ref.watch(alarmNotifierProvider));

  ref.listen<SessionSnapshot>(
    sessionControllerProvider,
    (_, next) => scheduler.apply(next),
    fireImmediately: true,
  );

  // The same switch as the in-app alarm: one feature, one setting.
  final enabled = ref.read(alarmEnabledProvider);
  if (enabled.hasValue) scheduler.enabled = enabled.requireValue;
  ref.listen<AsyncValue<bool>>(alarmEnabledProvider, (_, next) {
    if (!next.hasValue) return;
    scheduler.enabled = next.requireValue;
    // Turning it off has to take back what is already scheduled, not just
    // stop the next one.
    scheduler.apply(ref.read(sessionControllerProvider));
  });

  ref.onDispose(scheduler.dispose);
  return scheduler;
});

/// Hands the wake-up alarms to the system while the app is away.
///
/// While the app is open BotOS rings them itself, with the bot's screen and
/// the snooze. When it goes to the background the next ring of every alarm
/// is scheduled as a system alarm, and taken back on return, so an alarm
/// rings once and never twice.
class WakeAlarmSync with WidgetsBindingObserver {
  WakeAlarmSync(this._notifier, this._alarms, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final AlarmNotifier _notifier;
  final List<BotAlarm> Function() _alarms;
  final DateTime Function() _clock;

  bool _away = false;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        leave();
      case AppLifecycleState.resumed:
        back();
      case AppLifecycleState.inactive:
        break;
    }
  }

  /// The app is going out of sight.
  void leave() {
    _away = true;
    final now = _clock();
    final alarms = _alarms();
    for (var i = 0; i < alarms.length; i++) {
      final at = alarms[i].nextAfter(now);
      if (at == null) {
        unawaited(_notifier.cancelWake(i));
        continue;
      }
      unawaited(
        _notifier.scheduleWake(
          i,
          ScheduledAlarm(
            at: at,
            title: 'Alarm ${alarms[i].time}',
            body: 'Open FocusFreak to stop it.',
          ),
        ),
      );
    }
  }

  /// Back in front: BotOS rings them again.
  void back() {
    if (!_away) return;
    _away = false;
    for (var i = 0; i < BotAlarm.slots; i++) {
      unawaited(_notifier.cancelWake(i));
    }
  }
}

/// Live wiring, watched by the app.
final wakeAlarmSyncProvider = Provider<WakeAlarmSync>((ref) {
  // Builds the bot, which loads the saved alarms.
  ref.watch(botOsProvider.notifier);
  final sync = WakeAlarmSync(
    ref.watch(alarmNotifierProvider),
    () => ref.read(botAlarmsProvider),
  );
  WidgetsBinding.instance.addObserver(sync);
  ref.onDispose(() => WidgetsBinding.instance.removeObserver(sync));
  return sync;
});
