import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ff_format.dart';
import '../../design/components/ff_badge.dart';
import '../../design/components/ff_card.dart';
import '../../design/components/ff_ring.dart';
import '../../design/components/ff_stat_tile.dart';
import '../../design/components/ff_states.dart';
import '../../design/ff_colors.dart';
import '../../design/ff_theme.dart';
import '../../design/ff_tokens.dart';
import '../../design/ff_typography.dart';
import '../settings/theme_controller.dart';

/// The design-system gallery.
///
/// Exists so a component can be reviewed in all three themes without hunting
/// for a screen that happens to use it — and so a regression in the palette is
/// visible in one place rather than discovered in a report six screens later.
class GalleryScreen extends ConsumerStatefulWidget {
  const GalleryScreen({super.key});

  @override
  ConsumerState<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends ConsumerState<GalleryScreen> {
  double _progress = 0.62;

  @override
  Widget build(BuildContext context) {
    final p = context.ff;
    final mode = ref.watch(themeControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Design system'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Cycle theme (${mode.name})',
            icon: const Icon(Icons.contrast_rounded),
            onPressed: () => ref.read(themeControllerProvider.notifier).cycle(),
          ),
          const SizedBox(width: FfSpace.sm),
        ],
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: FfBreakpoint.maxContentWidth,
            ),
            child: ListView(
              padding: const EdgeInsets.all(FfSpace.gutter),
              children: <Widget>[
                _header(
                  context,
                  'Category palette',
                  'Derived from the firmware RGB565 words, never hand-picked.',
                ),
                FfCard(
                  child: Column(
                    children: <Widget>[
                      for (final c in FfCategory.values) ...<Widget>[
                        if (c.index > 0) const SizedBox(height: FfSpace.md),
                        Row(
                          children: <Widget>[
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: c.color,
                                borderRadius: BorderRadius.circular(
                                  FfRadius.sm,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '${c.id}',
                                style: FfType.titleSmall.copyWith(
                                  color: c.onColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: FfSpace.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    c.label,
                                    style: FfType.titleSmall.copyWith(
                                      color: p.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    c.hint,
                                    style: FfType.bodySmall.copyWith(
                                      color: p.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '0x${c.rgb565.toRadixString(16).toUpperCase().padLeft(4, '0')}',
                              style: FfType.caption.copyWith(
                                color: p.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                _header(context, 'Ring', 'The app\'s echo of the LED halo.'),
                FfCard(
                  child: Column(
                    children: <Widget>[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: <Widget>[
                          FfRing(
                            progress: _progress,
                            size: 130,
                            color: FfCategory.deepWork.color,
                            child: Text(
                              FfFormat.clock(
                                Duration(
                                  seconds: (5400 * (1 - _progress)).round(),
                                ),
                              ),
                              style: FfType.countdownMd.copyWith(
                                color: p.textPrimary,
                              ),
                            ),
                          ),
                          FfRing(
                            progress: _progress,
                            size: 130,
                            color: FfCategory.deepWork.color,
                            dimmed: true,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Text(
                                  FfFormat.clock(
                                    Duration(
                                      seconds: (5400 * (1 - _progress)).round(),
                                    ),
                                  ),
                                  style: FfType.countdownMd.copyWith(
                                    color: p.textMuted,
                                  ),
                                ),
                                Text(
                                  'PAUSED',
                                  style: FfType.overline.copyWith(
                                    color: p.paused,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: FfSpace.lg),
                      Slider(
                        value: _progress,
                        onChanged: (v) => setState(() => _progress = v),
                      ),
                      FfProgressBar(
                        progress: _progress,
                        color: FfCategory.output.color,
                      ),
                    ],
                  ),
                ),

                _header(
                  context,
                  'Stat tiles',
                  'The headline metric is a pair, never a single flattering number.',
                ),
                FfStatGrid(
                  tiles: <Widget>[
                    FfStatTile(
                      label: 'Verified today',
                      value: '3h 42m',
                      secondary: 'of 5h 26m claimed · 68%',
                      valueColor: p.verified,
                      icon: Icons.verified_outlined,
                    ),
                    FfStatTile(
                      label: 'Streak',
                      value: '12',
                      unit: 'days',
                      secondary: 'Best 21',
                      icon: Icons.local_fire_department_outlined,
                    ),
                    FfStatTile(
                      label: 'Violations',
                      value: '3',
                      secondary: 'Longest focus 92m',
                      valueColor: p.paused,
                      icon: Icons.warning_amber_rounded,
                    ),
                  ],
                ),

                _header(
                  context,
                  'Badges',
                  'The same four words the device prints on its Task screen.',
                ),
                FfCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Wrap(
                        spacing: FfSpace.sm,
                        runSpacing: FfSpace.sm,
                        children: const <Widget>[
                          FfBadge(label: 'TRACK', state: FfBadgeState.on),
                          FfBadge(label: 'DOCK', state: FfBadgeState.on),
                          FfBadge(label: 'HERE', state: FfBadgeState.off),
                          FfBadge(
                            label: 'BT',
                            state: FfBadgeState.unavailable,
                            tooltip: 'No bot connected',
                          ),
                        ],
                      ),
                      const SizedBox(height: FfSpace.lg),
                      Wrap(
                        spacing: FfSpace.sm,
                        runSpacing: FfSpace.sm,
                        children: <Widget>[
                          for (final c in FfCategory.values)
                            FfCategoryChip(category: c, dense: true),
                        ],
                      ),
                      const SizedBox(height: FfSpace.lg),
                      const Row(
                        children: <Widget>[
                          FfProvenanceBadge(live: false),
                          SizedBox(width: FfSpace.sm),
                          FfProvenanceBadge(live: true),
                        ],
                      ),
                    ],
                  ),
                ),

                _header(context, 'Buttons and inputs', null),
                FfCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Wrap(
                        spacing: FfSpace.sm,
                        runSpacing: FfSpace.sm,
                        children: <Widget>[
                          FilledButton(
                            onPressed: () {},
                            child: const Text('Start block'),
                          ),
                          OutlinedButton(
                            onPressed: () {},
                            child: const Text('Skip'),
                          ),
                          TextButton(
                            onPressed: () {},
                            child: const Text('Edit'),
                          ),
                        ],
                      ),
                      const SizedBox(height: FfSpace.lg),
                      const TextField(
                        decoration: InputDecoration(
                          labelText: 'Block name',
                          hintText: 'Deep Work 1',
                          helperText:
                              'Max 16 characters, the firmware struct is fixed',
                        ),
                      ),
                    ],
                  ),
                ),

                _header(context, 'Insight and states', null),
                const FfInsightLine(
                  text:
                      'You verified 68% of your claimed study time this week. '
                      'Your best focus happens between 06:00 and 09:00.',
                ),
                const SizedBox(height: FfSpace.sm),
                FfCard(
                  padding: EdgeInsets.zero,
                  child: const FfEmptyState(
                    icon: Icons.inbox_rounded,
                    title: 'Nothing here yet',
                    message: 'Every list in the app gets a real empty state.',
                    compact: true,
                  ),
                ),

                _header(context, 'Type scale', null),
                FfCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '25:30',
                        style: FfType.countdownXl.copyWith(
                          color: p.textPrimary,
                        ),
                      ),
                      const SizedBox(height: FfSpace.sm),
                      Text(
                        'Display large',
                        style: FfType.displayLarge.copyWith(
                          color: p.textPrimary,
                        ),
                      ),
                      Text(
                        'Title large',
                        style: FfType.titleLarge.copyWith(color: p.textPrimary),
                      ),
                      Text(
                        'Body: the quick brown fox jumps over the lazy dog.',
                        style: FfType.body.copyWith(color: p.textSecondary),
                      ),
                      Text(
                        'Caption',
                        style: FfType.caption.copyWith(color: p.textMuted),
                      ),
                      Text(
                        'OVERLINE',
                        style: FfType.overline.copyWith(color: p.textMuted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: FfSpace.xxxl),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context, String title, String? subtitle) {
    final p = context.ff;
    return Padding(
      padding: const EdgeInsets.only(
        top: FfSpace.xl,
        bottom: FfSpace.md,
        left: FfSpace.xs,
        right: FfSpace.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title.toUpperCase(),
            style: FfType.overline.copyWith(color: p.accent),
          ),
          if (subtitle != null) ...<Widget>[
            const SizedBox(height: FfSpace.xxs),
            Text(
              subtitle,
              style: FfType.bodySmall.copyWith(color: p.textMuted),
            ),
          ],
        ],
      ),
    );
  }
}
