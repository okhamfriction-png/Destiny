import 'package:destiny/domain/grammaire/chronos.dart';
import 'package:destiny/domain/grammaire/modeles.dart';
import 'package:destiny/domain/grammaire/progression.dart';
import 'package:flutter_test/flutter_test.dart';

import 'outils/grammaire_partagee.dart';

void main() {
  group('Progression : quatre actes, trois niveaux du danger', () {
    test('le danger n\'a que trois niveaux, un par DESTINY', () {
      expect(PalierId.values, hasLength(3));
      expect(PalierId.values.map((p) => p.nom), ['Il enferme', 'Il se manifeste', 'Il tue']);
      expect([for (final p in PalierId.values) p.acte], [2, 3, 4]);
      expect(PalierId.pourActe(1), isNull, reason: 'l\'acte 1 se joue sans danger');
      expect([for (var a = 2; a <= 4; a++) PalierId.pourActe(a)], PalierId.values);
    });

    test('commence à l\'acte 1, sans danger', () {
      const p = Progression.depart();
      expect(p.palier, isNull);
      expect(p.acte, 1);
      expect(p.destinys, 0);
    });

    test('chaque Destiny fait monter d\'un niveau, jusqu\'au troisième', () {
      var p = const Progression.depart();
      final vus = <PalierId>[];
      while (p.peutLancerDestiny) {
        p = p.apresDestiny();
        vus.add(p.palier!);
      }
      expect(vus, PalierId.values);
      expect(p.destinys, 3);
      expect(p.acte, 4);
      expect(p.dernierActe, isTrue);
      // Au dernier acte, plus rien ne monte.
      expect(p.apresDestiny(), p);
    });
  });

  group('Montée attendue et gestes', () {
    test('la montée de l\'archétype et le corps de l\'animal à chaque niveau', () async {
      final g = (await chargerGrammaire()).grammaire;
      final m = monteeAttendue(g, archetypeId: 'leader', animalId: 'lion', palier: PalierId.manifeste)!;
      expect(m.ceQuIlFait, 'Imposer ses choix');
      expect(m.corps, isNotEmpty);
      expect(monteeAttendue(g, archetypeId: 'inconnu', palier: PalierId.enferme), isNull);
    });

    test('Dire, Fixer, Bloquer, Nommer, Choisir', () async {
      final g = (await chargerGrammaire()).grammaire;
      expect([for (var a = 1; a <= 4; a++) gestePourActe(g, a)?.verbe],
          ['Dire', 'Bloquer', 'Nommer', 'Choisir']);
      expect(gestePremierFige(g)?.verbe, 'Fixer');
    });
  });

  group('Chronos', () {
    test('les trois chronos de base, un par nombre de joueurs', () {
      expect(kChronosParDefaut.map((c) => c.dureeMinutes), [12, 27, 33]);
      // À 2 : 3 min par acte ; à 3 : 8 min, le dernier à 3 ; à 4 et plus :
      // 10 min, le dernier à 3.
      expect(kChronosParDefaut[0].dureesActes, [3, 3, 3, 3]);
      expect(kChronosParDefaut[1].dureesActes, [8, 8, 8, 3]);
      expect(kChronosParDefaut[2].dureesActes, [10, 10, 10, 3]);
      expect([for (var n = 2; n <= 6; n++) rangChronoPourJoueurs(n)], [0, 1, 2, 2, 2]);
      for (final c in kChronosParDefaut) {
        expect(c.valide, isTrue);
        expect(c.dureesActes.reduce((a, b) => a + b), c.dureeMinutes);
      }
    });

    test('une autre durée : les Destiny pas encore lancés suivent, au prorata', () {
      // 33 → 45 min : 10, 20, 30 → 14, 27, 41.
      expect(adapterDestinys([10, 20, 30], ancienneDuree: 33, nouvelleDuree: 45), [14, 27, 41]);
      // 33 → 20 min : 6, 12, 18.
      expect(adapterDestinys([10, 20, 30], ancienneDuree: 33, nouvelleDuree: 20), [6, 12, 18]);
      // Le premier déjà lancé ne bouge pas ; les autres restent après lui
      // et après le temps joué (12 min 30).
      expect(adapterDestinys([10, 20, 30], ancienneDuree: 33, nouvelleDuree: 16, lances: 1, ecouleSecondes: 750),
          [10, 13, 15]);
      // Toujours croissants, avant la fin, même très court.
      expect(adapterDestinys([3, 6, 9], ancienneDuree: 12, nouvelleDuree: 4), [1, 2, 3]);
      expect(dureeMiniSpectacle([3, 6, 9]), 4);
      expect(adapterDestinys([3, 6, 9], ancienneDuree: 12, nouvelleDuree: 3), isNull);
      expect(dureeMiniSpectacle([10, 20, 30], lances: 2, ecouleSecondes: 25 * 60), 27);
      for (var d = 4; d <= 120; d++) {
        final m = adapterDestinys([10, 20, 30], ancienneDuree: 33, nouvelleDuree: d)!;
        expect(ChronoSpectacle(dureeMinutes: d, destinyMinutes: m).valide, isTrue, reason: '$d min : $m');
      }
    });

    test('l\'acte en cours suit les Destiny', () {
      final c = kChronosParDefaut[2];
      expect(c.acteA(0), 1);
      expect(c.acteA(9.9), 1);
      expect(c.acteA(10), 2);
      expect(c.acteA(20), 3);
      expect(c.acteA(32), 4);
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
