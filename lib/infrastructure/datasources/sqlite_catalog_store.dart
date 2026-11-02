import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../../domain/entities/danger.dart';
import '../../domain/entities/dilemma.dart';
import '../../domain/entities/location.dart';
import '../../domain/grammaire/synchro_catalogue.dart';
import '../../domain/repositories/catalog_store.dart';
import 'local_json_datasource.dart';

/// Implémentation SQLite, persistante, de [CatalogStore].
///
/// Version 5 (refonte 2.0) : les lieux gagnent leurs espaces, et le catalogue
/// se met à jour tout seul avec la grammaire, sans jamais écraser ce que
/// l'utilisateur a modifié (voir `synchro_catalogue.dart`).
class SqliteCatalogStore implements CatalogStore {
  SqliteCatalogStore({
    required LocalJsonDataSource seedSource,
    this.databaseName = 'destiny_catalog.db',
    Future<String> Function()? dossier,
  })  : _seed = seedSource,
        _dossier = dossier;

  final LocalJsonDataSource _seed;
  final String databaseName;

  /// Dossier de la base (par défaut, le dossier de support de l'appli).
  final Future<String> Function()? _dossier;
  Database? _db;

  static const int version = 5;

  Future<Database> _database() async {
    final existing = _db;
    if (existing != null) return existing;

    final dossier = _dossier != null
        ? await _dossier()
        : (await getApplicationSupportDirectory()).path;
    final path = p.join(dossier, databaseName);

    final db = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: version,
        onCreate: (db, version) async {
          await db.execute(
            'CREATE TABLE locations ('
            'id TEXT PRIMARY KEY, name TEXT NOT NULL, roles TEXT NOT NULL, '
            'rue INTEGER NOT NULL, actif INTEGER NOT NULL, sort INTEGER NOT NULL, '
            "espaces TEXT NOT NULL DEFAULT '[]')",
          );
          await db.execute(
            'CREATE TABLE dangers ('
            'id TEXT PRIMARY KEY, name TEXT NOT NULL, style TEXT NOT NULL, '
            'rue INTEGER NOT NULL, theatre INTEGER NOT NULL, '
            'actif INTEGER NOT NULL, paliers TEXT NOT NULL DEFAULT \'[]\', '
            'sort INTEGER NOT NULL)',
          );
          await db.execute(_createDilemmasSql);
          await db.execute(_createReferenceSql);
          await db.execute(_createMetaSql);
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
          if (oldVersion < 5) {
            await db.execute(
                "ALTER TABLE locations ADD COLUMN espaces TEXT NOT NULL DEFAULT '[]'");
            await db.execute(_createReferenceSql);
            await db.execute(_createMetaSql);
            await _referencesDepuis157(db);
          }
        },
      ),
    );
    _db = db;
    await _seedIfEmpty(db);
    await _seedDilemmasIfEmpty(db);
    await _synchroniser(db);
    return db;
  }

  static const String _createDilemmasSql =
      'CREATE TABLE IF NOT EXISTS dilemmas ('
      'id TEXT PRIMARY KEY, nom TEXT NOT NULL, source_reelle TEXT NOT NULL, '
      'moteur TEXT NOT NULL, danger_lie TEXT NOT NULL, situation TEXT NOT NULL, '
      'choix_a TEXT NOT NULL, choix_b TEXT NOT NULL, sort INTEGER NOT NULL)';

  /// Dernière valeur venue de la grammaire, par champ suivi.
  static const String _createReferenceSql =
      'CREATE TABLE IF NOT EXISTS reference ('
      'champ TEXT NOT NULL, id TEXT NOT NULL, valeur TEXT NOT NULL, '
      'PRIMARY KEY (champ, id))';

  static const String _createMetaSql =
      'CREATE TABLE IF NOT EXISTS meta (cle TEXT PRIMARY KEY, valeur TEXT NOT NULL)';

  static const String _champPaliers = 'danger.paliers';
  static const String _champRoles = 'lieu.roles';
  static const String _champEspaces = 'lieu.espaces';

  /// Base venue de la 1.5.7 : la référence est la photo du catalogue 1.5.7.
  Future<void> _referencesDepuis157(Database db) async {
    final ref = await _seed.loadReference157();
    final batch = db.batch();
    ref.paliers.forEach((id, v) => batch.insert(
        'reference', {'champ': _champPaliers, 'id': id, 'valeur': jsonEncode(v)},
        conflictAlgorithm: ConflictAlgorithm.replace));
    ref.roles.forEach((id, v) => batch.insert(
        'reference', {'champ': _champRoles, 'id': id, 'valeur': jsonEncode(v)},
        conflictAlgorithm: ConflictAlgorithm.replace));
    await batch.commit(noResult: true);
  }

  Future<void> _seedIfEmpty(Database db) async {
    final count = Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM locations')) ??
        0;
    if (count > 0) return;
    await _populate(db);
  }

  /// Seede les dilemmes depuis le JSON embarqué si la table est vide.
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

  static List<String> _liste(Object? raw) {
    try {
      return [for (final e in jsonDecode('${raw ?? '[]'}') as List<dynamic>) '$e'];
    } catch (_) {
      return const [];
    }
  }

  Future<Map<String, List<String>>> _references(Database db, String champ) async {
    final rows = await db.query('reference', where: 'champ = ?', whereArgs: [champ]);
    return {for (final r in rows) r['id'] as String: _liste(r['valeur'])};
  }

  /// Met le catalogue à jour avec la grammaire, si elle a changé depuis la
  /// dernière fois.
  Future<void> _synchroniser(Database db) async {
    final dangersCible = await _seed.loadDangers();
    final lieuxCible = await _seed.loadLocations();
    final cible = {
      for (final d in dangersCible) d.id: d.paliers,
      for (final l in lieuxCible) 'lieu:${l.id}': [...l.roles, '|', ...l.espaces],
    };
    final signature = empreinte(jsonEncode(cible));
    final meta = await db.query('meta', where: 'cle = ?', whereArgs: ['empreinte']);
    if (meta.isNotEmpty && meta.first['valeur'] == signature) return;

    final dangers = await db.query('dangers', columns: ['id', 'name', 'paliers']);
    final lieux = await db.query('locations', columns: ['id', 'name', 'roles', 'espaces']);
    final noms = <String, String>{
      for (final r in dangers) r['id'] as String: r['name'] as String,
      for (final r in lieux) r['id'] as String: r['name'] as String,
    };

    final rPaliers = synchroniserChamp(
      actuel: {for (final r in dangers) r['id'] as String: _liste(r['paliers'])},
      references: await _references(db, _champPaliers),
      cible: {for (final d in dangersCible) d.id: d.paliers},
    );
    final rRoles = synchroniserChamp(
      actuel: {for (final r in lieux) r['id'] as String: _liste(r['roles'])},
      references: await _references(db, _champRoles),
      cible: {for (final l in lieuxCible) l.id: l.roles},
    );
    final rEspaces = synchroniserChamp(
      actuel: {for (final r in lieux) r['id'] as String: _liste(r['espaces'])},
      references: await _references(db, _champEspaces),
      cible: {for (final l in lieuxCible) l.id: l.espaces},
    );

    final batch = db.batch();
    rPaliers.misesAJour.forEach((id, v) => batch.update(
        'dangers', {'paliers': jsonEncode(v)}, where: 'id = ?', whereArgs: [id]));
    rRoles.misesAJour.forEach((id, v) => batch.update(
        'locations', {'roles': jsonEncode(v)}, where: 'id = ?', whereArgs: [id]));
    rEspaces.misesAJour.forEach((id, v) => batch.update(
        'locations', {'espaces': jsonEncode(v)}, where: 'id = ?', whereArgs: [id]));
    for (final (champ, r) in [
      (_champPaliers, rPaliers),
      (_champRoles, rRoles),
      (_champEspaces, rEspaces),
    ]) {
      r.references.forEach((id, v) => batch.insert(
          'reference', {'champ': champ, 'id': id, 'valeur': jsonEncode(v)},
          conflictAlgorithm: ConflictAlgorithm.replace));
    }
    final nomsCible = {
      for (final d in dangersCible) d.id: d.name,
      for (final l in lieuxCible) l.id: l.name,
    };
    final rapport = RapportSynchroCatalogue(
      date: DateTime.now(),
      dangersMisAJour: rPaliers.misesAJour.length,
      lieuxMisAJour: {...rRoles.misesAJour.keys, ...rEspaces.misesAJour.keys}.length,
      gardes: [
        for (final id in {...rPaliers.gardes, ...rRoles.gardes, ...rEspaces.gardes})
          noms[id] ?? id,
      ],
      absents: [
        for (final id in {...rPaliers.absents, ...rRoles.absents}) nomsCible[id] ?? id,
      ],
    );
    batch.insert('meta', {'cle': 'empreinte', 'valeur': signature},
        conflictAlgorithm: ConflictAlgorithm.replace);
    batch.insert('meta', {'cle': 'rapport', 'valeur': jsonEncode(rapport.versJson())},
        conflictAlgorithm: ConflictAlgorithm.replace);
    await batch.commit(noResult: true);
  }

  Future<void> _populate(Database db) async {
    final locations = await _seed.loadLocations();
    final dangers = await _seed.loadDangers();
    final batch = db.batch();
    var i = 0;
    for (final l in locations) {
      batch.insert('locations', _locationRow(l, i++),
          conflictAlgorithm: ConflictAlgorithm.replace);
      batch.insert('reference',
          {'champ': _champRoles, 'id': l.id, 'valeur': jsonEncode(l.roles)},
          conflictAlgorithm: ConflictAlgorithm.replace);
      batch.insert('reference',
          {'champ': _champEspaces, 'id': l.id, 'valeur': jsonEncode(l.espaces)},
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    i = 0;
    for (final d in dangers) {
      batch.insert('dangers', _dangerRow(d, i++),
          conflictAlgorithm: ConflictAlgorithm.replace);
      batch.insert('reference',
          {'champ': _champPaliers, 'id': d.id, 'valeur': jsonEncode(d.paliers)},
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Map<String, Object?> _locationRow(Location l, int sort) => {
        'id': l.id,
        'name': l.name,
        'roles': jsonEncode(l.roles),
        'espaces': jsonEncode(l.espaces),
        'rue': 0,
        'actif': l.actif ? 1 : 0,
        'sort': sort,
      };

  Map<String, Object?> _dangerRow(Danger d, int sort) => {
        'id': d.id,
        'name': d.name,
        'style': d.style,
        'rue': 0,
        'theatre': 1,
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
              roles: _liste(r['roles']),
              espaces: _liste(r['espaces']),
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
              actif: (r['actif'] as int) == 1,
              paliers: _liste(r['paliers']),
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

  @override
  Future<RapportSynchroCatalogue?> dernierRapport() async {
    final db = await _database();
    final rows = await db.query('meta', where: 'cle = ?', whereArgs: ['rapport']);
    if (rows.isEmpty) return null;
    try {
      return RapportSynchroCatalogue.depuisJson(jsonDecode(rows.first['valeur'] as String));
    } catch (_) {
      return null;
    }
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
    await db.delete('reference');
    await _populate(db);
    await _seedDilemmasIfEmpty(db);
  }
}
