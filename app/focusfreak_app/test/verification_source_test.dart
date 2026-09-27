import 'package:flutter_test/flutter_test.dart';
import 'package:focusfreak_app/domain/engine/verification_source.dart';
import 'package:focusfreak_app/domain/model/verification.dart';

void main() {
  group('NullVerificationSource', () {
    test('provides nothing, so a tracked block cannot be verified', () {
      const source = NullVerificationSource();
      final snap = source.read(trackEnabled: true);

      expect(source.providedFactors, isEmpty);
      expect(snap.available, isEmpty);
      expect(
        snap.isVerified,
        isFalse,
        reason: 'no evidence must never read as verified',
      );
    });

    test('an untracked block still runs', () {
      const source = NullVerificationSource();
      expect(source.read(trackEnabled: false).isVerified, isTrue);
    });
  });

  group('ManualVerificationSource', () {
    test('only reports the factors it declares', () {
      final source = ManualVerificationSource(
        provides: <VerificationFactor>{VerificationFactor.screenLock},
      );
      final snap = source.read(trackEnabled: true);

      expect(snap.stateOf(VerificationFactor.screenLock), FactorState.holding);
      expect(
        snap.stateOf(VerificationFactor.presence),
        FactorState.unavailable,
        reason: 'a phone cannot know whether you are at your desk',
      );
    });

    test('setting a factor it does not provide is ignored', () {
      final source = ManualVerificationSource(
        provides: <VerificationFactor>{VerificationFactor.screenLock},
      );
      source.set(VerificationFactor.presence, false);

      expect(
        source.read(trackEnabled: true).stateOf(VerificationFactor.presence),
        FactorState.unavailable,
        reason: 'a source must not invent readings for hardware it lacks',
      );
    });

    test('a violation flips the verdict', () {
      final source = ManualVerificationSource();
      expect(source.read(trackEnabled: true).isVerified, isTrue);

      source.set(VerificationFactor.dock, false);
      expect(source.read(trackEnabled: true).isVerified, isFalse);

      source.set(VerificationFactor.dock, true);
      expect(source.read(trackEnabled: true).isVerified, isTrue);
    });
  });

  group('CompositeVerificationSource', () {
    /// The bot supplies what a phone cannot; the phone keeps supplying what it
    /// can. This is the shape of the whole app-plus-hardware story.
    late ManualVerificationSource phone;
    late ManualVerificationSource bot;
    late CompositeVerificationSource combined;

    setUp(() {
      phone = ManualVerificationSource(
        provides: <VerificationFactor>{VerificationFactor.screenLock},
      );
      bot = ManualVerificationSource(
        provides: <VerificationFactor>{
          VerificationFactor.presence,
          VerificationFactor.dock,
        },
      );
      combined = CompositeVerificationSource(<VerificationSource>[phone, bot]);
    });

    tearDown(() async => combined.dispose());

    test('merges the factors of every source', () {
      expect(combined.providedFactors, <VerificationFactor>{
        VerificationFactor.screenLock,
        VerificationFactor.presence,
        VerificationFactor.dock,
      });

      final snap = combined.read(trackEnabled: true);
      expect(snap.available, hasLength(3));
      expect(snap.isVerified, isTrue);
    });

    test('a violation from any source wins', () {
      bot.set(VerificationFactor.presence, false);
      final snap = combined.read(trackEnabled: true);

      expect(snap.stateOf(VerificationFactor.presence), FactorState.violated);
      expect(snap.isVerified, isFalse);
      expect(
        snap.stateOf(VerificationFactor.screenLock),
        FactorState.holding,
        reason: 'the phone keeps reporting its own factor',
      );
    });

    test('a real reading beats another source\'s unavailable', () {
      // The phone reports presence as unavailable; the bot has a real reading.
      final snap = combined.read(trackEnabled: true);
      expect(snap.stateOf(VerificationFactor.presence), FactorState.holding);
    });

    test('losing the bot degrades to app-only rather than failing', () {
      final appOnly = CompositeVerificationSource(<VerificationSource>[phone]);
      final snap = appOnly.read(trackEnabled: true);

      expect(snap.isVerified, isTrue);
      expect(snap.available, <VerificationFactor>[
        VerificationFactor.screenLock,
      ]);
      expect(
        snap.availabilityMask,
        VerificationFactor.screenLock.bit,
        reason: 'the mask records that this was a one-factor session',
      );
    });

    test('an empty composite verifies nothing', () {
      final empty = CompositeVerificationSource(const <VerificationSource>[]);
      expect(empty.read(trackEnabled: true).isVerified, isFalse);
      expect(empty.providedFactors, isEmpty);
    });
  });
}
