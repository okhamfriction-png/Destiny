import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Les assets déclarés dans le pubspec (fichiers et dossiers).
List<String> _declares() {
  final lignes = File('pubspec.yaml').readAsLinesSync();
  final debut = lignes.indexWhere((l) => l.trim() == 'assets:');
  return [
    for (final l in lignes.skip(debut + 1).takeWhile((l) => l.startsWith('    - ') || l.trim().startsWith('#')))
      if (l.trim().startsWith('- ')) l.trim().substring(2).trim(),
    // Les polices de la section `fonts:` sont embarquées à leur chemin.
    for (final l in lignes)
      if (l.trim().startsWith('- asset: ')) l.trim().substring('- asset: '.length).trim(),
  ];
}

void main() {
  test('chaque fichier lu par l\'appli est bien embarqué', () {
    final declares = _declares();
    expect(declares, isNotEmpty);
    bool embarque(String chemin) =>
        declares.any((d) => d == chemin || (d.endsWith('/') && chemin.startsWith(d) && !chemin.substring(d.length).contains('/')));

    final manquants = <String>{};
    final chemin = RegExp(r"'(assets/[A-Za-z0-9_./-]+\.(?:json|png|jpg|txt|wav|m4a|mp3|ttf))'");
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      for (final m in chemin.allMatches(f.readAsStringSync())) {
        final c = m.group(1)!;
        if (!embarque(c)) manquants.add('${f.path} : $c');
        expect(File(c).existsSync(), isTrue, reason: '$c (lu par ${f.path}) existe');
      }
    }
    expect(manquants, isEmpty);
  });
}
