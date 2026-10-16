import 'dart:io';

import 'package:destiny/domain/entities/archetype.dart';
import 'package:destiny/domain/entities/danger.dart';
import 'package:destiny/domain/entities/dilemma.dart';
import 'package:destiny/domain/entities/location.dart';
import 'package:destiny/domain/repositories/combination_memory.dart';
import 'package:destiny/domain/repositories/story_repository.dart';
import 'package:destiny/domain/usecases/constructeur_episode.dart' as dart;
import 'package:destiny/infrastructure/rust/rust_core.dart';
import 'package:destiny/infrastructure/rust/rust_generate_story_usecase.dart';
import 'package:destiny/src/rust/api/destiny.dart' as rust;
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:flutter_test/flutter_test.dart';

/// Librairie compilée sur l'hôte par `cargo build --release` dans `rust/`.
/// Absente : les tests sont sautés (le build mobile passe par cargokit).
final _lib = File(
    'rust/target/release/${Platform.isMacOS ? 'librust_lib_destiny.dylib' : 'librust_lib_destiny.so'}');

class _FakeRepo implements StoryRepository {
  @override
  Future<List<Location>> getLocations() async => const [
        Location(id: 'a', name: 'A', roles: ['r1', 'r2', 'r3']),
        Location(id: 'b', name: 'B', roles: ['r1', 'r2', 'r3']),
        Location(id: 'off', name: 'Off', roles: ['r1'], actif: false),
      ];

  @override
  Future<List<Danger>> getDangers() async => const [
        Danger(id: 'd1', name: 'D1', style: 'Catastrophe'),
        Danger(id: 'd2', name: 'D2', style: 'Thriller'),
        Danger(id: 'd3', name: 'D3', style: 'Mystère'),
      ];

  @override
  Future<List<Archetype>> getArchetypes() async => const [
        Archetype(id: 'x', name: 'X', traits: 't', statut: 'haut'),
        Archetype(id: 'y', name: 'Y', traits: 't', statut: 'bas'),
        Archetype(id: 'z', name: 'Z', traits: 't'),
      ];

  @override
  Future<List<Dilemma>> getDilemmas() async => const [
        Dilemma(
            id: 'dl',
            nom: 'Dl',
            sourceReelle: '',
            moteur: '',
            dangerLie: 'd2',
            situation: '',
            choixA: '',
            choixB: ''),
      ];
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
  final skip = _lib.existsSync() ? false : 'cargo build --release dans rust/';

  setUpAll(() async {
    if (_lib.existsSync()) {
      await RustCore.init(externalLibrary: ExternalLibrary.open(_lib.path));
    }
  });

  test('le cœur Rust est chargé', () {
    expect(RustCore.isReady, isTrue);
  }, skip: skip);

  test('Rust : aucun danger répété avant épuisement, puis nouveau cycle',
      () async {
    final memory = _MemFake();
    final useCase = RustGenerateStoryUseCase(
        storyRepository: _FakeRepo(), combinationMemory: memory);
    final seen = <String>{};
    for (var i = 0; i < 3; i++) {
      final s = await useCase.execute(playerCount: 3);
      expect(seen.add(s.danger.id), isTrue, reason: 'danger répété');
      expect(s.location.id, isNot('off'));
      expect(s.cycle, 1);
      expect(s.usedCount, i + 1);
      expect(s.players.map((p) => p.archetype.statut).toSet(),
          {'haut', 'bas', 'neutre'});
    }
    final next = await useCase.execute(playerCount: 2);
    expect(next.cycle, 2);
    expect(next.usedCount, 1);
    expect(await memory.usedCombos(), {next.danger.id});
  }, skip: skip);

  test('Rust : mode Dilemme et erreurs', () async {
    final useCase = RustGenerateStoryUseCase(
        storyRepository: _FakeRepo(), combinationMemory: _MemFake());
    final s = await useCase.execute(playerCount: 2, dilemma: true);
    expect(s.dilemma?.id, 'dl');
    expect(s.danger.id, 'd2');
    expect(() => useCase.execute(playerCount: 11), throwsArgumentError);
  }, skip: skip);

  test('Rust et Dart donnent les mêmes horaires de présages', () {
    for (final duree in [30000, 90000, 5 * 60000, 12 * 60000, 47 * 60000]) {
      for (var n = 0; n <= 8; n++) {
        for (final iv in [null, 45000, 3 * 60000]) {
          expect(
            rust
                .horairesDesPresages(
                    dureeMs: duree, nombre: n, intervalleMs: iv)
                .map((h) => h.toInt())
                .toList(),
            dart.horairesDesPresages(duree, n, intervalleMs: iv),
            reason: 'durée $duree, $n présages, intervalle $iv',
          );
        }
      }
    }
  }, skip: skip);
}
