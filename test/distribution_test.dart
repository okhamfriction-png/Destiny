import 'dart:math';

import 'package:destiny/domain/grammaire/distribution.dart';
import 'package:destiny/domain/grammaire/modeles.dart';
import 'package:destiny/domain/grammaire/textes.dart';
import 'package:flutter_test/flutter_test.dart';

import 'outils/grammaire_partagee.dart';

void main() {
  late Grammaire g;
  late TextesDestiny t;
  setUpAll(() async {
    final c = await chargerGrammaire();
    g = c.grammaire;
    t = c.textes;
  });

  group('Les duels', () {
    test('quatre duels, chaque archétype dans un seul, avec son enjeu', () {
      final duels = g.distribution.duels;
      expect(duels.map((d) => d.archetypes), [
        ['alarmiste', 'denegateur'],
        ['leader', 'tyran'],
        ['aidant', 'paranoiaque'],
        ['protecteur', 'prophete'],
      ]);
      expect(duels.expand((d) => d.archetypes).toSet(), g.archetypes.map((a) => a.id).toSet());
      for (final d in duels) {
        expect(d.sur, isNotEmpty);
        expect(d.enjeu, isNotEmpty);
      }
      expect(g.distribution.duelDe('tyran')!.adversaire('tyran'), 'leader');
      expect(g.distribution.duelDe('prophete')!.adversaire('prophete'), 'protecteur');
    });

    test('par_nombre : 1 duel + 1 seul à 3, 2 à 4, 2 + 1 à 5, 3 à 6', () {
      final attendu = {3: (1, 1), 4: (2, 0), 5: (2, 1), 6: (3, 0)};
      for (final MapEntry(key: n, value: (d, s)) in attendu.entries) {
        final c = g.distribution.pour(n)!;
        expect((c.duels, c.seuls), (d, s), reason: '$n joueurs');
      }
      expect(g.distribution.regle, contains('On distribue par duels'));
    });

    test('les quatre exemples, de 3 à 6 joueurs', () {
      final e = g.distribution.exemples;
      List<String> premiers(List<String> ids) => [for (final d in g.distribution.duelsComplets(ids)) d.premier];
      expect(premiers(e[0].pour(4)), ['alarmiste', 'leader']);
      expect(e[0].pour(5).last, 'aidant');
      expect(premiers(e[0].pour(6)), ['alarmiste', 'leader', 'aidant']);
      expect(premiers(e[1].pour(4)), ['alarmiste', 'aidant']);
      expect(premiers(e[1].pour(6)), ['alarmiste', 'aidant', 'protecteur']);
      expect(premiers(e[2].pour(4)), ['leader', 'protecteur']);
      expect(e[2].pour(5).last, 'alarmiste');
      expect(premiers(e[3].pour(4)), ['aidant', 'protecteur']);
      expect(premiers(e[3].pour(6)), ['alarmiste', 'aidant', 'protecteur']);
      for (final n in [3, 4, 5, 6]) {
        for (final ids in exemplesDistribution(g, n)) {
          final v = validerDistribution(g, ids);
          expect(v.valide, isTrue, reason: '$n : $ids → ${v.raison(g, t)}');
        }
      }
    });
  });

  group('validerDistribution', () {
    test('au spectacle, un groupe sans alarmiste est valide : le danger vient de la régie', () {
      final ids = ['leader', 'tyran', 'protecteur', 'prophete'];
      final v = validerDistribution(g, ids);
      expect(v.valide, isTrue, reason: v.raison(g, t));
      expect(validerDistribution(g, ['aidant', 'paranoiaque', 'prophete']).valide, isTrue);
    });

    test('en jeu de rôle, l\'alarmiste est toujours là : sinon on le dit, et on le propose', () {
      final ids = ['leader', 'tyran', 'protecteur', 'prophete'];
      final v = validerDistribution(g, ids, mode: ModeDistribution.serie);
      expect(v.valide, isFalse);
      expect(v.problemes.first.type, TypeProbleme.sansAlarmiste);
      expect(v.raison(g, t), contains('alarmiste'));
      final corrige = v.correction!.appliquer(ids);
      expect(validerDistribution(g, corrige, mode: ModeDistribution.serie).valide, isTrue, reason: '$corrige');
      expect(v.phraseCorrection(g, t), contains('Alarmiste'));
    });

    test('un archétype sans son adversaire : on le dit, et on propose l\'adversaire', () {
      final ids = ['alarmiste', 'leader', 'aidant', 'tyran'];
      final v = validerDistribution(g, ids);
      expect(v.valide, isFalse);
      expect(v.problemes.first.type, TypeProbleme.duelIncomplet);
      expect(v.raison(g, t), contains('sans son adversaire'));
      final corrige = v.correction!.appliquer(ids);
      expect(validerDistribution(g, corrige).valide, isTrue, reason: '$corrige');
    });

    test('à 4, une couleur manque : on propose de changer tout un duel', () {
      for (final ids in [
        ['alarmiste', 'denegateur', 'protecteur', 'prophete'],
        ['leader', 'tyran', 'aidant', 'paranoiaque'],
      ]) {
        final v = validerDistribution(g, ids);
        expect(v.problemes.single.type, TypeProbleme.familleManquante, reason: '$ids');
        final corrige = v.correction!.appliquer(ids);
        expect(validerDistribution(g, corrige).valide, isTrue, reason: '$corrige');
        expect(g.distribution.duelsComplets(corrige), hasLength(2));
      }
    });

    test('à 5, l\'archétype seul complète la couleur qui manque', () {
      expect(validerDistribution(g, ['alarmiste', 'denegateur', 'protecteur', 'prophete', 'tyran']).valide, isTrue);
      expect(validerDistribution(g, ['alarmiste', 'denegateur', 'protecteur', 'prophete', 'leader']).valide, isFalse);
    });

    test('à 3, les couleurs ne sont pas exigées', () {
      expect(validerDistribution(g, ['alarmiste', 'denegateur', 'prophete']).valide, isTrue);
    });

    test('le leader est facultatif, sauf si on le demande', () {
      final ids = ['alarmiste', 'denegateur', 'aidant', 'paranoiaque'];
      expect(validerDistribution(g, ids).valide, isTrue);
      final v = validerDistribution(g, ids, leaderObligatoire: true);
      expect(v.problemes.first.type, TypeProbleme.leaderDemande);
      expect(validerDistribution(g, v.correction!.appliquer(ids), leaderObligatoire: true).valide, isTrue);
    });

    test('refuse un archétype pris deux fois', () {
      final ids = ['alarmiste', 'leader', 'leader', 'tyran'];
      final v = validerDistribution(g, ids);
      expect(v.problemes.first.type, TypeProbleme.doublon);
      expect(validerDistribution(g, v.correction!.appliquer(ids)).valide, isTrue);
    });

    test('refuse moins de 3 ou plus de 6 joueurs', () {
      expect(validerDistribution(g, ['alarmiste', 'leader']).problemes.single.type, TypeProbleme.nombre);
      expect(validerDistribution(g, List.filled(7, 'leader')).valide, isFalse);
    });
  });

  group('tirerDistribution', () {
    test('sur 1 000 tirages à 3, 4, 5 et 6 : les bons duels, jamais un seul en trop, trois couleurs dès 4', () {
      final rng = Random(42);
      for (final n in [3, 4, 5, 6]) {
        final compo = g.distribution.pour(n)!;
        final vus = <String>{};
        for (var i = 0; i < 1000; i++) {
          final ids = tirerDistribution(g, n, hasard: rng);
          expect(ids, hasLength(n));
          expect(ids.toSet(), hasLength(n), reason: '$ids');
          expect(g.distribution.duelsComplets(ids), hasLength(compo.duels), reason: '$n : $ids');
          expect(archetypesSeuls(g, ids), hasLength(compo.seuls), reason: '$n : $ids');
          if (n >= 4) expect(couleursManquantes(g, ids), isEmpty, reason: '$n : $ids');
          expect(validerDistribution(g, ids).valide, isTrue, reason: '$ids');
          vus.add((ids.toList()..sort()).join(','));
        }
        expect(vus.length, greaterThan(1), reason: 'le hasard varie les tirages à $n');
      }
    });

    test('à 4, les tirages sans une couleur sont exclus', () {
      final rng = Random(9);
      for (var i = 0; i < 300; i++) {
        final ids = tirerDistribution(g, 4, hasard: rng).toSet();
        expect(ids, isNot({'alarmiste', 'denegateur', 'protecteur', 'prophete'}));
        expect(ids, isNot({'leader', 'tyran', 'aidant', 'paranoiaque'}));
      }
    });

    test('à 3, l\'archétype seul complète une couleur qui manque', () {
      final rng = Random(4);
      for (var i = 0; i < 300; i++) {
        final ids = tirerDistribution(g, 3, hasard: rng);
        final duel = g.distribution.duelsComplets(ids).single;
        final seul = ids.firstWhere((id) => !duel.contient(id));
        expect(couleursManquantes(g, duel.archetypes), contains(g.archetype(seul)!.famille), reason: '$ids');
      }
    });

    test('l\'ordre est mélangé : chacun peut recevoir n\'importe quel archétype', () {
      final rng = Random(8);
      final enTete = <String>{};
      for (var i = 0; i < 300; i++) {
        enTete.add(tirerDistribution(g, 4, hasard: rng).first);
      }
      expect(enTete, hasLength(8));
    });

    test('en jeu de rôle, l\'alarmiste est toujours tiré', () {
      final rng = Random(2);
      for (var i = 0; i < 200; i++) {
        for (final n in [4, 5, 6]) {
          final ids = tirerDistribution(g, n, hasard: rng, mode: ModeDistribution.serie);
          expect(ids, contains('alarmiste'));
          expect(validerDistribution(g, ids, mode: ModeDistribution.serie).valide, isTrue, reason: '$ids');
        }
      }
    });

    test('garde les archétypes imposés et le leader demandé', () {
      final rng = Random(7);
      for (var i = 0; i < 100; i++) {
        final ids = tirerDistribution(g, 5, hasard: rng, imposes: ['paranoiaque'], leaderObligatoire: true);
        expect(ids, containsAll(['paranoiaque', 'leader']));
        expect(validerDistribution(g, ids, leaderObligatoire: true).valide, isTrue);
      }
    });

    test('au spectacle, l\'alarmiste n\'a pas de place réservée', () {
      final rng = Random(3);
      var sans = 0;
      for (var i = 0; i < 200; i++) {
        if (!tirerDistribution(g, 4, hasard: rng).contains('alarmiste')) sans++;
      }
      expect(sans, greaterThan(40));
    });

    test('n\'existe ni à 2 ni à 7 joueurs', () {
      expect(() => tirerDistribution(g, 2), throwsArgumentError);
      expect(() => tirerDistribution(g, 7), throwsArgumentError);
    });

    test('tirerAnimal choisit un des trois animaux de l\'archétype', () {
      final rng = Random(1);
      final vus = <String>{};
      for (var i = 0; i < 60; i++) {
        final a = tirerAnimal(g, 'alarmiste', hasard: rng);
        expect(['coq', 'rat', 'chat'], contains(a));
        vus.add(a);
      }
      expect(vus, hasLength(3));
    });
  });
}
