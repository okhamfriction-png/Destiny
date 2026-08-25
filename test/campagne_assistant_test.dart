import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:destiny/application/assistant/campagne_assistant.dart';

void main() {
  group('sansPrenoms', () {
    test('remplacement mot entier, insensible à la casse', () {
      final r = sansPrenoms('Naël attrape la balle, naël court.',
          {'Naël': 'le renard'});
      expect(r, 'le renard attrape la balle, le renard court.');
    });

    test('un prénom à l\'intérieur d\'un mot n\'est pas touché', () {
      final r = sansPrenoms('Naelle range la salle.', {'Naël': 'le renard'});
      expect(r, 'Naelle range la salle.');
    });

    test('une transcription vide reste vide', () {
      expect(sansPrenoms('', {'Naël': 'le renard'}), '');
    });
  });

  group('MemoireEpisode.depuis', () {
    test('du JSON propre', () {
      final m = MemoireEpisode.depuis('{"resume": "Ils ont joué.", "suite": "Le méchant revient."}');
      expect(m.resume, 'Ils ont joué.');
      expect(m.suite, 'Le méchant revient.');
    });

    test('du JSON entouré de texte', () {
      final m = MemoireEpisode.depuis(
          'Voici : {"resume": "R", "suite": "S"} — voilà.');
      expect(m.resume, 'R');
      expect(m.suite, 'S');
    });

    test('du texte brut sans JSON devient tout le résumé', () {
      final m = MemoireEpisode.depuis('Ils ont sauvé le village.');
      expect(m.resume, 'Ils ont sauvé le village.');
      expect(m.suite, '');
    });

    test('une réponse vide', () {
      final m = MemoireEpisode.depuis('');
      expect(m.resume, '');
      expect(m.suite, '');
    });
  });

  test('vie privée : le dossier de l\'assistant ne connaît aucune notion de suivi',
      () {
    final dossier = Directory('lib/application/assistant');
    final interdits = [
      'jeton',
      'score',
      'tracking',
      'campagne_store',
      'seancejouee',
      'entities/campagne',
    ];
    for (final f in dossier.listSync().whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      // On ignore les lignes de commentaire : une explication a le droit de
      // nommer ce que le code n'a pas le droit de toucher.
      final code = f
          .readAsLinesSync()
          .where((l) => !l.trimLeft().startsWith('//'))
          .join('\n')
          .toLowerCase();
      for (final mot in interdits) {
        expect(code.contains(mot), isFalse,
            reason: 'L\'assistant ne doit pas connaître « $mot » (${f.path})');
      }
    }
  });
}
