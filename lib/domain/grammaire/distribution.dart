import 'dart:math';

import 'modeles.dart';
import 'textes.dart';

/// Pour quel jeu on distribue : au spectacle, l'alarmiste est un archétype
/// comme les autres, facultatif (le danger vient de la régie) ; en jeu de
/// rôle (la Série), il est toujours là, tenu par le maître du jeu s'il
/// manque parmi les joueurs.
enum ModeDistribution { spectacle, serie }

/// Un problème dans une distribution d'archétypes.
enum TypeProbleme {
  nombre,
  inconnu,
  doublon,
  sansAlarmiste,
  duelIncomplet,
  familleManquante,
}

class ProblemeDistribution {
  const ProblemeDistribution(this.type, {this.archetypeId, this.famille});

  final TypeProbleme type;
  final String? archetypeId;
  final FamilleId? famille;
}

/// Une correction proposée : un ou deux remplacements (l'archétype à
/// l'index devient le nouveau), ou un ajout quand l'index vaut null.
class CorrectionDistribution {
  const CorrectionDistribution({this.index, this.ancienId, required this.nouveauId, this.autres = const []});

  final int? index;
  final String? ancienId;
  final String nouveauId;

  /// D'autres remplacements à faire en même temps (changer un duel entier).
  final List<CorrectionDistribution> autres;

  /// Applique la correction à une distribution.
  List<String> appliquer(List<String> ids) {
    final copie = [...ids];
    for (final c in [this, ...autres]) {
      if (c.index == null) {
        copie.add(c.nouveauId);
      } else {
        copie[c.index!] = c.nouveauId;
      }
    }
    return copie;
  }
}

/// Le verdict sur une distribution.
class VerdictDistribution {
  const VerdictDistribution(this.problemes, this.correction);

  final List<ProblemeDistribution> problemes;
  final CorrectionDistribution? correction;

  bool get valide => problemes.isEmpty;

  /// La raison principale, en une phrase.
  String raison(Grammaire g, TextesDestiny t) {
    if (valide) return t.t('distribution.ok');
    return message(problemes.first, g, t);
  }

  /// La correction proposée, en une phrase (vide s'il n'y en a pas).
  String phraseCorrection(Grammaire g, TextesDestiny t) {
    final c = correction;
    if (c == null) return '';
    String nom(String id) => g.archetype(id)?.nom ?? id;
    if (c.ancienId == null) {
      return t.t('distribution.correction_ajout', {'nouveau': nom(c.nouveauId)});
    }
    final toutes = [c, ...c.autres];
    return t.t('distribution.correction', {
      'ancien': toutes.map((x) => nom(x.ancienId ?? '')).join(' et '),
      'nouveau': toutes.map((x) => nom(x.nouveauId)).join(' et '),
    });
  }

  static String message(ProblemeDistribution p, Grammaire g, TextesDestiny t) {
    String famille(FamilleId f) => _minusculeInitiale(g.famille(f).nom);
    final id = p.archetypeId ?? '';
    final nomArchetype = g.archetype(id)?.nom ?? id;
    return switch (p.type) {
      TypeProbleme.nombre => t.t('distribution.nombre'),
      TypeProbleme.inconnu => t.t('distribution.inconnu', {'archetype': nomArchetype}),
      TypeProbleme.doublon => t.t('distribution.doublon', {'archetype': nomArchetype}),
      TypeProbleme.sansAlarmiste => t.t('distribution.sans_alarmiste'),
      TypeProbleme.duelIncomplet => t.t('distribution.duel_incomplet', {
          'archetype': nomArchetype,
          'adversaire': g.archetype(g.distribution.duelDe(id)?.adversaire(id) ?? '')?.nom ?? '',
        }),
      TypeProbleme.familleManquante => t.t('distribution.famille_manquante', {
          'famille': famille(p.famille!),
          'pourquoi': g.famille(p.famille!).pourquoi,
        }).trim(),
    };
  }

  static String _minusculeInitiale(String s) =>
      s.isEmpty ? s : s[0].toLowerCase() + s.substring(1);
}

/// Combien d'archétypes de la [famille] (de la couleur) compte la
/// distribution, l'alarmiste compris.
int compterFamille(Grammaire g, Iterable<String> ids, FamilleId famille) =>
    ids.where((id) => g.archetype(id)?.famille == famille).length;

/// Les couleurs absentes d'une distribution.
List<FamilleId> couleursManquantes(Grammaire g, Iterable<String> ids) =>
    [for (final f in FamilleId.values) if (compterFamille(g, ids, f) == 0) f];

/// Les trois couleurs sont exigées à partir de trois joueurs : à deux, un
/// seul duel, deux couleurs au plus.
bool couleursExigees(int joueurs) => joueurs >= 3;

/// Les couleurs qui manquent à [ids], si elles sont exigées pour ce nombre de
/// joueurs.
List<FamilleId> _manquantes(Grammaire g, List<String> ids) =>
    couleursExigees(ids.length) ? couleursManquantes(g, ids) : const [];

/// Les archétypes de la distribution qui jouent sans leur adversaire.
List<String> archetypesSeuls(Grammaire g, List<String> ids) => [
      for (final id in ids)
        if (g.archetype(id) != null && !(g.distribution.duelDe(id)?.completDans(ids) ?? false)) id,
    ];

/// Vérifie une distribution d'archétypes (un par joueur) : des duels
/// complets (`par_nombre`), et toujours les trois couleurs.
VerdictDistribution validerDistribution(
  Grammaire g,
  List<String> ids, {
  ModeDistribution mode = ModeDistribution.spectacle,
}) {
  final problemes = _problemes(g, ids, mode);
  if (problemes.isEmpty) return const VerdictDistribution([], null);
  if (problemes.first.type == TypeProbleme.nombre) return VerdictDistribution(problemes, null);
  return VerdictDistribution(problemes, _proposerCorrection(g, ids, problemes.length, mode));
}

List<ProblemeDistribution> _problemes(Grammaire g, List<String> ids, ModeDistribution mode) {
  final compo = g.distribution.pour(ids.length);
  if (compo == null) return const [ProblemeDistribution(TypeProbleme.nombre)];
  final problemes = <ProblemeDistribution>[];
  final vus = <String>{};
  for (final id in ids) {
    if (g.archetype(id) == null) {
      problemes.add(ProblemeDistribution(TypeProbleme.inconnu, archetypeId: id));
    } else if (!vus.add(id)) {
      problemes.add(ProblemeDistribution(TypeProbleme.doublon, archetypeId: id));
    }
  }
  if (mode == ModeDistribution.serie && !ids.contains(Grammaire.alarmisteId)) {
    problemes.add(const ProblemeDistribution(TypeProbleme.sansAlarmiste));
  }
  final seuls = archetypesSeuls(g, ids.toSet().toList());
  final enTrop = seuls.length - compo.seuls;
  for (final id in seuls.take(enTrop < 0 ? 0 : enTrop)) {
    problemes.add(ProblemeDistribution(TypeProbleme.duelIncomplet, archetypeId: id));
  }
  for (final f in _manquantes(g, ids)) {
    problemes.add(ProblemeDistribution(TypeProbleme.familleManquante, famille: f));
  }
  return problemes;
}

/// Cherche le plus petit changement qui règle le plus de problèmes : un
/// remplacement, sinon un duel changé pour un autre.
CorrectionDistribution? _proposerCorrection(
    Grammaire g, List<String> ids, int avant, ModeDistribution mode) {
  int compter(List<String> essai) => _problemes(g, essai, mode).length;
  final tous = [for (final a in g.archetypes) a.id];
  CorrectionDistribution? meilleure;
  var score = avant;
  for (var i = ids.length - 1; i >= 0; i--) {
    for (final id in tous) {
      if (ids.contains(id)) continue;
      final n = compter([...ids]..[i] = id);
      if (n < score) {
        score = n;
        meilleure = CorrectionDistribution(index: i, ancienId: ids[i], nouveauId: id);
      }
    }
  }
  if (meilleure != null && score == 0) return meilleure;
  // Changer tout un duel : les deux qui le forment deviennent un autre duel.
  for (final present in g.distribution.duels) {
    final i = ids.indexOf(present.premier), j = ids.indexOf(present.second);
    if (i < 0 || j < 0) continue;
    for (final autre in g.distribution.duels) {
      if (autre.premier == present.premier || ids.contains(autre.premier) || ids.contains(autre.second)) continue;
      final essai = [...ids]
        ..[i] = autre.premier
        ..[j] = autre.second;
      final n = compter(essai);
      if (n < score) {
        score = n;
        meilleure = CorrectionDistribution(
          index: i,
          ancienId: present.premier,
          nouveauId: autre.premier,
          autres: [CorrectionDistribution(index: j, ancienId: present.second, nouveauId: autre.second)],
        );
      }
    }
  }
  return meilleure;
}

/// Tire une distribution par duels, au hasard (`par_nombre`) :
/// 1. le nombre de duels voulu, parmi les quatre ;
/// 2. à 3 et 5 joueurs, l'archétype seul vient des duels restants, et
///    complète la couleur qui manque s'il y en a une ;
/// 3. un tirage où une couleur manque est refusé, et on retire : les trois
///    couleurs sont toujours sur scène (à 3, jamais le duel
///    Alarmiste-Dénégateur, tout bleu) ;
/// 4. l'ordre est mélangé : les archétypes sont répartis au hasard entre les
///    joueurs.
/// Les archétypes [imposes] (et l'alarmiste en jeu de rôle) sont gardés : on retire tant qu'ils ne sont pas dans le tirage.
List<String> tirerDistribution(
  Grammaire g,
  int joueurs, {
  Random? hasard,
  List<String> imposes = const [],
  ModeDistribution mode = ModeDistribution.spectacle,
}) {
  final rng = hasard ?? Random();
  final compo = g.distribution.pour(joueurs);
  if (compo == null) {
    throw ArgumentError.value(joueurs, 'joueurs', 'Destiny se joue de 2 à 6.');
  }
  final requis = <String>{
    if (mode == ModeDistribution.serie) Grammaire.alarmisteId,
    for (final id in imposes)
      if (g.archetype(id) != null) id,
  };
  // Les requis qu'aucun tirage ne peut tenir ensemble sont lâchés, du
  // dernier au premier, plutôt que de boucler sans fin.
  final gardes = [...requis];
  while (gardes.isNotEmpty && !_possible(g, compo, gardes)) {
    gardes.removeLast();
  }
  for (;;) {
    final tirage = _unTirage(g, compo, rng);
    if (tirage == null) continue;
    if (!gardes.every(tirage.contains)) continue;
    return tirage..shuffle(rng);
  }
}

/// Un tirage brut (null : refusé, une couleur manque).
List<String>? _unTirage(Grammaire g, CompositionDistribution compo, Random rng) {
  final duels = [...g.distribution.duels]..shuffle(rng);
  final pris = duels.take(compo.duels).toList();
  final ids = [for (final d in pris) ...d.archetypes];
  if (compo.seuls > 0) {
    final restants = [for (final d in duels.skip(compo.duels)) ...d.archetypes];
    final manque = couleursManquantes(g, ids);
    final candidats = manque.isEmpty
        ? restants
        : [for (final id in restants) if (manque.contains(g.archetype(id)!.famille)) id];
    if (candidats.isEmpty) return null;
    for (var i = 0; i < compo.seuls; i++) {
      final libres = candidats.where((id) => !ids.contains(id)).toList();
      if (libres.isEmpty) return null;
      ids.add(libres[rng.nextInt(libres.length)]);
    }
  }
  if (_manquantes(g, ids).isNotEmpty) return null;
  return ids;
}

/// Un tirage peut-il contenir tous les [requis] ?
bool _possible(Grammaire g, CompositionDistribution compo, List<String> requis) {
  final duels = g.distribution.duels;
  Iterable<List<Duel>> combinaisons(int k, [int depuis = 0]) sync* {
    if (k == 0) {
      yield const [];
      return;
    }
    for (var i = depuis; i <= duels.length - k; i++) {
      for (final suite in combinaisons(k - 1, i + 1)) {
        yield [duels[i], ...suite];
      }
    }
  }

  for (final pris in combinaisons(compo.duels)) {
    final ids = [for (final d in pris) ...d.archetypes];
    final restants = [
      for (final d in duels)
        if (!pris.contains(d)) ...d.archetypes,
    ];
    final manque = couleursManquantes(g, ids);
    final seuls = compo.seuls == 0
        ? [<String>[]]
        : [
            for (final id in restants)
              if (manque.isEmpty || manque.contains(g.archetype(id)!.famille)) [id],
          ];
    for (final s in seuls) {
      final tirage = [...ids, ...s];
      if (_manquantes(g, tirage).isNotEmpty) continue;
      if (requis.every(tirage.contains)) return true;
    }
  }
  return false;
}

/// Les exemples tout prêts pour [joueurs] joueurs.
List<List<String>> exemplesDistribution(Grammaire g, int joueurs) => [
      for (final e in g.distribution.exemples) e.pour(joueurs, accepte: (ids) => _manquantes(g, ids).isEmpty),
    ];

/// Tire un animal parmi les trois de l'archétype.
String tirerAnimal(Grammaire g, String archetypeId, {Random? hasard}) {
  final animaux = g.animauxDe(archetypeId);
  if (animaux.isEmpty) return '';
  return animaux[(hasard ?? Random()).nextInt(animaux.length)].id;
}
