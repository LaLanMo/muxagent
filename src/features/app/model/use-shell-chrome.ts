import { useLocation, useSearchParams } from "react-router-dom";
import {
  buildInboxItems,
  collectScopedTasks,
  type BoardFilter,
} from "@/domain/task-shell";
import type { ShellCommands } from "@/features/app/model/use-shell-commands";
import { parseTaskDetailPath } from "@/domain/routes";
import type {
  ShellNavItem,
  ShellWorkspaceItem,
} from "@/features/layout/ui/DesktopShellFrame";
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

function buildTaskSurfacePath(filter: BoardFilter): string {
  const params = new URLSearchParams();
  if (filter !== "all") {
    params.set("view", filter);
  }
  const query = params.toString();
  return query ? `/?${query}` : "/";
}

export type ShellChromeState = {
  workDir: string;
  workspaceLabel: string;
  workspaceCount: number;
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

  const selectedWorkspace = workspaces.find(
    (workspace) => workspace.workspace_id === selectedWorkspaceId,
  );
  const tasksById = useTaskSnapshotStore((state) => state.tasksById);
  const taskIdsByWorkspaceId = useTaskSnapshotStore(
    (state) => state.taskIdsByWorkspaceId,
  );
  const scopedTasks = selectedWorkspaceId
    ? tasksForWorkspace(taskIdsByWorkspaceId, tasksById, selectedWorkspaceId).map((task) => ({
        workspaceId: selectedWorkspaceId,
        workspaceLabel: selectedWorkspace?.display_name ?? "Workspace",
        task,
      }))
    : collectScopedTasks(workspaces, taskIdsByWorkspaceId, tasksById);

  const inboxItems = buildInboxItems(scopedTasks);
  const boardFilter = parseBoardFilter(searchParams.get("view"));
  const taskRoute = parseTaskDetailPath(location.pathname);
  const taskSurfaceActive =
    location.pathname === "/" ||
    location.pathname === "/inbox" ||
    Boolean(taskRoute);
  const tasksRootActive =
    location.pathname === "/" && !taskRoute && !selectedWorkspaceId;

  const primaryNav: ShellNavItem[] = [
    {
      label: "Tasks",
      to: "/",
      active: tasksRootActive,
      icon: "tasks",
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
      to: buildTaskSurfacePath("all"),
      active: location.pathname === "/" && boardFilter === "all",
    },
    {
      label: "Needs Attention",
      to: buildTaskSurfacePath("attention"),
      active: location.pathname === "/" && boardFilter === "attention",
      count: inboxItems.length || undefined,
    },
    {
      label: "Running",
      to: buildTaskSurfacePath("active"),
      active: location.pathname === "/" && boardFilter === "active",
    },
    {
      label: "Completed",
      to: buildTaskSurfacePath("history"),
      active: location.pathname === "/" && boardFilter === "history",
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
        taskSurfaceActive &&
        workspace.workspace_id === selectedWorkspaceId,
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
    workDir: selectedWorkspace?.path ?? "",
    workspaceLabel:
      selectedWorkspace?.display_name ??
      (workspaces.length > 0 ? "All workspaces" : "No workspace selected"),
    workspaceCount: workspaces.length,
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
