import 'package:destiny/application/services/audio_service.dart';
import 'package:destiny/application/services/llm_service.dart';
import 'package:destiny/application/services/random_picker_service.dart';
import 'package:destiny/application/state/ai_settings.dart';
import 'package:destiny/application/state/chat_controller.dart';
import 'package:destiny/application/state/generation_history.dart';
import 'package:destiny/application/state/music_controller.dart';
import 'package:destiny/application/state/spectacle_controller.dart';
import 'package:destiny/application/state/spinoff_history.dart';
import 'package:destiny/application/state/story_controller.dart';
import 'package:destiny/application/state/visual_settings.dart';
import 'package:destiny/domain/repositories/combination_memory.dart';
import 'package:destiny/domain/usecases/generate_story_usecase.dart';
import 'package:destiny/infrastructure/datasources/in_memory_catalog_store.dart';
import 'package:destiny/infrastructure/datasources/in_memory_chat_store.dart';
import 'package:destiny/infrastructure/datasources/local_json_datasource.dart';
import 'package:destiny/infrastructure/repositories/story_repository_impl.dart';
import 'package:destiny/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Mémoire en mémoire vive pour les tests (pas de SQLite).
class InMemoryCombinationMemory implements CombinationMemory {
  final Set<String> _used = {};
  int _cycle = 1;

  @override
  Future<int> currentCycle() async => _cycle;

  @override
  Future<void> markUsed(String comboKey) async {
    _used.add(comboKey);
  }

  @override
  Future<int> resetCycle() async {
    _used.clear();
    return ++_cycle;
  }

  @override
  Future<void> reset() async {
    _used.clear();
    _cycle = 1;
  }

  @override
  Future<Set<String>> usedCombos() async => Set.of(_used);
}

void main() {
  testWidgets('Destiny app starts', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final dataSource = LocalJsonDataSource();
    final catalogStore = InMemoryCatalogStore(seedSource: dataSource);
    final repository = StoryRepositoryImpl(
      dataSource: dataSource,
      catalogStore: catalogStore,
    );
    final memory = InMemoryCombinationMemory();
    final useCase = GenerateStoryUseCase(
      storyRepository: repository,
      randomPickerService: RandomPickerService(),
      combinationMemory: memory,
    );
    final controller = StoryController(generateStoryUseCase: useCase);
    final aiSettings = await AiSettings.load();
    final llmService = LlmService();
    final chatController = ChatController(
      chatStore: InMemoryChatStore(),
      llm: llmService,
      aiSettings: aiSettings,
      generateStoryUseCase: useCase,
      dataSource: dataSource,
    );
    final spectacleController = SpectacleController(
      repository: repository,
      llm: llmService,
      aiSettings: aiSettings,
    );

    await tester.pumpWidget(
      DestinyApp(
        controller: controller,
        audioService: AudioService(),
        visualSettings: VisualSettings(),
        musicController: MusicController(),
        repository: repository,
        combinationMemory: memory,
        catalogStore: catalogStore,
        aiSettings: aiSettings,
        chatController: chatController,
        generationHistory: GenerationHistory(),
        spectacleController: spectacleController,
        llm: llmService,
        spinoffHistory: SpinoffHistory(),
      ),
    );

    // Le générateur est l'onglet par défaut : son bouton et sa navigation
    // sont présents au démarrage.
    expect(find.text('Générateur'), findsWidgets);
    expect(find.text('Générer une histoire'), findsOneWidget);
  });
}
