/// The alarm that survives the app being closed.
///
/// `SoundCues` can only ring while the app is alive. This is the other half:
/// one scheduled notification, set when a block starts and moved whenever the
/// countdown does, so the end of a block reaches you from a pocket.
///
/// Behind a seam for the same reason as `SoundOutput` — the scheduling logic
/// is then testable with no notification service, and a platform that has none
/// degrades to silence rather than throwing. Named `AlarmNotifier` rather than
/// `Notifier` because Riverpod exports a class of that name.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// One alarm, described in the app's terms rather than the platform's.
class ScheduledAlarm {
  const ScheduledAlarm({
    required this.at,
    required this.title,
    required this.body,
  });

  final DateTime at;
  final String title;
  final String body;
}

abstract interface class AlarmNotifier {
  /// Asks for whatever the platform needs before it will show anything.
  /// Returns false when the user says no — which is not an error, just an app
  /// whose alarm is on-screen only.
  Future<bool> prepare();

  /// Replaces any pending alarm with this one.
  Future<void> schedule(ScheduledAlarm alarm);

  /// No alarm pending. Called whenever a block stops counting.
  Future<void> cancel();

  /// A wake-up alarm in its own slot, separate from the block alarm.
  Future<void> scheduleWake(int slot, ScheduledAlarm alarm);

  Future<void> cancelWake(int slot);
}

/// The real one.
class LocalAlarmNotifier implements AlarmNotifier {
  LocalAlarmNotifier([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  /// One id, because there is only ever one alarm: the end of the block that
  /// is running. Scheduling a second replaces the first by construction.
  static const int _alarmId = 1;

  /// The channel carries the sound, and **a channel's sound is fixed when the
  /// channel is created** — Android will not change it afterwards. Changing
  /// the tone later means a new channel id, which is also why the app does not
  /// offer a custom track.
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'ff_block_end',
    'Block finished',
    description: 'Rings when a block or a run finishes.',
    importance: Importance.max,
    sound: RawResourceAndroidNotificationSound('ff_alarm'),
    audioAttributesUsage: AudioAttributesUsage.alarm,
  );

  /// Web and macOS have no notification plugin in this build.
  static bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  bool _ready = false;

  @override
  Future<bool> prepare() async {
    if (!_supported) return false;
    try {
      if (!_ready) {
        tzdata.initializeTimeZones();
        await _plugin.initialize(
          settings: const InitializationSettings(
            android: AndroidInitializationSettings('@mipmap/ic_launcher'),
            iOS: DarwinInitializationSettings(),
          ),
        );
        final android = _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        await android?.createNotificationChannel(_channel);
        _ready = true;
      }

      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android != null) {
        final granted = await android.requestNotificationsPermission();
        // Exact alarms are a separate grant on 13+. Asked for, not demanded:
        // an inexact alarm that fires "some time after" the block ends is not
        // an alarm, but it is better than no app.
        await android.requestExactAlarmsPermission();
        return granted ?? false;
      }

      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      return await ios?.requestPermissions(alert: true, sound: true) ?? false;
    } on Object {
      return false;
    }
  }

  @override
  Future<void> schedule(ScheduledAlarm alarm) async {
    if (!_supported) return;
    if (!_ready && !await prepare()) return;

    // A time in the past would fire immediately, which is worse than not
    // firing: the block is over and the app already said so.
    if (!alarm.at.isAfter(DateTime.now())) return;

    try {
      await _plugin.zonedSchedule(
        id: _alarmId,
        title: alarm.title,
        body: alarm.body,
        scheduledDate: tz.TZDateTime.from(alarm.at, tz.local),
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            importance: Importance.max,
            priority: Priority.high,
            category: AndroidNotificationCategory.alarm,
            sound: _channel.sound,
            audioAttributesUsage: AudioAttributesUsage.alarm,
          ),
          iOS: const DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } on Object {
      // Most likely the exact-alarm grant was refused. The in-app cue still
      // plays; the app is quieter, not broken.
    }
  }

  @override
  Future<void> cancel() async {
    if (!_supported) return;
    try {
      await _plugin.cancel(id: _alarmId);
    } on Object {
      // Nothing pending, or no plugin on this platform.
    }
  }

  /// Wake-up alarms take ids from here up, one per slot.
  static const int _wakeBase = 100;

  @override
  Future<void> scheduleWake(int slot, ScheduledAlarm alarm) async {
    if (!_supported) return;
    if (!_ready && !await prepare()) return;
    if (!alarm.at.isAfter(DateTime.now())) return;
    try {
      await _plugin.zonedSchedule(
        id: _wakeBase + slot,
        title: alarm.title,
        body: alarm.body,
        scheduledDate: tz.TZDateTime.from(alarm.at, tz.local),
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            importance: Importance.max,
            priority: Priority.high,
            category: AndroidNotificationCategory.alarm,
            fullScreenIntent: true,
            sound: _channel.sound,
            audioAttributesUsage: AudioAttributesUsage.alarm,
          ),
          iOS: const DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } on Object {
      // Same as the block alarm: quieter, not broken.
    }
  }

  @override
  Future<void> cancelWake(int slot) async {
    if (!_supported) return;
    try {
      await _plugin.cancel(id: _wakeBase + slot);
    } on Object {
      // Nothing pending.
    }
  }
}

/// Records instead of notifying. Used by tests, and anywhere the platform has
/// no notifications.
class RecordingAlarmNotifier implements AlarmNotifier {
  final List<ScheduledAlarm> scheduled = <ScheduledAlarm>[];
  int cancels = 0;
  bool permitted = true;

  ScheduledAlarm? get pending => scheduled.isEmpty ? null : scheduled.last;

  @override
  Future<bool> prepare() async => permitted;

  @override
  Future<void> schedule(ScheduledAlarm alarm) async => scheduled.add(alarm);

  @override
  Future<void> cancel() async => cancels++;

  final Map<int, ScheduledAlarm> wakes = <int, ScheduledAlarm>{};

  @override
  Future<void> scheduleWake(int slot, ScheduledAlarm alarm) async =>
      wakes[slot] = alarm;

  @override
  Future<void> cancelWake(int slot) async => wakes.remove(slot);
}
