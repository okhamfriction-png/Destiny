import 'dart:io';

import 'package:destiny/application/version.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('la version affichée est celle du pubspec : 2.3.4+30', () {
    final ligne = File('pubspec.yaml').readAsLinesSync().firstWhere((l) => l.startsWith('version:'));
    final version = ligne.split(':').last.trim();
    expect(version, '2.3.4+30');
    expect(version.split('+').first, kVersionAppli);
  });

  test('le changelog en français commence par la version du pubspec', () {
    final changelog = File('CHANGELOG.md').readAsStringSync();
    expect(changelog, contains('## $kVersionAppli'));
    expect(changelog.indexOf('## $kVersionAppli'), lessThan(changelog.indexOf('## 2.0.0')));
    expect(changelog.indexOf('## 2.0.0'), lessThan(changelog.indexOf('## 1.')));
  });

  test('la release de la version a ses notes', () {
    final notes = File('docs/release_notes/v$kVersionAppli.md');
    expect(notes.existsSync(), isTrue);
    expect(notes.readAsLinesSync().first, startsWith('# DestinyStory v$kVersionAppli'));
  });
}
