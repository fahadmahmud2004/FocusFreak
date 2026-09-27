/// Getting your data out, and back in.
///
/// FocusFreak has no cloud and no account, so this screen is the only thing
/// standing between a lost phone and a lost year. It is deliberately plain:
/// three files out, one file in, and nothing that needs explaining.
library;

import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/ff_shell.dart';
import '../../app/providers.dart';
import '../../design/components/ff_card.dart';
import '../../design/ff_theme.dart';
import '../../design/ff_tokens.dart';
import '../../design/ff_typography.dart';
import 'data_export.dart';
import 'data_import.dart';

class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  bool _busy = false;
  String? _note;
  bool _noteIsProblem = false;

  /// Every button on this screen writes or reads a real file, and the browser
  /// build has no file system to write to — `path_provider` has no web
  /// implementation, so an export there fails at the first line rather than
  /// producing anything. Saying so is better than a button that throws.
  String _onPhone(String subtitle) => kIsWeb ? 'Works on your phone' : subtitle;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;

    return FfPage(
      title: 'Your data',
      subtitle: 'It lives on this phone only. Keep a copy somewhere.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          FfSection(
            title: 'Back up',
            subtitle:
                'The full backup is the one to keep. It is the only '
                'file that can be restored.',
            children: <Widget>[
              FfCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: <Widget>[
                    _Action(
                      icon: Icons.inventory_2_outlined,
                      title: 'Full backup',
                      subtitle: _onPhone('Everything, as one JSON file'),
                      enabled: !_busy && !kIsWeb,
                      onTap: _exportJson,
                    ),
                    Divider(height: 1, color: ff.border),
                    _Action(
                      icon: Icons.table_chart_outlined,
                      title: 'Blocks as a spreadsheet',
                      subtitle: _onPhone(
                        'One row per block, for Excel or Sheets',
                      ),
                      enabled: !_busy && !kIsWeb,
                      onTap: _exportSessionsCsv,
                    ),
                    Divider(height: 1, color: ff.border),
                    _Action(
                      icon: Icons.calendar_month_outlined,
                      title: 'Days as a spreadsheet',
                      subtitle: _onPhone('One row per day'),
                      enabled: !_busy && !kIsWeb,
                      onTap: _exportDaysCsv,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: FfSpace.xl),
          FfSection(
            title: 'Restore',
            subtitle:
                'Adds what is in the file to what is already here. '
                'Nothing is deleted.',
            children: <Widget>[
              FfCard(
                padding: EdgeInsets.zero,
                child: _Action(
                  icon: Icons.settings_backup_restore_rounded,
                  title: 'Restore from a backup',
                  subtitle: kIsWeb
                      ? 'Works on your phone'
                      : 'Pick a FocusFreak backup file',
                  enabled: !_busy && !kIsWeb,
                  onTap: _restore,
                ),
              ),
            ],
          ),
          if (kIsWeb) ...<Widget>[
            const SizedBox(height: FfSpace.lg),
            Text(
              'This is the browser build, which has no file system. Backups '
              'work on the phone.',
              style: FfType.bodySmall.copyWith(color: ff.textMuted),
            ),
          ],
          if (_note != null) ...<Widget>[
            const SizedBox(height: FfSpace.lg),
            Text(
              _note!,
              style: FfType.bodySmall.copyWith(
                color: _noteIsProblem ? ff.broken : ff.verified,
              ),
            ),
          ],
          if (_busy) ...<Widget>[
            const SizedBox(height: FfSpace.lg),
            const Center(child: CircularProgressIndicator()),
          ],
        ],
      ),
    );
  }

  // -- out -------------------------------------------------------------------------

  Future<void> _exportJson() => _run(() async {
    final db = ref.read(databaseProvider);
    final sessions = await db.select(db.sessions).get();
    final days = await ref.read(sessionRepositoryProvider).allDays();
    final routines = await db.select(db.routines).get();
    final blocks = await db.select(db.blocks).get();
    final tasks = await db.select(db.tasks).get();
    final settings = await ref.read(settingsRepositoryProvider).exportAll();

    await _share(
      const DataExport().fullJson(
        sessions: sessions,
        days: days,
        routines: routines,
        blocks: blocks,
        tasks: tasks,
        settings: settings,
      ),
      _stamped('focusfreak-backup', 'json'),
    );
    return 'Backup ready to save or send.';
  });

  Future<void> _exportSessionsCsv() => _run(() async {
    final db = ref.read(databaseProvider);
    final sessions = await db.select(db.sessions).get();
    await _share(
      const DataExport().sessionsCsv(sessions),
      _stamped('focusfreak-blocks', 'csv'),
    );
    return '${sessions.length} blocks exported.';
  });

  Future<void> _exportDaysCsv() => _run(() async {
    final days = await ref.read(sessionRepositoryProvider).allDays();
    await _share(
      const DataExport().daysCsv(days),
      _stamped('focusfreak-days', 'csv'),
    );
    return '${days.length} days exported.';
  });

  /// Writes to a temporary file and hands it to the system share sheet.
  ///
  /// A file rather than shared text: a year of blocks is megabytes, and text
  /// sharing is truncated by half the apps that receive it.
  Future<void> _share(String contents, String filename) async {
    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, filename));
    await file.writeAsString(contents, flush: true);
    await SharePlus.instance.share(
      ShareParams(
        files: <XFile>[XFile(file.path)],
        fileNameOverrides: <String>[filename],
      ),
    );
  }

  static String _stamped(String base, String extension) {
    final day = DateTime.now().toIso8601String().split('T').first;
    return '$base-$day.$extension';
  }

  // -- in --------------------------------------------------------------------------

  Future<void> _restore() async {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: <String>['json'],
    );
    final path = picked?.files.single.path;
    if (path == null || !mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore this backup?'),
        content: const Text(
          'Anything in the file is added to what is on this phone. Where both '
          'have the same block or routine, the one in the file wins.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await _run(() async {
      final source = await File(path).readAsString(encoding: utf8);
      final result = await DataImport(
        ref.read(databaseProvider),
      ).restore(source);
      // Settings are watched through their own providers, but the theme is
      // read once at startup — nudge it so a restored theme applies now.
      ref.invalidate(routinesProvider);
      return result.summary;
    });
  }

  // -- plumbing ---------------------------------------------------------------------

  Future<void> _run(Future<String> Function() action) async {
    setState(() {
      _busy = true;
      _note = null;
    });
    try {
      final message = await action();
      if (mounted) {
        setState(() {
          _note = message;
          _noteIsProblem = false;
        });
      }
    } on NotABackupException catch (e) {
      if (mounted) {
        setState(() {
          _note = e.message;
          _noteIsProblem = true;
        });
      }
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _note = 'That did not work: $e';
          _noteIsProblem = true;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.ff;
    return ListTile(
      enabled: enabled,
      leading: Icon(icon, color: p.textSecondary),
      title: Text(title),
      subtitle: Text(
        subtitle,
        style: FfType.bodySmall.copyWith(color: p.textMuted),
      ),
      trailing: Icon(Icons.chevron_right_rounded, color: p.textMuted),
      onTap: enabled ? onTap : null,
    );
  }
}
