import 'package:flutter/material.dart';

import '../../application/state/visual_settings.dart';
import '../../domain/grammaire/modeles.dart';
import '../theme/destiny_theme.dart';
import 'donnees.dart';

/// Le sigle KIDS : marque tout ce qui se joue avec des enfants.
class SigleKids extends StatelessWidget {
  const SigleKids({super.key, this.petit = false});

  final bool petit;

  @override
  Widget build(BuildContext context) {
    final c = context.destiny;
    final texte = context.grammaire.modeKids.sigleTexte;
    return Semantics(
      label: texte,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: petit ? 6 : 9, vertical: petit ? 2 : 3),
        decoration: BoxDecoration(color: c.kidsFond, borderRadius: BorderRadius.circular(99)),
        child: Text(
          texte.split('').join(' '),
          style: TextStyle(
            fontFamily: kPoliceTexte,
            fontWeight: FontWeight.w800,
            fontSize: petit ? 9 : 11,
            letterSpacing: 1.2,
            color: c.kidsTexte,
          ),
        ),
      ),
    );
  }
}

/// La puce d'une famille : un point de couleur et son nom.
class PuceFamille extends StatelessWidget {
  const PuceFamille(this.famille, {super.key, this.compacte = false});

  final FamilleId famille;
  final bool compacte;

  @override
  Widget build(BuildContext context) {
    final c = context.destiny;
    final couleur = c.famille(famille);
    final nom = context.grammaire.famille(famille).nom;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compacte ? 8 : 10, vertical: compacte ? 3 : 5),
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: c.sombre ? 0.22 : 0.12),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: couleur.withValues(alpha: 0.8)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: couleur, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            nom,
            style: TextStyle(
              fontFamily: kPoliceTexte,
              fontSize: compacte ? 11 : 12.5,
              fontWeight: FontWeight.w600,
              // Éclairci en sombre, assombri en clair : lisible sur sa pastille.
              color: c.sombre ? Color.lerp(couleur, Colors.white, 0.55) : Color.lerp(couleur, c.encre, 0.4),
            ),
          ),
        ),
      ]),
    );
  }
}

/// La pastille du statut de départ d'un animal.
class PastilleStatut extends StatelessWidget {
  const PastilleStatut(this.statut, {super.key});

  final Statut statut;

  @override
  Widget build(BuildContext context) {
    final c = context.destiny;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: c.statuts[statut] ?? c.creme,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        context.textes.t('statuts.${statut.name}'),
        style: TextStyle(
          fontFamily: kPoliceTexte,
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          color: c.encre,
        ),
      ),
    );
  }
}

/// Icône de repli d'un animal (visuel vectoriel ou image absente).
const Map<String, String> kEmojiAnimal = {
  'lion': '🦁', 'aigle': '🦅', 'ours': '🐻', 'loup': '🐺', 'chien': '🐶',
  'mouton': '🐑', 'souris': '🐭', 'hibou': '🦉', 'coq': '🐓', 'rat': '🐀',
  'ane': '🐴', 'porc': '🐷', 'paon': '🦚', 'corbeau': '🐦', 'singe': '🐒',
  'renard': '🦊', 'hyene': '🐾', 'vautour': '🪶', 'fourmi': '🐜', 'taureau': '🐂',
  'chat': '🐈', 'cerf': '🦌', 'lapin': '🐇', 'serpent': '🐍',
};

/// L'icône d'un animal, à partir de son id (« hyene »), de son nom (« Hyène »)
/// ou d'un libellé « Opportuniste · Hyène » (on prend le dernier mot).
String? emojiAnimal(String nomOuId) {
  var s = nomOuId.split('·').last.toLowerCase().trim();
  const accents = 'àâäáãåçéèêëíìîïñóòôöõúùûüýÿ';
  const sans = 'aaaaaaceeeeiiiinooooouuuuyy';
  for (var i = 0; i < accents.length; i++) {
    s = s.replaceAll(accents[i], sans[i]);
  }
  return kEmojiAnimal[s.replaceAll(RegExp(r'[^a-z]'), '')];
}

/// Le médaillon d'un animal : rond, cerclé d'or.
class MedaillonAnimal extends StatelessWidget {
  const MedaillonAnimal(
    this.animal, {
    super.key,
    this.taille = 64,
    this.source = VisualSource.ai,
  });

  final Animal animal;
  final double taille;
  final VisualSource source;

  @override
  Widget build(BuildContext context) {
    final c = context.destiny;
    final archetype = context.grammaire.archetype(animal.archetypeId);
    final teinte = archetype == null ? c.or : c.famille(archetype.famille);
    Widget repli() => Container(
          color: Color.lerp(c.nuit, teinte, 0.35),
          alignment: Alignment.center,
          child: Text(
            source == VisualSource.minimal
                ? animal.nom.characters.first
                : (kEmojiAnimal[animal.id] ?? animal.nom.characters.first),
            style: TextStyle(
              fontSize: taille * 0.42,
              fontFamily: kPoliceTitres,
              fontWeight: FontWeight.w700,
              color: c.orClair,
            ),
          ),
        );
    return Semantics(
      label: animal.nom,
      image: true,
      child: Container(
        width: taille,
        height: taille,
        padding: EdgeInsets.all(taille * 0.045),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [c.orClair, c.or, c.orFonce],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: ClipOval(
          child: source == VisualSource.ai
              ? Image.asset(
                  animal.image,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  errorBuilder: (_, __, ___) => repli(),
                )
              : repli(),
        ),
      ),
    );
  }
}

/// L'encart d'une réplique : en italique, à la couleur de la famille.
class EncartReplique extends StatelessWidget {
  const EncartReplique(this.texte, {super.key, required this.couleur, this.taille = 13.5});

  final String texte;
  final Color couleur;
  final double taille;

  @override
  Widget build(BuildContext context) {
    final c = context.destiny;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 8, 6),
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: c.sombre ? 0.14 : 0.07),
        border: Border(left: BorderSide(color: couleur, width: 3)),
        borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
      ),
      child: Text(
        '« $texte »',
        style: TextStyle(
          fontFamily: kPoliceTexte,
          fontStyle: FontStyle.italic,
          fontSize: taille,
          height: 1.3,
          color: c.sombre ? Color.lerp(couleur, Colors.white, 0.6) : Color.lerp(couleur, c.encre, 0.35),
        ),
      ),
    );
  }
}

/// Le bandeau de titre façon affiche : surtitre, titre en Cinzel, filets d'or.
class BandeauAffiche extends StatelessWidget {
  const BandeauAffiche({super.key, required this.titre, this.surtitre, this.sousTitre});

  final String titre;
  final String? surtitre;
  final String? sousTitre;

  @override
  Widget build(BuildContext context) {
    final c = context.destiny;
    Widget filet() => Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [c.or.withValues(alpha: 0), c.or, c.or.withValues(alpha: 0)]),
            ),
          ),
        );
    return Column(mainAxisSize: MainAxisSize.min, children: [
      if (surtitre != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            surtitre!.toUpperCase(),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: kPoliceTexte,
              fontSize: 11,
              letterSpacing: 2.4,
              fontWeight: FontWeight.w600,
              color: c.texteSecondaire,
            ),
          ),
        ),
      Row(children: [
        filet(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text('◆', style: TextStyle(color: c.or, fontSize: 9)),
        ),
        filet(),
      ]),
      const SizedBox(height: 6),
      Text(
        titre,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: kPoliceTitres,
          fontWeight: FontWeight.w900,
          fontSize: 26,
          letterSpacing: 1.5,
          color: c.titre,
        ),
      ),
      if (sousTitre != null) ...[
        const SizedBox(height: 4),
        Text(
          sousTitre!,
          textAlign: TextAlign.center,
          style: TextStyle(fontFamily: kPoliceTexte, fontSize: 13, color: c.texteSecondaire),
        ),
      ],
      const SizedBox(height: 6),
      Row(children: [filet()]),
    ]);
  }
}

/// La frise des quatre paliers. Avec [textes], chaque palier montre ce que
/// fait le danger ; avec [courant], le palier en cours ressort.
class FrisePaliers extends StatelessWidget {
  const FrisePaliers({super.key, this.textes, this.courant, this.compacte = false});

  final List<String>? textes;
  final PalierId? courant;
  final bool compacte;

  @override
  Widget build(BuildContext context) {
    final c = context.destiny;
    final g = context.grammaire;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final p in g.paliers)
          _LignePalier(
            palier: p,
            texte: textes != null && textes!.length > p.id.index ? textes![p.id.index] : null,
            actif: courant == p.id,
            passe: courant != null && p.id.index < courant!.index,
            couleur: c.palier(p.id),
            compacte: compacte,
            dernier: p.id == PalierId.supprime,
          ),
      ],
    );
  }
}

class _LignePalier extends StatelessWidget {
  const _LignePalier({
    required this.palier,
    required this.texte,
    required this.actif,
    required this.passe,
    required this.couleur,
    required this.compacte,
    required this.dernier,
  });

  final Palier palier;
  final String? texte;
  final bool actif;
  final bool passe;
  final Color couleur;
  final bool compacte;
  final bool dernier;

  @override
  Widget build(BuildContext context) {
    final c = context.destiny;
    final pastille = compacte ? 22.0 : 28.0;
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
          width: pastille,
          child: Column(children: [
            Container(
              width: pastille,
              height: pastille,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: actif || passe ? couleur : Colors.transparent,
                border: Border.all(color: couleur, width: 2),
                boxShadow: actif
                    ? [BoxShadow(color: couleur.withValues(alpha: 0.6), blurRadius: 10)]
                    : null,
              ),
              child: Text(
                '${palier.numero}',
                style: TextStyle(
                  fontFamily: kPoliceTitres,
                  fontWeight: FontWeight.w900,
                  fontSize: compacte ? 11 : 13,
                  color: actif || passe
                      ? Colors.white
                      : (c.sombre ? Color.lerp(couleur, Colors.white, 0.45) : couleur),
                ),
              ),
            ),
            if (!dernier)
              Expanded(child: Container(width: 2, color: couleur.withValues(alpha: 0.45))),
          ]),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: compacte ? 6 : 10, top: 2),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(
                  child: Text(
                    palier.nom,
                    style: TextStyle(
                      fontFamily: kPoliceTitres,
                      fontWeight: FontWeight.w700,
                      fontSize: compacte ? 13 : 15,
                      color: actif ? c.titre : c.texte,
                    ),
                  ),
                ),
                if (!compacte) ...[
                  const SizedBox(width: 8),
                  Text(
                    palier.ambiance,
                    style: TextStyle(
                      fontFamily: kPoliceTexte,
                      fontSize: 11.5,
                      fontStyle: FontStyle.italic,
                      color: c.texteSecondaire,
                    ),
                  ),
                ],
              ]),
              if (texte != null && texte!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    texte!,
                    style: TextStyle(
                      fontFamily: kPoliceTexte,
                      fontSize: compacte ? 12 : 13,
                      height: 1.3,
                      color: actif ? c.texte : c.texteSecondaire,
                    ),
                  ),
                ),
            ]),
          ),
        ),
      ]),
    );
  }
}
