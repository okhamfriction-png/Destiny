import '../../domain/repositories/combination_memory.dart';
import '../datasources/in_memory_combination_memory.dart';

/// Implémentation web : pas de SQLite natif, mémoire en RAM.
void configureDatabasePlatform() {
  // Rien à configurer sur le web.
}

CombinationMemory createCombinationMemory() => InMemoryCombinationMemory();
