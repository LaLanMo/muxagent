import { useLocation, useNavigate } from "react-router-dom";
import { parseTaskDetailPath, sourceControlRoutePath } from "@/domain/routes";
import { useAppSessionController } from "@/features/app/model/use-app-session-controller";
import { buildNewTaskModalSearch } from "@/features/new-task/model/new-task-route-state";
import { useWorkbenchStore } from "@/features/layout/model/use-workbench-store";
import { useWorkspaceSelection } from "@/features/app/model/use-workspace-selection";
import { useWorkspaceStore } from "@/state/workspace-store";

export type ShellCommands = {
  addWorkspace: () => Promise<void>;
  disconnect: () => Promise<void>;
  openWorkspaceTasks: (workspaceId: string) => Promise<void>;
  openNewTask: () => void;
  reconnect: () => void;
  showTaskSurface: () => void;
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

function buildPreferredTaskSurfacePath(pathname: string, search: string): string {
  const currentTaskSurfacePath = buildCurrentTaskSurfacePath(pathname, search);
  if (pathname === "/" || pathname === "/inbox") {
    return currentTaskSurfacePath;
  }

  const taskRoute = parseTaskDetailPath(pathname);
  if (taskRoute) {
    const taskSurfaceReturnContext = useWorkspaceStore.getState().taskSurfaceReturnContext;
    if (taskSurfaceReturnContext?.path) {
      return taskSurfaceReturnContext.path;
    }
  }

  const taskBoardTab = useWorkbenchStore
    .getState()
    .tabs.find((tab) => tab.id === "task-board");
  return taskBoardTab?.href ?? "/";
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
  const currentHref = `${location.pathname}${location.search}`;

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
      const nextTaskSurfacePath = buildPreferredTaskSurfacePath(
        location.pathname,
        location.search,
      );
      if (nextTaskSurfacePath !== currentHref) {
        navigate(nextTaskSurfacePath, { replace: false });
      }
    },
    openNewTask: () => {
      navigate({
        pathname: location.pathname,
        search: buildNewTaskModalSearch(location.search, true),
      });
    },
    reconnect,
    showTaskSurface: () => {
      const nextTaskSurfacePath = buildPreferredTaskSurfacePath(
        location.pathname,
        location.search,
      );
      if (nextTaskSurfacePath !== currentHref) {
        navigate(nextTaskSurfacePath, { replace: false });
      }
    },
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
      clearWorkspaceSelection({ navigateToTaskSurface: false });
      const nextTaskSurfacePath = buildPreferredTaskSurfacePath(
        location.pathname,
        location.search,
      );
      if (nextTaskSurfacePath !== currentHref) {
        navigate(nextTaskSurfacePath, { replace: false });
      }
    },
  };
}
