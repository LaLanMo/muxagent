import {
  collectScopedTasks,
} from "@/domain/task-shell";
import { useShellModel } from "@/features/app/model/use-shell-model";
import { buildEntryTaskBoardModel } from "@/features/entry/model/task-board-model";
import { tasksForWorkspace, useTaskSnapshotStore } from "@/state/task-snapshot-store";
import { useWorkspaceStore } from "@/state/workspace-store";

export function useEntryScreen() {
  const shell = useShellModel();
  const selectedWorkspaceId = useWorkspaceStore(
    (state) => state.selectedWorkspaceId,
  );
  const workspaces = useWorkspaceStore((state) => state.workspaces);
  const tasksById = useTaskSnapshotStore((state) => state.tasksById);
  const taskIdsByWorkspaceId = useTaskSnapshotStore(
    (state) => state.taskIdsByWorkspaceId,
  );
  const scopedTasks = selectedWorkspaceId
    ? tasksForWorkspace(taskIdsByWorkspaceId, tasksById, selectedWorkspaceId).map((task) => ({
        workspaceId: selectedWorkspaceId,
        workspaceLabel:
          workspaces.find((workspace) => workspace.workspace_id === selectedWorkspaceId)
            ?.display_name ?? "Workspace",
        task,
      }))
    : collectScopedTasks(workspaces, taskIdsByWorkspaceId, tasksById);
  const catalog = useWorkspaceStore((state) => state.catalog);
  const taskBoardModel = buildEntryTaskBoardModel({
    scopedTasks,
    boardFilter: shell.boardFilter,
  });

  return {
    shell,
    columns: taskBoardModel.columns,
    rows: taskBoardModel.rows,
    hasTasks: taskBoardModel.hasTasks,
    launchableEntries: (catalog?.entries ?? []).filter((entry) => entry.launchable),
  };
}
