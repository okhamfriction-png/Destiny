import 'package:flutter/material.dart';

import '../theme/destiny_theme.dart';

/// Une page Destiny : barre de titre en Cinzel, contenu centré et lisible.
class PageDestiny extends StatelessWidget {
  const PageDestiny({
    super.key,
    required this.titre,
    required this.enfants,
    this.actions,
    this.entete,
    this.largeurMax = 760,
  });

  final String titre;
  final List<Widget> enfants;
  final List<Widget>? actions;

  /// Un widget fixe sous la barre (filtres, recherche).
  final Widget? entete;
  final double largeurMax;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(titre), actions: actions),
      body: SafeArea(
        top: false,
        child: Column(children: [
          if (entete != null)
            Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: largeurMax),
                child: Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 8), child: entete),
              ),
            ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                for (final e in enfants)
                  Center(
                    child: ConstrainedBox(constraints: BoxConstraints(maxWidth: largeurMax), child: e),
                  ),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

/// Une section : un intertitre doré, puis son contenu.
class SectionDestiny extends StatelessWidget {
  const SectionDestiny({super.key, required this.titre, required this.enfants, this.espace = 18});

  final String titre;
  final List<Widget> enfants;
  final double espace;

  @override
  Widget build(BuildContext context) {
    final c = context.destiny;
    return Padding(
      padding: EdgeInsets.only(top: espace),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(
          titre.toUpperCase(),
          style: TextStyle(
            fontFamily: kPoliceTexte,
            fontSize: 11.5,
            letterSpacing: 2,
            fontWeight: FontWeight.w700,
            color: c.titre,
          ),
        ),
        Container(
          height: 1,
          margin: const EdgeInsets.only(top: 4, bottom: 10),
          color: c.filet,
        ),
        ...enfants,
      ]),
    );
  }
}

/// Une ligne « libellé : texte ».
class LigneInfo extends StatelessWidget {
  const LigneInfo(this.libelle, this.texte, {super.key, this.italique = false});

  final String libelle;
  final String texte;
  final bool italique;

  @override
  Widget build(BuildContext context) {
    if (texte.trim().isEmpty) return const SizedBox.shrink();
    final c = context.destiny;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          libelle,
          style: TextStyle(
            fontFamily: kPoliceTexte,
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: c.texteSecondaire,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          texte,
          style: TextStyle(
            fontFamily: kPoliceTexte,
            fontSize: 14.5,
            height: 1.35,
            fontStyle: italique ? FontStyle.italic : FontStyle.normal,
            color: c.texte,
          ),
        ),
      ]),
    );
  }
}

/// Un paragraphe simple.
class Paragraphe extends StatelessWidget {
  const Paragraphe(this.texte, {super.key, this.italique = false, this.gras = false});

  final String texte;
  final bool italique;
  final bool gras;

  @override
  Widget build(BuildContext context) {
    final c = context.destiny;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        texte,
        style: TextStyle(
          fontFamily: kPoliceTexte,
          fontSize: 14.5,
          height: 1.4,
          fontStyle: italique ? FontStyle.italic : FontStyle.normal,
          fontWeight: gras ? FontWeight.w700 : FontWeight.w400,
          color: c.texte,
        ),
      ),
    );
  }
}

/// Une puce de liste.
class Puce extends StatelessWidget {
  const Puce(this.texte, {super.key, this.numero});

  final String texte;
  final int? numero;

  @override
  Widget build(BuildContext context) {
    final c = context.destiny;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 22,
          child: Text(
            numero == null ? '◆' : '$numero.',
            style: TextStyle(
              fontFamily: numero == null ? kPoliceTexte : kPoliceTitres,
              fontSize: numero == null ? 8 : 14,
              fontWeight: FontWeight.w700,
              color: c.or,
              height: numero == null ? 2.4 : 1.25,
            ),
          ),
        ),
        Expanded(
          child: Text(texte,
              style: TextStyle(fontFamily: kPoliceTexte, fontSize: 14.5, height: 1.35, color: c.texte)),
        ),
      ]),
    );
  }
}

/// Un élément de liste en carte, avec une bordure de couleur facultative.
class ElementListe extends StatelessWidget {
  const ElementListe({
    super.key,
    required this.titre,
    this.sousTitre,
    this.devant,
    this.apres,
    this.onTap,
    this.couleur,
  });

  final String titre;
  final String? sousTitre;
  final Widget? devant;
  final Widget? apres;
  final VoidCallback? onTap;

  /// Couleur du liseré gauche (couleur de famille, par exemple).
  final Color? couleur;

  @override
  Widget build(BuildContext context) {
    final c = context.destiny;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: c.carte,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 56),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: c.filet),
            ),
            child: Row(children: [
              if (couleur != null)
                Container(
                  width: 5,
                  height: 64,
                  decoration: BoxDecoration(
                    color: couleur,
                    borderRadius: const BorderRadius.horizontal(left: Radius.circular(14)),
                  ),
                ),
              if (devant != null) Padding(padding: const EdgeInsets.only(left: 12), child: devant),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                      titre,
                      style: TextStyle(
                        fontFamily: kPoliceTitres,
                        fontWeight: FontWeight.w700,
                        fontSize: 15.5,
                        color: c.texte,
                      ),
                    ),
                    if (sousTitre != null && sousTitre!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        sousTitre!,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: kPoliceTexte,
                          fontSize: 12.5,
                          height: 1.3,
                          color: c.texteSecondaire,
                        ),
                      ),
                    ],
                  ]),
                ),
              ),
              if (apres != null) Padding(padding: const EdgeInsets.only(right: 10), child: apres),
              if (onTap != null)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Icon(Icons.chevron_right_rounded, color: c.texteSecondaire),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Une rangée de puces de filtre.
class FiltresPuces<T> extends StatelessWidget {
  const FiltresPuces({
    super.key,
    required this.valeurs,
    required this.libelle,
    required this.choisi,
    required this.onChoix,
    this.couleur,
  });

  final List<T> valeurs;
  final String Function(T) libelle;
  final T choisi;
  final ValueChanged<T> onChoix;
  final Color? Function(T)? couleur;

  @override
  Widget build(BuildContext context) {
    final c = context.destiny;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        for (final v in valeurs)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(libelle(v)),
              selected: v == choisi,
              onSelected: (_) => onChoix(v),
              selectedColor: (couleur?.call(v) ?? c.or).withValues(alpha: 0.3),
              side: BorderSide(color: couleur?.call(v) ?? c.filet),
              showCheckmark: false,
            ),
          ),
      ]),
    );
  }
}

/// Un cadre arrondi avec un liseré de couleur à gauche (couleur de famille).
class CadreLisere extends StatelessWidget {
  const CadreLisere({super.key, required this.couleur, required this.child, this.marge = 10});

  final Color couleur;
  final Widget child;
  final double marge;

  @override
  Widget build(BuildContext context) {
    final c = context.destiny;
    return Container(
      margin: EdgeInsets.only(bottom: marge),
      decoration: BoxDecoration(
        color: c.carte,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.filet),
      ),
      // Sans IntrinsicHeight : le liseré suit la hauteur du contenu, même quand
      // un grand texte passe sur plusieurs lignes.
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: Stack(children: [
          Padding(padding: const EdgeInsets.fromLTRB(16, 12, 12, 12), child: child),
          Positioned(left: 0, top: 0, bottom: 0, width: 4, child: ColoredBox(color: couleur)),
        ]),
      ),
    );
  }
}
