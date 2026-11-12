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

    test('au spectacle, un groupe sans alarmiste est valide : le danger vient de la régie', () {
      final ids = ['leader', 'prophete', 'denegateur', 'opportuniste'];
      final v = validerDistribution(g, ids);
      expect(v.valide, isTrue, reason: v.raison(g, t));
      expect(v.raison(g, t), isNot(contains('alarmiste')));
      expect(validerDistribution(g, ids, mode: ModeDistribution.spectacle).valide, isTrue);
      // À 3 aussi : celui qui tient, celui qui interprète, celui qui se fissure.
      expect(validerDistribution(g, ['aidant', 'paranoiaque', 'prophete']).valide, isTrue);
    });

    test('en jeu de rôle, l\'alarmiste est toujours là : sinon on le dit, et on le propose', () {
      final ids = ['leader', 'prophete', 'denegateur', 'opportuniste'];
      final v = validerDistribution(g, ids, mode: ModeDistribution.serie);
      expect(v.valide, isFalse);
      expect(v.problemes.first.type, TypeProbleme.sansAlarmiste);
      expect(v.raison(g, t), contains('alarmiste'));
      final corrige = v.correction!.appliquer(ids);
      expect(validerDistribution(g, corrige, mode: ModeDistribution.serie).valide, isTrue);
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
          final jeu = tirerDistribution(g, n, hasard: rng, mode: ModeDistribution.serie);
          expect(jeu, contains('alarmiste'));
          expect(validerDistribution(g, jeu, mode: ModeDistribution.serie).valide, isTrue, reason: '$jeu');
        }
      }
    });

    test('garde les archétypes imposés et le leader demandé', () {
      final rng = Random(7);
      for (var i = 0; i < 100; i++) {
        final ids = tirerDistribution(g, 5,
            hasard: rng, imposes: ['paranoiaque'], leaderObligatoire: true);
        expect(ids, containsAll(['paranoiaque', 'leader']));
        expect(validerDistribution(g, ids, leaderObligatoire: true).valide, isTrue);
      }
    });

    test('au spectacle, l\'alarmiste n\'a plus de place réservée', () {
      final rng = Random(3);
      var sans = 0;
      for (var i = 0; i < 200; i++) {
        if (!tirerDistribution(g, 4, hasard: rng).contains('alarmiste')) sans++;
      }
      expect(sans, greaterThan(100), reason: 'la plupart des tirages se passent de lui');
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
