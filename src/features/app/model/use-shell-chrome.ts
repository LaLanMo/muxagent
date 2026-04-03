import { useEffectEvent } from "react";
import { useLocation, useNavigate, useSearchParams } from "react-router-dom";
import {
  addWorkspace,
  chooseWorkspace,
  disconnectServer,
} from "@/application/workspace";
import { getRuntime } from "@/app/runtime";
import {
  buildInboxItems,
  displayWorkspaceName,
  type BoardFilter,
} from "@/domain/task-shell";
import { clearRememberedWorkspaceId } from "@/features/app/model/workspace-memory";
import { useWorkspaceSelection } from "@/features/app/model/use-workspace-selection";
import { parseTaskDetailPath } from "@/domain/routes";
import type {
  ShellNavItem,
  ShellWorkspaceItem,
} from "@/features/layout/ui/DesktopShellFrame";
import { useTaskSnapshotStore } from "@/state/task-snapshot-store";
import { useWorkspaceStore } from "@/state/workspace-store";

const emptyTasks: never[] = [];

function workspaceRowTone(
  workspace: Parameters<typeof buildWorkspaceMeta>[0],
): ShellChromeModel["connectionTone"] {
  if (!workspace.reachable || workspace.actor.last_error) {
    return "failed";
  }
  const actorState = workspace.actor.state.toLowerCase();
  if (actorState.includes("run") || actorState.includes("start")) {
    return "running";
  }
  if (actorState.includes("await") || actorState.includes("block")) {
    return "awaiting";
  }
  return "neutral";
}

function buildWorkspaceMeta(workspace: {
  path: string;
  display_name: string;
  reachable: boolean;
  actor: { state: string; last_error?: string };
}): string {
  const parts: string[] = [];
  if (!workspace.reachable) {
    parts.push("Unavailable");
  } else if (workspace.actor.last_error) {
    parts.push("Error");
  } else {
    const actorState = workspace.actor.state.trim().toLowerCase();
    if (actorState && actorState !== "idle") {
      parts.push(actorState);
    }
  }

  const basename = displayWorkspaceName(workspace.path);
  if (basename !== workspace.display_name) {
    parts.push(basename);
  }

  return parts.join(" · ");
}

function parseBoardFilter(raw: string | null): BoardFilter {
  switch (raw) {
    case "mine":
    case "active":
    case "history":
      return raw;
    default:
      return "all";
  }
}

export type ShellChromeModel = {
  workDir: string;
  workspaceLabel: string;
  phase: "idle" | "connecting" | "connected" | "failed";
  error?: string;
  connectionTone: "running" | "awaiting" | "done" | "failed" | "neutral";
  connectionLabel: string;
  boardFilter: BoardFilter;
  workspaceItems: ShellWorkspaceItem[];
  primaryNav: ShellNavItem[];
  secondaryNav: ShellNavItem[];
  footerNav: ShellNavItem;
  addWorkspace: () => Promise<void>;
  disconnect: () => Promise<void>;
};

export function useShellChrome(): ShellChromeModel {
  const navigate = useNavigate();
  const location = useLocation();
  const [searchParams] = useSearchParams();

  const resetTasks = useTaskSnapshotStore((state) => state.reset);

  const phase = useWorkspaceStore((state) => state.phase);
  const error = useWorkspaceStore((state) => state.error);
  const status = useWorkspaceStore((state) => state.status);
  const workspaces = useWorkspaceStore((state) => state.workspaces);
  const selectedWorkspaceId = useWorkspaceStore(
    (state) => state.selectedWorkspaceId,
  );
  const upsertWorkspace = useWorkspaceStore((state) => state.upsertWorkspace);
  const setError = useWorkspaceStore((state) => state.setError);
  const resetWorkspace = useWorkspaceStore((state) => state.reset);
  const { selectWorkspace } = useWorkspaceSelection();

  const selectedWorkspace = workspaces.find(
    (workspace) => workspace.workspace_id === selectedWorkspaceId,
  );
  const activeTasks = useTaskSnapshotStore(
    (state) =>
      (selectedWorkspaceId
        ? state.tasksByWorkspaceId[selectedWorkspaceId]
        : undefined) ?? emptyTasks,
  );

  const addWorkspaceAction = useEffectEvent(async () => {
    const picked = await chooseWorkspace(getRuntime());
    if (!picked) {
      return;
    }
    try {
      const workspace = await addWorkspace(getRuntime(), picked);
      upsertWorkspace(workspace);
      await selectWorkspace(workspace);
    } catch (addError) {
      setError(
        addError instanceof Error
          ? addError.message
          : "Failed to add workspace",
      );
    }
  });

  const disconnectAction = useEffectEvent(async () => {
    clearRememberedWorkspaceId();
    await disconnectServer(getRuntime()).catch(() => undefined);
    resetTasks();
    resetWorkspace();
    navigate("/", { replace: true });
  });

  const inboxItems = selectedWorkspaceId
    ? buildInboxItems(activeTasks, selectedWorkspaceId)
    : [];
  const boardFilter = parseBoardFilter(searchParams.get("view"));
  const machinesCount = status?.runtime_count ?? 0;
  const taskRoute = parseTaskDetailPath(location.pathname);
  const boardRouteActive = location.pathname === "/" || Boolean(taskRoute);

  const primaryNav: ShellNavItem[] = [
    {
      label: "Inbox",
      to: "/inbox",
      count: inboxItems.length || undefined,
      icon: "inbox",
    },
    {
      label: "My Tasks",
      to: "/?view=mine",
      active: location.pathname === "/" && boardFilter === "mine",
      icon: "tasks",
    },
    {
      label: "All Tasks",
      to: "/",
      active: boardRouteActive && boardFilter === "all",
      icon: "tasks",
    },
    {
      label: "Active",
      to: "/?view=active",
      active: location.pathname === "/" && boardFilter === "active",
      icon: "active",
    },
    {
      label: "History",
      to: "/?view=history",
      active: location.pathname === "/" && boardFilter === "history",
      icon: "history",
    },
  ];

  const secondaryNav: ShellNavItem[] = [
    {
      label: "Machines",
      to: "/settings#runtime",
      count: machinesCount || undefined,
      icon: "machines",
    },
    { label: "Configs", to: "/configs", icon: "configs" },
  ];

  const footerNav: ShellNavItem = { label: "Settings", to: "/settings", icon: "settings" };

  const workspaceItems: ShellWorkspaceItem[] = workspaces.map((workspace) => ({
    id: workspace.workspace_id,
    label: workspace.display_name,
    meta: buildWorkspaceMeta(workspace),
    active: workspace.workspace_id === selectedWorkspaceId,
    tone: workspaceRowTone(workspace),
    onClick: () => {
      void selectWorkspace(workspace);
    },
  }));

  let connectionLabel = "Disconnected";
  let connectionTone: ShellChromeModel["connectionTone"] = "failed";
  switch (phase) {
    case "connecting":
      connectionLabel = "Connecting";
      connectionTone = "awaiting";
      break;
    case "connected":
      connectionLabel = "Connected";
      connectionTone = "done";
      break;
    case "failed":
      connectionLabel = "Disconnected";
      connectionTone = "failed";
      break;
    case "idle":
    default:
      connectionLabel = "Starting";
      connectionTone = "neutral";
      break;
  }

  return {
    workDir: selectedWorkspace?.path ?? "",
    workspaceLabel: selectedWorkspace?.display_name ?? "No workspace selected",
    phase,
    error,
    connectionTone,
    connectionLabel,
    boardFilter,
    workspaceItems,
    primaryNav,
    secondaryNav,
    footerNav,
    addWorkspace: addWorkspaceAction,
    disconnect: disconnectAction,
  };
}
