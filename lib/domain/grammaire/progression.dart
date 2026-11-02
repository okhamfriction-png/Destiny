import 'modeles.dart';

/// Où en est une histoire : le palier du danger, qui est aussi le numéro de
/// l'acte. Chaque Destiny fait monter d'un palier, jamais plus haut que 4,
/// jamais en arrière.
class Progression {
  const Progression._(this.palier, this.destinys);

  /// Le début de l'histoire : acte 1, le danger se signale.
  const Progression.depart() : this._(PalierId.signale, 0);

  /// Reprend une progression à un palier donné.
  factory Progression.auPalier(PalierId p) => Progression._(p, p.index);

  final PalierId palier;

  /// Nombre de rituels Destiny déjà passés (0 à 3).
  final int destinys;

  int get acte => palier.numero;

  /// Le dernier acte est atteint : plus de Destiny possible.
  bool get dernierActe => palier == PalierId.supprime;

  bool get peutLancerDestiny => !dernierActe;

  /// Le prochain Destiny est le premier : c'est pendant ce figé que chacun
  /// fixe sa phrase « il veut… mais il a besoin de… ».
  bool get prochainEstPremierFige => destinys == 0;

  /// Après le rituel Destiny : le palier suivant. Sans effet au dernier acte.
  Progression apresDestiny() => dernierActe
      ? this
      : Progression._(PalierId.values[palier.index + 1], destinys + 1);

  @override
  bool operator ==(Object other) =>
      other is Progression && other.palier == palier && other.destinys == destinys;

  @override
  int get hashCode => Object.hash(palier, destinys);
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
