import 'package:flutter/material.dart';

import '../../application/services/assistant_jeu.dart';
import '../../application/services/audio_service.dart';
import '../../application/state/ai_settings.dart';
import '../../application/state/chat_controller.dart';
import '../../application/state/location_details.dart';
import '../../application/state/music_controller.dart';
import '../../application/state/reglages_destiny.dart';
import '../../application/state/relation_cheatsheet.dart';
import '../../application/state/serie_store.dart';
import '../../application/state/spectacle_controller.dart';
import '../../application/state/troupe_store.dart';
import '../../application/state/visual_settings.dart';
import '../../domain/repositories/catalog_store.dart';
import '../accueil/decouvrir_screen.dart';
import '../bibliotheque/bibliotheque_screen.dart';
import '../destiny/donnees.dart';
import '../exercices/exercices_screen.dart';
import '../jouer/jouer_screen.dart';
import '../serie/contexte_serie.dart';
import '../theme/destiny_theme.dart';
import '../troupe/troupe_screen.dart';
import '../widgets/ecran_sombre.dart';
import 'music_screen.dart';
import 'settings_screen.dart';

/// Les trois onglets : Jouer · Troupe · Exercices. L'appli s'ouvre sur
/// Troupe. La Bibliothèque, la musique et les réglages sont de petits boutons.
class RootScreen extends StatefulWidget {
  const RootScreen({
    required this.audioService,
    required this.visualSettings,
    required this.musicController,
    required this.catalogStore,
    required this.aiSettings,
    required this.chatController,
    required this.spectacleController,
    required this.relationCheatsheet,
    required this.locationDetails,
    required this.serieStore,
    required this.troupeStore,
    required this.reglages,
    this.assistantJeu,
    super.key,
  });

  final AudioService audioService;
  final VisualSettings visualSettings;
  final MusicController musicController;
  final CatalogStore catalogStore;
  final AiSettings aiSettings;
  final ChatController chatController;
  final SpectacleController spectacleController;
  final RelationCheatsheet relationCheatsheet;
  final LocationDetailsStore locationDetails;
  final SerieStore serieStore;
  final TroupeStore troupeStore;
  final ReglagesDestiny reglages;
  final AssistantJeu? assistantJeu;

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  /// 0 Jouer · 1 Troupe · 2 Exercices.
  int _index = 1;

  void _ouvrir(Widget page) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

  @override
  void initState() {
    super.initState();
    // Au premier lancement, « Découvrir Destiny ». Vu une fois, même passé.
    if (!widget.reglages.decouverteVue) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context)
            .push(MaterialPageRoute<void>(fullscreenDialog: true, builder: (_) => const DecouvrirScreen()))
            .then((_) => widget.reglages.changer(decouverteVue: true));
      });
    }
  }

  ContexteBibliotheque get _contexteBibliotheque => ContexteBibliotheque(
        catalogue: widget.catalogStore,
        visuels: widget.visualSettings,
        detailsLieux: widget.locationDetails,
        univers: widget.serieStore.catalogue,
      );

  void _ouvrirBibliotheque() => _ouvrir(BibliothequeScreen(contexte: _contexteBibliotheque));

  void _ouvrirMusique() => _ouvrir(ThemeSombre(
        child: Scaffold(
          appBar: AppBar(title: Text(context.textes.t('navigation.musique'))),
          body: MusicScreen(controller: widget.musicController),
        ),
      ));

  void _ouvrirReglages() => _ouvrir(SettingsScreen(
        reglages: widget.reglages,
        visualSettings: widget.visualSettings,
        catalogStore: widget.catalogStore,
        aiSettings: widget.aiSettings,
        relationCheatsheet: widget.relationCheatsheet,
        locationDetails: widget.locationDetails,
        audioService: widget.audioService,
        musicController: widget.musicController,
      ));

  @override
  Widget build(BuildContext context) {
    final t = context.textes;
    final c = context.destiny;
    final contexteTroupe = ContexteTroupe(
      store: widget.troupeStore,
      reglages: widget.reglages,
      catalogue: widget.catalogStore,
      audio: widget.audioService,
      musique: widget.musicController,
      visuels: widget.visualSettings,
      relations: widget.relationCheatsheet,
      detailsLieux: widget.locationDetails,
      ia: widget.assistantJeu,
    );
    final pages = [
      JouerScreen(
        serie: ContexteSerie(
          store: widget.serieStore,
          reglages: widget.reglages,
          catalogue: widget.catalogStore,
          audio: widget.audioService,
          musique: widget.musicController,
          visuels: widget.visualSettings,
          ia: widget.assistantJeu,
        ),
        chatController: widget.chatController,
        spectacleController: widget.spectacleController,
        audioService: widget.audioService,
        visualSettings: widget.visualSettings,
        musicController: widget.musicController,
      ),
      TroupeScreen(
        contexte: contexteTroupe,
        versJouer: () => setState(() => _index = 0),
        versExercices: () => setState(() => _index = 2),
        versBibliotheque: _ouvrirBibliotheque,
      ),
      ExercicesScreen(audioService: widget.audioService, bibliotheque: _contexteBibliotheque),
    ];

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 52,
        title: Text(
          t.t('navigation.${['jouer', 'troupe', 'exercices'][_index]}'),
          style: TextStyle(fontFamily: kPoliceTitres, fontWeight: FontWeight.w900, color: c.titre),
        ),
        actions: [
          _PetitBouton(
              icon: Icons.menu_book_rounded, tooltip: t.t('navigation.bibliotheque'), onPressed: _ouvrirBibliotheque),
          _PetitBouton(
              icon: Icons.library_music_outlined, tooltip: t.t('navigation.musique'), onPressed: _ouvrirMusique),
          _PetitBouton(icon: Icons.settings_outlined, tooltip: t.t('navigation.reglages'), onPressed: _ouvrirReglages),
          _BoutonSon(audioService: widget.audioService, musicController: widget.musicController),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: IndexedStack(index: _index, children: pages),
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          NavigationDestination(
              icon: const Icon(Icons.auto_stories_outlined),
              selectedIcon: const Icon(Icons.auto_stories),
              label: t.t('navigation.jouer')),
          NavigationDestination(
              icon: const Icon(Icons.theater_comedy_outlined),
              selectedIcon: const Icon(Icons.theater_comedy),
              label: t.t('navigation.troupe')),
          NavigationDestination(
              icon: const Icon(Icons.self_improvement_outlined),
              selectedIcon: const Icon(Icons.self_improvement),
              label: t.t('navigation.exercices')),
        ],
      ),
    );
  }
}

class _PetitBouton extends StatelessWidget {
  const _PetitBouton({required this.icon, required this.tooltip, required this.onPressed});

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) =>
      IconButton(icon: Icon(icon, size: 22), tooltip: tooltip, onPressed: onPressed);
}

/// Coupe ou remet le son (effets et musique).
class _BoutonSon extends StatefulWidget {
  const _BoutonSon({required this.audioService, required this.musicController});

  final AudioService audioService;
  final MusicController musicController;

  @override
  State<_BoutonSon> createState() => _BoutonSonState();
}

class _BoutonSonState extends State<_BoutonSon> {
  @override
  void initState() {
    super.initState();
    widget.musicController.addListener(_changement);
  }

  @override
  void dispose() {
    widget.musicController.removeListener(_changement);
    super.dispose();
  }

  void _changement() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final actif = !widget.audioService.muted || widget.musicController.playing;
    return _PetitBouton(
      icon: actif ? Icons.volume_up_rounded : Icons.volume_off_rounded,
      tooltip: context.textes.t('navigation.son'),
      onPressed: () => setState(() {
        if (actif) {
          widget.audioService.setMuted(true);
          widget.musicController.stop();
        } else {
          widget.audioService.setMuted(false);
        }
      }),
    );
  }
}
