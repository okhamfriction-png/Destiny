import '../../domain/repositories/catalog_store.dart';
import '../datasources/local_json_datasource.dart';
import '../datasources/sqlite_catalog_store.dart';

CatalogStore createCatalogStore(LocalJsonDataSource seedSource) =>
    SqliteCatalogStore(seedSource: seedSource);
