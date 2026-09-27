import 'package:flutter/material.dart';

import '../ff_colors.dart';
import '../ff_theme.dart';
import '../ff_tokens.dart';
import '../ff_typography.dart';

/// The four status badges the device shows along the bottom of its Task
/// screen: `TRACK` `DOCK` `HERE` `BT`.
///
/// The app uses the identical words and the identical on/off/unknown states so
/// that a user who learns the device already knows the app, and vice versa.
enum FfBadgeState {
  /// The condition holds. Green.
  on,

  /// The condition has dropped out. Amber.
  off,

  /// There is no sensor for this, so the app refuses to claim either way.
  /// Rendered muted — never green, never red.
  unavailable,
}

class FfBadge extends StatelessWidget {
  const FfBadge({
    super.key,
    required this.label,
    required this.state,
    this.tooltip,
  });

  final String label;
  final FfBadgeState state;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final p = context.ff;
    final (Color fg, Color bg) = switch (state) {
      FfBadgeState.on => (p.verified, p.verified.withValues(alpha: 0.14)),
      FfBadgeState.off => (p.paused, p.paused.withValues(alpha: 0.14)),
      FfBadgeState.unavailable => (p.textMuted, p.surfaceRaised),
    };

    final chip = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: FfSpace.sm,
        vertical: FfSpace.xs + 1,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(FfRadius.sm),
        border: Border.all(
          color: state == FfBadgeState.unavailable
              ? p.border
              : fg.withValues(alpha: 0.35),
        ),
      ),
      child: Text(
        label.toUpperCase(),
        style: FfType.overline.copyWith(color: fg),
      ),
    );

    return Semantics(
      label:
          '$label ${switch (state) {
            FfBadgeState.on => 'confirmed',
            FfBadgeState.off => 'not confirmed',
            FfBadgeState.unavailable => 'unavailable',
          }}',
      child: tooltip == null ? chip : Tooltip(message: tooltip!, child: chip),
    );
  }
}

/// A category pill carrying its firmware colour.
class FfCategoryChip extends StatelessWidget {
  const FfCategoryChip({
    super.key,
    required this.category,
    this.dense = false,
    this.showLabel = true,
  });

  final FfCategory category;
  final bool dense;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final color = category.color;
    if (!showLabel) {
      return Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
    }
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? FfSpace.sm : FfSpace.md,
        vertical: dense ? FfSpace.xxs : FfSpace.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(FfRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: FfSpace.sm - 2),
          Text(
            category.label,
            style: (dense ? FfType.overline : FfType.caption).copyWith(
              color: context.ff.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// `VIRTUAL` / `LIVE` — the honesty marker on the bot screen, and the same
/// idea applied to session provenance (`APP-VERIFIED` vs `SENSOR-VERIFIED`).
class FfProvenanceBadge extends StatelessWidget {
  const FfProvenanceBadge({
    super.key,
    required this.live,
    this.liveLabel = 'LIVE',
    this.virtualLabel = 'VIRTUAL',
  });

  final bool live;
  final String liveLabel;
  final String virtualLabel;

  @override
  Widget build(BuildContext context) {
    final p = context.ff;
    final color = live ? p.verified : p.accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: FfSpace.sm, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(FfRadius.sm),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: FfSpace.xs + 1),
          Text(
            live ? liveLabel : virtualLabel,
            style: FfType.overline.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
