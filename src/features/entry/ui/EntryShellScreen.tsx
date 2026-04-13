import { Inbox, Plus } from "lucide-react";
import { NavLink } from "react-router-dom";
import type { ShellChromeModel } from "@/features/app/model/use-shell-chrome";
import { DesktopShellFrame } from "@/features/layout/ui/DesktopShellFrame";
import type { ConfigCatalogEntryDto } from "@/rpc/types";
import type { TaskBoardColumnModel } from "@/features/tasks/ui/TaskBoard";
import { TaskBoard } from "@/features/tasks/ui/TaskBoard";

type EntryShellScreenProps = {
  shell: ShellChromeModel;
  columns: TaskBoardColumnModel[];
  hasTasks: boolean;
  launchableEntries: ConfigCatalogEntryDto[];
};

function slugifyTaskView(label: string) {
  return label.toLowerCase().replace(/\s+/g, "-");
}

export function EntryShellScreen({
  shell,
  columns,
  hasTasks,
  launchableEntries,
}: EntryShellScreenProps) {
  const showTaskViewSwitch = shell.phase === "connected" && hasTasks;
  const showReconnectAction =
    shell.phase !== "connected" &&
    shell.phase !== "connecting" &&
    !shell.bootstrapPending;
  const showTaskListEmptyState =
    shell.phase === "connected" && shell.workspaceCount > 0 && !hasTasks;

  return (
    <>
      <DesktopShellFrame
        addWorkspaceDisabled={shell.phase !== "connected"}
        footerNav={shell.footerNav}
        onPrimaryAction={shell.openNewTask}
        primaryActionDisabled={
          shell.phase !== "connected" || shell.workspaceCount === 0 || launchableEntries.length === 0
        }
        primaryNav={shell.primaryNav}
        workspaceItems={shell.workspaceItems}
        onAddWorkspace={() => void shell.addWorkspace()}
        topBarLeft={
          <div className="screen-heading screen-heading--shell">
            <h1 className="screen-title">Tasks</h1>
          </div>
        }
        topBarRight={
          showTaskViewSwitch ? (
            <div className="task-view-switch" data-testid="task-view-switch">
              {shell.taskViewNav.map((item) => (
                <NavLink
                  className={({ isActive }) =>
                    `task-view-switch__item${
                      (typeof item.active === "boolean" ? item.active : isActive)
                        ? " is-active"
                        : ""
                    }`
                  }
                  data-testid={`task-view-${slugifyTaskView(item.label)}`}
                  end={item.to === "/" || item.to?.startsWith("/?")}
                  key={item.label}
                  to={item.to ?? "/"}
                >
                  <span>{item.label}</span>
                </NavLink>
              ))}
            </div>
          ) : showReconnectAction ? (
            <button
              className="secondary-action"
              data-testid="reconnect-app-server"
              onClick={shell.reconnect}
              type="button"
            >
              Reconnect
            </button>
          ) : null
        }
      >
        <section
          className={`board-screen board-screen--board${
            showTaskListEmptyState ? " board-screen--board-empty" : ""
          }`}
          data-testid="entry-shell"
        >
          {shell.error ? (
            <div className="inline-banner inline-banner--failed" data-testid="shell-error">
              {shell.error}
            </div>
          ) : null}

          {shell.phase === "connecting" || shell.bootstrapPending ? (
            <div className="board-empty-state" data-testid="entry-empty-state">
              <h2>Connecting to app-server</h2>
              <p>Bootstrapping the local task control plane.</p>
            </div>
          ) : shell.phase !== "connected" ? (
            <div className="board-empty-state" data-testid="entry-empty-state">
              <h2>App-server disconnected</h2>
              <p>Reconnect the local task control plane to browse workspaces and tasks.</p>
              <button
                className="primary-action"
                data-testid="entry-reconnect-button"
                onClick={shell.reconnect}
                type="button"
              >
                Reconnect
              </button>
            </div>
          ) : shell.workspaceCount === 0 ? (
            <div className="board-empty-state" data-testid="entry-empty-state">
              <h2>Add a workspace to start</h2>
              <p>Register a local workspace, then start or review tasks from the same shell.</p>
              <button
                className="primary-action"
                onClick={() => void shell.addWorkspace()}
                type="button"
              >
                Add workspace
              </button>
            </div>
          ) : !hasTasks ? (
            <div
              className="board-empty-state board-empty-state--task-list"
              data-testid="board-empty-state"
            >
              <div className="board-empty-state__panel">
                <div className="board-empty-state__icon" aria-hidden="true">
                  <Inbox size={28} strokeWidth={1.75} />
                </div>
                <h2>No tasks yet</h2>
                <p>Create your first task to start a workflow.</p>
                <button
                  className="board-empty-state__action"
                  onClick={shell.openNewTask}
                  type="button"
                >
                  <Plus aria-hidden="true" size={14} strokeWidth={2.1} />
                  <span>New Task</span>
                </button>
              </div>
            </div>
          ) : (
            <TaskBoard columns={columns} />
          )}
        </section>
      </DesktopShellFrame>
    </>
  );
}
