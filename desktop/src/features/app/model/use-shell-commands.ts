import { useLocation, useNavigate } from "react-router-dom";
import {
  buildTaskBoardHref,
  parseTaskBoardHref,
  parseTaskBoardPath,
  parseTaskDetailPath,
  sourceControlRoutePath,
  taskBoardTabId,
  type TaskBoardRoute,
  type TaskBoardScope,
} from "@/domain/routes";
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

const validBoardViews = new Set(["mine", "active", "history", "attention"]);

function buildTaskBoardViewSearch(search: string): string {
  const params = new URLSearchParams(search);
  const view = params.get("view");
  if (!view || !validBoardViews.has(view)) {
    return "";
  }
  return `?${new URLSearchParams({ view }).toString()}`;
}

function buildTaskBoardHrefWithView(
  scope: TaskBoardScope,
  search: string,
): string {
  return buildTaskBoardHref(scope, buildTaskBoardViewSearch(search));
}

function taskBoardRouteFromHref(href: string): TaskBoardRoute | null {
  const route = parseTaskBoardHref(href);
  if (!route) {
    return null;
  }
  const hrefWithView = buildTaskBoardHrefWithView(route.scope, route.search);
  return {
    ...route,
    search: buildTaskBoardViewSearch(route.search),
    href: hrefWithView,
  };
}

function taskBoardRouteFromLocation(
  pathname: string,
  search: string,
): TaskBoardRoute | null {
  const scope = parseTaskBoardPath(pathname);
  if (!scope) {
    return null;
  }
  const href = buildTaskBoardHrefWithView(scope, search);
  return {
    scope,
    pathname: scope.kind === "all" ? "/" : `/workspaces/${encodeURIComponent(scope.workspaceId)}/tasks`,
    search: buildTaskBoardViewSearch(search),
    href,
  };
}

function preferredTaskBoardSearch(pathname: string, search: string): string {
  const currentBoardRoute = taskBoardRouteFromLocation(pathname, search);
  if (currentBoardRoute) {
    return currentBoardRoute.search;
  }

  if (parseTaskDetailPath(pathname)) {
    const taskSurfaceReturnContext = useWorkspaceStore.getState().taskSurfaceReturnContext;
    const returnRoute = taskSurfaceReturnContext?.path
      ? taskBoardRouteFromHref(taskSurfaceReturnContext.path)
      : null;
    if (returnRoute) {
      return returnRoute.search;
    }
  }

  const workbench = useWorkbenchStore.getState();
  const activeBoardTab = workbench.tabs.find(
    (tab) => tab.id === workbench.activeTabId && taskBoardRouteFromHref(tab.href),
  );
  const preferredBoardTab =
    activeBoardTab ?? workbench.tabs.find((tab) => taskBoardRouteFromHref(tab.href));
  const preferredBoardRoute = preferredBoardTab
    ? taskBoardRouteFromHref(preferredBoardTab.href)
    : null;
  return preferredBoardRoute?.search ?? buildTaskBoardViewSearch(search);
}

function buildPreferredTaskBoardPath(pathname: string, search: string): string {
  const currentBoardRoute = taskBoardRouteFromLocation(pathname, search);
  if (currentBoardRoute) {
    return currentBoardRoute.href;
  }

  if (parseTaskDetailPath(pathname)) {
    const taskSurfaceReturnContext = useWorkspaceStore.getState().taskSurfaceReturnContext;
    const returnRoute = taskSurfaceReturnContext?.path
      ? taskBoardRouteFromHref(taskSurfaceReturnContext.path)
      : null;
    if (returnRoute) {
      return returnRoute.href;
    }
  }

  const workbench = useWorkbenchStore.getState();
  const activeBoardTab = workbench.tabs.find(
    (tab) => tab.id === workbench.activeTabId && taskBoardRouteFromHref(tab.href),
  );
  const preferredBoardTab =
    activeBoardTab ?? workbench.tabs.find((tab) => taskBoardRouteFromHref(tab.href));
  const preferredBoardRoute = preferredBoardTab
    ? taskBoardRouteFromHref(preferredBoardTab.href)
    : null;
  return (
    preferredBoardRoute?.href ??
    buildTaskBoardHrefWithView({ kind: "all" }, search)
  );
}

function syncTaskBoardTab(
  scope: TaskBoardScope,
  href: string,
  title = "Board",
): void {
  useWorkbenchStore.getState().syncRouteTab({
    id: taskBoardTabId(scope),
    kind: "task-board",
    title,
    href,
    closeable: true,
  });
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
      const search = preferredTaskBoardSearch(location.pathname, location.search);
      const result = await selectWorkspaceById(workspaceId, {
        suppressTaskRouteRedirect: true,
      });
      if (result.status !== "selected") {
        return;
      }
      const scope: TaskBoardScope = { kind: "workspace", workspaceId };
      const nextTaskSurfacePath = buildTaskBoardHrefWithView(
        scope,
        search,
      );
      const workspace = useWorkspaceStore
        .getState()
        .workspaces.find((entry) => entry.workspace_id === workspaceId);
      syncTaskBoardTab(scope, nextTaskSurfacePath, workspace?.display_name);
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
      const nextTaskSurfacePath = buildPreferredTaskBoardPath(
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
      const search = preferredTaskBoardSearch(location.pathname, location.search);
      clearWorkspaceSelection({ navigateToTaskSurface: false });
      const scope: TaskBoardScope = { kind: "all" };
      const nextTaskSurfacePath = buildTaskBoardHrefWithView(scope, search);
      syncTaskBoardTab(scope, nextTaskSurfacePath);
      if (nextTaskSurfacePath !== currentHref) {
        navigate(nextTaskSurfacePath, { replace: false });
      }
    },
  };
}
