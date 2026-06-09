import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/feedback_entry.dart';

class SqliteService {
  Database? _database;

  Future<void> initializeDatabase() async {
    if (_database != null) return;
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(dir.path, 'nsl_translate.db');
    _database = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
CREATE TABLE feedback_queue (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  sign_label TEXT NOT NULL,
  video_path TEXT NOT NULL,
  submitted_at TEXT NOT NULL,
  synced INTEGER NOT NULL DEFAULT 0
)
''');
      },
    );
  }

  Database get database {
    final db = _database;
    if (db == null) {
      throw StateError('SQLite database is not initialized.');
    }
    return db;
  }

  Future<int> insertFeedback(FeedbackEntry entry) {
    return database.insert(
      'feedback_queue',
      entry.toMap()..remove('id'),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<FeedbackEntry>> getUnsynced() async {
    final rows = await database.query(
      'feedback_queue',
      where: 'synced = ?',
      whereArgs: [0],
      orderBy: 'submitted_at DESC',
    );
    return rows.map(FeedbackEntry.fromMap).toList();
  }

  Future<void> markAsSynced(int id) async {
    await database.update(
      'feedback_queue',
      {'synced': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteAll() => database.delete('feedback_queue');

  Future<void> dispose() async {
    await _database?.close();
    _database = null;
  }
}
