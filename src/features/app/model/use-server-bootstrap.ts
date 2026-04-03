import { useEffect, useEffectEvent, useRef } from "react";
import { useLocation } from "react-router-dom";
import { connectServer } from "@/application/workspace";
import { getRuntime } from "@/app/runtime";
import { parseTaskDetailPath } from "@/domain/routes";
import { readRememberedWorkspaceId } from "@/features/app/model/workspace-memory";
import { selectWorkspaceIntoState } from "@/features/app/model/workspace-selection";
import { useTaskSnapshotStore } from "@/state/task-snapshot-store";
import { useWorkspaceStore } from "@/state/workspace-store";

export function useServerBootstrap(): void {
  const location = useLocation();
  const restoreAttempted = useRef(false);

  const setTasks = useTaskSnapshotStore((state) => state.setTasks);
  const resetTasks = useTaskSnapshotStore((state) => state.reset);
  const resetWorkspaceTasks = useTaskSnapshotStore((state) => state.resetWorkspace);

  const phase = useWorkspaceStore((state) => state.phase);
  const server = useWorkspaceStore((state) => state.server);
  const setConnecting = useWorkspaceStore((state) => state.setConnecting);
  const setConnected = useWorkspaceStore((state) => state.setConnected);
  const setSelectedWorkspace = useWorkspaceStore(
    (state) => state.setSelectedWorkspace,
  );
  const setFailed = useWorkspaceStore((state) => state.setFailed);
  const setError = useWorkspaceStore((state) => state.setError);

  const initializeServer = useEffectEvent(async () => {
    setConnecting();
    resetTasks();
    try {
      const bootstrap = await connectServer(getRuntime());
      setConnected(
        bootstrap.server,
        bootstrap.status,
        bootstrap.catalog,
        bootstrap.workspaces,
      );

      const routeWorkspaceId = parseTaskDetailPath(location.pathname)?.workspaceId;
      const rememberedId = readRememberedWorkspaceId();
      const initialWorkspace =
        bootstrap.workspaces.find(
          (workspace) => workspace.workspace_id === routeWorkspaceId,
        ) ??
        bootstrap.workspaces.find(
          (workspace) => workspace.workspace_id === rememberedId,
        ) ??
        bootstrap.workspaces[0];

      if (initialWorkspace) {
        await selectWorkspaceIntoState({
          runtime: getRuntime(),
          workspace: initialWorkspace,
          setTasks,
          resetWorkspace: resetWorkspaceTasks,
          setSelectedWorkspace,
          setError,
        });
      }
    } catch (connectError) {
      setFailed(
        connectError instanceof Error
          ? connectError.message
          : "Failed to connect app-server",
      );
    }
  });

  useEffect(() => {
    if (restoreAttempted.current) {
      return;
    }
    if (phase !== "idle" || server) {
      return;
    }
    restoreAttempted.current = true;
    void initializeServer();
  }, [initializeServer, phase, server]);
}
