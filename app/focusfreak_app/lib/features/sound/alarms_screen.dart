import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/ff_shell.dart';
import '../../app/providers.dart';
import '../../botos/alarms.dart';
import '../../botos/music.dart';
import '../../data/repo/settings_repository.dart';
import '../../design/components/ff_card.dart';
import '../../design/ff_theme.dart';
import '../../design/ff_tokens.dart';
import '../../design/ff_typography.dart';
import '../bot/botos_host.dart';
import 'alarm_scheduler.dart';
import 'sound_cues.dart';

/// The bot's alarms, set from the phone, and the tone a block ends with.
///
/// The same four slots as the Alarms app on the bot: a change here shows on
/// the bot at once, and the other way round.
class AlarmsScreen extends ConsumerWidget {
  const AlarmsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Built so the saved alarms are loaded before they are shown.
    ref.watch(botOsProvider.select((f) => f.frame ~/ 25));
    final alarms = ref.watch(botAlarmsProvider);

    return FfPage(
      title: 'Alarms',
      subtitle: 'They ring on your bot and on this phone',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          FfSection(
            title: 'Wake-up alarms',
            subtitle: 'Press the knob to stop. Touch a pad to snooze.',
            children: <Widget>[
              for (var i = 0; i < alarms.length; i++) ...<Widget>[
                if (i > 0) const SizedBox(height: FfSpace.sm),
                _AlarmCard(slot: i, alarm: alarms[i]),
              ],
            ],
          ),
          const SizedBox(height: FfSpace.xl),
          const _BlockEndTone(),
        ],
      ),
    );
  }
}

class _AlarmCard extends ConsumerWidget {
  const _AlarmCard({required this.slot, required this.alarm});

  final int slot;
  final BotAlarm alarm;

  void _save(WidgetRef ref, BotAlarm next) =>
      ref.read(botOsProvider.notifier).setAlarm(slot, next);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.ff;
    final a = alarm;
    final muted = !a.on;

    return FfCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              InkWell(
                borderRadius: BorderRadius.circular(FfRadius.sm),
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay(hour: a.hour, minute: a.minute),
                  );
                  if (picked == null) return;
                  _save(
                    ref,
                    a.copy()
                      ..hour = picked.hour
                      ..minute = picked.minute
                      ..on = true,
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: FfSpace.xs),
                  child: Text(
                    a.time,
                    style: FfType.countdownMd.copyWith(
                      color: muted ? p.textMuted : p.textPrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: FfSpace.md),
              Expanded(
                child: Text(
                  a.on ? a.repeatLabel : 'Off',
                  style: FfType.bodySmall.copyWith(color: p.textSecondary),
                ),
              ),
              Switch(
                value: a.on,
                activeThumbColor: p.accent,
                onChanged: (v) async {
                  _save(ref, a.copy()..on = v);
                  if (v) await ref.read(alarmNotifierProvider).prepare();
                },
              ),
            ],
          ),
          const SizedBox(height: FfSpace.sm),
          Wrap(
            spacing: FfSpace.xs,
            runSpacing: FfSpace.xs,
            children: <Widget>[
              for (var d = 0; d < 7; d++)
                FilterChip(
                  label: Text(AlarmRepeat.dayNames[d]),
                  selected: (a.days >> d) & 1 == 1,
                  showCheckmark: false,
                  visualDensity: VisualDensity.compact,
                  onSelected: (_) => _save(
                    ref,
                    a.copy()
                      ..days = a.days ^ (1 << d)
                      ..on = true,
                  ),
                ),
            ],
          ),
          const SizedBox(height: FfSpace.sm),
          Row(
            children: <Widget>[
              Icon(Icons.music_note_rounded, size: 18, color: p.textMuted),
              const SizedBox(width: FfSpace.sm),
              Expanded(
                child: DropdownButton<int>(
                  value: a.tone.clamp(0, AlarmTones.all.length - 1),
                  isExpanded: true,
                  underline: const SizedBox.shrink(),
                  items: <DropdownMenuItem<int>>[
                    for (var t = 0; t < AlarmTones.all.length; t++)
                      DropdownMenuItem<int>(
                        value: t,
                        child: Text(AlarmTones.all[t].title),
                      ),
                  ],
                  onChanged: (t) {
                    if (t == null) return;
                    _save(ref, a.copy()..tone = t);
                    ref.read(botOsProvider.notifier).previewAlarmTone(t);
                  },
                ),
              ),
              IconButton(
                tooltip: 'Hear it',
                icon: Icon(
                  Icons.play_circle_outline_rounded,
                  color: p.textSecondary,
                ),
                onPressed: () =>
                    ref.read(botOsProvider.notifier).previewAlarmTone(a.tone),
              ),
              IconButton(
                tooltip: 'Stop',
                icon: Icon(Icons.stop_circle_outlined, color: p.textSecondary),
                onPressed: () => ref.read(botOsProvider.notifier).stopSound(),
              ),
            ],
          ),
          if (a.once && a.on)
            Text(
              'No days picked: rings once, then switches off.',
              style: FfType.caption.copyWith(color: p.textMuted),
            ),
        ],
      ),
    );
  }
}

/// The tone that rings when a timer or a routine finishes.
class _BlockEndTone extends ConsumerWidget {
  const _BlockEndTone();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.ff;
    final tone = ref.watch(alarmToneProvider).valueOrNull ?? 0;
    final cues = ref.watch(soundCuesProvider);
    final names = SoundCues.toneNames;

    return FfSection(
      title: 'When a block ends',
      subtitle: 'The tone for the end of a timer or a routine.',
      children: <Widget>[
        FfCard(
          padding: EdgeInsets.zero,
          child: RadioGroup<int>(
            groupValue: tone.clamp(0, names.length - 1),
            onChanged: (v) {
              if (v == null) return;
              ref
                  .read(settingsRepositoryProvider)
                  .setInt(SettingKey.alarmTone, v);
              cues.playAlarm(tone: v);
            },
            child: Column(
              children: <Widget>[
                for (var i = 0; i < names.length; i++)
                  RadioListTile<int>(
                    value: i,
                    dense: true,
                    title: Text(
                      names[i],
                      style: FfType.body.copyWith(color: p.textPrimary),
                    ),
                    secondary: i == tone
                        ? IconButton(
                            tooltip: 'Stop',
                            icon: Icon(
                              Icons.stop_circle_outlined,
                              color: p.textSecondary,
                            ),
                            onPressed: cues.stopAlarm,
                          )
                        : null,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
