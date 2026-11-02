import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../../application/state/visual_settings.dart';
import '../../domain/grammaire/modeles.dart';
import '../../domain/serie/serie.dart';
import '../bibliotheque/fiches.dart';
import '../bibliotheque/mechants_screen.dart';
import '../destiny/composants.dart';
import '../destiny/donnees.dart';
import '../destiny/page.dart';
import '../theme/destiny_theme.dart';

/// Le choix d'un archétype, rangé par famille.
Future<String?> choisirArchetype(BuildContext context) {
  final g = context.grammaire;
  final c = context.destiny;
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      builder: (ctx, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.all(16),
        children: [
          Text(context.textes.t('preparer.choisir_archetype'),
              style: Theme.of(ctx).textTheme.titleLarge, textAlign: TextAlign.center),
          for (final f in FamilleId.values) ...[
            Padding(padding: const EdgeInsets.only(top: 12, bottom: 6), child: PuceFamille(f)),
            for (final a in g.archetypesDe(f))
              ElementListe(
                titre: a.nom,
                sousTitre: a.ceQuIlFait,
                couleur: c.famille(f),
                onTap: () => Navigator.of(ctx).pop(a.id),
              ),
          ],
        ],
      ),
    ),
  );
}

/// Les deux animaux d'un archétype, côte à côte : on tape pour choisir.
class ChoixAnimal extends StatelessWidget {
  const ChoixAnimal({
    super.key,
    required this.archetypeId,
    required this.animalId,
    required this.onChoisi,
    this.source = VisualSource.ai,
  });

  final String archetypeId;
  final String animalId;
  final ValueChanged<String> onChoisi;
  final VisualSource source;

  @override
  Widget build(BuildContext context) {
    final g = context.grammaire;
    final c = context.destiny;
    final arch = g.archetype(archetypeId);
    if (arch == null) return const SizedBox.shrink();
    final couleur = c.famille(arch.famille);
    return Row(children: [
      for (final a in g.animauxDe(arch.id))
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => onChoisi(a.id),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: animalId == a.id ? couleur : c.filet, width: animalId == a.id ? 2 : 1),
                color: animalId == a.id ? couleur.withValues(alpha: 0.12) : null,
              ),
              child: Row(children: [
                MedaillonAnimal(a, taille: 34, source: source),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(a.nom,
                      style: TextStyle(fontFamily: kPoliceTitres, fontWeight: FontWeight.w700, color: c.texte)),
                ),
                if (animalId == a.id) Icon(Icons.check_circle_rounded, color: couleur, size: 18),
              ]),
            ),
          ),
        ),
    ]);
  }
}

/// La couleur d'un mode de PNJ : bleu pour le figurant, rouge pour le sbire.
Color couleurMode(DestinyCouleurs c, ModePnj mode) =>
    mode == ModePnj.sbire ? c.famille(FamilleId.fissure) : c.bleuDestiny;

IconData iconeMode(ModePnj mode) => mode == ModePnj.sbire ? Icons.local_fire_department_rounded : Icons.person_rounded;

/// L'interrupteur figurant / sbire, avec sa couleur et son icône.
class InterrupteurMode extends StatelessWidget {
  const InterrupteurMode({super.key, required this.mode, this.onChange});

  final ModePnj mode;
  final ValueChanged<ModePnj>? onChange;

  @override
  Widget build(BuildContext context) {
    final c = context.destiny;
    final couleur = couleurMode(c, mode);
    return ActionChip(
      visualDensity: VisualDensity.compact,
      avatar: Icon(iconeMode(mode), size: 16, color: couleur),
      side: BorderSide(color: couleur),
      backgroundColor: couleur.withValues(alpha: 0.12),
      label: Text(context.textes.t('modes_pnj.${mode.name}'),
          style: TextStyle(fontFamily: kPoliceTexte, fontWeight: FontWeight.w700, fontSize: 12, color: couleur)),
      onPressed: onChange == null
          ? null
          : () => onChange!(mode == ModePnj.sbire ? ModePnj.figurant : ModePnj.sbire),
    );
  }
}

/// Le combat d'un personnage, sur une ligne : le cœur (en forme → blessé →
/// sorti), le malus, la valeur, le bonus.
class CombatEnLigne extends StatelessWidget {
  const CombatEnLigne({super.key, required this.sante, required this.mod, required this.onSante, required this.onMod});

  final Sante sante;
  final int mod;
  final ValueChanged<Sante> onSante;
  final ValueChanged<int> onMod;

  @override
  Widget build(BuildContext context) {
    final c = context.destiny;
    final (icone, couleur) = switch (sante) {
      Sante.enForme => (Icons.favorite, c.famille(FamilleId.fissure)),
      Sante.blesse => (Icons.heart_broken, c.or),
      Sante.sorti => (Icons.favorite_border, c.texteSecondaire),
    };
    final vert = c.famille(FamilleId.tient);
    Widget bouton(IconData i, Color col, bool actif, VoidCallback f) => InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            HapticFeedback.selectionClick();
            f();
          },
          child: SizedBox(
              width: 36, height: 36, child: Icon(i, size: 19, color: actif ? col : c.texteSecondaire.withValues(alpha: 0.5))),
        );
    return Row(mainAxisSize: MainAxisSize.min, children: [
      bouton(icone, couleur, true, () => onSante(sante.suivante)),
      bouton(Icons.remove_circle_outline, c.or, mod < 0, () => onMod(mod - 1)),
      SizedBox(
        width: 22,
        child: Text(mod == 0 ? '0' : (mod > 0 ? '+$mod' : '$mod'),
            textAlign: TextAlign.center,
            style: TextStyle(
                fontFamily: kPoliceTexte,
                fontWeight: FontWeight.w800,
                fontSize: 13,
                color: mod > 0 ? vert : (mod < 0 ? c.or : c.texteSecondaire))),
      ),
      bouton(Icons.add_circle_outline, vert, mod > 0, () => onMod(mod + 1)),
    ]);
  }
}

/// La légende du combat.
Future<void> expliquerCombat(BuildContext context, {required bool kids}) {
  final t = context.textes;
  final c = context.destiny;
  String k(String x) => t.t('serie.combat.$x');
  Widget ligne(IconData i, Color col, String titre, String texte) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(i, color: col, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(TextSpan(children: [
              TextSpan(text: '$titre — ', style: TextStyle(color: col, fontWeight: FontWeight.w800)),
              TextSpan(text: texte),
            ])),
          ),
        ]),
      );
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(k('titre')),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(k('aide'), style: Theme.of(ctx).textTheme.bodySmall),
          const SizedBox(height: 8),
          ligne(Icons.favorite, c.famille(FamilleId.fissure), k('coeur'), k('en_forme')),
          ligne(Icons.heart_broken, c.or, k('brise'), k('blesse')),
          ligne(Icons.favorite_border, c.texteSecondaire, k('vide'), kids ? k('sorti_kids') : k('sorti')),
          ligne(Icons.remove_circle_outline, c.or, k('moins'), k('malus')),
          ligne(Icons.add_circle_outline, c.famille(FamilleId.tient), k('plus'), k('bonus')),
        ]),
      ),
      actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: Text(k('compris')))],
    ),
  );
}

/// L'aide-mémoire des huit types de figurants.
Future<void> ouvrirTypesFigurants(BuildContext context) {
  final g = context.grammaire;
  final t = context.textes;
  String f(String k) => t.t('bibliotheque.fiche.$k');
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      builder: (ctx, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.all(16),
        children: [
          Text(t.t('serie.jeu.types'), style: Theme.of(ctx).textTheme.titleLarge, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          for (final ty in g.figurants.types)
            CadreLisere(
              couleur: ctx.destiny.bleuDestiny,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(ty.nom, style: Theme.of(ctx).textTheme.titleMedium),
                Paragraphe(ty.ceQuIlEst),
                LigneInfo(f('veut'), ty.veut),
                LigneInfo(f('comment_le_jouer'), ty.commentLeJouer),
                LigneInfo(f('sert_a'), ty.sertA),
              ]),
            ),
        ],
      ),
    ),
  );
}

/// La carte complète d'un méchant, avec ses sbires en petit.
Future<void> ouvrirCarteMechant(BuildContext context, Mechant m, {required bool kids}) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.9,
        builder: (ctx, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.all(12),
          children: [CarteMechant(m, kids: kids)],
        ),
      ),
    );

/// Une ligne de PNJ : son animal, son nom, son type, son mode, le bouton pour
/// le jouer, et (en jeu) son combat.
class LignePnj extends StatelessWidget {
  const LignePnj({
    super.key,
    required this.pnj,
    required this.kids,
    this.onMode,
    this.onBascule,
    this.combat,
    this.source = VisualSource.ai,
  });

  final PnjEpisode pnj;
  final bool kids;
  final ValueChanged<ModePnj>? onMode;

  /// « Il a accepté l'offre » (seulement pour un figurant).
  final VoidCallback? onBascule;
  final Widget? combat;
  final VisualSource source;

  @override
  Widget build(BuildContext context) {
    final g = context.grammaire;
    final t = context.textes;
    final c = context.destiny;
    final animal = g.animal(pnj.animalId);
    final type = g.figurants.type(pnj.type);
    final sorti = pnj.sante == Sante.sorti;
    return CadreLisere(
      couleur: couleurMode(c, pnj.mode),
      marge: 8,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (animal != null) MedaillonAnimal(animal, taille: 38, source: source),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(pnj.nom,
                  style: TextStyle(
                      fontFamily: kPoliceTitres,
                      fontWeight: FontWeight.w700,
                      color: c.texte,
                      decoration: sorti ? TextDecoration.lineThrough : null)),
              Text(
                [if (type != null) type.nom, if (pnj.veut.isNotEmpty) pnj.veut].join(' · '),
                style: TextStyle(fontFamily: kPoliceTexte, fontSize: 12.5, color: c.texteSecondaire),
              ),
              if (pnj.sait.isNotEmpty || pnj.fait.isNotEmpty)
                Text(pnj.fait.isNotEmpty ? pnj.fait : pnj.sait,
                    style: TextStyle(fontFamily: kPoliceTexte, fontSize: 12.5, color: couleurMode(c, pnj.mode))),
            ]),
          ),
        ]),
        const SizedBox(height: 4),
        Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
          InterrupteurMode(mode: pnj.mode, onChange: onMode),
          ActionChip(
            visualDensity: VisualDensity.compact,
            avatar: const Icon(Icons.theater_comedy_outlined, size: 16),
            label: Text(t.t('serie.jeu.jouer')),
            onPressed: () => ouvrirFicheJouable(context,
                nom: pnj.nom,
                animalId: pnj.animalId,
                mode: pnj.mode,
                type: pnj.type,
                veut: pnj.veut,
                vientDe: pnj.vientDe,
                fait: pnj.fait,
                sait: pnj.sait,
                kids: kids),
          ),
          if (onBascule != null && pnj.mode == ModePnj.figurant && !pnj.aBascule)
            ActionChip(
              visualDensity: VisualDensity.compact,
              avatar: Icon(Icons.handshake_outlined, size: 16, color: couleurMode(c, ModePnj.sbire)),
              label: Text(t.t('serie.jeu.accepte_offre')),
              onPressed: onBascule,
            ),
          if (combat != null) combat!,
        ]),
      ]),
    );
  }
}

/// Une liste de chips à choix unique, avec un « au choix » en texte libre.
class ChampAvecIdees extends StatelessWidget {
  const ChampAvecIdees({
    super.key,
    required this.controleur,
    required this.libelle,
    this.aide,
    this.idees = const [],
    this.onChange,
    this.lignes = 1,
  });

  final TextEditingController controleur;
  final String libelle;
  final String? aide;
  final List<String> idees;
  final ValueChanged<String>? onChange;
  final int lignes;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      TextField(
        controller: controleur,
        maxLines: lignes,
        minLines: 1,
        decoration: InputDecoration(labelText: libelle, helperText: aide, helperMaxLines: 3, isDense: true),
        onChanged: onChange,
      ),
      if (idees.isNotEmpty) ...[
        const SizedBox(height: 4),
        Wrap(spacing: 6, runSpacing: 4, children: [
          for (final i in idees)
            ActionChip(
              visualDensity: VisualDensity.compact,
              label: Text(i, style: const TextStyle(fontSize: 12)),
              onPressed: () {
                controleur.text = i;
                onChange?.call(i);
              },
            ),
        ]),
      ],
    ]);
  }
}
