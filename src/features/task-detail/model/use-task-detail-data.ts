import { useTaskDetailHydration } from "@/features/task-detail/model/use-task-detail-hydration";
import { useTaskDetailStoreEntry } from "@/features/task-detail/model/use-task-detail-store-entry";
export type { LoadTaskDetailFn } from "@/features/task-detail/model/use-task-detail-hydration";

type UseTaskDetailDataArgs = {
  workspaceId: string;
  taskId: string;
  connected: boolean;
};

export function useTaskDetailData({
  workspaceId,
  taskId,
  connected,
}: UseTaskDetailDataArgs) {
  const { task, detailEntry, liveOutput } = useTaskDetailStoreEntry({
    workspaceId,
    taskId,
  });
  const { loadDetail } = useTaskDetailHydration({
    workspaceId,
    taskId,
    connected,
    detailEntry,
  });

  return {
    task,
    detailEntry,
    liveOutput,
    loadDetail,
  };
}
