import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/ff_shell.dart';
import '../../botos/music.dart';
import '../../botos/os.dart';
import '../../botos/screens.dart' as bot;
import '../../core/ff_format.dart';
import '../../design/components/ff_card.dart';
import '../../design/components/ff_ring.dart';
import '../../design/ff_colors.dart';
import '../../design/ff_theme.dart';
import '../../design/ff_tokens.dart';
import '../../design/ff_typography.dart';
import '../../domain/model/session_state.dart';
import '../bot/botos_host.dart';
import '../bot/device_mirror.dart';
import '../bot/oled_display.dart';
import '../device/device_controller.dart';
import '../settings/profile_store.dart';
import '../timer/floating_timer.dart';
import '../timer/session_controller.dart';
import 'today_providers.dart';

/// Home: the bot and everything it can do, one tap away.
///
/// Today's numbers live in Stats, so this tab is the control centre instead:
/// a live view of the bot's screen, what its sensors say about the room, and
/// the games and music that run on it.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider);
    final name = ref.watch(userNameProvider).valueOrNull ?? '';

    return FfPage(
      title: _greeting(DateTime.now(), name),
      subtitle: FfFormat.dayMonth(DateTime.now()),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (session.isActive) ...<Widget>[
            _RunningCard(session: session),
            const SizedBox(height: FfSpace.lg),
          ],
          const _BotHero(),
          const SizedBox(height: FfSpace.xl),
          const _Room(),
          const SizedBox(height: FfSpace.xl),
          const _Play(),
          const SizedBox(height: FfSpace.xl),
          const _Listen(),
          const SizedBox(height: FfSpace.xl),
          const _TodayStrip(),
          const SizedBox(height: FfSpace.xxxl),
        ],
      ),
    );
  }

  static String _greeting(DateTime now, String name) {
    final part = now.hour < 5
        ? 'Up late'
        : now.hour < 12
        ? 'Good morning'
        : now.hour < 17
        ? 'Good afternoon'
        : 'Good evening';
    return name.isEmpty ? part : '$part, $name';
  }
}

void _openOnBot(
  BuildContext context,
  WidgetRef ref,
  BotApp app, {
  int arg = 0,
}) {
  // Asking for a game is asking for a bot: with none connected, the virtual
  // one comes up rather than a page asking which.
  final device = ref.read(deviceControllerProvider.notifier);
  if (!ref.read(botConnectedProvider)) unawaited(device.connectVirtual());
  ref.read(botOsProvider.notifier).launch(app, arg: arg);
  context.go(FfTab.bot.path);
}

// --- the bot ------------------------------------------------------------------

class _BotHero extends ConsumerWidget {
  const _BotHero();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.ff;
    final frame = ref.watch(botOsProvider);
    final live = ref.watch(botStateProvider).live;
    final sensors = ref.watch(botSensorsProvider);
    final comfort = bot.HomeScreen.comfort(sensors.tempC, sensors.humidity).$1;

    return FfCard(
      onTap: () => context.go(FfTab.bot.path),
      padding: const EdgeInsets.all(FfSpace.md),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 150,
            child: Container(
              padding: const EdgeInsets.all(FfSpace.xs),
              decoration: BoxDecoration(
                color: const Color(0xFF050607),
                borderRadius: BorderRadius.circular(FfRadius.md),
                border: Border.all(color: p.borderStrong),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(FfRadius.sm - 4),
                child: OledDisplay(frame: frame),
              ),
            ),
          ),
          const SizedBox(width: FfSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: live ? p.verified : p.accent,
                      ),
                    ),
                    const SizedBox(width: FfSpace.xs + 2),
                    Text(
                      live ? 'CONNECTED' : 'VIRTUAL BOT',
                      style: FfType.overline.copyWith(color: p.textMuted),
                    ),
                  ],
                ),
                const SizedBox(height: FfSpace.xs),
                Text(
                  'Your bot',
                  style: FfType.titleMedium.copyWith(color: p.textPrimary),
                ),
                const SizedBox(height: FfSpace.xxs),
                Text(
                  comfort,
                  style: FfType.bodySmall.copyWith(color: p.textSecondary),
                  maxLines: 2,
                ),
                const SizedBox(height: FfSpace.sm),
                Wrap(
                  spacing: FfSpace.sm,
                  runSpacing: FfSpace.xs,
                  children: <Widget>[
                    FilledButton.tonal(
                      onPressed: () => openQuickTimer(context),
                      style: _compact,
                      child: const Text('Timer'),
                    ),
                    OutlinedButton(
                      onPressed: live
                          ? () => context.go(FfTab.plan.path)
                          : () => context.push('/more/device'),
                      style: _compact,
                      child: Text(live ? 'Routines' : 'Connect'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static final ButtonStyle _compact = ButtonStyle(
    visualDensity: VisualDensity.compact,
    padding: WidgetStateProperty.all(
      const EdgeInsets.symmetric(horizontal: FfSpace.md),
    ),
  );
}

// --- the room -----------------------------------------------------------------

class _Room extends ConsumerWidget {
  const _Room();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.ff;
    final s = ref.watch(botSensorsProvider);
    final sitting = ref.watch(botSittingProvider);
    final comfort = bot.HomeScreen.comfort(s.tempC, s.humidity).$1;
    final light = s.light;
    final d = s.distanceCm;

    final tiles = <Widget>[
      _SensorTile(
        icon: Icons.thermostat_rounded,
        label: 'Temperature',
        value: s.tempC == null ? '--' : '${s.tempC!.toStringAsFixed(1)}°',
        note: comfort,
        good: comfort.startsWith('Comf'),
      ),
      _SensorTile(
        icon: Icons.water_drop_outlined,
        label: 'Humidity',
        value: s.humidity == null ? '--' : '${s.humidity!.round()}%',
        note: s.humidity == null
            ? 'No sensor'
            : s.humidity! > 70
            ? 'Humid'
            : s.humidity! < 30
            ? 'Dry air'
            : 'Fine',
        good: s.humidity != null && s.humidity! >= 30 && s.humidity! <= 70,
      ),
      _SensorTile(
        icon: s.dark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
        label: 'Light',
        value: light == null ? '--' : '${(light / 10.23).round()}%',
        note: light == null ? 'No sensor' : _lightNote(light),
        good: light != null && light >= 350,
      ),
      _SensorTile(
        icon: Icons.person_outline_rounded,
        label: 'At the desk',
        value: !s.present ? 'Away' : '$d cm',
        note: !s.present
            ? 'Nobody in front'
            : d! < 30
            ? 'Sit back a little'
            : 'Good distance',
        good: s.present && d! >= 30,
      ),
    ];

    return FfSection(
      title: 'Room',
      subtitle: 'From your bot\'s sensors.',
      children: <Widget>[
        LayoutBuilder(
          builder: (context, c) {
            final w = (c.maxWidth - FfSpace.sm) / 2;
            return Wrap(
              spacing: FfSpace.sm,
              runSpacing: FfSpace.sm,
              children: <Widget>[
                for (final t in tiles) SizedBox(width: w, child: t),
              ],
            );
          },
        ),
        const SizedBox(height: FfSpace.sm),
        FfCard(
          padding: const EdgeInsets.symmetric(
            horizontal: FfSpace.md,
            vertical: FfSpace.md,
          ),
          child: Row(
            children: <Widget>[
              Icon(Icons.chair_outlined, size: 18, color: p.textMuted),
              const SizedBox(width: FfSpace.md),
              Expanded(
                child: Text(
                  'Sitting',
                  style: FfType.body.copyWith(color: p.textPrimary),
                ),
              ),
              Text(
                bot.HomeScreen.sittingLabel(sitting),
                style: FfType.titleSmall.copyWith(
                  color: sitting != null && sitting >= BotOs.sitNudge
                      ? p.paused
                      : p.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _lightNote(int light) =>
      switch (bot.HomeScreen.lightVerdict(light)) {
        'Dark' => 'Too dark to study',
        'Too dim' => 'Turn a lamp on',
        'Good' => 'Good for reading',
        _ => 'Bright',
      };
}

class _SensorTile extends StatelessWidget {
  const _SensorTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.note,
    required this.good,
  });

  final IconData icon;
  final String label;
  final String value;
  final String note;
  final bool good;

  @override
  Widget build(BuildContext context) {
    final p = context.ff;
    return FfCard(
      padding: const EdgeInsets.all(FfSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, size: 16, color: p.textMuted),
              const SizedBox(width: FfSpace.xs + 2),
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  style: FfType.overline.copyWith(color: p.textMuted),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: FfSpace.sm),
          Text(value, style: FfType.statValue.copyWith(color: p.textPrimary)),
          const SizedBox(height: FfSpace.xxs),
          Row(
            children: <Widget>[
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: good ? p.verified : p.paused,
                ),
              ),
              const SizedBox(width: FfSpace.xs + 2),
              Expanded(
                child: Text(
                  note,
                  style: FfType.caption.copyWith(color: p.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// --- play ---------------------------------------------------------------------

class _Play extends ConsumerWidget {
  const _Play();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(botOsProvider.select((f) => f.frame ~/ 25));
    final best = ref.read(botOsProvider.notifier).os.settings.best;

    String? score(String id) => best[id]?.toString();
    final games = <(BotApp, String, String, IconData, String?)>[
      (
        BotApp.snake,
        'Snake',
        'Steer with the knob',
        Icons.gesture_rounded,
        score('snake'),
      ),
      (
        BotApp.blocks,
        'Blocks',
        'Stack and clear lines',
        Icons.view_quilt_rounded,
        score('blocks'),
      ),
      (
        BotApp.dino,
        'Dino Run',
        'Jump with a touch pad',
        Icons.directions_run_rounded,
        score('dino'),
      ),
      (
        BotApp.flap,
        'Flap',
        'Tap to fly the gaps',
        Icons.flutter_dash_rounded,
        score('flap'),
      ),
      (
        BotApp.starRaid,
        'Star Raid',
        'Hold off the invaders',
        Icons.rocket_launch_rounded,
        score('raid'),
      ),
      (
        BotApp.breakout,
        'Breakout',
        'The knob is the paddle',
        Icons.grid_view_rounded,
        score('breakout'),
      ),
      (
        BotApp.paddle,
        'Paddle',
        'Beat the bot to seven',
        Icons.sports_tennis_rounded,
        score('paddle'),
      ),
      (
        BotApp.g2048,
        '2048',
        'Slide and merge tiles',
        Icons.apps_rounded,
        score('2048'),
      ),
      (
        BotApp.reaction,
        'Reaction',
        'How fast is your tap?',
        Icons.bolt_rounded,
        best['reaction'] == null ? null : '${best['reaction']} ms',
      ),
    ];

    return FfSection(
      title: 'Play',
      subtitle: 'Games on your bot, for breaks.',
      children: <Widget>[
        SizedBox(
          height: 176,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: games.length,
            separatorBuilder: (_, __) => const SizedBox(width: FfSpace.sm),
            itemBuilder: (context, i) => SizedBox(
              width: 132,
              child: _GameCard(
                title: games[i].$2,
                hint: games[i].$3,
                icon: games[i].$4,
                best: games[i].$5,
                onTap: () => _openOnBot(context, ref, games[i].$1),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _GameCard extends StatelessWidget {
  const _GameCard({
    required this.title,
    required this.hint,
    required this.icon,
    required this.best,
    required this.onTap,
  });

  final String title;
  final String hint;
  final IconData icon;
  final String? best;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.ff;
    return FfCard(
      onTap: onTap,
      padding: const EdgeInsets.all(FfSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: p.accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(FfRadius.sm),
            ),
            child: Icon(icon, size: 20, color: p.accent),
          ),
          const SizedBox(height: FfSpace.md),
          Text(
            title,
            style: FfType.titleSmall.copyWith(color: p.textPrimary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: FfSpace.xxs),
          Text(
            hint,
            style: FfType.caption.copyWith(color: p.textMuted),
            maxLines: 2,
          ),
          const SizedBox(height: FfSpace.sm),
          Text(
            best == null ? 'Not played yet' : 'Best $best',
            style: FfType.caption.copyWith(color: p.textSecondary),
          ),
        ],
      ),
    );
  }
}

// --- listen -------------------------------------------------------------------

class _Listen extends ConsumerWidget {
  const _Listen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FfSection(
      title: 'Listen',
      subtitle:
          'Classics on the bot\'s buzzer, the way a music box plays them.',
      action: TextButton(
        onPressed: () => _allTunes(context, ref),
        child: const Text('All tunes'),
      ),
      children: <Widget>[
        FfCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: <Widget>[for (var i = 0; i < 4; i++) _TuneRow(index: i)],
          ),
        ),
      ],
    );
  }

  static Future<void> _allTunes(BuildContext context, WidgetRef ref) =>
      showModalBottomSheet<void>(
        context: context,
        useRootNavigator: true,
        isScrollControlled: true,
        builder: (context) => SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.75,
            ),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: FfSpace.md),
              children: <Widget>[
                for (var i = 0; i < Melodies.all.length; i++)
                  _TuneRow(index: i),
              ],
            ),
          ),
        ),
      );
}

class _TuneRow extends ConsumerWidget {
  const _TuneRow({required this.index});

  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.ff;
    final m = Melodies.all[index];
    final seconds = Rtttl.lengthMs(Rtttl.parse(m.rtttl)) ~/ 1000;
    return ListTile(
      leading: Icon(Icons.music_note_rounded, color: p.accent),
      title: Text(m.title, style: FfType.body.copyWith(color: p.textPrimary)),
      subtitle: Text(
        '${m.by} · ${seconds}s',
        style: FfType.caption.copyWith(color: p.textMuted),
      ),
      trailing: Icon(Icons.play_circle_outline_rounded, color: p.textSecondary),
      onTap: () {
        final nav = Navigator.of(context);
        if (nav.canPop()) nav.pop();
        _openOnBot(context, ref, BotApp.music, arg: index + 1);
      },
    );
  }
}

// --- today --------------------------------------------------------------------

class _TodayStrip extends ConsumerWidget {
  const _TodayStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.ff;
    final seconds = ref.watch(todaySecondsProvider).valueOrNull;
    final streak = ref.watch(streakProvider).valueOrNull?.current ?? 0;
    final verified = Duration(seconds: seconds?.verified ?? 0);
    final claimed = Duration(seconds: seconds?.claimed ?? 0);

    return FfCard(
      onTap: () => context.go(FfTab.stats.path),
      child: Row(
        children: <Widget>[
          FfRing(
            progress: claimed.inSeconds == 0
                ? 0
                : verified.inSeconds / claimed.inSeconds,
            size: 52,
            thickness: 5,
            color: p.verified,
            child: Icon(Icons.verified_outlined, size: 18, color: p.textMuted),
          ),
          const SizedBox(width: FfSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'TODAY',
                  style: FfType.overline.copyWith(color: p.textMuted),
                ),
                const SizedBox(height: FfSpace.xxs),
                Text(
                  '${FfFormat.humanDuration(verified)} verified',
                  style: FfType.titleSmall.copyWith(color: p.textPrimary),
                ),
                Text(
                  streak == 0
                      ? 'Of ${FfFormat.humanDuration(claimed)} claimed'
                      : 'Of ${FfFormat.humanDuration(claimed)} claimed · '
                            '$streak day streak',
                  style: FfType.caption.copyWith(color: p.textSecondary),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: p.textMuted),
        ],
      ),
    );
  }
}

// --- running ------------------------------------------------------------------

class _RunningCard extends StatelessWidget {
  const _RunningCard({required this.session});

  final SessionSnapshot session;

  @override
  Widget build(BuildContext context) {
    final p = context.ff;
    final block = session.block!;
    final category = FfCategory.fromId(block.category);
    final paused = session.state == SessionState.paused;

    return FfCard(
      accent: category.color,
      onTap: () => context.go(FfTab.bot.path),
      child: Row(
        children: <Widget>[
          FfRing(
            progress: session.progress,
            size: 64,
            thickness: 6,
            color: category.color,
            dimmed: paused,
            child: Icon(
              paused ? Icons.pause_rounded : Icons.timer_outlined,
              size: 20,
              color: p.textSecondary,
            ),
          ),
          const SizedBox(width: FfSpace.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  session.autoMode
                      ? 'BLOCK ${session.queueIndex + 1} OF ${session.queue.length}'
                      : 'RUNNING',
                  style: FfType.overline.copyWith(color: p.accent),
                ),
                Text(
                  block.name,
                  style: FfType.titleMedium.copyWith(color: p.textPrimary),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  category.label,
                  style: FfType.caption.copyWith(color: category.color),
                ),
              ],
            ),
          ),
          Text(
            FfFormat.clock(session.remaining),
            style: FfType.countdownMd.copyWith(
              color: paused ? p.textMuted : p.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
