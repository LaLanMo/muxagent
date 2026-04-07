import { useLocation, useNavigate } from "react-router-dom";
import { useAppSessionController } from "@/features/app/model/use-app-session-controller";
import { useWorkspaceSelection } from "@/features/app/model/use-workspace-selection";

export type ShellCommands = {
  addWorkspace: () => Promise<void>;
  disconnect: () => Promise<void>;
  openWorkspaceTasks: (workspaceId: string) => Promise<void>;
  openNewTask: () => void;
  reconnect: () => void;
  showAllTasks: () => void;
};

function buildCurrentTaskSurfacePath(pathname: string, search: string): string {
  const params = new URLSearchParams(search);
  params.delete("newTask");

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
      const result = await selectWorkspaceById(workspaceId);
      if (result.status !== "selected") {
        return;
      }
      navigate(buildCurrentTaskSurfacePath(location.pathname, location.search), {
        replace: false,
      });
    },
    openNewTask: () => {
      const params = new URLSearchParams(
        location.pathname === "/" ? location.search : "",
      );
      params.set("newTask", "1");
      navigate({
        pathname: "/",
        search: `?${params.toString()}`,
      });
    },
    reconnect,
    showAllTasks: () => {
      clearWorkspaceSelection();
      navigate(buildCurrentTaskSurfacePath(location.pathname, location.search), {
        replace: false,
      });
    },
  };
}
