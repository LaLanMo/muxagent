import { useEffect, useEffectEvent } from "react";
import { hydrateTaskDetail } from "@/application/tasks";
import { getRuntime } from "@/app/runtime";
import type { TaskViewDto } from "@/rpc/types";
import type { TaskDetailCacheEntry } from "@/state/task-snapshot-store";
import {
  shouldReplaceTask,
  taskForWorkspace,
  useTaskSnapshotStore,
} from "@/state/task-snapshot-store";

export type LoadTaskDetailFn = (
  options?: { showLoading?: boolean },
) => Promise<Awaited<ReturnType<typeof hydrateTaskDetail>> | undefined>;

type UseTaskDetailHydrationArgs = {
  workspaceId: string;
  taskId: string;
  connected: boolean;
  task?: TaskViewDto;
  detailEntry?: TaskDetailCacheEntry;
};

export function useTaskDetailHydration({
  workspaceId,
  taskId,
  connected,
  task,
  detailEntry,
}: UseTaskDetailHydrationArgs) {
  const upsertTask = useTaskSnapshotStore((state) => state.upsertTask);
  const beginTaskDetailLoad = useTaskSnapshotStore(
    (state) => state.beginTaskDetailLoad,
  );
  const hydrateLiveEvents = useTaskSnapshotStore(
    (state) => state.hydrateLiveEvents,
  );
  const resolveTaskDetail = useTaskSnapshotStore(
    (state) => state.resolveTaskDetail,
  );
  const failTaskDetail = useTaskSnapshotStore(
    (state) => state.failTaskDetail,
  );

  const loadDetail = useEffectEvent<LoadTaskDetailFn>(
    async (options = {}) => {
      if (!taskId || !workspaceId || !connected) {
        return undefined;
      }
      if (options.showLoading ?? true) {
        beginTaskDetailLoad(workspaceId, taskId);
      }
      try {
        const detail = await hydrateTaskDetail(getRuntime(), workspaceId, taskId);
        const currentTask = taskForWorkspace(
          useTaskSnapshotStore.getState().tasksById,
          workspaceId,
          taskId,
        );
        const shouldApplyTaskSnapshot = shouldReplaceTask(currentTask, detail.task);
        if (shouldApplyTaskSnapshot) {
          upsertTask(workspaceId, detail.task);
          hydrateLiveEvents(
            workspaceId,
            taskId,
            detail.task.status,
            detail.liveEventsRunId,
            detail.liveEvents,
          );
        }
        resolveTaskDetail(workspaceId, taskId, {
          config: detail.config,
          inputRequest: detail.inputRequest,
          artifacts: detail.artifacts,
          liveEventsRunId: detail.liveEventsRunId,
        });
        return detail;
      } catch (error) {
        failTaskDetail(
          workspaceId,
          taskId,
          error instanceof Error ? error.message : "Failed to load task detail",
        );
        return undefined;
      }
    },
  );

  const hydrate = useEffectEvent(async () => {
    await loadDetail();
  });

  useEffect(() => {
    if (!taskId || !connected) {
      return;
    }
    if (!task || !detailEntry || detailEntry.stale) {
      void hydrate();
    }
  }, [connected, detailEntry, hydrate, task, taskId]);

  return { loadDetail };
}
