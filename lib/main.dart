import 'dart:convert';

import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'application/son/regie_son.dart';
import 'domain/grammaire/modeles.dart' show Grammaire;
import 'application/services/assistant_jeu.dart';
import 'application/services/audio_service.dart';
import 'application/services/llm_service.dart';
import 'application/state/ai_settings.dart';
import 'application/state/chat_controller.dart';
import 'application/state/location_details.dart';
import 'application/state/music_controller.dart';
import 'application/state/reglages_destiny.dart';
import 'application/state/relation_cheatsheet.dart';
import 'application/state/serie_store.dart';
import 'application/state/spectacle_controller.dart';
import 'application/state/spectacle_store.dart';
import 'application/state/troupe_store.dart';
import 'application/state/visual_settings.dart';
import 'domain/repositories/catalog_store.dart';
import 'infrastructure/datasources/grammaire_source.dart';
import 'infrastructure/datasources/local_json_datasource.dart';
import 'infrastructure/platform/base_de_donnees.dart';
import 'infrastructure/platform/catalog_store_factory.dart';
import 'infrastructure/platform/chat_store_factory.dart';
import 'presentation/destiny/donnees.dart';
import 'presentation/screens/credits_screen.dart';
import 'presentation/screens/root_screen.dart';
import 'presentation/theme/destiny_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Rend visible toute erreur de construction (sinon écran blanc).
  ErrorWidget.builder = (details) => Directionality(
        textDirection: TextDirection.ltr,
        child: Container(
          color: const Color(0xFF1A0000),
          padding: const EdgeInsets.all(24),
          alignment: Alignment.center,
          child: SingleChildScrollView(
            child: Text('BUILD ERROR:\n${details.exceptionAsString()}',
                style: const TextStyle(color: Colors.white, fontSize: 12)),
          ),
        ),
      );

  try {
    await _boot();
  } catch (e, st) {
    runApp(_BootError('$e\n\n$st'));
  }
}

Future<void> _boot() async {
  // Garde l'écran allumé tant que l'app est ouverte (pas de veille pendant
  // une répétition / un spectacle). Sans effet si non supporté.
  try {
    await WakelockPlus.enable();
  } catch (_) {}

  // FFI sur desktop, défaut sur mobile, no-op sur le web.
  configureDatabasePlatform();

  // La grammaire de Destiny : chargée et vérifiée une seule fois.
  final grammaireSource = GrammaireSource();
  final grammaire = await grammaireSource.charger();
  final dataSource = LocalJsonDataSource(grammaire: grammaireSource);
  final catalogStore = createCatalogStore(dataSource);
  final audioService = AudioService();
  final visualSettings = VisualSettings();
  final musicController = MusicController();
  final aiSettings = await AiSettings.load();
  final llmService = LlmService();
  final chatController = ChatController(
    chatStore: createChatStore(),
    llm: llmService,
    aiSettings: aiSettings,
    catalogue: catalogStore,
    grammaire: grammaire,
  );
  final spectacleController = SpectacleController(
    catalogue: catalogStore,
    grammaire: grammaire,
    llm: llmService,
    aiSettings: aiSettings,
    store: SpectacleStore(),
  );
  // Détecte une partie de Spectacle en cours (bouton « Reprendre »).
  await spectacleController.loadSavedSession();

  final relationCheatsheet = RelationCheatsheet();
  final locationDetails = LocationDetailsStore();
  await locationDetails.load();
  final serieStore = SerieStore(llm: llmService, aiSettings: aiSettings);
  await serieStore.charger(grammaire: grammaire.grammaire);
  final reglages = ReglagesDestiny();
  await reglages.charger();
  final troupeStore = TroupeStore();
  await troupeStore.charger();

  final assistantJeu = AssistantJeu(llm: llmService, reglages: aiSettings, grammaire: grammaire.grammaire);

  // La régie son du spectacle : le pack audio importé, ses réglages, la conduite.
  final regieSon = await RegieSon.creer(audio: audioService, musique: musicController, reglagesDestiny: reglages);

  enregistrerLicencesPolices();

  runApp(DestinyApp(
    grammaire: grammaire,
    audioService: audioService,
    visualSettings: visualSettings,
    musicController: musicController,
    catalogStore: catalogStore,
    aiSettings: aiSettings,
    chatController: chatController,
    spectacleController: spectacleController,
    relationCheatsheet: relationCheatsheet,
    locationDetails: locationDetails,
    serieStore: serieStore,
    troupeStore: troupeStore,
    reglages: reglages,
    assistantJeu: assistantJeu,
    regieSon: regieSon,
  ));
}

/// Écran de secours si le démarrage échoue (affiche l'erreur au lieu d'un
/// écran blanc).
class _BootError extends StatelessWidget {
  const _BootError(this.message);
  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF1A0000),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Text('BOOT ERROR:\n$message', style: const TextStyle(color: Colors.white, fontSize: 12)),
            ),
          ),
        ),
      ),
    );
  }
}

class DestinyApp extends StatelessWidget {
  const DestinyApp({
    required this.grammaire,
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
    this.regieSon,
    super.key,
  });

  /// La grammaire de Destiny et les textes de l'appli.
  final GrammaireChargee grammaire;
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
  final RegieSon? regieSon;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: reglages,
      builder: (context, _) => _appli(),
    );
  }

  /// La grammaire, avec les exemples de vouloir changés en mode admin (la
  /// même instance tant qu'ils ne changent pas).
  Grammaire _grammaireDuJour() {
    final surcharges = reglages.exemplesVouloir;
    final cle = jsonEncode(surcharges);
    if (_grammaireCache?.$1 != cle || _grammaireCache?.$2 != grammaire.grammaire) {
      _grammaireCache = (cle, grammaire.grammaire, grammaire.grammaire.avecExemplesVouloir(surcharges));
    }
    return _grammaireCache!.$3;
  }

  static (String, Grammaire, Grammaire)? _grammaireCache;

  Widget _appli() {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'DestinyStory',
      // Sur la version web et sur ordinateur, les listes et les onglets se
      // font aussi glisser à la souris.
      scrollBehavior: const MaterialScrollBehavior().copyWith(dragDevices: PointerDeviceKind.values.toSet()),
      theme: themeDestiny(grammaire.grammaire, sombre: false),
      darkTheme: themeDestiny(grammaire.grammaire, sombre: true),
      themeMode: switch (reglages.theme) {
        ThemeDestiny.sombre => ThemeMode.dark,
        ThemeDestiny.clair => ThemeMode.light,
        ThemeDestiny.auto => ThemeMode.system,
      },
      builder: (context, child) => DestinyDonnees(
        // Les exemples de vouloir changés en mode admin, par-dessus le fichier.
        grammaire: _grammaireDuJour(),
        textes: grammaire.textes,
        child: child ?? const SizedBox.shrink(),
      ),
      home: RootScreen(
        audioService: audioService,
        visualSettings: visualSettings,
        musicController: musicController,
        catalogStore: catalogStore,
        aiSettings: aiSettings,
        chatController: chatController,
        spectacleController: spectacleController,
        relationCheatsheet: relationCheatsheet,
        locationDetails: locationDetails,
        serieStore: serieStore,
        troupeStore: troupeStore,
        reglages: reglages,
        assistantJeu: assistantJeu,
        regieSon: regieSon,
      ),
    );
  }
}
