import { buildInboxItems } from "@/domain/task-shell";
import { useShellChrome } from "@/features/app/model/use-shell-chrome";
import { useTaskSnapshotStore } from "@/state/task-snapshot-store";
import { useWorkspaceStore } from "@/state/workspace-store";

const emptyTasks: never[] = [];

export function useInboxScreen() {
  const shell = useShellChrome();
  const selectedWorkspaceId = useWorkspaceStore(
    (state) => state.selectedWorkspaceId,
  );
  const tasks = useTaskSnapshotStore(
    (state) =>
      (selectedWorkspaceId
        ? state.tasksByWorkspaceId[selectedWorkspaceId]
        : undefined) ?? emptyTasks,
  );

  return {
    shell,
    items: selectedWorkspaceId ? buildInboxItems(tasks, selectedWorkspaceId) : [],
  };
}
