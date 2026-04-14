import type { SessionHistoryEvent } from "@/domain/session-history";
import {
  taskForWorkspace,
  useTaskSnapshotStore,
} from "@/state/task-snapshot-store";

const emptyLiveEvents: SessionHistoryEvent[] = [];

type UseTaskDetailStoreEntryArgs = {
  workspaceId: string;
  taskId: string;
};

export function useTaskDetailStoreEntry({
  workspaceId,
  taskId,
}: UseTaskDetailStoreEntryArgs) {
  const task = useTaskSnapshotStore((state) =>
    taskId && workspaceId
      ? taskForWorkspace(state.tasksById, workspaceId, taskId)
      : undefined,
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

  return {
    task,
    detailEntry,
    liveEvents,
    liveEventsRunId,
  };
}
