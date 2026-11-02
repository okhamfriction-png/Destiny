import 'package:flutter/material.dart';

import '../../application/state/visual_settings.dart';
import '../../domain/grammaire/modeles.dart';
import '../destiny/cartes.dart';
import '../destiny/composants.dart';
import '../destiny/donnees.dart';
import '../destiny/page.dart';
import '../theme/destiny_theme.dart';

/// Une puce d'archétype à la couleur de sa famille.
class PuceArchetype extends StatelessWidget {
  const PuceArchetype(this.archetypeId, {super.key, this.suffixe, this.onTap});

  final String archetypeId;
  final String? suffixe;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final g = context.grammaire;
    final c = context.destiny;
    final a = g.archetype(archetypeId);
    if (a == null) return const SizedBox.shrink();
    final couleur = c.famille(a.famille);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(99),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: couleur.withValues(alpha: c.sombre ? 0.25 : 0.12),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: couleur),
        ),
        child: Text(
          suffixe == null ? a.nom : '${a.nom} · $suffixe',
          style: TextStyle(
            fontFamily: kPoliceTexte,
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: c.sombre ? Color.lerp(couleur, Colors.white, 0.55) : couleur,
          ),
        ),
      ),
    );
  }
}

/// Un exemple des six directions.
class CarteDirection extends StatelessWidget {
  const CarteDirection(this.d, {super.key});

  final Direction d;

  @override
  Widget build(BuildContext context) {
    final t = context.textes;
    final c = context.destiny;
    final g = context.grammaire;
    final a = g.archetype(d.archetypeId);
    String f(String k) => t.t('bibliotheque.fiche.$k');
    return CadreLisere(
      couleur: a == null ? c.or : c.famille(a.famille),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(d.personnage,
                style: TextStyle(fontFamily: kPoliceTexte, fontWeight: FontWeight.w700, fontSize: 16, color: c.texte)),
          ),
          Flexible(child: PuceArchetype(d.archetypeId)),
        ]),
        const SizedBox(height: 8),
        LigneInfo(f('acte1'), d.acte1Veut),
        LigneInfo(f('blessure'), d.acte1Blessure, italique: true),
        LigneInfo(f('acte2'), d.acte2),
        LigneInfo(f('acte3'), d.acte3, italique: true),
        LigneInfo(f('acte4'), d.acte4),
        LigneInfo(f('besoin'), d.besoin),
      ]),
    );
  }
}

/// La fiche jouable d'un personnage non joueur (figurant ou sbire) : la
/// carte de son animal, ce qu'il veut, d'où il vient, ce qu'il fait ou sait.
Future<void> ouvrirFicheJouable(
  BuildContext context, {
  required String nom,
  required String animalId,
  required ModePnj mode,
  String type = '',
  String veut = '',
  String vientDe = '',
  String fait = '',
  String sait = '',
  bool kids = false,
}) {
  final t = context.textes;
  final g = context.grammaire;
  String f(String k) => t.t('bibliotheque.fiche.$k');
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      builder: (ctx, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.all(16),
        children: [
          Text(nom,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontFamily: kPoliceTitres, fontWeight: FontWeight.w900, fontSize: 22, color: ctx.destiny.titre)),
          const SizedBox(height: 4),
          Center(
            child: Wrap(spacing: 6, children: [
              Chip(label: Text(t.t('modes_pnj.${mode.name}'))),
              if (type.isNotEmpty) Chip(label: Text(g.figurants.type(type)?.nom ?? type)),
              if (kids) const SigleKids(),
            ]),
          ),
          const SizedBox(height: 10),
          Center(
            child: kids
                ? CarteArchetype.kids(animalId, source: VisualSource.ai)
                : CarteArchetype.animal(animalId, source: VisualSource.ai),
          ),
          const SizedBox(height: 12),
          LigneInfo(f('veut'), veut),
          LigneInfo(f('vient_de'), vientDe),
          LigneInfo(f('fait'), fait),
          LigneInfo(f('sait'), sait),
          if (type.isNotEmpty) LigneInfo(f('comment_le_jouer'), g.figurants.type(type)?.commentLeJouer ?? ''),
        ],
      ),
    ),
  );
}

/// Un figurant prêt à jouer.
class CarteFigurant extends StatelessWidget {
  const CarteFigurant(this.f, {super.key});

  final FigurantPret f;

  @override
  Widget build(BuildContext context) {
    final g = context.grammaire;
    final c = context.destiny;
    final animal = g.animal(f.animalId);
    final type = g.figurants.type(f.type);
    return ElementListe(
      titre: f.nom,
      sousTitre: [if (type != null) type.nom, f.veut, f.sait].where((s) => s.isNotEmpty).join(' · '),
      couleur: c.famille(g.archetype(f.archetypeId)?.famille ?? FamilleId.tient),
      devant: animal == null ? null : MedaillonAnimal(animal, taille: 40),
      onTap: () => ouvrirFicheJouable(context,
          nom: f.nom,
          animalId: f.animalId,
          mode: f.mode,
          type: f.type,
          veut: f.veut,
          vientDe: f.vientDe,
          sait: f.sait),
    );
  }
}

/// Un sbire, en petit.
class CarteSbire extends StatelessWidget {
  const CarteSbire(this.s, {super.key});

  final Sbire s;

  @override
  Widget build(BuildContext context) {
    final g = context.grammaire;
    final c = context.destiny;
    final animal = g.animal(s.animalId);
    return ElementListe(
      titre: s.nom,
      sousTitre: s.veut,
      couleur: c.famille(g.archetype(s.archetypeId)?.famille ?? FamilleId.fissure),
      devant: animal == null ? null : MedaillonAnimal(animal, taille: 36),
      apres: s.kids ? const SigleKids(petit: true) : null,
      onTap: () => ouvrirFicheJouable(context,
          nom: s.nom,
          animalId: s.animalId,
          mode: ModePnj.sbire,
          veut: s.veut,
          vientDe: s.vientDe,
          fait: s.fait,
          kids: s.kids),
    );
  }
}
