import 'dart:convert';
import 'dart:io';

import 'package:destiny/application/livret/livret.dart';
import 'package:destiny/application/state/reglages_destiny.dart';
import 'package:destiny/domain/grammaire/lecture.dart';
import 'package:destiny/domain/grammaire/modeles.dart';
import 'package:destiny/domain/grammaire/textes.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'outils/grammaire_partagee.dart';

late Grammaire g;
late TextesDestiny t;

void main() {
  setUpAll(() async {
    final c = await chargerGrammaire();
    g = c.grammaire;
    t = c.textes;
  });

  test('les 24 animaux ont un exemple de vouloir et un exemple pour les enfants', () {
    final brut = jsonDecode(File('assets/data/destiny_grammaire.json').readAsStringSync()) as Map<String, dynamic>;
    final animaux = [
      for (final a in brut['archetypes'] as List)
        for (final an in (a as Map)['animaux'] as List) an as Map,
    ];
    expect(animaux, hasLength(24));
    for (final an in animaux) {
      expect('${an['exemple_vouloir'] ?? ''}'.trim(), isNotEmpty, reason: '${an['id']}');
      expect('${an['exemple_vouloir_kids'] ?? ''}'.trim(), isNotEmpty, reason: '${an['id']} (kids)');
    }
    // Le modèle les lit.
    expect(g.animal('lion')!.exempleVouloir,
        'Je veux que mon frère signe ce soir et me laisse reprendre le resto de papa.');
    expect(g.animal('rat')!.exempleVouloir, 'Je veux qu\'il me rende les 300 euros qu\'il me doit.');
    expect(g.animal('lion')!.exempleVouloirKids, 'Je veux que mon frère me laisse être le chef de la cabane.');
    expect(g.animaux.every((a) => a.exempleVouloir.isNotEmpty && a.exempleVouloirKids.isNotEmpty), isTrue);
  });

  test('une grammaire sans ces champs se lit quand même : les exemples restent vides', () {
    final brut = jsonDecode(File('assets/data/destiny_grammaire.json').readAsStringSync()) as Map<String, dynamic>;
    for (final a in brut['archetypes'] as List) {
      for (final an in (a as Map)['animaux'] as List) {
        (an as Map)
          ..remove('exemple_vouloir')
          ..remove('exemple_vouloir_kids');
      }
    }
    final sans = lireGrammaire(brut);
    expect(sans.animaux, hasLength(24));
    expect(sans.animaux.every((a) => a.exempleVouloir.isEmpty && a.exempleVouloirKids.isEmpty), isTrue);
    expect(sans.animal('lion')!.exempleVouloirPour(kids: true), isEmpty);
  });

  test('le mode admin : un exemple changé passe par-dessus la grammaire, et se remet', () async {
    SharedPreferences.setMockInitialValues({});
    final r = ReglagesDestiny();
    await r.changerExempleVouloir('lion', 'Je veux que le serveur m\'apporte l\'addition maintenant.');
    await r.changerExempleVouloir('rat', 'Je veux qu\'il me rende mes cartes.', kids: true);
    final g2 = g.avecExemplesVouloir(r.exemplesVouloir);
    expect(g2.animal('lion')!.exempleVouloir, 'Je veux que le serveur m\'apporte l\'addition maintenant.');
    expect(g2.animal('lion')!.exempleVouloirKids, g.animal('lion')!.exempleVouloirKids);
    expect(g2.animal('rat')!.exempleVouloirKids, 'Je veux qu\'il me rende mes cartes.');
    expect(g2.animal('rat')!.exempleVouloir, g.animal('rat')!.exempleVouloir);
    // Le reste de l'animal ne bouge pas.
    expect(g2.animal('lion')!.replique, g.animal('lion')!.replique);
    expect(g2.archetypeDeLAnimal('lion')!.id, 'leader');
    // Gardés dans les réglages…
    final relu = ReglagesDestiny();
    await relu.charger();
    expect(relu.exemplesVouloir, r.exemplesVouloir);
    // …et remis au texte du fichier.
    await r.changerExempleVouloir('lion', null);
    expect(g.avecExemplesVouloir(r.exemplesVouloir).animal('lion')!.exempleVouloir, g.animal('lion')!.exempleVouloir);
    expect(identical(g.avecExemplesVouloir(const {}), g), isTrue);
  });

  group('le livret : « Trouver son vouloir »', () {
    List<BlocLivret> blocs(Livret l) => [for (final s in l.sections) ...s.blocs];

    test('la formule, les trois tests, ce qui ne marche pas, pourquoi, le vêtement et les 24 exemples', () {
      final l = construireLivret(g, t);
      final tout = blocs(l).map((b) => b.texte).join('\n');
      expect(tout, contains(t.t('trouver_vouloir.titre')));
      expect(tout, contains('Je veux que [quelqu\'un sur scène] [fasse quelque chose] ce soir.'));
      for (final test in t.liste('trouver_vouloir.tests')) {
        expect(tout, contains(test));
      }
      expect(tout, contains(t.t('trouver_vouloir.ne_marche_pas')));
      expect(tout, contains(t.t('trouver_vouloir.pourquoi')));
      expect(tout, contains(t.t('trouver_vouloir.vetement')));
      expect(tout, contains('Ce ne sont que des exemples : on les adapte au lieu et au partenaire.'));
      final tableau = blocs(l).whereType<TableauLivret>().single;
      expect(tableau.entetes, ['Archétype', 'Animal', 'Exemple']);
      expect(tableau.lignes, hasLength(24));
      expect(tableau.lignes.first, ['Leader', 'Lion', g.animal('lion')!.exempleVouloir]);
    });

    test('en mode kids : la formule des enfants et leurs exemples, jamais ceux des adultes', () {
      final l = construireLivret(g, t, kids: true);
      final tout = blocs(l).map((b) => b.texte).join('\n');
      expect(tout, contains('Je veux que [quelqu\'un ici] [fasse quelque chose] aujourd\'hui.'));
      expect(tout, isNot(contains('[quelqu\'un sur scène]')));
      final tableau = blocs(l).whereType<TableauLivret>().single;
      expect(tableau.lignes, hasLength(24));
      for (final a in g.animaux) {
        expect(tout, contains(a.exempleVouloirKids));
        expect(tout, isNot(contains(a.exempleVouloir)), reason: a.id);
      }
    });
  });
}
