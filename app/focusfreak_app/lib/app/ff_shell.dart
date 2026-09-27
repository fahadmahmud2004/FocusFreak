import 'package:flutter/material.dart';

import '../design/ff_theme.dart';
import '../design/ff_tokens.dart';
import '../features/timer/floating_timer.dart';

/// Top-level destinations.
///
/// Five, deliberately. The bot sits in the middle because it is the thing that
/// makes this app not a to-do list.
enum FfTab {
  home('Home', Icons.home_outlined, Icons.home_rounded, '/home'),
  plan('Plan', Icons.checklist_outlined, Icons.checklist_rounded, '/plan'),
  bot('Bot', Icons.smart_toy_outlined, Icons.smart_toy_rounded, '/bot'),
  stats('Stats', Icons.bar_chart_outlined, Icons.bar_chart_rounded, '/stats'),
  more('More', Icons.more_horiz_outlined, Icons.more_horiz_rounded, '/more');

  const FfTab(this.label, this.icon, this.selectedIcon, this.path);

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String path;
}

/// The persistent navigation frame.
///
/// Uses a bottom bar on phones and a rail once there is width for it, so the
/// macOS and web builds used during development are not a cramped phone in a
/// large window.
class FfShell extends StatelessWidget {
  const FfShell({
    super.key,
    required this.child,
    required this.currentIndex,
    required this.onSelect,
    this.location = '',
  });

  final Widget child;
  final int currentIndex;
  final ValueChanged<int> onSelect;

  /// The current path. The floating timer shows only on a tab's own page, so
  /// it never sits on top of a sub-page's buttons.
  final String location;

  @override
  Widget build(BuildContext context) {
    final p = context.ff;
    final wide = FfBreakpoint.isExpanded(context);
    final onTabRoot =
        location.isEmpty || FfTab.values.any((t) => t.path == location);
    final timer = onTabRoot
        ? FloatingTimer(onBotTab: currentIndex == FfTab.bot.index)
        : null;

    if (wide) {
      return Scaffold(
        floatingActionButton: timer,
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        body: Row(
          children: <Widget>[
            NavigationRail(
              selectedIndex: currentIndex,
              onDestinationSelected: onSelect,
              backgroundColor: p.surfaceElevated,
              labelType: NavigationRailLabelType.all,
              indicatorColor: p.accent.withValues(alpha: 0.18),
              destinations: <NavigationRailDestination>[
                for (final t in FfTab.values)
                  NavigationRailDestination(
                    icon: Icon(t.icon, color: p.textMuted),
                    selectedIcon: Icon(t.selectedIcon, color: p.accent),
                    label: Text(t.label),
                  ),
              ],
            ),
            VerticalDivider(width: 1, color: p.border),
            Expanded(child: child),
          ],
        ),
      );
    }

    return Scaffold(
      body: child,
      floatingActionButton: timer,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: p.border)),
        ),
        child: NavigationBar(
          selectedIndex: currentIndex,
          onDestinationSelected: onSelect,
          destinations: <Widget>[
            for (final t in FfTab.values)
              NavigationDestination(
                icon: Icon(t.icon),
                selectedIcon: Icon(t.selectedIcon),
                label: t.label,
              ),
          ],
        ),
      ),
    );
  }
}

/// Standard page scaffold: a large title, optional actions, and a body that
/// stays readable on a wide window by capping its own width.
class FfPage extends StatelessWidget {
  const FfPage({
    super.key,
    required this.title,
    required this.child,
    this.actions,
    this.subtitle,
    this.scrollable = true,
    this.padding = const EdgeInsets.fromLTRB(
      FfSpace.gutter,
      FfSpace.sm,
      FfSpace.gutter,
      FfSpace.xxxl,
    ),
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final List<Widget>? actions;
  final bool scrollable;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final p = context.ff;
    final body = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: FfBreakpoint.maxContentWidth),
      child: Padding(padding: padding, child: child),
    );

    return Scaffold(
      backgroundColor: p.surfaceBase,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(title),
            if (subtitle != null)
              Text(
                subtitle!,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: p.textMuted),
              ),
          ],
        ),
        actions: actions,
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: scrollable ? SingleChildScrollView(child: body) : body,
        ),
      ),
    );
  }
}
