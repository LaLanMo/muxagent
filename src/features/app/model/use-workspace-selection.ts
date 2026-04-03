import { useEffectEvent } from "react";
import { useLocation, useNavigate } from "react-router-dom";
import { getRuntime } from "@/app/runtime";
import { parseTaskDetailPath } from "@/domain/routes";
import { selectWorkspaceIntoState } from "@/features/app/model/workspace-selection";
import type { WorkspaceSummaryDto } from "@/rpc/types";
import { useTaskSnapshotStore } from "@/state/task-snapshot-store";
import { useWorkspaceStore } from "@/state/workspace-store";

type SelectWorkspaceOptions = {
  persist?: boolean;
  navigateHomeFromTaskRoute?: boolean;
};

export function useWorkspaceSelection() {
  const navigate = useNavigate();
  const location = useLocation();
  const setSelectedWorkspace = useWorkspaceStore(
    (state) => state.setSelectedWorkspace,
  );
  const setError = useWorkspaceStore((state) => state.setError);
  const setTasks = useTaskSnapshotStore((state) => state.setTasks);
  const resetWorkspaceTasks = useTaskSnapshotStore((state) => state.resetWorkspace);

  const selectWorkspace = useEffectEvent(
    async (
      workspace: WorkspaceSummaryDto,
      options: SelectWorkspaceOptions = {},
    ): Promise<boolean> => {
      const {
        persist = true,
        navigateHomeFromTaskRoute = true,
      } = options;
      const selected = await selectWorkspaceIntoState({
        runtime: getRuntime(),
        workspace,
        setTasks,
        resetWorkspace: resetWorkspaceTasks,
        setSelectedWorkspace,
        setError,
        rememberSelection: persist,
      });
      if (
        selected &&
        navigateHomeFromTaskRoute &&
        parseTaskDetailPath(location.pathname)?.workspaceId !== workspace.workspace_id &&
        parseTaskDetailPath(location.pathname)
      ) {
        navigate("/", { replace: false });
      }
      return selected;
    },
  );

  return {
    selectWorkspace,
  };
}
