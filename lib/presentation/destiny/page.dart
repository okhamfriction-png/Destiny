import 'package:flutter/material.dart';

import '../theme/destiny_theme.dart';

/// Ouvre une page (une fiche) dans une fenêtre par-dessus l'écran en cours :
/// on la ferme avec la croix, en la glissant vers le bas ou en touchant à
/// côté, et on retrouve l'écran tel quel (le chrono continue).
Future<void> ouvrirEnFenetre(BuildContext context, Widget page) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      clipBehavior: Clip.antiAlias,
      builder: (_) => FractionallySizedBox(heightFactor: 0.92, child: EnFenetre(child: page)),
    );

/// Marque une page ouverte en fenêtre ([ouvrirEnFenetre]) : sa barre a une
/// croix à droite plutôt qu'une flèche de retour.
class EnFenetre extends InheritedWidget {
  const EnFenetre({super.key, required super.child});

  static bool de(BuildContext context) => context.dependOnInheritedWidgetOfExactType<EnFenetre>() != null;

  @override
  bool updateShouldNotify(EnFenetre oldWidget) => false;
}

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
    final fenetre = EnFenetre.de(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(titre),
        primary: !fenetre,
        automaticallyImplyLeading: !fenetre,
        actions: [
          ...?actions,
          if (fenetre)
            CloseButton(key: const ValueKey('fermer_fenetre'), onPressed: () => Navigator.of(context).maybePop()),
        ],
      ),
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

/// Une section : un intertitre net (capitales sobres, en or, précédé d'un
/// trait), bien détaché de ce qui précède, puis son contenu.
class SectionDestiny extends StatelessWidget {
  const SectionDestiny({super.key, required this.titre, required this.enfants, this.espace = 26});

  final String titre;
  final List<Widget> enfants;
  final double espace;

  @override
  Widget build(BuildContext context) {
    final c = context.destiny;
    return Padding(
      padding: EdgeInsets.only(top: espace),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Container(
              width: 4,
              height: 18,
              decoration: BoxDecoration(color: c.or, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                titre.toUpperCase(),
                style: TextStyle(
                  fontFamily: kPoliceTexte,
                  fontSize: 14.5,
                  letterSpacing: 0.9,
                  height: 1.25,
                  fontWeight: FontWeight.w700,
                  color: c.titre,
                ),
              ),
            ),
          ]),
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
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          libelle,
          style: TextStyle(
            fontFamily: kPoliceTexte,
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: c.titre,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          texte,
          style: TextStyle(
            fontFamily: kPoliceTexte,
            fontSize: 15,
            height: 1.45,
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
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        texte,
        style: TextStyle(
          fontFamily: kPoliceTexte,
          fontSize: 15,
          height: 1.45,
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
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 24,
          child: numero == null
              ? Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(color: c.or, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                )
              : Text(
                  '$numero.',
                  style: TextStyle(
                    fontFamily: kPoliceTexte,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: c.titre,
                    height: 1.4,
                  ),
                ),
        ),
        Expanded(
          child: Text(texte,
              style: TextStyle(fontFamily: kPoliceTexte, fontSize: 15, height: 1.4, color: c.texte)),
        ),
      ]),
    );
  }
}

/// Une icône sur une pastille teintée de sa couleur : le repère visuel d'une
/// entrée (une couleur par entrée, pour la reconnaître d'un coup d'œil).
class PastilleIcone extends StatelessWidget {
  const PastilleIcone(this.icone, {super.key, this.couleur, this.taille = 44});

  final IconData icone;

  /// Couleur d'accent (l'or par défaut).
  final Color? couleur;
  final double taille;

  @override
  Widget build(BuildContext context) {
    final c = context.destiny;
    final base = couleur ?? c.or;
    return Container(
      width: taille,
      height: taille,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c.teinte(base),
        borderRadius: BorderRadius.circular(taille * 0.29),
      ),
      child: Icon(icone, color: c.accent(base), size: taille * 0.55),
    );
  }
}

/// Le fond d'une carte : une surface pleine, plus claire que la page, avec
/// une ombre douce. Pas de bordure, sauf si elle dit quelque chose.
BoxDecoration decorCarte(DestinyCouleurs c, {double rayon = 16, Color? bordure, double largeur = 1.5}) =>
    BoxDecoration(
      color: c.carte,
      borderRadius: BorderRadius.circular(rayon),
      border: bordure == null ? null : Border.all(color: bordure, width: largeur),
      boxShadow: c.ombre,
    );

/// Un élément de liste en carte : une pastille d'icône (ou un médaillon),
/// un titre lisible, un sous-titre, et un liseré de couleur facultatif.
///
/// Une simple [Icon] passée en [devant] devient une [PastilleIcone] de sa
/// couleur (l'or si elle n'en a pas).
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
    final d = devant;
    final Widget? tete = d is Icon && d.icon != null
        ? PastilleIcone(d.icon!, couleur: d.color == null || d.color == c.titre ? c.or : d.color)
        : d;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DecoratedBox(
        decoration: decorCarte(c),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 64),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(couleur != null ? 20 : 14, 14, onTap != null ? 8 : 14, 14),
                    child: Row(children: [
                      if (tete != null) ...[tete, const SizedBox(width: 14)],
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(
                            titre,
                            style: TextStyle(
                              fontFamily: kPoliceTexte,
                              fontWeight: FontWeight.w700,
                              fontSize: 16.5,
                              height: 1.25,
                              color: c.texte,
                            ),
                          ),
                          if (sousTitre != null && sousTitre!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              sousTitre!,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: kPoliceTexte,
                                fontSize: 14,
                                height: 1.35,
                                color: c.texteSecondaire,
                              ),
                            ),
                          ],
                        ]),
                      ),
                      if (apres != null) Padding(padding: const EdgeInsets.only(left: 10), child: apres),
                      if (onTap != null)
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Icon(Icons.chevron_right_rounded, color: c.texteSecondaire, size: 26),
                        ),
                    ]),
                  ),
                ),
                if (couleur != null)
                  Positioned(left: 0, top: 0, bottom: 0, width: 6, child: ColoredBox(color: couleur!)),
              ]),
            ),
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
            child: Builder(builder: (context) {
              final teinte = couleur?.call(v);
              final actif = v == choisi;
              return ChoiceChip(
                label: Text(libelle(v)),
                selected: actif,
                onSelected: (_) => onChoix(v),
                avatar: teinte == null
                    ? null
                    : Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(color: teinte, shape: BoxShape.circle),
                      ),
                selectedColor: teinte == null ? c.selection : c.teinte(teinte),
                side: BorderSide(
                  color: actif ? (teinte ?? c.or) : c.ligne,
                  width: actif ? 1.6 : 1,
                ),
                showCheckmark: false,
              );
            }),
          ),
      ]),
    );
  }
}

/// Un cadre en carte, avec un liseré de couleur à gauche (couleur de famille).
class CadreLisere extends StatelessWidget {
  const CadreLisere({super.key, required this.couleur, required this.child, this.marge = 12});

  final Color couleur;
  final Widget child;
  final double marge;

  @override
  Widget build(BuildContext context) {
    final c = context.destiny;
    return Container(
      margin: EdgeInsets.only(bottom: marge),
      decoration: decorCarte(c),
      // Sans IntrinsicHeight : le liseré suit la hauteur du contenu, même quand
      // un grand texte passe sur plusieurs lignes.
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(children: [
          Padding(padding: const EdgeInsets.fromLTRB(20, 12, 14, 12), child: child),
          Positioned(left: 0, top: 0, bottom: 0, width: 6, child: ColoredBox(color: couleur)),
        ]),
      ),
    );
  }
}
