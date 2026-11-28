import 'dart:convert';
import 'dart:io';

import 'package:destiny/domain/entities/chat_story.dart';
import 'package:destiny/domain/grammaire/migration_archetypes.dart';
import 'package:destiny/domain/grammaire/modeles.dart';
import 'package:destiny/domain/serie/serie.dart';
import 'package:destiny/domain/troupe/session.dart';
import 'package:flutter_test/flutter_test.dart';

import 'outils/grammaire_partagee.dart';

/// Les ids des archétypes supprimés en 2.5.
const _supprimes = ['debrouillard', 'cynique', 'opportuniste', 'solitaire', 'gardien_de_l_ordre'];

/// Toutes les chaînes (clés et valeurs) d'un JSON, avec leur chemin.
Iterable<(String, String)> _chaines(Object? o, [String chemin = '']) sync* {
  if (o is Map) {
    for (final e in o.entries) {
      yield ('$chemin.{clé ${e.key}}', '${e.key}');
      yield* _chaines(e.value, '$chemin.${e.key}');
    }
  } else if (o is List) {
    for (final (i, x) in o.indexed) {
      yield* _chaines(x, '$chemin[$i]');
    }
  } else if (o is String) {
    yield (chemin, o);
  }
}

void main() {
  late Grammaire g;
  setUpAll(() async => g = (await chargerGrammaire()).grammaire);

  group('Les huit archétypes', () {
    test('8 archétypes, dans l\'ordre du tableau, 3 animaux chacun, les 24 une seule fois', () {
      const attendu = {
        'leader': ['lion', 'aigle', 'renard'],
        'protecteur': ['ours', 'loup', 'cerf'],
        'aidant': ['chien', 'mouton', 'souris'],
        'alarmiste': ['coq', 'rat', 'chat'],
        'denegateur': ['ane', 'porc', 'singe'],
        'prophete': ['paon', 'corbeau', 'hibou'],
        'tyran': ['fourmi', 'taureau', 'hyene'],
        'paranoiaque': ['lapin', 'serpent', 'vautour'],
      };
      expect(g.archetypes.map((a) => a.id), attendu.keys);
      for (final MapEntry(key: id, value: animaux) in attendu.entries) {
        expect(g.animauxDe(id).map((a) => a.id), animaux, reason: id);
        for (final a in animaux) {
          expect(g.animal(a)!.archetypeId, id);
        }
      }
      expect(g.animaux.map((a) => a.id), attendu.values.expand((x) => x), reason: 'l\'ordre du tableau partout');
      expect(g.animaux.map((a) => a.id).toSet(), hasLength(24));
    });

    test('le Gardien de l\'ordre devient le Tyran, avec sa montée', () {
      final t = g.archetype('tyran')!;
      expect(t.nom, 'Tyran');
      expect(t.famille, FamilleId.fissure);
      expect(t.ceQuIlFait, 'Impose sa loi, rationne, punit qui désobéit.');
      expect([for (final p in PalierId.values) t.monteeA(p)],
          ['Fixer les règles', 'Punir qui désobéit', "Sacrifier quelqu'un au nom de la règle"]);
      for (final id in _supprimes) {
        expect(g.archetype(id), isNull, reason: id);
      }
    });

    test('les huit vêtements qui changent d\'archétype', () {
      final renard = g.animal('renard')!;
      expect((renard.statutDepart, renard.port), (Statut.neutre, 'souple'));
      expect(renard.replique, "J'adore quand un plan se déroule sans accroc.");
      expect(renard.repliqueAdulteSeulement, isFalse);
      expect(g.animal('cerf')!.replique, 'On ne laisse pas Bébé dans un coin.');
      expect(g.animal('cerf')!.statutDepart, Statut.haut);
      expect(g.animal('souris')!.sourceReplique, 'Le Seigneur des anneaux : Le Retour du roi');
      expect(g.animal('hibou')!.posture, "immobile, il observe, parle peu, et ce qu'il annonce arrive");
      expect(g.animal('chat')!.replique, 'Ils sont là !');
      expect(g.animal('chat')!.port, 'aux aguets');
      expect(g.animal('singe')!.replique, "Ce n'est qu'une égratignure !");
      expect(g.animal('hyene')!.replique, "Je vais lui faire une offre qu'il ne pourra pas refuser.");
      expect(g.animal('hyene')!.exempleVouloir, "Je veux que le nouveau s'excuse devant toute l'équipe de m'avoir contredit.");
      expect(g.animal('vautour')!.port, 'perché');
      expect(g.animal('fourmi')!.exempleVouloir,
          'Je veux que mon collègue refasse son rapport ce soir, comme le veut le règlement.');
    });

    test('les 24 animaux ont une réplique, une réplique kids, un exemple et un exemple kids', () {
      for (final a in g.animaux) {
        expect(a.replique.trim(), isNotEmpty, reason: a.id);
        expect(a.repliqueKids.trim(), isNotEmpty, reason: a.id);
        expect(a.exempleVouloir.trim(), isNotEmpty, reason: a.id);
        expect(a.exempleVouloirKids.trim(), isNotEmpty, reason: a.id);
      }
    });

    test('en mode kids, le Vautour dit « Mon précieux… », et le Renard garde sa réplique', () {
      final vautour = g.animal('vautour')!;
      expect(vautour.replique, "Je sais ce que vous avez fait l'été dernier.");
      expect(vautour.repliqueAdulteSeulement, isTrue);
      expect(vautour.repliquePour(kids: true), 'Mon précieux…');
      expect(vautour.sourcePour(kids: true), 'Le Seigneur des anneaux');
      final renard = g.animal('renard')!;
      expect(renard.repliquePour(kids: true), renard.replique);
      final j = jsonDecode(File('assets/data/destiny_grammaire.json').readAsStringSync()) as Map;
      final remplacees = [for (final r in (j['mode_kids'] as Map)['repliques_remplacees'] as List) (r as Map)['animal']];
      expect(remplacees, contains('Vautour'));
      expect(remplacees, isNot(contains('Renard')));
    });
  });

  group('Plus d\'anciens archétypes', () {
    test('ni dans les données (hors « obsolete »), ni dans les textes affichés', () {
      final fichiers = Directory('assets/data').listSync().whereType<File>().where((f) => f.path.endsWith('.json'));
      for (final f in fichiers) {
        final j = jsonDecode(f.readAsStringSync());
        if (j is Map && j.containsKey('obsolete')) j.remove('obsolete');
        for (final (chemin, s) in _chaines(j)) {
          expect(_supprimes, isNot(contains(s)), reason: '${f.path} $chemin');
          expect(s.toLowerCase(), isNot(contains("gardien de l'ordre")), reason: '${f.path} $chemin');
          expect(s.toLowerCase(), isNot(contains("gardienne de l'ordre")), reason: '${f.path} $chemin');
          for (final nom in ['Le débrouillard', 'Le cynique', "L'opportuniste", 'Le solitaire']) {
            expect(s.startsWith(nom), isFalse, reason: '${f.path} $chemin : $s');
          }
        }
      }
      final g2 = jsonDecode(File('assets/data/destiny_grammaire.json').readAsStringSync()) as Map;
      final obsolete = (g2['obsolete'] as List).join(' ');
      for (final nom in ['Débrouillard', 'Cynique', 'Opportuniste', 'Solitaire', "Gardien de l'ordre"]) {
        expect(obsolete, contains(nom));
      }
    });

    test('ni dans le code (hors la migration)', () {
      final motif = RegExp("'(${_supprimes.join('|')})'|[Gg]ardien de l'ordre|[Gg]ardien de l\\\\'ordre");
      for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
        if (!f.path.endsWith('.dart') || f.path.endsWith('migration_archetypes.dart')) continue;
        expect(motif.hasMatch(f.readAsStringSync()), isFalse, reason: f.path);
      }
    });

    test('chaque figurant, sbire et personnage d\'œuvre a un archétype qui existe', () async {
      for (final l in g.lieux) {
        for (final f in l.figurants) {
          expect(g.archetype(f.archetypeId), isNotNull, reason: '${l.nom} : ${f.nom}');
        }
      }
      for (final m in g.mechants) {
        expect(g.archetype(m.archetypeId), isNotNull, reason: m.id);
        for (final s in m.sbires) {
          expect(g.archetype(s.archetypeId), isNotNull, reason: s.id);
          expect(g.animal(s.animalId)?.archetypeId, s.archetypeId, reason: s.id);
        }
      }
      for (final o in g.oeuvres) {
        for (final p in o.personnages) {
          expect(g.archetype(p.archetypeId), isNotNull, reason: '${o.titre} : ${p.nom}');
        }
      }
      // Les figurants et méchants des univers de la Série.
      for (final fichier in ['assets/data/campagne_lieux.json', 'assets/data/campagne_mechants.json']) {
        final j = jsonDecode(await lireFichier(fichier));
        for (final (chemin, s) in _chaines(j)) {
          if (chemin.endsWith('.archetype')) expect(g.archetype(s), isNotNull, reason: '$fichier $chemin');
        }
      }
    });
  });

  group('La migration des données enregistrées', () {
    test('gardien_de_l_ordre, cynique avec Singe, solitaire sans animal, un id inconnu', () {
      expect(migrerArchetype('gardien_de_l_ordre'), 'tyran');
      expect(migrerArchetype('gardien_de_l_ordre', animal: 'fourmi'), 'tyran');
      expect(migrerArchetype('cynique', animal: 'singe'), 'denegateur');
      expect(migrerArchetype('cynique', animal: 'Singe'), 'denegateur');
      expect(migrerArchetype('cynique', animal: 'renard'), 'leader');
      expect(migrerArchetype('solitaire'), 'paranoiaque');
      expect(migrerArchetype('solitaire', animal: 'cerf'), 'protecteur');
      expect(migrerArchetype('opportuniste', animal: 'Hyène'), 'tyran');
      expect(migrerArchetype('opportuniste', animal: 'vautour'), 'paranoiaque');
      expect(migrerArchetype('debrouillard', animal: 'hibou'), 'prophete');
      expect(migrerArchetype('debrouillard'), 'aidant');
      expect(migrerArchetype('debrouillard', animal: 'licorne'), 'aidant');
      expect(migrerArchetype('leader', animal: 'lion'), 'leader');
      expect(migrerArchetype('inconnu_du_futur'), 'inconnu_du_futur');
      expect(migrerArchetype(''), '');
      expect(migrerArchetypes(['cynique', 'solitaire', 'tyran']), ['denegateur', 'paranoiaque', 'tyran']);
    });

    test('à la lecture d\'une troupe, d\'une série et d\'une histoire', () {
      final session = SessionTroupe.depuisJson({
        'id': 's',
        'date': DateTime(2026).toIso8601String(),
        'personnages': [
          {'archetype': 'gardien_de_l_ordre', 'animal': 'taureau'},
          {'archetype': 'cynique', 'animal': 'singe'},
          {'archetype': 'solitaire', 'animal': ''},
          {'archetype': 'n_existe_pas'},
        ],
      });
      expect(session.personnages.map((p) => p.archetypeId), ['tyran', 'denegateur', 'paranoiaque', 'n_existe_pas']);
      // Relue après enregistrement : plus rien à migrer.
      final relue = SessionTroupe.depuisJson(jsonDecode(jsonEncode(session.versJson())) as Map<String, dynamic>);
      expect(relue.personnages.map((p) => p.archetypeId), ['tyran', 'denegateur', 'paranoiaque', 'n_existe_pas']);

      final p = PersonnageSerie.depuisJson(
          {'id': 'p', 'archetype': 'debrouillard', 'animal': 'souris', 'anciens_archetypes': ['cynique', 'gardien_de_l_ordre']});
      expect(p.archetypeId, 'aidant');
      expect(p.anciensArchetypes, ['denegateur', 'tyran']);

      final joueur = ChatPlayer.fromJson({'name': 'Léa', 'archetype_id': 'opportuniste', 'animal_id': 'vautour'});
      expect(joueur.archetypeId, 'paranoiaque');
    });
  });
}
