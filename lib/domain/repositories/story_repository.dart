import '../entities/archetype.dart';
import '../entities/danger.dart';
import '../entities/dilemma.dart';
import '../entities/location.dart';

abstract class StoryRepository {
  Future<List<Location>> getLocations();

  Future<List<Danger>> getDangers();

  Future<List<Archetype>> getArchetypes();

  /// Dilemmes moraux (mode Dilemme).
  Future<List<Dilemma>> getDilemmas();
}
