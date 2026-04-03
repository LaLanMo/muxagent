import { useEffect, useEffectEvent, useState } from "react";
import { useParams } from "react-router-dom";
import { getRuntime } from "@/app/runtime";
import { useWorkspaceSelection } from "@/features/app/model/use-workspace-selection";
import { useWorkspaceStore } from "@/state/workspace-store";

export function useTaskRouteSelection(): "pending" | "ready" | "redirect" {
  const { workspaceId = "", taskId = "" } = useParams();
  const phase = useWorkspaceStore((state) => state.phase);
  const workspaces = useWorkspaceStore((state) => state.workspaces);
  const upsertWorkspace = useWorkspaceStore((state) => state.upsertWorkspace);
  const selectedWorkspaceId = useWorkspaceStore(
    (state) => state.selectedWorkspaceId,
  );
  const routeWorkspace = workspaces.find(
    (workspace) => workspace.workspace_id === workspaceId,
  );
  const { selectWorkspace } = useWorkspaceSelection();
  const [syncingWorkspaceId, setSyncingWorkspaceId] = useState<string | undefined>();
  const [failedWorkspaceId, setFailedWorkspaceId] = useState<string | undefined>();
  const [resolvingWorkspaceId, setResolvingWorkspaceId] = useState<
    string | undefined
  >();

  useEffect(() => {
    setSyncingWorkspaceId(undefined);
    setFailedWorkspaceId(undefined);
    setResolvingWorkspaceId(undefined);
  }, [taskId, workspaceId]);

  const resolveRouteWorkspace = useEffectEvent(async () => {
    if (!workspaceId) {
      return;
    }
    setResolvingWorkspaceId(workspaceId);
    try {
      const result = await getRuntime().backend.workspaceGet(workspaceId);
      upsertWorkspace(result.workspace);
    } catch {
      setFailedWorkspaceId(workspaceId);
    } finally {
      setResolvingWorkspaceId((current) =>
        current === workspaceId ? undefined : current,
      );
    }
  });

  useEffect(() => {
    if (phase !== "connected" || !workspaceId || !taskId || routeWorkspace) {
      return;
    }
    if (
      resolvingWorkspaceId === workspaceId ||
      failedWorkspaceId === workspaceId
    ) {
      return;
    }
    void resolveRouteWorkspace();
  }, [
    failedWorkspaceId,
    phase,
    resolveRouteWorkspace,
    resolvingWorkspaceId,
    routeWorkspace,
    taskId,
    workspaceId,
  ]);

  useEffect(() => {
    if (phase !== "connected" || !routeWorkspace || !workspaceId || !taskId) {
      return;
    }
    if (
      selectedWorkspaceId === workspaceId ||
      syncingWorkspaceId === workspaceId ||
      failedWorkspaceId === workspaceId
    ) {
      return;
    }
    setSyncingWorkspaceId(workspaceId);
    void selectWorkspace(routeWorkspace, {
      persist: false,
      navigateHomeFromTaskRoute: false,
    }).then((selected) => {
      setSyncingWorkspaceId((current) =>
        current === workspaceId ? undefined : current,
      );
      setFailedWorkspaceId(selected ? undefined : workspaceId);
    });
  }, [
    failedWorkspaceId,
    phase,
    routeWorkspace,
    selectWorkspace,
    selectedWorkspaceId,
    syncingWorkspaceId,
    taskId,
    workspaceId,
  ]);

  if (!workspaceId || !taskId) {
    return "redirect";
  }
  if (
    phase === "idle" ||
    phase === "connecting" ||
    resolvingWorkspaceId === workspaceId
  ) {
    return "pending";
  }
  if (
    phase !== "connected" ||
    failedWorkspaceId === workspaceId ||
    !routeWorkspace
  ) {
    return "redirect";
  }
  if (
    syncingWorkspaceId === workspaceId ||
    selectedWorkspaceId !== workspaceId
  ) {
    return "pending";
  }
  return "ready";
}
