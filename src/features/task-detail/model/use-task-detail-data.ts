import { useTaskDetailHydration } from "@/features/task-detail/model/use-task-detail-hydration";
import { useTaskDetailStoreEntry } from "@/features/task-detail/model/use-task-detail-store-entry";
export type { LoadTaskDetailFn } from "@/features/task-detail/model/use-task-detail-hydration";

type UseTaskDetailDataArgs = {
  workspaceId: string;
  taskId: string;
  connected: boolean;
  supportsTaskAncestry: boolean;
};

export function useTaskDetailData({
  workspaceId,
  taskId,
  connected,
  supportsTaskAncestry,
}: UseTaskDetailDataArgs) {
  const { task, detailEntry, liveEvents, liveEventsRunId } = useTaskDetailStoreEntry({
    workspaceId,
    taskId,
  });
  const { loadDetail } = useTaskDetailHydration({
    workspaceId,
    taskId,
    connected,
    supportsTaskAncestry,
    task,
    detailEntry,
  });

  return {
    task,
    detailEntry,
    liveEvents,
    liveEventsRunId,
    loadDetail,
  };
}
