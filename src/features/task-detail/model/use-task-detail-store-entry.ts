import type { TaskViewDto } from "@/rpc/types";
import { useTaskSnapshotStore } from "@/state/task-snapshot-store";

const emptyTasks: never[] = [];
const emptyLiveOutput: string[] = [];

type UseTaskDetailStoreEntryArgs = {
  workspaceId: string;
  taskId: string;
};

export function useTaskDetailStoreEntry({
  workspaceId,
  taskId,
}: UseTaskDetailStoreEntryArgs) {
  const tasks = useTaskSnapshotStore(
    (state) =>
      (workspaceId
        ? state.tasksByWorkspaceId[workspaceId]
        : undefined) ?? emptyTasks,
  );
  const detailEntry = useTaskSnapshotStore(
    (state) =>
      (workspaceId
        ? state.taskDetailsByWorkspaceId[workspaceId]?.[taskId]
        : undefined),
  );
  const liveOutput = useTaskSnapshotStore(
    (state) =>
      (workspaceId
        ? state.liveOutputByWorkspaceId[workspaceId]?.[taskId]
        : undefined) ?? emptyLiveOutput,
  );
  const taskFromList = tasks.find((entry: TaskViewDto) => entry.task.id === taskId);

  return {
    task: detailEntry?.task ?? taskFromList,
    detailEntry,
    liveOutput,
  };
}
