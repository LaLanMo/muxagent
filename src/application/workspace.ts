import type { DesktopRuntime } from "@/platform/contract";
import type {
  ConfigCatalogResult,
  InitializeResult,
  ServiceStatusResult,
  TaskViewDto,
  WorkspaceSummaryDto,
} from "@/rpc/types";

export type ServerBootstrap = {
  server: InitializeResult;
  status: ServiceStatusResult;
  catalog: ConfigCatalogResult;
  workspaces: WorkspaceSummaryDto[];
};

export type WorkspaceSelectionBootstrap = {
  workspace: WorkspaceSummaryDto;
  tasks: TaskViewDto[];
};

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
  const [status, catalog, workspaceList] = await Promise.all([
    runtime.backend.status(),
    runtime.backend.configCatalog(),
    runtime.backend.workspaceList(),
  ]);

  return {
    server,
    status,
    catalog,
    workspaces: workspaceList.workspaces,
  };
}

export async function addWorkspace(
  runtime: DesktopRuntime,
  path: string,
): Promise<WorkspaceSummaryDto> {
  const trimmed = path.trim();
  if (!trimmed) {
    throw new Error("Workspace path is required");
  }
  const result = await runtime.backend.workspaceAdd({ path: trimmed });
  return result.workspace;
}

export async function renameWorkspace(
  runtime: DesktopRuntime,
  workspaceId: string,
  displayName: string,
): Promise<WorkspaceSummaryDto> {
  const trimmedWorkspaceId = workspaceId.trim();
  const trimmedDisplayName = displayName.trim();
  if (!trimmedWorkspaceId) {
    throw new Error("Workspace id is required");
  }
  if (!trimmedDisplayName) {
    throw new Error("Workspace name is required");
  }
  const result = await runtime.backend.workspaceUpdate({
    workspace_id: trimmedWorkspaceId,
    display_name: trimmedDisplayName,
  });
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
  const taskList = await runtime.backend.taskList(workspace.workspace_id);
  return {
    workspace,
    tasks: taskList.tasks,
  };
}

export async function disconnectServer(runtime: DesktopRuntime): Promise<void> {
  await runtime.backend.disconnect();
}
