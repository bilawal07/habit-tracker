import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Manages the local on-device SQLite database lifecycle and schema.
class DatabaseHelper {
  DatabaseHelper({
    this._databaseFactory,
    this._databasePathOverride,
  });

  static const String databaseName = 'hotfire_habits.db';
  static const int databaseVersion = 1;

  final DatabaseFactory? _databaseFactory;
  final String? _databasePathOverride;
  Database? _database;

  /// Returns an open SQLite database instance, initializing it if needed.
  Future<Database> get database async {
    final existing = _database;
    if (existing != null && existing.isOpen) {
      return existing;
    }
    _database = await _open();
    return _database!;
  }

  Future<Database> _open() async {
    final factory = _databaseFactory ?? databaseFactory;
    final dbPath = _databasePathOverride ??
        p.join(await factory.getDatabasesPath(), databaseName);

    return factory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: databaseVersion,
        onConfigure: _onConfigure,
        onCreate: _onCreate,
      ),
    );
  }

  Future<void> _onConfigure(Database db) async {
    // Required so ON DELETE CASCADE works across daily_logs and task_badges.
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE tasks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        reminder_mode TEXT NOT NULL DEFAULT 'strict',
        created_at TEXT NOT NULL,
        is_archived INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE daily_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        task_id INTEGER NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
        log_date TEXT NOT NULL,
        completed_at TEXT NOT NULL,
        UNIQUE(task_id, log_date)
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_daily_logs_task_date
      ON daily_logs(task_id, log_date)
    ''');

    await db.execute('''
      CREATE TABLE task_badges (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        task_id INTEGER NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
        badge_key TEXT NOT NULL,
        unlocked_at TEXT NOT NULL,
        UNIQUE(task_id, badge_key)
      )
    ''');
  }

  /// Closes the database handle if open.
  Future<void> close() async {
    final existing = _database;
    if (existing != null && existing.isOpen) {
      await existing.close();
      _database = null;
    }
  }
}
