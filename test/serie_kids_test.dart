import 'package:destiny/domain/grammaire/modeles.dart';
import 'package:flutter_test/flutter_test.dart';

import 'outils/grammaire_partagee.dart';

void main() {
  late Grammaire g;
  setUpAll(() async {
    final c = await chargerGrammaire();
    expect(c.erreurs, isEmpty);
    g = c.grammaire;
  });

  group('La série', () {
    test('épisode, saison, série et règles du méchant', () {
      expect(g.version, '2.1');
      expect(g.serie.episode, isNotEmpty);
      expect(g.serie.saison, isNotEmpty);
      expect(g.serie.serie, isNotEmpty);
      expect(g.serie.reglesDuMechant, hasLength(7));
      expect(g.serie.registre.categories, hasLength(10));
    });
  });

  group('Les grands méchants', () {
    test('24 méchants, deux par archétype, chacun avec un animal hors des 24', () {
      expect(g.mechants, hasLength(24));
      for (final a in g.archetypes) {
        expect(g.mechantsReflets(a.id), hasLength(2), reason: a.id);
      }
      for (final m in g.mechants) {
        expect(g.animalNomme(m.animal), isNull, reason: m.id);
        expect(m.veut, isNotEmpty);
        expect(m.besoin, isNotEmpty);
        expect(m.faille, isNotEmpty);
        expect(m.offreAuTraitre, isNotEmpty);
      }
    });

    test('au moins un méchant kids par archétype, avec sa version kids', () {
      expect(g.mechants.where((m) => m.kids), hasLength(16));
      for (final a in g.archetypes) {
        expect(g.mechantsReflets(a.id, kids: true), isNotEmpty, reason: a.id);
      }
      final m = g.mechants.firstWhere((m) => m.kids);
      expect(m.histoirePour(kids: true), m.versionKids);
      expect(m.faillePour(kids: true), m.failleKids);
      expect(m.histoirePour(), m.histoire);
    });

    test('chaque méchant a deux sbires différents, jouables', () {
      final ids = <String>{};
      for (final m in g.mechants) {
        expect(m.sbires, hasLength(2), reason: m.id);
        expect(m.sbires[0].id, isNot(m.sbires[1].id));
        for (final s in m.sbires) {
          expect(ids.add(s.id), isTrue, reason: s.id);
          // Son animal fait partie des 24 et appartient à son archétype.
          expect(g.animal(s.animalId)?.archetypeId, s.archetypeId, reason: s.id);
          expect(s.kids, m.kids);
          expect(s.mode, ModePnj.sbire);
          expect(g.sbire(s.id)?.mechant.id, m.id);
        }
      }
      expect(ids, hasLength(48));
    });
  });

  group('Les figurants', () {
    test('deux modes, huit types, des règles', () {
      expect(g.figurants.modes.keys, ModePnj.values);
      expect(g.figurants.types.map((t) => t.id), hasLength(8));
      expect(g.figurants.type('temoin')?.commentLeJouer, isNotEmpty);
      expect(g.figurants.regles, isNotEmpty);
    });

    test('trois figurants prêts à jouer par lieu', () {
      for (final l in g.lieux) {
        expect(l.figurants, hasLength(3), reason: l.nom);
        for (final f in l.figurants) {
          expect(g.animal(f.animalId)?.archetypeId, f.archetypeId, reason: f.nom);
          expect(g.figurants.type(f.type), isNotNull, reason: f.nom);
          expect(f.mode, ModePnj.figurant);
          expect(f.id, startsWith('${l.id}.'));
        }
      }
    });
  });

  group('Le mode kids', () {
    test('le sigle, les règles, les pouvoirs', () {
      expect(g.modeKids.sigleTexte, 'KIDS');
      expect(g.modeKids.sigleFond, '#F2C230');
      expect(g.modeKids.regles, hasLength(6));
      expect(g.modeKids.pouvoirsExemples, isNotEmpty);
      expect(g.modeKids.dureeEpisodeMinutes, [20, 30]);
      expect(g.directionArtistique.couleurs['kids'], '#F2C230');
    });

    test('24 dangers kids avec un palier 4 sans mort, 35 lieux kids', () {
      final kids = g.dangers.where((d) => d.kids).toList();
      expect(kids, hasLength(24));
      for (final d in kids) {
        expect(d.textesPour(kids: true)[3], d.supprimeKids);
        expect(d.textesPour()[3], d.paliers[PalierId.supprime]);
      }
      expect(g.lieux.where((l) => l.kids), hasLength(35));
      expect(g.modeKids.dangerIds.toSet(), kids.map((d) => d.id).toSet());
    });

    test('trois répliques réservées aux adultes ont leur version kids', () {
      final adultes = g.animaux.where((a) => a.repliqueAdulteSeulement).map((a) => a.id);
      expect(adultes.toSet(), {'loup', 'corbeau', 'renard'});
      final loup = g.animal('loup')!;
      expect(loup.repliquePour(kids: true), loup.repliqueKids);
      expect(loup.repliquePour(kids: true), isNot(loup.replique));
      expect(loup.sourcePour(kids: true), 'Le Petit Prince');
    });
  });
}
