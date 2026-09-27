import 'package:flutter/material.dart';

import '../../../core/ff_format.dart';
import '../../../data/db/database.dart';
import '../../../data/repo/routine_repository.dart';
import '../../../design/components/ff_card.dart';
import '../../../design/ff_colors.dart';
import '../../../design/ff_theme.dart';
import '../../../design/ff_tokens.dart';
import '../../../design/ff_typography.dart';

/// A proportional bar of a routine's whole day, coloured by category.
///
/// Shows the *shape* of a routine at a glance — how much of the day is deep
/// work versus sleep versus slack — which is the thing a list of block names
/// cannot convey.
class RoutineShapeBar extends StatelessWidget {
  const RoutineShapeBar({super.key, required this.blocks, this.height = 8});

  final List<Block> blocks;
  final double height;

  @override
  Widget build(BuildContext context) {
    final p = context.ff;
    if (blocks.isEmpty) {
      return Container(
        height: height,
        decoration: BoxDecoration(
          color: p.surfaceRaised,
          borderRadius: BorderRadius.circular(height),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: SizedBox(
        height: height,
        // `stretch` is required, not cosmetic: a ColoredBox has no child and
        // therefore no intrinsic height, so under the Row's default centre
        // alignment every segment collapses to zero and the bar paints nothing
        // while still reporting the right size. It is safe here because the
        // SizedBox above gives the Row a tight height to stretch into.
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (final b in blocks)
              Expanded(
                flex: b.durationMin.clamp(1, 100000),
                child: ColoredBox(color: FfColors.category(b.category)),
              ),
          ],
        ),
      ),
    );
  }
}

class RoutineCard extends StatelessWidget {
  const RoutineCard({
    super.key,
    required this.detail,
    this.onTap,
    this.trailing,
  });

  final RoutineWithBlocks detail;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final p = context.ff;
    final r = detail.routine;

    return FfCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            r.name,
                            style: FfType.titleMedium.copyWith(
                              color: p.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (r.isBuiltIn) ...<Widget>[
                          const SizedBox(width: FfSpace.sm),
                          _Tag(label: 'BUILT-IN', color: p.accent),
                        ],
                      ],
                    ),
                    if (r.description.isNotEmpty) ...<Widget>[
                      const SizedBox(height: FfSpace.xxs),
                      Text(
                        r.description,
                        style: FfType.bodySmall.copyWith(color: p.textMuted),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: FfSpace.lg),
          RoutineShapeBar(blocks: detail.blocks),
          const SizedBox(height: FfSpace.md),
          Wrap(
            spacing: FfSpace.md,
            runSpacing: FfSpace.xs,
            children: <Widget>[
              _Stat(
                icon: Icons.view_agenda_outlined,
                label: '${detail.blocks.length} blocks',
              ),
              _Stat(
                icon: Icons.psychology_outlined,
                label: '${FfFormat.minutes(detail.deepWorkMinutes)} deep',
              ),
              _Stat(
                icon: Icons.verified_outlined,
                label: '${detail.trackedCount} tracked',
              ),
              if (detail.isTimed && detail.blocks.isNotEmpty)
                _Stat(
                  icon: Icons.schedule_rounded,
                  label:
                      'From '
                      '${FfFormat.timeOfDay(detail.blocks.first.startMin)}',
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.ff.textMuted;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 13, color: c),
        const SizedBox(width: FfSpace.xs + 1),
        Text(label, style: FfType.caption.copyWith(color: c)),
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: FfSpace.sm, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(FfRadius.sm),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(label, style: FfType.overline.copyWith(color: color)),
    );
  }
}
