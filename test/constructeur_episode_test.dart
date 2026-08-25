import 'package:flutter_test/flutter_test.dart';
import 'package:destiny/domain/entities/campagne.dart';
import 'package:destiny/domain/usecases/constructeur_episode.dart';

MechantHistoire _mechant({int sbires = 1, int presages = 4}) => MechantHistoire(
      id: 'm',
      univers: 'u',
      nom: 'Boss',
      description: '',
      but: '',
      manoeuvres: const ['fait A', 'fait B', 'fait C'],
      presages: [for (var i = 0; i < presages; i++) 'présage ${i + 1}'],
      sbires: [
        for (var i = 0; i < sbires; i++)
          Sbire(nom: 'Sbire$i', description: '', manoeuvres: const ['ouvre X']),
      ],
    );

void main() {
  group('orchestrer', () {
    test('les deux dernières marches sont du méchant, les sbires ouvrent', () {
      final e = orchestrer(_mechant(sbires: 1, presages: 4));
      expect(e.length, 4);
      expect(e[0].estMechant, isFalse); // sbire ouvre
      expect(e[1].estMechant, isFalse);
      expect(e[2].estMechant, isTrue); // les deux dernières : méchant
      expect(e[3].estMechant, isTrue);
      expect(e[3].quiAgit, 'Boss');
    });

    test('sans sbire, tout est du méchant', () {
      final e = orchestrer(_mechant(sbires: 0, presages: 4));
      expect(e.every((m) => m.estMechant), isTrue);
    });
  });

  group('horairesDesPresages', () {
    test('douze minutes et quatre présages donnent 2, 4, 6, 8', () {
      final h = horairesDesPresages(12 * 60000, 4);
      expect(h.map((ms) => ms ~/ 60000).toList(), [2, 4, 6, 8]);
    });

    test('tous strictement avant la fin', () {
      final h = horairesDesPresages(12 * 60000, 4);
      expect(h.every((ms) => ms < 12 * 60000), isTrue);
    });

    test('un intervalle imposé est respecté', () {
      final h = horairesDesPresages(30 * 60000, 4, intervalleMs: 3 * 60000);
      expect(h.map((ms) => ms ~/ 60000).toList(), [3, 6, 9, 12]);
    });
  });

  group('borner', () {
    test('des horaires hors épisode restent ordonnés et distincts', () {
      final h = borner(
          [11 * 60000, 11 * 60000, 11 * 60000, 11 * 60000], 12 * 60000);
      for (var i = 1; i < h.length; i++) {
        expect(h[i] > h[i - 1], isTrue); // ordonnés et distincts
      }
      expect(h.every((ms) => ms < 12 * 60000), isTrue); // dans l'épisode
    });
  });

  group('ConstructeurEpisode', () {
    final lieux = [
      LieuHistoire(
          id: 'l0',
          univers: 'u',
          nom: 'Lieu 0',
          description: '',
          espaces: const [],
          roles: const ['r1', 'r2', 'r3', 'r4', 'r5', 'r6', 'r7']),
      LieuHistoire(
          id: 'l1',
          univers: 'u',
          nom: 'Lieu 1',
          description: '',
          espaces: const [],
          roles: const ['a', 'b', 'c', 'd', 'e', 'f', 'g']),
    ];
    final mechants = [_mechant(), _mechant()..toString()];
    final archs = [
      for (var i = 0; i < 16; i++)
        ArchetypeHistoire(
            id: 'a$i', nom: 'A$i', temperament: '', port: '', moteur: ''),
    ];
    const objs = ['o1', 'o2', 'o3'];
    const c = ConstructeurEpisode();
    final campagne =
        const Campagne(id: 5, nom: 'C', univers: 'u', ton: 'drole');

    test('le méchant est stable, le lieu change d\'un épisode à l\'autre', () {
      final e1 = c.construire(
          campagne: campagne,
          numero: 1,
          joueurs: const ['J1', 'J2', 'J3'],
          lieux: lieux,
          mechants: mechants,
          archetypes: archs,
          objectifs: objs)!;
      final e2 = c.construire(
          campagne: campagne,
          numero: 2,
          joueurs: const ['J1', 'J2', 'J3'],
          lieux: lieux,
          mechants: mechants,
          archetypes: archs,
          objectifs: objs)!;
      expect(e1.mechant.id, e2.mechant.id); // stable
      expect(e1.lieu.id == e2.lieu.id, isFalse); // change
    });

    test('les figurants n\'ont jamais l\'archétype d\'un joueur', () {
      final e = c.construire(
          campagne: campagne,
          numero: 1,
          joueurs: const ['J1', 'J2', 'J3'],
          lieux: lieux,
          mechants: mechants,
          archetypes: archs,
          objectifs: objs)!;
      final animauxJoueurs = e.roles.map((r) => r.archetype.id).toSet();
      for (final f in e.figurants) {
        expect(animauxJoueurs.contains(f.archetype.id), isFalse);
      }
    });

    test('deux figurants n\'ont pas le même visage', () {
      final e = c.construire(
          campagne: campagne,
          numero: 1,
          joueurs: const ['J1', 'J2'],
          lieux: lieux,
          mechants: mechants,
          archetypes: archs,
          objectifs: objs)!;
      expect(e.figurants[0].visage == e.figurants[1].visage, isFalse);
    });

    test('rend null si l\'univers n\'a ni lieu ni méchant', () {
      final e = c.construire(
          campagne: campagne,
          numero: 1,
          joueurs: const ['J1'],
          lieux: const [],
          mechants: const [],
          archetypes: archs,
          objectifs: objs);
      expect(e, isNull);
    });
  });
}
