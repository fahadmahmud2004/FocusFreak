/// First run.
///
/// Three screens and out. It asks for a name, asks four questions about when
/// the user is actually awake, and picks the matching track in the season's
/// salah times.
///
/// The whole thing is skippable from the first screen. An app that will not
/// let you in until you have answered a quiz has already spent goodwill it has
/// not earned yet.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/ff_constants.dart';
import '../../data/repo/settings_repository.dart';
import '../../design/components/ff_card.dart';
import '../../design/ff_theme.dart';
import '../../core/ff_format.dart';
import '../../design/ff_tokens.dart';
import '../../design/ff_typography.dart';
import '../../domain/model/template.dart';

/// The three tracks, and what each one is for.
enum Chronotype {
  earlyBird(
    'earlyBird',
    'Early Bird',
    'Your best hours are before most people are up.',
  ),
  standard(
    'standard',
    'Standard',
    'A conventional day, with the hard work early.',
  ),
  nightOwl(
    'nightOwl',
    'Night Owl',
    'Your best hours are after the house goes quiet.',
  );

  const Chronotype(this.key, this.label, this.detail);

  /// Also the template key — the quiz picks a routine, not an abstraction.
  final String key;
  final String label;
  final String detail;

  /// Read from the track itself, for this season: wake-up moves with Fajr, so
  /// a fixed string here would be wrong for half the year.
  String get hours {
    final t = Templates.byKey(
      Templates.keyFor(key, RoutineSeason.of(DateTime.now())),
    )!;
    final wake = t.blocks.first.startMin!;
    final sleep = t.blocks.lastWhere((b) => b.category == 5).startMin!;
    return 'Wake ${FfFormat.timeOfDay(wake)} · '
        'Sleep ${FfFormat.timeOfDay(sleep)}';
  }

  static Chronotype fromKey(String key) => switch (key) {
    'earlyBird' => Chronotype.earlyBird,
    'nightOwl' => Chronotype.nightOwl,
    _ => Chronotype.standard,
  };
}

/// One question, and what each answer says about the day.
///
/// Scored on one axis: negative is earlier, positive is later. Four questions
/// so no single answer decides it, and the middle option is always a real
/// answer rather than a way of skipping.
class _Question {
  const _Question(this.text, this.answers);
  final String text;
  final List<(String label, int score)> answers;
}

const List<_Question> _quiz = <_Question>[
  _Question('Left alone with no alarm, when do you wake up?', <(String, int)>[
    ('Before 6', -2),
    ('Around 7 or 8', 0),
    ('After 9', 2),
  ]),
  _Question('When does hard work feel easiest?', <(String, int)>[
    ('Early morning', -2),
    ('Late morning or afternoon', 0),
    ('Late at night', 2),
  ]),
  _Question('How is the first hour after you wake?', <(String, int)>[
    ('Sharp straight away', -1),
    ('Slow, then fine', 0),
    ('Rough for a while', 1),
  ]),
  _Question(
    'If tomorrow is free, when do you go to bed tonight?',
    <(String, int)>[
      ('Before 10', -2),
      ('Around 11 or midnight', 0),
      ('After 1', 2),
    ],
  ),
];

Chronotype _scoreToType(int score) {
  if (score <= -3) return Chronotype.earlyBird;
  if (score >= 3) return Chronotype.nightOwl;
  return Chronotype.standard;
}

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key, this.onDone});

  /// Called once the flow has written its settings. The app swaps itself for
  /// the real router when [SettingKey.onboardingDone] flips, so this is only
  /// for callers that opened it deliberately.
  final VoidCallback? onDone;

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pages = PageController();
  final TextEditingController _name = TextEditingController();

  /// One answer index per question, or −1 for unanswered.
  final List<int> _answers = List<int>.filled(_quiz.length, -1);

  bool _saving = false;

  int get _score {
    var total = 0;
    for (var i = 0; i < _quiz.length; i++) {
      if (_answers[i] >= 0) total += _quiz[i].answers[_answers[i]].$2;
    }
    return total;
  }

  bool get _answered => !_answers.contains(-1);

  @override
  void dispose() {
    _pages.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _finish({Chronotype? type}) async {
    if (_saving) return;
    setState(() => _saving = true);

    final settings = ref.read(settingsRepositoryProvider);
    final name = _name.text.trim();
    if (name.isNotEmpty) {
      await settings.setString(SettingKey.userName, name);
    }
    if (type != null) {
      await settings.setString(SettingKey.chronotype, type.key);

      // Point the app at the matching routine. The templates are seeded at
      // startup, so the row exists by the time anyone can answer a quiz.
      // The track's variant for this season, so salah blocks land on today's
      // times rather than the other half of the year's.
      final routines = await ref.read(routineRepositoryProvider).allTemplates();
      final match =
          routines[Templates.keyFor(
            type.key,
            RoutineSeason.of(DateTime.now()),
          )] ??
          routines[type.key];
      if (match != null) {
        await settings.setString(SettingKey.activeRoutineId, match);
      }
    }

    // Last, so a crash halfway through means the flow runs again rather than
    // leaving someone in an app that never asked them anything.
    await settings.setBool(SettingKey.onboardingDone, true);
    widget.onDone?.call();
  }

  void _to(int page) => _pages.animateToPage(
    page,
    duration: FfMotion.normal,
    curve: Curves.easeOutCubic,
  );

  @override
  Widget build(BuildContext context) {
    final p = context.ff;

    return Scaffold(
      backgroundColor: p.surfaceBase,
      body: SafeArea(
        child: PageView(
          controller: _pages,
          physics: const NeverScrollableScrollPhysics(),
          children: <Widget>[
            _Welcome(
              name: _name,
              onSkip: _saving ? null : () => _finish(),
              onNext: _saving ? null : () => _to(1),
            ),
            _Quiz(
              answers: _answers,
              onAnswer: (q, a) => setState(() => _answers[q] = a),
              onBack: () => _to(0),
              onNext: _answered ? () => _to(2) : null,
            ),
            _Result(
              type: _scoreToType(_score),
              saving: _saving,
              onBack: () => _to(1),
              onAccept: (type) => _finish(type: type),
            ),
          ],
        ),
      ),
    );
  }
}

// -- pages ----------------------------------------------------------------------

/// The shared frame: a scrolling body with a fixed row of buttons under it.
///
/// The list is named `body` rather than `children` on purpose — it is content,
/// not this widget's children, and calling it `children` would ask every call
/// site to put it last.
class _Page extends StatelessWidget {
  const _Page({required this.body, this.footer});

  final List<Widget> body;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(FfSpace.gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: body,
              ),
            ),
          ),
          if (footer != null) ...<Widget>[
            const SizedBox(height: FfSpace.lg),
            footer!,
          ],
        ],
      ),
    );
  }
}

class _Welcome extends StatelessWidget {
  const _Welcome({
    required this.name,
    required this.onSkip,
    required this.onNext,
  });

  final TextEditingController name;
  final VoidCallback? onSkip;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final p = context.ff;

    return _Page(
      body: <Widget>[
        const SizedBox(height: FfSpace.xl),
        // The full lockup, and big — it carries the name itself, so the only
        // words under it are the ones the logo does not say.
        ClipRRect(
          borderRadius: BorderRadius.circular(FfRadius.lg),
          child: Image.asset(
            'assets/logo/focusfreak_logo.png',
            width: 200,
            height: 200,
            filterQuality: FilterQuality.medium,
          ),
        ),
        const SizedBox(height: FfSpace.md),
        Text(
          FfApp.tagline,
          style: FfType.titleMedium.copyWith(color: p.textMuted),
        ),
        const SizedBox(height: FfSpace.xl),
        Text(
          'FocusFreak measures two numbers: the time you claimed, and the '
          'time it could actually verify. Everything else is in service of '
          'that difference.\n\n'
          'It all stays on this phone. No account, nothing to sign up for.',
          style: FfType.body.copyWith(color: p.textSecondary),
        ),
        const SizedBox(height: FfSpace.xl),
        FfCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'What should we call you?',
                style: FfType.titleSmall.copyWith(color: p.textPrimary),
              ),
              const SizedBox(height: FfSpace.sm),
              TextField(
                controller: name,
                textCapitalization: TextCapitalization.words,
                maxLength: 40,
                decoration: const InputDecoration(
                  hintText: 'Your name',
                  counterText: '',
                ),
              ),
              Text(
                'Optional, and only used on this phone and your reports.',
                style: FfType.caption.copyWith(color: p.textMuted),
              ),
            ],
          ),
        ),
      ],
      footer: Row(
        children: <Widget>[
          TextButton(onPressed: onSkip, child: const Text('Skip setup')),
          const Spacer(),
          FilledButton(onPressed: onNext, child: const Text('Next')),
        ],
      ),
    );
  }
}

class _Quiz extends StatelessWidget {
  const _Quiz({
    required this.answers,
    required this.onAnswer,
    required this.onBack,
    required this.onNext,
  });

  final List<int> answers;
  final void Function(int question, int answer) onAnswer;
  final VoidCallback onBack;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final p = context.ff;

    return _Page(
      body: <Widget>[
        const SizedBox(height: FfSpace.lg),
        Text(
          'When are you actually awake?',
          style: FfType.titleLarge.copyWith(color: p.textPrimary),
        ),
        const SizedBox(height: FfSpace.xs),
        Text(
          'All three are built around the five salah. They differ in when '
          'your best hours fall.',
          style: FfType.bodySmall.copyWith(color: p.textMuted),
        ),
        const SizedBox(height: FfSpace.lg),
        for (var q = 0; q < _quiz.length; q++) ...<Widget>[
          FfCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  _quiz[q].text,
                  style: FfType.titleSmall.copyWith(color: p.textPrimary),
                ),
                const SizedBox(height: FfSpace.sm),
                Wrap(
                  spacing: FfSpace.sm,
                  runSpacing: FfSpace.xs,
                  children: <Widget>[
                    for (var a = 0; a < _quiz[q].answers.length; a++)
                      ChoiceChip(
                        label: Text(_quiz[q].answers[a].$1),
                        selected: answers[q] == a,
                        onSelected: (_) => onAnswer(q, a),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: FfSpace.md),
        ],
      ],
      footer: Row(
        children: <Widget>[
          TextButton(onPressed: onBack, child: const Text('Back')),
          const Spacer(),
          FilledButton(
            onPressed: onNext,
            child: Text(onNext == null ? 'Answer all four' : 'See the track'),
          ),
        ],
      ),
    );
  }
}

class _Result extends StatelessWidget {
  const _Result({
    required this.type,
    required this.saving,
    required this.onBack,
    required this.onAccept,
  });

  final Chronotype type;
  final bool saving;
  final VoidCallback onBack;
  final void Function(Chronotype type) onAccept;

  @override
  Widget build(BuildContext context) {
    final p = context.ff;
    final template = Templates.byKey(type.key);

    return _Page(
      body: <Widget>[
        const SizedBox(height: FfSpace.lg),
        Text(
          'Start here',
          style: FfType.titleLarge.copyWith(color: p.textPrimary),
        ),
        const SizedBox(height: FfSpace.xs),
        Text(
          'A starting point, not a verdict. Every track is editable, and you '
          'can switch whenever the day changes.',
          style: FfType.bodySmall.copyWith(color: p.textMuted),
        ),
        const SizedBox(height: FfSpace.lg),
        for (final option in Chronotype.values)
          Padding(
            padding: const EdgeInsets.only(bottom: FfSpace.sm),
            child: _TrackCard(
              type: option,
              recommended: option == type,
              blocks: Templates.byKey(option.key)?.blocks.length ?? 0,
              onTap: saving ? null : () => onAccept(option),
            ),
          ),
        if (template != null) ...<Widget>[
          const SizedBox(height: FfSpace.sm),
          Text(
            template.basis,
            style: FfType.caption.copyWith(color: p.textMuted),
          ),
        ],
      ],
      footer: Row(
        children: <Widget>[
          TextButton(
            onPressed: saving ? null : onBack,
            child: const Text('Back'),
          ),
          const Spacer(),
          FilledButton(
            onPressed: saving ? null : () => onAccept(type),
            child: Text(saving ? 'Setting up…' : 'Use ${type.label}'),
          ),
        ],
      ),
    );
  }
}

class _TrackCard extends StatelessWidget {
  const _TrackCard({
    required this.type,
    required this.recommended,
    required this.blocks,
    required this.onTap,
  });

  final Chronotype type;
  final bool recommended;
  final int blocks;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.ff;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(FfRadius.lg),
      child: FfCard(
        child: Row(
          children: <Widget>[
            Icon(
              recommended
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: recommended ? p.accent : p.textMuted,
              size: 20,
            ),
            const SizedBox(width: FfSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Text(
                        type.label,
                        style: FfType.titleSmall.copyWith(color: p.textPrimary),
                      ),
                      if (recommended) ...<Widget>[
                        const SizedBox(width: FfSpace.sm),
                        Text(
                          'Suggested',
                          style: FfType.overline.copyWith(color: p.accent),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    type.hours,
                    style: FfType.bodySmall.copyWith(color: p.textSecondary),
                  ),
                  Text(
                    '${type.detail}${blocks > 0 ? ' · $blocks blocks' : ''}',
                    style: FfType.caption.copyWith(color: p.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
