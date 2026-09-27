/// The app side of a live link to a bot.
///
/// Owns one [Transport], one [FrameParser] and the request/reply rules that
/// `docs/PROTOCOL.md` §12 describes: the connect handshake, the status poll,
/// the heartbeat, and the atomic routine push.
///
/// Pure Dart. It knows nothing about Riverpod, Drift or widgets, so the same
/// object is driven by the app, by the tests, and by the desktop simulator.
library;

import 'dart:async';
import 'dart:typed_data';

import '../core/ff_constants.dart';
import 'frame_codec.dart';
import 'protocol.dart';
import 'transport/transport.dart';

/// A reply that never came. The link stays up: one lost reply is a retry, not
/// a disconnect.
class DeviceTimeoutException implements Exception {
  const DeviceTimeoutException(this.cmd, this.waited);
  final int cmd;
  final Duration waited;
  @override
  String toString() =>
      'No reply to ${FfCmd.name(cmd)} '
      'after ${waited.inMilliseconds} ms';
}

/// The device refused. Carries the reason so the UI can say which one in
/// plain words rather than showing a code.
class DeviceNackException implements Exception {
  const DeviceNackException(this.reason, this.raw);

  /// Null when the device sent a reason this build does not know.
  final NackReason? reason;
  final int raw;

  String get message =>
      reason?.message ?? 'The device refused (code 0x${raw.toRadixString(16)})';

  @override
  String toString() => 'DeviceNack: $message';
}

/// What a routine push did.
enum PushOutcome {
  /// Committed, and the device replied with its status.
  committed,

  /// The device rejected the commit checksum twice. **Nothing was written** —
  /// the device still holds the routine it had before.
  checksumFailed,

  /// The push did not finish: the link dropped or the device went quiet.
  interrupted,
}

class PushResult {
  const PushResult(this.outcome, {this.status, this.detail});
  final PushOutcome outcome;
  final DeviceStatus? status;
  final String? detail;
  bool get ok => outcome == PushOutcome.committed;
}

/// A live connection to a bot.
class DeviceLink {
  DeviceLink(
    this.transport, {
    Duration? statusPoll,
    Duration? heartbeat,
    this.replyTimeout = const Duration(seconds: 2),
    this.streamQuietPeriod = const Duration(milliseconds: 400),
    DateTime Function()? clock,
    void Function(String line)? onWireLog,
  }) : statusPoll = statusPoll ?? FfFirmware.statusPollInterval,
       heartbeatInterval = heartbeat ?? FfFirmware.heartbeatInterval,
       _clock = clock ?? DateTime.now,
       _onWireLog = onWireLog {
    _parser = FrameParser(
      clock: _clock,
      onDrop: (reason, detail) => _wire('!! drop ${reason.name} $detail'),
    );
  }

  final Transport transport;
  final Duration statusPoll;
  final Duration heartbeatInterval;
  final Duration replyTimeout;

  /// How long to wait after the last entry of a streamed reply before calling
  /// it finished.
  ///
  /// `0x40 LOG_REQ` and `0x23 ROUTINE_GET` stream n replies with **no
  /// terminator** — the device sends what it has, which may be fewer than
  /// asked for. Rather than change the wire format, the app treats a quiet gap
  /// as the end of the stream. At 9600 baud a 17-byte frame takes ~18 ms, so
  /// this window is an order of magnitude of headroom.
  final Duration streamQuietPeriod;

  final DateTime Function() _clock;
  final void Function(String)? _onWireLog;
  late final FrameParser _parser;

  StreamSubscription<Uint8List>? _bytesSub;
  Timer? _pollTimer;
  Timer? _heartbeatTimer;
  Timer? _resyncTimer;

  final StreamController<DeviceStatus> _statuses =
      StreamController<DeviceStatus>.broadcast();
  final StreamController<DeviceLogEntry> _logs =
      StreamController<DeviceLogEntry>.broadcast();
  final StreamController<DeviceNackException> _nacks =
      StreamController<DeviceNackException>.broadcast();

  /// Outstanding requests in send order. One flat list rather than a queue per
  /// command, because a NACK has to be matched to the oldest request overall —
  /// it does not say which command it refuses.
  final List<_PendingRequest> _waiting = <_PendingRequest>[];
  final List<Frame> _streamBuffer = <Frame>[];
  int? _streamingCmd;
  Completer<List<Frame>>? _streamDone;
  Timer? _streamQuietTimer;

  HelloAck? _helloAck;
  DeviceStatus? _lastStatus;
  bool _phoneLocked = false;
  bool _tracking = false;

  Stream<DeviceStatus> get statuses => _statuses.stream;
  Stream<DeviceLogEntry> get logEntries => _logs.stream;
  Stream<DeviceNackException> get nacks => _nacks.stream;
  Stream<LinkState> get states => transport.states;
  LinkState get state => transport.state;

  /// What the device declared at HELLO_ACK, or null before the handshake.
  HelloAck? get helloAck => _helloAck;

  /// Capabilities, or none when no device has introduced itself.
  ///
  /// Defaulting to *none* rather than to a guess matters: every factor is
  /// unavailable until a bot says otherwise, which is the honest starting
  /// state.
  DeviceCapabilities get capabilities =>
      _helloAck?.capabilities ?? const DeviceCapabilities.none();

  DeviceStatus? get lastStatus => _lastStatus;

  /// How many blocks this particular device can hold. Read from the device,
  /// never assumed, so a firmware with a bigger EEPROM map needs no app change.
  int get maxBlocks => _helloAck?.maxBlocks ?? FfFirmware.maxDeviceBlocks;

  // -- Lifecycle ---------------------------------------------------------------

  /// Connects the transport and runs the §12 handshake.
  ///
  /// Returns what the device declared. Throws [DeviceTimeoutException] if it
  /// never says hello — a paired-but-silent HC-05 is common enough (wrong
  /// baud, module in AT mode) that it needs a real error rather than a spinner
  /// that never stops.
  Future<HelloAck> connect() async {
    if (transport.state != LinkState.connected) {
      await transport.connect();
    }
    _bytesSub ??= transport.incoming.listen(_onBytes);
    _resyncTimer ??= Timer.periodic(
      kInterByteTimeout,
      (_) => _parser.resyncIfStale(_clock()),
    );

    final ack = HelloAck.decode(
      (await _request(helloFrame(), FfCmd.helloAck)).payload,
    );
    _helloAck = ack;
    _wire('   device ${ack.firmwareVersion} caps [${ack.capabilities}]');

    // The phone's clock is authoritative on connect: a DS3231 that lost its
    // coin cell would otherwise date every log entry wrongly.
    await send(setTimeFrame(_clock()));

    startPolling();
    return ack;
  }

  /// Begins the 5 s status poll. Called by [connect]; separate so a screen can
  /// stop and restart it.
  void startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(statusPoll, (_) => _pollOnce());
    _pollOnce();
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  void _pollOnce() {
    if (transport.state != LinkState.connected) return;
    // Registered as a request, not a bare send, so its reply is accounted for.
    // See [_request]: STATUS replies are matched to sends in order, and a poll
    // whose reply nobody claimed would shift every later match by one.
    unawaited(
      _request(
        statusReqFrame(),
        FfCmd.status,
      ).then<void>((_) {}).catchError((Object _) {}),
    );
  }

  /// Starts or stops the heartbeat.
  ///
  /// Sent **only while a tracked block is running** (`docs/PROTOCOL.md` §12):
  /// there is nothing to verify otherwise, and a 9600-baud link shared with
  /// status polls should stay quiet when it has nothing to say.
  void setTracking({required bool tracking, required bool phoneLocked}) {
    _phoneLocked = phoneLocked;
    if (tracking == _tracking) {
      if (tracking) _sendHeartbeat();
      return;
    }
    _tracking = tracking;
    _heartbeatTimer?.cancel();
    if (tracking) {
      _heartbeatTimer = Timer.periodic(
        heartbeatInterval,
        (_) => _sendHeartbeat(),
      );
      _sendHeartbeat();
    } else {
      _heartbeatTimer = null;
    }
  }

  void _sendHeartbeat() {
    if (transport.state != LinkState.connected) return;
    unawaited(
      send(heartbeatFrame(screenLocked: _phoneLocked)).catchError((_) {}),
    );
  }

  Future<void> disconnect() async {
    stopPolling();
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _resyncTimer?.cancel();
    _resyncTimer = null;
    _tracking = false;
    await _bytesSub?.cancel();
    _bytesSub = null;
    _failWaiting('link closed');
    await transport.disconnect();
  }

  Future<void> dispose() async {
    await disconnect();
    await transport.dispose();
    await _statuses.close();
    await _logs.close();
    await _nacks.close();
  }

  // -- Requests ----------------------------------------------------------------

  Future<void> send(Frame frame) async {
    _wire('>> ${FfCmd.name(frame.cmd)} ${frame.length} B');
    await transport.send(frame.encode());
  }

  /// Sends a frame and waits for the first unclaimed reply of [expect].
  ///
  /// The protocol carries no sequence numbers, so replies are matched to sends
  /// by command byte in FIFO order. That only stays correct if **every** frame
  /// the device sends is claimed by exactly one waiter — which is why the
  /// status poll, CONTROL and ROUTINE_COMMIT all go through here rather than
  /// through a bare [send]. An unclaimed STATUS shifts every later match by
  /// one, and the symptom is an app that shows the previous state.
  ///
  /// A `0xE0 NACK` arriving while a request is outstanding completes it with a
  /// [DeviceNackException] rather than letting it time out — the device has
  /// already answered, and waiting two more seconds to say so helps nobody.
  Future<Frame> _request(Frame frame, int expect, {Duration? timeout}) async {
    final pending = _PendingRequest(expect, Completer<Frame>());
    _waiting.add(pending);
    await send(frame);
    final wait = timeout ?? replyTimeout;
    try {
      return await pending.completer.future.timeout(
        wait,
        onTimeout: () {
          throw DeviceTimeoutException(frame.cmd, wait);
        },
      );
    } finally {
      _waiting.remove(pending);
    }
  }

  /// Sends a request whose reply is a *stream* of frames with no terminator.
  Future<List<Frame>> _requestStream(Frame frame, int expect) async {
    final done = Completer<List<Frame>>();
    _streamingCmd = expect;
    _streamBuffer.clear();
    _streamDone = done;
    _armStreamQuiet();
    await send(frame);
    return done.future;
  }

  void _armStreamQuiet() {
    _streamQuietTimer?.cancel();
    _streamQuietTimer = Timer(streamQuietPeriod, _finishStream);
  }

  void _finishStream() {
    final done = _streamDone;
    _streamQuietTimer?.cancel();
    _streamQuietTimer = null;
    _streamingCmd = null;
    _streamDone = null;
    if (done != null && !done.isCompleted) {
      done.complete(List<Frame>.of(_streamBuffer));
    }
    _streamBuffer.clear();
  }

  // -- Receive -----------------------------------------------------------------

  void _onBytes(Uint8List bytes) {
    for (final frame in _parser.feed(bytes)) {
      _wire('<< ${FfCmd.name(frame.cmd)} ${frame.length} B');
      _handle(frame);
    }
  }

  void _handle(Frame frame) {
    // Streamed replies first: they arrive as many frames of one command.
    if (_streamingCmd == frame.cmd) {
      _streamBuffer.add(frame);
      _armStreamQuiet();
    }

    try {
      switch (frame.cmd) {
        case FfCmd.status:
          final status = DeviceStatus.decode(frame.payload);
          _lastStatus = status;
          if (!_statuses.isClosed) _statuses.add(status);
        case FfCmd.logEntry:
          final entry = DeviceLogEntry.decode(frame.payload);
          if (!_logs.isClosed) _logs.add(entry);
        case FfCmd.nack:
          final raw = frame.length == 1 ? frame.payload[0] : 0;
          final nack = DeviceNackException(NackReason.fromWire(raw), raw);
          if (!_nacks.isClosed) _nacks.add(nack);
          // `UNKNOWN_CMD` is informational — the device says it ignored
          // something and carried on (`docs/PROTOCOL.md` §10). Failing an
          // unrelated request over it would turn forward compatibility into
          // an error. Any other reason fails the oldest outstanding request,
          // which is the one it answers.
          if (NackReason.fromWire(raw) != NackReason.unknownCmd) {
            _failOldestWaiting(nack);
          }
        default:
          // Unknown command: logged and ignored, never thrown. This is what
          // makes a newer device safe to plug into an older app.
          break;
      }
    } on ProtocolException catch (e) {
      // A malformed frame is a logged event, not a crash. The link stays up.
      _wire('!! ${e.message}');
    }

    for (var i = 0; i < _waiting.length; i++) {
      if (_waiting[i].expect == frame.cmd) {
        final pending = _waiting.removeAt(i);
        if (!pending.completer.isCompleted) pending.completer.complete(frame);
        break;
      }
    }
  }

  void _failOldestWaiting(Object error) {
    if (_waiting.isEmpty) return;
    final pending = _waiting.removeAt(0);
    if (!pending.completer.isCompleted) pending.completer.completeError(error);
  }

  void _completeWaitingWithError(Object error) {
    while (_waiting.isNotEmpty) {
      final pending = _waiting.removeAt(0);
      if (!pending.completer.isCompleted) {
        pending.completer.completeError(error);
      }
    }
  }

  void _failWaiting(String why) {
    _completeWaitingWithError(StateError(why));
    final done = _streamDone;
    _streamQuietTimer?.cancel();
    _streamQuietTimer = null;
    _streamingCmd = null;
    _streamDone = null;
    if (done != null && !done.isCompleted) {
      done.complete(List<Frame>.of(_streamBuffer));
    }
    _streamBuffer.clear();
  }

  void _wire(String line) => _onWireLog?.call('[wire] $line');

  // -- Operations --------------------------------------------------------------

  Future<DeviceStatus> requestStatus() async => DeviceStatus.decode(
    (await _request(statusReqFrame(), FfCmd.status)).payload,
  );

  /// Sends a control action and returns the status the device replies with.
  ///
  /// The reply is awaited rather than fired and forgotten: the device answers
  /// every CONTROL with a `0xB0 STATUS`, and an unclaimed one would shift the
  /// reply matching for everything after it.
  Future<DeviceStatus> control(ControlAction action, {int arg = 0}) async =>
      DeviceStatus.decode(
        (await _request(controlFrame(action, arg: arg), FfCmd.status)).payload,
      );

  /// What the bot's sensors read now (`0x31` / `0xB1`).
  Future<DeviceSensors> requestSensors() async => DeviceSensors.decode(
    (await _request(sensorReqFrame(), FfCmd.sensors)).payload,
  );

  /// Press one of the bot's controls from the phone.
  Future<void> sendInput(int key) => send(inputFrame(key));

  /// Open a BotOS app on the bot.
  Future<void> launch(int app, {int arg = 0}) =>
      send(launchFrame(app, arg: arg));

  Future<void> setConfig(Map<ConfigKey, int> values) =>
      send(configSetFrame(values));

  /// Pulls the device's day logs. The phone is the permanent archive, so this
  /// runs on every connect, before old days roll out of the 30-entry buffer.
  Future<List<DeviceLogEntry>> fetchLogs([int? days]) async {
    final frames = await _requestStream(
      logReqFrame(days ?? _helloAck?.eepromLogDays ?? FfFirmware.deviceLogDays),
      FfCmd.logEntry,
    );
    final out = <DeviceLogEntry>[];
    for (final f in frames) {
      try {
        out.add(DeviceLogEntry.decode(f.payload));
      } on ProtocolException catch (e) {
        // One bad entry loses one day, not the whole history.
        _wire('!! log entry skipped: ${e.message}');
      }
    }
    return out;
  }

  /// Reads back what the device is actually holding.
  Future<List<WireBlock>> fetchRoutine() async {
    final frames = await _requestStream(
      routineGetFrame(),
      FfCmd.routineBlockReply,
    );
    final byIndex = <int, WireBlock>{};
    for (final f in frames) {
      try {
        final (idx, block) = WireBlock.fromFrame(f.payload);
        byIndex[idx] = block;
      } on ProtocolException catch (e) {
        _wire('!! routine block skipped: ${e.message}');
      }
    }
    final keys = byIndex.keys.toList()..sort();
    return <WireBlock>[for (final k in keys) byIndex[k]!];
  }

  /// Pushes a routine, atomically.
  ///
  /// BEGIN → n × BLOCK → COMMIT, and **the device writes nothing until the
  /// commit checksum verifies** (`docs/PROTOCOL.md` §12). A half-written
  /// routine would be a corrupt device whose only recovery is a factory reset,
  /// so a failed push must leave the previous routine intact.
  ///
  /// A `ROUTINE_CRC` NACK retries the whole push once — a single corrupted
  /// block byte is the likely cause on a 9600-baud clone module, and it
  /// usually succeeds the second time.
  Future<PushResult> pushRoutine(List<WireBlock> blocks) async {
    if (blocks.length > maxBlocks) {
      return PushResult(
        PushOutcome.checksumFailed,
        detail:
            'This device holds $maxBlocks blocks; the routine has '
            '${blocks.length}',
      );
    }

    // The protocol has no sequence numbers, so a reply is matched by command
    // byte alone. A 5 s poll landing mid-push would satisfy the wait for the
    // commit's STATUS and the app would report success before the device had
    // decided. Silence the poll for the duration instead.
    final wasPolling = _pollTimer != null;
    stopPolling();
    try {
      return await _pushAttempts(blocks);
    } finally {
      if (wasPolling) startPolling();
    }
  }

  Future<PushResult> _pushAttempts(List<WireBlock> blocks) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        await send(routineBeginFrame(blocks.length));
        for (var i = 0; i < blocks.length; i++) {
          await send(blocks[i].toFrame(i));
        }
        final reply = await _request(
          routineCommitFrame(blocks),
          FfCmd.status,
          timeout: const Duration(seconds: 4), // an EEPROM write is slow
        );
        return PushResult(
          PushOutcome.committed,
          status: DeviceStatus.decode(reply.payload),
        );
      } on DeviceNackException catch (e) {
        if (e.reason == NackReason.routineCrc && attempt == 0) {
          _wire('   commit checksum failed, retrying the push once');
          continue;
        }
        return PushResult(PushOutcome.checksumFailed, detail: e.message);
      } on DeviceTimeoutException catch (e) {
        return PushResult(PushOutcome.interrupted, detail: e.toString());
      } on StateError catch (e) {
        return PushResult(PushOutcome.interrupted, detail: e.message);
      }
    }
    return const PushResult(PushOutcome.checksumFailed);
  }
}

/// One outstanding request: what reply command satisfies it, and who is
/// waiting.
class _PendingRequest {
  _PendingRequest(this.expect, this.completer);
  final int expect;
  final Completer<Frame> completer;
}
