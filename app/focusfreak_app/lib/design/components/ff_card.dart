import 'package:flutter/material.dart';

import '../ff_theme.dart';
import '../ff_tokens.dart';
import '../ff_typography.dart';

/// The app's single surface primitive.
///
/// Elevation is expressed with a border and a surface step, never a drop
/// shadow — shadows read as smudges on the near-black theme the logo implies.
class FfCard extends StatelessWidget {
  const FfCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(FfSpace.lg),
    this.onTap,
    this.accent,
    this.raised = false,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  /// Draws a 3px colour rail down the leading edge — used to carry a block's
  /// category colour without tinting the whole card.
  final Color? accent;

  final bool raised;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final p = context.ff;
    final content = Padding(padding: padding, child: child);

    return Material(
      color: raised ? p.surfaceRaised : p.surfaceElevated,
      borderRadius: FfRadius.cardRadius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: FfRadius.cardRadius,
        // The accent rail is drawn as an overlay, clipped by the Material's
        // rounded corners.
        //
        // Two approaches were tried and rejected. A stretched Row child
        // collapses to zero height in an unbounded vertical context, silently
        // making the whole card invisible with no error. A thick left
        // BorderSide is rejected outright by BoxDecoration, which requires
        // uniform widths whenever a borderRadius is present. A positioned
        // overlay has neither problem: the Stack takes its size from the
        // content, and the rail stretches to whatever that turns out to be.
        child: Stack(
          children: <Widget>[
            Container(
              decoration: BoxDecoration(
                borderRadius: FfRadius.cardRadius,
                border: Border.all(color: borderColor ?? p.border),
              ),
              child: content,
            ),
            if (accent != null)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: 3,
                child: ColoredBox(color: accent!),
              ),
          ],
        ),
      ),
    );
  }
}

/// A titled group of related cards. Keeps section spacing consistent across
/// every screen instead of each one inventing its own header.
class FfSection extends StatelessWidget {
  const FfSection({
    super.key,
    required this.title,
    required this.children,
    this.action,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget? action;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final p = context.ff;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(
            left: FfSpace.xs,
            right: FfSpace.xs,
            bottom: FfSpace.sm,
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: FfType.titleMedium.copyWith(color: p.textPrimary),
                    ),
                    if (subtitle != null)
                      Padding(
                        padding: const EdgeInsets.only(top: FfSpace.xxs),
                        child: Text(
                          subtitle!,
                          style: FfType.bodySmall.copyWith(color: p.textMuted),
                        ),
                      ),
                  ],
                ),
              ),
              if (action != null) action!,
            ],
          ),
        ),
        for (var i = 0; i < children.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(height: FfSpace.sm),
          children[i],
        ],
      ],
    );
  }
}
