import { useEffect, useState } from "react";
import { startTask } from "@/application/tasks";
import { getRuntime } from "@/app/runtime";
import { flowNodesForConfig } from "@/domain/task-shell";
import { useTaskSnapshotStore } from "@/state/task-snapshot-store";
import { useWorkspaceStore } from "@/state/workspace-store";

type UseNewTaskModalArgs = {
  open: boolean;
  onClose: () => void;
};

export function useNewTaskModal({ open, onClose }: UseNewTaskModalArgs) {
  const catalog = useWorkspaceStore((state) => state.catalog);
  const workspaces = useWorkspaceStore((state) => state.workspaces);
  const selectedWorkspaceId = useWorkspaceStore(
    (state) => state.selectedWorkspaceId,
  );
  const [selectedTargetWorkspaceId, setSelectedTargetWorkspaceId] = useState(
    selectedWorkspaceId ?? "",
  );
  const selectedWorkspace = workspaces.find(
    (workspace) => workspace.workspace_id === selectedTargetWorkspaceId,
  );
  const setTasks = useTaskSnapshotStore((state) => state.setTasks);

  const defaultAlias = catalog?.default_alias ?? "";
  const [description, setDescription] = useState("");
  const [selectedAlias, setSelectedAlias] = useState(defaultAlias);
  const [useWorktree, setUseWorktree] = useState(
    catalog?.default_use_worktree ?? false,
  );
  const [configExpanded, setConfigExpanded] = useState(true);
  const [configPicking, setConfigPicking] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | undefined>();

  useEffect(() => {
    if (!open) {
      return;
    }
    setSelectedTargetWorkspaceId((current) => {
      if (current && workspaces.some((workspace) => workspace.workspace_id === current)) {
        return current;
      }
      return selectedWorkspaceId ?? workspaces[0]?.workspace_id ?? "";
    });
    setSelectedAlias((current) => current || defaultAlias);
    setUseWorktree(catalog?.default_use_worktree ?? false);
    setConfigExpanded(true);
    setConfigPicking(false);
    setError(undefined);
  }, [
    catalog?.default_use_worktree,
    defaultAlias,
    open,
    selectedWorkspaceId,
    workspaces,
  ]);

  const entries = (catalog?.entries ?? []).filter((entry) => entry.launchable);
  const selectedEntry =
    entries.find((entry) => entry.alias === selectedAlias) ?? entries[0];
  const canSubmit = Boolean(
    description.trim() && selectedEntry && selectedTargetWorkspaceId,
  );

  async function submit(): Promise<void> {
    const trimmed = description.trim();
    if (!trimmed || !selectedEntry || !selectedTargetWorkspaceId) {
      setError("Task description, workspace, and config are required");
      return;
    }

    setSubmitting(true);
    setError(undefined);
    try {
      const workspaceId = selectedTargetWorkspaceId;
      await startTask(getRuntime(), {
        workspace_id: workspaceId,
        client_command_id: globalThis.crypto?.randomUUID?.() ?? String(Date.now()),
        description: trimmed,
        config_alias: selectedEntry.alias,
        config_path: selectedEntry.config_path,
        use_worktree: Boolean(selectedWorkspace?.worktree_available && useWorktree),
      });
      setDescription("");
      onClose();
      void getRuntime()
        .backend.taskList(workspaceId)
        .then((taskList) => {
          setTasks(workspaceId, taskList.tasks);
        })
        .catch(() => {
          // Notifications or later refreshes can reconcile the list if this read races.
        });
    } catch (submitError) {
      setError(
        submitError instanceof Error ? submitError.message : "Failed to start task",
      );
    } finally {
      setSubmitting(false);
    }
  }

  return {
    description,
    setDescription,
    selectedTargetWorkspaceId,
    setSelectedTargetWorkspaceId,
    workspaceOptions: workspaces.map((workspace) => ({
      id: workspace.workspace_id,
      label: workspace.display_name,
      path: workspace.path,
    })),
    selectedAlias,
    setSelectedAlias,
    selectedEntry,
    flowNodes: flowNodesForConfig(selectedEntry),
    useWorktree,
    setUseWorktree,
    worktreeAvailable: Boolean(selectedWorkspace?.worktree_available),
    configExpanded,
    toggleConfigExpanded: () => setConfigExpanded((v) => !v),
    configPicking,
    openConfigPicker: () => setConfigPicking(true),
    closeConfigPicker: () => setConfigPicking(false),
    submitting,
    canSubmit,
    error,
    submit,
  };
}
