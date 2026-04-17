import type { DesktopRuntime } from "@/platform/contract";
import type {
  ConfigCatalogResult,
  InitializeResult,
  RuntimeStatusResult,
  ServiceStatusResult,
  TaskViewDto,
  WorkspaceSummaryDto,
} from "@/rpc/types";

export type ServerBootstrap = {
  server: InitializeResult;
  status: ServiceStatusResult;
  runtimeStatus: RuntimeStatusResult;
  catalog: ConfigCatalogResult;
  workspaces: WorkspaceSummaryDto[];
};

export type WorkspaceSelectionBootstrap = {
  workspace: WorkspaceSummaryDto;
  tasks: TaskViewDto[];
};

export type WorkspaceTasksById = Record<string, TaskViewDto[]>;

export async function chooseWorkspace(
  runtime: DesktopRuntime,
): Promise<string | null> {
  const picked = await runtime.shell.pickDirectory();
  return picked?.trim() || null;
}

export async function connectServer(
  runtime: DesktopRuntime,
): Promise<ServerBootstrap> {
  const server = await runtime.backend.connect();
  const [runtimeStatus, status, catalog, workspaceList] = await Promise.all([
    runtime.backend.runtimeStatus(),
    runtime.backend.status(),
    runtime.backend.configCatalog(),
    runtime.backend.workspaceList(),
  ]);

  return {
    server,
    status,
    runtimeStatus,
    catalog,
    workspaces: workspaceList.workspaces,
  };
}

export async function addWorkspace(
  runtime: DesktopRuntime,
  path: string,
  displayName?: string,
): Promise<WorkspaceSummaryDto> {
  const trimmed = path.trim();
  if (!trimmed) {
    throw new Error("Workspace path is required");
  }
  const trimmedDisplayName = displayName?.trim() || undefined;
  const result = await runtime.backend.workspaceAdd({
    path: trimmed,
    display_name: trimmedDisplayName,
  });
  return result.workspace;
}

export async function getWorkspace(
  runtime: DesktopRuntime,
  workspaceId: string,
): Promise<WorkspaceSummaryDto> {
  const trimmedWorkspaceId = workspaceId.trim();
  if (!trimmedWorkspaceId) {
    throw new Error("Workspace id is required");
  }
  const result = await runtime.backend.workspaceGet(trimmedWorkspaceId);
  return result.workspace;
}

export async function removeWorkspace(
  runtime: DesktopRuntime,
  workspaceId: string,
): Promise<void> {
  const trimmedWorkspaceId = workspaceId.trim();
  if (!trimmedWorkspaceId) {
    throw new Error("Workspace id is required");
  }
  await runtime.backend.workspaceRemove({
    workspace_id: trimmedWorkspaceId,
  });
}

export async function loadWorkspaceTasks(
  runtime: DesktopRuntime,
  workspace: WorkspaceSummaryDto,
): Promise<WorkspaceSelectionBootstrap> {
  if (!workspace.reachable) {
    throw new Error("Workspace is unreachable");
  }
  await reconcileWorkspaceStale(runtime, workspace);
  const taskList = await runtime.backend.taskList(workspace.workspace_id);
  return {
    workspace,
    tasks: taskList.tasks,
  };
}

export async function loadAllWorkspaceTasks(
  runtime: DesktopRuntime,
  workspaces: WorkspaceSummaryDto[],
): Promise<WorkspaceTasksById> {
  const entries = await Promise.all(
    workspaces.map(async (workspace) => {
      if (!workspace.reachable) {
        return [workspace.workspace_id, []] as const;
      }

      try {
        await reconcileWorkspaceStale(runtime, workspace);
        const taskList = await runtime.backend.taskList(workspace.workspace_id);
        return [workspace.workspace_id, taskList.tasks] as const;
      } catch {
        return [workspace.workspace_id, []] as const;
      }
    }),
  );

  return Object.fromEntries(entries);
}

export async function disconnectServer(runtime: DesktopRuntime): Promise<void> {
  await runtime.backend.disconnect();
}

async function reconcileWorkspaceStale(
  runtime: DesktopRuntime,
  workspace: WorkspaceSummaryDto,
): Promise<void> {
  if (!workspace.reachable || workspace.actor.state === "active") {
    return;
  }
  await runtime.backend
    .workspaceReconcileStale({ workspace_id: workspace.workspace_id })
    .catch(() => undefined);
}
