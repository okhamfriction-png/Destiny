import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../../application/state/visual_settings.dart';
import '../../domain/grammaire/modeles.dart';
import '../../domain/serie/pbta.dart';
import '../destiny/donnees.dart';
import '../theme/destiny_theme.dart';
import '../widgets/piece_destin_flip.dart' show DestinyOmen;

/// La couleur d'une face de la pièce : celle de la vraie pièce (l'éclair
/// orange de BRAVE, le masque violet de SMART).
Color couleurFace(FacePiece f) => f == FacePiece.brave ? DestinyOmen.braveGradient[1] : DestinyOmen.smartGradient[1];

/// L'icône d'une face : l'éclair ou le masque.
IconData iconeFace(FacePiece f) => f == FacePiece.brave ? Icons.bolt_rounded : Icons.theater_comedy_rounded;

/// Le nom d'une face (« BRAVE »).
String nomFace(BuildContext context, FacePiece f) => context.textes.t('pbta.piece.faces.${f.name}.nom');

/// Une face de la pièce en petit : son icône et son nom.
class PuceFace extends StatelessWidget {
  const PuceFace(this.face, {super.key, this.suffixe = ''});

  final FacePiece face;

  /// Un mot après le nom (« bonus »).
  final String suffixe;

  @override
  Widget build(BuildContext context) {
    final c = context.destiny;
    final couleur = couleurFace(face);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: couleur, width: 1.5),
        color: couleur.withValues(alpha: 0.12),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(iconeFace(face), size: 16, color: couleur),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            [nomFace(context, face), if (suffixe.isNotEmpty) suffixe].join(' · '),
            style: TextStyle(fontFamily: kPoliceTexte, fontWeight: FontWeight.w800, fontSize: 12, color: c.texte),
          ),
        ),
      ]),
    );
  }
}

/// Le choix entre BRAVE et SMART : le bonus d'un personnage, ou l'approche
/// d'une action (le bonus du personnage est alors mis en avant).
class ChoixFace extends StatelessWidget {
  const ChoixFace({super.key, required this.face, required this.onChoisi, this.bonus, this.motBonus = ''});

  final FacePiece? face;
  final ValueChanged<FacePiece> onChoisi;
  final FacePiece? bonus;
  final String motBonus;

  @override
  Widget build(BuildContext context) {
    final c = context.destiny;
    return Wrap(spacing: 8, runSpacing: 6, children: [
      for (final f in FacePiece.values)
        ChoiceChip(
          avatar: Icon(iconeFace(f), size: 18, color: couleurFace(f)),
          side: BorderSide(color: face == f ? couleurFace(f) : c.filet, width: face == f ? 2 : 1),
          label: Text(
            [nomFace(context, f), if (bonus == f && motBonus.isNotEmpty) motBonus].join(' · '),
            style: TextStyle(fontWeight: bonus == f ? FontWeight.w800 : FontWeight.w600),
          ),
          selected: face == f,
          onSelected: (_) => onChoisi(f),
        ),
    ]);
  }
}

/// Les trois cases de blessures d'un personnage : on touche une case pour la
/// cocher (ou la décocher), « Soigner » en efface une.
class PisteBlessures extends StatelessWidget {
  const PisteBlessures({
    super.key,
    required this.cases,
    required this.libelles,
    required this.onChange,
    required this.soigner,
  });

  final int cases;

  /// Les noms des trois cases (« Secoué », « Blessé », « Hors jeu »).
  final List<String> libelles;
  final ValueChanged<int> onChange;

  /// Le libellé du bouton qui efface une case.
  final String soigner;

  @override
  Widget build(BuildContext context) {
    final c = context.destiny;
    Color teinte(int i) => switch (i) {
          0 => c.titre,
          1 => c.palier(PalierId.envahit),
          _ => c.famille(FamilleId.fissure),
        };
    return Wrap(spacing: 2, runSpacing: 2, crossAxisAlignment: WrapCrossAlignment.center, children: [
      for (var i = 0; i < libelles.length; i++)
        Tooltip(
          message: libelles[i],
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () {
              HapticFeedback.selectionClick();
              onChange(cases > i ? i : i + 1);
            },
            child: SizedBox(
              width: 40,
              height: 40,
              child: Icon(
                cases > i ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                color: cases > i ? teinte(i) : c.texteSecondaire,
              ),
            ),
          ),
        ),
      if (cases > 0)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            libelles[(cases - 1).clamp(0, libelles.length - 1)],
            style: TextStyle(fontFamily: kPoliceTexte, fontWeight: FontWeight.w800, color: c.texte),
          ),
        ),
      if (cases > 0)
        TextButton.icon(
          onPressed: () => onChange(cases - 1),
          icon: const Icon(Icons.healing_rounded, size: 18),
          label: Text(soigner),
        ),
    ]);
  }
}

/// L'interrupteur « hors jeu » d'un figurant, d'un sbire ou du méchant.
class InterrupteurHorsJeu extends StatelessWidget {
  const InterrupteurHorsJeu({super.key, required this.horsJeu, required this.libelle, required this.onChange});

  final bool horsJeu;
  final String libelle;
  final ValueChanged<bool> onChange;

  @override
  Widget build(BuildContext context) {
    final c = context.destiny;
    return FilterChip(
      visualDensity: VisualDensity.compact,
      avatar: Icon(
        horsJeu ? Icons.person_off_rounded : Icons.person_outline_rounded,
        size: 16,
        color: horsJeu ? c.famille(FamilleId.fissure) : c.texteSecondaire,
      ),
      showCheckmark: false,
      label: Text(libelle, style: const TextStyle(fontSize: 12)),
      selected: horsJeu,
      onSelected: onChange,
    );
  }
}

/// Une horloge en quatre crans : les paliers du danger (l'épisode) ou les
/// présages du méchant (la saison).
class HorlogeQuatre extends StatelessWidget {
  const HorlogeQuatre({
    super.key,
    required this.titre,
    required this.rempli,
    this.legende = '',
    this.icone = Icons.schedule_rounded,
  });

  final String titre;

  /// Le nombre de crans atteints (0 à 4).
  final int rempli;
  final String legende;
  final IconData icone;

  @override
  Widget build(BuildContext context) {
    final c = context.destiny;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(icone, size: 18, color: c.titre),
          const SizedBox(width: 6),
          Expanded(
            child: Text(titre, style: TextStyle(fontFamily: kPoliceTitres, fontWeight: FontWeight.w700, color: c.texte)),
          ),
          Text('${rempli.clamp(0, 4)} / 4',
              style: TextStyle(fontFamily: kPoliceTexte, fontWeight: FontWeight.w700, color: c.texteSecondaire)),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          for (var i = 0; i < 4; i++)
            Expanded(
              child: Container(
                height: 14,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(7),
                  color: i < rempli ? c.palier(PalierId.values[i]) : Colors.transparent,
                  border: Border.all(color: c.palier(PalierId.values[i]), width: 1.5),
                ),
              ),
            ),
        ]),
        if (legende.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(legende, style: TextStyle(fontFamily: kPoliceTexte, fontSize: 12.5, color: c.texteSecondaire)),
        ],
      ]),
    );
  }
}

/// La vignette d'un lieu ou d'un danger du catalogue : son image (ou un
/// repli), son nom, un bouton pour en tirer un autre, un pour choisir dans la
/// liste, et un bouton « i » pour sa fiche dans la Bibliothèque.
class VignetteCatalogue extends StatelessWidget {
  const VignetteCatalogue({
    super.key,
    required this.dossier,
    required this.id,
    required this.surtitre,
    required this.nom,
    required this.icone,
    required this.source,
    required this.onRelancer,
    required this.relancer,
    required this.onListe,
    required this.liste,
    required this.onInfo,
    required this.info,
  });

  /// `locations` ou `dangers` (dans `assets/images/`).
  final String dossier;
  final String id;
  final String surtitre;
  final String nom;
  final IconData icone;
  final VisualSource source;
  final VoidCallback onRelancer;
  final String relancer;
  final VoidCallback onListe;
  final String liste;
  final VoidCallback? onInfo;
  final String info;

  @override
  Widget build(BuildContext context) {
    final c = context.destiny;
    Widget repli() => Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [c.orFonce, c.nuit]),
          ),
          child: Center(child: Icon(icone, size: 48, color: c.orClair)),
        );
    Widget bouton(IconData i, String tip, VoidCallback? onTap) => Material(
          color: c.nuit.withValues(alpha: 0.55),
          shape: const CircleBorder(),
          child: IconButton(
            tooltip: tip,
            visualDensity: VisualDensity.compact,
            iconSize: 20,
            color: c.creme,
            icon: Icon(i),
            onPressed: onTap,
          ),
        );
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: AspectRatio(
        aspectRatio: 0.85,
        child: Stack(fit: StackFit.expand, children: [
          if (id.isNotEmpty && source == VisualSource.ai)
            Image.asset('assets/images/$dossier/$id.jpg', fit: BoxFit.cover, errorBuilder: (_, __, ___) => repli())
          else
            repli(),
          // Le dégradé du bas, pour que le nom se lise sur l'image.
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.4, 1],
                colors: [c.nuit.withValues(alpha: 0), c.nuit.withValues(alpha: 0.92)],
              ),
            ),
          ),
          Positioned(
            left: 10,
            right: 10,
            bottom: 10,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(
                surtitre.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: kPoliceTexte,
                  fontSize: 10.5,
                  letterSpacing: 1.6,
                  fontWeight: FontWeight.w700,
                  color: c.orClair,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                nom.isEmpty ? '—' : nom,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontFamily: kPoliceTitres, fontWeight: FontWeight.w700, fontSize: 15, color: c.creme),
              ),
            ]),
          ),
          Positioned(
            top: 6,
            left: 6,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              bouton(Icons.shuffle_rounded, relancer, onRelancer),
              const SizedBox(height: 6),
              bouton(Icons.list_rounded, liste, onListe),
            ]),
          ),
          Positioned(top: 6, right: 6, child: bouton(Icons.info_outline_rounded, info, onInfo)),
        ]),
      ),
    );
  }
}
