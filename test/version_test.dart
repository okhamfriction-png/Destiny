import 'dart:io';

import 'package:destiny/application/version.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('la version affichée est celle du pubspec : 2.0.0+20', () {
    final ligne = File('pubspec.yaml').readAsLinesSync().firstWhere((l) => l.startsWith('version:'));
    final version = ligne.split(':').last.trim();
    expect(version, '2.0.0+20');
    expect(version.split('+').first, kVersionAppli);
  });

  test('le changelog en français commence par la 2.0.0', () {
    final changelog = File('CHANGELOG.md').readAsStringSync();
    expect(changelog, contains('## 2.0.0'));
    expect(changelog.indexOf('## 2.0.0'), lessThan(changelog.indexOf('## 1.')));
  });
}
