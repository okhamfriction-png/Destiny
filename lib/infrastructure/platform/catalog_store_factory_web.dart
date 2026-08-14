import '../../domain/repositories/catalog_store.dart';
import '../datasources/in_memory_catalog_store.dart';
import '../datasources/local_json_datasource.dart';

CatalogStore createCatalogStore(LocalJsonDataSource seedSource) =>
    InMemoryCatalogStore(seedSource: seedSource);
