import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'application/services/audio_service.dart';
import 'application/services/llm_service.dart';
import 'application/services/random_picker_service.dart';
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
import 'domain/repositories/combination_memory.dart';
import 'domain/repositories/story_repository.dart';
import 'domain/usecases/generate_story_usecase.dart';
import 'infrastructure/datasources/grammaire_source.dart';
import 'infrastructure/datasources/local_json_datasource.dart';
import 'infrastructure/platform/catalog_store_factory.dart';
import 'infrastructure/platform/chat_store_factory.dart';
import 'infrastructure/platform/combination_memory_factory.dart';
import 'infrastructure/repositories/story_repository_impl.dart';
import 'presentation/destiny/donnees.dart';
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
  final repository = StoryRepositoryImpl(
    dataSource: dataSource,
    catalogStore: catalogStore,
  );
  final combinationMemory = createCombinationMemory();
  final useCase = GenerateStoryUseCase(
    storyRepository: repository,
    randomPickerService: RandomPickerService(),
    combinationMemory: combinationMemory,
  );
  final audioService = AudioService();
  final visualSettings = VisualSettings();
  final musicController = MusicController();
  final aiSettings = await AiSettings.load();
  final llmService = LlmService();
  final chatController = ChatController(
    chatStore: createChatStore(),
    llm: llmService,
    aiSettings: aiSettings,
    generateStoryUseCase: useCase,
    dataSource: dataSource,
  );
  final spectacleController = SpectacleController(
    repository: repository,
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

  runApp(DestinyApp(
    grammaire: grammaire,
    audioService: audioService,
    visualSettings: visualSettings,
    musicController: musicController,
    repository: repository,
    combinationMemory: combinationMemory,
    catalogStore: catalogStore,
    aiSettings: aiSettings,
    chatController: chatController,
    spectacleController: spectacleController,
    relationCheatsheet: relationCheatsheet,
    locationDetails: locationDetails,
    serieStore: serieStore,
    troupeStore: troupeStore,
    reglages: reglages,
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
              child: Text('BOOT ERROR:\n$message',
                  style: const TextStyle(color: Colors.white, fontSize: 12)),
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
    required this.repository,
    required this.combinationMemory,
    required this.catalogStore,
    required this.aiSettings,
    required this.chatController,
    required this.spectacleController,
    required this.relationCheatsheet,
    required this.locationDetails,
    required this.serieStore,
    required this.troupeStore,
    required this.reglages,
    super.key,
  });

  /// La grammaire de Destiny et les textes de l'appli.
  final GrammaireChargee grammaire;
  final AudioService audioService;
  final VisualSettings visualSettings;
  final MusicController musicController;
  final StoryRepository repository;
  final CombinationMemory combinationMemory;
  final CatalogStore catalogStore;
  final AiSettings aiSettings;
  final ChatController chatController;
  final SpectacleController spectacleController;
  final RelationCheatsheet relationCheatsheet;
  final LocationDetailsStore locationDetails;
  final SerieStore serieStore;
  final TroupeStore troupeStore;
  final ReglagesDestiny reglages;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'DestinyStory',
      theme: themeDestiny(grammaire.grammaire, sombre: false),
      darkTheme: themeDestiny(grammaire.grammaire, sombre: true),
      themeMode: ThemeMode.dark,
      builder: (context, child) => DestinyDonnees(
        grammaire: grammaire.grammaire,
        textes: grammaire.textes,
        child: child ?? const SizedBox.shrink(),
      ),
      home: RootScreen(
        audioService: audioService,
        visualSettings: visualSettings,
        musicController: musicController,
        repository: repository,
        combinationMemory: combinationMemory,
        catalogStore: catalogStore,
        aiSettings: aiSettings,
        chatController: chatController,
        spectacleController: spectacleController,
        relationCheatsheet: relationCheatsheet,
        locationDetails: locationDetails,
        serieStore: serieStore,
        troupeStore: troupeStore,
        reglages: reglages,
      ),
    );
  }
}
