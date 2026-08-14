import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../../domain/entities/chat_message.dart';
import '../../domain/entities/chat_story.dart';
import '../../domain/repositories/chat_store.dart';

/// Implémentation SQLite, persistante, de [ChatStore].
class SqliteChatStore implements ChatStore {
  SqliteChatStore({this.databaseName = 'destiny_chat.db'});

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
        version: 5,
        onCreate: (db, version) async {
          await db.execute(
            'CREATE TABLE stories ('
            'id TEXT PRIMARY KEY, title TEXT NOT NULL, created_at INTEGER NOT NULL, '
            'context TEXT NOT NULL, messages TEXT NOT NULL, '
            'max_responses INTEGER NOT NULL DEFAULT 0, '
            'child_mode INTEGER NOT NULL DEFAULT 0, '
            "players TEXT NOT NULL DEFAULT '[]', "
            "tone TEXT NOT NULL DEFAULT '', "
            'archived INTEGER NOT NULL DEFAULT 0)',
          );
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            await db.execute(
                'ALTER TABLE stories ADD COLUMN max_responses INTEGER NOT NULL DEFAULT 0');
          }
          if (oldVersion < 3) {
            await db.execute(
                'ALTER TABLE stories ADD COLUMN child_mode INTEGER NOT NULL DEFAULT 0');
          }
          if (oldVersion < 4) {
            await db.execute(
                "ALTER TABLE stories ADD COLUMN players TEXT NOT NULL DEFAULT '[]'");
            await db.execute(
                "ALTER TABLE stories ADD COLUMN tone TEXT NOT NULL DEFAULT ''");
          }
          if (oldVersion < 5) {
            await db.execute(
                'ALTER TABLE stories ADD COLUMN archived INTEGER NOT NULL DEFAULT 0');
          }
        },
      ),
    );
    _db = db;
    return db;
  }

  @override
  Future<List<ChatStory>> list() async {
    final db = await _database();
    final rows = await db.query('stories', orderBy: 'created_at DESC');
    return rows.map(_fromRow).toList(growable: false);
  }

  ChatStory _fromRow(Map<String, Object?> r) => ChatStory(
        id: r['id'] as String,
        title: r['title'] as String,
        createdAt: r['created_at'] as int,
        context: r['context'] as String,
        maxResponses: (r['max_responses'] as int?) ?? 0,
        childMode: ((r['child_mode'] as int?) ?? 0) == 1,
        archived: ((r['archived'] as int?) ?? 0) == 1,
        tone: (r['tone'] as String?) ?? '',
        players: ((jsonDecode((r['players'] as String?) ?? '[]'))
                as List<dynamic>)
            .map((e) => ChatPlayer.fromJson(e as Map<String, dynamic>))
            .toList(),
        messages: (jsonDecode(r['messages'] as String) as List<dynamic>)
            .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  @override
  Future<void> save(ChatStory story) async {
    final db = await _database();
    await db.insert(
      'stories',
      {
        'id': story.id,
        'title': story.title,
        'created_at': story.createdAt,
        'context': story.context,
        'max_responses': story.maxResponses,
        'child_mode': story.childMode ? 1 : 0,
        'archived': story.archived ? 1 : 0,
        'tone': story.tone,
        'players': jsonEncode(story.players.map((p) => p.toJson()).toList()),
        'messages':
            jsonEncode(story.messages.map((m) => m.toJson()).toList()),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> delete(String id) async {
    final db = await _database();
    await db.delete('stories', where: 'id = ?', whereArgs: [id]);
  }
}
