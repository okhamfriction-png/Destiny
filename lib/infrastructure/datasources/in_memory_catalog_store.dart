import '../../domain/entities/danger.dart';
import '../../domain/entities/dilemma.dart';
import '../../domain/entities/location.dart';
import '../../domain/repositories/catalog_store.dart';
import 'local_json_datasource.dart';

/// Implémentation en mémoire de [CatalogStore] (web / tests). Seedée depuis le
/// JSON ; les modifications ne survivent pas à un rechargement.
class InMemoryCatalogStore implements CatalogStore {
  InMemoryCatalogStore({required LocalJsonDataSource seedSource})
      : _seed = seedSource;

  final LocalJsonDataSource _seed;
  List<Location>? _locations;
  List<Danger>? _dangers;
  List<Dilemma>? _dilemmas;

  Future<void> _ensure() async {
    if (_locations != null && _dangers != null && _dilemmas != null) return;
    _locations = [...await _seed.loadLocations()];
    _dangers = [...await _seed.loadDangers()];
    _dilemmas = [...await _seed.loadDilemmas()];
  }

  @override
  Future<List<Location>> getLocations() async {
    await _ensure();
    return List.unmodifiable(_locations!);
  }

  @override
  Future<List<Danger>> getDangers() async {
    await _ensure();
    return List.unmodifiable(_dangers!);
  }

  @override
  Future<List<Dilemma>> getDilemmas() async {
    await _ensure();
    return List.unmodifiable(_dilemmas!);
  }

  @override
  Future<void> saveLocation(Location location) async {
    await _ensure();
    final i = _locations!.indexWhere((l) => l.id == location.id);
    if (i >= 0) {
      _locations![i] = location;
    } else {
      _locations!.add(location);
    }
  }

  @override
  Future<void> deleteLocation(String id) async {
    await _ensure();
    _locations!.removeWhere((l) => l.id == id);
  }

  @override
  Future<void> saveDanger(Danger danger) async {
    await _ensure();
    final i = _dangers!.indexWhere((d) => d.id == danger.id);
    if (i >= 0) {
      _dangers![i] = danger;
    } else {
      _dangers!.add(danger);
    }
  }

  @override
  Future<void> deleteDanger(String id) async {
    await _ensure();
    _dangers!.removeWhere((d) => d.id == id);
  }

  @override
  Future<void> saveDilemma(Dilemma dilemma) async {
    await _ensure();
    final i = _dilemmas!.indexWhere((d) => d.id == dilemma.id);
    if (i >= 0) {
      _dilemmas![i] = dilemma;
    } else {
      _dilemmas!.add(dilemma);
    }
  }

  @override
  Future<void> deleteDilemma(String id) async {
    await _ensure();
    _dilemmas!.removeWhere((d) => d.id == id);
  }

  @override
  Future<void> resetToDefaults() async {
    _locations = [...await _seed.loadLocations()];
    _dangers = [...await _seed.loadDangers()];
    _dilemmas = [...await _seed.loadDilemmas()];
  }
}
