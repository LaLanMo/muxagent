import { useEffect, useEffectEvent, useRef, useState } from "react";
import { loadTaskWorktreeCleanupInfo } from "@/application/tasks";
import { getRuntime } from "@/app/runtime";
import { isWorktreeTask } from "@/domain/task-shell";
import type { TaskViewDto, WorktreeCleanupInfoDto } from "@/rpc/types";

export type LoadTaskWorktreeCleanupInfoFn = (
  options?: { showLoading?: boolean },
) => Promise<WorktreeCleanupInfoDto | undefined>;

type UseTaskWorktreeCleanupArgs = {
  workspaceId: string;
  taskId: string;
  connected: boolean;
  supported: boolean;
  task?: TaskViewDto;
};

export function useTaskWorktreeCleanup({
  workspaceId,
  taskId,
  connected,
  supported,
  task,
}: UseTaskWorktreeCleanupArgs) {
  const [cleanupInfo, setCleanupInfo] = useState<WorktreeCleanupInfoDto | undefined>();
  const [cleanupLoading, setCleanupLoading] = useState(false);
  const [cleanupError, setCleanupError] = useState<string | undefined>();
  const latestRequestIdRef = useRef(0);
  const eligible =
    connected &&
    supported &&
    Boolean(task && task.status === "done" && isWorktreeTask(task));
  const taskSnapshotKey = task ? `${task.status}|${task.task.updated_at}` : "";

  const loadCleanupInfo = useEffectEvent<LoadTaskWorktreeCleanupInfoFn>(
    async (options = {}) => {
      if (!eligible || !workspaceId || !taskId) {
        return undefined;
      }
      const requestId = latestRequestIdRef.current + 1;
      latestRequestIdRef.current = requestId;
      if (options.showLoading ?? true) {
        setCleanupLoading(true);
      }
      setCleanupError(undefined);
      try {
        const info = await loadTaskWorktreeCleanupInfo(getRuntime(), workspaceId, taskId);
        if (latestRequestIdRef.current === requestId) {
          setCleanupInfo(info);
        }
        return info;
      } catch (error) {
        const message =
          error instanceof Error ? error.message : "Failed to load worktree cleanup info";
        if (latestRequestIdRef.current === requestId) {
          setCleanupError(message);
        }
        return undefined;
      } finally {
        if (latestRequestIdRef.current === requestId) {
          setCleanupLoading(false);
        }
      }
    },
  );

  useEffect(() => {
    latestRequestIdRef.current += 1;
    setCleanupInfo(undefined);
    setCleanupLoading(false);
    setCleanupError(undefined);
  }, [eligible, taskId, taskSnapshotKey, workspaceId]);

  return {
    cleanupInfo,
    cleanupLoading,
    cleanupError,
    clearCleanupError: () => setCleanupError(undefined),
    loadCleanupInfo,
    setCleanupInfo,
  };
}
