import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart'
    show AnyhowException;

import '../../application/services/random_picker_service.dart';
import '../../domain/entities/danger.dart';
import '../../domain/entities/dilemma.dart';
import '../../domain/entities/location.dart';
import '../../domain/entities/player_assignment.dart';
import '../../domain/entities/story.dart';
import '../../domain/repositories/combination_memory.dart';
import '../../domain/repositories/story_repository.dart';
import '../../domain/usecases/generate_story_usecase.dart';
import '../../src/rust/api/destiny.dart' as rust;
import '../../src/rust/models.dart' as rs;
import 'rust_core.dart';

/// [GenerateStoryUseCase] dont le tirage est fait par le cœur Rust.
///
/// Dart garde le catalogue et la mémoire SQLite ; Rust reçoit l'état, tire
/// l'histoire et dit quoi écrire en mémoire. Sans cœur Rust (web, librairie
/// absente), on retombe sur l'implémentation Dart d'origine.
class RustGenerateStoryUseCase extends GenerateStoryUseCase {
  RustGenerateStoryUseCase({
    required StoryRepository storyRepository,
    required CombinationMemory combinationMemory,
    RandomPickerService? randomPickerService,
  })  : _storyRepository = storyRepository,
        _combinationMemory = combinationMemory,
        super(
          storyRepository: storyRepository,
          randomPickerService: randomPickerService ?? RandomPickerService(),
          combinationMemory: combinationMemory,
        );

  final StoryRepository _storyRepository;
  final CombinationMemory _combinationMemory;

  @override
  Future<Story> execute({
    required int playerCount,
    bool dilemma = false,
  }) async {
    if (!RustCore.isReady) {
      return super.execute(playerCount: playerCount, dilemma: dilemma);
    }

    final locations = await _storyRepository.getLocations();
    final dangers = await _storyRepository.getDangers();
    final archetypes = await _storyRepository.getArchetypes();
    final dilemmas =
        dilemma ? await _storyRepository.getDilemmas() : const <Dilemma>[];

    final rs.Generation g;
    try {
      g = rust.generateStory(
        locations: [for (final l in locations) _location(l)],
        dangers: [for (final d in dangers) _danger(d)],
        archetypes: [
          for (final a in archetypes)
            rs.Archetype(id: a.id, name: a.name, statut: a.statut),
        ],
        dilemmas: [
          for (final d in dilemmas)
            rs.Dilemma(id: d.id, nom: d.nom, dangerLie: d.dangerLie),
        ],
        memory: rs.MemoryState(
          usedDangerIds: (await _combinationMemory.usedCombos()).toList(),
          cycle: await _combinationMemory.currentCycle(),
        ),
        playerCount: playerCount,
        dilemma: dilemma,
      );
    } on AnyhowException catch (e) {
      // Mêmes types d'erreur que l'implémentation Dart.
      if (playerCount < 1 || playerCount > 10) {
        throw ArgumentError.value(playerCount, 'playerCount', e.message);
      }
      throw StateError(e.message);
    }

    if (g.memory.resetCycle) await _combinationMemory.resetCycle();
    final used = g.memory.markUsed;
    if (used != null) await _combinationMemory.markUsed(used);

    final s = g.story;
    final archetypesById = {for (final a in archetypes) a.id: a};
    return Story(
      location: locations.firstWhere((l) => l.id == s.locationId),
      danger: dangers.firstWhere((d) => d.id == s.dangerId),
      players: [
        for (final p in s.players)
          PlayerAssignment(
            playerIndex: p.playerIndex,
            archetype: archetypesById[p.archetypeId]!,
            role: p.role,
          ),
      ],
      dilemma: s.dilemmaId == null
          ? null
          : dilemmas.firstWhere((d) => d.id == s.dilemmaId),
      cycle: s.cycle,
      usedCount: s.usedCount,
      totalCombos: s.totalCombos,
    );
  }

  static rs.Location _location(Location l) => rs.Location(
        id: l.id,
        name: l.name,
        roles: l.roles,
        rue: l.rue,
        actif: l.actif,
      );

  static rs.Danger _danger(Danger d) => rs.Danger(
        id: d.id,
        name: d.name,
        style: d.style,
        rue: d.rue,
        theatre: d.theatre,
        actif: d.actif,
        paliers: d.paliers,
      );
}
