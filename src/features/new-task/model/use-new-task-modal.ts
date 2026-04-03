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
  const selectedWorkspaceId = useWorkspaceStore(
    (state) => state.selectedWorkspaceId,
  );
  const selectedWorkspace = useWorkspaceStore((state) =>
    state.workspaces.find(
      (workspace) => workspace.workspace_id === state.selectedWorkspaceId,
    ),
  );
  const setTasks = useTaskSnapshotStore((state) => state.setTasks);

  const defaultAlias = catalog?.default_alias ?? "";
  const [description, setDescription] = useState("");
  const [selectedAlias, setSelectedAlias] = useState(defaultAlias);
  const [useWorktree, setUseWorktree] = useState(
    catalog?.default_use_worktree ?? false,
  );
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | undefined>();

  useEffect(() => {
    if (!open) {
      return;
    }
    setSelectedAlias((current) => current || defaultAlias);
    setUseWorktree(catalog?.default_use_worktree ?? false);
    setError(undefined);
  }, [catalog?.default_use_worktree, defaultAlias, open]);

  const entries = (catalog?.entries ?? []).filter((entry) => entry.launchable);
  const selectedEntry =
    entries.find((entry) => entry.alias === selectedAlias) ?? entries[0];
  const canSubmit = Boolean(
    description.trim() && selectedEntry && selectedWorkspaceId,
  );

  async function submit(): Promise<void> {
    const trimmed = description.trim();
    if (!trimmed || !selectedEntry || !selectedWorkspaceId) {
      setError("Task description and config are required");
      return;
    }

    setSubmitting(true);
    setError(undefined);
    try {
      await startTask(getRuntime(), {
        workspace_id: selectedWorkspaceId,
        client_command_id: globalThis.crypto?.randomUUID?.() ?? String(Date.now()),
        description: trimmed,
        config_alias: selectedEntry.alias,
        config_path: selectedEntry.config_path,
        use_worktree: Boolean(selectedWorkspace?.worktree_available && useWorktree),
      });
      const taskList = await getRuntime().backend.taskList(selectedWorkspaceId);
      setTasks(selectedWorkspaceId, taskList.tasks);
      setDescription("");
      onClose();
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
    selectedAlias,
    setSelectedAlias,
    selectedEntry,
    flowNodes: flowNodesForConfig(selectedEntry),
    useWorktree,
    setUseWorktree,
    worktreeAvailable: Boolean(selectedWorkspace?.worktree_available),
    submitting,
    canSubmit,
    error,
    submit,
  };
}
