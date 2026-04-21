import { useEffectEvent } from "react";
import { useLocation, useNavigate } from "react-router-dom";
import {
  connectServer,
  disconnectServer,
  loadAllWorkspaceTasks,
} from "@/application/workspace";
import { getRuntime } from "@/app/runtime";
import { readRememberedWorkspaceId } from "@/features/app/model/workspace-memory";
import { clearRememberedWorkspaceId } from "@/features/app/model/workspace-memory";
import { parseTaskBoardPath, parseTaskDetailPath } from "@/domain/routes";
import { useWorkspaceSelection } from "@/features/app/model/use-workspace-selection";
import { useTaskSnapshotStore } from "@/state/task-snapshot-store";
import { useWorkspaceStore } from "@/state/workspace-store";

export function useAppSessionController() {
  const location = useLocation();
  const navigate = useNavigate();

  const resetTasks = useTaskSnapshotStore((state) => state.reset);
  const setTasks = useTaskSnapshotStore((state) => state.setTasks);

  const setConnecting = useWorkspaceStore((state) => state.setConnecting);
  const setConnected = useWorkspaceStore((state) => state.setConnected);
  const setDisconnected = useWorkspaceStore((state) => state.setDisconnected);
  const setFailed = useWorkspaceStore((state) => state.setFailed);
  const setSelectedWorkspace = useWorkspaceStore(
    (state) => state.setSelectedWorkspace,
  );
  const beginWorkspaceReconcile = useWorkspaceStore(
    (state) => state.beginWorkspaceReconcile,
  );
  const finishWorkspaceReconcile = useWorkspaceStore(
    (state) => state.finishWorkspaceReconcile,
  );
  const requestBootstrap = useWorkspaceStore((state) => state.requestBootstrap);
  const { selectPreferredWorkspaceForPath } = useWorkspaceSelection();

  const bootstrap = useEffectEvent(async () => {
    setConnecting();
    resetTasks();
    try {
      const bootstrap = await connectServer(getRuntime());
      const reconciledWorkspaceIds = bootstrap.workspaces
        .filter((workspace) => workspace.reachable && workspace.actor.state !== "active")
        .map((workspace) => workspace.workspace_id);
      for (const workspaceId of reconciledWorkspaceIds) {
        beginWorkspaceReconcile(workspaceId);
      }
      let taskMap;
      try {
        taskMap = await loadAllWorkspaceTasks(getRuntime(), bootstrap.workspaces);
      } finally {
        for (const workspaceId of reconciledWorkspaceIds) {
          finishWorkspaceReconcile(workspaceId);
        }
      }
      setConnected(
        bootstrap.server,
        bootstrap.status,
        bootstrap.runtimeStatus,
        bootstrap.catalog,
        bootstrap.workspaces,
      );
      for (const [workspaceId, tasks] of Object.entries(taskMap)) {
        setTasks(workspaceId, tasks);
      }

      const rememberedId = readRememberedWorkspaceId();
      const taskBoardRoute = parseTaskBoardPath(location.pathname);
      const routeHasWorkspace =
        Boolean(parseTaskDetailPath(location.pathname)) ||
        taskBoardRoute?.kind === "workspace";
      if (routeHasWorkspace) {
        await selectPreferredWorkspaceForPath(location.pathname, [rememberedId]);
      } else {
        setSelectedWorkspace(undefined);
      }
    } catch (connectError) {
      setFailed(
        connectError instanceof Error
          ? connectError.message
          : "Failed to connect app-server",
      );
    }
  });

  const disconnect = useEffectEvent(async () => {
    clearRememberedWorkspaceId();
    await disconnectServer(getRuntime()).catch(() => undefined);
    resetTasks();
    setDisconnected();
    navigate("/", { replace: true });
  });

  const reconnect = useEffectEvent(() => {
    resetTasks();
    requestBootstrap();
    navigate("/", { replace: true });
  });

  return {
    bootstrap,
    disconnect,
    reconnect,
  };
}
