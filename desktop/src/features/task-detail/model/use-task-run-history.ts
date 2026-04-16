import { useEffect, useEffectEvent } from "react";
import {
  loadTaskRunFullHistory,
  loadTaskRunHistory,
} from "@/application/tasks";
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
  shouldLoad?: boolean;
};

function isOpenRunStatus(status: string | undefined): boolean {
  const normalized = status?.trim().toLowerCase() ?? "";
  return normalized.includes("run") || normalized.includes("await");
}

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
  shouldLoad = true,
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
  const shouldPollOpenHistory =
    Boolean(selectedRunId) &&
    shouldLoad &&
    connected &&
    historyEntry?.signature === signature &&
    !historyEntry?.loading &&
    isOpenRunStatus(selectedRun?.status) &&
    (
      historyEntry?.result?.completeness !== "complete" ||
      historyEntry?.result?.provenance === "none" ||
      Boolean(historyEntry?.error)
    );

  useEffect(() => {
    if (!selectedRunId || !connected || !shouldLoad) {
      return;
    }
    if (historyEntry?.loading) {
      return;
    }
    const shouldRefreshOpenReplay =
      historyEntry?.signature === signature &&
      Boolean(detailEntry?.stale) &&
      (isOpenRunStatus(selectedRun?.status) ||
        historyEntry?.result?.completeness !== "complete" ||
        historyEntry?.result?.provenance === "none");
    if (
      historyEntry?.signature === signature &&
      (historyEntry?.result || historyEntry?.error) &&
      !shouldRefreshOpenReplay
    ) {
      return;
    }
    void loadRunHistory(selectedRunId, signature);
  }, [
    connected,
    detailEntry?.stale,
    historyEntry,
    loadRunHistory,
    shouldLoad,
    selectedRun?.status,
    selectedRunId,
    signature,
  ]);

  useEffect(() => {
    if (!selectedRunId || !shouldPollOpenHistory) {
      return;
    }
    const timer = window.setTimeout(() => {
      void loadRunHistory(selectedRunId, signature);
    }, 2000);
    return () => window.clearTimeout(timer);
  }, [loadRunHistory, selectedRunId, shouldPollOpenHistory, signature]);

  return historyEntry;
}

type UseTaskRunFullHistoryArgs = {
  workspaceId: string;
  taskId: string;
  connected: boolean;
  selectedRun?: NodeRunViewDto;
  detailEntry?: TaskDetailCacheEntry;
  shouldLoad?: boolean;
};

export function useTaskRunFullHistory({
  workspaceId,
  taskId,
  connected,
  selectedRun,
  detailEntry,
  shouldLoad = false,
}: UseTaskRunFullHistoryArgs): RunHistoryCacheEntry | undefined {
  const beginFullRunHistoryLoad = useTaskSnapshotStore(
    (state) => state.beginFullRunHistoryLoad,
  );
  const resolveFullRunHistory = useTaskSnapshotStore(
    (state) => state.resolveFullRunHistory,
  );
  const failFullRunHistory = useTaskSnapshotStore(
    (state) => state.failFullRunHistory,
  );

  const loadRunHistory = useEffectEvent(
    async (nodeRunId: string, signature: string) => {
      if (!workspaceId || !taskId || !connected) {
        return;
      }
      beginFullRunHistoryLoad(workspaceId, taskId, nodeRunId, signature);
      try {
        const result = await loadTaskRunFullHistory(
          getRuntime(),
          workspaceId,
          taskId,
          nodeRunId,
        );
        resolveFullRunHistory(workspaceId, taskId, nodeRunId, signature, result);
      } catch (error) {
        failFullRunHistory(
          workspaceId,
          taskId,
          nodeRunId,
          signature,
          error instanceof Error ? error.message : "Failed to load full run history",
        );
      }
    },
  );

  const selectedRunId = selectedRun?.id;
  const signature = runHistorySignature(selectedRun);
  const historyEntry = selectedRunId
    ? detailEntry?.runHistoryByRunId?.[selectedRunId]
    : undefined;
  const shouldPollOpenHistory =
    Boolean(selectedRunId) &&
    shouldLoad &&
    connected &&
    historyEntry?.fullSignature === signature &&
    !historyEntry?.fullLoading &&
    isOpenRunStatus(selectedRun?.status) &&
    (
      historyEntry?.fullResult?.completeness !== "complete" ||
      historyEntry?.fullResult?.provenance === "none" ||
      Boolean(historyEntry?.fullError)
    );

  useEffect(() => {
    if (!selectedRunId || !connected || !shouldLoad) {
      return;
    }
    if (historyEntry?.fullLoading) {
      return;
    }
    const shouldRefreshOpenReplay =
      historyEntry?.fullSignature === signature &&
      Boolean(detailEntry?.stale) &&
      (isOpenRunStatus(selectedRun?.status) ||
        historyEntry?.fullResult?.completeness !== "complete" ||
        historyEntry?.fullResult?.provenance === "none");
    if (
      historyEntry?.fullSignature === signature &&
      (historyEntry?.fullResult || historyEntry?.fullError) &&
      !shouldRefreshOpenReplay
    ) {
      return;
    }
    void loadRunHistory(selectedRunId, signature);
  }, [
    connected,
    detailEntry?.stale,
    historyEntry,
    loadRunHistory,
    shouldLoad,
    selectedRun?.status,
    selectedRunId,
    signature,
  ]);

  useEffect(() => {
    if (!selectedRunId || !shouldPollOpenHistory) {
      return;
    }
    const timer = window.setTimeout(() => {
      void loadRunHistory(selectedRunId, signature);
    }, 2000);
    return () => window.clearTimeout(timer);
  }, [loadRunHistory, selectedRunId, shouldPollOpenHistory, signature]);

  return historyEntry;
}
