import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'application/services/audio_service.dart';
import 'application/services/llm_service.dart';
import 'application/services/random_picker_service.dart';
import 'application/state/ai_settings.dart';
import 'application/state/chat_controller.dart';
import 'application/state/generation_history.dart';
import 'application/state/guide_content.dart';
import 'application/state/last_generation_store.dart';
import 'application/state/location_details.dart';
import 'application/state/music_controller.dart';
import 'application/state/relation_cheatsheet.dart';
import 'application/state/tracking_store.dart';
import 'application/state/spectacle_controller.dart';
import 'application/state/spectacle_store.dart';
import 'application/state/spinoff_history.dart';
import 'application/state/story_controller.dart';
import 'application/state/visual_settings.dart';
import 'domain/repositories/catalog_store.dart';
import 'domain/repositories/combination_memory.dart';
import 'domain/repositories/story_repository.dart';
import 'domain/usecases/generate_story_usecase.dart';
import 'infrastructure/datasources/local_json_datasource.dart';
import 'infrastructure/platform/catalog_store_factory.dart';
import 'infrastructure/platform/chat_store_factory.dart';
import 'infrastructure/platform/combination_memory_factory.dart';
import 'infrastructure/repositories/story_repository_impl.dart';
import 'presentation/screens/root_screen.dart';
import 'presentation/theme/app_theme.dart';

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

  final dataSource = LocalJsonDataSource();
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
  final generationHistory = GenerationHistory();
  final spinoffHistory = SpinoffHistory();
  final lastGenerationStore = LastGenerationStore();
  final controller = StoryController(
    generateStoryUseCase: useCase,
    history: generationHistory,
    lastStore: lastGenerationStore,
  );
  // Restaure la dernière scène générée (histoire / rue / dilemme).
  await controller.restoreLast();
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

  // Briques « univers Destiny » : Guide, tableaux de suivi, antisèche, lieux.
  final guideContent = GuideContent();
  final trackingStore = TrackingStore();
  final relationCheatsheet = RelationCheatsheet();
  final locationDetails = LocationDetailsStore();
  await locationDetails.load();

  runApp(DestinyApp(
    controller: controller,
    audioService: audioService,
    visualSettings: visualSettings,
    musicController: musicController,
    repository: repository,
    combinationMemory: combinationMemory,
    catalogStore: catalogStore,
    aiSettings: aiSettings,
    chatController: chatController,
    generationHistory: generationHistory,
    spectacleController: spectacleController,
    llm: llmService,
    spinoffHistory: spinoffHistory,
    guideContent: guideContent,
    trackingStore: trackingStore,
    relationCheatsheet: relationCheatsheet,
    locationDetails: locationDetails,
  ));
}

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
    required this.controller,
    required this.audioService,
    required this.visualSettings,
    required this.musicController,
    required this.repository,
    required this.combinationMemory,
    required this.catalogStore,
    required this.aiSettings,
    required this.chatController,
    required this.generationHistory,
    required this.spectacleController,
    required this.llm,
    required this.spinoffHistory,
    required this.guideContent,
    required this.trackingStore,
    required this.relationCheatsheet,
    required this.locationDetails,
    super.key,
  });

  final StoryController controller;
  final AudioService audioService;
  final VisualSettings visualSettings;
  final MusicController musicController;
  final StoryRepository repository;
  final CombinationMemory combinationMemory;
  final CatalogStore catalogStore;
  final AiSettings aiSettings;
  final ChatController chatController;
  final GenerationHistory generationHistory;
  final SpectacleController spectacleController;
  final LlmService llm;
  final SpinoffHistory spinoffHistory;
  final GuideContent guideContent;
  final TrackingStore trackingStore;
  final RelationCheatsheet relationCheatsheet;
  final LocationDetailsStore locationDetails;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Destiny',
      theme: AppTheme.darkCinematic,
      home: RootScreen(
        controller: controller,
        audioService: audioService,
        visualSettings: visualSettings,
        musicController: musicController,
        repository: repository,
        combinationMemory: combinationMemory,
        catalogStore: catalogStore,
        aiSettings: aiSettings,
        chatController: chatController,
        generationHistory: generationHistory,
        spectacleController: spectacleController,
        llm: llm,
        spinoffHistory: spinoffHistory,
        guideContent: guideContent,
        trackingStore: trackingStore,
        relationCheatsheet: relationCheatsheet,
        locationDetails: locationDetails,
      ),
    );
  }
}
