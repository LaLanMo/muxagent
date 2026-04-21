import { useEffect, useState } from "react";
import { useLocation, useParams } from "react-router-dom";
import { parseTaskBoardPath } from "@/domain/routes";
import { useWorkspaceSelection } from "@/features/app/model/use-workspace-selection";
import { useWorkspaceStore } from "@/state/workspace-store";

type RouteSyncState =
  | { status: "idle" }
  | { status: "syncing"; workspaceId: string }
  | { status: "failed"; workspaceId: string };

export function useTaskRouteSelection(): "pending" | "ready" | "redirect" {
  const { workspaceId = "", taskId = "" } = useParams();
  const phase = useWorkspaceStore((state) => state.phase);
  const selectedWorkspaceId = useWorkspaceStore(
    (state) => state.selectedWorkspaceId,
  );
  const { selectTaskRouteWorkspace } = useWorkspaceSelection();
  const [routeSyncState, setRouteSyncState] = useState<RouteSyncState>({
    status: "idle",
  });

  useEffect(() => {
    if (phase !== "connected" || !workspaceId || !taskId) {
      if (routeSyncState.status !== "idle") {
        setRouteSyncState({ status: "idle" });
      }
      return;
    }
    if (selectedWorkspaceId === workspaceId) {
      if (routeSyncState.status !== "idle") {
        setRouteSyncState({ status: "idle" });
      }
      return;
    }
    if (
      routeSyncState.status === "syncing" &&
      routeSyncState.workspaceId === workspaceId
    ) {
      return;
    }
    if (
      routeSyncState.status === "failed" &&
      routeSyncState.workspaceId === workspaceId
    ) {
      return;
    }

    setRouteSyncState({ status: "syncing", workspaceId });
    void selectTaskRouteWorkspace(workspaceId).then((result) => {
      setRouteSyncState((current) => {
        if (current.status !== "syncing" || current.workspaceId !== workspaceId) {
          return current;
        }
        return result.status === "selected"
          ? { status: "idle" }
          : { status: "failed", workspaceId };
      });
    });
  }, [
    phase,
    routeSyncState,
    selectTaskRouteWorkspace,
    selectedWorkspaceId,
    taskId,
    workspaceId,
  ]);

  if (!workspaceId || !taskId) {
    return "redirect";
  }
  if (phase === "idle" || phase === "connecting") {
    return "pending";
  }
  if (
    phase !== "connected" ||
    (routeSyncState.status === "failed" &&
      routeSyncState.workspaceId === workspaceId)
  ) {
    return "redirect";
  }
  if (
    (routeSyncState.status === "syncing" &&
      routeSyncState.workspaceId === workspaceId) ||
    selectedWorkspaceId !== workspaceId
  ) {
    return "pending";
  }
  return "ready";
}

export function useTaskBoardRouteSelection(): "pending" | "ready" | "redirect" {
  const location = useLocation();
  const boardRoute = parseTaskBoardPath(location.pathname);
  const workspaceId =
    boardRoute?.kind === "workspace" ? boardRoute.workspaceId : undefined;
  const phase = useWorkspaceStore((state) => state.phase);
  const selectedWorkspaceId = useWorkspaceStore(
    (state) => state.selectedWorkspaceId,
  );
  const { selectTaskRouteWorkspace } = useWorkspaceSelection();
  const [routeSyncState, setRouteSyncState] = useState<RouteSyncState>({
    status: "idle",
  });

  useEffect(() => {
    if (phase !== "connected" || !workspaceId) {
      if (routeSyncState.status !== "idle") {
        setRouteSyncState({ status: "idle" });
      }
      return;
    }
    if (selectedWorkspaceId === workspaceId) {
      if (routeSyncState.status !== "idle") {
        setRouteSyncState({ status: "idle" });
      }
      return;
    }
    if (
      routeSyncState.status === "syncing" &&
      routeSyncState.workspaceId === workspaceId
    ) {
      return;
    }
    if (
      routeSyncState.status === "failed" &&
      routeSyncState.workspaceId === workspaceId
    ) {
      return;
    }

    setRouteSyncState({ status: "syncing", workspaceId });
    void selectTaskRouteWorkspace(workspaceId).then((result) => {
      setRouteSyncState((current) => {
        if (current.status !== "syncing" || current.workspaceId !== workspaceId) {
          return current;
        }
        return result.status === "selected"
          ? { status: "idle" }
          : { status: "failed", workspaceId };
      });
    });
  }, [
    phase,
    routeSyncState,
    selectTaskRouteWorkspace,
    selectedWorkspaceId,
    workspaceId,
  ]);

  if (!boardRoute) {
    return "redirect";
  }
  if (phase === "idle" || phase === "connecting") {
    return "pending";
  }
  if (boardRoute.kind === "all") {
    return "ready";
  }
  if (
    phase !== "connected" ||
    (routeSyncState.status === "failed" &&
      routeSyncState.workspaceId === boardRoute.workspaceId)
  ) {
    return "redirect";
  }
  if (
    (routeSyncState.status === "syncing" &&
      routeSyncState.workspaceId === boardRoute.workspaceId) ||
    selectedWorkspaceId !== boardRoute.workspaceId
  ) {
    return "pending";
  }
  return "ready";
}
