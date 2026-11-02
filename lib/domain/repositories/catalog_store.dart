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

  /// Le rapport de la dernière mise à jour avec la grammaire (null s'il n'y
  /// en a pas eu) : ce qui a été mis à jour, et ce qui a été gardé parce que
  /// l'utilisateur l'avait modifié.
  Future<RapportSynchroCatalogue?> dernierRapport();
}

/// Ce que la mise à jour du catalogue avec la grammaire a fait.
class RapportSynchroCatalogue {
  const RapportSynchroCatalogue({
    required this.date,
    required this.dangersMisAJour,
    required this.lieuxMisAJour,
    required this.gardes,
    required this.absents,
    this.sansCorrespondance = const [],
  });

  final DateTime date;
  final int dangersMisAJour;
  final int lieuxMisAJour;

  /// Noms des éléments gardés tels quels (modifiés par l'utilisateur).
  final List<String> gardes;

  /// Noms des éléments de la grammaire absents du catalogue (supprimés par
  /// l'utilisateur) : ils ne reviennent pas.
  final List<String> absents;

  /// Éléments du catalogue de l'appli sans équivalent dans la grammaire
  /// (signalés, jamais choisis seuls).
  final List<String> sansCorrespondance;

  Map<String, dynamic> versJson() => {
        'date': date.toIso8601String(),
        'dangers': dangersMisAJour,
        'lieux': lieuxMisAJour,
        'gardes': gardes,
        'absents': absents,
        'sans_correspondance': sansCorrespondance,
      };

  static RapportSynchroCatalogue? depuisJson(Object? j) {
    if (j is! Map) return null;
    List<String> ls(Object? v) => [for (final x in (v as List? ?? const [])) '$x'];
    return RapportSynchroCatalogue(
      date: DateTime.tryParse('${j['date']}') ?? DateTime.now(),
      dangersMisAJour: (j['dangers'] as num?)?.toInt() ?? 0,
      lieuxMisAJour: (j['lieux'] as num?)?.toInt() ?? 0,
      gardes: ls(j['gardes']),
      absents: ls(j['absents']),
      sansCorrespondance: ls(j['sans_correspondance']),
    );
  }
}
