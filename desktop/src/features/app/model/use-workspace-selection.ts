import { useEffectEvent } from "react";
import { useLocation, useNavigate } from "react-router-dom";
import { getRuntime } from "@/app/runtime";
import { parseTaskDetailPath } from "@/domain/routes";
import { preferredWorkspaceIdsForPath } from "@/features/app/model/task-route";
import {
  pickPreferredWorkspace,
  pickReplacementWorkspace,
  selectWorkspaceIntoState,
} from "@/features/app/model/workspace-selection";
import { clearRememberedWorkspaceId } from "@/features/app/model/workspace-memory";
import {
  addWorkspace,
  chooseWorkspace,
  getWorkspace,
  loadWorkspaceTasks,
} from "@/application/workspace";
import type { WorkspaceSummaryDto } from "@/rpc/types";
import { useTaskSnapshotStore } from "@/state/task-snapshot-store";
import { useWorkspaceStore } from "@/state/workspace-store";

type SelectWorkspaceByIdResult =
  | { status: "selected" }
  | { status: "missing" }
  | { status: "failed" };

export function useWorkspaceSelection() {
  const navigate = useNavigate();
  const location = useLocation();
  const setSelectedWorkspace = useWorkspaceStore(
    (state) => state.setSelectedWorkspace,
  );
  const beginWorkspaceReconcile = useWorkspaceStore(
    (state) => state.beginWorkspaceReconcile,
  );
  const finishWorkspaceReconcile = useWorkspaceStore(
    (state) => state.finishWorkspaceReconcile,
  );
  const upsertWorkspace = useWorkspaceStore((state) => state.upsertWorkspace);
  const removeWorkspaceFromStore = useWorkspaceStore(
    (state) => state.removeWorkspace,
  );
  const setError = useWorkspaceStore((state) => state.setError);
  const setTasks = useTaskSnapshotStore((state) => state.setTasks);
  const resetWorkspaceTasks = useTaskSnapshotStore((state) => state.resetWorkspace);

  const activateWorkspace = useEffectEvent(
    async (
      workspace: WorkspaceSummaryDto,
      mode: "default" | "route",
    ): Promise<boolean> => {
      const taskRoute = parseTaskDetailPath(location.pathname);
      const shouldTrackReconcile =
        workspace.reachable && workspace.actor.state !== "active";
      if (shouldTrackReconcile) {
        beginWorkspaceReconcile(workspace.workspace_id);
      }
      let selected = false;
      try {
        selected = await selectWorkspaceIntoState({
          runtime: getRuntime(),
          workspace,
          setTasks,
          resetWorkspace: resetWorkspaceTasks,
          setSelectedWorkspace,
          setError,
          rememberSelection: mode === "default",
        });
      } finally {
        if (shouldTrackReconcile) {
          finishWorkspaceReconcile(workspace.workspace_id);
        }
      }
      if (
        selected &&
        mode === "default" &&
        taskRoute &&
        taskRoute.workspaceId !== workspace.workspace_id
      ) {
        navigate("/", { replace: false });
      }
      return selected;
    },
  );

  const activateWorkspaceById = useEffectEvent(
    async (
      workspaceId: string,
      mode: "default" | "route",
    ): Promise<SelectWorkspaceByIdResult> => {
      const trimmedWorkspaceId = workspaceId.trim();
      if (!trimmedWorkspaceId) {
        return { status: "missing" };
      }

      let workspace = useWorkspaceStore.getState().workspaces.find(
        (entry) => entry.workspace_id === trimmedWorkspaceId,
      );
      if (!workspace) {
        try {
          workspace = await getWorkspace(getRuntime(), trimmedWorkspaceId);
          upsertWorkspace(workspace);
        } catch (error) {
          setError(
            error instanceof Error
              ? error.message
              : "Failed to load workspace",
          );
          return { status: "failed" };
        }
      }

      const selected = await activateWorkspace(workspace, mode);
      return { status: selected ? "selected" : "failed" };
    },
  );

  const selectPreferredWorkspace = useEffectEvent(
    async (
      preferredIds: Array<string | undefined>,
    ): Promise<boolean> => {
      const workspace = pickPreferredWorkspace(
        useWorkspaceStore.getState().workspaces,
        preferredIds,
      );
      if (!workspace) {
        return false;
      }
      return activateWorkspace(workspace, "default");
    },
  );

  const selectPreferredWorkspaceForPath = useEffectEvent(
    async (
      pathname: string,
      fallbackIds: Array<string | undefined> = [],
    ): Promise<boolean> =>
      selectPreferredWorkspace(preferredWorkspaceIdsForPath(pathname, ...fallbackIds)),
  );

  const clearWorkspaceSelection = useEffectEvent((): void => {
    clearRememberedWorkspaceId();
    setSelectedWorkspace(undefined);
    setError(undefined);

    const taskRoute = parseTaskDetailPath(location.pathname);
    if (taskRoute) {
      navigate("/", { replace: false });
    }
  });

  const selectTaskRouteWorkspace = useEffectEvent(
    async (workspaceId: string): Promise<SelectWorkspaceByIdResult> =>
      activateWorkspaceById(workspaceId, "route"),
  );

  const removeWorkspaceFromState = useEffectEvent(
    async (workspaceId: string): Promise<void> => {
      const removedWorkspaceId = workspaceId.trim();
      if (!removedWorkspaceId) {
        return;
      }

      const { selectedWorkspaceId, workspaces } = useWorkspaceStore.getState();
      const replacement = pickReplacementWorkspace(workspaces, removedWorkspaceId);
      const removedWasSelected = selectedWorkspaceId === removedWorkspaceId;
      resetWorkspaceTasks(removedWorkspaceId);
      removeWorkspaceFromStore(removedWorkspaceId);

      if (!removedWasSelected) {
        return;
      }

      if (!replacement) {
        setSelectedWorkspace(undefined);
        return;
      }

      const selectedReplacement = await activateWorkspace(replacement, "default");
      if (!selectedReplacement) {
        setSelectedWorkspace(undefined);
      }
    },
  );

  const selectWorkspace = useEffectEvent(
    async (workspace: WorkspaceSummaryDto): Promise<boolean> =>
      activateWorkspace(workspace, "default"),
  );

  const selectWorkspaceById = useEffectEvent(
    async (workspaceId: string): Promise<SelectWorkspaceByIdResult> =>
      activateWorkspaceById(workspaceId, "default"),
  );

  const addWorkspaceFromPicker = useEffectEvent(async (): Promise<void> => {
    const picked = await chooseWorkspace(getRuntime());
    if (!picked) {
      return;
    }
    try {
      const workspace = await addWorkspace(getRuntime(), picked);
      upsertWorkspace(workspace);
      if (workspace.reachable) {
        const shouldTrackReconcile = workspace.actor.state !== "active";
        if (shouldTrackReconcile) {
          beginWorkspaceReconcile(workspace.workspace_id);
        }
        try {
          const bootstrap = await loadWorkspaceTasks(getRuntime(), workspace);
          setTasks(workspace.workspace_id, bootstrap.tasks);
        } finally {
          if (shouldTrackReconcile) {
            finishWorkspaceReconcile(workspace.workspace_id);
          }
        }
      } else {
        resetWorkspaceTasks(workspace.workspace_id);
      }
      setError(undefined);
    } catch (error) {
      setError(
        error instanceof Error ? error.message : "Failed to add workspace",
      );
    }
  });

  return {
    addWorkspaceFromPicker,
    clearWorkspaceSelection,
    selectWorkspace,
    selectWorkspaceById,
    selectPreferredWorkspace,
    selectPreferredWorkspaceForPath,
    selectTaskRouteWorkspace,
    removeWorkspaceFromState,
  };
}
