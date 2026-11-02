import '../../domain/entities/danger.dart';
import '../../domain/entities/dilemma.dart';
import '../../domain/entities/location.dart';
import '../../domain/repositories/catalog_store.dart';
import '../../domain/repositories/story_repository.dart';

class StoryRepositoryImpl implements StoryRepository {
  StoryRepositoryImpl({required CatalogStore catalogStore}) : _catalogStore = catalogStore;

  final CatalogStore _catalogStore;

  // Lieux et dangers proviennent du catalogue éditable et persistant.
  @override
  Future<List<Location>> getLocations() => _catalogStore.getLocations();

  @override
  Future<List<Danger>> getDangers() => _catalogStore.getDangers();

  // Les dilemmes proviennent du catalogue éditable et persistant
  // (seedé depuis le JSON, puis complété par danger depuis les paramètres).
  @override
  Future<List<Dilemma>> getDilemmas() => _catalogStore.getDilemmas();
}
