import 'package:flutter/material.dart';

import '../../domain/serie/univers.dart';
import '../../application/state/location_details.dart';
import '../../application/state/visual_settings.dart';
import '../../domain/grammaire/modeles.dart';
import '../../domain/repositories/catalog_store.dart';
import '../accueil/decouvrir_screen.dart';
import '../destiny/composants.dart';
import '../destiny/donnees.dart';
import '../destiny/page.dart';
import '../theme/destiny_theme.dart';
import 'archetypes_screen.dart';
import 'dangers_lieux_screen.dart';
import 'livret_screen.dart';
import 'mechants_screen.dart';
import 'oeuvres_screen.dart';
import 'pages_textes.dart';

/// Ce dont la Bibliothèque a besoin de l'appli.
class ContexteBibliotheque {
  const ContexteBibliotheque({
    required this.catalogue,
    required this.visuels,
    this.detailsLieux,
    this.univers = CatalogueUnivers.vide,
  });

  /// Le catalogue modifiable (dangers et lieux tels que la troupe les joue).
  final CatalogStore catalogue;
  final VisualSettings visuels;
  final LocationDetailsStore? detailsLieux;

  /// Les univers du jeu de rôle (leurs méchants et leurs sbires).
  final CatalogueUnivers univers;
}

/// Les entrées de la Bibliothèque : clé (celle des textes
/// `bibliotheque.entrees`), icône, page.
List<(String, IconData, Widget Function())> entreesBibliotheque(ContexteBibliotheque contexte) => [
      ('decouvrir', Icons.explore_outlined, () => const DecouvrirScreen()),
      ('regles', Icons.auto_stories_outlined, () => const LivretScreen()),
      ('archetypes', Icons.style_outlined, () => ArchetypesScreen(contexte: contexte)),
      ('animaux', Icons.pets_outlined, () => AnimauxScreen(contexte: contexte)),
      ('vouloir_besoin', Icons.favorite_border_rounded, () => const VouloirBesoinScreen()),
      ('dangers', Icons.bolt_outlined, () => DangersScreen(contexte: contexte)),
      ('lieux', Icons.place_outlined, () => LieuxScreen(contexte: contexte)),
      ('oeuvres', Icons.movie_filter_outlined, () => OeuvresScreen(contexte: contexte)),
      ('mechants', Icons.nightlight_outlined, () => MechantsScreen(contexte: contexte)),
      ('figurants', Icons.groups_2_outlined, () => FigurantsScreen(contexte: contexte)),
      ('kids', Icons.child_care_outlined, () => const KidsScreen()),
      ('outils', Icons.handyman_outlined, () => const OutilsScreen()),
      ('lexique', Icons.translate_rounded, () => const LexiqueScreen()),
    ];

/// La couleur d'accent d'une entrée de la Bibliothèque : une par entrée,
/// pour s'y retrouver d'un coup d'œil (familles, or, accents vifs).
Color couleurEntreeBibliotheque(BuildContext context, String cle) {
  final c = context.destiny;
  return switch (cle) {
    'decouvrir' => c.or,
    'regles' => DestinyCouleurs.ambre,
    'archetypes' => c.famille(FamilleId.interprete),
    'animaux' => c.famille(FamilleId.tient),
    'vouloir_besoin' => DestinyCouleurs.rose,
    'dangers' => DestinyCouleurs.corail,
    'lieux' => DestinyCouleurs.turquoise,
    'oeuvres' => DestinyCouleurs.lavande,
    'mechants' => c.famille(FamilleId.fissure),
    'figurants' => DestinyCouleurs.ciel,
    'kids' => c.kidsFond,
    'outils' => DestinyCouleurs.cyan,
    'lexique' => c.bleuDestiny,
    _ => c.or,
  };
}

/// La page de la Bibliothèque qui porte la clé [cle], ou null.
Widget? pageBibliotheque(String cle, ContexteBibliotheque contexte) {
  for (final (k, _, page) in entreesBibliotheque(contexte)) {
    if (k == cle) return page();
  }
  return null;
}

/// La Bibliothèque : remplace le Guide et le Catalogue.
class BibliothequeScreen extends StatelessWidget {
  const BibliothequeScreen({super.key, required this.contexte});

  final ContexteBibliotheque contexte;

  @override
  Widget build(BuildContext context) {
    final t = context.textes;
    final g = context.grammaire;
    String titre(String k) => t.t('bibliotheque.entrees.$k.titre');
    String texte(String k) => t.t('bibliotheque.entrees.$k.texte');
    void ouvrir(Widget page) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

    final entrees = entreesBibliotheque(contexte);

    return PageDestiny(
      titre: t.t('bibliotheque.titre'),
      enfants: [
        BandeauAffiche(titre: g.nom.toUpperCase(), surtitre: t.t('bibliotheque.titre'), sousTitre: g.promesse),
        const SizedBox(height: 20),
        for (final (cle, icone, page) in entrees)
          ElementListe(
            titre: titre(cle),
            sousTitre: texte(cle),
            devant: PastilleIcone(icone, couleur: couleurEntreeBibliotheque(context, cle)),
            apres: cle == 'kids' ? const SigleKids(petit: true) : null,
            onTap: () => ouvrir(page()),
          ),
      ],
    );
  }
}
