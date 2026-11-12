import 'package:destiny/domain/grammaire/chronos.dart';
import 'package:destiny/domain/grammaire/modeles.dart';
import 'package:destiny/domain/grammaire/progression.dart';
import 'package:flutter_test/flutter_test.dart';

import 'outils/grammaire_partagee.dart';

void main() {
  group('Progression des paliers', () {
    test('commence à l\'acte 1, le danger se signale', () {
      const p = Progression.depart();
      expect(p.palier, PalierId.signale);
      expect(p.acte, 1);
      expect(p.prochainEstPremierFige, isTrue);
    });

    test('chaque Destiny monte d\'un palier, jusqu\'au quatrième', () {
      var p = const Progression.depart();
      final vus = <PalierId>[p.palier];
      while (p.peutLancerDestiny) {
        p = p.apresDestiny();
        vus.add(p.palier);
      }
      expect(vus, PalierId.values);
      expect(p.destinys, 3);
      expect(p.dernierActe, isTrue);
      // Au dernier acte, plus rien ne monte.
      expect(p.apresDestiny(), p);
    });

    test('seul le premier Destiny est le figé du besoin', () {
      final p = const Progression.depart().apresDestiny();
      expect(p.prochainEstPremierFige, isFalse);
    });
  });

  group('Montée attendue et gestes', () {
    test('la montée de l\'archétype et le corps de l\'animal à chaque palier', () async {
      final g = (await chargerGrammaire()).grammaire;
      final m = monteeAttendue(g, archetypeId: 'leader', animalId: 'lion', palier: PalierId.envahit)!;
      expect(m.ceQuIlFait, 'Imposer ses choix');
      expect(m.corps, isNotEmpty);
      expect(monteeAttendue(g, archetypeId: 'inconnu', palier: PalierId.signale), isNull);
    });

    test('Dire, Fixer, Bloquer, Nommer, Choisir', () async {
      final g = (await chargerGrammaire()).grammaire;
      expect([for (var a = 1; a <= 4; a++) gestePourActe(g, a)?.verbe],
          ['Dire', 'Bloquer', 'Nommer', 'Choisir']);
      expect(gestePremierFige(g)?.verbe, 'Fixer');
    });
  });

  group('Chronos', () {
    test('les trois chronos de base', () {
      expect(kChronosParDefaut.map((c) => c.dureeMinutes), [20, 30, 45]);
      expect(kChronosParDefaut[0].destinyMinutes, [8, 15, 18]);
      expect(kChronosParDefaut[1].destinyMinutes, [10, 18, 27]);
      expect(kChronosParDefaut[2].destinyMinutes, [10, 25, 40]);
      for (final c in kChronosParDefaut) {
        expect(c.valide, isTrue);
        expect(c.dureesActes.reduce((a, b) => a + b), c.dureeMinutes);
      }
    });

    test('l\'acte en cours suit les Destiny', () {
      final c = kChronosParDefaut[1];
      expect(c.acteA(0), 1);
      expect(c.acteA(9.9), 1);
      expect(c.acteA(10), 2);
      expect(c.acteA(20), 3);
      expect(c.acteA(29), 4);
    });

    test('un chrono mal réglé est refusé, et se relit depuis le JSON', () {
      expect(const ChronoSpectacle(dureeMinutes: 20, destinyMinutes: [8, 8, 15]).valide, isFalse);
      expect(const ChronoSpectacle(dureeMinutes: 20, destinyMinutes: [8, 15, 20]).valide, isFalse);
      final c = kChronosParDefaut[2];
      expect(ChronoSpectacle.depuisJson(c.versJson()), c);
      expect(ChronoSpectacle.depuisJson({'duree': 10, 'destiny': [5]}), isNull);
    });
  });
}
