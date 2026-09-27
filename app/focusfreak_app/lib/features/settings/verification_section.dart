/// What the phone is allowed to check, and what it needs to keep checking.
///
/// Every switch here adds a factor the app can actually read. None of them is
/// required: a factor left off is *excluded* from the verdict, never assumed to
/// hold and never counted against you. That is the same rule a bot's missing
/// sensor follows, and it is why this screen can be entirely ignored.
///
/// The copy avoids the words "sensor", "factor" and "permission" wherever it
/// can. What a user wants to know is what the app will notice, and what it
/// costs them.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/repo/settings_repository.dart';
import '../../design/components/ff_card.dart';
import '../../design/ff_theme.dart';
import '../../design/ff_tokens.dart';
import '../../design/ff_typography.dart';
import '../../platform/phone_channel.dart';
import '../../platform/power_channel.dart';
import '../timer/phone_tracking.dart';
import '../timer/session_controller.dart';

final powerChannelProvider = Provider<PowerChannel>(
  (ref) => const PowerChannel(),
);

final usageStatsChannelProvider = Provider<UsageStatsChannel>(
  (ref) => UsageStatsChannel(),
);

/// Whether Android is currently allowed to freeze the app mid-block.
final batteryExemptProvider = FutureProvider<bool>(
  (ref) => ref.watch(powerChannelProvider).isExempt,
);

/// Whether this ROM has a vendor autostart screen worth offering.
final hasAutostartProvider = FutureProvider<bool>(
  (ref) => ref.watch(powerChannelProvider).hasAutostartSettings,
);

/// Whether usage access has been granted. Re-read rather than remembered: it
/// can be revoked from system settings at any time.
final usageAccessProvider = FutureProvider<bool>(
  (ref) => ref.watch(usageStatsChannelProvider).hasAccess(),
);

class VerificationSection extends ConsumerWidget {
  const VerificationSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.ff;
    final settings = ref.watch(settingsRepositoryProvider);
    final stillness = ref.watch(useStillnessAsDockProvider).valueOrNull ?? true;
    final appUsage =
        ref.watch(useAppUsageTrackingProvider).valueOrNull ?? false;
    final usageGranted = ref.watch(usageAccessProvider).valueOrNull ?? false;
    final pauseWhenAway = ref.watch(pauseWhenAwayProvider).valueOrNull ?? false;

    return FfSection(
      title: 'What the app checks',
      subtitle:
          'Anything you leave off is left out and never counted '
          'against you.',
      children: <Widget>[
        FfCard(
          child: Column(
            children: <Widget>[
              // Not a switch: there is nothing to configure. Stated so the
              // list of what the app watches is complete and honest.
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.lock_outline_rounded, color: p.accent),
                title: const Text('Whether the screen is off'),
                subtitle: Text(
                  'Always checked during a tracked block.',
                  style: FfType.bodySmall.copyWith(color: p.textMuted),
                ),
              ),
              SwitchListTile(
                value: stillness,
                activeThumbColor: p.accent,
                contentPadding: EdgeInsets.zero,
                title: const Text('Whether the phone is face down'),
                subtitle: Text(
                  'A phone lying face down and still counts as parked.',
                  style: FfType.bodySmall.copyWith(color: p.textMuted),
                ),
                onChanged: (v) =>
                    settings.setBool(SettingKey.useStillnessAsDock, v),
              ),
              SwitchListTile(
                value: appUsage && usageGranted,
                activeThumbColor: p.accent,
                contentPadding: EdgeInsets.zero,
                title: const Text('Whether you opened another app'),
                subtitle: Text(
                  usageGranted || !appUsage
                      ? 'Off by default. FocusFreak only looks at which app is '
                            'in front, never at what is in it.'
                      : 'Needs permission. Tap to grant it.',
                  style: FfType.bodySmall.copyWith(color: p.textMuted),
                ),
                onChanged: (v) async {
                  if (v && !usageGranted) {
                    // The grant lives on a system screen, so the switch takes
                    // the user there rather than flipping on and quietly doing
                    // nothing.
                    await ref.read(usageStatsChannelProvider).openSettings();
                  }
                  await settings.setBool(SettingKey.useAppUsageTracking, v);
                  ref.invalidate(usageAccessProvider);
                },
              ),
              SwitchListTile(
                value: pauseWhenAway,
                activeThumbColor: p.accent,
                contentPadding: EdgeInsets.zero,
                title: const Text('Pause the timer when you step away'),
                subtitle: Text(
                  pauseWhenAway
                      ? 'The countdown waits for you after 30 seconds away.'
                      : 'Off: the timer keeps going. Time away just is not '
                            'verified.',
                  style: FfType.bodySmall.copyWith(color: p.textMuted),
                ),
                onChanged: (v) => settings.setBool(SettingKey.pauseWhenAway, v),
              ),
            ],
          ),
        ),
        const SizedBox(height: FfSpace.md),
        const _KeepRunningCard(),
      ],
    );
  }
}

/// The two settings that decide whether a long block survives a pocket.
///
/// Shown only when there is something to fix. A card that says "all good" is a
/// card that trains people to ignore it.
class _KeepRunningCard extends ConsumerWidget {
  const _KeepRunningCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.ff;
    final exempt = ref.watch(batteryExemptProvider).valueOrNull ?? true;
    final hasAutostart = ref.watch(hasAutostartProvider).valueOrNull ?? false;
    if (exempt && !hasAutostart) return const SizedBox.shrink();

    final power = ref.read(powerChannelProvider);

    return FfCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Keep FocusFreak running',
            style: FfType.titleSmall.copyWith(color: p.textPrimary),
          ),
          const SizedBox(height: FfSpace.sm),
          Text(
            'Some phones stop apps that are not on screen. If your blocks stop '
            'counting when you put the phone down, these two settings are why.',
            style: FfType.bodySmall.copyWith(color: p.textSecondary),
          ),
          const SizedBox(height: FfSpace.md),
          Wrap(
            spacing: FfSpace.sm,
            runSpacing: FfSpace.sm,
            children: <Widget>[
              if (!exempt)
                OutlinedButton(
                  onPressed: () async {
                    await power.requestExemption();
                    ref.invalidate(batteryExemptProvider);
                  },
                  child: const Text('Allow background use'),
                ),
              if (hasAutostart)
                OutlinedButton(
                  onPressed: power.openAutostartSettings,
                  child: const Text('Open autostart settings'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
