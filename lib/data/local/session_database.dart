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
  static Database? _db;

  static Future<Database> get database async {
    _db ??= await openDatabase(
      join(await getDatabasesPath(), 'muxagent.db'),
      version: 1,
      onCreate: _onCreate,
    );
    return _db!;
  }

  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE sessions (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL DEFAULT '',
        status TEXT NOT NULL DEFAULT 'idle',
        model TEXT,
        cost_input_tokens INTEGER DEFAULT 0,
        cost_output_tokens INTEGER DEFAULT 0,
        cost_cache_read INTEGER DEFAULT 0,
        cost_cache_write INTEGER DEFAULT 0,
        cost_total_usd REAL DEFAULT 0,
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

  static Future<void> insertSession(AgentSession s) async {
    final db = await database;
    final machineId = s.metadata?['machineId'] as String? ?? '';
    final runtime = s.metadata?['runtime'] as String? ?? '';
    final cwd = s.metadata?['cwd'] as String? ?? '';
    final mode = s.metadata?['mode'] as String? ?? '';
    await db.insert(
      'sessions',
      {
        'id': s.id,
        'title': s.title,
        'status': s.status.value,
        'model': s.model,
        'cost_input_tokens': s.cost?.inputTokens ?? 0,
        'cost_output_tokens': s.cost?.outputTokens ?? 0,
        'cost_cache_read': s.cost?.cacheRead ?? 0,
        'cost_cache_write': s.cost?.cacheWrite ?? 0,
        'cost_total_usd': s.cost?.totalUsd ?? 0,
        'machine_id': machineId,
        'runtime': runtime,
        'cwd': cwd,
        'mode': mode,
        'created_at': s.createdAt.toIso8601String(),
        'updated_at': s.updatedAt.toIso8601String(),
        'is_read': s.isRead ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<List<AgentSession>> loadAll() async {
    final db = await database;
    final rows = await db.query('sessions', orderBy: 'updated_at DESC');
    return rows.map(_rowToSession).toList();
  }

  static Future<void> updateFields(
    String id,
    Map<String, dynamic> fields,
  ) async {
    final db = await database;
    await db.update('sessions', fields, where: 'id = ?', whereArgs: [id]);
  }

  static Future<void> deleteSession(String id) async {
    final db = await database;
    await db.delete('sessions', where: 'id = ?', whereArgs: [id]);
  }

  static Future<List<RecentCwd>> recentCwds({String? machineId}) async {
    final db = await database;
    final where = machineId != null ? 'WHERE machine_id = ?' : '';
    final args = machineId != null ? [machineId] : <String>[];
    final rows = await db.rawQuery(
      '''
      SELECT cwd, MAX(updated_at) as last_used
      FROM sessions
      $where
      GROUP BY cwd
      HAVING cwd != ''
      ORDER BY last_used DESC
      LIMIT 20
      ''',
      args,
    );
    return rows.map((r) => RecentCwd(
      path: r['cwd'] as String,
      lastUsed: DateTime.parse(r['last_used'] as String),
    )).toList();
  }

  static AgentSession _rowToSession(Map<String, dynamic> row) {
    final costInputTokens = row['cost_input_tokens'] as int? ?? 0;
    final costOutputTokens = row['cost_output_tokens'] as int? ?? 0;
    final costCacheRead = row['cost_cache_read'] as int? ?? 0;
    final costCacheWrite = row['cost_cache_write'] as int? ?? 0;
    final costTotalUsd = (row['cost_total_usd'] as num?)?.toDouble() ?? 0;

    final hasCost = costInputTokens != 0 ||
        costOutputTokens != 0 ||
        costCacheRead != 0 ||
        costCacheWrite != 0 ||
        costTotalUsd != 0;

    return AgentSession(
      id: row['id'] as String,
      title: row['title'] as String? ?? '',
      status: SessionStatus.fromValue(row['status'] as String? ?? 'idle'),
      model: row['model'] as String?,
      cost: hasCost
          ? CostInfo(
              inputTokens: costInputTokens,
              outputTokens: costOutputTokens,
              cacheRead: costCacheRead,
              cacheWrite: costCacheWrite,
              totalUsd: costTotalUsd,
            )
          : null,
      isRead: (row['is_read'] as int? ?? 0) == 1,
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: DateTime.parse(row['updated_at'] as String),
      metadata: {
        'machineId': row['machine_id'] as String? ?? '',
        'runtime': row['runtime'] as String? ?? '',
        'cwd': row['cwd'] as String? ?? '',
        'mode': row['mode'] as String? ?? '',
      },
    );
  }
}
