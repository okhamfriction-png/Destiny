import 'package:flutter/material.dart';

import '../../domain/serie/univers.dart';
import '../../application/state/location_details.dart';
import '../../application/state/visual_settings.dart';
import '../../domain/repositories/catalog_store.dart';
import '../destiny/composants.dart';
import '../destiny/donnees.dart';
import '../destiny/page.dart';
import '../theme/destiny_theme.dart';
import 'archetypes_screen.dart';
import 'dangers_lieux_screen.dart';
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

/// La Bibliothèque : remplace le Guide et le Catalogue.
class BibliothequeScreen extends StatelessWidget {
  const BibliothequeScreen({super.key, required this.contexte});

  final ContexteBibliotheque contexte;

  @override
  Widget build(BuildContext context) {
    final t = context.textes;
    final g = context.grammaire;
    final c = context.destiny;
    String titre(String k) => t.t('bibliotheque.entrees.$k.titre');
    String texte(String k) => t.t('bibliotheque.entrees.$k.texte');
    void ouvrir(Widget page) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

    final entrees = <(String, IconData, Widget Function())>[
      ('regles', Icons.auto_stories_outlined, () => const ReglesScreen()),
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

    return PageDestiny(
      titre: t.t('bibliotheque.titre'),
      enfants: [
        BandeauAffiche(titre: g.nom.toUpperCase(), surtitre: t.t('bibliotheque.titre'), sousTitre: g.promesse),
        const SizedBox(height: 14),
        for (final (cle, icone, page) in entrees)
          ElementListe(
            titre: titre(cle),
            sousTitre: texte(cle),
            devant: Icon(icone, color: c.titre),
            apres: cle == 'kids' ? const SigleKids(petit: true) : null,
            onTap: () => ouvrir(page()),
          ),
      ],
    );
  }
}
