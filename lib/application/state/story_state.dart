import '../../domain/entities/story.dart';

enum StoryStatus { idle, loading, success, error }

/// Mode du générateur.
enum GeneratorMode { histoire, rue, dilemme, spinoff }

class StoryState {
  const StoryState({
    required this.playerCount,
    required this.status,
    this.story,
    this.errorMessage,
    this.mode = GeneratorMode.histoire,
  });

  factory StoryState.initial() {
    return const StoryState(
      playerCount: 3,
      status: StoryStatus.idle,
    );
  }

  final int playerCount;
  final StoryStatus status;
  final Story? story;
  final String? errorMessage;

  /// Mode courant : Histoire (joueurs), Rue (lieu+danger), Dilemme.
  final GeneratorMode mode;

  bool get rueMode => mode == GeneratorMode.rue;
  bool get dilemmaMode => mode == GeneratorMode.dilemme;

  StoryState copyWith({
    int? playerCount,
    StoryStatus? status,
    Story? story,
    String? errorMessage,
    GeneratorMode? mode,
    bool clearStory = false,
    bool clearError = false,
  }) {
    return StoryState(
      playerCount: playerCount ?? this.playerCount,
      status: status ?? this.status,
      story: clearStory ? null : (story ?? this.story),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      mode: mode ?? this.mode,
    );
  }
}
