import 'dart:convert';
import 'dart:math';

import 'package:destiny/domain/grammaire/modeles.dart';
import 'package:destiny/domain/grammaire/textes.dart';
import 'package:destiny/domain/serie/pbta.dart';
import 'package:destiny/domain/serie/serie.dart';
import 'package:flutter_test/flutter_test.dart';

import 'outils/grammaire_partagee.dart';

/// Un hasard écrit d'avance : chaque `nextBool` rend la valeur suivante
/// (vrai : BRAVE, faux : SMART).
class FauxHasard implements Random {
  FauxHasard(this.faces);
  final List<bool> faces;
  int lus = 0;

  @override
  bool nextBool() => faces[lus++];

  @override
  int nextInt(int max) => 0;

  @override
  double nextDouble() => 0;
}

const b = FacePiece.brave;
const sm = FacePiece.smart;

ResultatPiece lancer(FacePiece approche, ModeLancer mode, List<bool> faces, {int palier = 1}) =>
    lancerPiece(approche: approche, mode: mode, palier: palier, hasard: FauxHasard(faces));

void main() {
  late Grammaire g;
  late TextesDestiny t;
  late ReglesPbta r;
  setUpAll(() async {
    final c = await chargerGrammaire();
    g = c.grammaire;
    t = c.textes;
    r = ReglesPbta.depuis(t);
  });

  group('La pièce du destin BRAVE / SMART', () {
    test('la face choisie : succès ; l\'autre face : échec (un seul lancer)', () {
      final ok = lancer(b, ModeLancer.simple, [true]);
      expect(ok.lancers, [b]);
      expect(ok.reussite, isTrue);
      final rate = lancer(b, ModeLancer.simple, [false]);
      expect(rate.lancers, [sm]);
      expect(rate.reussite, isFalse);
      expect(lancer(sm, ModeLancer.simple, [false]).reussite, isTrue);
      expect(lancer(sm, ModeLancer.simple, [true]).reussite, isFalse);
    });

    test('le bonus : deux lancers, une seule face choisie suffit', () {
      expect(modeDuLancer(approche: b, bonus: b), ModeLancer.secondeChance);
      // L'autre approche que son bonus : un seul lancer, comme d'habitude.
      expect(modeDuLancer(approche: sm, bonus: b), ModeLancer.simple);
      expect(modeDuLancer(approche: sm), ModeLancer.simple);

      final secondeChance = lancer(b, ModeLancer.secondeChance, [false, true]);
      expect(secondeChance.lancers, [sm, b]);
      expect(secondeChance.reussite, isTrue);
      // Le premier lancer suffit : on ne relance pas.
      final duPremierCoup = lancer(b, ModeLancer.secondeChance, [true]);
      expect(duPremierCoup.lancers, [b]);
      expect(duPremierCoup.reussite, isTrue);
      final deuxFoisRate = lancer(b, ModeLancer.secondeChance, [false, false]);
      expect(deuxFoisRate.lancers, hasLength(2));
      expect(deuxFoisRate.reussite, isFalse);
    });

    test('l\'aide, le vouloir dit et le pouvoir kids donnent le second lancer ; jamais plus de deux', () {
      expect(modeDuLancer(approche: sm, aide: true), ModeLancer.secondeChance);
      expect(modeDuLancer(approche: sm, vouloirDit: true), ModeLancer.secondeChance);
      expect(modeDuLancer(approche: sm, pouvoir: true), ModeLancer.secondeChance);
      expect(modeDuLancer(approche: b, bonus: b, aide: true, vouloirDit: true), ModeLancer.secondeChance);
      // L'aidé rate le premier lancer, et réussit grâce au second.
      final aide = lancer(sm, modeDuLancer(approche: sm, aide: true), [true, false]);
      expect(aide.lancers, [b, sm]);
      expect(aide.reussite, isTrue);
      expect(encoreUnLancer(sm, ModeLancer.secondeChance, [b, b]), isFalse);
    });

    test('la gêne : deux lancers, la moindre face contraire fait échouer ; aide et gêne s\'annulent', () {
      expect(modeDuLancer(approche: b, gene: true), ModeLancer.gene);
      expect(modeDuLancer(approche: b, bonus: b, gene: true), ModeLancer.simple);
      expect(modeDuLancer(approche: b, aide: true, gene: true), ModeLancer.simple);
      final deuxFois = lancer(b, ModeLancer.gene, [true, true]);
      expect(deuxFois.lancers, [b, b]);
      expect(deuxFois.reussite, isTrue);
      expect(lancer(b, ModeLancer.gene, [true, false]).reussite, isFalse);
      // Raté au premier : pas besoin du second.
      final tout = lancer(b, ModeLancer.gene, [false]);
      expect(tout.lancers, [sm]);
      expect(tout.reussite, isFalse);
    });

    test('la gravité suit le palier : doux aux paliers 1 et 2, dur aux paliers 3 et 4', () {
      expect(graviteAuPalier(1), GraviteMouvement.doux);
      expect(graviteAuPalier(2), GraviteMouvement.doux);
      expect(graviteAuPalier(3), GraviteMouvement.dur);
      expect(graviteAuPalier(4), GraviteMouvement.dur);
      expect(lancer(b, ModeLancer.simple, [false], palier: 2).gravite, GraviteMouvement.doux);
      expect(lancer(b, ModeLancer.simple, [false], palier: 3).gravite, GraviteMouvement.dur);
    });

    test('avec la même graine, les mêmes lancers', () {
      for (var graine = 0; graine < 20; graine++) {
        final a = lancerPiece(approche: b, mode: ModeLancer.secondeChance, palier: 2, hasard: Random(graine));
        final c = lancerPiece(approche: b, mode: ModeLancer.secondeChance, palier: 2, hasard: Random(graine));
        expect(a.lancers, c.lancers);
        expect(a.reussite, c.reussite);
      }
    });

    test('sur beaucoup de lancers, le second lancer aide vraiment (une fois sur deux, trois fois sur quatre)', () {
      final rng = Random(7);
      var simple = 0;
      var chance = 0;
      for (var i = 0; i < 4000; i++) {
        if (lancerPiece(approche: b, palier: 1, hasard: rng).reussite) simple++;
        if (lancerPiece(approche: b, mode: ModeLancer.secondeChance, palier: 1, hasard: rng).reussite) chance++;
      }
      expect(simple / 4000, closeTo(0.5, 0.05));
      expect(chance / 4000, closeTo(0.75, 0.05));
    });
  });

  group('Les blessures', () {
    test('trois cases : on les coche, « Soigner » en efface une, la troisième met hors jeu', () {
      final role = RoleEpisode(personnageId: 'p');
      expect(role.blessures, 0);
      role.marquerBlessure();
      role.marquerBlessure();
      expect(role.horsJeu, isFalse);
      role
        ..marquerBlessure()
        ..marquerBlessure();
      expect(role.blessures, kCasesBlessure);
      expect(role.horsJeu, isTrue);
      role.soigner();
      expect(role.blessures, 2);
      role
        ..soigner()
        ..soigner()
        ..soigner();
      expect(role.blessures, 0);
      role.blessures = 9;
      expect(role.blessures, 3);
    });

    test('les libellés : adultes et kids ; en kids, personne ne meurt', () {
      expect(r.blessures(kids: false), ['Secoué', 'Blessé', 'Hors jeu']);
      expect(r.blessures(kids: true), ['Fatigué', 'Épuisé', 'Doit se reposer']);
      for (final x in r.blessures(kids: true)) {
        expect(x.toLowerCase(), isNot(contains('mort')));
        expect(x.toLowerCase(), isNot(contains('meurt')));
      }
      expect(r.etatBlessure(0, kids: false), '');
      expect(r.etatBlessure(2, kids: true), 'Épuisé');
      expect(r.etatBlessure(3, kids: false), 'Hors jeu');
      // Le mouvement « blessure » du Maître du destin, en kids : jamais la mort.
      final blessure = r.mouvementsMj.firstWhere((m) => m.id == 'blessure');
      expect(blessure.textePour(kids: true), isNot(blessure.texte));
      expect(blessure.textePour(kids: true), contains('Jamais la mort'));
    });

    test('une ancienne sauvegarde sans cases se relit à zéro', () {
      final role = RoleEpisode.depuisJson({'personnage': 'p', 'sante': 'blesse', 'mod': 2});
      expect(role.blessures, 0);
      expect(role.elan, isFalse);
      expect(jsonDecode(jsonEncode(role.versJson()))['blessures'], 0);
    });
  });

  group('Les textes du jeu de rôle', () {
    test('chaque mouvement de joueur a son déclencheur, et son succès et son échec (ou son effet sans pièce)', () {
      expect(r.mouvements.map((m) => m.id), containsAll(['affronter', 'lire_situation', 'lire_quelqu_un', 'aider_gener', 's_opposer', 'dire_vouloir', 'payer_le_prix']));
      for (final m in r.mouvements) {
        expect(m.nom, isNotEmpty, reason: m.id);
        expect(m.quand, matches(RegExp('^(Quand|La première|Au final)')), reason: m.id);
        expect(m.approche, isNotEmpty, reason: m.id);
        if (m.avecPiece) {
          expect(m.reussite, isNotEmpty, reason: m.id);
          expect(m.echec, isNotEmpty, reason: m.id);
          expect(m.approches, isNotEmpty, reason: m.id);
        } else {
          expect(m.effet, isNotEmpty, reason: m.id);
        }
      }
      // Lire, c'est SMART ; s'opposer, BRAVE en se battant, SMART en parlant.
      expect(r.mouvement('lire_situation')!.approches, [sm]);
      expect(r.mouvement('lire_quelqu_un')!.approches, [sm]);
      expect(r.mouvement('s_opposer')!.approches, [b, sm]);
      expect(r.mouvement('payer_le_prix')!.avecPiece, isFalse);
      // Le pouvoir est un mouvement des enfants seulement.
      expect(r.mouvementsPour(kids: false).any((m) => m.id == 'pouvoir'), isFalse);
      expect(r.mouvementsPour(kids: true).any((m) => m.id == 'pouvoir'), isTrue);
    });

    test('l\'agenda, les principes et les mouvements du Maître du destin, doux et durs', () {
      expect(r.agenda, hasLength(3));
      expect(r.principes.length, greaterThanOrEqualTo(8));
      final doux = r.mouvementsMjDe(GraviteMouvement.doux);
      final durs = r.mouvementsMjDe(GraviteMouvement.dur);
      expect(doux.length, greaterThanOrEqualTo(4));
      expect(durs.length, greaterThanOrEqualTo(4));
      expect(durs.map((m) => m.id), contains('destiny'));
      for (final m in r.mouvementsMj) {
        expect(m.nom, isNotEmpty);
        expect(m.texte, isNotEmpty);
      }
      expect(r.mouvementsMj.map((m) => m.id).toSet(), hasLength(r.mouvementsMj.length));
    });

    test('deux ou trois idées de mouvements, de la bonne gravité, toujours les mêmes avec la même graine', () {
      for (final gravite in GraviteMouvement.values) {
        final a = suggestionsMj(r, gravite, hasard: Random(3));
        expect(a, hasLength(3));
        expect(a.every((m) => m.gravite == gravite), isTrue);
        expect(suggestionsMj(r, gravite, hasard: Random(3)).map((m) => m.id), a.map((m) => m.id));
      }
    });

    test('un bonus proposé pour chacun des 12 archétypes', () {
      for (final a in g.archetypes) {
        expect(r.bonusSuggere(a.id), isNotNull, reason: a.id);
      }
      expect(FacePiece.values.every((f) => r.bonusSuggeres.values.contains(f)), isTrue);
    });

    test('les deux faces, leur approche et leur légende', () {
      for (final f in FacePiece.values) {
        for (final cle in ['nom', 'approche', 'legende']) {
          expect(t.t('pbta.piece.faces.${f.name}.$cle'), isNotEmpty, reason: '${f.name}.$cle');
        }
      }
      expect(t.t('pbta.piece.faces.brave.nom'), 'BRAVE');
      expect(t.t('pbta.piece.faces.smart.nom'), 'SMART');
    });

    test('ni dé, ni pile, ni avantage : la pièce BRAVE / SMART', () {
      final mots = RegExp(r'(^|[^\p{L}])(dé|dés|pile|avantage|désavantage)([^\p{L}]|$)', unicode: true, caseSensitive: false);
      void verifier(Object? v, String chemin) {
        if (v is String) expect(mots.hasMatch(v), isFalse, reason: '$chemin : $v');
        if (v is List) {
          for (final (i, x) in v.indexed) {
            verifier(x, '$chemin.$i');
          }
        }
        if (v is Map) {
          for (final e in v.entries) {
            verifier(e.value, '$chemin.${e.key}');
          }
        }
      }

      verifier(t.table('pbta'), 'pbta');
      verifier(t.table('serie'), 'serie');
    });
  });

  group('Le personnage', () {
    test('son bonus se garde ; une ancienne sauvegarde n\'en a pas', () {
      final p = PersonnageSerie(id: 'p', archetypeId: 'leader', bonus: FacePiece.brave);
      expect(PersonnageSerie.depuisJson(jsonDecode(jsonEncode(p.versJson())) as Map<String, dynamic>).bonus, FacePiece.brave);
      expect(PersonnageSerie.depuisJson({'id': 'x', 'archetype': 'leader'}).bonus, isNull);
    });

    test('son nom à l\'écran ne montre plus sa place dans le lieu', () {
      final p = PersonnageSerie(id: 'p', joueur: 'Léa', fonction: 'la serveuse', archetypeId: 'aidant');
      expect(p.appel, 'Léa');
      expect(p.nomSansPrenom, 'la serveuse');
      p.nom = 'Rose';
      expect(p.appel, 'Rose');
    });
  });
}
