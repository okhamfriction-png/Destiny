import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../../domain/entities/danger.dart';
import '../../domain/entities/dilemma.dart';
import '../../domain/entities/location.dart';
import '../../domain/repositories/catalog_store.dart';
import 'local_json_datasource.dart';

/// Implémentation SQLite, persistante, de [CatalogStore].
class SqliteCatalogStore implements CatalogStore {
  SqliteCatalogStore({
    required LocalJsonDataSource seedSource,
    this.databaseName = 'destiny_catalog.db',
  }) : _seed = seedSource;

  final LocalJsonDataSource _seed;
  final String databaseName;
  Database? _db;

  Future<Database> _database() async {
    final existing = _db;
    if (existing != null) return existing;

    final dir = await getApplicationSupportDirectory();
    final path = p.join(dir.path, databaseName);

    final db = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 4,
        onCreate: (db, version) async {
          await db.execute(
            'CREATE TABLE locations ('
            'id TEXT PRIMARY KEY, name TEXT NOT NULL, roles TEXT NOT NULL, '
            'rue INTEGER NOT NULL, actif INTEGER NOT NULL, sort INTEGER NOT NULL)',
          );
          await db.execute(
            'CREATE TABLE dangers ('
            'id TEXT PRIMARY KEY, name TEXT NOT NULL, style TEXT NOT NULL, '
            'rue INTEGER NOT NULL, theatre INTEGER NOT NULL, '
            'actif INTEGER NOT NULL, paliers TEXT NOT NULL DEFAULT \'[]\', '
            'sort INTEGER NOT NULL)',
          );
          await db.execute(_createDilemmasSql);
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            await db.execute(
                'ALTER TABLE dangers ADD COLUMN theatre INTEGER NOT NULL DEFAULT 1');
          }
          if (oldVersion < 3) {
            await db.execute(
                'ALTER TABLE dangers ADD COLUMN paliers TEXT NOT NULL DEFAULT \'[]\'');
          }
          if (oldVersion < 4) {
            await db.execute(_createDilemmasSql);
          }
        },
      ),
    );
    _db = db;
    await _seedIfEmpty(db);
    await _seedDilemmasIfEmpty(db);
    await _backfillPaliers(db);
    return db;
  }

  static const String _createDilemmasSql =
      'CREATE TABLE IF NOT EXISTS dilemmas ('
      'id TEXT PRIMARY KEY, nom TEXT NOT NULL, source_reelle TEXT NOT NULL, '
      'moteur TEXT NOT NULL, danger_lie TEXT NOT NULL, situation TEXT NOT NULL, '
      'choix_a TEXT NOT NULL, choix_b TEXT NOT NULL, sort INTEGER NOT NULL)';

  Future<void> _seedIfEmpty(Database db) async {
    final count = Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM locations')) ??
        0;
    if (count > 0) return;
    await _populate(db);
  }

  /// Seede les dilemmes depuis le JSON embarqué si la table est vide (table
  /// ajoutée en v4 : les bases migrées ont locations pleines mais dilemmes vide).
  Future<void> _seedDilemmasIfEmpty(Database db) async {
    final count = Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM dilemmas')) ??
        0;
    if (count > 0) return;
    final dilemmas = await _seed.loadDilemmas();
    final batch = db.batch();
    var i = 0;
    for (final d in dilemmas) {
      batch.insert('dilemmas', _dilemmaRow(d, i++),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  /// Répare les dangers dont les paliers ont été perdus (bases migrées avant
  /// l'ajout des paliers) en les recomplétant depuis les données de référence.
  /// Idempotent : ne touche que les rangées aux paliers vides.
  Future<void> _backfillPaliers(Database db) async {
    final rows = await db.query('dangers', columns: ['id', 'paliers']);
    final current = <String, List<String>>{};
    for (final r in rows) {
      current[r['id'] as String] = _decodePaliers(r['paliers'] as String?);
    }
    final seedDangers = await _seed.loadDangers();
    final seed = {for (final d in seedDangers) d.id: d.paliers};
    final toFix = paliersBackfill(current, seed);
    if (toFix.isEmpty) return;
    final batch = db.batch();
    toFix.forEach((id, paliers) {
      batch.update('dangers', {'paliers': jsonEncode(paliers)},
          where: 'id = ?', whereArgs: [id]);
    });
    await batch.commit(noResult: true);
  }

  static List<String> _decodePaliers(String? raw) {
    try {
      return (jsonDecode(raw ?? '[]') as List<dynamic>)
          .map((e) => e as String)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Calcule les paliers à recompléter : pour chaque danger dont les paliers
  /// courants sont vides, on prend ceux de la référence (s'ils existent).
  /// Fonction pure, testable sans base de données.
  static Map<String, List<String>> paliersBackfill(
    Map<String, List<String>> current,
    Map<String, List<String>> seed,
  ) {
    final out = <String, List<String>>{};
    current.forEach((id, paliers) {
      if (paliers.isEmpty) {
        final s = seed[id];
        if (s != null && s.isNotEmpty) out[id] = s;
      }
    });
    return out;
  }

  Future<void> _populate(Database db) async {
    final locations = await _seed.loadLocations();
    final dangers = await _seed.loadDangers();
    final batch = db.batch();
    var i = 0;
    for (final l in locations) {
      batch.insert('locations', _locationRow(l, i++),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    i = 0;
    for (final d in dangers) {
      batch.insert('dangers', _dangerRow(d, i++),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Map<String, Object?> _locationRow(Location l, int sort) => {
        'id': l.id,
        'name': l.name,
        'roles': jsonEncode(l.roles),
        'rue': l.rue ? 1 : 0,
        'actif': l.actif ? 1 : 0,
        'sort': sort,
      };

  Map<String, Object?> _dangerRow(Danger d, int sort) => {
        'id': d.id,
        'name': d.name,
        'style': d.style,
        'rue': d.rue ? 1 : 0,
        'theatre': d.theatre ? 1 : 0,
        'actif': d.actif ? 1 : 0,
        'paliers': jsonEncode(d.paliers),
        'sort': sort,
      };

  Map<String, Object?> _dilemmaRow(Dilemma d, int sort) => {
        'id': d.id,
        'nom': d.nom,
        'source_reelle': d.sourceReelle,
        'moteur': d.moteur,
        'danger_lie': d.dangerLie,
        'situation': d.situation,
        'choix_a': d.choixA,
        'choix_b': d.choixB,
        'sort': sort,
      };

  @override
  Future<List<Location>> getLocations() async {
    final db = await _database();
    final rows = await db.query('locations', orderBy: 'sort ASC');
    return rows
        .map((r) => Location(
              id: r['id'] as String,
              name: r['name'] as String,
              roles: (jsonDecode(r['roles'] as String) as List<dynamic>)
                  .map((e) => e as String)
                  .toList(growable: false),
              rue: (r['rue'] as int) == 1,
              actif: (r['actif'] as int) == 1,
            ))
        .toList(growable: false);
  }

  @override
  Future<List<Danger>> getDangers() async {
    final db = await _database();
    final rows = await db.query('dangers', orderBy: 'sort ASC');
    return rows
        .map((r) => Danger(
              id: r['id'] as String,
              name: r['name'] as String,
              style: r['style'] as String,
              rue: (r['rue'] as int) == 1,
              theatre: ((r['theatre'] as int?) ?? 1) == 1,
              actif: (r['actif'] as int) == 1,
              paliers: (jsonDecode((r['paliers'] as String?) ?? '[]')
                      as List<dynamic>)
                  .map((e) => e as String)
                  .toList(growable: false),
            ))
        .toList(growable: false);
  }

  @override
  Future<List<Dilemma>> getDilemmas() async {
    final db = await _database();
    final rows = await db.query('dilemmas', orderBy: 'sort ASC');
    return rows
        .map((r) => Dilemma(
              id: r['id'] as String,
              nom: r['nom'] as String,
              sourceReelle: (r['source_reelle'] as String?) ?? '',
              moteur: (r['moteur'] as String?) ?? '',
              dangerLie: (r['danger_lie'] as String?) ?? '',
              situation: (r['situation'] as String?) ?? '',
              choixA: (r['choix_a'] as String?) ?? '',
              choixB: (r['choix_b'] as String?) ?? '',
            ))
        .toList(growable: false);
  }

  Future<int> _nextSort(Database db, String table) async {
    final v = Sqflite.firstIntValue(
        await db.rawQuery('SELECT MAX(sort) FROM $table'));
    return (v ?? -1) + 1;
  }

  @override
  Future<void> saveLocation(Location location) async {
    final db = await _database();
    final existing = await db
        .query('locations', columns: ['sort'], where: 'id = ?', whereArgs: [location.id]);
    final sort = existing.isNotEmpty
        ? existing.first['sort'] as int
        : await _nextSort(db, 'locations');
    await db.insert('locations', _locationRow(location, sort),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> deleteLocation(String id) async {
    final db = await _database();
    await db.delete('locations', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<void> saveDanger(Danger danger) async {
    final db = await _database();
    final existing = await db
        .query('dangers', columns: ['sort'], where: 'id = ?', whereArgs: [danger.id]);
    final sort = existing.isNotEmpty
        ? existing.first['sort'] as int
        : await _nextSort(db, 'dangers');
    await db.insert('dangers', _dangerRow(danger, sort),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> deleteDanger(String id) async {
    final db = await _database();
    await db.delete('dangers', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<void> saveDilemma(Dilemma dilemma) async {
    final db = await _database();
    final existing = await db.query('dilemmas',
        columns: ['sort'], where: 'id = ?', whereArgs: [dilemma.id]);
    final sort = existing.isNotEmpty
        ? existing.first['sort'] as int
        : await _nextSort(db, 'dilemmas');
    await db.insert('dilemmas', _dilemmaRow(dilemma, sort),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> deleteDilemma(String id) async {
    final db = await _database();
    await db.delete('dilemmas', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<void> resetToDefaults() async {
    final db = await _database();
    await db.delete('locations');
    await db.delete('dangers');
    await db.delete('dilemmas');
    await _populate(db);
    await _seedDilemmasIfEmpty(db);
  }
}
