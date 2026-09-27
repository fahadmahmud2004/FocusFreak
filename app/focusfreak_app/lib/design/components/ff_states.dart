import 'package:flutter/material.dart';

import '../ff_theme.dart';
import '../ff_tokens.dart';
import '../ff_typography.dart';

/// Empty state.
///
/// Every list in this app gets one. An empty screen with no explanation is the
/// fastest way to make a new user close a productivity app and not come back.
class FfEmptyState extends StatelessWidget {
  const FfEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final p = context.ff;
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: FfSpace.xl,
          vertical: compact ? FfSpace.xl : FfSpace.xxxl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: compact ? 48 : 64,
              height: compact ? 48 : 64,
              decoration: BoxDecoration(
                color: p.surfaceRaised,
                shape: BoxShape.circle,
                border: Border.all(color: p.border),
              ),
              child: Icon(icon, size: compact ? 22 : 28, color: p.textMuted),
            ),
            const SizedBox(height: FfSpace.lg),
            Text(
              title,
              textAlign: TextAlign.center,
              style: FfType.titleMedium.copyWith(color: p.textPrimary),
            ),
            const SizedBox(height: FfSpace.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: FfType.bodySmall.copyWith(color: p.textMuted),
            ),
            if (actionLabel != null && onAction != null) ...<Widget>[
              const SizedBox(height: FfSpace.xl),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Error state. Shows what failed and offers the one action that might fix it.
class FfErrorState extends StatelessWidget {
  const FfErrorState({
    super.key,
    required this.message,
    this.detail,
    this.onRetry,
  });

  final String message;
  final String? detail;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final p = context.ff;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(FfSpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.error_outline_rounded, size: 32, color: p.broken),
            const SizedBox(height: FfSpace.lg),
            Text(
              message,
              textAlign: TextAlign.center,
              style: FfType.titleMedium.copyWith(color: p.textPrimary),
            ),
            if (detail != null) ...<Widget>[
              const SizedBox(height: FfSpace.sm),
              Text(
                detail!,
                textAlign: TextAlign.center,
                style: FfType.bodySmall.copyWith(color: p.textMuted),
              ),
            ],
            if (onRetry != null) ...<Widget>[
              const SizedBox(height: FfSpace.xl),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Try again'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A single line of plain, factual commentary — the visual home of
/// `InsightEngine` output.
///
/// Deliberately quiet: no exclamation marks, no trophies, no guilt. The
/// product's stance is that an accurate sentence motivates better than praise.
class FfInsightLine extends StatelessWidget {
  const FfInsightLine({super.key, required this.text, this.icon});

  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final p = context.ff;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: FfSpace.lg,
        vertical: FfSpace.md,
      ),
      decoration: BoxDecoration(
        color: p.accent.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(FfRadius.md),
        border: Border.all(color: p.accent.withValues(alpha: 0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon ?? Icons.insights_rounded, size: 16, color: p.accent),
          const SizedBox(width: FfSpace.md),
          Expanded(
            child: Text(
              text,
              style: FfType.bodySmall.copyWith(color: p.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
