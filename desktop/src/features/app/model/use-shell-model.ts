import { createElement, useEffect, useState } from "react";
import { removeWorkspace } from "@/application/workspace";
import { getRuntime } from "@/app/runtime";
import {
  useShellChrome,
  type ShellChromeModel,
} from "@/features/app/model/use-shell-chrome";
import { useShellCommands } from "@/features/app/model/use-shell-commands";
import { useWorkspaceSelection } from "@/features/app/model/use-workspace-selection";
import { useWorkspaceStore } from "@/state/workspace-store";

export function useShellModel(): ShellChromeModel {
  const shellState = useShellChrome();
  const shellCommands = useShellCommands();
  const { removeWorkspaceFromState } = useWorkspaceSelection();
  const workspaces = useWorkspaceStore((state) => state.workspaces);
  const [removeTargetWorkspaceId, setRemoveTargetWorkspaceId] = useState<string>();
  const [pendingRemoveWorkspaceId, setPendingRemoveWorkspaceId] = useState<string>();
  const [workspaceRemoveError, setWorkspaceRemoveError] = useState<string>();

  const removeTargetWorkspace = workspaces.find(
    (workspace) => workspace.workspace_id === removeTargetWorkspaceId,
  );

  useEffect(() => {
    if (!removeTargetWorkspaceId || pendingRemoveWorkspaceId) {
      return;
    }
    if (removeTargetWorkspace) {
      return;
    }
    setRemoveTargetWorkspaceId(undefined);
    setWorkspaceRemoveError(undefined);
  }, [
    pendingRemoveWorkspaceId,
    removeTargetWorkspace,
    removeTargetWorkspaceId,
  ]);

  function openWorkspaceRemoveDialog(workspaceId: string) {
    if (pendingRemoveWorkspaceId) {
      return;
    }
    setWorkspaceRemoveError(undefined);
    setRemoveTargetWorkspaceId(workspaceId);
  }

  function closeWorkspaceRemoveDialog() {
    if (pendingRemoveWorkspaceId) {
      return;
    }
    setRemoveTargetWorkspaceId(undefined);
    setWorkspaceRemoveError(undefined);
  }

  async function confirmWorkspaceRemove() {
    if (!removeTargetWorkspace) {
      return;
    }

    const targetWorkspaceId = removeTargetWorkspace.workspace_id;
    setPendingRemoveWorkspaceId(targetWorkspaceId);
    setWorkspaceRemoveError(undefined);

    try {
      await removeWorkspace(getRuntime(), targetWorkspaceId);
      await removeWorkspaceFromState(targetWorkspaceId);
      setRemoveTargetWorkspaceId(undefined);
    } catch (error) {
      setWorkspaceRemoveError(
        error instanceof Error ? error.message : "Failed to remove workspace",
      );
    } finally {
      setPendingRemoveWorkspaceId(undefined);
    }
  }

  return {
    ...shellState,
    ...shellCommands,
    primaryNav: shellState.primaryNav.map((item) =>
      item.label === "Tasks"
        ? {
            ...item,
            onClick: shellCommands.showAllTasks,
          }
        : item.label === "Source Control"
          ? {
              ...item,
              onClick: () => void shellCommands.showSourceControl(),
            }
        : item,
    ),
    workspaceItems: shellState.workspaceItems.map((item) => ({
      ...item,
      onClick: () => void shellCommands.openWorkspaceTasks(item.id),
      onRemove: () => openWorkspaceRemoveDialog(item.id),
      removePending: pendingRemoveWorkspaceId === item.id,
    })),
    workspaceRemoveDialog: removeTargetWorkspace
      ? {
          open: true,
          title: "Remove workspace",
          body: [
            createElement(
              "p",
              { key: "copy" },
              `Remove workspace "${removeTargetWorkspace.display_name}" from this shell? Existing task data stays on disk.`,
            ),
            workspaceRemoveError
              ? createElement(
                  "div",
                  {
                    key: "error",
                    className: "inline-banner inline-banner--failed",
                    "data-testid": "workspace-remove-error",
                  },
                  workspaceRemoveError,
                )
              : null,
          ],
          cancelLabel: "Cancel",
          confirmLabel: pendingRemoveWorkspaceId ? "Removing..." : "Remove",
          confirmDisabled: Boolean(pendingRemoveWorkspaceId),
          onCancel: closeWorkspaceRemoveDialog,
          onConfirm: () => void confirmWorkspaceRemove(),
        }
      : undefined,
  };
}
