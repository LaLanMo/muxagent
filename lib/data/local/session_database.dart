import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../../domain/cost_info.dart';
import '../../domain/enums.dart';
import '../../domain/session.dart';

class RecentCwd {
  final String path;
  final DateTime lastUsed;

  RecentCwd({required this.path, required this.lastUsed});
}

class SessionDatabase {
  static const String databaseFileName = 'muxagent.db';
  static const int schemaVersion = 3;
  static const String sessionsTable = 'sessions';
  static const String sessionChatCacheTable = 'session_chat_cache';

  static Database? _db;
  static String? _databasePathOverride;

  static Future<Database> get database async {
    _db ??= await openDatabase(
      await _resolveDatabasePath(),
      version: schemaVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
    return _db!;
  }

  static Future<String> _resolveDatabasePath() async {
    return _databasePathOverride ??
        join(await getDatabasesPath(), databaseFileName);
  }

  static Future<void> _onCreate(Database db, int version) async {
    await _createSessionsTable(db);
    await _createSessionChatCacheTable(db);
  }

  static Future<void> _onUpgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      await _createSessionChatCacheTable(db);
    }
    if (oldVersion >= 2 && oldVersion < 3) {
      await db.execute('''
        ALTER TABLE $sessionChatCacheTable
        ADD COLUMN last_applied_seq INTEGER NOT NULL DEFAULT 0
      ''');
    }
  }

  static Future<void> _createSessionsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $sessionsTable (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL DEFAULT '',
        status TEXT NOT NULL DEFAULT 'idle',
        model TEXT,
        cost_amount REAL DEFAULT 0,
        cost_currency TEXT NOT NULL DEFAULT 'USD',
        total_tokens INTEGER DEFAULT 0,
        machine_id TEXT NOT NULL,
        runtime TEXT NOT NULL DEFAULT '',
        cwd TEXT NOT NULL DEFAULT '',
        mode TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        is_read INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  static Future<void> _createSessionChatCacheTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $sessionChatCacheTable (
        session_id TEXT PRIMARY KEY,
        machine_id TEXT NOT NULL,
        title TEXT NOT NULL DEFAULT '',
        cache_state TEXT NOT NULL DEFAULT 'empty',
        cache_version INTEGER NOT NULL DEFAULT 1,
        last_applied_seq INTEGER NOT NULL DEFAULT 0,
        chat_state_json TEXT NOT NULL,
        config_snapshot_json TEXT,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_session_chat_cache_machine_updated
      ON $sessionChatCacheTable(machine_id, updated_at DESC)
    ''');
  }

  static Future<void> close() async {
    final db = _db;
    _db = null;
    if (db != null) {
      await db.close();
    }
  }

  @visibleForTesting
  static Future<void> resetForTest({String? databasePathOverride}) async {
    await close();
    _databasePathOverride = databasePathOverride;
  }

  static Future<void> insertSession(AgentSession s) async {
    final db = await database;
    await db.insert(sessionsTable, {
      'id': s.id,
      'title': s.title,
      'status': s.status.value,
      'model': s.model,
      'cost_amount': s.cost?.costAmount ?? 0,
      'cost_currency': s.cost?.costCurrency ?? 'USD',
      'total_tokens': s.cost?.totalTokens ?? 0,
      'machine_id': s.machineId,
      'runtime': s.runtime,
      'cwd': s.cwd,
      'mode': s.mode ?? '',
      'created_at': s.createdAt.toIso8601String(),
      'updated_at': s.updatedAt.toIso8601String(),
      'is_read': s.isRead ? 1 : 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<List<AgentSession>> loadAll() async {
    final db = await database;
    final rows = await db.query(sessionsTable, orderBy: 'updated_at DESC');
    return rows.map(_rowToSession).toList();
  }

  static Future<void> updateFields(
    String id,
    Map<String, dynamic> fields,
  ) async {
    final db = await database;
    await db.update(sessionsTable, fields, where: 'id = ?', whereArgs: [id]);
  }

  static Future<void> deleteSession(String id) async {
    final db = await database;
    await db.delete(sessionsTable, where: 'id = ?', whereArgs: [id]);
  }

  static Future<List<RecentCwd>> recentCwds({String? machineId}) async {
    final db = await database;
    final where = machineId != null ? 'WHERE machine_id = ?' : '';
    final args = machineId != null ? [machineId] : <String>[];
    final rows = await db.rawQuery('''
      SELECT cwd, MAX(updated_at) as last_used
      FROM sessions
      $where
      GROUP BY cwd
      HAVING cwd != ''
      ORDER BY last_used DESC
      LIMIT 20
      ''', args);
    return rows
        .map(
          (r) => RecentCwd(
            path: r['cwd'] as String,
            lastUsed: DateTime.parse(r['last_used'] as String),
          ),
        )
        .toList();
  }

  static AgentSession _rowToSession(Map<String, dynamic> row) {
    final costAmount = (row['cost_amount'] as num?)?.toDouble() ?? 0;
    final costCurrency = row['cost_currency'] as String? ?? 'USD';
    final totalTokens = (row['total_tokens'] as num?)?.toInt() ?? 0;

    final hasCost = costAmount != 0 || totalTokens != 0;

    return AgentSession(
      id: row['id'] as String,
      title: row['title'] as String? ?? '',
      status: SessionStatus.fromValue(row['status'] as String? ?? 'idle'),
      model: row['model'] as String?,
      cost: hasCost
          ? CostInfo(
              costAmount: costAmount,
              costCurrency: costCurrency,
              totalTokens: totalTokens,
            )
          : null,
      isRead: (row['is_read'] as int? ?? 0) == 1,
      machineId: row['machine_id'] as String? ?? '',
      runtime: row['runtime'] as String? ?? '',
      cwd: row['cwd'] as String? ?? '',
      mode: (row['mode'] as String?)?.isNotEmpty == true
          ? row['mode'] as String
          : null,
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: DateTime.parse(row['updated_at'] as String),
    );
  }
}
