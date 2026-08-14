import '../../domain/repositories/catalog_store.dart';
import '../datasources/local_json_datasource.dart';
import 'catalog_store_factory_io.dart'
    if (dart.library.html) 'catalog_store_factory_web.dart' as impl;

/// Construit le [CatalogStore] adapté à la plateforme (SQLite persistant sur
/// mobile/desktop, en mémoire sur le web).
CatalogStore createCatalogStore(LocalJsonDataSource seedSource) =>
    impl.createCatalogStore(seedSource);
