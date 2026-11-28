import 'modeles.dart';

/// Où en est une histoire : l'acte (1 à 4) et le nombre de DESTINY passés.
/// Chaque DESTINY fait passer à l'acte suivant et monter le danger d'un
/// niveau ; l'acte 1 se joue sans danger. Jamais plus loin que l'acte 4,
/// jamais en arrière.
class Progression {
  const Progression._(this.acte);

  /// Le début de l'histoire : acte 1, sans danger.
  const Progression.depart() : this._(1);

  /// Reprend une progression à l'acte [acte].
  factory Progression.aLActe(int acte) => Progression._(acte.clamp(1, kNombreActes));

  /// L'acte en cours (1 à 4).
  final int acte;

  /// Le niveau du danger (null à l'acte 1).
  PalierId? get palier => PalierId.pourActe(acte);

  /// Nombre de rituels DESTINY déjà passés (0 à 3).
  int get destinys => acte - 1;

  /// Le dernier acte est atteint : plus de DESTINY possible.
  bool get dernierActe => acte >= kNombreActes;

  bool get peutLancerDestiny => !dernierActe;

  /// Après le rituel DESTINY : l'acte suivant. Sans effet au dernier acte.
  Progression apresDestiny() => dernierActe ? this : Progression._(acte + 1);

  @override
  bool operator ==(Object other) => other is Progression && other.acte == acte;

  @override
  int get hashCode => acte.hashCode;
}

/// Les rappels de la régie à un moment de l'histoire, tirés du tableau
/// « acte par acte » (Dire, Fixer, Bloquer, Nommer, Choisir).
GesteActe? gestePourActe(Grammaire g, int acte) {
  final gestes = g.personnage.acteParActe;
  // Ordre du fichier : Acte 1, Destiny 1, Acte 2, Acte 3, Acte 4.
  final cible = Grammaire.normaliser('Acte $acte');
  for (final geste in gestes) {
    if (Grammaire.normaliser(geste.moment) == cible) return geste;
  }
  return null;
}

/// Le geste du premier figé (« Fixer »).
GesteActe? gestePremierFige(Grammaire g) {
  for (final geste in g.personnage.acteParActe) {
    if (Grammaire.normaliser(geste.moment).startsWith('destiny')) return geste;
  }
  return null;
}

/// Ce que doit montrer chaque personnage à ce palier : la montée de son
/// archétype (ce qu'il fait) et le corps de son animal (comment il le fait).
class MonteeAttendue {
  const MonteeAttendue({
    required this.archetype,
    required this.animal,
    required this.palier,
  });

  final Archetype archetype;
  final Animal? animal;
  final PalierId palier;

  String get ceQuIlFait => archetype.monteeA(palier);
  String get corps => animal?.corpsA(palier) ?? '';
}

MonteeAttendue? monteeAttendue(
  Grammaire g, {
  required String archetypeId,
  String? animalId,
  required PalierId palier,
}) {
  final a = g.archetype(archetypeId);
  if (a == null) return null;
  return MonteeAttendue(
    archetype: a,
    animal: animalId == null ? null : g.animal(animalId),
    palier: palier,
  );
}
