import 'dart:convert';
import 'dart:io';

import 'package:destiny/domain/grammaire/lecture.dart';
import 'package:destiny/domain/grammaire/modeles.dart';
import 'package:flutter_test/flutter_test.dart';

import 'outils/grammaire_partagee.dart';

Map<String, dynamic> _brut() => jsonDecode(
        File('assets/data/destiny_grammaire.json').readAsStringSync())
    as Map<String, dynamic>;

void main() {
  group('Le fichier de grammaire', () {
    test('est valide', () async {
      final c = await chargerGrammaire();
      expect(c.erreurs, isEmpty);
    });

    test('12 archétypes, 3 familles, 24 animaux uniques', () async {
      final g = (await chargerGrammaire()).grammaire;
      expect(g.archetypes, hasLength(12));
      expect(g.familles.map((f) => f.id), FamilleId.values);
      expect(g.animaux, hasLength(24));
      expect(g.animaux.map((a) => a.id).toSet(), hasLength(24));
      for (final f in FamilleId.values) {
        expect(g.archetypesDe(f), hasLength(4), reason: 'famille ${f.name}');
      }
    });

    test('chaque archétype a sa montée complète et deux animaux', () async {
      final g = (await chargerGrammaire()).grammaire;
      for (final a in g.archetypes) {
        for (final p in PalierId.values) {
          expect(a.monteeA(p), isNotEmpty, reason: '${a.id} ${p.name}');
        }
        expect(g.animauxDe(a.id), hasLength(2));
        for (final an in g.animauxDe(a.id)) {
          expect(g.archetypeDeLAnimal(an.id)?.id, a.id);
        }
      }
    });

    test('chaque animal a sa réplique, son corps à chaque palier et son tempérament',
        () async {
      final g = (await chargerGrammaire()).grammaire;
      for (final an in g.animaux) {
        expect(an.replique, isNotEmpty, reason: an.id);
        expect(an.sourceReplique, isNotEmpty, reason: an.id);
        expect(an.posture, isNotEmpty, reason: an.id);
        expect(an.temperament, isNotEmpty, reason: an.id);
        for (final p in PalierId.values) {
          expect(an.corpsA(p), isNotEmpty, reason: '${an.id} ${p.name}');
        }
      }
      // Le port vient de la grammaire.
      expect(g.animal('chat')!.port, 'feutré');
    });

    test('quatre paliers nommés, quatre actes, huit règles d\'or', () async {
      final g = (await chargerGrammaire()).grammaire;
      expect(g.paliers.map((p) => p.id), PalierId.values);
      expect(g.palier(PalierId.supprime).nom, 'Il bloque les sorties');
      expect(g.actes, hasLength(4));
      expect(g.reglesDOr, hasLength(10));
      expect(g.reglesDOr.map((r) => r.id).toSet(), hasLength(10), reason: 'chaque règle a son identifiant');
      expect(g.rituel.sequence, isNotEmpty);
    });

    test('38 dangers à 4 paliers, 40 lieux avec espaces et rôles', () async {
      final g = (await chargerGrammaire()).grammaire;
      expect(g.dangers, hasLength(38));
      for (final d in g.dangers) {
        expect(d.textes.where((t) => t.isNotEmpty), hasLength(4), reason: d.nom);
      }
      expect(g.lieux, hasLength(40));
      for (final l in g.lieux) {
        expect(l.espaces, isNotEmpty, reason: l.nom);
        expect(l.roles, isNotEmpty, reason: l.nom);
      }
    });

    test('œuvres, scènes, exercices et thèmes', () async {
      final g = (await chargerGrammaire()).grammaire;
      expect(g.oeuvres, hasLength(21));
      expect(g.scenes, hasLength(3));
      expect(g.exercices, hasLength(21));
      expect(g.themesExercices.map((t) => t.id), ['crow', 'lieu', 'destiny']);
      expect(g.modelesDe('alarmiste'), isNotEmpty);
      expect(g.directionDe('leader'), isNotNull);
    });

    test('plus de logique d\'objets : ni règle, ni exercice, ni mouvement, ni catégorie du registre', () async {
      final g = (await chargerGrammaire()).grammaire;
      final brut = [
        File('assets/data/destiny_grammaire.json').readAsStringSync(),
        File('assets/data/destiny_textes.json').readAsStringSync(),
        File('assets/data/archetypes.json').readAsStringSync(),
      ].join('\n').toLowerCase();
      for (final x in ['trois objets', 'objets du lieu', 'objet du lieu', 'objet du début', 'objets et mystère']) {
        expect(brut, isNot(contains(x)), reason: x);
      }
      expect(g.exercices.map((e) => e.id), isNot(contains('trois_objets')));
      // Les objets reviennent comme accessoires de jeu (poser le lieu et des
      // objets, planter pour payer), pas comme l'ancienne mécanique des trois
      // objets donnés au départ.
      expect(g.serie.registre.categories.where((c) => c.contains('objet')), isEmpty);
      final textes = jsonDecode(File('assets/data/destiny_textes.json').readAsStringSync()) as Map<String, dynamic>;
      final pbta = textes['pbta'] as Map<String, dynamic>;
      final mj = pbta['mouvements_mj'] as Map<String, dynamic>;
      for (final liste in mj.values.whereType<List<dynamic>>()) {
        for (final m in liste.cast<Map<String, dynamic>>()) {
          expect(m['id'], isNot('objet'));
        }
      }
    });

    test('rapproche les noms sans tenir compte des accents', () async {
      final g = (await chargerGrammaire()).grammaire;
      expect(g.dangerNomme('UN INCENDIE')?.nom, 'Un incendie');
      expect(g.lieuNomme('ecole')?.nom, 'École');
    });
  });

  group('La validation repère un fichier abîmé', () {
    test('un archétype en moins', () {
      final j = _brut();
      (j['archetypes'] as List).removeLast();
      expect(validerGrammaire(j), isNotEmpty);
    });

    test('un animal qui sert à deux archétypes', () {
      final j = _brut();
      final a = j['archetypes'] as List;
      ((a[1] as Map)['animaux'] as List)[0] = ((a[0] as Map)['animaux'] as List)[0];
      expect(validerGrammaire(j).join(' '), contains('plusieurs archétypes'));
    });

    test('une montée incomplète', () {
      final j = _brut();
      ((j['archetypes'] as List)[0] as Map)['montee'] = {'signale': 'x'};
      expect(validerGrammaire(j).join(' '), contains('montée'));
    });

    test('un danger sans son dernier palier', () {
      final j = _brut();
      (((j['dangers'] as List)[0] as Map)['paliers'] as Map).remove('supprime');
      expect(validerGrammaire(j).join(' '), contains('supprime'));
    });

    test('sans alarmiste', () {
      final j = _brut();
      (j['archetypes'] as List).removeWhere((a) => (a as Map)['id'] == 'alarmiste');
      expect(validerGrammaire(j).join(' '), contains('alarmiste'));
    });
  });

  group('Les textes de l\'appli', () {
    test('sont lus', () async {
      final t = (await chargerGrammaire()).textes;
      expect(t.t('rituel.texte_ellipse'), 'Quelques heures plus tard…');
      expect(t.t('distribution.sans_alarmiste'), isNotEmpty);
      expect(t.liste('besoin.objets'), contains('argent'));
      expect(t.tables('outils_de_jeu.outils'), hasLength(4));
    });

    test('remplacent les variables', () async {
      final t = (await chargerGrammaire()).textes;
      expect(t.t('distribution.correction', {'ancien': 'A', 'nouveau': 'B'}),
          contains('A devient B'));
    });
  });
}
