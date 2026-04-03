import { create } from "zustand";
import type {
  ConfigCatalogResult,
  InitializeResult,
  ServiceStatusResult,
  WorkspaceSummaryDto,
} from "@/rpc/types";

interface WorkspaceState {
  phase: "idle" | "connecting" | "connected" | "failed";
  server?: InitializeResult;
  status?: ServiceStatusResult;
  catalog?: ConfigCatalogResult;
  workspaces: WorkspaceSummaryDto[];
  selectedWorkspaceId?: string;
  error?: string;
  setConnecting: () => void;
  setConnected: (
    server: InitializeResult,
    status: ServiceStatusResult,
    catalog: ConfigCatalogResult,
    workspaces: WorkspaceSummaryDto[],
  ) => void;
  setSelectedWorkspace: (workspaceId?: string) => void;
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
  workspaces: [],
  setConnecting: () =>
    set((state) => ({
      phase: "connecting",
      server: state.server,
      status: state.status,
      catalog: state.catalog,
      error: undefined,
    })),
  setConnected: (server, status, catalog, workspaces) =>
    set((state) => ({
      phase: "connected",
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
  setSelectedWorkspace: (workspaceId) =>
    set({
      selectedWorkspaceId: workspaceId,
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
        selectedWorkspaceId:
          state.selectedWorkspaceId === workspaceId
            ? workspaces[0]?.workspace_id
            : state.selectedWorkspaceId,
      };
    }),
  setError: (message) =>
    set({
      error: message,
    }),
  setFailed: (message) =>
    set({
      phase: "failed",
      error: message,
    }),
  reset: () =>
    set({
      phase: "idle",
      server: undefined,
      status: undefined,
      catalog: undefined,
      workspaces: [],
      selectedWorkspaceId: undefined,
      error: undefined,
    }),
}));
