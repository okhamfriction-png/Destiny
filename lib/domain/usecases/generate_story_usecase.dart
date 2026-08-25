import '../../application/services/random_picker_service.dart';
import '../entities/archetype.dart';
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

    final pickedArchetypes =
        _pickArchetypesWithVariety(archetypes, playerCount);

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

  /// Tire [count] archétypes en garantissant, quand c'est possible, un mélange
  /// de statuts (haut / bas / neutre) — « à chaque histoire, on a de tout ».
  List<Archetype> _pickArchetypesWithVariety(
      List<Archetype> archetypes, int count) {
    final byStatut = <String, List<Archetype>>{};
    for (final a in archetypes) {
      (byStatut[a.statut] ??= <Archetype>[]).add(a);
    }
    // Variété impossible (1 seul joueur ou 1 seul statut) : tirage normal.
    if (count <= 1 || byStatut.length < 2) {
      return _randomPickerService.pickMany(archetypes, count,
          avoidDuplicates: true);
    }
    final chosen = <Archetype>[];
    final chosenIds = <String>{};
    // 1) Un archétype de chaque statut présent (haut, bas, neutre), dans la
    //    limite de count : garantit la diversité.
    for (final s in const ['haut', 'bas', 'neutre']) {
      if (chosen.length >= count) break;
      final pool =
          (byStatut[s] ?? const <Archetype>[]).where((a) => !chosenIds.contains(a.id)).toList();
      if (pool.isEmpty) continue;
      final a = _randomPickerService.pickOne(pool);
      chosen.add(a);
      chosenIds.add(a.id);
    }
    // 2) Complète avec des archétypes aléatoires (tous statuts), sans doublon.
    final rest = archetypes.where((a) => !chosenIds.contains(a.id)).toList();
    if (chosen.length < count && rest.isNotEmpty) {
      chosen.addAll(_randomPickerService.pickMany(rest, count - chosen.length,
          avoidDuplicates: true));
    }
    // 3) Mélange l'ordre pour que le statut ne colle pas aux positions.
    final shuffled = _randomPickerService.pickMany(chosen, chosen.length,
        avoidDuplicates: true);
    return shuffled.take(count).toList(growable: false);
  }
}
