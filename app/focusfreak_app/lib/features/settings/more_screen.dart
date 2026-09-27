import 'dart:async';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/ff_shell.dart';
import '../../app/providers.dart';
import '../../core/ff_constants.dart';
import '../../data/repo/settings_repository.dart';
import '../../design/components/ff_card.dart';
import '../../design/ff_theme.dart';
import '../../design/ff_tokens.dart';
import '../../design/ff_typography.dart';
import '../../platform/sound_player.dart';
import '../sound/alarm_scheduler.dart';
import '../sound/sound_cues.dart';
import 'profile_store.dart';
import 'theme_controller.dart';
import 'verification_section.dart';

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.ff;
    final mode = ref.watch(themeControllerProvider);

    return FfPage(
      title: 'More',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const _ProfileCard(),
          const SizedBox(height: FfSpace.xl),
          FfSection(
            title: 'Appearance',
            subtitle: 'Pick how the app looks.',
            children: <Widget>[
              FfCard(
                padding: const EdgeInsets.all(FfSpace.sm),
                child: RadioGroup<FfThemeMode>(
                  groupValue: mode,
                  onChanged: (v) {
                    if (v != null) {
                      ref.read(themeControllerProvider.notifier).set(v);
                    }
                  },
                  child: Column(
                    children: <Widget>[
                      for (final m in FfThemeMode.values)
                        RadioListTile<FfThemeMode>(
                          value: m,
                          activeColor: p.accent,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: FfSpace.sm,
                          ),
                          title: Text(switch (m) {
                            FfThemeMode.dark => 'Dark',
                            FfThemeMode.amoled => 'AMOLED black',
                            FfThemeMode.light => 'Light',
                          }),
                          subtitle: Text(
                            switch (m) {
                              FfThemeMode.dark => 'Easy on the eyes at night.',
                              FfThemeMode.amoled =>
                                'True black. Uses less battery on an OLED '
                                    'screen.',
                              FfThemeMode.light => 'For bright rooms.',
                            },
                            style: FfType.bodySmall.copyWith(
                              color: p.textMuted,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: FfSpace.xl),
          const _SoundSection(),
          const SizedBox(height: FfSpace.xl),
          const VerificationSection(),
          const SizedBox(height: FfSpace.xl),
          FfSection(
            title: 'Bot',
            subtitle: 'Optional. The app is complete without one.',
            children: <Widget>[
              FfCard(
                padding: EdgeInsets.zero,
                child: ListTile(
                  leading: Icon(
                    Icons.smart_toy_outlined,
                    color: p.textSecondary,
                  ),
                  title: const Text('Connect a bot'),
                  subtitle: Text(
                    'Pair a FocusFreak, or try the virtual one',
                    style: FfType.bodySmall.copyWith(color: p.textMuted),
                  ),
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    color: p.textMuted,
                  ),
                  onTap: () => context.push('/more/device'),
                ),
              ),
            ],
          ),
          const SizedBox(height: FfSpace.xl),
          FfSection(
            title: 'Your record',
            children: <Widget>[
              FfCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: <Widget>[
                    ListTile(
                      leading: Icon(
                        Icons.emoji_events_outlined,
                        color: p.textSecondary,
                      ),
                      title: const Text('Milestones'),
                      subtitle: Text(
                        'What you have reached so far',
                        style: FfType.bodySmall.copyWith(color: p.textMuted),
                      ),
                      trailing: Icon(
                        Icons.chevron_right_rounded,
                        color: p.textMuted,
                      ),
                      onTap: () => context.push('/more/achievements'),
                    ),
                    Divider(height: 1, color: p.border),
                    ListTile(
                      leading: Icon(
                        Icons.backup_outlined,
                        color: p.textSecondary,
                      ),
                      title: const Text('Your data'),
                      subtitle: Text(
                        'Back up, export, or restore',
                        style: FfType.bodySmall.copyWith(color: p.textMuted),
                      ),
                      trailing: Icon(
                        Icons.chevron_right_rounded,
                        color: p.textMuted,
                      ),
                      onTap: () => context.push('/more/data'),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: FfSpace.xl),
          FfSection(
            title: 'Developer',
            children: <Widget>[
              FfCard(
                padding: EdgeInsets.zero,
                child: ListTile(
                  leading: Icon(Icons.palette_outlined, color: p.textSecondary),
                  title: const Text('Design system gallery'),
                  subtitle: Text(
                    'Every component, in the current theme',
                    style: FfType.bodySmall.copyWith(color: p.textMuted),
                  ),
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    color: p.textMuted,
                  ),
                  onTap: () => context.push('/more/gallery'),
                ),
              ),
            ],
          ),
          const SizedBox(height: FfSpace.xl),
          FfSection(
            title: 'About',
            children: <Widget>[
              FfCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(FfRadius.md),
                          child: Image.asset(
                            'assets/logo/focusfreak_mark.png',
                            width: 44,
                            height: 44,
                            filterQuality: FilterQuality.medium,
                          ),
                        ),
                        const SizedBox(width: FfSpace.md),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              FfApp.name,
                              style: FfType.titleMedium.copyWith(
                                color: p.textPrimary,
                              ),
                            ),
                            Text(
                              FfApp.tagline,
                              style: FfType.bodySmall.copyWith(
                                color: p.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: FfSpace.lg),
                    Text(
                      'All data stays on this device. No accounts, no cloud, '
                      'no analytics. Bluetooth is the only thing that ever '
                      'leaves the phone, and only to your own bot.',
                      style: FfType.bodySmall.copyWith(color: p.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: FfSpace.xl),
          const _Colophon(),
        ],
      ),
    );
  }
}

/// Who is using the app.
///
/// A name and a face, both optional and both local — there is no account
/// behind this. Until it is filled in it says so plainly rather than showing a
/// stranger's silhouette and an empty line.
class _ProfileCard extends ConsumerWidget {
  const _ProfileCard();

  Future<void> _editName(
    BuildContext context,
    ProfileStore store,
    String current,
  ) async {
    final controller = TextEditingController(text: current);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Your name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          maxLength: 40,
          decoration: const InputDecoration(
            hintText: 'What should we call you?',
          ),
          onSubmitted: (v) => Navigator.of(context).pop(v),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name != null) await store.setName(name);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.ff;
    final store = ref.watch(profileStoreProvider);
    final name = ref.watch(userNameProvider).valueOrNull ?? '';
    final photo = ref.watch(userPhotoProvider).valueOrNull ?? '';

    Future<void> choosePhoto() async {
      final outcome = await store.pickPhoto();
      if (!context.mounted) return;
      final message = switch (outcome) {
        PhotoPickOutcome.chosen || PhotoPickOutcome.cancelled => null,
        PhotoPickOutcome.unsupported => 'Choosing a photo works on your phone.',
        PhotoPickOutcome.failed => 'That image could not be used.',
      };
      if (message != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    }

    return FfCard(
      child: Row(
        children: <Widget>[
          _Avatar(
            name: name,
            photoPath: photo,
            onTap: store.canPickPhoto ? choosePhoto : null,
          ),
          const SizedBox(width: FfSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  name.isEmpty ? 'Add your name' : name,
                  style: FfType.titleMedium.copyWith(
                    color: name.isEmpty ? p.textMuted : p.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  photo.isEmpty && store.canPickPhoto
                      ? 'Tap the circle for a photo'
                      : 'Kept on this phone',
                  style: FfType.bodySmall.copyWith(color: p.textMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (photo.isNotEmpty)
            IconButton(
              tooltip: 'Remove photo',
              icon: Icon(Icons.hide_image_outlined, color: p.textMuted),
              onPressed: store.removePhoto,
            ),
          IconButton(
            tooltip: 'Edit your name',
            icon: Icon(Icons.edit_outlined, color: p.textSecondary),
            onPressed: () => _editName(context, store, name),
          ),
        ],
      ),
    );
  }
}

/// The photo, the monogram, or the app's own mark — in that order.
class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.name,
    required this.photoPath,
    required this.onTap,
  });

  final String name;
  final String photoPath;
  final VoidCallback? onTap;

  static const double _size = 52;

  @override
  Widget build(BuildContext context) {
    final p = context.ff;
    final initials = initialsOf(name);
    final file = photoPath.isEmpty ? null : File(photoPath);

    return Semantics(
      button: onTap != null,
      label: onTap == null ? null : 'Choose a profile photo',
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: _size,
          height: _size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: p.surfaceRaised,
            border: Border.all(color: p.border),
          ),
          clipBehavior: Clip.antiAlias,
          alignment: Alignment.center,
          child: switch ((file, initials)) {
            (final File f, _) when f.existsSync() => Image.file(
              f,
              width: _size,
              height: _size,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.medium,
              // A photo the user moved or a phone that revoked access falls
              // back to the monogram rather than to a broken-image glyph.
              errorBuilder: (_, __, ___) => _Monogram(initials: initials),
            ),
            _ => _Monogram(initials: initials),
          },
        ),
      ),
    );
  }
}

class _Monogram extends StatelessWidget {
  const _Monogram({required this.initials});

  final String initials;

  @override
  Widget build(BuildContext context) {
    final p = context.ff;
    if (initials.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(FfSpace.xs),
        child: Image.asset(
          'assets/logo/focusfreak_mark.png',
          filterQuality: FilterQuality.medium,
        ),
      );
    }
    return Text(initials, style: FfType.titleMedium.copyWith(color: p.accent));
  }
}

/// The line at the bottom of everything.
class _Colophon extends StatelessWidget {
  const _Colophon();

  @override
  Widget build(BuildContext context) {
    final p = context.ff;
    final year = DateTime.now().year;

    return Center(
      child: Padding(
        padding: const EdgeInsets.only(bottom: FfSpace.md),
        child: Text.rich(
          TextSpan(
            style: FfType.caption.copyWith(color: p.textMuted),
            children: <InlineSpan>[
              TextSpan(text: '© $year '),
              TextSpan(
                text: FfApp.name,
                style: TextStyle(
                  color: p.textSecondary,
                  decoration: TextDecoration.underline,
                  decorationColor: p.border,
                ),
                recognizer: TapGestureRecognizer()
                  ..onTap = () => unawaited(
                    launchUrl(
                      Uri.parse(FfApp.siteUrl),
                      mode: LaunchMode.externalApplication,
                    ),
                  ),
              ),
              const TextSpan(text: '. All rights reserved.'),
            ],
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

/// Sound.
///
/// Two switches rather than one: the cues are feedback while you are sitting
/// there, the alarm is for when you are not. A library needs the first off and
/// the second on.
class _SoundSection extends ConsumerWidget {
  const _SoundSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.ff;
    final settings = ref.watch(settingsRepositoryProvider);
    final cues = ref.watch(soundCuesProvider);

    final effects = ref.watch(soundEffectsEnabledProvider).valueOrNull ?? true;
    final alarm = ref.watch(alarmEnabledProvider).valueOrNull ?? true;

    return FfSection(
      title: 'Sound',
      subtitle:
          'Nothing sounds when a block breaks. The bot\'s face carries '
          'that.',
      children: <Widget>[
        FfCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: <Widget>[
              SwitchListTile(
                value: effects,
                activeThumbColor: p.accent,
                title: const Text('Block sounds'),
                subtitle: Text(
                  'A chime when a block starts and ends, and a tick for the '
                  'last three seconds.',
                  style: FfType.bodySmall.copyWith(color: p.textMuted),
                ),
                secondary: IconButton(
                  tooltip: 'Hear it',
                  icon: Icon(
                    Icons.play_circle_outline_rounded,
                    color: p.textSecondary,
                  ),
                  onPressed: () => cues.preview(FfSound.blockStart),
                ),
                onChanged: (v) => settings.setBool(SettingKey.soundEffects, v),
              ),
              Divider(height: 1, color: p.border),
              SwitchListTile(
                value: alarm,
                activeThumbColor: p.accent,
                title: const Text('Alarm when a block ends'),
                subtitle: Text(
                  'Loud enough for the next room, and it still arrives if the '
                  'app is closed.',
                  style: FfType.bodySmall.copyWith(color: p.textMuted),
                ),
                secondary: IconButton(
                  tooltip: 'Hear it',
                  icon: Icon(
                    Icons.play_circle_outline_rounded,
                    color: p.textSecondary,
                  ),
                  onPressed: cues.playAlarm,
                ),
                // Permission is asked for here rather than at first launch:
                // the moment someone turns the alarm on is the moment the
                // request makes sense to them.
                onChanged: (v) async {
                  await settings.setBool(SettingKey.alarmEnabled, v);
                  if (v) await ref.read(alarmNotifierProvider).prepare();
                },
              ),
              Divider(height: 1, color: p.border),
              ListTile(
                leading: Icon(Icons.alarm_rounded, color: p.accent),
                title: const Text('Alarms and tones'),
                subtitle: Text(
                  'Wake-up alarms, and the tone a block ends with.',
                  style: FfType.bodySmall.copyWith(color: p.textMuted),
                ),
                trailing: Icon(Icons.chevron_right_rounded, color: p.textMuted),
                onTap: () => context.push('/more/alarms'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
