import 'package:destiny/application/services/audio_service.dart';
import 'package:destiny/application/services/llm_service.dart';
import 'package:destiny/application/services/random_picker_service.dart';
import 'package:destiny/application/state/ai_settings.dart';
import 'package:destiny/application/state/campagne_store.dart';
import 'package:destiny/application/state/chat_controller.dart';
import 'package:destiny/application/state/location_details.dart';
import 'package:destiny/application/state/music_controller.dart';
import 'package:destiny/application/state/reglages_destiny.dart';
import 'package:destiny/application/state/troupe_store.dart';
import 'package:destiny/application/state/relation_cheatsheet.dart';
import 'package:destiny/application/state/spectacle_controller.dart';
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

import 'outils/grammaire_partagee.dart';

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
    final grammaire = (await tester.runAsync(chargerGrammaire))!;
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
        grammaire: grammaire,
        audioService: AudioService(),
        visualSettings: VisualSettings(),
        musicController: MusicController(),
        repository: repository,
        combinationMemory: memory,
        catalogStore: catalogStore,
        aiSettings: aiSettings,
        chatController: chatController,
        spectacleController: spectacleController,
        relationCheatsheet: RelationCheatsheet(),
        locationDetails: LocationDetailsStore(),
        campagneStore: CampagneStore(),
        troupeStore: TroupeStore(),
        reglages: ReglagesDestiny(),
      ),
    );

    await tester.pumpAndSettle();
    // L'appli s'ouvre sur Troupe ; les trois onglets sont là.
    final t = grammaire.textes;
    expect(find.text(t.t('navigation.jouer')), findsWidgets);
    expect(find.text(t.t('navigation.troupe')), findsWidgets);
    expect(find.text(t.t('navigation.exercices')), findsWidgets);
    expect(find.text(t.t('troupe.preparer')), findsOneWidget);
    expect(find.text(grammaire.grammaire.promesse), findsWidgets);
  });
}
