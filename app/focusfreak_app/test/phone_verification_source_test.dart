import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusfreak_app/domain/model/verification.dart';
import 'package:focusfreak_app/platform/phone_channel.dart';
import 'package:focusfreak_app/platform/phone_verification_source.dart';

/// The phone's own evidence.
///
/// The bug this file exists to keep fixed: `phoneVerificationSourceProvider`
/// used to be a `ManualVerificationSource` declaring `screenLock` that nothing
/// ever set, and `ManualVerificationSource` defaults an unset factor to
/// *holding*. Every bot-less session therefore reported LOCK as holding with no
/// sensor behind it and verified itself — the exact dishonesty `docs/ARCHITECTURE.md`
/// forbids. Most of what follows is one assertion in different clothes: **no
/// feed means unavailable, never holding.**
/// A stand-in for one of the Kotlin plugins.
///
/// Answers method calls and can push readings down the event channel the same
/// way the real plugin does, so the source is exercised through its actual
/// platform seam rather than through a hand-made subclass.
class FakePlugin {
  FakePlugin(this.name) : method = MethodChannel('focusfreak/$name');

  final String name;
  final MethodChannel method;

  final List<String> calls = <String>[];
  Map<String, String> factors = <String, String>{};
  bool granted = true;
  bool running = false;

  /// Set to make every method call fail, standing in for a plugin that is not
  /// there at all — web, macOS, or an Android build without it.
  bool missing = false;

  TestDefaultBinaryMessenger get _messenger =>
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  Map<String, Object?> get payload => <String, Object?>{
    'running': running,
    'granted': granted,
    'factors': factors,
  };

  void install() {
    _messenger.setMockMethodCallHandler(method, (call) async {
      calls.add(call.method);
      if (missing) throw MissingPluginException(call.method);
      switch (call.method) {
        case 'start':
          running = true;
          return payload;
        case 'stop':
          running = false;
          factors = <String, String>{};
          return null;
        case 'configure':
        case 'read':
          return payload;
        case 'hasAccelerometer':
        case 'hasAccess':
          return true;
      }
      return null;
    });
  }

  /// Pushes a reading the way the plugin's `EventChannel` does.
  Future<void> push() async {
    await _messenger.handlePlatformMessage(
      'focusfreak/$name/events',
      const StandardMethodCodec().encodeSuccessEnvelope(payload),
      (_) {},
    );
  }

  void remove() => _messenger.setMockMethodCallHandler(method, null);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakePlugin phonePlugin;
  late FakePlugin usagePlugin;
  late PhoneVerificationSource source;

  setUp(() {
    phonePlugin = FakePlugin('phone')..install();
    usagePlugin = FakePlugin('usage')..install();
    source = PhoneVerificationSource(
      phone: PhoneStateChannel(),
      usage: UsageStatsChannel(),
    );
  });

  tearDown(() async {
    await source.dispose();
    phonePlugin.remove();
    usagePlugin.remove();
  });

  Future<void> start({bool stillness = true, bool appUsage = false}) =>
      source.start(
        useStillness: stillness,
        useAppUsage: appUsage,
        title: 'Deep Work is running',
        body: 'body',
      );

  group('before anything is observing', () {
    test('provides no factors at all', () {
      expect(source.providedFactors, isEmpty);
    });

    test('a tracked block is NOT verified', () {
      // The heart of it. With no evidence, "verified" is a claim the app has
      // no basis for — and the old code made it anyway.
      final snapshot = source.read(trackEnabled: true);
      expect(
        snapshot.stateOf(VerificationFactor.screenLock),
        FactorState.unavailable,
      );
      expect(snapshot.isVerified, isFalse);
      expect(snapshot.availabilityMask, 0);
    });

    test('an untracked block is still fine', () {
      // A plain timer is not a failed verification, it is a different thing.
      expect(source.read(trackEnabled: false).isVerified, isTrue);
    });
  });

  group('while observing', () {
    test('reports the factors the platform actually sent', () async {
      phonePlugin.factors = <String, String>{'screenLock': 'holding'};
      await start();

      expect(source.providedFactors, <VerificationFactor>{
        VerificationFactor.screenLock,
      });
      expect(source.read(trackEnabled: true).isVerified, isTrue);
    });

    test('a violation reaches the verdict', () async {
      phonePlugin.factors = <String, String>{
        'screenLock': 'violated',
        'dock': 'holding',
      };
      await start();

      final snapshot = source.read(trackEnabled: true);
      expect(
        snapshot.stateOf(VerificationFactor.screenLock),
        FactorState.violated,
      );
      expect(snapshot.isVerified, isFalse);
    });

    test(
      'a factor the platform stopped sending goes unavailable, not stale',
      () async {
        phonePlugin.factors = <String, String>{
          'screenLock': 'holding',
          'dock': 'holding',
        };
        await start();
        expect(source.providedFactors, hasLength(2));

        // The user turned stillness off, or the sensor went away. Either way the
        // last reading is not evidence about now.
        phonePlugin.factors = <String, String>{'screenLock': 'holding'};
        await phonePlugin.push();

        expect(source.providedFactors, <VerificationFactor>{
          VerificationFactor.screenLock,
        });
        expect(
          source.read(trackEnabled: true).stateOf(VerificationFactor.dock),
          FactorState.unavailable,
        );
      },
    );

    test('app usage is not observed unless it was opted into', () async {
      usagePlugin.factors = <String, String>{'appUsage': 'holding'};
      await start();

      expect(usagePlugin.calls, isNot(contains('start')));
      expect(
        source.providedFactors,
        isNot(contains(VerificationFactor.appUsage)),
      );
    });

    test('app usage is observed when it was', () async {
      usagePlugin.factors = <String, String>{'appUsage': 'violated'};
      await start(appUsage: true);

      expect(
        source.read(trackEnabled: true).stateOf(VerificationFactor.appUsage),
        FactorState.violated,
      );
    });

    test(
      'revoking usage access withdraws the factor rather than passing it',
      () async {
        usagePlugin.factors = <String, String>{'appUsage': 'holding'};
        await start(appUsage: true);
        expect(source.providedFactors, contains(VerificationFactor.appUsage));

        // The grant can be taken away from system settings mid-block. The plugin
        // answers by reporting no factors, and "no factor" must not read as "you
        // opened nothing".
        usagePlugin.granted = false;
        usagePlugin.factors = <String, String>{};
        await usagePlugin.push();

        expect(
          source.providedFactors,
          isNot(contains(VerificationFactor.appUsage)),
        );
      },
    );
  });

  group('stopping', () {
    test('clears the factors instead of freezing them', () async {
      phonePlugin.factors = <String, String>{'screenLock': 'holding'};
      await start();
      expect(source.providedFactors, isNotEmpty);

      await source.stop();

      // The same rule DeviceVerificationSource applies to a stale bot: a
      // reading from before the block ended is not evidence about now.
      expect(source.providedFactors, isEmpty);
      expect(source.read(trackEnabled: true).isVerified, isFalse);
    });

    test('a late reading after stopping is ignored', () async {
      phonePlugin.factors = <String, String>{'screenLock': 'holding'};
      await start();
      await source.stop();

      // The plugin's last event can arrive after the stop call returns.
      await phonePlugin.push();
      expect(source.providedFactors, isEmpty);
    });
  });

  group('where the plugin does not exist', () {
    test('reports nothing rather than throwing', () async {
      // Web and macOS are development surfaces with no plugin at all. The app
      // has to run there — it just has no phone factors.
      phonePlugin.missing = true;
      usagePlugin.missing = true;

      await start(appUsage: true);

      expect(source.providedFactors, isEmpty);
      expect(source.read(trackEnabled: true).isVerified, isFalse);
    });
  });
}
