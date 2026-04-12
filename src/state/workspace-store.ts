import { create } from "zustand";
import type { TaskSurfaceReturnState } from "@/domain/routes";
import type {
  ConfigCatalogResult,
  InitializeResult,
  ServiceStatusResult,
  WorkspaceSummaryDto,
} from "@/rpc/types";

interface WorkspaceState {
  phase: "idle" | "connecting" | "connected" | "failed";
  bootstrapPending: boolean;
  server?: InitializeResult;
  status?: ServiceStatusResult;
  catalog?: ConfigCatalogResult;
  workspaces: WorkspaceSummaryDto[];
  selectedWorkspaceId?: string;
  taskSurfaceReturnContext?: TaskSurfaceReturnState;
  error?: string;
  setConnecting: () => void;
  requestBootstrap: () => void;
  setConnected: (
    server: InitializeResult,
    status: ServiceStatusResult,
    catalog: ConfigCatalogResult,
    workspaces: WorkspaceSummaryDto[],
  ) => void;
  setDisconnected: () => void;
  setSelectedWorkspace: (workspaceId?: string) => void;
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
  setConnecting: () =>
    set((state) => ({
      phase: "connecting",
      bootstrapPending: false,
      server: state.server,
      status: state.status,
      catalog: state.catalog,
      error: undefined,
    })),
  requestBootstrap: () =>
    set({
      phase: "idle",
      bootstrapPending: true,
      server: undefined,
      status: undefined,
      catalog: undefined,
      workspaces: [],
      selectedWorkspaceId: undefined,
      taskSurfaceReturnContext: undefined,
      error: undefined,
    }),
  setConnected: (server, status, catalog, workspaces) =>
    set((state) => ({
      phase: "connected",
      bootstrapPending: false,
      server,
      status,
      catalog,
      workspaces: sortWorkspaces(workspaces),
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
      catalog: undefined,
      workspaces: [],
      selectedWorkspaceId: undefined,
      taskSurfaceReturnContext: undefined,
      error: undefined,
    }),
  setSelectedWorkspace: (workspaceId) =>
    set({
      selectedWorkspaceId: workspaceId,
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
      return {
        workspaces,
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
      catalog: undefined,
      workspaces: [],
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
      catalog: undefined,
      workspaces: [],
      selectedWorkspaceId: undefined,
      taskSurfaceReturnContext: undefined,
      error: undefined,
    }),
}));
