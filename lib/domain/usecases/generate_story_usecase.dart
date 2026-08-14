import '../../application/services/random_picker_service.dart';
import '../entities/player_assignment.dart';
import '../entities/story.dart';
import '../repositories/combination_memory.dart';
import '../repositories/story_repository.dart';

class GenerateStoryUseCase {
  GenerateStoryUseCase({
    required StoryRepository storyRepository,
    required RandomPickerService randomPickerService,
    required CombinationMemory combinationMemory,
  })  : _storyRepository = storyRepository,
        _randomPickerService = randomPickerService,
        _combinationMemory = combinationMemory;

  final StoryRepository _storyRepository;
  final RandomPickerService _randomPickerService;
  final CombinationMemory _combinationMemory;

  Future<Story> execute({
    required int playerCount,
    bool dilemma = false,
  }) async {
    if (playerCount < 1 || playerCount > 10) {
      throw ArgumentError.value(
          playerCount, 'playerCount', 'Must be between 1 and 10.');
    }

    final allLocations = await _storyRepository.getLocations();
    final allDangers = await _storyRepository.getDangers();
    final archetypes = await _storyRepository.getArchetypes();

    final locations =
        allLocations.where((l) => l.actif).toList(growable: false);
    final dangers = allDangers.where((d) => d.actif).toList(growable: false);

    if (locations.isEmpty || dangers.isEmpty || archetypes.isEmpty) {
      throw StateError('Missing required local data to generate a story.');
    }

    // Mode Dilemme : on tire un dilemme réel + son danger lié + un lieu libre.
    if (dilemma) {
      final all = await _storyRepository.getDilemmas();
      if (all.isNotEmpty) {
        final d = _randomPickerService.pickOne(all);
        final linked = allDangers.where((x) => x.id == d.dangerLie);
        final theDanger = linked.isNotEmpty
            ? linked.first
            : _randomPickerService.pickOne(dangers);
        return Story(
          location: _randomPickerService.pickOne(locations),
          danger: theDanger,
          players: const [],
          dilemma: d,
          cycle: await _combinationMemory.currentCycle(),
          usedCount: 0,
          totalCombos: dangers.length,
        );
      }
    }

    // On fait défiler TOUS les dangers avant d'en reprendre un (cycle de la
    // taille du nombre de dangers actifs, ~30). Le lieu, lui, est libre.
    final totalDangers = dangers.length;

    var used = await _combinationMemory.usedCombos();
    var cycle = await _combinationMemory.currentCycle();

    var remaining =
        dangers.where((d) => !used.contains(d.id)).toList(growable: false);

    if (remaining.isEmpty) {
      // Tous les dangers ont été vus : nouveau cycle.
      cycle = await _combinationMemory.resetCycle();
      used = <String>{};
      remaining = dangers;
    }

    final danger = _randomPickerService.pickOne(remaining);
    await _combinationMemory.markUsed(danger.id);

    final location = _randomPickerService.pickOne(locations);

    final usedCount = totalDangers - remaining.length + 1;

    final pickedArchetypes = _randomPickerService.pickMany(
      archetypes,
      playerCount,
      avoidDuplicates: true,
    );

    final pickedRoles = _randomPickerService.pickMany(
      location.roles,
      playerCount,
      avoidDuplicates: true,
    );

    final players = List<PlayerAssignment>.generate(
      playerCount,
      (index) => PlayerAssignment(
        playerIndex: index + 1,
        archetype: pickedArchetypes[index],
        role: pickedRoles[index],
      ),
      growable: false,
    );

    return Story(
      location: location,
      danger: danger,
      players: players,
      cycle: cycle,
      usedCount: usedCount,
      totalCombos: totalDangers,
    );
  }
}
