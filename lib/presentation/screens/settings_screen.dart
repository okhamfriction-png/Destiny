import 'package:flutter/material.dart';

import '../../application/services/audio_service.dart';
import '../../application/state/ai_settings.dart';
import '../../application/state/location_details.dart';
import '../../application/state/music_controller.dart';
import '../../application/state/reglages_destiny.dart';
import '../../application/state/relation_cheatsheet.dart';
import '../../application/state/visual_settings.dart';
import '../../application/version.dart';
import '../../domain/repositories/catalog_store.dart';
import '../bibliotheque/bibliotheque_screen.dart';
import '../destiny/donnees.dart';
import '../destiny/page.dart';
import '../reglages/grammaire_admin_screen.dart';
import '../reglages/reglages_destiny_screen.dart';
import '../reglages/synchro_screen.dart';
import '../widgets/ecran_sombre.dart';
import 'about_screen.dart';
import 'ai_config_screen.dart';
import 'appearance_screen.dart';
import 'catalog_editor_screen.dart';
import 'contact_screen.dart';
import 'credits_screen.dart';
import 'dilemma_editor_screen.dart';
import 'location_details_screen.dart';
import 'relation_cheatsheet_screen.dart';
import 'tutorial_screen.dart';

/// Les réglages : Destiny, l'IA, l'apparence, les données, l'aide. Les écrans
/// de l'ancienne interface (éditeurs, IA, aide) restent en thème sombre.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    required this.reglages,
    required this.visualSettings,
    required this.catalogStore,
    required this.aiSettings,
    required this.relationCheatsheet,
    required this.locationDetails,
    required this.audioService,
    required this.musicController,
    super.key,
  });

  final ReglagesDestiny reglages;
  final VisualSettings visualSettings;
  final CatalogStore catalogStore;
  final AiSettings aiSettings;
  final RelationCheatsheet relationCheatsheet;
  final LocationDetailsStore locationDetails;
  final AudioService audioService;
  final MusicController musicController;

  void _ouvrir(BuildContext context, Widget page, {bool sombre = false}) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => sombre ? ThemeSombre(child: page) : page));

  @override
  Widget build(BuildContext context) {
    final t = context.textes;
    String k(String x, [Map<String, String> v = const {}]) => t.t('reglages.$x', v);
    Widget entree(IconData icone, String titre, String aide, VoidCallback onTap) => ElementListe(
          titre: titre,
          sousTitre: aide,
          devant: Icon(icone),
          onTap: onTap,
        );

    return ListenableBuilder(
      listenable: Listenable.merge([visualSettings, aiSettings]),
      builder: (context, _) => PageDestiny(
        titre: k('titre'),
        enfants: [
          entree(Icons.flash_on_rounded, k('destiny'), k('destiny_aide'), () => _ouvrir(
                context,
                ReglagesDestinyScreen(reglages: reglages, audio: audioService, musique: musicController),
              )),
          entree(
            Icons.smart_toy_outlined,
            k('ia'),
            aiSettings.configured ? '${aiSettings.provider.label} · ${aiSettings.model}' : k('ia_aide_off'),
            () => _ouvrir(context, AiConfigScreen(settings: aiSettings), sombre: true),
          ),
          entree(Icons.palette_outlined, k('apparence'), k('apparence_aide'),
              () => _ouvrir(context, AppearanceScreen(visualSettings: visualSettings, reglages: reglages))),
          SectionDestiny(titre: k('donnees'), enfants: [
            entree(Icons.tune_rounded, k('catalogue'), k('catalogue_aide'),
                () => _ouvrir(context, CatalogEditorScreen(catalogStore: catalogStore), sombre: true)),
            entree(Icons.place_outlined, k('details_lieux'), k('details_lieux_aide'),
                () => _ouvrir(context, LocationDetailsListScreen(store: locationDetails), sombre: true)),
            entree(Icons.diversity_3_outlined, k('relations'), k('relations_aide'),
                () => _ouvrir(context, RelationCheatsheetScreen(cheatsheet: relationCheatsheet), sombre: true)),
            entree(Icons.balance_outlined, k('dilemmes'), k('dilemmes_aide'),
                () => _ouvrir(context, DilemmaEditorScreen(catalogStore: catalogStore), sombre: true)),
            entree(Icons.sync_rounded, k('synchro'), k('synchro_aide'),
                () => _ouvrir(context, SynchroScreen(catalogue: catalogStore))),
          ]),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.admin_panel_settings_outlined),
            title: Text(k('admin')),
            subtitle: Text(k('admin_aide')),
            value: visualSettings.adminMode,
            onChanged: visualSettings.setAdminMode,
          ),
          if (visualSettings.adminMode)
            entree(Icons.data_object_rounded, k('grammaire'), k('grammaire_aide'),
                () => _ouvrir(
                    context,
                    GrammaireAdminScreen(
                      contexteBibliotheque: ContexteBibliotheque(
                          catalogue: catalogStore, visuels: visualSettings, detailsLieux: locationDetails),
                    ))),
          SectionDestiny(titre: k('aide'), enfants: [
            entree(Icons.school_outlined, k('tutoriel'), k('tutoriel_aide'),
                () => _ouvrir(context, const TutorialScreen(), sombre: true)),
            entree(Icons.alternate_email, k('contact'), k('contact_aide'),
                () => _ouvrir(context, const ContactScreen(), sombre: true)),
            entree(Icons.favorite_border, k('credits'), k('credits_aide'),
                () => _ouvrir(context, const CreditsScreen(), sombre: true)),
            entree(Icons.info_outline, k('a_propos'), k('a_propos_aide'),
                () => _ouvrir(context, const AboutScreen(), sombre: true)),
          ]),
          const SizedBox(height: 8),
          Center(child: Text(k('version', {'version': kVersionAppli}), style: Theme.of(context).textTheme.bodySmall)),
        ],
      ),
    );
  }
}
