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
  id,
  label,
  activePanel,
  onSelect,
  children,
}: {
  id: WorkbenchPanelId;
  label: string;
  activePanel: WorkbenchPanelId;
  onSelect: (id: WorkbenchPanelId) => void;
  children: ReactNode;
}) {
  const isActive = activePanel === id;
  return (
    <button
      aria-label={label}
      aria-pressed={isActive}
      className={activityButtonClass(isActive)}
      data-testid={`workbench-activity-${id}`}
      onClick={() => onSelect(id)}
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
            <div className="workbench__traffic-lights" aria-hidden="true">
              <span className="workbench__traffic-light is-red" />
              <span className="workbench__traffic-light is-yellow" />
              <span className="workbench__traffic-light is-green" />
            </div>

            <nav className="workbench__activity-nav" aria-label="Primary">
              <ActivityBarIcon
                id="tasks"
                label="Tasks"
                activePanel={activePanel}
                onSelect={setPanel}
              >
                <ListTodo size={18} strokeWidth={1.9} />
              </ActivityBarIcon>
              <ActivityBarIcon
                id="source-control"
                label="Source Control"
                activePanel={activePanel}
                onSelect={setPanel}
              >
                <GitBranch size={18} strokeWidth={1.9} />
              </ActivityBarIcon>
              <ActivityBarIcon
                id="configs"
                label="Configs"
                activePanel={activePanel}
                onSelect={setPanel}
              >
                <SlidersHorizontal size={18} strokeWidth={1.9} />
              </ActivityBarIcon>
            </nav>
          </div>

          <NavLink
            aria-label="Settings"
            className={({ isActive }) => activityButtonClass(isActive)}
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
