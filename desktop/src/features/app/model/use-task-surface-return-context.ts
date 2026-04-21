import { useLayoutEffect, useRef } from "react";
import { useLocation } from "react-router-dom";
import type { TaskDetailLocationState, TaskSurfaceReturnState } from "@/domain/routes";
import {
  buildTaskBoardHref,
  parseTaskBoardHref,
  parseTaskBoardPath,
  parseTaskDetailPath,
} from "@/domain/routes";
import { clearRememberedWorkspaceId, rememberWorkspaceId } from "@/features/app/model/workspace-memory";
import { useWorkspaceStore } from "@/state/workspace-store";

function restoreWorkspaceSelection(workspaceId: string | undefined): void {
  useWorkspaceStore.getState().setSelectedWorkspace(workspaceId);
  if (workspaceId) {
    rememberWorkspaceId(workspaceId);
    return;
  }
  clearRememberedWorkspaceId();
}

function normalizeTaskSurfaceReturnContext(
  context: TaskSurfaceReturnState | undefined,
  workspaceIds: Set<string>,
): TaskSurfaceReturnState | undefined {
  if (!context?.path.trim()) {
    return undefined;
  }
  const boardRoute = parseTaskBoardHref(context.path);
  if (!boardRoute) {
    return undefined;
  }
  if (
    boardRoute.scope.kind === "workspace" &&
    !workspaceIds.has(boardRoute.scope.workspaceId)
  ) {
    return undefined;
  }
  return {
    path: boardRoute.href,
    workspaceId:
      boardRoute.scope.kind === "workspace"
        ? boardRoute.scope.workspaceId
        : undefined,
  };
}

function buildReturnContextFromBoardLocation(
  pathname: string,
  search: string,
  workspaceIds: Set<string>,
): TaskSurfaceReturnState | undefined {
  const boardScope = parseTaskBoardPath(pathname);
  if (!boardScope) {
    return undefined;
  }
  return normalizeTaskSurfaceReturnContext(
    {
      path: buildTaskBoardHref(boardScope, search),
      workspaceId:
        boardScope.kind === "workspace" ? boardScope.workspaceId : undefined,
    },
    workspaceIds,
  );
}

export function useTaskSurfaceReturnContext(): void {
  const location = useLocation();
  const workspaces = useWorkspaceStore((state) => state.workspaces);
  const captureTaskSurfaceReturnContext = useWorkspaceStore(
    (state) => state.captureTaskSurfaceReturnContext,
  );
  const clearTaskSurfaceReturnContext = useWorkspaceStore(
    (state) => state.clearTaskSurfaceReturnContext,
  );
  const previousLocationRef = useRef<
    { pathname: string; search: string } | undefined
  >(undefined);

  useLayoutEffect(() => {
    const workspaceIds = new Set(
      workspaces.map((workspace) => workspace.workspace_id),
    );
    const previousLocation = previousLocationRef.current;
    const previousTaskRoute = previousLocation
      ? parseTaskDetailPath(previousLocation.pathname)
      : null;
    const currentTaskRoute = parseTaskDetailPath(location.pathname);
    const routeState = location.state as TaskDetailLocationState | null;
    const existingReturnContext = useWorkspaceStore.getState().taskSurfaceReturnContext;
    const normalizedExistingReturnContext = normalizeTaskSurfaceReturnContext(
      existingReturnContext,
      workspaceIds,
    );

    if (existingReturnContext && !normalizedExistingReturnContext) {
      clearTaskSurfaceReturnContext();
    }

    if (
      currentTaskRoute &&
      previousLocation &&
      !previousTaskRoute &&
      !normalizedExistingReturnContext
    ) {
      const routeContext = normalizeTaskSurfaceReturnContext(
        routeState?.taskSurfaceReturnContext,
        workspaceIds,
      );
      const previousBoardContext = buildReturnContextFromBoardLocation(
        previousLocation.pathname,
        previousLocation.search,
        workspaceIds,
      );
      const fallbackContext = normalizeTaskSurfaceReturnContext(
        {
          path: buildTaskBoardHref(
            { kind: "workspace", workspaceId: currentTaskRoute.workspaceId },
            previousLocation.search || location.search,
          ),
          workspaceId: currentTaskRoute.workspaceId,
        },
        workspaceIds,
      );
      const nextContext = routeContext ?? previousBoardContext ?? fallbackContext;
      if (nextContext) {
        captureTaskSurfaceReturnContext(nextContext);
      }
    } else if (!currentTaskRoute && previousTaskRoute) {
      const taskSurfaceReturnContext = normalizeTaskSurfaceReturnContext(
        useWorkspaceStore.getState().taskSurfaceReturnContext,
        workspaceIds,
      );
      const destinationBoardContext = buildReturnContextFromBoardLocation(
        location.pathname,
        location.search,
        workspaceIds,
      );
      if (
        taskSurfaceReturnContext &&
        destinationBoardContext?.path === taskSurfaceReturnContext.path
      ) {
        restoreWorkspaceSelection(taskSurfaceReturnContext.workspaceId);
      }
      clearTaskSurfaceReturnContext();
    }

    previousLocationRef.current = {
      pathname: location.pathname,
      search: location.search,
    };
  }, [
    captureTaskSurfaceReturnContext,
    clearTaskSurfaceReturnContext,
    location.pathname,
    location.search,
    workspaces,
  ]);
}
