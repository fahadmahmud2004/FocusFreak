/// The name and face on the More tab.
///
/// Local, like everything else: a name typed into a text field and a photo
/// **copied into the app's own storage**. There is no account, nothing is
/// uploaded, and a backup that includes the name is a file on this phone.
///
/// The copy matters for the same reason it did for the alarm track: a path
/// handed over by the Android picker is a grant that can expire, and a broken
/// image link is a worse profile than none.
library;

import 'dart:io';

// Grapheme clusters, not code units: a monogram built with `substring` cuts a
// Bangla name — or an emoji — in half.
import 'package:characters/characters.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../app/providers.dart';
import '../../data/repo/settings_repository.dart';

enum PhotoPickOutcome { chosen, cancelled, failed, unsupported }

class ProfileStore {
  ProfileStore(this._settings);

  final SettingsRepository _settings;

  /// The picker only returns a real path where there is a real file system.
  /// On the web it returns bytes with nowhere to keep them, so the option is
  /// not offered rather than offered and broken.
  bool get canPickPhoto => !kIsWeb;

  Future<void> setName(String name) =>
      _settings.setString(SettingKey.userName, name.trim());

  Future<PhotoPickOutcome> pickPhoto() async {
    if (!canPickPhoto) return PhotoPickOutcome.unsupported;

    try {
      final picked = await FilePicker.pickFiles(type: FileType.image);
      final path = picked?.files.single.path;
      if (path == null) return PhotoPickOutcome.cancelled;

      final dir = await getApplicationDocumentsDirectory();
      // The name carries a stamp so the widget tree sees a new path and
      // reloads: Flutter caches `FileImage` by path, and reusing one would
      // show the old photo until the app restarted.
      final copy = File(
        p.join(
          dir.path,
          'profile_${DateTime.now().millisecondsSinceEpoch}${p.extension(path)}',
        ),
      );
      await _removeExisting();
      await File(path).copy(copy.path);

      await _settings.setString(SettingKey.userPhotoFile, copy.path);
      return PhotoPickOutcome.chosen;
    } on Object {
      return PhotoPickOutcome.failed;
    }
  }

  Future<void> removePhoto() async {
    await _removeExisting();
    await _settings.setString(SettingKey.userPhotoFile, '');
  }

  Future<void> _removeExisting() async {
    final current = await _settings.getString(SettingKey.userPhotoFile);
    if (current.isEmpty) return;
    try {
      final file = File(current);
      if (file.existsSync()) await file.delete();
    } on Object {
      // A stray copy is a few hundred kilobytes, not a failure worth stopping
      // the user over.
    }
  }
}

final profileStoreProvider = Provider<ProfileStore>(
  (ref) => ProfileStore(ref.watch(settingsRepositoryProvider)),
);

final userNameProvider = StreamProvider<String>(
  (ref) =>
      ref.watch(settingsRepositoryProvider).watchString(SettingKey.userName),
);

final userPhotoProvider = StreamProvider<String>(
  (ref) => ref
      .watch(settingsRepositoryProvider)
      .watchString(SettingKey.userPhotoFile),
);

/// Up to two letters for the monogram shown when there is no photo.
///
/// Falls back to the app's own mark rather than to a blank circle or a
/// stranger's silhouette icon.
String initialsOf(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty);
  if (parts.isEmpty) return '';
  if (parts.length == 1) {
    final one = parts.first;
    return one.characters.take(2).toString().toUpperCase();
  }
  return (parts.first.characters.first + parts.last.characters.first)
      .toUpperCase();
}
