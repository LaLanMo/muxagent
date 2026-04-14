import { loadWorkspaceTasks } from "@/application/workspace";
import type { DesktopRuntime } from "@/platform/contract";
import type { TaskViewDto, WorkspaceSummaryDto } from "@/rpc/types";
import { rememberWorkspaceId } from "@/features/app/model/workspace-memory";

type SelectWorkspaceIntoStateArgs = {
  runtime: DesktopRuntime;
  workspace: WorkspaceSummaryDto;
  setTasks: (workspaceId: string, tasks: TaskViewDto[]) => void;
  resetWorkspace: (workspaceId: string) => void;
  setSelectedWorkspace: (workspaceId?: string) => void;
  setError: (message?: string) => void;
  rememberSelection?: boolean;
};

export async function selectWorkspaceIntoState({
  runtime,
  workspace,
  setTasks,
  resetWorkspace,
  setSelectedWorkspace,
  setError,
  rememberSelection = true,
}: SelectWorkspaceIntoStateArgs): Promise<boolean> {
  setError(undefined);
  try {
    const bootstrap = await loadWorkspaceTasks(runtime, workspace);
    setTasks(workspace.workspace_id, bootstrap.tasks);
    setSelectedWorkspace(workspace.workspace_id);
    if (rememberSelection) {
      rememberWorkspaceId(workspace.workspace_id);
    }
    return true;
  } catch (error) {
    resetWorkspace(workspace.workspace_id);
    setError(
      error instanceof Error ? error.message : "Failed to load workspace tasks",
    );
    return false;
  }
}

export function pickPreferredWorkspace(
  workspaces: WorkspaceSummaryDto[],
  preferredIds: Array<string | undefined>,
): WorkspaceSummaryDto | undefined {
  for (const preferredId of preferredIds) {
    const trimmed = preferredId?.trim();
    if (!trimmed) {
      continue;
    }
    const match = workspaces.find(
      (workspace) => workspace.workspace_id === trimmed,
    );
    if (match) {
      return match;
    }
  }
  return workspaces[0];
}

export function pickReplacementWorkspace(
  workspaces: WorkspaceSummaryDto[],
  removedWorkspaceId: string,
): WorkspaceSummaryDto | undefined {
  return workspaces.find(
    (workspace) => workspace.workspace_id !== removedWorkspaceId,
  );
}
