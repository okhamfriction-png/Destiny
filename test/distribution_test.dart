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

  group('validerDistribution', () {
    test('accepte les quatre exemples à 3, 4, 5 et 6 joueurs', () {
      for (final n in [3, 4, 5, 6]) {
        for (final e in exemplesDistribution(g, n)) {
          final v = validerDistribution(g, e);
          expect(v.valide, isTrue, reason: '$n : $e → ${v.raison(g, t)}');
        }
      }
    });

    test('refuse un groupe sans alarmiste, et explique pourquoi', () {
      final v = validerDistribution(g, ['leader', 'prophete', 'denegateur', 'opportuniste']);
      expect(v.valide, isFalse);
      expect(v.problemes.first.type, TypeProbleme.sansAlarmiste);
      expect(v.raison(g, t), contains('alarmiste'));
      // La correction fait entrer l'alarmiste sans casser les familles.
      final corrige = v.correction!.appliquer(['leader', 'prophete', 'denegateur', 'opportuniste']);
      expect(validerDistribution(g, corrige).valide, isTrue);
      expect(v.phraseCorrection(g, t), contains('Alarmiste'));
    });

    test('refuse un groupe sans la famille qui fissure le groupe', () {
      final ids = ['alarmiste', 'leader', 'aidant', 'cynique'];
      final v = validerDistribution(g, ids);
      expect(v.valide, isFalse);
      expect(v.problemes.first.type, TypeProbleme.familleManquante);
      expect(v.problemes.first.famille, FamilleId.fissure);
      expect(v.raison(g, t), contains('fissure le groupe'));
      expect(validerDistribution(g, v.correction!.appliquer(ids)).valide, isTrue);
    });

    test('refuse un groupe sans personne qui tient le groupe', () {
      final ids = ['alarmiste', 'cynique', 'opportuniste', 'solitaire'];
      final v = validerDistribution(g, ids);
      expect(v.problemes.map((p) => p.famille), contains(FamilleId.tient));
      expect(validerDistribution(g, v.correction!.appliquer(ids)).valide, isTrue);
    });

    test('l\'alarmiste ne compte pas comme « interprète le danger »', () {
      final v = validerDistribution(g, ['alarmiste', 'leader', 'aidant', 'opportuniste']);
      expect(v.problemes.first.famille, FamilleId.interprete);
    });

    test('à 6, il faut deux qui tiennent et deux qui fissurent', () {
      final v = validerDistribution(
          g, ['alarmiste', 'leader', 'cynique', 'prophete', 'opportuniste', 'solitaire']);
      expect(v.valide, isFalse);
      expect(v.problemes.first.type, TypeProbleme.familleInsuffisante);
      expect(v.raison(g, t), contains('6 joueurs'));
    });

    test('le leader et le gardien de l\'ordre peuvent jouer ensemble', () {
      expect(
          validerDistribution(g, ['alarmiste', 'leader', 'cynique', 'gardien_de_l_ordre']).valide,
          isTrue);
    });

    test('le leader est facultatif, sauf si on le demande', () {
      final ids = ['alarmiste', 'aidant', 'cynique', 'solitaire'];
      expect(validerDistribution(g, ids).valide, isTrue);
      final v = validerDistribution(g, ids, leaderObligatoire: true);
      expect(v.problemes.single.type, TypeProbleme.leaderDemande);
      expect(validerDistribution(g, v.correction!.appliquer(ids), leaderObligatoire: true).valide,
          isTrue);
    });

    test('refuse un archétype pris deux fois', () {
      final ids = ['alarmiste', 'leader', 'leader', 'opportuniste'];
      final v = validerDistribution(g, ids);
      expect(v.problemes.first.type, TypeProbleme.doublon);
      expect(validerDistribution(g, v.correction!.appliquer(ids)).valide, isTrue);
    });

    test('refuse moins de 3 ou plus de 6 joueurs', () {
      expect(validerDistribution(g, ['alarmiste', 'leader']).problemes.single.type, TypeProbleme.nombre);
      expect(validerDistribution(g, List.filled(7, 'leader')).valide, isFalse);
    });

    test('à 3 joueurs : l\'alarmiste, un qui tient, un qui se fissure', () {
      for (final e in exemplesDistribution(g, 3)) {
        expect(e, hasLength(3));
        expect(e, contains('alarmiste'));
        expect(e.map((id) => g.archetype(id)!.famille).toSet(),
            containsAll([FamilleId.tient, FamilleId.fissure]), reason: '$e');
      }
    });
  });

  group('tirerDistribution', () {
    test('rend toujours une distribution équilibrée', () {
      final rng = Random(42);
      for (var i = 0; i < 300; i++) {
        for (final n in [3, 4, 5, 6]) {
          final ids = tirerDistribution(g, n, hasard: rng);
          expect(ids, hasLength(n));
          expect(validerDistribution(g, ids).valide, isTrue, reason: '$ids');
        }
      }
    });

    test('garde les archétypes imposés et le leader demandé', () {
      final rng = Random(7);
      for (var i = 0; i < 100; i++) {
        final ids = tirerDistribution(g, 5,
            hasard: rng, imposes: ['paranoiaque'], leaderObligatoire: true);
        expect(ids, containsAll(['alarmiste', 'paranoiaque', 'leader']));
        expect(validerDistribution(g, ids, leaderObligatoire: true).valide, isTrue);
      }
    });

    test('n\'existe ni à 2 ni à 7 joueurs', () {
      expect(() => tirerDistribution(g, 2), throwsArgumentError);
      expect(() => tirerDistribution(g, 7), throwsArgumentError);
    });

    test('tirerAnimal choisit un des deux animaux de l\'archétype', () {
      final rng = Random(1);
      for (var i = 0; i < 20; i++) {
        expect(['coq', 'rat'], contains(tirerAnimal(g, 'alarmiste', hasard: rng)));
      }
    });
  });
}
