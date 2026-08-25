import 'dart:math';

import '../entities/campagne.dart';

/// Composition d'un épisode et calcul des horaires de l'escalade.
///
/// Rien n'est tiré au hasard complet : le hasard rendrait l'histoire
/// incohérente d'un épisode à l'autre. Le méchant est stable (il revient), le
/// lieu change (c'est ce qui fait avancer), et les tirages sont déterministes
/// par épisode — rouvrir un épisode montre la même composition.

/// L'escalade : une marche par présage. Les DEUX dernières sont pour le
/// méchant, quel que soit le nombre de présages ; les précédentes sont pour
/// les sbires, à tour de rôle. Sans sbire, tout est du méchant.
List<Escalade> orchestrer(MechantHistoire mechant) {
  final presages = mechant.presages;
  final n = presages.length;
  final result = <Escalade>[];
  var sbireIdx = 0;
  for (var i = 0; i < n; i++) {
    final estMechant = i >= n - 2 || mechant.sbires.isEmpty;
    if (estMechant) {
      final man = mechant.manoeuvres.isEmpty
          ? ''
          : mechant.manoeuvres[i % mechant.manoeuvres.length];
      result.add(Escalade(
        rang: i + 1,
        quiAgit: mechant.nom,
        ceQuilFait: man,
        ceQueCaProduit: presages[i],
        estMechant: true,
      ));
    } else {
      final s = mechant.sbires[sbireIdx % mechant.sbires.length];
      sbireIdx++;
      final man = s.manoeuvres.isEmpty ? '' : s.manoeuvres[i % s.manoeuvres.length];
      result.add(Escalade(
        rang: i + 1,
        quiAgit: s.nom,
        ceQuilFait: man,
        ceQueCaProduit: presages[i],
        estMechant: false,
      ));
    }
  }
  return result;
}

/// Horaires (ms écoulées) par défaut des présages dans un épisode de [dureeMs].
///
/// Avec un [intervalleMs] imposé : intervalle × rang. Sinon, des écarts égaux
/// en minutes entières : pas = floor((durée_min − 1) / nombre). Douze minutes
/// et quatre présages donnent 2, 4, 6, 8 — ce qui se lit sur un curseur et se
/// retient en jouant. Épisode trop court pour des minutes entières : répartition
/// fine en millisecondes. Puis [borner].
List<int> horairesDesPresages(int dureeMs, int nombre, {int? intervalleMs}) {
  if (nombre <= 0) return const [];
  final horaires = <int>[];
  if (intervalleMs != null && intervalleMs > 0) {
    for (var i = 0; i < nombre; i++) {
      horaires.add(intervalleMs * (i + 1));
    }
  } else {
    final dureeMin = dureeMs ~/ 60000;
    final pas = dureeMin >= 2 ? ((dureeMin - 1) / nombre).floor() : 0;
    if (pas >= 1) {
      for (var i = 0; i < nombre; i++) {
        horaires.add(pas * (i + 1) * 60000);
      }
    } else {
      // Trop court pour des minutes entières : réparti finement en ms.
      for (var i = 0; i < nombre; i++) {
        horaires.add((dureeMs * (i + 1) / (nombre + 1)).round());
      }
    }
  }
  return borner(horaires, dureeMs);
}

/// Ramène des horaires dans l'épisode, ordonnés et distincts, avec un pas
/// minimal d'une minute (ou moins si l'épisode est trop court), en réservant
/// une place pour chacun des présages restants plus la fin.
///
/// Un présage qui ne tombe jamais est un bug qu'on découvre en jouant ; un
/// dernier danger au coup de sifflet ne se joue pas, il s'annonce.
List<int> borner(List<int> horaires, int dureeMs) {
  final n = horaires.length;
  if (n == 0) return const [];
  var pasMin = 60000; // une minute
  // Il faut loger n horaires + la fin : (n + 1) créneaux.
  if (dureeMs < pasMin * (n + 1)) {
    pasMin = (dureeMs / (n + 1)).floor();
    if (pasMin < 1) pasMin = 1;
  }
  final sorted = [...horaires]..sort();
  final result = <int>[];
  for (var i = 0; i < n; i++) {
    var h = sorted[i];
    final minH = result.isEmpty ? pasMin : result.last + pasMin;
    if (h < minH) h = minH;
    final presagesRestants = n - 1 - i; // ceux qui viennent après celui-ci
    final maxH = dureeMs - pasMin * (presagesRestants + 1);
    if (h > maxH) h = maxH;
    result.add(h);
  }
  return result;
}

/// Compose un épisode jouable à partir du catalogue de l'univers.
/// Rend null si l'univers n'a ni lieu ni méchant.
class ConstructeurEpisode {
  const ConstructeurEpisode();

  Episode? construire({
    required Campagne campagne,
    required int numero,
    required List<String> joueurs,
    required List<LieuHistoire> lieux,
    required List<MechantHistoire> mechants,
    required List<ArchetypeHistoire> archetypes,
    required List<String> objectifs,
  }) {
    if (lieux.isEmpty || mechants.isEmpty || archetypes.isEmpty) return null;

    // Déterministe par épisode (le lieu, les rôles joueurs) …
    final rng = Random(campagne.id * 100003 + numero);
    // … et STABLE sur toute la campagne (figurants, méchant) : à l'épisode 2 on
    // retrouve exactement les mêmes figurants et le même danger qu'à l'épisode 1.
    final rngStable = Random(campagne.id * 100003);

    final mechant = mechants[campagne.id % mechants.length];
    final lieu = lieux[(campagne.id + numero) % lieux.length];

    final roles = [...lieu.roles]..shuffle(rng);

    // Figurants stables : identité (archétype / objectif / visage) tirée sur la
    // campagne, pas sur l'épisode. Leur rôle s'adapte au lieu du moment.
    final animauxStable = [...archetypes]..shuffle(rngStable);
    final objs = [...objectifs]..shuffle(rngStable);
    final figurants = <Figurant>[
      for (var f = 0; f < 2; f++)
        Figurant(
          role: (joueurs.length + f) < roles.length
              ? roles[joueurs.length + f]
              : 'quelqu\'un du coin',
          archetype: animauxStable[f % animauxStable.length],
          objectif: objs[f % objs.length],
          visage: f,
        ),
    ];
    final idsFigurants = {for (final fg in figurants) fg.archetype.id};

    // Archétypes des joueurs : parité des statuts (haut / bas / neutre), sans
    // jamais reprendre l'archétype d'un figurant.
    final dispo =
        archetypes.where((a) => !idsFigurants.contains(a.id)).toList();
    final animauxJoueurs = _pickAvecParite(dispo, joueurs.length, rng);
    final rolesJoueurs = <RoleJoueur>[
      for (var i = 0; i < joueurs.length; i++)
        RoleJoueur(
          joueur: joueurs[i],
          role: i < roles.length ? roles[i] : 'quelqu\'un du coin',
          archetype: animauxJoueurs[i % animauxJoueurs.length],
        ),
    ];

    return Episode(
      numero: numero,
      lieu: lieu,
      mechant: mechant,
      roles: rolesJoueurs,
      figurants: figurants,
      escalade: orchestrer(mechant),
    );
  }

  /// Tire [count] archétypes en garantissant, si possible, un mélange de statuts
  /// (au moins un haut, un bas, un neutre dès 3 joueurs).
  List<ArchetypeHistoire> _pickAvecParite(
      List<ArchetypeHistoire> dispo, int count, Random rng) {
    final byStatut = <String, List<ArchetypeHistoire>>{};
    for (final a in dispo) {
      (byStatut[a.statut] ??= <ArchetypeHistoire>[]).add(a);
    }
    if (count <= 1 || byStatut.length < 2) {
      return ([...dispo]..shuffle(rng)).take(count).toList();
    }
    final chosen = <ArchetypeHistoire>[];
    final ids = <String>{};
    for (final s in const ['haut', 'bas', 'neutre']) {
      if (chosen.length >= count) break;
      final pool = (byStatut[s] ?? const <ArchetypeHistoire>[])
          .where((a) => !ids.contains(a.id))
          .toList()
        ..shuffle(rng);
      if (pool.isEmpty) continue;
      chosen.add(pool.first);
      ids.add(pool.first.id);
    }
    final rest = dispo.where((a) => !ids.contains(a.id)).toList()..shuffle(rng);
    chosen.addAll(rest.take(count - chosen.length));
    chosen.shuffle(rng);
    return chosen.take(count).toList();
  }
}
