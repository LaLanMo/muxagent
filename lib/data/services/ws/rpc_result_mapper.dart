import '../../../domain/approval.dart';
import '../../../domain/enums.dart';
import '../../../domain/fs_entry.dart';
import '../../../domain/session_config_snapshot.dart';
import 'approval_event_mapper.dart';
import 'session_config_mapper.dart';
import 'models/approval_event_models.dart';
import 'models/rpc_result_models.dart';

class ResolvedSessionSnapshot {
  final String sessionId;
  final String title;
  final String cwd;
  final String runtime;
  final SessionStatus status;
  final DateTime? updatedAt;
  final SessionConfigSnapshot? configSnapshot;

  const ResolvedSessionSnapshot({
    required this.sessionId,
    required this.title,
    required this.cwd,
    this.runtime = '',
    required this.status,
    required this.updatedAt,
    this.configSnapshot,
  });
}

class RpcResultMapper {
  static List<FsEntry> toFsEntries(Iterable<RpcFsEntryDto> entries) {
    return entries
        .map(
          (entry) => FsEntry(
            name: (entry.name?.trim().isNotEmpty ?? false)
                ? entry.name!.trim()
                : entry.path.split('/').last,
            path: entry.path,
            isDir: entry.isDir,
          ),
        )
        .toList();
  }

  static List<ResolvedSessionSnapshot> toResolvedSessions(
    Iterable<RpcResolvedSessionDto> sessions,
  ) {
    return sessions
        .map(
          (session) => ResolvedSessionSnapshot(
            sessionId: session.sessionId,
            title: session.title?.trim() ?? '',
            cwd: session.cwd?.trim() ?? '',
            runtime: session.runtime?.trim() ?? '',
            status: SessionStatus.fromValue(session.status?.trim() ?? 'idle'),
            updatedAt: session.updatedAt,
            configSnapshot: session.configOptions == null
                ? null
                : SessionConfigMapper.snapshotFromConfigOptions(
                    runtimeId: session.runtime?.trim() ?? '',
                    configOptions: session.configOptions!,
                  ),
          ),
        )
        .toList();
  }

  static List<ApprovalRequest> toPendingApprovals(
    Iterable<ApprovalWireDto> approvals,
  ) {
    return approvals.map(ApprovalEventMapper.toDomainApproval).toList();
  }
}
