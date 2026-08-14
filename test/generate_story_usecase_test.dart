import 'package:destiny/application/services/random_picker_service.dart';
import 'package:destiny/domain/entities/archetype.dart';
import 'package:destiny/domain/entities/danger.dart';
import 'package:destiny/domain/entities/dilemma.dart';
import 'package:destiny/domain/entities/location.dart';
import 'package:destiny/domain/repositories/combination_memory.dart';
import 'package:destiny/domain/repositories/story_repository.dart';
import 'package:destiny/domain/usecases/generate_story_usecase.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeRepo implements StoryRepository {
  @override
  Future<List<Location>> getLocations() async => const [
        Location(id: 'a', name: 'A', roles: ['r1', 'r2', 'r3']),
        Location(id: 'b', name: 'B', roles: ['r1', 'r2', 'r3']),
      ];

  @override
  Future<List<Danger>> getDangers() async => const [
        Danger(id: 'd1', name: 'D1', style: 'Catastrophe'),
        Danger(id: 'd2', name: 'D2', style: 'Thriller'),
        Danger(id: 'd3', name: 'D3', style: 'Mystère'),
      ];

  @override
  Future<List<Archetype>> getArchetypes() async => const [
        Archetype(id: 'x', name: 'X', traits: 't'),
        Archetype(id: 'y', name: 'Y', traits: 't'),
        Archetype(id: 'z', name: 'Z', traits: 't'),
      ];

  @override
  Future<List<Dilemma>> getDilemmas() async => const [];
}

class _MemFake implements CombinationMemory {
  final Set<String> _used = {};
  int _cycle = 1;

  @override
  Future<int> currentCycle() async => _cycle;

  @override
  Future<void> markUsed(String comboKey) async => _used.add(comboKey);

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
  test('ne tire que les entrées actives', () async {
    final useCase = GenerateStoryUseCase(
      storyRepository: _FakeRepo(),
      randomPickerService: RandomPickerService(),
      combinationMemory: _MemFake(),
    );
    // 3 dangers actifs = cycle de 3.
    final story = await useCase.execute(playerCount: 1);
    expect(story.totalCombos, 3);
    expect(story.players.length, 1);
  });

  test('aucun danger répété avant épuisement, puis nouveau cycle', () async {
    final useCase = GenerateStoryUseCase(
      storyRepository: _FakeRepo(),
      randomPickerService: RandomPickerService(),
      combinationMemory: _MemFake(),
    );

    // 3 dangers : 3 tirages doivent donner 3 dangers distincts.
    final seen = <String>{};
    for (var i = 0; i < 3; i++) {
      final s = await useCase.execute(playerCount: 2);
      expect(seen.contains(s.danger.id), isFalse,
          reason: 'danger répété dans le cycle');
      seen.add(s.danger.id);
      expect(s.cycle, 1);
      expect(s.usedCount, i + 1);
    }
    expect(seen.length, 3);

    // Le 4e tirage déclenche un nouveau cycle.
    final next = await useCase.execute(playerCount: 2);
    expect(next.cycle, 2);
    expect(next.usedCount, 1);
  });
}
