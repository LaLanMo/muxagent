import { useEffect, useEffectEvent } from "react";
import { hydrateTaskDetail } from "@/application/tasks";
import { getRuntime } from "@/app/runtime";
import type { TaskViewDto } from "@/rpc/types";
import type { TaskDetailCacheEntry } from "@/state/task-snapshot-store";
import {
  taskSnapshotKey,
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
  supportsTaskAncestry: boolean;
  task?: TaskViewDto;
  detailEntry?: TaskDetailCacheEntry;
};

export function useTaskDetailHydration({
  workspaceId,
  taskId,
  connected,
  supportsTaskAncestry,
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
  const failTaskDetailLoad = useTaskSnapshotStore(
    (state) => state.failTaskDetailLoad,
  );

  const loadDetail = useEffectEvent<LoadTaskDetailFn>(
    async (options = {}) => {
      if (!taskId || !workspaceId || !connected) {
        return undefined;
      }
      const requestedTask = taskForWorkspace(
        useTaskSnapshotStore.getState().tasksById,
        workspaceId,
        taskId,
      );
      const requestedSnapshotKey = taskSnapshotKey(requestedTask);
      const generation = beginTaskDetailLoad(workspaceId, taskId, requestedSnapshotKey, {
        showLoading: options.showLoading,
      });
      try {
        const detail = await hydrateTaskDetail(getRuntime(), workspaceId, taskId, {
          includeAncestry: supportsTaskAncestry,
        });
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
        resolveTaskDetail(
          workspaceId,
          taskId,
          taskSnapshotKey(detail.task),
          generation,
          {
          config: detail.config,
          inputRequest: detail.inputRequest,
          followUp: detail.followUp,
          artifacts: detail.artifacts,
          ancestry: detail.ancestry,
          liveEventsRunId: detail.liveEventsRunId,
          },
        );
        return detail;
      } catch (error) {
        failTaskDetailLoad(
          workspaceId,
          taskId,
          requestedSnapshotKey,
          generation,
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
