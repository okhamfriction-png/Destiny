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
  familleManquante,
  familleInsuffisante,
  leaderDemande,
}

class ProblemeDistribution {
  const ProblemeDistribution(this.type,
      {this.archetypeId, this.famille, this.joueurs = 0, this.minimum = 0});

  final TypeProbleme type;
  final String? archetypeId;
  final FamilleId? famille;

  /// Nombre de joueurs et minimum attendu (pour « famille insuffisante »).
  final int joueurs;
  final int minimum;
}

/// Une correction proposée : remplacer l'archétype à [index] (ou en ajouter
/// un si [index] vaut null) par [nouveauId].
class CorrectionDistribution {
  const CorrectionDistribution({this.index, this.ancienId, required this.nouveauId});

  final int? index;
  final String? ancienId;
  final String nouveauId;

  /// Applique la correction à une distribution.
  List<String> appliquer(List<String> ids) {
    final copie = [...ids];
    if (index == null) {
      copie.add(nouveauId);
    } else {
      copie[index!] = nouveauId;
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
    final nouveau = g.archetype(c.nouveauId)?.nom ?? c.nouveauId;
    if (c.ancienId == null) {
      return t.t('distribution.correction_ajout', {'nouveau': nouveau});
    }
    return t.t('distribution.correction', {
      'ancien': g.archetype(c.ancienId!)?.nom ?? c.ancienId!,
      'nouveau': nouveau,
    });
  }

  static String message(ProblemeDistribution p, Grammaire g, TextesDestiny t) {
    String famille(FamilleId f) => _minusculeInitiale(g.famille(f).nom);
    final nomArchetype = g.archetype(p.archetypeId ?? '')?.nom ?? p.archetypeId ?? '';
    return switch (p.type) {
      TypeProbleme.nombre => t.t('distribution.nombre'),
      TypeProbleme.inconnu => t.t('distribution.inconnu', {'archetype': nomArchetype}),
      TypeProbleme.doublon => t.t('distribution.doublon', {'archetype': nomArchetype}),
      TypeProbleme.sansAlarmiste => t.t('distribution.sans_alarmiste'),
      TypeProbleme.familleManquante => t.t('distribution.famille_manquante', {
          'famille': famille(p.famille!),
          'pourquoi': g.famille(p.famille!).pourquoi,
        }).trim(),
      TypeProbleme.familleInsuffisante => t.t('distribution.famille_insuffisante', {
          'famille': famille(p.famille!),
          'joueurs': '${p.joueurs}',
          'minimum': '${p.minimum}',
        }),
      TypeProbleme.leaderDemande => t.t('distribution.leader_demande'),
    };
  }

  static String _minusculeInitiale(String s) =>
      s.isEmpty ? s : s[0].toLowerCase() + s.substring(1);
}

/// Combien d'archétypes de la [famille] compte la distribution (l'alarmiste
/// n'est pas compté avec les autres « interprète le danger »).
int compterFamille(Grammaire g, List<String> ids, FamilleId famille) => ids
    .where((id) => id != Grammaire.alarmisteId && g.archetype(id)?.famille == famille)
    .length;

/// Vérifie une distribution d'archétypes (un par joueur).
VerdictDistribution validerDistribution(
  Grammaire g,
  List<String> ids, {
  bool leaderObligatoire = false,
  ModeDistribution mode = ModeDistribution.spectacle,
}) {
  final alarmisteObligatoire = mode == ModeDistribution.serie;
  final problemes = <ProblemeDistribution>[];
  final compo = g.distribution.pour(ids.length);
  if (compo == null) {
    return const VerdictDistribution(
        [ProblemeDistribution(TypeProbleme.nombre)], null);
  }
  final vus = <String>{};
  for (final id in ids) {
    if (g.archetype(id) == null) {
      problemes.add(ProblemeDistribution(TypeProbleme.inconnu, archetypeId: id));
    } else if (!vus.add(id)) {
      problemes.add(ProblemeDistribution(TypeProbleme.doublon, archetypeId: id));
    }
  }
  if (alarmisteObligatoire && !ids.contains(Grammaire.alarmisteId)) {
    problemes.add(const ProblemeDistribution(TypeProbleme.sansAlarmiste));
  }
  for (final f in FamilleId.values) {
    final n = compterFamille(g, ids, f);
    final min = compo.minimumPour(f);
    if (n == 0 && min > 0) {
      problemes.add(ProblemeDistribution(TypeProbleme.familleManquante, famille: f));
    } else if (n < min) {
      problemes.add(ProblemeDistribution(TypeProbleme.familleInsuffisante,
          famille: f, joueurs: ids.length, minimum: min));
    }
  }
  if (leaderObligatoire && !ids.contains(Grammaire.leaderId)) {
    problemes.add(const ProblemeDistribution(TypeProbleme.leaderDemande));
  }
  if (problemes.isEmpty) return const VerdictDistribution([], null);
  return VerdictDistribution(
      problemes, _proposerCorrection(g, ids, compo, problemes.first, leaderObligatoire, alarmisteObligatoire));
}

/// Cherche un seul remplacement qui règle le premier problème.
CorrectionDistribution? _proposerCorrection(
  Grammaire g,
  List<String> ids,
  CompositionDistribution compo,
  ProblemeDistribution p,
  bool leaderObligatoire,
  bool alarmisteObligatoire,
) {
  // L'archétype à faire entrer.
  String? entrant;
  switch (p.type) {
    case TypeProbleme.sansAlarmiste:
      entrant = Grammaire.alarmisteId;
    case TypeProbleme.leaderDemande:
      entrant = Grammaire.leaderId;
    case TypeProbleme.familleManquante:
    case TypeProbleme.familleInsuffisante:
      entrant = g
          .archetypesDe(p.famille!)
          .map((a) => a.id)
          .where((id) => id != Grammaire.alarmisteId && !ids.contains(id))
          .firstOrNull;
    case TypeProbleme.doublon:
    case TypeProbleme.inconnu:
      // On remplace l'intrus par un archétype d'une famille en manque, sinon
      // par le premier archétype libre.
      final index = p.type == TypeProbleme.doublon
          ? ids.lastIndexOf(p.archetypeId!)
          : ids.indexOf(p.archetypeId!);
      final reste = [...ids]..removeAt(index);
      final manque = FamilleId.values.where(
          (f) => compterFamille(g, reste, f) < compo.minimumPour(f));
      final candidats = [
        if (alarmisteObligatoire && !reste.contains(Grammaire.alarmisteId)) Grammaire.alarmisteId,
        for (final f in manque) ...g.archetypesDe(f).map((a) => a.id),
        ...g.archetypes.map((a) => a.id),
      ].where((id) => !reste.contains(id));
      final nouveau = candidats.firstOrNull;
      return nouveau == null
          ? null
          : CorrectionDistribution(index: index, ancienId: ids[index], nouveauId: nouveau);
    case TypeProbleme.nombre:
      return null;
  }
  if (entrant == null) return null;
  // Le joueur à changer : celui dont le départ ne crée pas de nouveau manque.
  for (var i = ids.length - 1; i >= 0; i--) {
    final ancien = ids[i];
    if (alarmisteObligatoire && ancien == Grammaire.alarmisteId) continue;
    if (leaderObligatoire && ancien == Grammaire.leaderId) continue;
    final essai = [...ids]..[i] = entrant;
    final avant = _compterProblemes(g, ids, leaderObligatoire, alarmisteObligatoire);
    final apres = _compterProblemes(g, essai, leaderObligatoire, alarmisteObligatoire);
    if (apres < avant) {
      return CorrectionDistribution(index: i, ancienId: ancien, nouveauId: entrant);
    }
  }
  return null;
}

int _compterProblemes(Grammaire g, List<String> ids, bool leaderObligatoire, bool alarmisteObligatoire) {
  final compo = g.distribution.pour(ids.length);
  if (compo == null) return 1;
  var n = 0;
  final vus = <String>{};
  for (final id in ids) {
    if (g.archetype(id) == null || !vus.add(id)) n++;
  }
  if (alarmisteObligatoire && !ids.contains(Grammaire.alarmisteId)) n++;
  for (final f in FamilleId.values) {
    if (compterFamille(g, ids, f) < compo.minimumPour(f)) n++;
  }
  if (leaderObligatoire && !ids.contains(Grammaire.leaderId)) n++;
  return n;
}

/// Tire une distribution équilibrée pour [joueurs] joueurs. Les archétypes
/// [imposes] sont gardés ; le reste est tiré pour que chaque famille soit
/// représentée. En jeu de rôle, l'alarmiste est toujours tiré ; au
/// spectacle, il n'a pas de place réservée (il peut venir en plus). L'ordre
/// final est mélangé.
List<String> tirerDistribution(
  Grammaire g,
  int joueurs, {
  Random? hasard,
  List<String> imposes = const [],
  bool leaderObligatoire = false,
  ModeDistribution mode = ModeDistribution.spectacle,
}) {
  final rng = hasard ?? Random();
  final compo = g.distribution.pour(joueurs);
  if (compo == null) {
    throw ArgumentError.value(joueurs, 'joueurs', 'Destiny se joue de 3 à 6.');
  }
  final choisis = <String>[];
  void ajouter(String id) {
    if (!choisis.contains(id) && choisis.length < joueurs && g.archetype(id) != null) {
      choisis.add(id);
    }
  }

  if (mode == ModeDistribution.serie) ajouter(Grammaire.alarmisteId);
  for (final id in imposes) {
    ajouter(id);
  }
  if (leaderObligatoire) ajouter(Grammaire.leaderId);

  for (final f in FamilleId.values) {
    final libres = g
        .archetypesDe(f)
        .map((a) => a.id)
        .where((id) => id != Grammaire.alarmisteId && !choisis.contains(id))
        .toList()
      ..shuffle(rng);
    var manque = compo.minimumPour(f) - compterFamille(g, choisis, f);
    for (final id in libres) {
      if (manque <= 0) break;
      ajouter(id);
      manque--;
    }
  }
  final restants = g.archetypes
      .map((a) => a.id)
      .where((id) => !choisis.contains(id))
      .toList()
    ..shuffle(rng);
  for (final id in restants) {
    if (choisis.length >= joueurs) break;
    ajouter(id);
  }
  return choisis..shuffle(rng);
}

/// Les exemples tout prêts pour [joueurs] joueurs. À 3, l'exemple à 4 perd
/// son archétype qui « interprète le danger » en plus de l'alarmiste : il
/// reste l'alarmiste, celui qui tient et celui qui se fissure.
List<List<String>> exemplesDistribution(Grammaire g, int joueurs) => [
      for (final e in g.distribution.exemples)
        if (joueurs == 3) _aTrois(g, e.aQuatre) else e.pour(joueurs),
    ];

List<String> _aTrois(Grammaire g, List<String> aQuatre) {
  final i = aQuatre.indexWhere(
      (id) => id != Grammaire.alarmisteId && g.archetype(id)?.famille == FamilleId.interprete);
  return [...aQuatre]..removeAt(i < 0 ? aQuatre.length - 1 : i);
}

/// Tire un animal parmi les deux de l'archétype.
String tirerAnimal(Grammaire g, String archetypeId, {Random? hasard}) {
  final animaux = g.animauxDe(archetypeId);
  if (animaux.isEmpty) return '';
  return animaux[(hasard ?? Random()).nextInt(animaux.length)].id;
}
