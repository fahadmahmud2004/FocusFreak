import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// No em or en dashes in anything the app shows. They read as machine-written
/// copy, so the screen uses a full stop, a comma or a colon instead. Comments
/// are free to use them; string literals are not.
void main() {
  test('no em or en dash in a string the user can read', () {
    final offenders = <String>[];
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart') && !f.path.endsWith('.g.dart'));
    for (final file in files) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i].trimLeft();
        if (line.startsWith('//')) continue;
        final code = line.split(' //').first;
        if (!code.contains("'") && !code.contains('"')) continue;
        if (code.contains('—') || code.contains('–') || code.contains('---')) {
          offenders.add('${file.path}:${i + 1}');
        }
      }
    }
    expect(offenders, isEmpty);
  });
}
