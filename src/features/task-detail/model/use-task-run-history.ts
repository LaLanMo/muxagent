import { useEffect, useEffectEvent } from "react";
import { loadTaskRunHistory } from "@/application/tasks";
import { getRuntime } from "@/app/runtime";
import type { NodeRunViewDto } from "@/rpc/types";
import type {
  RunHistoryCacheEntry,
  TaskDetailCacheEntry,
} from "@/state/task-snapshot-store";
import { useTaskSnapshotStore } from "@/state/task-snapshot-store";

type UseTaskRunHistoryArgs = {
  workspaceId: string;
  taskId: string;
  connected: boolean;
  selectedRun?: NodeRunViewDto;
  detailEntry?: TaskDetailCacheEntry;
};

function runHistorySignature(run: NodeRunViewDto | undefined): string {
  if (!run) {
    return "";
  }
  return [
    run.id,
    run.status,
    run.started_at ?? "",
    run.completed_at ?? "",
    run.failure_reason ?? "",
    run.session_id ?? "",
  ].join("|");
}

export function useTaskRunHistory({
  workspaceId,
  taskId,
  connected,
  selectedRun,
  detailEntry,
}: UseTaskRunHistoryArgs): RunHistoryCacheEntry | undefined {
  const beginRunHistoryLoad = useTaskSnapshotStore(
    (state) => state.beginRunHistoryLoad,
  );
  const resolveRunHistory = useTaskSnapshotStore(
    (state) => state.resolveRunHistory,
  );
  const failRunHistory = useTaskSnapshotStore((state) => state.failRunHistory);

  const loadRunHistory = useEffectEvent(
    async (nodeRunId: string, signature: string) => {
      if (!workspaceId || !taskId || !connected) {
        return;
      }
      beginRunHistoryLoad(workspaceId, taskId, nodeRunId, signature);
      try {
        const result = await loadTaskRunHistory(
          getRuntime(),
          workspaceId,
          taskId,
          nodeRunId,
        );
        resolveRunHistory(workspaceId, taskId, nodeRunId, signature, result);
      } catch (error) {
        failRunHistory(
          workspaceId,
          taskId,
          nodeRunId,
          signature,
          error instanceof Error ? error.message : "Failed to load run history",
        );
      }
    },
  );

  const selectedRunId = selectedRun?.id;
  const signature = runHistorySignature(selectedRun);
  const historyEntry = selectedRunId
    ? detailEntry?.runHistoryByRunId?.[selectedRunId]
    : undefined;

  useEffect(() => {
    if (!selectedRunId || !connected) {
      return;
    }
    if (historyEntry?.loading) {
      return;
    }
    if (
      historyEntry?.signature === signature &&
      (historyEntry?.result || historyEntry?.error)
    ) {
      return;
    }
    void loadRunHistory(selectedRunId, signature);
  }, [connected, historyEntry, loadRunHistory, selectedRunId, signature]);

  return historyEntry;
}
