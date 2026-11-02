import 'package:destiny/domain/grammaire/modeles.dart';
import 'package:destiny/domain/grammaire/synchro_catalogue.dart';
import 'package:flutter_test/flutter_test.dart';

import 'outils/grammaire_partagee.dart';

void main() {
  group('Le catalogue lit ses textes dans la grammaire', () {
    test('chaque danger du catalogue a les 4 paliers de la grammaire', () async {
      final g = (await chargerGrammaire()).grammaire;
      final dangers = await donneesDeTest().loadDangers();
      expect(dangers, hasLength(38));
      for (final d in dangers) {
        final dg = g.dangerNomme(d.name);
        expect(dg, isNotNull, reason: d.name);
        expect(d.paliers, dg!.textes, reason: d.name);
      }
      // Les identifiants de l'appli sont gardés (images, mémoire des tirages).
      expect(dangers.first.id, 'robots_rebelle');
      // Drapeau kids et palier 4 kids venus de la grammaire.
      final kids = dangers.where((d) => d.kids).toList();
      expect(kids, hasLength(24));
      expect(kids.every((d) => d.palier4Kids.isNotEmpty), isTrue);
      expect(kids.first.paliersPour(kids: true)[3], kids.first.palier4Kids);
    });

    test('tout le catalogue embarqué a son équivalent dans la grammaire', () async {
      expect(await donneesDeTest().sansCorrespondance(), isEmpty);
    });

    test('chaque lieu a ses espaces et ses rôles de la grammaire', () async {
      final g = (await chargerGrammaire()).grammaire;
      final lieux = await donneesDeTest().loadLocations();
      expect(lieux, hasLength(40));
      for (final l in lieux) {
        final lg = g.lieuNomme(l.name)!;
        expect(l.espaces, lg.espaces, reason: l.name);
        expect(l.roles, lg.roles, reason: l.name);
      }
      expect(lieux.firstWhere((l) => l.id == 'base_spatiale').name, 'Station spatiale');
      expect(lieux.where((l) => l.kids), hasLength(35));
      expect(lieux.firstWhere((l) => l.id == 'casino').kids, isFalse);
    });

    test('la photo 1.5.7 garde les anciens textes', () async {
      final ref = await donneesDeTest().loadReference157();
      expect(ref.paliers, hasLength(38));
      expect(ref.paliers['incendie']![2], contains('on est piégés'));
      expect(ref.roles, hasLength(40));
    });
  });

  group('synchroniserChamp', () {
    const ancien = ['a1', 'a2', 'a3', 'a4'];
    const nouveau = ['n1', 'n2', 'n3', 'n4'];

    test('met à jour une ligne non modifiée', () {
      final r = synchroniserChamp(
        actuel: {'x': ancien},
        references: {'x': ancien},
        cible: {'x': nouveau},
      );
      expect(r.misesAJour, {'x': nouveau});
      expect(r.references['x'], nouveau);
      expect(r.gardes, isEmpty);
    });

    test('ne touche jamais une ligne modifiée par l\'utilisateur', () {
      final r = synchroniserChamp(
        actuel: {'x': ['à moi', 'a2', 'a3', 'a4']},
        references: {'x': ancien},
        cible: {'x': nouveau},
      );
      expect(r.misesAJour, isEmpty);
      expect(r.gardes, {'x'});
      // La référence reste l'ancienne : la modification restera reconnue.
      expect(r.references['x'], ancien);
    });

    test('ne remet pas une ligne supprimée, ne touche pas une ligne ajoutée', () {
      final r = synchroniserChamp(
        actuel: {'perso': ['p']},
        references: {},
        cible: {'supprime': nouveau},
      );
      expect(r.misesAJour, isEmpty);
      expect(r.absents, {'supprime'});
      expect(r.references.containsKey('perso'), isFalse);
    });

    test('remplit un champ vide (les espaces d\'une base 1.5.7)', () {
      final r = synchroniserChamp(
        actuel: {'x': const []},
        references: {},
        cible: {'x': nouveau},
      );
      expect(r.misesAJour, {'x': nouveau});
    });

    test('suit les versions successives de la grammaire', () {
      // v1 → v2 appliquée, puis v2 → v3 : la ligne suit tant qu'on n'y touche pas.
      final r1 = synchroniserChamp(
          actuel: {'x': ancien}, references: {'x': ancien}, cible: {'x': nouveau});
      const v3 = ['v1', 'v2', 'v3', 'v4'];
      final r2 = synchroniserChamp(
          actuel: {'x': nouveau}, references: r1.references, cible: {'x': v3});
      expect(r2.misesAJour, {'x': v3});
    });

    test('empreinte stable', () {
      expect(empreinte('abc'), empreinte('abc'));
      expect(empreinte('abc'), isNot(empreinte('abd')));
    });
  });

  test('les noms se rapprochent sans accents ni ponctuation', () {
    expect(Grammaire.normaliser("L'air devient irrespirable"),
        Grammaire.normaliser("l air devient IRRESPIRABLE"));
  });
}
