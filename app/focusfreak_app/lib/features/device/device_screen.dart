/// The bot connection screen.
///
/// Everything here works against the virtual bot with no hardware present,
/// which is both how it was built and the reason a demo survives a dead HC-05.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/ff_shell.dart';
import '../../app/providers.dart';
import '../../design/components/ff_badge.dart';
import '../../design/components/ff_card.dart';
import '../../design/components/ff_states.dart';
import '../../design/ff_theme.dart';
import '../../design/ff_tokens.dart';
import '../../design/ff_typography.dart';
import '../../device/protocol.dart';
import '../../device/transport/transport.dart';
import '../../domain/engine/routine_clock.dart';
import 'device_controller.dart';

class DeviceScreen extends ConsumerWidget {
  const DeviceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(deviceControllerProvider);

    return FfPage(
      title: 'Bot',
      subtitle: switch (state) {
        // The reconnect is silent, but not invisible: someone watching the
        // screen while their bot is out of range should see that the app is
        // still trying, rather than a flat "not connected" that looks final.
        DeviceConnectionState(reconnecting: true) => 'Reconnecting…',
        DeviceConnectionState(link: LinkState.connected) =>
          'Connected to ${state.label}',
        DeviceConnectionState(link: LinkState.connecting) => 'Connecting…',
        _ => 'No bot connected',
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (state.error != null) ...<Widget>[
            _ErrorBanner(
              message: state.error!,
              onDismiss: () =>
                  ref.read(deviceControllerProvider.notifier).clearError(),
            ),
            const SizedBox(height: FfSpace.lg),
          ],
          const _ConnectionSection(),
          if (state.isConnected) ...<Widget>[
            const SizedBox(height: FfSpace.xl),
            const _CapabilitySection(),
            const SizedBox(height: FfSpace.xl),
            const _StatusSection(),
            const SizedBox(height: FfSpace.xl),
            const _PushSection(),
            if (state.kind == DeviceKind.virtual) ...<Widget>[
              const SizedBox(height: FfSpace.xl),
              const _VirtualControls(),
            ],
          ],
          const SizedBox(height: FfSpace.xl),
          const _WireLogSection(),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onDismiss});

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final p = context.ff;
    return FfCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.info_outline_rounded, color: p.paused, size: 20),
          const SizedBox(width: FfSpace.md),
          Expanded(
            child: Text(
              message,
              style: FfType.bodySmall.copyWith(color: p.textSecondary),
            ),
          ),
          IconButton(
            onPressed: onDismiss,
            icon: const Icon(Icons.close_rounded, size: 18),
            tooltip: 'Dismiss',
          ),
        ],
      ),
    );
  }
}

class _ConnectionSection extends ConsumerWidget {
  const _ConnectionSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.ff;
    final state = ref.watch(deviceControllerProvider);
    final controller = ref.read(deviceControllerProvider.notifier);

    if (state.isConnected) {
      final ack = state.ack;
      return FfSection(
        title: 'Connection',
        children: <Widget>[
          FfCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(
                      state.kind == DeviceKind.virtual
                          ? Icons.smart_toy_outlined
                          : Icons.bluetooth_connected_rounded,
                      color: p.verified,
                    ),
                    const SizedBox(width: FfSpace.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            state.label ?? 'Bot',
                            style: FfType.titleMedium.copyWith(
                              color: p.textPrimary,
                            ),
                          ),
                          if (ack != null)
                            Text(
                              'Firmware ${ack.firmwareVersion} · protocol '
                              '${ack.protoVersion} · holds ${ack.maxBlocks} '
                              'blocks, ${ack.eepromLogDays} days of logs',
                              style: FfType.bodySmall.copyWith(
                                color: p.textMuted,
                              ),
                            ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: state.busy ? null : controller.disconnect,
                      child: const Text('Disconnect'),
                    ),
                  ],
                ),
                if (ack != null && !ack.versionMatches) ...<Widget>[
                  const SizedBox(height: FfSpace.md),
                  Text(
                    'This bot runs older software than the app expects. '
                    'Everything both sides understand still works. Updating '
                    'the bot brings back the rest.',
                    style: FfType.bodySmall.copyWith(color: p.paused),
                  ),
                ],
              ],
            ),
          ),
        ],
      );
    }

    return FfSection(
      title: 'Connect your bot',
      subtitle: 'Turn the bot on and it will show up here.',
      action: state.scanning
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : IconButton(
              onPressed: controller.scan,
              icon: const Icon(Icons.refresh_rounded, size: 20),
              tooltip: 'Look again',
            ),
      children: const <Widget>[
        _BotList(),
        SizedBox(height: FfSpace.lg),
        _VirtualBotFallback(),
      ],
    );
  }
}

/// Bots in range and bots already paired, in one list.
///
/// One tap does everything: pair if it has never been paired, then connect.
/// The user is never sent to Android settings and never types a PIN — the app
/// answers the pairing request itself. This is the whole point of the screen.
class _BotList extends ConsumerStatefulWidget {
  const _BotList();

  @override
  ConsumerState<_BotList> createState() => _BotListState();
}

class _BotListState extends ConsumerState<_BotList> {
  /// Held rather than read in [dispose], where `ref` is already gone.
  DeviceController? _controller;

  @override
  void initState() {
    super.initState();
    // Scanning on arrival rather than behind a button: opening this screen is
    // already the user saying "find my bot".
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _controller = ref.read(deviceControllerProvider.notifier);
      _controller!.scan();
    });
  }

  @override
  void dispose() {
    // A scan left running is a radio left running.
    _controller?.stopScan();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.ff;
    final available = ref.watch(bluetoothAvailableProvider);
    final state = ref.watch(deviceControllerProvider);
    final controller = ref.read(deviceControllerProvider.notifier);

    return available.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (supported) {
        if (!supported) {
          return FfCard(
            child: Text(
              'This phone has no Bluetooth. Everything except the bot still '
              'works.',
              style: FfType.bodySmall.copyWith(color: p.textMuted),
            ),
          );
        }

        if (state.found.isEmpty) {
          return FfCard(
            child: FfEmptyState(
              compact: true,
              icon: state.scanning
                  ? Icons.bluetooth_searching_rounded
                  : Icons.bluetooth_disabled_rounded,
              title: state.scanning ? 'Looking for your bot…' : 'No bot found',
              message: state.scanning
                  ? 'Make sure it is switched on and nearby.'
                  : 'Switch the bot on, then tap the refresh button above.',
            ),
          );
        }

        return FfCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: <Widget>[
              for (final device in state.found)
                ListTile(
                  leading: Icon(Icons.smart_toy_rounded, color: p.accent),
                  title: Text(device.displayName),
                  subtitle: Text(
                    device.bonded ? 'Ready to connect' : 'Tap to set up',
                    style: FfType.bodySmall.copyWith(color: p.textMuted),
                  ),
                  trailing: state.pairingAddress == device.address
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(Icons.chevron_right_rounded, color: p.textMuted),
                  onTap: state.busy || state.pairingAddress != null
                      ? null
                      : () => controller.connectBluetooth(device),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// The bot without the bot.
///
/// Kept, and kept working, but no longer the first thing offered: someone who
/// has just bought hardware should not have to scroll past a simulation of it.
class _VirtualBotFallback extends ConsumerWidget {
  const _VirtualBotFallback();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.ff;
    final state = ref.watch(deviceControllerProvider);
    final controller = ref.read(deviceControllerProvider.notifier);

    return FfCard(
      padding: EdgeInsets.zero,
      child: ListTile(
        leading: Icon(Icons.science_outlined, color: p.textMuted),
        title: Text(
          'No bot yet?',
          style: FfType.body.copyWith(color: p.textSecondary),
        ),
        subtitle: Text(
          'Try the virtual one. It behaves exactly like the real bot.',
          style: FfType.bodySmall.copyWith(color: p.textMuted),
        ),
        trailing: Icon(Icons.chevron_right_rounded, color: p.textMuted),
        onTap: state.busy ? null : controller.connectVirtual,
      ),
    );
  }
}

class _CapabilitySection extends ConsumerWidget {
  const _CapabilitySection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final caps = ref.watch(deviceControllerProvider).capabilities;
    final present = caps.present;

    return FfSection(
      title: 'What this bot has',
      subtitle:
          'A sensor your bot does not have is never counted against '
          'you.',
      children: <Widget>[
        FfCard(
          child: Wrap(
            spacing: FfSpace.sm,
            runSpacing: FfSpace.sm,
            children: <Widget>[
              for (final cap in DeviceCapability.values)
                FfBadge(
                  label: cap.label,
                  state: present.contains(cap)
                      ? FfBadgeState.on
                      : FfBadgeState.unavailable,
                  tooltip: present.contains(cap)
                      ? '${cap.label}: present and healthy at boot'
                      : '${cap.label}: not on this bot',
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatusSection extends ConsumerWidget {
  const _StatusSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.ff;
    final state = ref.watch(deviceControllerProvider);
    final controller = ref.read(deviceControllerProvider.notifier);
    final status = state.status;
    final caps = state.capabilities;

    return FfSection(
      title: 'Live status',
      action: IconButton(
        onPressed: state.busy ? null : controller.refreshStatus,
        icon: const Icon(Icons.refresh_rounded, size: 20),
        tooltip: 'Ask now',
      ),
      children: <Widget>[
        if (status == null)
          const FfCard(
            child: FfEmptyState(
              compact: true,
              icon: Icons.sensors_off_rounded,
              title: 'No status yet',
              message: 'The bot has not reported since it connected.',
            ),
          )
        else
          FfCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        switch (status.state) {
                          DeviceRunState.idle => 'Idle',
                          DeviceRunState.armed => 'Armed',
                          DeviceRunState.running => 'Running',
                          DeviceRunState.paused => 'Paused',
                          DeviceRunState.complete => 'Finished',
                          DeviceRunState.broken => 'Stopped',
                        },
                        style: FfType.titleMedium.copyWith(
                          color: p.textPrimary,
                        ),
                      ),
                    ),
                    if (status.hasActiveBlock)
                      Text(
                        'Block ${status.blockIdx + 1} · '
                        '${status.remaining.inMinutes} min left',
                        style: FfType.bodySmall.copyWith(color: p.textMuted),
                      ),
                  ],
                ),
                const SizedBox(height: FfSpace.md),
                Wrap(
                  spacing: FfSpace.sm,
                  runSpacing: FfSpace.sm,
                  children: <Widget>[
                    // A verification bit whose capability is absent must be
                    // ignored, not shown as failing (PROTOCOL.md §6).
                    FfBadge(
                      label: 'HERE',
                      state: caps.has(DeviceCapability.presence)
                          ? (status.present
                                ? FfBadgeState.on
                                : FfBadgeState.off)
                          : FfBadgeState.unavailable,
                    ),
                    FfBadge(
                      label: 'DOCK',
                      state: caps.has(DeviceCapability.dock)
                          ? (status.docked ? FfBadgeState.on : FfBadgeState.off)
                          : FfBadgeState.unavailable,
                    ),
                    FfBadge(
                      label: 'LOCK',
                      state: status.phoneLocked
                          ? FfBadgeState.on
                          : FfBadgeState.off,
                    ),
                    FfBadge(
                      label: 'TRACK',
                      state: status.trackEnabled
                          ? FfBadgeState.on
                          : FfBadgeState.unavailable,
                    ),
                    FfBadge(
                      label: 'VERIFIED',
                      // With nothing tracked there is nothing to verify, so
                      // this reads unavailable rather than amber. An untracked
                      // block is not a failed verification, and the badge must
                      // not imply it is.
                      state: !status.trackEnabled
                          ? FfBadgeState.unavailable
                          : (status.deviceVerified
                                ? FfBadgeState.on
                                : FfBadgeState.off),
                      tooltip: 'What the bot itself concluded.',
                    ),
                  ],
                ),
                const SizedBox(height: FfSpace.lg),
                Text(
                  '${status.verifiedToday} verified of '
                  '${status.claimedToday} claimed minutes today'
                  '${status.battPct == null ? '' : ' · battery ${status.battPct}%'}',
                  style: FfType.bodySmall.copyWith(color: p.textSecondary),
                ),
                const SizedBox(height: FfSpace.lg),
                Wrap(
                  spacing: FfSpace.sm,
                  children: <Widget>[
                    for (final (label, action) in <(String, ControlAction)>[
                      ('Pause', ControlAction.pause),
                      ('Resume', ControlAction.resume),
                      ('Skip', ControlAction.skip),
                      ('Stop', ControlAction.stop),
                    ])
                      OutlinedButton(
                        onPressed: () => controller.control(action),
                        child: Text(label),
                      ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _PushSection extends ConsumerWidget {
  const _PushSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.ff;
    final routines = ref.watch(routinesProvider);
    final state = ref.watch(deviceControllerProvider);
    final maxBlocks = state.ack?.maxBlocks ?? 16;

    return FfSection(
      title: 'Send a routine',
      subtitle:
          'Your bot holds $maxBlocks blocks. Longer routines stay in the '
          'app.',
      children: <Widget>[
        routines.when(
          loading: () => const FfCard(
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          error: (_, __) =>
              const FfCard(child: Text('Could not read your routines.')),
          data: (list) {
            if (list.isEmpty) {
              return const FfCard(
                child: FfEmptyState(
                  compact: true,
                  icon: Icons.event_note_outlined,
                  title: 'No routines yet',
                  message: 'Build one in Plan, then send it here.',
                ),
              );
            }
            return FfCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: <Widget>[
                  for (final routine in list)
                    ListTile(
                      title: Text(routine.name),
                      subtitle: Text(
                        routine.description.isEmpty
                            ? 'Tap to send to the bot'
                            : routine.description,
                        style: FfType.bodySmall.copyWith(color: p.textMuted),
                      ),
                      trailing: Icon(Icons.upload_rounded, color: p.textMuted),
                      onTap: state.busy
                          ? null
                          : () => _push(context, ref, routine.id),
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Future<void> _push(BuildContext context, WidgetRef ref, String id) async {
    final messenger = ScaffoldMessenger.of(context);
    final loaded = await ref.read(routineRepositoryProvider).load(id);
    if (loaded == null) return;

    // A day longer than the bot holds goes over in part: the stretch from
    // the block that is on now.
    final from = loaded.fitsDevice
        ? 0
        : RoutineClock.blockAt(loaded.timed, DateTime.now())?.index ?? 0;
    final report = await ref
        .read(deviceControllerProvider.notifier)
        .pushRoutine(loaded.windowFrom(from));
    messenger.showSnackBar(SnackBar(content: Text(report.message)));
  }
}

/// Controls for the in-app bot.
///
/// Flipping presence here is the fastest way to show what the product actually
/// claims: leave the desk and the verified counter stops while the claimed one
/// keeps going.
class _VirtualControls extends ConsumerWidget {
  const _VirtualControls();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.ff;
    // Watched, not read: the switches show the bot's sensors, and a `read`
    // never rebuilds — flipping one would change the device and leave the
    // switch sitting where it was.
    ref.watch(deviceControllerProvider);
    final controller = ref.read(deviceControllerProvider.notifier);
    final device = controller.simulated;
    if (device == null) return const SizedBox.shrink();

    return FfSection(
      title: 'Virtual bot sensors',
      subtitle: 'Only for the virtual bot. A real one reports what it sees.',
      children: <Widget>[
        FfCard(
          child: Column(
            children: <Widget>[
              SwitchListTile(
                value: device.present,
                activeThumbColor: p.accent,
                contentPadding: EdgeInsets.zero,
                title: const Text('At the desk'),
                subtitle: Text(
                  'The ultrasonic sensor sees someone in the chair',
                  style: FfType.bodySmall.copyWith(color: p.textMuted),
                ),
                onChanged: (value) async {
                  device.present = value;
                  await controller.refreshStatus();
                },
              ),
              SwitchListTile(
                value: device.docked,
                activeThumbColor: p.accent,
                contentPadding: EdgeInsets.zero,
                title: const Text('Phone docked'),
                subtitle: Text(
                  'The dock sensor sees the phone',
                  style: FfType.bodySmall.copyWith(color: p.textMuted),
                ),
                onChanged: (value) async {
                  device.docked = value;
                  await controller.refreshStatus();
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Every frame, both directions, in hex.
///
/// `docs/PROTOCOL.md` §14: when an integration bug shows up at 2 a.m. in week
/// 4, this log next to Logcat's `FF-WIRE` is the thing that resolves it.
class _WireLogSection extends ConsumerWidget {
  const _WireLogSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.ff;
    final state = ref.watch(deviceControllerProvider);
    final controller = ref.read(deviceControllerProvider.notifier);
    final lines = state.wireLog;

    return FfSection(
      title: 'Wire log',
      subtitle:
          'Everything the app and the bot say to each other. Never '
          'leaves your phone.',
      action: lines.isEmpty
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                IconButton(
                  tooltip: 'Copy',
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  onPressed: () =>
                      Clipboard.setData(ClipboardData(text: lines.join('\n'))),
                ),
                IconButton(
                  tooltip: 'Clear',
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  onPressed: controller.clearWireLog,
                ),
              ],
            ),
      children: <Widget>[
        FfCard(
          child: lines.isEmpty
              ? Text(
                  'Nothing yet. Connect a bot and the frames appear here.',
                  style: FfType.bodySmall.copyWith(color: p.textMuted),
                )
              : ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 220),
                  child: ListView.builder(
                    reverse: true,
                    itemCount: lines.length,
                    itemBuilder: (_, i) => Text(
                      lines[lines.length - 1 - i],
                      style: FfType.mono.copyWith(color: p.textSecondary),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}
