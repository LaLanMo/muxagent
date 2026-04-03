import { useState } from "react";
import {
  removeWorkspace,
  renameWorkspace,
} from "@/application/workspace";
import { getRuntime } from "@/app/runtime";
import { displayWorkspaceName } from "@/domain/task-shell";
import { useShellChrome } from "@/features/app/model/use-shell-chrome";
import { useWorkspaceSelection } from "@/features/app/model/use-workspace-selection";
import { useTaskSnapshotStore } from "@/state/task-snapshot-store";
import { useWorkspaceStore } from "@/state/workspace-store";

export type SettingsWorkspaceRowModel = {
  id: string;
  label: string;
  path: string;
  pathLabel: string;
  selected: boolean;
  reachable: boolean;
  actorState: string;
  taskSummary: string;
  editing: boolean;
  pendingRename: boolean;
  pendingRemove: boolean;
};

function summarizeTasks(counts: {
  running: number;
  awaiting: number;
  done: number;
  failed: number;
}): string {
  return `${counts.running} running · ${counts.awaiting} awaiting · ${counts.done} done · ${counts.failed} failed`;
}

function actorStateLabel(state: string, reachable: boolean): string {
  if (!reachable) {
    return "Unavailable";
  }
  switch (state) {
    case "running":
      return "Running";
    case "failed":
      return "Failed";
    case "starting":
      return "Starting";
    case "idle":
    default:
      return "Idle";
  }
}

export function useSettingsScreen() {
  const shell = useShellChrome();
  const { selectWorkspace } = useWorkspaceSelection();
  const status = useWorkspaceStore((state) => state.status);
  const server = useWorkspaceStore((state) => state.server);
  const workspaces = useWorkspaceStore((state) => state.workspaces);
  const selectedWorkspaceId = useWorkspaceStore(
    (state) => state.selectedWorkspaceId,
  );
  const upsertWorkspace = useWorkspaceStore((state) => state.upsertWorkspace);
  const removeWorkspaceFromStore = useWorkspaceStore((state) => state.removeWorkspace);
  const setSelectedWorkspace = useWorkspaceStore((state) => state.setSelectedWorkspace);
  const resetWorkspaceTasks = useTaskSnapshotStore((state) => state.resetWorkspace);

  const workDir = workspaces.find(
    (workspace) => workspace.workspace_id === selectedWorkspaceId,
  )?.path;

  const [editingWorkspaceId, setEditingWorkspaceId] = useState<string>();
  const [renameDraft, setRenameDraft] = useState("");
  const [pendingRenameId, setPendingRenameId] = useState<string>();
  const [pendingRemoveId, setPendingRemoveId] = useState<string>();
  const [workspaceActionError, setWorkspaceActionError] = useState<string>();

  async function beginRename(workspaceId: string) {
    const workspace = workspaces.find((entry) => entry.workspace_id === workspaceId);
    if (!workspace) {
      return;
    }
    setWorkspaceActionError(undefined);
    setEditingWorkspaceId(workspaceId);
    setRenameDraft(workspace.display_name);
  }

  function cancelRename() {
    setEditingWorkspaceId(undefined);
    setRenameDraft("");
    setWorkspaceActionError(undefined);
  }

  async function commitRename(workspaceId: string) {
    setPendingRenameId(workspaceId);
    setWorkspaceActionError(undefined);
    try {
      const workspace = await renameWorkspace(getRuntime(), workspaceId, renameDraft);
      upsertWorkspace(workspace);
      setEditingWorkspaceId(undefined);
      setRenameDraft("");
    } catch (error) {
      setWorkspaceActionError(
        error instanceof Error ? error.message : "Failed to rename workspace",
      );
    } finally {
      setPendingRenameId(undefined);
    }
  }

  async function removeWorkspaceAction(workspaceId: string) {
    const nextWorkspace = workspaces.find(
      (workspace) => workspace.workspace_id !== workspaceId,
    );
    const removedWasSelected = selectedWorkspaceId === workspaceId;
    setPendingRemoveId(workspaceId);
    setWorkspaceActionError(undefined);
    try {
      await removeWorkspace(getRuntime(), workspaceId);
      resetWorkspaceTasks(workspaceId);
      removeWorkspaceFromStore(workspaceId);
      if (removedWasSelected) {
        if (nextWorkspace) {
          await selectWorkspace(nextWorkspace, {
            persist: true,
            navigateHomeFromTaskRoute: true,
          });
        } else {
          setSelectedWorkspace(undefined);
        }
      }
      if (editingWorkspaceId === workspaceId) {
        setEditingWorkspaceId(undefined);
        setRenameDraft("");
      }
    } catch (error) {
      setWorkspaceActionError(
        error instanceof Error ? error.message : "Failed to remove workspace",
      );
    } finally {
      setPendingRemoveId(undefined);
    }
  }

  const workspaceRows: SettingsWorkspaceRowModel[] = workspaces.map((workspace) => ({
    id: workspace.workspace_id,
    label: workspace.display_name,
    path: workspace.path,
    pathLabel: displayWorkspaceName(workspace.path),
    selected: workspace.workspace_id === selectedWorkspaceId,
    reachable: workspace.reachable,
    actorState: actorStateLabel(workspace.actor.state, workspace.reachable),
    taskSummary: summarizeTasks(workspace.task_counts),
    editing: editingWorkspaceId === workspace.workspace_id,
    pendingRename: pendingRenameId === workspace.workspace_id,
    pendingRemove: pendingRemoveId === workspace.workspace_id,
  }));

  return {
    shell,
    status,
    workDir,
    server,
    workspaceRows,
    renameDraft,
    setRenameDraft,
    workspaceActionError,
    beginRename,
    cancelRename,
    commitRename,
    removeWorkspace: removeWorkspaceAction,
  };
}
