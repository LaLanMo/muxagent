import { useLayoutEffect, useRef } from "react";
import { useLocation } from "react-router-dom";
import type { TaskDetailLocationState } from "@/domain/routes";
import { parseTaskDetailPath } from "@/domain/routes";
import { clearRememberedWorkspaceId, rememberWorkspaceId } from "@/features/app/model/workspace-memory";
import { useWorkspaceStore } from "@/state/workspace-store";

function buildLocationPath(pathname: string, search: string): string {
  return search ? `${pathname}${search}` : pathname;
}

function restoreWorkspaceSelection(workspaceId: string | undefined): void {
  useWorkspaceStore.getState().setSelectedWorkspace(workspaceId);
  if (workspaceId) {
    rememberWorkspaceId(workspaceId);
    return;
  }
  clearRememberedWorkspaceId();
}

export function useTaskSurfaceReturnContext(): void {
  const location = useLocation();
  const selectedWorkspaceId = useWorkspaceStore(
    (state) => state.selectedWorkspaceId,
  );
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
    const previousLocation = previousLocationRef.current;
    const previousTaskRoute = previousLocation
      ? parseTaskDetailPath(previousLocation.pathname)
      : null;
    const currentTaskRoute = parseTaskDetailPath(location.pathname);
    const routeState = location.state as TaskDetailLocationState | null;
    const existingReturnContext = useWorkspaceStore.getState().taskSurfaceReturnContext;

    if (
      currentTaskRoute &&
      previousLocation &&
      !previousTaskRoute &&
      !existingReturnContext
    ) {
      captureTaskSurfaceReturnContext(
        routeState?.taskSurfaceReturnContext ?? {
          path: buildLocationPath(previousLocation.pathname, previousLocation.search),
          workspaceId: selectedWorkspaceId,
        },
      );
    } else if (!currentTaskRoute && previousTaskRoute) {
      const { taskSurfaceReturnContext } = useWorkspaceStore.getState();
      if (
        taskSurfaceReturnContext &&
        buildLocationPath(location.pathname, location.search) ===
          taskSurfaceReturnContext.path
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
    selectedWorkspaceId,
  ]);
}
