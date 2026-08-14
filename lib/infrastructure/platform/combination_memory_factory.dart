import '../../domain/repositories/combination_memory.dart';
import 'combination_memory_factory_io.dart'
    if (dart.library.html) 'combination_memory_factory_web.dart' as impl;

/// Configure le moteur de base de données selon la plateforme courante
/// (FFI sur desktop, défaut sur mobile, no-op sur le web).
void configureDatabasePlatform() => impl.configureDatabasePlatform();

/// Construit l'implémentation de [CombinationMemory] adaptée à la plateforme
/// (SQLite sur mobile/desktop, en mémoire sur le web).
CombinationMemory createCombinationMemory() => impl.createCombinationMemory();
