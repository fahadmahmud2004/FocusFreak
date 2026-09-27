import 'package:flutter/material.dart';

import '../ff_theme.dart';
import '../ff_tokens.dart';
import '../ff_typography.dart';

/// A single number with a label, and optionally the honest second number
/// beside it.
///
/// The `secondary` slot exists because FocusFreak's headline metric is a pair,
/// not a figure: verified minutes are only meaningful next to claimed minutes.
/// A tile that shows one without the other is the kind of flattering statistic
/// this product exists to replace.
class FfStatTile extends StatelessWidget {
  const FfStatTile({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    this.secondary,
    this.valueColor,
    this.icon,
    this.onTap,
  });

  final String label;
  final String value;
  final String? unit;
  final String? secondary;
  final Color? valueColor;
  final IconData? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.ff;
    return Material(
      color: p.surfaceElevated,
      borderRadius: FfRadius.cardRadius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(FfSpace.lg),
          decoration: BoxDecoration(
            borderRadius: FfRadius.cardRadius,
            border: Border.all(color: p.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                children: <Widget>[
                  if (icon != null) ...<Widget>[
                    Icon(icon, size: 14, color: p.textMuted),
                    const SizedBox(width: FfSpace.xs + 2),
                  ],
                  Expanded(
                    child: Text(
                      label.toUpperCase(),
                      style: FfType.overline.copyWith(color: p.textMuted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: FfSpace.sm),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: <Widget>[
                  Flexible(
                    child: Text(
                      value,
                      style: FfType.statValue.copyWith(
                        color: valueColor ?? p.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (unit != null) ...<Widget>[
                    const SizedBox(width: FfSpace.xs),
                    Text(
                      unit!,
                      style: FfType.statUnit.copyWith(color: p.textMuted),
                    ),
                  ],
                ],
              ),
              if (secondary != null) ...<Widget>[
                const SizedBox(height: FfSpace.xs),
                Text(
                  secondary!,
                  style: FfType.caption.copyWith(color: p.textMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A responsive row of [FfStatTile]s that reflows instead of overflowing.
class FfStatGrid extends StatelessWidget {
  const FfStatGrid({super.key, required this.tiles, this.minTileWidth = 150});

  final List<Widget> tiles;
  final double minTileWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = (constraints.maxWidth / minTileWidth).floor().clamp(
          1,
          tiles.length,
        );
        final spacing = FfSpace.sm;
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: <Widget>[
            for (final t in tiles) SizedBox(width: width, child: t),
          ],
        );
      },
    );
  }
}
