import 'package:flutter/foundation.dart';

import '../../domain/entities/story.dart';
import '../../domain/usecases/generate_story_usecase.dart';
import 'generation_history.dart';
import 'last_generation_store.dart';
import 'story_state.dart';

class StoryController extends ChangeNotifier {
  StoryController({
    required GenerateStoryUseCase generateStoryUseCase,
    this.history,
    this.lastStore,
  }) : _generateStoryUseCase = generateStoryUseCase;

  final GenerateStoryUseCase _generateStoryUseCase;
  final GenerationHistory? history;
  final LastGenerationStore? lastStore;

  StoryState _state = StoryState.initial();
  StoryState get state => _state;

  /// Restaure la dernière scène générée (au démarrage), si disponible.
  Future<void> restoreLast() async {
    final store = lastStore;
    if (store == null) return;
    // Ne pas écraser une scène déjà générée dans cette session.
    if (_state.story != null) return;
    final last = await store.load();
    if (last == null || _state.story != null) return;
    _state = _state.copyWith(
      status: StoryStatus.success,
      story: last.story,
      mode: last.mode,
      clearError: true,
    );
    notifyListeners();
  }

  void updatePlayerCount(double value) {
    _state = _state.copyWith(
      playerCount: value.round(),
      clearError: true,
    );
    notifyListeners();
  }

  void setMode(GeneratorMode mode) {
    _state = _state.copyWith(mode: mode, clearStory: true, clearError: true);
    notifyListeners();
  }

  /// Affiche une scène donnée (ex. rechargée depuis l'historique).
  void showStory(Story story, GeneratorMode mode) {
    _state = _state.copyWith(
      status: StoryStatus.success,
      story: story,
      mode: mode,
      clearError: true,
    );
    lastStore?.save(story, mode);
    notifyListeners();
  }

  /// Génère une scène. Rue & Dilemme : 1 « héros », pas de liens.
  Future<void> generateStory() async {
    _state = _state.copyWith(status: StoryStatus.loading, clearError: true);
    notifyListeners();

    final solo = _state.rueMode || _state.dilemmaMode;
    try {
      final story = await _generateStoryUseCase.execute(
        playerCount: solo ? 1 : _state.playerCount,
        dilemma: _state.dilemmaMode,
      );
      _state = _state.copyWith(
        status: StoryStatus.success,
        story: story,
        clearError: true,
      );
      history?.add(GenerationRecord.fromStory(story,
          rue: _state.rueMode, mode: _state.mode.name));
      // Conserve la dernière scène pour la restaurer au redémarrage.
      lastStore?.save(story, _state.mode);
    } catch (_) {
      _state = _state.copyWith(
        status: StoryStatus.error,
        errorMessage:
            'Impossible de générer une histoire. Vérifie les données locales.',
      );
    }

    notifyListeners();
  }

  Future<void> reroll() => generateStory();

  void reset() {
    _state = _state.copyWith(clearStory: true, clearError: true);
    lastStore?.clear();
    notifyListeners();
  }
}
