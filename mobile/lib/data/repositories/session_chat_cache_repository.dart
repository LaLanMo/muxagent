import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../../domain/session_config_snapshot.dart';
import '../../ui/chat/chat_state.dart';
import '../local/session_database.dart';
import 'session_chat_cache_dto.dart';

class SessionChatCacheRepository {
  final _cacheBySessionId = <String, SessionChatCacheEntry>{};
  final _changes = StreamController<String>.broadcast();

  Stream<String> get changes => _changes.stream;

  @visibleForTesting
  Map<String, SessionChatCacheEntry> get cacheBySessionId =>
      Map.unmodifiable(_cacheBySessionId);

  Future<void> init() async {
    final db = await SessionDatabase.database;
    final rows = await db.query(
      SessionDatabase.sessionChatCacheTable,
      orderBy: 'updated_at DESC',
    );

    _cacheBySessionId.clear();
    for (final row in rows) {
      final entry = SessionChatCacheEntry.fromDatabaseRow(row);
      if (entry == null) {
        continue;
      }
      _cacheBySessionId[entry.sessionId] = entry;
    }
  }

  SessionChatCacheEntry? cacheForSession(String sessionId) {
    return _cacheBySessionId[sessionId];
  }

  SessionChatCacheEntry? renderableCacheForSession(String sessionId) {
    final entry = _cacheBySessionId[sessionId];
    if (entry == null || !entry.isRenderable) {
      return null;
    }
    return entry;
  }

  SessionChatCacheHydrated? hydratedCacheForSession(String sessionId) {
    final entry = renderableCacheForSession(sessionId);
    if (entry == null) {
      return null;
    }
    return hydrateSessionChatCacheEntry(entry);
  }

  Future<SessionChatCacheEntry?> reloadSession(String sessionId) async {
    final db = await SessionDatabase.database;
    final rows = await db.query(
      SessionDatabase.sessionChatCacheTable,
      where: 'session_id = ?',
      whereArgs: [sessionId],
      limit: 1,
    );
    if (rows.isEmpty) {
      _cacheBySessionId.remove(sessionId);
      return null;
    }
    final entry = SessionChatCacheEntry.fromDatabaseRow(rows.first);
    if (entry == null) {
      _cacheBySessionId.remove(sessionId);
      return null;
    }
    _cacheBySessionId[sessionId] = entry;
    return entry;
  }

  Future<SessionChatCacheHydrated?> reloadHydratedSession(
    String sessionId,
  ) async {
    final entry = await reloadSession(sessionId);
    if (entry == null) {
      return null;
    }
    return hydrateSessionChatCacheEntry(entry);
  }

  Future<void> seedEmptyCache({
    required String sessionId,
    required String machineId,
    String title = '',
    SessionConfigSnapshot? configSnapshot,
  }) async {
    await persistSnapshot(
      sessionId: sessionId,
      machineId: machineId,
      title: title,
      chatState: ChatState(sessionId: sessionId),
      configSnapshot: configSnapshot ?? const SessionConfigSnapshot(),
      cacheState: SessionChatCacheState.empty,
      lastAppliedSeq: 0,
    );
  }

  Future<SessionChatCacheEntry> persistSnapshot({
    required String sessionId,
    required String machineId,
    required String title,
    required ChatState chatState,
    required SessionConfigSnapshot configSnapshot,
    required SessionChatCacheState cacheState,
    required int lastAppliedSeq,
    DateTime? updatedAt,
  }) async {
    final entry = buildSessionChatCacheEntry(
      sessionId: sessionId,
      machineId: machineId,
      title: title,
      chatState: chatState,
      configSnapshot: configSnapshot,
      cacheState: cacheState,
      lastAppliedSeq: lastAppliedSeq,
      updatedAt: updatedAt,
    );
    await upsert(entry);
    return entry;
  }

  Future<void> upsert(SessionChatCacheEntry entry) async {
    final db = await SessionDatabase.database;
    await db.insert(
      SessionDatabase.sessionChatCacheTable,
      entry.toDatabaseRow(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _cacheBySessionId[entry.sessionId] = entry;
    _changes.add(entry.sessionId);
  }

  Future<void> deleteSession(String sessionId) async {
    final db = await SessionDatabase.database;
    await db.delete(
      SessionDatabase.sessionChatCacheTable,
      where: 'session_id = ?',
      whereArgs: [sessionId],
    );
    if (_cacheBySessionId.remove(sessionId) != null) {
      _changes.add(sessionId);
    }
  }

  Future<bool> markSessionCacheStale(String sessionId) async {
    final existing = _cacheBySessionId[sessionId];
    if (existing == null ||
        existing.cacheState != SessionChatCacheState.ready ||
        !existing.isRenderable ||
        !existing.isNonEmpty) {
      return false;
    }

    final updated = existing.copyWith(
      cacheState: SessionChatCacheState.stale,
      updatedAt: DateTime.now(),
    );
    _cacheBySessionId[sessionId] = updated;
    _changes.add(sessionId);

    final db = await SessionDatabase.database;
    await db.update(
      SessionDatabase.sessionChatCacheTable,
      updated.toDatabaseRow(),
      where: 'session_id = ?',
      whereArgs: [sessionId],
    );
    return true;
  }

  Future<int> markMachineCachesStale(String machineId) async {
    final now = DateTime.now();
    final updatedEntries = <SessionChatCacheEntry>[];

    for (final entry in _cacheBySessionId.values) {
      if (entry.machineId != machineId) {
        continue;
      }
      if (entry.cacheState != SessionChatCacheState.ready ||
          !entry.isNonEmpty ||
          !entry.isRenderable) {
        continue;
      }
      updatedEntries.add(
        entry.copyWith(cacheState: SessionChatCacheState.stale, updatedAt: now),
      );
    }

    if (updatedEntries.isEmpty) {
      return 0;
    }

    final db = await SessionDatabase.database;
    final batch = db.batch();
    for (final entry in updatedEntries) {
      batch.update(
        SessionDatabase.sessionChatCacheTable,
        entry.toDatabaseRow(),
        where: 'session_id = ?',
        whereArgs: [entry.sessionId],
      );
      _cacheBySessionId[entry.sessionId] = entry;
    }
    await batch.commit(noResult: true);

    for (final entry in updatedEntries) {
      _changes.add(entry.sessionId);
    }
    return updatedEntries.length;
  }

  void dispose() {
    _changes.close();
  }
}
