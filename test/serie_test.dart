import 'dart:convert';
import 'dart:math';

import 'package:destiny/application/assistant/campagne_assistant.dart';
import 'package:destiny/application/services/llm_service.dart';
import 'package:destiny/application/state/ai_settings.dart';
import 'package:destiny/application/state/serie_store.dart';
import 'package:destiny/domain/entities/chat_message.dart';
import 'package:destiny/domain/grammaire/distribution.dart';
import 'package:destiny/domain/grammaire/modeles.dart';
import 'package:destiny/domain/serie/migration_campagnes.dart';
import 'package:destiny/domain/serie/regles_serie.dart';
import 'package:destiny/domain/serie/serie.dart';
import 'package:destiny/domain/serie/univers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'outils/grammaire_partagee.dart';

/// Un faux service d'IA : il garde ce qu'on lui envoie et rend une réponse
/// écrite d'avance.
class FauxLlm extends LlmService {
  FauxLlm(this.reponse);
  String reponse;
  final List<String> envois = [];

  @override
  Future<String> complete({
    required AiSettings settings,
    required String system,
    required List<ChatMessage> messages,
  }) async {
    envois.add([system, for (final m in messages) m.content].join('\n'));
    return reponse;
  }
}

Future<CatalogueUnivers> chargerCatalogue(Grammaire g) async {
  Future<Map<String, dynamic>> j(String c) async => jsonDecode(await lireFichier(c)) as Map<String, dynamic>;
  return CatalogueUnivers.depuisJson(
    univers: await j('assets/data/univers.json'),
    lieux: await j('assets/data/campagne_lieux.json'),
    mechants: await j('assets/data/campagne_mechants.json'),
    archetypesCampagne: await j('assets/data/campagne_archetypes.json'),
    grammaire: g,
  );
}

/// Une ancienne campagne 1.5.7, au format exact de sa sauvegarde.
const Map<String, dynamic> kCampagneV1 = {
  'id': 3,
  'nom': 'Les pirates du dimanche',
  'univers': 'pirates',
  'ton': 'drole',
  'public': 'enfant',
  'lore': 'Peter Pan',
  'contexte': 'Une île au large.',
  'resume': 'Ils ont trouvé une carte.',
  'accroche': 'Le capitaine revient.',
  'episodesJoues': 2,
  'figurantsMorts': ['tortue'],
  'sbiresMorts': ['Crabe le grincheux'],
  'mechantsMorts': <String>[],
};

void main() {
  late Grammaire g;
  late CatalogueUnivers catalogue;
  setUpAll(() async {
    g = (await chargerGrammaire()).grammaire;
    catalogue = await chargerCatalogue(g);
  });

  group('Le catalogue des univers', () {
    test('21 univers, 42 lieux, 42 méchants avec leur archétype', () {
      expect(catalogue.univers, hasLength(21));
      expect(catalogue.lieux, hasLength(42));
      expect(catalogue.mechants, hasLength(42));
      for (final m in catalogue.mechants) {
        expect(g.archetype(m.mechant.archetypeId), isNotNull, reason: m.mechant.id);
        expect(m.presages, hasLength(4), reason: m.mechant.id);
        expect(m.mechant.sbires, isNotEmpty, reason: m.mechant.id);
        expect(m.mechant.besoin, isNotEmpty, reason: m.mechant.id);
        expect(m.mechant.faille, isNotEmpty, reason: m.mechant.id);
        expect(m.mechant.offreAuTraitre, isNotEmpty, reason: m.mechant.id);
        for (final s in m.mechant.sbires) {
          expect(s.fait, isNotEmpty, reason: s.nom);
          // Un sbire se joue avec la carte de son archétype.
          expect(g.animauxDe(s.archetypeId).map((a) => a.id), contains(s.animalId), reason: s.nom);
        }
      }
      for (final l in catalogue.lieux) {
        expect(l.figurants, hasLength(3), reason: l.id);
        for (final (i, f) in l.figurants.indexed) {
          expect(kTypesParRang[i], contains(f.type), reason: f.nom);
          expect(g.animauxDe(f.archetypeId).map((a) => a.id), contains(f.animalId), reason: f.nom);
        }
      }
      expect(catalogue.tons, hasLength(10));
      expect(catalogue.vouloirs, isNotEmpty);
    });

    test('chaque univers a ses trois dangers à quatre paliers ; en kids, le palier 4 est sans mort', () {
      for (final u in catalogue.univers) {
        expect(u.dangers, hasLength(3), reason: u.id);
        for (final d in u.dangers) {
          expect(d.paliers, hasLength(4), reason: d.id);
          expect(d.paliers.every((p) => p.isNotEmpty), isTrue, reason: d.id);
          if (d.kids) {
            expect(d.supprimeKids, isNotEmpty, reason: d.id);
            expect(d.paliersPour(kids: true).last, d.supprimeKids);
          }
        }
        if (u.kids && !u.adulte) {
          expect(catalogue.dangersDe(u.id, kids: true), hasLength(3), reason: u.id);
        }
      }
    });

    test('les méchants des univers enfants sont kids', () {
      for (final m in catalogue.mechantsDe('pirates')) {
        expect(m.mechant.kids, isTrue);
      }
      for (final m in catalogue.mechantsDe('horreur')) {
        expect(m.mechant.kids, isFalse);
      }
    });

    test('les peuples suivent le lore, puis l\'univers', () {
      expect(catalogue.peuplesPour('animaux_parlent', 'Le Roi Lion').first, 'Lions');
      expect(catalogue.peuplesPour('pirates', '').first, 'Pirates');
      expect(catalogue.peuplesPour('inconnu', ''), isNotEmpty);
    });
  });

  group('Le modèle', () {
    test('une série se relit à l\'identique', () {
      final s = Serie(
        id: 's1',
        creee: DateTime(2026, 11, 2),
        nom: 'La brume',
        public: PublicSerie.kids,
        univers: 'monde_magique',
        reglages: ReglagesSerie(traitre: true, combat: false),
        personnages: [
          PersonnageSerie(
              id: 'p1',
              joueur: 'Naël',
              nom: 'Pip',
              archetypeId: 'aidant',
              animalId: 'chien',
              pouvoir: 'parler aux arbres',
              bonus: FacePiece.smart),
          PersonnageSerie(id: 'p2', archetypeId: 'alarmiste', animalId: 'coq', pnj: true),
        ],
        saisons: [
          SaisonSerie(
            numero: 1,
            mechantId: 'le_seigneur_des_brumes',
            cibleId: 'p1',
            presages: ['a', 'b', 'c', 'd'],
            presagesValides: true,
            traitre: TraitreSaison(personnageId: 'p1', accepte: false),
          ),
        ],
        episodes: [
          EpisodeSerie(
            id: 'e1',
            date: DateTime(2026, 11, 2, 18),
            saison: 1,
            paliers: ['1', '2', '3', '4'],
            roles: [
              RoleEpisode(
                  personnageId: 'p1',
                  vouloir: 'Ouvrir la porte',
                  choix: ChoixFinal.besoin,
                  blessures: 2,
                  vouloirDit: true,
                  elan: true),
            ],
            pnjs: [PnjEpisode(id: 'x.0', nom: 'Lou', mode: ModePnj.figurant, aBascule: true, sante: Sante.blesse)],
            destinys: [const EvenementDestiny(numero: 1, secondes: 600, manuel: true)],
            notes: [const NoteRegie(secondes: 30, texte: 'Bravo')],
            registreRessorti: ['r1'],
          ),
        ],
        registre: [EntreeRegistre(id: 'r1', categorie: CategorieRegistre.promesse, nom: 'La promesse', saison: 1)],
        pnjSortis: ['le_cocher'],
      );
      final relue = Serie.depuisJson(jsonDecode(jsonEncode(s.versJson())) as Map<String, dynamic>);
      expect(jsonEncode(relue.versJson()), jsonEncode(s.versJson()));
      expect(relue.kids, isTrue);
      expect(relue.nature, NatureSerie.saison);
      expect(relue.prochainNumero, 2);
      expect(relue.episodes.single.pnjs.single.aBascule, isTrue);
      expect(relue.personnages.first.bonus, FacePiece.smart);
      expect(relue.personnages.last.bonus, isNull);
      expect(relue.episodes.single.roles.single.blessures, 2);
      expect(relue.episodes.single.roles.single.elan, isTrue);
    });

    test('une série d\'avant le jeu de rôle se relit : univers, ton, fonction, peuple, combat', () {
      final ancienne = {
        'version': 2,
        'id': 'v',
        'creee': '2026-10-01T10:00:00.000',
        'nom': 'Les pirates',
        'public': 'adulte',
        'univers': 'pirates',
        'ton': 'drole',
        'lore': 'Peter Pan',
        'reglages': {'traitre': false, 'registre': true, 'combat': true, 'piece': true},
        'personnages': [
          {'id': 'p1', 'joueur': 'Léa', 'fonction': 'la vigie', 'peuple': 'Pirates', 'archetype': 'leader', 'animal': 'lion'},
        ],
        'episodes': [
          {
            'id': 'e1',
            'date': '2026-10-01T10:00:00.000',
            'roles': [
              {'personnage': 'p1', 'vouloir': 'Le trésor', 'sante': 'blesse', 'mod': -1},
            ],
          },
        ],
      };
      final s = Serie.depuisJson(jsonDecode(jsonEncode(ancienne)) as Map<String, dynamic>);
      expect(s.univers, 'pirates');
      expect(s.ton, 'drole');
      final p = s.personnages.single;
      expect(p.fonction, 'la vigie');
      expect(p.peuple, 'Pirates');
      expect(p.bonus, isNull);
      // Le registre et l'IA reçoivent le personnage, jamais le prénom.
      expect(p.nomSansPrenom, 'la vigie');
      final r = s.episodes.single.roles.single;
      expect(r.sante, Sante.blesse);
      expect(r.mod, -1);
      expect(r.blessures, 0);
      expect(r.vouloirDit, isFalse);
      // Et elle se réécrit sans rien perdre.
      final relue = Serie.depuisJson(jsonDecode(jsonEncode(s.versJson())) as Map<String, dynamic>);
      expect(relue.univers, 'pirates');
      expect(relue.personnages.single.fonction, 'la vigie');
      expect(relue.reglages.combat, isTrue);
    });

    test('un épisode seul est un épisode ; deux saisons font une série', () {
      final s = Serie(id: 'x', creee: DateTime(2026));
      expect(s.nature, NatureSerie.episode);
      s.saisons.addAll([SaisonSerie(numero: 1, mechantId: 'a'), SaisonSerie(numero: 2, mechantId: 'b')]);
      expect(s.nature, NatureSerie.serie);
    });
  });

  group('Le cœur et le cerveau', () {
    test('chaque rôle garde son cœur et son cerveau ; une ancienne sauvegarde est lucide', () {
      final r = RoleEpisode(personnageId: 'p1', sante: Sante.blesse, esprit: Esprit.auBord);
      final relu = RoleEpisode.depuisJson(jsonDecode(jsonEncode(r.versJson())) as Map<String, dynamic>);
      expect(relu.sante, Sante.blesse);
      expect(relu.esprit, Esprit.auBord);
      final ancien = RoleEpisode.depuisJson({'personnage': 'p1', 'sante': 'enForme'});
      expect(ancien.esprit, Esprit.lucide);
      expect(Esprit.depuisTexte('n importe quoi'), Esprit.lucide);
    });

    test('un nouvel épisode reprend le cœur et le cerveau du dernier épisode joué', () {
      final s = Serie(id: 's', creee: DateTime(2026), personnages: [
        PersonnageSerie(id: 'a', archetypeId: 'leader'),
        PersonnageSerie(id: 'b', archetypeId: 'cynique'),
      ]);
      final e1 = EpisodeSerie(id: 'e1', date: DateTime(2026), etape: EtapeEpisode.termine, roles: [
        RoleEpisode(personnageId: 'a', sante: Sante.blesse, esprit: Esprit.fou),
        RoleEpisode(personnageId: 'b', sante: Sante.sorti, esprit: Esprit.ebranle),
      ]);
      // Un épisode commencé mais pas fini ne compte pas.
      final enCours = EpisodeSerie(id: 'e2', date: DateTime(2026), etape: EtapeEpisode.jeu, roles: [
        RoleEpisode(personnageId: 'a'),
      ]);
      s.episodes.addAll([e1, enCours]);
      final a = s.nouveauRole('a', sauf: enCours);
      expect(a.sante, Sante.blesse);
      expect(a.esprit, Esprit.fou);
      // Un mort ne revient pas « mort » : il a quitté la série au rangement.
      expect(s.nouveauRole('b').sante, Sante.enForme);
      expect(s.nouveauRole('inconnu').esprit, Esprit.lucide);
    });

    test('un épisode est une scène jouée, comme une session de la Troupe', () {
      final SceneJouee e = EpisodeSerie(id: 'e', date: DateTime(2026), lieuNom: 'Le phare', dureeMinutes: 30, destinyMinutes: [10, 18, 27]);
      expect(e.lieuNom, 'Le phare');
      e.palierAtteint = 3;
      expect(e.palierAtteint, 3);
      expect(EpisodeSerie.depuisJson((e as EpisodeSerie).versJson()).palierAtteint, 3);
      final notes = EpisodeSerie(id: 'n', date: DateTime(2026), notesMj: 'Ils ont fui par le toit.');
      expect(EpisodeSerie.depuisJson(notes.versJson()).notesMj, 'Ils ont fui par le toit.');
    });
  });

  group('Le méchant de saison', () {
    test('ses reflets ont l\'archétype du protagoniste visé', () {
      for (final a in g.archetypes) {
        final reflets = mechantsReflets(g, archetypeId: a.id, kids: false);
        expect(reflets.length, greaterThanOrEqualTo(2), reason: a.id);
        expect(reflets.every((m) => m.archetypeId == a.id), isTrue);
      }
    });

    test('en kids, seulement des méchants kids, et au moins un par archétype', () {
      for (final a in g.archetypes) {
        final reflets = mechantsReflets(g, archetypeId: a.id, kids: true);
        expect(reflets, isNotEmpty, reason: a.id);
        expect(reflets.every((m) => m.kids), isTrue);
      }
    });

    test('entre humains, seulement les 24 grands méchants (pas d\'univers), chacun avec ses deux sbires', () {
      final ids = {for (final m in g.mechants) m.id};
      expect(mechantsDisponibles(g, kids: false), hasLength(24));
      expect(mechantsDisponibles(g, kids: true), hasLength(g.mechants.where((m) => m.kids).length));
      for (final a in g.archetypes) {
        for (final kids in [false, true]) {
          for (final m in mechantsReflets(g, archetypeId: a.id, kids: kids)) {
            expect(ids, contains(m.id));
            expect(m.sbires, hasLength(2));
          }
        }
      }
      for (var graine = 0; graine < 30; graine++) {
        expect(ids, contains(tirerMechant(g, kids: graine.isEven, hasard: Random(graine))!.id));
      }
    });

    test('le méchant d\'univers d\'une ancienne série se relit toujours', () {
      expect(trouverMechant(g, catalogue, 'pirates_capitaine_gargouille')?.nom, isNotEmpty);
      expect(trouverMechant(g, catalogue, 'le_seigneur_des_brumes')?.id, 'le_seigneur_des_brumes');
      expect(trouverMechant(g, catalogue, ''), isNull);
    });

    test('le tirage évite les méchants déjà joués', () {
      final m = tirerMechant(g,
          kids: false, archetypeId: 'leader', exclus: ['le_seigneur_des_brumes'], hasard: Random(1));
      expect(m, isNotNull);
      expect(m!.id, isNot('le_seigneur_des_brumes'));
      expect(m.archetypeId, 'leader');
    });
  });

  group('L\'escalade', () {
    const paliers = ['p1', 'p2', 'p3', 'p4'];

    test('hors saison sans méchant : le danger monte seul', () {
      final e = escaladeEpisode(paliersDanger: paliers);
      expect(e.map((m) => m.qui), everyElement(QuiAgit.danger));
      expect(e.map((m) => m.ceQueCaProduit), paliers);
    });

    test('hors saison avec un méchant : l\'ancienne règle (le méchant prend les deux dernières marches)', () {
      final m = g.mechant('le_seigneur_des_brumes')!;
      final e = escaladeEpisode(paliersDanger: paliers, mechant: m);
      expect(e.map((x) => x.qui), [QuiAgit.sbire, QuiAgit.sbire, QuiAgit.mechant, QuiAgit.mechant]);
    });

    test('épisodes 1 à 3 : le méchant reste dans l\'ombre', () {
      final m = g.mechant('le_seigneur_des_brumes')!;
      for (final n in [1, 2, 3]) {
        final e = escaladeEpisode(paliersDanger: paliers, mechant: m, saison: 1, numero: n);
        expect(e.any((x) => x.qui == QuiAgit.mechant), isFalse, reason: 'épisode $n');
        expect(e.where((x) => x.qui == QuiAgit.sbire), hasLength(2));
        expect(mechantEnPersonne(saison: 1, numero: n, aUnMechant: true), isFalse);
      }
    });

    test('épisode 4 : le méchant en personne, au final', () {
      final m = g.mechant('le_seigneur_des_brumes')!;
      final e = escaladeEpisode(paliersDanger: paliers, mechant: m, saison: 1, numero: 4);
      expect(e.last.qui, QuiAgit.mechant);
      expect(e.where((x) => x.qui == QuiAgit.mechant), hasLength(1));
      expect(mechantEnPersonne(saison: 1, numero: 4, aUnMechant: true), isTrue);
    });

    test('un sbire sorti laisse sa marche au danger', () {
      final m = g.mechant('le_seigneur_des_brumes')!;
      final e = escaladeEpisode(
          paliersDanger: paliers, mechant: m, saison: 1, numero: 2, sortis: [for (final s in m.sbires) s.id]);
      expect(e.map((x) => x.qui), everyElement(QuiAgit.danger));
    });
  });

  group('Les figurants et les sbires', () {
    test('le lieu de la grammaire donne ses trois figurants', () {
      final lieu = g.lieux.first;
      final f = figurantsDuLieu(g, prets: lieu.figurants);
      expect(f, hasLength(3));
      expect(f.first.type, 'aide');
      expect(f.every((x) => x.mode == ModePnj.figurant && !x.duMechant), isTrue);
    });

    test('sans figurants prêts, trois figurants tirés : un aide, un témoin, une victime', () {
      final f = figurantsDuLieu(g, fonctions: ['le vigile', 'la cuisinière', 'le facteur'], hasard: Random(4));
      expect(f, hasLength(3));
      expect(kTypesParRang[0], contains(f[0].type));
      expect(kTypesParRang[1], contains(f[1].type));
      expect(kTypesParRang[2], contains(f[2].type));
      for (final x in f) {
        expect(g.animauxDe(x.archetypeId).map((a) => a.id), contains(x.animalId));
      }
    });

    test('un figurant sorti ne revient pas', () {
      final lieu = g.lieux.first;
      final f = figurantsDuLieu(g, prets: lieu.figurants, sortis: [lieu.figurants.first.id]);
      expect(f, hasLength(2));
    });

    test('les sbires du méchant sont jouables, sauf ceux qui sont sortis', () {
      final m = g.mechant('le_seigneur_des_brumes')!;
      final s = sbiresDuMechant(m, sortis: [m.sbires.first.id]);
      expect(s, hasLength(1));
      expect(s.single.mode, ModePnj.sbire);
      expect(s.single.duMechant, isTrue);
      expect(g.animal(s.single.animalId), isNotNull);
    });
  });

  group('La distribution', () {
    test('à deux ou trois joueurs, l\'alarmiste est tenu par le maître du jeu', () {
      for (final n in [1, 2, 3]) {
        for (var graine = 0; graine < 20; graine++) {
          final d = tirerDistributionJeu(g, n, hasard: Random(graine));
          expect(d.joueurs, hasLength(n));
          expect(d.alarmistePnj, isTrue);
          expect(d.joueurs, isNot(contains(Grammaire.alarmisteId)));
          expect(d.joueurs.map((id) => g.archetype(id)!.famille).toSet(), hasLength(n));
        }
      }
    });

    test('de quatre à six, l\'alarmiste joue (en jeu de rôle, il est toujours là)', () {
      for (final n in [4, 5, 6]) {
        for (var graine = 0; graine < 30; graine++) {
          final d = tirerDistributionJeu(g, n, hasard: Random(graine));
          expect(d.joueurs, hasLength(n));
          expect(d.joueurs, contains(Grammaire.alarmisteId));
          expect(d.alarmistePnj, isFalse);
          expect(validerDistribution(g, d.joueurs, mode: ModeDistribution.serie).valide, isTrue);
        }
      }
    });

    test('en Série, le maître du jeu tient toujours l\'alarmiste quand aucun joueur ne l\'a', () {
      for (var n = 1; n <= 6; n++) {
        for (var graine = 0; graine < 20; graine++) {
          final d = tirerDistributionJeu(g, n, hasard: Random(graine));
          expect(d.alarmistePnj || d.joueurs.contains(Grammaire.alarmisteId), isTrue, reason: '$n : ${d.joueurs}');
        }
      }
      // Une distribution sans alarmiste, valide au spectacle, ne l'est pas en Série.
      const sans = ['leader', 'prophete', 'denegateur', 'opportuniste'];
      expect(validerDistribution(g, sans).valide, isTrue);
      expect(validerDistribution(g, sans, mode: ModeDistribution.serie).valide, isFalse);
    });

    test('au-delà de six, chacun a un archétype', () {
      final d = tirerDistributionJeu(g, 8, hasard: Random(2));
      expect(d.joueurs, hasLength(8));
      expect(d.joueurs.toSet(), hasLength(8));
    });

    test('le traître n\'est jamais un personnage du maître du jeu', () {
      final ps = [
        PersonnageSerie(id: 'a', archetypeId: 'leader'),
        PersonnageSerie(id: 'b', archetypeId: 'alarmiste', pnj: true),
        PersonnageSerie(id: 'c', archetypeId: 'cynique'),
      ];
      for (var i = 0; i < 20; i++) {
        final t = tirerTraitre(ps, cibleId: 'a', hasard: Random(i))!;
        expect(t.id, 'c');
      }
    });
  });

  group('Le registre', () {
    test('les suggestions : au plus trois, jamais les morts, des catégories variées', () {
      final r = [
        EntreeRegistre(id: '1', categorie: CategorieRegistre.figurant, nom: 'Le facteur'),
        EntreeRegistre(id: '2', categorie: CategorieRegistre.figurant, nom: 'La boulangère'),
        EntreeRegistre(id: '3', categorie: CategorieRegistre.mort, nom: 'Le garde'),
        EntreeRegistre(id: '4', categorie: CategorieRegistre.secret, nom: 'La porte condamnée'),
        EntreeRegistre(id: '5', categorie: CategorieRegistre.promesse, nom: 'Revenir'),
        EntreeRegistre(id: '6', categorie: CategorieRegistre.sbire, nom: 'Le cocher', statut: StatutRegistre.tombe),
        // Un objet noté avant la 2.0.2 : gardé, mais plus proposé.
        EntreeRegistre(id: '7', categorie: CategorieRegistre.objet, nom: 'La clé'),
      ];
      final s = suggestionsRegistre(r, hasard: Random(1));
      expect(s, hasLength(3));
      expect(s.map((e) => e.id), isNot(contains('3')));
      expect(s.map((e) => e.id), isNot(contains('6')));
      expect(s.map((e) => e.id), isNot(contains('7')));
      expect(s.map((e) => e.categorie).toSet(), hasLength(3));
      expect(suggestionsRegistre(r, dejaRessortis: ['1', '2', '4', '5']), isEmpty);
    });

    test('les catégories de l\'IA se lisent avec leurs mots', () {
      expect(CategorieRegistre.depuisTexte('figurants'), CategorieRegistre.figurant);
      // Les anciens objets se relisent toujours.
      expect(CategorieRegistre.depuisTexte('objet'), CategorieRegistre.objet);
      expect(StatutRegistre.depuisTexte('tombé'), StatutRegistre.tombe);
      expect(StatutRegistre.depuisTexte('présent'), StatutRegistre.present);
      expect(CategorieRegistre.actives, hasLength(g.serie.registre.categories.length));
      expect(CategorieRegistre.actives, isNot(contains(CategorieRegistre.objet)));
    });
  });

  group('La migration des anciennes campagnes', () {
    final seances = {
      '3': [
        {
          'numero': 1,
          'dateMs': DateTime(2026, 5, 1).millisecondsSinceEpoch,
          'intitule': 'L\'île au trésor — Capitaine Gargouille',
          'amorceId': 'pirates_ile_tresor|pirates_capitaine_gargouille',
          'phrase': 'À l\'abordage !',
          'ceQuiAMarche': 'Les voix',
          'transcription': 'Il était une fois…',
          'morts': ['Crabe le grincheux'],
          'blesses': <String>[],
        },
        {
          'numero': 2,
          'dateMs': DateTime(2026, 5, 8).millisecondsSinceEpoch,
          'intitule': 'Le bateau — Capitaine Gargouille',
          'amorceId': 'pirates_bateau|pirates_capitaine_gargouille',
        },
      ],
    };

    test('rien ne se perd', () {
      final s = migrerCampagne(kCampagneV1, seances: seances['3'], catalogue: catalogue, maintenant: DateTime(2026, 11, 2));
      expect(s.id, 'campagne-3');
      expect(s.migreDe, 'campagne:3');
      expect(s.nom, 'Les pirates du dimanche');
      expect(s.kids, isTrue);
      expect(s.univers, 'pirates');
      expect(s.lore, 'Peter Pan');
      expect(s.contexte, 'Une île au large.');
      expect(s.resume, 'Ils ont trouvé une carte.');
      expect(s.accroche, 'Le capitaine revient.');
      expect(s.episodes, hasLength(2));
      final e = s.episodes.first;
      expect(e.ancienneGrammaire, isTrue);
      expect(e.etape, EtapeEpisode.termine);
      expect(e.intitule, 'L\'île au trésor — Capitaine Gargouille');
      expect(e.lieuNom, isNotEmpty);
      expect(e.mechantId, 'pirates_capitaine_gargouille');
      expect(e.phrase, 'À l\'abordage !');
      expect(e.transcription, 'Il était une fois…');
      expect(e.mortsAnciens, ['Crabe le grincheux']);
      expect(s.creee, DateTime(2026, 5, 1));
    });

    test('la continuité passe aux ids, et en kids personne n\'est mort', () {
      final s = migrerCampagne(kCampagneV1, seances: seances['3'], catalogue: catalogue, maintenant: DateTime(2026, 11, 2));
      final gargouille = catalogue.mechantUnivers('pirates_capitaine_gargouille')!.mechant;
      final sbire = gargouille.sbires.firstWhere((x) => x.nom == 'Crabe le grincheux');
      expect(s.pnjSortis, contains(sbire.id));
      expect(s.pnjSortis, contains('ancien.figurant.tortue'));
      expect(s.registre, hasLength(2));
      expect(s.registre.every((r) => r.statut == StatutRegistre.parti), isTrue);
      expect(s.registre.any((r) => r.categorie == CategorieRegistre.mort), isFalse);
    });

    test('en adulte, les morts restent des morts', () {
      final c = {...kCampagneV1, 'public': 'adulte', 'univers': 'horreur', 'mechantsMorts': ['horreur_medecin']};
      final s = migrerCampagne(c, catalogue: catalogue, maintenant: DateTime(2026, 11, 2));
      expect(s.kids, isFalse);
      expect(s.registre.where((r) => r.categorie == CategorieRegistre.mort), hasLength(1));
      expect(s.pnjSortis, contains('horreur_medecin'));
    });
  });

  group('Le magasin des séries', () {
    Future<SerieStore> magasin({LlmService? llm, AiSettings? ia}) async {
      final m = SerieStore(lire: lireFichier, llm: llm, aiSettings: ia);
      await m.charger(grammaire: g);
      return m;
    }

    test('migre une seule fois, sans toucher aux anciennes clés', () async {
      final v1 = jsonEncode([kCampagneV1]);
      SharedPreferences.setMockInitialValues({SerieStore.cleCampagnesV1: v1});
      final m = await magasin();
      expect(m.series, hasLength(1));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(SerieStore.cleCampagnesV1), v1);

      // Rechargement : pas de doublon. Suppression : elle ne revient pas.
      final m2 = await magasin();
      expect(m2.series, hasLength(1));
      await m2.supprimer('campagne-3');
      final m3 = await magasin();
      expect(m3.series, isEmpty);
    });

    test('une sauvegarde illisible n\'est jamais écrasée', () async {
      SharedPreferences.setMockInitialValues({SerieStore.cleSeries: '{pas du json'});
      final m = await magasin();
      expect(m.lectureEchouee, isTrue);
      await m.creer(nom: 'Nouvelle');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(SerieStore.cleSeries), '{pas du json');
    });

    test('créer, enregistrer, relire', () async {
      SharedPreferences.setMockInitialValues({});
      final m = await magasin();
      final s = await m.creer(nom: 'La brume', public: PublicSerie.kids);
      s.personnages.add(PersonnageSerie(id: 'p1', archetypeId: 'aidant', pouvoir: 'voler'));
      await m.enregistrer(s);
      final m2 = await magasin();
      expect(m2.serie(s.id)!.personnages.single.pouvoir, 'voler');
    });
  });

  group('La vie privée', () {
    const prenom = 'Naël';

    Future<(SerieStore, FauxLlm, Serie)> preparer(String reponse) async {
      SharedPreferences.setMockInitialValues({'ai_token': 'jeton'});
      final ia = await AiSettings.load();
      final llm = FauxLlm(reponse);
      final m = SerieStore(lire: lireFichier, llm: llm, aiSettings: ia);
      await m.charger(grammaire: g);
      final s = await m.creer(public: PublicSerie.kids, contexte: 'Pour $prenom et sa sœur.');
      s.personnages.add(PersonnageSerie(id: 'p1', joueur: prenom, nom: 'le petit renard', archetypeId: 'cynique'));
      return (m, llm, s);
    }

    test('aucun prénom ne part vers l\'IA', () async {
      final (m, llm, s) = await preparer('{"resume": "R", "suite": "S", "registre": []}');
      await m.resumer(s, transcription: '$prenom ouvre la porte. naël rit.', categories: ['figurant']);
      expect(llm.envois, hasLength(1));
      expect(llm.envois.single.toLowerCase(), isNot(contains(prenom.toLowerCase())));
      expect(llm.envois.single, contains('le petit renard'));
    });

    test('le registre ne garde aucun prénom, même si l\'IA en répète un', () async {
      final (m, _, s) = await preparer(jsonEncode({
        'resume': '$prenom a gagné.',
        'suite': 'On retrouve $prenom.',
        'registre': [
          {'categorie': 'figurant', 'nom': 'Le facteur', 'detail': 'Il a parlé à $prenom.', 'statut': 'présent'},
          {'categorie': 'mort', 'nom': 'Le garde', 'detail': 'Tombé.', 'statut': 'tombé'},
        ],
      }));
      final e = EpisodeSerie(id: 'e1', date: DateTime(2026));
      s.episodes.add(e);
      final memoire = await m.resumer(s, transcription: 'bla', categories: ['figurant', 'mort']);
      m.integrerMemoire(s, e, memoire);
      final tout = jsonEncode(s.versJson()..remove('personnages')..remove('contexte'));
      expect(tout.toLowerCase(), isNot(contains(prenom.toLowerCase())));
      expect(s.registre, hasLength(2));
      // En kids, personne ne meurt.
      expect(s.registre.any((r) => r.categorie == CategorieRegistre.mort), isFalse);
      expect(s.registre.last.statut, StatutRegistre.parti);
    });

    test('rien de l\'univers, du ton ni du lore ne part vers l\'IA, même pour une ancienne série', () async {
      final (m, llm, s) = await preparer('{"resume": "R", "suite": "S", "presages": ["a", "b", "c", "d"], "choix": []}');
      s
        ..univers = 'pirates'
        ..ton = 'drole'
        ..lore = 'Peter Pan';
      await m.resumer(s, transcription: 'Ils ouvrent la porte.');
      await m.proposerPresages(s, g.mechant('le_seigneur_des_brumes')!, paliers: [for (final x in g.paliers) x.nom]);
      await m.proposerRessortis(s, [EntreeRegistre(id: 'r', categorie: CategorieRegistre.secret, nom: 'La porte condamnée')]);
      expect(llm.envois, hasLength(3));
      for (final envoi in llm.envois) {
        expect(envoi, isNot(contains('Univers')));
        expect(envoi, isNot(contains('Ton :')));
        expect(envoi, isNot(contains('Peter Pan')));
        expect(envoi.toLowerCase(), isNot(contains('pirates')));
      }
    });

    test('les présages et les ressortis passent par l\'assistant, sans prénom', () async {
      final (m, llm, s) = await preparer('{"presages": ["un", "deux", "trois", "quatre"], "choix": [{"numero": 1, "comment": "Il revient"}]}');
      final p = await m.proposerPresages(s, g.mechant('le_seigneur_des_brumes')!, paliers: [for (final x in g.paliers) x.nom]);
      expect(p, ['un', 'deux', 'trois', 'quatre']);
      final r = await m.proposerRessortis(s, [EntreeRegistre(id: 'r', categorie: CategorieRegistre.figurant, nom: 'Le facteur')]);
      expect(r.single.numero, 1);
      for (final envoi in llm.envois) {
        expect(envoi.toLowerCase(), isNot(contains(prenom.toLowerCase())));
      }
    });

    test('la mémoire se lit avec son registre', () {
      final m = MemoireEpisode.depuis(
          'Voilà : {"resume": "R", "suite": "S", "registre": [{"categorie": "objet", "nom": "La clé", "liens": ["la porte"]}, {"nom": ""}]}');
      expect(m.registre, hasLength(1));
      expect(m.registre.single.liens, ['la porte']);
    });
  });
}
