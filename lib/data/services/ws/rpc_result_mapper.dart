import '../../../domain/approval.dart';
import '../../../domain/enums.dart';
import '../../../domain/fs_entry.dart';
import 'approval_event_mapper.dart';
import 'models/approval_event_models.dart';
import 'models/rpc_result_models.dart';

class ResolvedSessionSnapshot {
  final String sessionId;
  final String title;
  final String cwd;
  final SessionStatus status;
  final DateTime? updatedAt;

  const ResolvedSessionSnapshot({
    required this.sessionId,
    required this.title,
    required this.cwd,
    required this.status,
    required this.updatedAt,
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
            status: SessionStatus.fromValue(session.status?.trim() ?? 'idle'),
            updatedAt: session.updatedAt,
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
