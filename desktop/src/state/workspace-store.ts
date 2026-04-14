import { create } from "zustand";
import type { TaskSurfaceReturnState } from "@/domain/routes";
import type {
  ConfigCatalogResult,
  InitializeResult,
  RuntimeStatusResult,
  ServiceStatusResult,
  WorkspaceSummaryDto,
} from "@/rpc/types";

interface WorkspaceState {
  phase: "idle" | "connecting" | "connected" | "failed";
  bootstrapPending: boolean;
  server?: InitializeResult;
  status?: ServiceStatusResult;
  runtimeStatus?: RuntimeStatusResult;
  catalog?: ConfigCatalogResult;
  workspaces: WorkspaceSummaryDto[];
  workspaceReconcileCounts: Record<string, number>;
  selectedWorkspaceId?: string;
  taskSurfaceReturnContext?: TaskSurfaceReturnState;
  error?: string;
  setConnecting: () => void;
  requestBootstrap: () => void;
  setConnected: (
    server: InitializeResult,
    status: ServiceStatusResult,
    runtimeStatus: RuntimeStatusResult,
    catalog: ConfigCatalogResult,
    workspaces: WorkspaceSummaryDto[],
  ) => void;
  setDisconnected: () => void;
  setSelectedWorkspace: (workspaceId?: string) => void;
  beginWorkspaceReconcile: (workspaceId: string) => void;
  finishWorkspaceReconcile: (workspaceId: string) => void;
  captureTaskSurfaceReturnContext: (context: TaskSurfaceReturnState) => void;
  clearTaskSurfaceReturnContext: () => void;
  setCatalog: (catalog?: ConfigCatalogResult) => void;
  upsertWorkspace: (workspace: WorkspaceSummaryDto) => void;
  removeWorkspace: (workspaceId: string) => void;
  setError: (message?: string) => void;
  setFailed: (message: string) => void;
  reset: () => void;
}

function sortWorkspaces(workspaces: WorkspaceSummaryDto[]): WorkspaceSummaryDto[] {
  return [...workspaces].sort((left, right) => {
    const leftLast = left.last_opened_at ?? left.added_at;
    const rightLast = right.last_opened_at ?? right.added_at;
    return rightLast.localeCompare(leftLast);
  });
}

export const useWorkspaceStore = create<WorkspaceState>((set) => ({
  phase: "idle",
  bootstrapPending: true,
  workspaces: [],
  workspaceReconcileCounts: {},
  setConnecting: () =>
    set((state) => ({
      phase: "connecting",
      bootstrapPending: false,
      server: state.server,
      status: state.status,
      runtimeStatus: undefined,
      catalog: state.catalog,
      workspaceReconcileCounts: state.workspaceReconcileCounts,
      error: undefined,
    })),
  requestBootstrap: () =>
    set({
      phase: "idle",
      bootstrapPending: true,
      server: undefined,
      status: undefined,
      runtimeStatus: undefined,
      catalog: undefined,
      workspaces: [],
      workspaceReconcileCounts: {},
      selectedWorkspaceId: undefined,
      taskSurfaceReturnContext: undefined,
      error: undefined,
    }),
  setConnected: (server, status, runtimeStatus, catalog, workspaces) =>
    set((state) => ({
      phase: "connected",
      bootstrapPending: false,
      server,
      status,
      runtimeStatus,
      catalog,
      workspaces: sortWorkspaces(workspaces),
      workspaceReconcileCounts: state.workspaceReconcileCounts,
      selectedWorkspaceId:
        state.selectedWorkspaceId &&
        workspaces.some(
          (workspace) => workspace.workspace_id === state.selectedWorkspaceId,
        )
          ? state.selectedWorkspaceId
          : undefined,
      error: undefined,
    })),
  setDisconnected: () =>
    set({
      phase: "idle",
      bootstrapPending: false,
      server: undefined,
      status: undefined,
      runtimeStatus: undefined,
      catalog: undefined,
      workspaces: [],
      workspaceReconcileCounts: {},
      selectedWorkspaceId: undefined,
      taskSurfaceReturnContext: undefined,
      error: undefined,
    }),
  setSelectedWorkspace: (workspaceId) =>
    set({
      selectedWorkspaceId: workspaceId,
    }),
  beginWorkspaceReconcile: (workspaceId) =>
    set((state) => {
      const trimmedWorkspaceId = workspaceId.trim();
      if (!trimmedWorkspaceId) {
        return {};
      }
      return {
        workspaceReconcileCounts: {
          ...state.workspaceReconcileCounts,
          [trimmedWorkspaceId]:
            (state.workspaceReconcileCounts[trimmedWorkspaceId] ?? 0) + 1,
        },
      };
    }),
  finishWorkspaceReconcile: (workspaceId) =>
    set((state) => {
      const trimmedWorkspaceId = workspaceId.trim();
      if (!trimmedWorkspaceId) {
        return {};
      }
      const currentCount = state.workspaceReconcileCounts[trimmedWorkspaceId] ?? 0;
      if (currentCount <= 0) {
        return {};
      }
      const nextCounts = { ...state.workspaceReconcileCounts };
      if (currentCount === 1) {
        delete nextCounts[trimmedWorkspaceId];
      } else {
        nextCounts[trimmedWorkspaceId] = currentCount - 1;
      }
      return {
        workspaceReconcileCounts: nextCounts,
      };
    }),
  captureTaskSurfaceReturnContext: (context) =>
    set({
      taskSurfaceReturnContext: context.path.trim() ? context : undefined,
    }),
  clearTaskSurfaceReturnContext: () =>
    set({
      taskSurfaceReturnContext: undefined,
    }),
  setCatalog: (catalog) =>
    set({
      catalog,
    }),
  upsertWorkspace: (workspace) =>
    set((state) => {
      const next = state.workspaces.some(
        (entry) => entry.workspace_id === workspace.workspace_id,
      )
        ? state.workspaces.map((entry) =>
            entry.workspace_id === workspace.workspace_id ? workspace : entry,
          )
        : [...state.workspaces, workspace];
      return {
        workspaces: sortWorkspaces(next),
      };
    }),
  removeWorkspace: (workspaceId) =>
    set((state) => {
      const workspaces = state.workspaces.filter(
        (workspace) => workspace.workspace_id !== workspaceId,
      );
      const workspaceReconcileCounts = { ...state.workspaceReconcileCounts };
      delete workspaceReconcileCounts[workspaceId];
      return {
        workspaces,
        workspaceReconcileCounts,
      };
    }),
  setError: (message) =>
    set({
      error: message,
    }),
  setFailed: (message) =>
    set({
      phase: "failed",
      bootstrapPending: false,
      server: undefined,
      status: undefined,
      runtimeStatus: undefined,
      catalog: undefined,
      workspaces: [],
      workspaceReconcileCounts: {},
      selectedWorkspaceId: undefined,
      taskSurfaceReturnContext: undefined,
      error: message,
    }),
  reset: () =>
    set({
      phase: "idle",
      bootstrapPending: true,
      server: undefined,
      status: undefined,
      runtimeStatus: undefined,
      catalog: undefined,
      workspaces: [],
      workspaceReconcileCounts: {},
      selectedWorkspaceId: undefined,
      taskSurfaceReturnContext: undefined,
      error: undefined,
    }),
}));
