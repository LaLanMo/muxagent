import { useLocation } from "react-router-dom";
import { collectScopedTasks } from "@/domain/task-shell";
import { parseTaskBoardPath, taskBoardTabId } from "@/domain/routes";
import { useShellModel } from "@/features/app/model/use-shell-model";
import { buildEntryTaskBoardModel } from "@/features/entry/model/task-board-model";
import { tasksForWorkspace, useTaskSnapshotStore } from "@/state/task-snapshot-store";
import { useWorkspaceStore } from "@/state/workspace-store";

export function useEntryScreen() {
  const shell = useShellModel();
  const location = useLocation();
  const workspaces = useWorkspaceStore((state) => state.workspaces);
  const tasksById = useTaskSnapshotStore((state) => state.tasksById);
  const taskIdsByWorkspaceId = useTaskSnapshotStore(
    (state) => state.taskIdsByWorkspaceId,
  );
  const boardScope = parseTaskBoardPath(location.pathname) ?? { kind: "all" as const };
  const boardWorkspace =
    boardScope.kind === "workspace"
      ? workspaces.find(
          (workspace) => workspace.workspace_id === boardScope.workspaceId,
        )
      : undefined;
  const scopedTasks =
    boardScope.kind === "workspace"
      ? tasksForWorkspace(
          taskIdsByWorkspaceId,
          tasksById,
          boardScope.workspaceId,
        ).map((task) => ({
          workspaceId: boardScope.workspaceId,
          workspaceLabel: boardWorkspace?.display_name ?? "Workspace",
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
    boardTabId: taskBoardTabId(boardScope),
    boardTitle: boardWorkspace?.display_name ?? "Board",
  };
}
