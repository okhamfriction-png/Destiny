import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../../domain/repositories/combination_memory.dart';

/// Implémentation SQLite de [CombinationMemory].
///
/// Schéma :
///  - `used_combos(combo TEXT PRIMARY KEY, created_at INTEGER)`
///  - `meta(key TEXT PRIMARY KEY, value INTEGER)` — stocke le numéro de cycle.
class SqliteCombinationMemory implements CombinationMemory {
  SqliteCombinationMemory({this.databaseName = 'destiny_memory.db'});

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
        version: 1,
        onCreate: (db, version) async {
          await db.execute(
            'CREATE TABLE used_combos ('
            'combo TEXT PRIMARY KEY, '
            'created_at INTEGER NOT NULL)',
          );
          await db.execute(
            'CREATE TABLE meta ('
            'key TEXT PRIMARY KEY, '
            'value INTEGER NOT NULL)',
          );
          await db.insert('meta', {'key': 'cycle', 'value': 1});
        },
      ),
    );
    _db = db;
    return db;
  }

  @override
  Future<Set<String>> usedCombos() async {
    final db = await _database();
    final rows = await db.query('used_combos', columns: ['combo']);
    return rows.map((row) => row['combo'] as String).toSet();
  }

  @override
  Future<void> markUsed(String comboKey) async {
    final db = await _database();
    await db.insert(
      'used_combos',
      {'combo': comboKey, 'created_at': DateTime.now().millisecondsSinceEpoch},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  @override
  Future<int> currentCycle() async {
    final db = await _database();
    final rows = await db.query(
      'meta',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: ['cycle'],
    );
    if (rows.isEmpty) return 1;
    return rows.first['value'] as int;
  }

  @override
  Future<void> reset() async {
    final db = await _database();
    await db.transaction((txn) async {
      await txn.delete('used_combos');
      await txn.insert(
        'meta',
        {'key': 'cycle', 'value': 1},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  @override
  Future<int> resetCycle() async {
    final db = await _database();
    return db.transaction<int>((txn) async {
      await txn.delete('used_combos');
      final current = await txn.query(
        'meta',
        columns: ['value'],
        where: 'key = ?',
        whereArgs: ['cycle'],
      );
      final next = (current.isEmpty ? 1 : current.first['value'] as int) + 1;
      await txn.insert(
        'meta',
        {'key': 'cycle', 'value': next},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return next;
    });
  }
}
