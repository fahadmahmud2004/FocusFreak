import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/ff_shell.dart';
import '../../design/components/ff_badge.dart';
import '../../design/components/ff_card.dart';
import '../../design/ff_theme.dart';
import '../../design/ff_tokens.dart';
import '../../design/ff_typography.dart';
import '../device/device_controller.dart';
import 'bot_device.dart';
import 'botos_host.dart';
import 'device_mirror.dart';
import 'oled_display.dart';
import 'routine_panel.dart';

/// The bot, and everything running on it.
///
/// The rule for the whole app: every timer and routine runs here. The device
/// at the top is fully usable (knob, button, three touch pads), so the virtual
/// bot is the real one's twin; with hardware connected it mirrors and drives
/// the bot on the desk.
class BotScreen extends ConsumerWidget {
  const BotScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.ff;
    final bot = ref.watch(botStateProvider);
    final live = bot.live;
    final connection = ref.watch(deviceControllerProvider);
    final connected = connection.isConnected;
    final virtual = connected && connection.kind == DeviceKind.virtual;

    return FfPage(
      title: 'Bot',
      subtitle: !connected
          ? 'No bot connected'
          : live
          ? 'Connected to ${bot.deviceName}'
          : 'Virtual bot',
      actions: <Widget>[
        if (connected)
          IconButton(
            tooltip: 'Full screen',
            icon: const Icon(Icons.open_in_full_rounded),
            onPressed: () => context.push('/bot/fullscreen'),
          ),
        if (connected)
          Padding(
            padding: const EdgeInsets.only(right: FfSpace.gutter),
            child: Center(child: FfProvenanceBadge(live: live)),
          ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const SizedBox(height: FfSpace.sm),
          if (connected) ...<Widget>[
            const BotDevice(),
            const SizedBox(height: FfSpace.md),
            Text(
              'Turn the knob to browse · Menu for apps and games · '
              'Tap the top pads to pet',
              textAlign: TextAlign.center,
              style: FfType.caption.copyWith(color: p.textMuted),
            ),
          ] else
            const _ConnectGate(),
          const SizedBox(height: FfSpace.xl),
          const RoutinePanel(),
          const SizedBox(height: FfSpace.md),
          const _AlarmsRow(),
          if (virtual) ...<Widget>[
            const SizedBox(height: FfSpace.xl),
            const _RoomPanel(),
          ],
          if (connected) ...<Widget>[
            const SizedBox(height: FfSpace.xl),
            Center(
              child: FilledButton.tonalIcon(
                onPressed: () => context.push('/bot/fullscreen'),
                icon: const Icon(Icons.smartphone_rounded, size: 18),
                label: const Text('Use this phone as the bot'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// What the Bot tab shows with no bot: the two ways to get one.
///
/// The virtual bot is offered as plainly as the real one. Most people open
/// this tab before any hardware exists, and it is the whole bot, sound,
/// games and timer included.
class _ConnectGate extends ConsumerWidget {
  const _ConnectGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.ff;
    final frame = ref.watch(botOsProvider);
    final state = ref.watch(deviceControllerProvider);
    final controller = ref.read(deviceControllerProvider.notifier);
    final busy = state.busy || state.reconnecting;

    return FfCard(
      padding: const EdgeInsets.all(FfSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // The screen, asleep: a preview of what connecting wakes up.
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 260),
              child: Opacity(
                opacity: 0.35,
                child: Container(
                  padding: const EdgeInsets.all(FfSpace.xs),
                  decoration: BoxDecoration(
                    color: const Color(0xFF050607),
                    borderRadius: BorderRadius.circular(FfRadius.md),
                    border: Border.all(color: p.borderStrong),
                  ),
                  child: OledDisplay(frame: frame),
                ),
              ),
            ),
          ),
          const SizedBox(height: FfSpace.lg),
          Text(
            'Connect a bot',
            textAlign: TextAlign.center,
            style: FfType.titleMedium.copyWith(color: p.textPrimary),
          ),
          const SizedBox(height: FfSpace.xs),
          Text(
            'Pair your FocusFreak bot, or use the virtual bot on this phone. '
            'It has everything the real one has: the face, timer, music, '
            'games and alarms.',
            textAlign: TextAlign.center,
            style: FfType.bodySmall.copyWith(color: p.textSecondary),
          ),
          if (state.error != null) ...<Widget>[
            const SizedBox(height: FfSpace.sm),
            Text(
              state.error!,
              textAlign: TextAlign.center,
              style: FfType.caption.copyWith(color: p.textMuted),
            ),
          ],
          const SizedBox(height: FfSpace.lg),
          FilledButton.icon(
            onPressed: busy ? null : controller.connectVirtual,
            icon: busy
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.smart_toy_outlined, size: 18),
            label: Text(
              state.reconnecting
                  ? 'Looking for your bot'
                  : 'Use the virtual bot',
            ),
          ),
          const SizedBox(height: FfSpace.sm),
          OutlinedButton.icon(
            onPressed: () => context.push('${FfTab.more.path}/device'),
            icon: const Icon(Icons.bluetooth_searching_rounded, size: 18),
            label: const Text('Connect my bot'),
          ),
        ],
      ),
    );
  }
}

/// The next alarm, and the way in to all of them.
class _AlarmsRow extends ConsumerWidget {
  const _AlarmsRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.ff;
    final alarms = ref.watch(botAlarmsProvider);
    final now = DateTime.now();
    DateTime? next;
    for (final a in alarms) {
      final at = a.nextAfter(now);
      if (at != null && (next == null || at.isBefore(next))) next = at;
    }
    final on = alarms.where((a) => a.on).length;
    return FfCard(
      onTap: () => context.push('${FfTab.more.path}/alarms'),
      child: Row(
        children: <Widget>[
          Icon(Icons.alarm_rounded, color: p.accent),
          const SizedBox(width: FfSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Alarms',
                  style: FfType.titleSmall.copyWith(color: p.textPrimary),
                ),
                Text(
                  next == null
                      ? 'None set'
                      : 'Next: ${_when(next, now)} · $on on',
                  style: FfType.caption.copyWith(color: p.textMuted),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: p.textMuted),
        ],
      ),
    );
  }

  static String _when(DateTime t, DateTime now) {
    final days = DateTime(
      t.year,
      t.month,
      t.day,
    ).difference(DateTime(now.year, now.month, now.day)).inDays;
    final day = switch (days) {
      0 => 'today',
      1 => 'tomorrow',
      _ => const <String>[
        'Mon',
        'Tue',
        'Wed',
        'Thu',
        'Fri',
        'Sat',
        'Sun',
      ][t.weekday - 1],
    };
    return '$day ${_hhmm(t)}';
  }

  static String _hhmm(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

/// The virtual bot's surroundings. Every change shows on the bot at once,
/// the same way the real sensors would report it.
class _RoomPanel extends ConsumerWidget {
  const _RoomPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final room = ref.watch(virtualRoomProvider);
    final set = ref.read(virtualRoomProvider.notifier);
    void update(VirtualRoom Function(VirtualRoom r) f) =>
        set.state = f(set.state);

    return FfSection(
      title: 'Room',
      subtitle:
          'What the virtual bot\'s sensors read. Change it and watch it '
          'react.',
      children: <Widget>[
        FfCard(
          child: Column(
            children: <Widget>[
              _SliderRow(
                icon: Icons.thermostat_rounded,
                label: 'Temperature',
                value: '${room.tempC.toStringAsFixed(1)} °C',
                slider: Slider(
                  value: room.tempC,
                  min: 14,
                  max: 38,
                  onChanged: (v) => update((r) => r.copyWith(tempC: v)),
                ),
              ),
              _SliderRow(
                icon: Icons.water_drop_outlined,
                label: 'Humidity',
                value: '${room.humidity.round()}%',
                slider: Slider(
                  value: room.humidity,
                  min: 15,
                  max: 95,
                  onChanged: (v) => update((r) => r.copyWith(humidity: v)),
                ),
              ),
              _SliderRow(
                icon: room.light < 150
                    ? Icons.dark_mode_outlined
                    : Icons.light_mode_outlined,
                label: 'Light',
                value: '${(room.light / 10.23).round()}%',
                slider: Slider(
                  value: room.light.toDouble(),
                  max: 1023,
                  onChanged: (v) => update((r) => r.copyWith(light: v.round())),
                ),
              ),
              _SliderRow(
                icon: Icons.person_outline_rounded,
                label: 'Someone at the desk',
                value: !room.present ? 'Away' : '${room.distanceCm} cm',
                slider: Slider(
                  value: (room.distanceCm ?? 150).toDouble().clamp(15, 150),
                  min: 15,
                  max: 150,
                  onChanged: (v) => update(
                    (r) => v >= 149
                        ? r.copyWith(clearDistance: true)
                        : r.copyWith(distanceCm: v.round()),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.slider,
  });

  final IconData icon;
  final String label;
  final String value;
  final Widget slider;

  @override
  Widget build(BuildContext context) {
    final p = context.ff;
    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(icon, size: 18, color: p.textMuted),
            const SizedBox(width: FfSpace.md),
            Expanded(
              child: Text(
                label,
                style: FfType.body.copyWith(color: p.textPrimary),
              ),
            ),
            Text(
              value,
              style: FfType.titleSmall.copyWith(color: p.textSecondary),
            ),
          ],
        ),
        slider,
      ],
    );
  }
}
