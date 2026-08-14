import '../../domain/repositories/combination_memory.dart';

/// Implémentation en mémoire vive de [CombinationMemory].
///
/// Utilisée sur le web (où SQLite n'est pas disponible sans configuration
/// WASM) et dans les tests. La mémoire n'est pas persistée entre deux
/// lancements de l'application.
class InMemoryCombinationMemory implements CombinationMemory {
  final Set<String> _used = <String>{};
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
