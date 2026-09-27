import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/ff_shell.dart';
import '../../core/ff_format.dart';
import '../../design/components/ff_ring.dart';
import '../../design/ff_colors.dart';
import '../../design/ff_theme.dart';
import '../../design/ff_tokens.dart';
import '../../design/ff_typography.dart';
import '../../domain/model/session_state.dart';
import 'quick_timer_sheet.dart';
import 'session_controller.dart';

/// Open the quick timer and, once it starts, go to the Bot tab.
///
/// The Bot tab is where anything running lives: the face follows the block
/// and the panel under it has the controls.
Future<void> openQuickTimer(BuildContext context) async {
  final started = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    // Above the tab bar and the floating timer, not underneath them.
    useRootNavigator: true,
    builder: (_) => const QuickTimerSheet(),
  );
  if (started == true && context.mounted) context.go(FfTab.bot.path);
}

/// The quick timer, one tap away on every tab, bottom right.
///
/// Frosted glass so the page reads through it. Idle it is a timer button;
/// while something runs it becomes the countdown with a ring, and a tap goes
/// to the Bot tab. It is not shown on the Bot tab, which has both.
class FloatingTimer extends ConsumerWidget {
  const FloatingTimer({super.key, required this.onBotTab});

  final bool onBotTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.ff;
    final s = ref.watch(sessionControllerProvider);

    // The Bot tab has its own timer button and its own countdown, and its
    // controls sit where this would float.
    if (onBotTab) return const SizedBox.shrink();

    final Widget content;
    final VoidCallback onTap;
    if (!s.isActive) {
      onTap = () => openQuickTimer(context);
      content = SizedBox(
        width: 52,
        height: 52,
        child: Icon(Icons.timer_outlined, color: p.accent, size: 24),
      );
    } else {
      final block = s.block!;
      final color = FfCategory.fromId(block.category).color;
      final paused = s.state == SessionState.paused;
      onTap = () => context.go(FfTab.bot.path);
      content = Padding(
        padding: const EdgeInsets.fromLTRB(
          FfSpace.sm,
          FfSpace.sm,
          FfSpace.lg,
          FfSpace.sm,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            FfRing(
              progress: s.progress,
              size: 34,
              thickness: 3,
              color: color,
              dimmed: paused,
              child: Icon(
                paused ? Icons.pause_rounded : Icons.timer_outlined,
                size: 15,
                color: p.textSecondary,
              ),
            ),
            const SizedBox(width: FfSpace.sm),
            Text(
              FfFormat.clock(s.remaining),
              style: FfType.countdownSm.copyWith(
                color: paused ? p.textMuted : p.textPrimary,
              ),
            ),
          ],
        ),
      );
    }

    return Tooltip(
      message: s.isActive ? 'Open on the Bot tab' : 'Quick timer',
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(FfRadius.pill),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.28),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(FfRadius.pill),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Material(
              color: p.surfaceRaised.withValues(alpha: 0.55),
              shape: StadiumBorder(
                side: BorderSide(
                  color:
                      (s.isActive
                              ? FfCategory.fromId(s.block!.category).color
                              : p.accent)
                          .withValues(alpha: 0.35),
                ),
              ),
              child: InkWell(
                customBorder: const StadiumBorder(),
                onTap: onTap,
                child: content,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
