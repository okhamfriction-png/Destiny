import 'package:flutter/material.dart';

import '../../application/state/visual_settings.dart';
import '../../domain/grammaire/modeles.dart';
import '../theme/destiny_theme.dart';
import 'composants.dart';
import 'donnees.dart';

/// Les trois variantes de la carte d'archétype.
enum VarianteCarte { archetype, animal, kids }

/// La carte d'archétype, d'après les cartes imprimées de la troupe.
///
/// - [CarteArchetype.archetype] : l'archétype, ses deux animaux et sa montée ;
/// - [CarteArchetype.animal] : un animal avec sa réplique ;
/// - [CarteArchetype.kids] : un animal avec sa réplique kids.
///
/// La source d'une réplique ne s'affiche jamais sur une carte.
class CarteArchetype extends StatelessWidget {
  const CarteArchetype.archetype(
    this.archetypeId, {
    super.key,
    this.courant,
    this.source = VisualSource.ai,
    this.largeur = 340,
  })  : variante = VarianteCarte.archetype,
        animalId = null;

  const CarteArchetype.animal(
    String this.animalId, {
    super.key,
    this.courant,
    this.source = VisualSource.ai,
    this.largeur = 340,
  })  : variante = VarianteCarte.animal,
        archetypeId = '';

  const CarteArchetype.kids(
    String this.animalId, {
    super.key,
    this.courant,
    this.source = VisualSource.ai,
    this.largeur = 340,
  })  : variante = VarianteCarte.kids,
        archetypeId = '';

  final VarianteCarte variante;
  final String archetypeId;
  final String? animalId;

  /// Palier en cours (mis en avant dans la montée).
  final PalierId? courant;
  final VisualSource source;
  final double largeur;

  @override
  Widget build(BuildContext context) {
    final g = context.grammaire;
    final c = context.destiny;
    final animal = animalId == null ? null : g.animal(animalId!);
    final archetype = animal != null ? g.archetype(animal.archetypeId) : g.archetype(archetypeId);
    if (archetype == null) return const SizedBox.shrink();
    final couleur = c.famille(archetype.famille);
    final kids = variante == VarianteCarte.kids;

    return Semantics(
      container: true,
      label: animal == null ? archetype.nom : '${archetype.nom}, ${animal.nom}',
      child: Container(
        width: largeur,
        decoration: BoxDecoration(
          color: c.carte,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: couleur, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: c.sombre ? 0.45 : 0.08),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _Entete(archetype: archetype, animal: animal, couleur: couleur, kids: kids),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(
                  archetype.ceQuIlFait,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: kPoliceTexte, fontSize: 14.5, height: 1.4, color: c.texte),
                ),
                const SizedBox(height: 12),
                if (animal == null)
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    for (final a in g.animauxDe(archetype.id))
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: _TuileAnimal(animal: a, couleur: couleur, source: source),
                        ),
                      ),
                  ])
                else
                  _AnimalSeul(animal: animal, couleur: couleur, source: source, kids: kids),
                const SizedBox(height: 12),
                _Montee(archetype: archetype, couleur: couleur, courant: courant),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Entete extends StatelessWidget {
  const _Entete({required this.archetype, required this.animal, required this.couleur, required this.kids});

  final Archetype archetype;
  final Animal? animal;
  final Color couleur;
  final bool kids;

  @override
  Widget build(BuildContext context) {
    final c = context.destiny;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      decoration: BoxDecoration(
        color: c.sombre ? Color.lerp(c.nuit, couleur, 0.18) : c.familleClaire(archetype.famille),
        border: Border(bottom: BorderSide(color: c.or.withValues(alpha: 0.6))),
      ),
      child: Stack(alignment: Alignment.topCenter, children: [
        Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
          const SizedBox(width: double.infinity),
          Text(
            archetype.nom.toUpperCase(),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: kPoliceTitres,
              fontWeight: FontWeight.w900,
              fontSize: 22,
              letterSpacing: 1.6,
              color: c.sombre ? c.or : c.orFonce,
            ),
          ),
          if (animal != null)
            Text(
              animal!.nom,
              style: TextStyle(
                fontFamily: kPoliceTexte,
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: c.texte,
              ),
            ),
          const SizedBox(height: 6),
          PuceFamille(archetype.famille, compacte: true),
        ]),
        if (kids) const Positioned(top: 0, right: 0, child: SigleKids(petit: true)),
      ]),
    );
  }
}

class _TuileAnimal extends StatelessWidget {
  const _TuileAnimal({required this.animal, required this.couleur, required this.source});

  final Animal animal;
  final Color couleur;
  final VisualSource source;

  @override
  Widget build(BuildContext context) {
    final c = context.destiny;
    return Column(children: [
      MedaillonAnimal(animal, taille: 58, source: source),
      const SizedBox(height: 4),
      Text(
        animal.nom,
        style: TextStyle(fontFamily: kPoliceTexte, fontWeight: FontWeight.w700, fontSize: 15, color: c.texte),
      ),
      Text(
        '${context.textes.t('cartes.port')} ${animal.port}',
        textAlign: TextAlign.center,
        style: TextStyle(fontFamily: kPoliceTexte, fontStyle: FontStyle.italic, fontSize: 12.5, color: c.texteSecondaire),
      ),
      const SizedBox(height: 3),
      PastilleStatut(animal.statutDepart),
      const SizedBox(height: 6),
      EncartReplique(animal.replique, couleur: couleur, taille: 12.5),
    ]);
  }
}

class _AnimalSeul extends StatelessWidget {
  const _AnimalSeul({required this.animal, required this.couleur, required this.source, required this.kids});

  final Animal animal;
  final Color couleur;
  final VisualSource source;
  final bool kids;

  @override
  Widget build(BuildContext context) {
    final c = context.destiny;
    return Column(children: [
      MedaillonAnimal(animal, taille: 92, source: source),
      const SizedBox(height: 8),
      Text(
        animal.posture,
        textAlign: TextAlign.center,
        style: TextStyle(fontFamily: kPoliceTexte, fontSize: 14, height: 1.35, color: c.texteSecondaire),
      ),
      const SizedBox(height: 6),
      Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 4,
        children: [
          Text(
            '${context.textes.t('cartes.port')} ${animal.port}',
            style: TextStyle(fontFamily: kPoliceTexte, fontStyle: FontStyle.italic, fontSize: 13, color: c.texteSecondaire),
          ),
          PastilleStatut(animal.statutDepart),
        ],
      ),
      const SizedBox(height: 10),
      EncartReplique(animal.repliquePour(kids: kids), couleur: couleur, taille: 15),
    ]);
  }
}

class _Montee extends StatelessWidget {
  const _Montee({required this.archetype, required this.couleur, required this.courant});

  final Archetype archetype;
  final Color couleur;
  final PalierId? courant;

  @override
  Widget build(BuildContext context) {
    final c = context.destiny;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(
        context.textes.t('cartes.montee').toUpperCase(),
        style: TextStyle(
          fontFamily: kPoliceTexte,
          fontSize: 12.5,
          letterSpacing: 1.1,
          fontWeight: FontWeight.w700,
          color: c.titre,
        ),
      ),
      const SizedBox(height: 6),
      for (final p in PalierId.values)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 20,
              height: 20,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: courant == p ? couleur : c.palier(p).withValues(alpha: 0.22),
              ),
              child: Text(
                '${p.numero}',
                style: TextStyle(
                  fontFamily: kPoliceTexte,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                  color: courant == p ? Colors.white : c.texte,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                archetype.monteeA(p),
                style: TextStyle(
                  fontFamily: kPoliceTexte,
                  fontSize: 13.5,
                  height: 1.35,
                  fontWeight: courant == p ? FontWeight.w700 : FontWeight.w400,
                  color: c.texte,
                ),
              ),
            ),
          ]),
        ),
    ]);
  }
}

/// Le dos d'une carte : le cube Destiny (le logo) et la promesse, dans un
/// contour épais de la couleur de la famille.
class DosCarte extends StatelessWidget {
  const DosCarte({super.key, required this.famille, this.largeur = 340, this.hauteur = 480});

  final FamilleId famille;
  final double largeur;
  final double hauteur;

  @override
  Widget build(BuildContext context) {
    final c = context.destiny;
    final g = context.grammaire;
    return Container(
      width: largeur,
      height: hauteur,
      decoration: BoxDecoration(
        color: c.nuit,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.famille(famille), width: 10),
      ),
      child: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: c.or.withValues(alpha: 0.7)),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Image.asset(
            'assets/images/destiny_cube.png',
            width: largeur * 0.42,
            errorBuilder: (_, __, ___) => Icon(Icons.flash_on_rounded, size: largeur * 0.3, color: c.or),
          ),
          const SizedBox(height: 18),
          Text(
            g.nom.toUpperCase(),
            style: TextStyle(
              fontFamily: kPoliceTitres,
              fontWeight: FontWeight.w900,
              fontSize: 26,
              letterSpacing: 4,
              color: c.or,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            g.promesse,
            style: TextStyle(
              fontFamily: kPoliceTitres,
              fontWeight: FontWeight.w700,
              fontSize: 15,
              letterSpacing: 1,
              color: c.orClair,
            ),
          ),
        ]),
      ),
    );
  }
}
