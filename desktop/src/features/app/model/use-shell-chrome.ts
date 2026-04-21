import { useLocation, useSearchParams } from "react-router-dom";
import {
  buildInboxItems,
  collectScopedTasks,
  type BoardFilter,
  type ScopedTaskView,
} from "@/domain/task-shell";
import type { ShellCommands } from "@/features/app/model/use-shell-commands";
import {
  buildTaskBoardHref,
  isSourceControlPath,
  parseTaskBoardHref,
  parseTaskBoardPath,
  parseTaskDetailPath,
  sourceControlRoutePath,
  type TaskBoardScope,
} from "@/domain/routes";
import type {
  ShellNavItem,
  ShellWorkspaceItem,
} from "@/features/layout/ui/DesktopShellFrame";
import type { ConfirmDialogProps } from "@/features/shared/ui/ConfirmDialog";
import type { TaskViewDto, WorkspaceSummaryDto } from "@/rpc/types";
import { tasksForWorkspace, useTaskSnapshotStore } from "@/state/task-snapshot-store";
import { useWorkspaceStore } from "@/state/workspace-store";

function parseBoardFilter(raw: string | null): BoardFilter {
  switch (raw) {
    case "mine":
    case "active":
    case "history":
    case "attention":
      return raw;
    default:
      return "all";
  }
}

function buildTaskSurfacePath(scope: TaskBoardScope, filter: BoardFilter): string {
  const params = new URLSearchParams();
  if (filter !== "all") {
    params.set("view", filter);
  }
  return buildTaskBoardHref(scope, params.toString() ? `?${params.toString()}` : "");
}

function scopesEqual(left: TaskBoardScope, right: TaskBoardScope): boolean {
  if (left.kind !== right.kind) {
    return false;
  }
  if (left.kind === "all") {
    return true;
  }
  return right.kind === "workspace" && left.workspaceId === right.workspaceId;
}

function workspaceScope(workspaceId: string | undefined): TaskBoardScope {
  return workspaceId
    ? { kind: "workspace", workspaceId }
    : { kind: "all" };
}

function workspaceExists(
  scope: TaskBoardScope,
  workspaces: WorkspaceSummaryDto[],
): boolean {
  return (
    scope.kind === "all" ||
    workspaces.some((workspace) => workspace.workspace_id === scope.workspaceId)
  );
}

function scopedTasksForScope(
  scope: TaskBoardScope,
  workspaces: WorkspaceSummaryDto[],
  taskIdsByWorkspaceId: Record<string, string[]>,
  tasksById: Record<string, TaskViewDto>,
): ScopedTaskView[] {
  if (scope.kind === "all") {
    return collectScopedTasks(workspaces, taskIdsByWorkspaceId, tasksById);
  }
  const workspace = workspaces.find(
    (entry) => entry.workspace_id === scope.workspaceId,
  );
  return tasksForWorkspace(taskIdsByWorkspaceId, tasksById, scope.workspaceId).map(
    (task) => ({
      workspaceId: scope.workspaceId,
      workspaceLabel: workspace?.display_name ?? "Workspace",
      task,
    }),
  );
}

export type ShellChromeState = {
  workDir: string;
  workspaceLabel: string;
  workspaceCount: number;
  allWorkspacesActive: boolean;
  phase: "idle" | "connecting" | "connected" | "failed";
  bootstrapPending: boolean;
  error?: string;
  boardFilter: BoardFilter;
  workspaceItems: Array<{
    id: string;
    label: string;
    active?: boolean;
    badgeCount?: number;
    badgeTone?: "running" | "attention";
  }>;
  primaryNav: ShellNavItem[];
  taskViewNav: ShellNavItem[];
  footerNav: ShellNavItem;
};

export type ShellChromeModel = Omit<ShellChromeState, "workspaceItems"> &
  ShellCommands & {
    workspaceItems: ShellWorkspaceItem[];
    workspaceRemoveDialog?: ConfirmDialogProps;
  };

export function useShellChrome(): ShellChromeState {
  const location = useLocation();
  const [searchParams] = useSearchParams();

  const phase = useWorkspaceStore((state) => state.phase);
  const bootstrapPending = useWorkspaceStore((state) => state.bootstrapPending);
  const error = useWorkspaceStore((state) => state.error);
  const workspaces = useWorkspaceStore((state) => state.workspaces);
  const selectedWorkspaceId = useWorkspaceStore(
    (state) => state.selectedWorkspaceId,
  );

  const taskSurfaceReturnContext = useWorkspaceStore(
    (state) => state.taskSurfaceReturnContext,
  );
  const taskRoute = parseTaskDetailPath(location.pathname);
  const boardRoute = parseTaskBoardPath(location.pathname);
  const sourceControlActive = isSourceControlPath(location.pathname);
  const currentBoardScope = boardRoute;
  const returnBoardScope = taskSurfaceReturnContext?.path
    ? parseTaskBoardHref(taskSurfaceReturnContext.path)?.scope
    : null;
  const validReturnBoardScope =
    returnBoardScope && workspaceExists(returnBoardScope, workspaces)
      ? returnBoardScope
      : null;
  const focusScope =
    boardRoute ??
    (taskRoute
      ? workspaceScope(taskRoute.workspaceId)
      : workspaceScope(selectedWorkspaceId));
  const statusTargetScope =
    boardRoute ??
    validReturnBoardScope ??
    (taskRoute
      ? workspaceScope(taskRoute.workspaceId)
      : workspaceScope(selectedWorkspaceId));
  const focusWorkspaceId =
    focusScope.kind === "workspace" ? focusScope.workspaceId : undefined;
  const focusWorkspace = focusWorkspaceId
    ? workspaces.find((workspace) => workspace.workspace_id === focusWorkspaceId)
    : undefined;
  const allWorkspacesActive =
    phase === "connected" && workspaces.length > 0 && focusScope.kind === "all";
  const tasksById = useTaskSnapshotStore((state) => state.tasksById);
  const taskIdsByWorkspaceId = useTaskSnapshotStore(
    (state) => state.taskIdsByWorkspaceId,
  );
  const scopedTasks = scopedTasksForScope(
    statusTargetScope,
    workspaces,
    taskIdsByWorkspaceId,
    tasksById,
  );

  const inboxItems = buildInboxItems(scopedTasks);
  const boardFilter = parseBoardFilter(searchParams.get("view"));
  const taskSurfaceActive = Boolean(boardRoute || taskRoute);
  const statusNavActive = (filter: BoardFilter) =>
    Boolean(
      currentBoardScope &&
        scopesEqual(currentBoardScope, statusTargetScope) &&
        boardFilter === filter,
    );

  const primaryNav: ShellNavItem[] = [
    {
      label: "Tasks",
      to: "/",
      active: taskSurfaceActive,
      icon: "tasks",
    },
    {
      label: "Source Control",
      to: sourceControlRoutePath,
      icon: "source-control",
      active: sourceControlActive,
    },
    {
      label: "Configs",
      to: "/configs",
      icon: "configs",
      active: location.pathname.startsWith("/configs"),
    },
  ];

  const taskViewNav: ShellNavItem[] = [
    {
      label: "All",
      to: buildTaskSurfacePath(statusTargetScope, "all"),
      active: statusNavActive("all"),
    },
    {
      label: "Needs Attention",
      to: buildTaskSurfacePath(statusTargetScope, "attention"),
      active: statusNavActive("attention"),
      count: inboxItems.length || undefined,
    },
    {
      label: "Running",
      to: buildTaskSurfacePath(statusTargetScope, "active"),
      active: statusNavActive("active"),
    },
    {
      label: "Completed",
      to: buildTaskSurfacePath(statusTargetScope, "history"),
      active: statusNavActive("history"),
    },
  ];

  const footerNav: ShellNavItem = { label: "Settings", to: "/settings", icon: "settings" };

  const workspaceItems = workspaces.map((workspace) => {
    const attentionCount =
      workspace.task_counts.awaiting + workspace.task_counts.failed;
    const runningCount = workspace.task_counts.running;
    const badgeTone: "running" | "attention" | undefined =
      attentionCount > 0
        ? "attention"
        : runningCount > 0
          ? "running"
          : undefined;
    return {
      id: workspace.workspace_id,
      label: workspace.display_name,
      active:
        (taskSurfaceActive || sourceControlActive) &&
        workspace.workspace_id === focusWorkspaceId,
      badgeCount:
        attentionCount > 0
          ? attentionCount
          : runningCount > 0
            ? runningCount
            : undefined,
      badgeTone,
    };
  });

  return {
    workDir: focusWorkspace?.path ?? "",
    workspaceLabel:
      focusWorkspace?.display_name ??
      (workspaces.length > 0 ? "All workspaces" : "No workspace selected"),
    workspaceCount: workspaces.length,
    allWorkspacesActive,
    phase,
    bootstrapPending,
    error,
    boardFilter,
    workspaceItems,
    primaryNav,
    taskViewNav,
    footerNav,
  };
}
