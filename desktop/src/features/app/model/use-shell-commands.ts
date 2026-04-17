import { useLocation, useNavigate } from "react-router-dom";
import { parseTaskDetailPath, sourceControlRoutePath } from "@/domain/routes";
import { useAppSessionController } from "@/features/app/model/use-app-session-controller";
import { buildNewTaskModalSearch } from "@/features/new-task/model/new-task-route-state";
import { useWorkspaceSelection } from "@/features/app/model/use-workspace-selection";
import { useWorkspaceStore } from "@/state/workspace-store";

export type ShellCommands = {
  addWorkspace: () => Promise<void>;
  disconnect: () => Promise<void>;
  openWorkspaceTasks: (workspaceId: string) => Promise<void>;
  openNewTask: () => void;
  reconnect: () => void;
  showSourceControl: () => Promise<void>;
  showAllTasks: () => void;
};

function buildCurrentTaskSurfacePath(pathname: string, search: string): string {
  const params = new URLSearchParams(search);
  params.delete("newTask");
  params.delete("layout");

  if (pathname === "/") {
    const query = params.toString();
    return query ? `/?${query}` : "/";
  }

  if (pathname === "/inbox") {
    return "/inbox";
  }

  return "/";
}

export function useShellCommands(): ShellCommands {
  const location = useLocation();
  const navigate = useNavigate();
  const clearTaskSurfaceReturnContext = useWorkspaceStore(
    (state) => state.clearTaskSurfaceReturnContext,
  );
  const {
    addWorkspaceFromPicker,
    clearWorkspaceSelection,
    selectWorkspaceById,
  } = useWorkspaceSelection();
  const { disconnect, reconnect } = useAppSessionController();

  return {
    addWorkspace: addWorkspaceFromPicker,
    disconnect,
    openWorkspaceTasks: async (workspaceId: string) => {
      if (parseTaskDetailPath(location.pathname)) {
        clearTaskSurfaceReturnContext();
      }
      const result = await selectWorkspaceById(workspaceId);
      if (result.status !== "selected") {
        return;
      }
      navigate(buildCurrentTaskSurfacePath(location.pathname, location.search), {
        replace: false,
      });
    },
    openNewTask: () => {
      navigate({
        pathname: location.pathname,
        search: buildNewTaskModalSearch(location.search, true),
      });
    },
    reconnect,
    showSourceControl: async () => {
      if (parseTaskDetailPath(location.pathname)) {
        clearTaskSurfaceReturnContext();
      }
      const state = useWorkspaceStore.getState();
      if (!state.selectedWorkspaceId && state.workspaces[0]?.workspace_id) {
        const result = await selectWorkspaceById(state.workspaces[0].workspace_id);
        if (result.status !== "selected") {
          return;
        }
      }
      navigate(sourceControlRoutePath, { replace: false });
    },
    showAllTasks: () => {
      if (parseTaskDetailPath(location.pathname)) {
        clearTaskSurfaceReturnContext();
      }
      clearWorkspaceSelection();
      navigate(buildCurrentTaskSurfacePath(location.pathname, location.search), {
        replace: false,
      });
    },
  };
}
