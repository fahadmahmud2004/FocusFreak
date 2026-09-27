import 'dart:async';

import '../model/verification.dart';

/// Where verification readings come from.
///
/// The whole point of the abstraction: the session engine never knows whether
/// a factor came from an ultrasonic sensor on a desk or from an Android
/// broadcast receiver. It only sees factors and their three possible states.
/// Connecting a bot swaps the implementation and changes nothing downstream.
abstract class VerificationSource {
  /// Factors this source can speak to at all. Anything outside this set is
  /// reported as [FactorState.unavailable] rather than guessed.
  Set<VerificationFactor> get providedFactors;

  /// The current reading.
  VerificationSnapshot read({required bool trackEnabled});

  /// Emits when a factor changes, for sources that can push.
  Stream<void> get changes;

  Future<void> dispose() async {}
}

/// No source at all.
///
/// Used before onboarding grants anything, and in tests. Reports every factor
/// unavailable, which means a tracked block cannot be verified — the correct,
/// honest outcome when there is no evidence to be had.
class NullVerificationSource implements VerificationSource {
  const NullVerificationSource();

  @override
  Set<VerificationFactor> get providedFactors => const <VerificationFactor>{};

  @override
  VerificationSnapshot read({required bool trackEnabled}) =>
      VerificationSnapshot(
        trackEnabled: trackEnabled,
        factors: const <VerificationFactor, FactorState>{},
      );

  @override
  Stream<void> get changes => const Stream<void>.empty();

  @override
  Future<void> dispose() async {}
}

/// A source driven by explicitly-set values.
///
/// Backs three things: unit tests, the on-device demo mode, and the virtual
/// bot's manual controls.
class ManualVerificationSource implements VerificationSource {
  ManualVerificationSource({Set<VerificationFactor>? provides})
    : _provides =
          provides ??
          <VerificationFactor>{
            VerificationFactor.presence,
            VerificationFactor.dock,
            VerificationFactor.screenLock,
          };

  final Set<VerificationFactor> _provides;
  final Map<VerificationFactor, FactorState> _states =
      <VerificationFactor, FactorState>{};
  final StreamController<void> _changes = StreamController<void>.broadcast();

  @override
  Set<VerificationFactor> get providedFactors => _provides;

  void set(VerificationFactor factor, bool holding) {
    if (!_provides.contains(factor)) return;
    _states[factor] = holding ? FactorState.holding : FactorState.violated;
    if (!_changes.isClosed) _changes.add(null);
  }

  void setAll(bool holding) {
    for (final f in _provides) {
      _states[f] = holding ? FactorState.holding : FactorState.violated;
    }
    if (!_changes.isClosed) _changes.add(null);
  }

  @override
  VerificationSnapshot read({required bool trackEnabled}) =>
      VerificationSnapshot(
        trackEnabled: trackEnabled,
        factors: <VerificationFactor, FactorState>{
          for (final f in _provides) f: _states[f] ?? FactorState.holding,
        },
      );

  @override
  Stream<void> get changes => _changes.stream;

  @override
  Future<void> dispose() async => _changes.close();
}

/// Combines several sources, preferring whichever actually has a reading.
///
/// This is how the bot and the phone coexist. When a bot is connected it
/// supplies presence and dock; the phone continues to supply screen-lock and
/// app-usage. Neither has to know about the other, and unplugging the bot
/// degrades to app-only verification rather than failing.
class CompositeVerificationSource implements VerificationSource {
  CompositeVerificationSource(this._sources);

  final List<VerificationSource> _sources;

  @override
  Set<VerificationFactor> get providedFactors =>
      _sources.expand((s) => s.providedFactors).toSet();

  @override
  VerificationSnapshot read({required bool trackEnabled}) {
    final merged = <VerificationFactor, FactorState>{};
    for (final source in _sources) {
      final snapshot = source.read(trackEnabled: trackEnabled);
      for (final entry in snapshot.factors.entries) {
        // A real reading always beats an "unavailable" from another source.
        final existing = merged[entry.key];
        if (existing == null || existing == FactorState.unavailable) {
          merged[entry.key] = entry.value;
        } else if (entry.value == FactorState.violated) {
          // Any source reporting a violation wins: it saw something the
          // others did not, and verification must be the strict reading.
          merged[entry.key] = FactorState.violated;
        }
      }
    }
    return VerificationSnapshot(trackEnabled: trackEnabled, factors: merged);
  }

  @override
  Stream<void> get changes {
    if (_sources.isEmpty) return const Stream<void>.empty();
    return StreamGroup.merge(_sources.map((s) => s.changes));
  }

  @override
  Future<void> dispose() async {
    for (final s in _sources) {
      await s.dispose();
    }
  }
}

/// Minimal stream merge, so the domain layer keeps zero package dependencies.
class StreamGroup {
  const StreamGroup._();

  static Stream<T> merge<T>(Iterable<Stream<T>> streams) {
    final list = streams.toList(growable: false);
    if (list.isEmpty) return const Stream.empty();
    if (list.length == 1) return list.single;

    late StreamController<T> controller;
    final subs = <StreamSubscription<T>>[];

    controller = StreamController<T>.broadcast(
      onListen: () {
        for (final s in list) {
          subs.add(s.listen(controller.add, onError: controller.addError));
        }
      },
      onCancel: () async {
        for (final sub in subs) {
          await sub.cancel();
        }
        subs.clear();
      },
    );
    return controller.stream;
  }
}
