import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../device/protocol.dart';
import '../../domain/engine/routine_clock.dart';
import '../../domain/model/session_state.dart';
import '../timer/session_controller.dart';
import 'device_controller.dart';

/// Keeps a connected bot on the routine the app is running.
///
/// The bot holds 16 blocks and a full FW day holds up to 35, so it is never
/// sent the whole routine. It gets the stretch from the current block on, and
/// the next stretch when the app runs past the end of that one. Each push is
/// followed by a start, so the block on the desk is the block on the phone.
///
/// The first block of a push carries only what is left of it — a routine that
/// follows the clock joins its block part-way, and the bot's countdown has to
/// agree with the phone's. The protocol has no offset field, so the shortened
/// length is sent as the duration instead.
///
/// Only the user's own actions are forwarded. Each side runs its own
/// verification, and a pause because *this* side lost sight of you is not an
/// instruction for the other one.
class RoutineDeviceSync {
  RoutineDeviceSync(this._device);

  final DeviceController _device;

  /// The run the bot is on, by identity: every start builds a new queue.
  List<Object>? _run;
  int _windowStart = 0;
  int _windowEnd = 0;
  int _index = -1;
  bool _pausedByUser = false;

  Future<void> _pending = Future<void>.value();

  /// Called on every session snapshot and every connect or disconnect.
  /// Updates are applied one at a time, in order.
  Future<void> update(SessionSnapshot s, {required bool connected}) =>
      _pending = _pending.then((_) => _apply(s, connected));

  Future<void> _apply(SessionSnapshot s, bool connected) async {
    if (!connected) {
      // Whatever the bot had is stale by the time it is back. Forgetting the
      // run makes the reconnect push from wherever the phone is then.
      _run = null;
      return;
    }

    // A routine or a single timer: either way the bot should be running it,
    // so the countdown on the desk matches the one on the phone.
    final running = s.isActive && s.queue.isNotEmpty;
    if (!running) {
      if (_run != null && s.state == SessionState.idle) {
        _run = null;
        await _device.control(ControlAction.stop);
      }
      return;
    }

    final index = s.queueIndex;
    if (!identical(s.queue, _run) ||
        index < _windowStart ||
        index >= _windowEnd) {
      await _push(s);
      return;
    }
    if (index != _index) {
      _index = index;
      await _device.control(ControlAction.start, arg: index - _windowStart);
    }
    if (s.pausedByUser != _pausedByUser) {
      _pausedByUser = s.pausedByUser;
      await _device.control(
        s.pausedByUser ? ControlAction.pause : ControlAction.resume,
      );
    }
  }

  Future<void> _push(SessionSnapshot s) async {
    final window = RoutineClock.deviceWindow(s.queue.length, s.queueIndex);
    final wire = <WireBlock>[
      for (var i = window.start; i < window.end; i++)
        WireBlock(
          name: s.queue[i].name,
          description: s.queue[i].description,
          durationMin: i == window.start
              ? _minutesLeft(s.remaining)
              : s.queue[i].duration.inMinutes,
          category: s.queue[i].category,
          trackEnabled: s.queue[i].trackEnabled,
        ),
    ];
    final report = await _device.pushWire(wire);
    if (!report.ok) return;

    _run = s.queue;
    _windowStart = window.start;
    _windowEnd = window.end;
    _index = s.queueIndex;
    _pausedByUser = false;
    await _device.control(ControlAction.start);
    if (s.pausedByUser) {
      _pausedByUser = true;
      await _device.control(ControlAction.pause);
    }
  }

  /// Rounded up: a block with 30 seconds left is still a block, and a
  /// zero-minute one would finish on the bot before it started.
  static int _minutesLeft(Duration remaining) {
    final minutes = (remaining.inSeconds + 59) ~/ 60;
    return minutes < 1 ? 1 : minutes;
  }
}

/// Watched from the app root, like the auto-connect, so the bot follows the
/// routine whichever screen is open.
final routineDeviceSyncProvider = Provider<RoutineDeviceSync>((ref) {
  final sync = RoutineDeviceSync(ref.read(deviceControllerProvider.notifier));

  void run() => unawaited(
    sync.update(
      ref.read(sessionControllerProvider),
      connected: ref.read(deviceControllerProvider).isConnected,
    ),
  );

  ref.listen<SessionSnapshot>(sessionControllerProvider, (_, __) => run());
  ref.listen<bool>(
    deviceControllerProvider.select((s) => s.isConnected),
    (_, __) => run(),
  );
  return sync;
});
