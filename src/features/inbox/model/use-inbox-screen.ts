import { buildInboxItems, collectScopedTasks } from "@/domain/task-shell";
import { useShellModel } from "@/features/app/model/use-shell-model";
import { useTaskSnapshotStore } from "@/state/task-snapshot-store";
import { useWorkspaceStore } from "@/state/workspace-store";

const emptyTasks: never[] = [];

export function useInboxScreen() {
  const shell = useShellModel();
  const selectedWorkspaceId = useWorkspaceStore(
    (state) => state.selectedWorkspaceId,
  );
  const workspaces = useWorkspaceStore((state) => state.workspaces);
  const tasksByWorkspaceId = useTaskSnapshotStore((state) => state.tasksByWorkspaceId);
  const tasks = selectedWorkspaceId
    ? (tasksByWorkspaceId[selectedWorkspaceId] ?? emptyTasks).map((task) => ({
        workspaceId: selectedWorkspaceId,
        workspaceLabel:
          workspaces.find((workspace) => workspace.workspace_id === selectedWorkspaceId)
            ?.display_name ?? "Workspace",
        task,
      }))
    : collectScopedTasks(workspaces, tasksByWorkspaceId);

  return {
    shell,
    items: buildInboxItems(tasks),
  };
}
