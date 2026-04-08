import { useEffect, useEffectEvent } from "react";
import { hydrateTaskDetail } from "@/application/tasks";
import { getRuntime } from "@/app/runtime";
import type { TaskDetailCacheEntry } from "@/state/task-snapshot-store";
import { useTaskSnapshotStore } from "@/state/task-snapshot-store";

export type LoadTaskDetailFn = (
  options?: { showLoading?: boolean },
) => Promise<Awaited<ReturnType<typeof hydrateTaskDetail>> | undefined>;

type UseTaskDetailHydrationArgs = {
  workspaceId: string;
  taskId: string;
  connected: boolean;
  detailEntry?: TaskDetailCacheEntry;
};

export function useTaskDetailHydration({
  workspaceId,
  taskId,
  connected,
  detailEntry,
}: UseTaskDetailHydrationArgs) {
  const upsertTask = useTaskSnapshotStore((state) => state.upsertTask);
  const beginTaskDetailLoad = useTaskSnapshotStore(
    (state) => state.beginTaskDetailLoad,
  );
  const hydrateLiveOutput = useTaskSnapshotStore(
    (state) => state.hydrateLiveOutput,
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
        upsertTask(workspaceId, detail.task);
        hydrateLiveOutput(
          workspaceId,
          taskId,
          detail.task.status,
          detail.liveOutputRunId,
          detail.liveOutput,
        );
        resolveTaskDetail(workspaceId, taskId, {
          task: detail.task,
          config: detail.config,
          inputRequest: detail.inputRequest,
          artifacts: detail.artifacts,
          liveOutputRunId: detail.liveOutputRunId,
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
    if (!detailEntry || detailEntry.stale) {
      void hydrate();
    }
  }, [connected, detailEntry, hydrate, taskId]);

  return { loadDetail };
}
