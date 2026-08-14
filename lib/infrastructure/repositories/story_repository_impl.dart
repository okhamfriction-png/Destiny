import '../../domain/entities/archetype.dart';
import '../../domain/entities/danger.dart';
import '../../domain/entities/dilemma.dart';
import '../../domain/entities/location.dart';
import '../../domain/repositories/catalog_store.dart';
import '../../domain/repositories/story_repository.dart';
import '../datasources/local_json_datasource.dart';

class StoryRepositoryImpl implements StoryRepository {
  StoryRepositoryImpl({
    required LocalJsonDataSource dataSource,
    required CatalogStore catalogStore,
  })  : _dataSource = dataSource,
        _catalogStore = catalogStore;

  final LocalJsonDataSource _dataSource;
  final CatalogStore _catalogStore;

  // Lieux et dangers proviennent du catalogue éditable et persistant.
  @override
  Future<List<Location>> getLocations() => _catalogStore.getLocations();

  @override
  Future<List<Danger>> getDangers() => _catalogStore.getDangers();

  // Les archétypes restent chargés depuis le JSON embarqué (non éditables).
  @override
  Future<List<Archetype>> getArchetypes() => _dataSource.loadArchetypes();

  // Les dilemmes proviennent du catalogue éditable et persistant
  // (seedé depuis le JSON, puis complété par danger depuis les paramètres).
  @override
  Future<List<Dilemma>> getDilemmas() => _catalogStore.getDilemmas();
}
