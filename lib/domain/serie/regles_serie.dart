/// Les règles de la Série, sans interface : le méchant reflet, l'escalade
/// d'un épisode, les figurants du lieu, la distribution des archétypes et les
/// suggestions du registre. Tout est déterministe quand on donne un hasard.
library;

import 'dart:math';

import '../grammaire/distribution.dart';
import '../grammaire/modeles.dart';
import 'serie.dart';
import 'univers.dart';

/// Les méchants qu'on peut choisir pour une saison : les 24 grands méchants
/// de la grammaire, chacun avec ses deux sbires. En kids, seulement les
/// méchants kids. (Les méchants d'univers restent dans la Bibliothèque et
/// dans les modes avec l'IA : entre humains, on n'a pas d'univers.)
List<Mechant> mechantsDisponibles(Grammaire g, {required bool kids}) => [
      for (final m in g.mechants)
        if (!kids || m.kids) m,
    ];

/// Retrouve un méchant par son id : un grand méchant, ou le méchant d'univers
/// d'une ancienne série (pour la relire telle quelle).
Mechant? trouverMechant(Grammaire g, CatalogueUnivers catalogue, String id) {
  if (id.isEmpty) return null;
  return g.mechant(id) ?? catalogue.mechantUnivers(id)?.mechant;
}

/// Les méchants reflets du protagoniste visé : les grands méchants qui ont
/// le même archétype que lui.
List<Mechant> mechantsReflets(Grammaire g, {required String archetypeId, required bool kids}) =>
    g.mechantsReflets(archetypeId, kids: kids);

/// Un méchant au hasard. Avec un [archetypeId], parmi ses reflets.
Mechant? tirerMechant(
  Grammaire g, {
  required bool kids,
  String archetypeId = '',
  Iterable<String> exclus = const [],
  Random? hasard,
}) {
  final rng = hasard ?? Random();
  var pool = archetypeId.isEmpty
      ? mechantsDisponibles(g, kids: kids)
      : mechantsReflets(g, archetypeId: archetypeId, kids: kids);
  final restants = [for (final m in pool) if (!exclus.contains(m.id)) m];
  if (restants.isNotEmpty) pool = restants;
  if (pool.isEmpty) return null;
  return pool[rng.nextInt(pool.length)];
}

/// Qui agit sur une marche de l'escalade.
enum QuiAgit { danger, sbire, mechant }

/// Une marche de l'escalade, alignée sur un palier.
class MarcheEscalade {
  const MarcheEscalade({
    required this.palier,
    required this.qui,
    required this.nom,
    required this.ceQuIlFait,
    required this.ceQueCaProduit,
    this.sbireId = '',
  });

  final PalierId palier;
  final QuiAgit qui;

  /// Le nom de celui qui agit (vide pour le danger).
  final String nom;
  final String ceQuIlFait;
  final String ceQueCaProduit;
  final String sbireId;
}

/// L'escalade d'un épisode, une marche par palier.
///
/// - **Hors saison, sans méchant** : le danger monte seul.
/// - **Hors saison, avec un méchant** (l'ancienne règle de la Campagne) : les
///   sbires agissent d'abord, le méchant prend les deux dernières marches.
/// - **En saison, épisodes 1 à 3** : le méchant reste dans l'ombre ; les
///   marches sont jouées par le danger et par ses sbires.
/// - **En saison, épisode 4** : ses sbires, le danger, puis le méchant en
///   personne, au final.
///
/// Un sbire qui a quitté l'histoire laisse sa marche au danger.
List<MarcheEscalade> escaladeEpisode({
  required List<String> paliersDanger,
  Mechant? mechant,
  int saison = 0,
  int numero = 1,
  Iterable<String> sortis = const [],
}) {
  String palierTexte(int i) => i < paliersDanger.length ? paliersDanger[i] : '';
  final sbires = mechant == null ? const <Sbire>[] : [for (final s in mechant.sbires) if (!sortis.contains(s.id)) s];
  var rangSbire = 0;
  Sbire? prochainSbire() => sbires.isEmpty ? null : sbires[rangSbire++ % sbires.length];

  final qui = <QuiAgit>[];
  if (mechant == null) {
    qui.addAll(List.filled(4, QuiAgit.danger));
  } else if (saison == 0) {
    qui.addAll([QuiAgit.sbire, QuiAgit.sbire, QuiAgit.mechant, QuiAgit.mechant]);
  } else if (numero < 4) {
    qui.addAll([QuiAgit.danger, QuiAgit.sbire, QuiAgit.sbire, QuiAgit.danger]);
  } else {
    qui.addAll([QuiAgit.sbire, QuiAgit.sbire, QuiAgit.danger, QuiAgit.mechant]);
  }

  final marches = <MarcheEscalade>[];
  for (var i = 0; i < 4; i++) {
    final palier = PalierId.values[i];
    var q = qui[i];
    Sbire? s;
    if (q == QuiAgit.sbire) {
      s = prochainSbire();
      if (s == null) q = mechant != null && saison == 0 ? QuiAgit.mechant : QuiAgit.danger;
    }
    marches.add(switch (q) {
      QuiAgit.danger => MarcheEscalade(palier: palier, qui: q, nom: '', ceQuIlFait: '', ceQueCaProduit: palierTexte(i)),
      QuiAgit.sbire => MarcheEscalade(
          palier: palier, qui: q, nom: s!.nom, ceQuIlFait: s.fait, ceQueCaProduit: palierTexte(i), sbireId: s.id),
      QuiAgit.mechant => MarcheEscalade(
          palier: palier, qui: q, nom: mechant!.nom, ceQuIlFait: mechant.veut, ceQueCaProduit: palierTexte(i)),
    });
  }
  return marches;
}

/// Le méchant se montre-t-il en personne dans cet épisode ? En saison,
/// seulement au final de l'épisode 4.
bool mechantEnPersonne({required int saison, required int numero, required bool aUnMechant}) =>
    aUnMechant && (saison == 0 || numero >= 4);

/// Les types de figurants proposés, dans l'ordre de la grammaire : un aide,
/// un témoin (ou assimilé), une victime (ou assimilée).
const List<List<String>> kTypesParRang = [
  ['aide'],
  ['temoin', 'commere', 'curieux', 'officiel'],
  ['victime', 'sceptique', 'innocent'],
];

/// Les figurants de l'épisode : les trois figurants prêts à jouer du lieu de
/// la grammaire. S'il n'y en a pas (un lieu ajouté à la main), on en tire
/// trois parmi les 24 animaux, un par rang (aide, témoin, victime), avec les
/// rôles du lieu.
/// Les figurants qui ont quitté l'histoire ne reviennent pas.
List<PnjEpisode> figurantsDuLieu(
  Grammaire g, {
  List<FigurantPret> prets = const [],
  List<String> fonctions = const [],
  Iterable<String> sortis = const [],
  String prefixe = 'figurant',
  Random? hasard,
}) {
  final vivants = [for (final f in prets) if (!sortis.contains(f.id)) f];
  if (vivants.isNotEmpty) {
    return [
      for (final f in vivants)
        PnjEpisode(
          id: f.id,
          nom: f.nom,
          mode: f.mode,
          type: f.type,
          archetypeId: f.archetypeId,
          animalId: f.animalId,
          veut: f.veut,
          vientDe: f.vientDe,
          sait: f.sait,
        ),
    ];
  }
  final rng = hasard ?? Random();
  final archetypes = [for (final a in g.archetypes) a.id]..shuffle(rng);
  final roles = [...fonctions]..shuffle(rng);
  return [
    for (var i = 0; i < 3; i++)
      () {
        final types = kTypesParRang[i];
        final type = types[rng.nextInt(types.length)];
        final archetypeId = archetypes[i];
        return PnjEpisode(
          id: '$prefixe.$i',
          nom: i < roles.length ? roles[i] : (g.figurants.type(type)?.nom ?? type),
          mode: ModePnj.figurant,
          type: type,
          archetypeId: archetypeId,
          animalId: tirerAnimal(g, archetypeId, hasard: rng),
          veut: g.figurants.type(type)?.veut ?? '',
        );
      }(),
  ];
}

/// Les sbires du méchant, prêts à jouer dans l'épisode (ceux qui ont quitté
/// l'histoire ne reviennent pas).
List<PnjEpisode> sbiresDuMechant(Mechant? mechant, {Iterable<String> sortis = const []}) => [
      if (mechant != null)
        for (final s in mechant.sbires)
          if (!sortis.contains(s.id))
            PnjEpisode(
              id: s.id,
              nom: s.nom,
              mode: ModePnj.sbire,
              archetypeId: s.archetypeId,
              animalId: s.animalId,
              veut: s.veut,
              vientDe: s.vientDe,
              fait: s.fait,
              duMechant: true,
            ),
    ];

/// Une distribution pour le jeu de rôle.
class DistributionJeu {
  const DistributionJeu({required this.joueurs, required this.alarmistePnj});

  /// Un archétype par joueur.
  final List<String> joueurs;

  /// Moins de quatre joueurs : l'alarmiste est un personnage non joueur,
  /// tenu par le maître du jeu.
  final bool alarmistePnj;
}

/// Tire une distribution équilibrée. De 4 à 6 joueurs, la règle du
/// spectacle (l'alarmiste est toujours là). En dessous, une famille par
/// joueur, et l'alarmiste est tenu par le maître du jeu. Au-delà de 6, on
/// complète avec des archétypes encore libres.
DistributionJeu tirerDistributionJeu(Grammaire g, int joueurs, {Random? hasard, List<String> imposes = const []}) {
  final rng = hasard ?? Random();
  if (joueurs <= 0) return const DistributionJeu(joueurs: [], alarmistePnj: true);
  if (joueurs >= 4) {
    final base = tirerDistribution(g, joueurs.clamp(4, 6), hasard: rng, imposes: imposes);
    final libres = [for (final a in g.archetypes) if (!base.contains(a.id)) a.id]..shuffle(rng);
    final ids = [...base];
    for (final id in libres) {
      if (ids.length >= joueurs) break;
      ids.add(id);
    }
    while (ids.length < joueurs) {
      ids.add(g.archetypes[rng.nextInt(g.archetypes.length)].id);
    }
    return DistributionJeu(joueurs: ids, alarmistePnj: false);
  }
  final ids = <String>[for (final id in imposes) if (g.archetype(id) != null && id != Grammaire.alarmisteId) id];
  final familles = [...FamilleId.values]..shuffle(rng);
  for (final f in familles) {
    if (ids.length >= joueurs) break;
    if (ids.any((id) => g.archetype(id)?.famille == f)) continue;
    final libres = [
      for (final a in g.archetypesDe(f))
        if (a.id != Grammaire.alarmisteId && !ids.contains(a.id)) a.id,
    ]..shuffle(rng);
    if (libres.isNotEmpty) ids.add(libres.first);
  }
  final restants = [
    for (final a in g.archetypes)
      if (a.id != Grammaire.alarmisteId && !ids.contains(a.id)) a.id,
  ]..shuffle(rng);
  for (final id in restants) {
    if (ids.length >= joueurs) break;
    ids.add(id);
  }
  return DistributionJeu(joueurs: ids..shuffle(rng), alarmistePnj: true);
}

/// Jusqu'à trois entrées du registre à ressortir, sans l'IA : de préférence
/// des figurants encore là, des objets, des promesses et des secrets, puis le
/// reste ; jamais les morts. En kids, les « morts » ne sont pas proposés.
List<EntreeRegistre> suggestionsRegistre(
  List<EntreeRegistre> registre, {
  Iterable<String> dejaRessortis = const [],
  int combien = 3,
  Random? hasard,
}) {
  final rng = hasard ?? Random();
  const preferees = {
    CategorieRegistre.figurant,
    CategorieRegistre.objet,
    CategorieRegistre.promesse,
    CategorieRegistre.secret,
    CategorieRegistre.heritage,
  };
  final candidates = [
    for (final e in registre)
      if (e.categorie != CategorieRegistre.mort &&
          e.statut != StatutRegistre.tombe &&
          !dejaRessortis.contains(e.id))
        e,
  ]..shuffle(rng);
  candidates.sort((a, b) {
    final pa = preferees.contains(a.categorie) ? 0 : 1;
    final pb = preferees.contains(b.categorie) ? 0 : 1;
    return pa.compareTo(pb);
  });
  // Pas deux entrées de la même catégorie si on peut l'éviter.
  final choisies = <EntreeRegistre>[];
  for (final e in candidates) {
    if (choisies.length >= combien) break;
    if (choisies.any((c) => c.categorie == e.categorie)) continue;
    choisies.add(e);
  }
  for (final e in candidates) {
    if (choisies.length >= combien) break;
    if (!choisies.contains(e)) choisies.add(e);
  }
  return choisies;
}

/// Le personnage qu'on propose comme traître : un joueur (jamais un
/// personnage tenu par le maître du jeu), au hasard, si possible autre que la
/// cible du méchant.
PersonnageSerie? tirerTraitre(List<PersonnageSerie> personnages, {String cibleId = '', Random? hasard}) {
  final joueurs = [for (final p in personnages) if (!p.pnj && !p.sorti) p];
  if (joueurs.isEmpty) return null;
  final autres = [for (final p in joueurs) if (p.id != cibleId) p];
  final pool = autres.isNotEmpty ? autres : joueurs;
  return pool[(hasard ?? Random()).nextInt(pool.length)];
}
