import { type ReactNode } from "react";
import {
  GitBranch,
  ListTodo,
  Settings,
  SlidersHorizontal,
} from "lucide-react";
import { NavLink, useLocation, useSearchParams } from "react-router-dom";
import { startWindowDrag } from "@/features/layout/ui/window-drag";
import { TasksPanel } from "@/features/layout/ui/TasksPanel";
import { SourceControlPanel } from "@/features/layout/ui/SourceControlPanel";
import { ConfigsPanel } from "@/features/layout/ui/ConfigsPanel";
import { ConfirmDialog } from "@/features/shared/ui/ConfirmDialog";
import { useShellModel } from "@/features/app/model/use-shell-model";
import {
  isSourceControlPath,
  parseTaskDetailPath,
} from "@/domain/routes";

export type WorkbenchPanelId = "tasks" | "source-control" | "configs";
type WorkbenchActivityId = WorkbenchPanelId | "settings";

export function defaultPanelForPath(pathname: string): WorkbenchPanelId {
  if (isSourceControlPath(pathname)) {
    return "source-control";
  }
  if (pathname.startsWith("/configs")) {
    return "configs";
  }
  return "tasks";
}

export function useActivePanelId(): WorkbenchPanelId {
  const location = useLocation();
  const [searchParams] = useSearchParams();
  const raw = searchParams.get("panel");
  if (raw === "tasks" || raw === "source-control" || raw === "configs") {
    return raw;
  }
  return defaultPanelForPath(location.pathname);
}

function activityButtonClass(active: boolean): string {
  return active
    ? "workbench__activity-link is-active"
    : "workbench__activity-link";
}

function ActivityBarIcon({
  label,
  active,
  onSelect,
  children,
}: {
  label: string;
  active: boolean;
  onSelect: () => void;
  children: ReactNode;
}) {
  return (
    <button
      aria-label={label}
      aria-pressed={active}
      className={activityButtonClass(active)}
      data-testid={`workbench-activity-${label.toLowerCase().replace(/\s+/g, "-")}`}
      onClick={onSelect}
      type="button"
    >
      {children}
    </button>
  );
}

export function WorkbenchShell({ children }: { children: ReactNode }) {
  const shell = useShellModel();
  const activePanel = useActivePanelId();
  const [searchParams, setSearchParams] = useSearchParams();
  const location = useLocation();
  const activeActivity: WorkbenchActivityId = location.pathname.startsWith("/settings")
    ? "settings"
    : activePanel;

  function setPanel(id: WorkbenchPanelId) {
    const next = new URLSearchParams(searchParams);
    const defaultId = defaultPanelForPath(location.pathname);
    if (id === defaultId) {
      next.delete("panel");
    } else {
      next.set("panel", id);
    }
    setSearchParams(next, { replace: true });
  }

  const panelNode =
    activePanel === "source-control" ? (
      <SourceControlPanel />
    ) : activePanel === "configs" ? (
      <ConfigsPanel shell={shell} />
    ) : (
      <TasksPanel shell={shell} />
    );

  const onTaskDetail = Boolean(parseTaskDetailPath(location.pathname));

  return (
    <>
      <main className="workbench" data-testid="workbench-shell">
        <aside className="workbench__activity-bar">
          <div
            aria-hidden="true"
            className="workbench__activity-drag-strip"
            onMouseDown={(event) => {
              void startWindowDrag(event);
            }}
          />
          <div className="workbench__activity-top">
            <nav className="workbench__activity-nav" aria-label="Primary">
              <ActivityBarIcon
                label="Tasks"
                active={activeActivity === "tasks"}
                onSelect={() => setPanel("tasks")}
              >
                <ListTodo size={18} strokeWidth={1.9} />
              </ActivityBarIcon>
              <ActivityBarIcon
                label="Source Control"
                active={activeActivity === "source-control"}
                onSelect={() => setPanel("source-control")}
              >
                <GitBranch size={18} strokeWidth={1.9} />
              </ActivityBarIcon>
              <ActivityBarIcon
                label="Configs"
                active={activeActivity === "configs"}
                onSelect={() => setPanel("configs")}
              >
                <SlidersHorizontal size={18} strokeWidth={1.9} />
              </ActivityBarIcon>
            </nav>
          </div>

          <NavLink
            aria-label="Settings"
            className={activityButtonClass(activeActivity === "settings")}
            data-testid="workbench-activity-settings"
            to="/settings"
          >
            <Settings size={18} strokeWidth={1.9} />
          </NavLink>
        </aside>

        <section
          className="workbench__panel"
          data-testid={`workbench-panel-${activePanel}`}
        >
          {panelNode}
        </section>

        <section
          className={`workbench__main${onTaskDetail ? " workbench__main--detail" : ""}`}
          data-testid="workbench-main"
        >
          {children}
        </section>
      </main>

      {shell.workspaceRemoveDialog ? (
        <ConfirmDialog {...shell.workspaceRemoveDialog} />
      ) : null}
    </>
  );
}
