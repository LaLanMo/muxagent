import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:muxagent/data/local/session_database.dart';
import 'package:muxagent/data/repositories/session_chat_cache_dto.dart';
import 'package:muxagent/data/repositories/session_chat_cache_repository.dart';
import 'package:muxagent/domain/approval.dart';
import 'package:muxagent/domain/enums.dart';
import 'package:muxagent/domain/event.dart';
import 'package:muxagent/domain/message.dart';
import 'package:muxagent/domain/model_info.dart';
import 'package:muxagent/domain/mode_option.dart';
import 'package:muxagent/domain/plan_entry.dart';
import 'package:muxagent/domain/session_config_snapshot.dart';
import 'package:muxagent/ui/chat/chat_state.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('SessionChatCacheRepository', () {
    late Directory tempDir;
    late String dbPath;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'muxagent-session-chat-cache-test-',
      );
      dbPath = p.join(tempDir.path, SessionDatabase.databaseFileName);
      await SessionDatabase.resetForTest(databasePathOverride: dbPath);
    });

    tearDown(() async {
      await SessionDatabase.resetForTest();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('seedEmptyCache persists a non-renderable empty cache row', () async {
      final repository = SessionChatCacheRepository();
      await repository.init();

      await repository.seedEmptyCache(
        sessionId: 'session-1',
        machineId: 'machine-1',
        title: 'Fresh Session',
      );

      final seeded = repository.cacheForSession('session-1');
      expect(seeded, isNotNull);
      expect(seeded?.cacheState, SessionChatCacheState.empty);
      expect(seeded?.isRenderable, isFalse);
      expect(repository.renderableCacheForSession('session-1'), isNull);

      final reloaded = SessionChatCacheRepository();
      await reloaded.init();
      final restored = reloaded.cacheForSession('session-1');
      expect(restored, isNotNull);
      expect(restored?.title, 'Fresh Session');
      expect(restored?.cacheState, SessionChatCacheState.empty);
      expect(restored?.isRenderable, isFalse);
    });

    test('persistSnapshot round-trips a hydrated chat cache', () async {
      final repository = SessionChatCacheRepository();
      await repository.init();
      final chatState = ChatState(sessionId: 'session-1');

      chatState.finalizeMessage(
        Message(
          id: 'user-1',
          sessionId: 'session-1',
          role: MessageRole.user,
          parts: [MessagePart(type: PartType.text, text: 'make a change')],
          createdAt: DateTime(2026, 1, 1, 0, 0),
        ),
      );
      chatState.applyToolEvent(
        ToolEvent(
          partId: 'tool-part-1',
          messageId: 'assistant-1',
          callId: 'tool-1',
          name: 'edit_file',
          kind: 'edit',
          status: ToolStatus.completed,
          diffs: [
            ToolDiff(
              path: 'lib/main.dart',
              oldText: 'old line\n',
              newText: 'new line\n',
            ),
          ],
          claudeCode: const ClaudeCodeToolInfo(toolName: 'Edit'),
          locations: [ToolLocation(path: 'lib/main.dart', line: 1)],
        ),
      );
      chatState.addApproval(
        ApprovalRequest(
          id: 'approval-1',
          sessionId: 'session-1',
          title: 'Review plan',
          kind: 'switch_mode',
          planMarkdown: '1. Do the thing',
          options: const [
            PermOption(
              optionId: 'allow',
              kind: PermOptionKind.allowAlways,
              name: 'Allow',
            ),
          ],
          createdAt: DateTime(2026, 1, 1, 0, 1),
          resolved: true,
        ),
      );
      chatState.updatePlan([
        PlanEntry(
          content: 'Do the thing',
          status: 'completed',
          priority: 'high',
        ),
      ]);

      await repository.persistSnapshot(
        sessionId: 'session-1',
        machineId: 'machine-1',
        title: 'Cached chat',
        chatState: chatState,
        configSnapshot: const SessionConfigSnapshot(
          modeConfigId: 'mode',
          modelConfigId: 'model',
          currentModel: 'gpt-5.4',
          currentMode: ModeOption(id: 'plan', label: 'Plan'),
          availableModels: [ModelInfo(value: 'gpt-5.4', name: 'GPT-5.4')],
          availableModes: [ModeOption(id: 'plan', label: 'Plan')],
        ),
        cacheState: SessionChatCacheState.ready,
        lastAppliedSeq: 42,
      );

      final hydrated = repository.hydratedCacheForSession('session-1');
      expect(hydrated, isNotNull);
      expect(hydrated!.entry.lastAppliedSeq, 42);
      expect(hydrated.chatState.orderedMessages, hasLength(2));
      expect(
        hydrated.chatState.runDiffSummaryAfter('user-1')?.files.single.path,
        'lib/main.dart',
      );
      expect(hydrated.chatState.approvals['approval-1']?.resolved, isTrue);
      expect(hydrated.configSnapshot.modeConfigId, 'mode');
      expect(hydrated.configSnapshot.currentModel, 'gpt-5.4');
      expect(hydrated.configSnapshot.currentMode?.id, 'plan');
    });

    test('hydrates legacy config snapshots that omit config ids', () async {
      final repository = SessionChatCacheRepository();
      await repository.init();
      final now = DateTime(2026, 1, 1, 0, 0);

      final db = await SessionDatabase.database;
      await db.insert(SessionDatabase.sessionChatCacheTable, {
        'session_id': 'session-legacy',
        'machine_id': 'machine-1',
        'title': 'Legacy chat',
        'cache_state': SessionChatCacheState.ready.value,
        'cache_version': sessionChatCacheSchemaVersion,
        'last_applied_seq': 3,
        'chat_state_json': jsonEncode({
          'messages': [
            {
              'id': 'msg-1',
              'sessionId': 'session-legacy',
              'role': 'user',
              'parts': [
                {'type': 'text', 'text': 'legacy message'},
              ],
              'createdAt': now.toIso8601String(),
            },
          ],
          'messageOrder': ['msg-1'],
          'toolsByCallId': const <String, dynamic>{},
          'approvalsById': const <String, dynamic>{},
          'planEntries': const <dynamic>[],
        }),
        'config_snapshot_json': jsonEncode({
          'currentModel': 'gpt-5.4',
          'currentMode': {'id': 'plan', 'label': 'Plan'},
          'availableModels': [
            {'value': 'gpt-5.4', 'name': 'GPT-5.4'},
          ],
          'availableModes': [
            {'id': 'plan', 'label': 'Plan'},
          ],
        }),
        'updated_at': now.toIso8601String(),
      });

      final reloaded = SessionChatCacheRepository();
      await reloaded.init();

      final hydrated = reloaded.hydratedCacheForSession('session-legacy');
      expect(hydrated, isNotNull);
      expect(hydrated!.entry.isRenderable, isTrue);
      expect(hydrated.configSnapshot.modeConfigId, isNull);
      expect(hydrated.configSnapshot.modelConfigId, isNull);
      expect(hydrated.configSnapshot.currentMode?.id, 'plan');
      expect(hydrated.configSnapshot.currentModel, 'gpt-5.4');
      expect(
        hydrated.chatState.orderedMessages.single.parts.single.text,
        'legacy message',
      );
    });

    test(
      'hydrates transcript even when config snapshot payload is invalid',
      () async {
        final repository = SessionChatCacheRepository();
        await repository.init();
        final now = DateTime(2026, 1, 1, 0, 0);

        final db = await SessionDatabase.database;
        await db.insert(SessionDatabase.sessionChatCacheTable, {
          'session_id': 'session-invalid-config',
          'machine_id': 'machine-1',
          'title': 'Invalid config chat',
          'cache_state': SessionChatCacheState.ready.value,
          'cache_version': sessionChatCacheSchemaVersion,
          'last_applied_seq': 4,
          'chat_state_json': jsonEncode({
            'messages': [
              {
                'id': 'msg-1',
                'sessionId': 'session-invalid-config',
                'role': 'user',
                'parts': [
                  {'type': 'text', 'text': 'hello'},
                ],
                'createdAt': now.toIso8601String(),
              },
            ],
            'messageOrder': ['msg-1'],
            'toolsByCallId': const <String, dynamic>{},
            'approvalsById': const <String, dynamic>{},
            'planEntries': const <dynamic>[],
          }),
          'config_snapshot_json': jsonEncode({
            'currentModel': 123,
            'currentMode': 'bad',
            'availableModels': 'bad',
            'availableModes': const <dynamic>[],
          }),
          'updated_at': now.toIso8601String(),
        });

        final reloaded = SessionChatCacheRepository();
        await reloaded.init();

        final hydrated = reloaded.hydratedCacheForSession(
          'session-invalid-config',
        );
        expect(hydrated, isNotNull);
        expect(hydrated!.entry.isRenderable, isTrue);
        expect(hydrated.configSnapshot, const SessionConfigSnapshot());
        expect(
          hydrated.chatState.orderedMessages.single.parts.single.text,
          'hello',
        );
      },
    );

    test(
      'persistSnapshot keeps authoritative user message after optimistic replacement',
      () async {
        final repository = SessionChatCacheRepository();
        await repository.init();
        final chatState = ChatState(sessionId: 'session-1');

        chatState.finalizeMessage(
          Message(
            id: 'local-1',
            sessionId: 'session-1',
            role: MessageRole.user,
            parts: [MessagePart(type: PartType.text, text: 'hello')],
            createdAt: DateTime(2026, 1, 1, 0, 0),
          ),
        );
        chatState.finalizeMessage(
          Message(
            id: 'assistant-1',
            sessionId: 'session-1',
            role: MessageRole.agent,
            parts: [MessagePart(type: PartType.text, text: 'world')],
            createdAt: DateTime(2026, 1, 1, 0, 1),
          ),
        );

        expect(chatState.adoptLocalOptimisticUserMessage('user-1'), isTrue);
        chatState.applyDelta(
          MessagePartEvent(
            partId: 'user-part-1',
            messageId: 'user-1',
            role: MessageRole.user,
            delta: 'hello',
            partType: 'text',
          ),
        );

        await repository.persistSnapshot(
          sessionId: 'session-1',
          machineId: 'machine-1',
          title: 'Cached chat',
          chatState: chatState,
          configSnapshot: const SessionConfigSnapshot(),
          cacheState: SessionChatCacheState.ready,
          lastAppliedSeq: 7,
        );

        final hydrated = repository.hydratedCacheForSession('session-1');
        expect(hydrated, isNotNull);
        expect(
          hydrated!.chatState.orderedMessages
              .map((message) => message.id)
              .toList(),
          ['user-1', 'assistant-1'],
        );
        expect(
          hydrated.chatState.orderedMessages.first.parts.single.text,
          'hello',
        );
        expect(hydrated.chatState.orderedMessages.first.role, MessageRole.user);
      },
    );

    test(
      'markMachineCachesStale downgrades only ready non-empty caches',
      () async {
        final repository = SessionChatCacheRepository();
        await repository.init();

        await repository.upsert(
          _entry(
            sessionId: 'ready-chat',
            machineId: 'machine-1',
            cacheState: SessionChatCacheState.ready,
            chatStateJson: _nonEmptyChatStateJson(),
          ),
        );
        await repository.upsert(
          _entry(
            sessionId: 'empty-chat',
            machineId: 'machine-1',
            cacheState: SessionChatCacheState.empty,
            chatStateJson: SessionChatCacheEntry.emptyChatStateJson(),
            configSnapshotJson: SessionChatCacheEntry.emptyConfigSnapshotJson(),
          ),
        );
        await repository.upsert(
          _entry(
            sessionId: 'already-stale',
            machineId: 'machine-1',
            cacheState: SessionChatCacheState.stale,
            chatStateJson: _nonEmptyChatStateJson(),
          ),
        );
        await repository.upsert(
          _entry(
            sessionId: 'other-machine',
            machineId: 'machine-2',
            cacheState: SessionChatCacheState.ready,
            chatStateJson: _nonEmptyChatStateJson(),
          ),
        );

        final updatedCount = await repository.markMachineCachesStale(
          'machine-1',
        );

        expect(updatedCount, 1);
        expect(
          repository.cacheForSession('ready-chat')?.cacheState,
          SessionChatCacheState.stale,
        );
        expect(
          repository.cacheForSession('empty-chat')?.cacheState,
          SessionChatCacheState.empty,
        );
        expect(
          repository.cacheForSession('already-stale')?.cacheState,
          SessionChatCacheState.stale,
        );
        expect(
          repository.cacheForSession('other-machine')?.cacheState,
          SessionChatCacheState.ready,
        );

        final reloaded = SessionChatCacheRepository();
        await reloaded.init();
        expect(
          reloaded.cacheForSession('ready-chat')?.cacheState,
          SessionChatCacheState.stale,
        );
      },
    );

    test('upgrades sqlite 1 to 2 without wiping sessions', () async {
      final legacyDb = await openDatabase(
        dbPath,
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE sessions (
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
          await db.insert('sessions', {
            'id': 'legacy-session',
            'title': 'Legacy',
            'status': 'idle',
            'model': null,
            'cost_amount': 0,
            'cost_currency': 'USD',
            'total_tokens': 0,
            'machine_id': 'machine-1',
            'runtime': 'codex',
            'cwd': '/tmp',
            'mode': '',
            'created_at': DateTime(2026, 1, 1).toIso8601String(),
            'updated_at': DateTime(2026, 1, 1).toIso8601String(),
            'is_read': 0,
          });
        },
      );
      await legacyDb.close();

      await SessionDatabase.resetForTest(databasePathOverride: dbPath);
      final upgradedDb = await SessionDatabase.database;

      final cacheTables = await upgradedDb.query(
        'sqlite_master',
        columns: const ['name'],
        where: 'type = ? AND name = ?',
        whereArgs: ['table', SessionDatabase.sessionChatCacheTable],
      );
      expect(cacheTables, hasLength(1));
      expect(cacheTables.single['name'], SessionDatabase.sessionChatCacheTable);

      final rows = await upgradedDb.query(
        SessionDatabase.sessionsTable,
        where: 'id = ?',
        whereArgs: ['legacy-session'],
      );
      expect(rows, hasLength(1));
      expect(rows.single['runtime'], 'codex');
      expect(rows.single['cwd'], '/tmp');

      final cacheColumns = await upgradedDb.rawQuery(
        'PRAGMA table_info(${SessionDatabase.sessionChatCacheTable})',
      );
      expect(
        cacheColumns.map((column) => column['name']),
        contains('last_applied_seq'),
      );
    });
  });
}

SessionChatCacheEntry _entry({
  required String sessionId,
  required String machineId,
  required SessionChatCacheState cacheState,
  required Map<String, dynamic> chatStateJson,
  Map<String, dynamic>? configSnapshotJson,
}) {
  return SessionChatCacheEntry(
    sessionId: sessionId,
    machineId: machineId,
    title: sessionId,
    cacheState: cacheState,
    lastAppliedSeq: 0,
    chatStateJson: chatStateJson,
    configSnapshotJson:
        configSnapshotJson ?? SessionChatCacheEntry.emptyConfigSnapshotJson(),
    updatedAt: DateTime(2026, 1, 1),
  );
}

Map<String, dynamic> _nonEmptyChatStateJson() {
  return {
    'messages': [
      {
        'messageId': 'msg-1',
        'role': 'agent',
        'createdAt': DateTime(2026, 1, 1).toIso8601String(),
        'parts': [
          {'type': 'text', 'text': 'hello'},
        ],
      },
    ],
    'messageOrder': ['msg-1'],
    'toolsByCallId': const <String, dynamic>{},
    'approvalsById': const <String, dynamic>{},
    'planEntries': const <dynamic>[],
  };
}
