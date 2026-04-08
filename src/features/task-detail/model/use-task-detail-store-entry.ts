import type { SessionHistoryEvent } from "@/domain/session-history";
import type { TaskViewDto } from "@/rpc/types";
import { useTaskSnapshotStore } from "@/state/task-snapshot-store";

const emptyTasks: never[] = [];
const emptyLiveEvents: SessionHistoryEvent[] = [];

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
  const liveEvents = useTaskSnapshotStore(
    (state) =>
      (workspaceId
        ? state.liveEventsByWorkspaceId[workspaceId]?.[taskId]
        : undefined) ?? emptyLiveEvents,
  );
  const liveEventsRunId = useTaskSnapshotStore(
    (state) =>
      workspaceId
        ? state.liveEventRunIdsByWorkspaceId[workspaceId]?.[taskId]
        : undefined,
  );
  const taskFromList = tasks.find((entry: TaskViewDto) => entry.task.id === taskId);

  return {
    task: detailEntry?.task ?? taskFromList,
    detailEntry,
    liveEvents,
    liveEventsRunId,
  };
}
