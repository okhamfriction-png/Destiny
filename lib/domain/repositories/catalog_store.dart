import '../entities/danger.dart';
import '../entities/dilemma.dart';
import '../entities/location.dart';

/// Stockage éditable et persistant des lieux, dangers & dilemmes. Initialisé
/// (seedé) à partir des données JSON embarquées au premier lancement, puis
/// modifiable depuis les paramètres.
abstract class CatalogStore {
  Future<List<Location>> getLocations();
  Future<List<Danger>> getDangers();
  Future<List<Dilemma>> getDilemmas();

  /// Insère ou met à jour un lieu (par `id`).
  Future<void> saveLocation(Location location);
  Future<void> deleteLocation(String id);

  /// Insère ou met à jour un danger (par `id`).
  Future<void> saveDanger(Danger danger);
  Future<void> deleteDanger(String id);

  /// Insère ou met à jour un dilemme (par `id`).
  Future<void> saveDilemma(Dilemma dilemma);
  Future<void> deleteDilemma(String id);

  /// Restaure les listes par défaut (depuis le JSON embarqué).
  Future<void> resetToDefaults();
}
