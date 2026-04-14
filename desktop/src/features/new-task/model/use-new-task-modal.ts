import { useEffect, useRef, useState } from "react";
import {
  loadConfigDetail,
  pickPreferredLaunchableConfig,
} from "@/application/configs";
import { startTask } from "@/application/tasks";
import { getRuntime } from "@/app/runtime";
import {
  readRememberedConfigAlias,
  rememberConfigAlias,
} from "@/features/app/model/config-memory";
import { flowNodesForConfig } from "@/domain/task-shell";
import type { ConfigDraftDto } from "@/rpc/types";
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

  const entries = (catalog?.entries ?? []).filter((entry) => entry.launchable);
  const preferredAlias =
    pickPreferredLaunchableConfig(entries, readRememberedConfigAlias())?.alias ?? "";
  const [description, setDescription] = useState("");
  const [selectedAlias, setSelectedAlias] = useState(preferredAlias);
  const [useWorktree, setUseWorktree] = useState(
    catalog?.default_use_worktree ?? false,
  );
  const [workspacePicking, setWorkspacePicking] = useState(false);
  const [configPicking, setConfigPicking] = useState(false);
  const [configDetail, setConfigDetail] = useState<ConfigDraftDto | undefined>();
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | undefined>();
  const fetchAliasRef = useRef("");

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
    setSelectedAlias(preferredAlias);
    setUseWorktree(catalog?.default_use_worktree ?? false);
    setWorkspacePicking(false);
    setConfigPicking(false);
    setConfigDetail(undefined);
    setError(undefined);
  }, [
    catalog?.default_use_worktree,
    open,
    preferredAlias,
    selectedWorkspaceId,
    workspaces,
  ]);

  // Fetch full config detail (topology) when selected alias changes
  useEffect(() => {
    if (!open || !selectedAlias) {
      return;
    }
    const alias = selectedAlias;
    fetchAliasRef.current = alias;
    setConfigDetail(undefined);
    loadConfigDetail(getRuntime(), alias)
      .then((detail) => {
        if (fetchAliasRef.current === alias) {
          setConfigDetail(detail.config);
        }
      })
      .catch(() => {
        // Config detail is supplementary; catalog data still shows
      });
  }, [open, selectedAlias]);

  const selectedEntry =
    entries.find((entry) => entry.alias === selectedAlias) ??
    pickPreferredLaunchableConfig(entries, readRememberedConfigAlias()) ??
    entries[0];
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
      rememberConfigAlias(selectedEntry.alias);
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
    workspacePicking,
    toggleWorkspacePicker: () => setWorkspacePicking((value) => !value),
    closeWorkspacePicker: () => setWorkspacePicking(false),
    selectedAlias,
    setSelectedAlias,
    selectedEntry,
    flowNodes: flowNodesForConfig(selectedEntry),
    useWorktree,
    setUseWorktree,
    worktreeAvailable: Boolean(selectedWorkspace?.worktree_available),
    configMaxIterations: configDetail?.topology.max_iterations,
    configEntryNode: configDetail?.topology.entry,
    configPicking,
    toggleConfigPicker: () => setConfigPicking((v) => !v),
    closeConfigPicker: () => setConfigPicking(false),
    submitting,
    canSubmit,
    error,
    submit,
  };
}
