import { Plus, Trash2 } from "lucide-react";
import { NavLink } from "react-router-dom";
import type { ShellChromeModel } from "@/features/app/model/use-shell-chrome";
import { Button } from "@/features/shared/ui/Button";
import { ShellIcon } from "@/features/layout/ui/ShellIcon";

type TasksPanelProps = {
  shell: ShellChromeModel;
};

function slugifyTaskView(label: string) {
  return label.toLowerCase().replace(/\s+/g, "-");
}

export function TasksPanel({ shell }: TasksPanelProps) {
  const showWorkspacePrimaryAction = shell.workspaceItems.length === 0;
  const primaryActionLabel = showWorkspacePrimaryAction ? "New Workspace" : "New Task";
  const primaryActionTestId = showWorkspacePrimaryAction
    ? "open-new-workspace"
    : "open-new-task";
  const primaryActionHandler = showWorkspacePrimaryAction
    ? () => void shell.addWorkspace()
    : shell.openNewTask;
  const primaryActionDisabled = showWorkspacePrimaryAction
    ? shell.phase !== "connected"
    : shell.phase !== "connected" || shell.workspaceCount === 0;

  return (
    <div className="tasks-panel" data-testid="tasks-panel">
      <div className="tasks-panel__header">
        <Button
          data-testid={primaryActionTestId}
          disabled={primaryActionDisabled}
          fullWidth
          leadingIcon={<Plus strokeWidth={2.2} />}
          onClick={primaryActionHandler}
          size="md"
          type="button"
          variant="primary"
        >
          {primaryActionLabel}
        </Button>
      </div>

      <div className="tasks-panel__status">
        <div className="tasks-panel__section-header">
          <span>STATUS</span>
        </div>
        <nav className="tasks-panel__filter-nav" aria-label="Task filters">
          {shell.taskViewNav.map((item) => (
            <NavLink
              className={({ isActive }) =>
                `tasks-panel__filter${
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
              {item.count != null ? (
                <span className="tasks-panel__filter-count">{item.count}</span>
              ) : null}
            </NavLink>
          ))}
        </nav>
      </div>

      <div className="tasks-panel__workspaces">
        <div className="tasks-panel__section-header">
          <span>WORKSPACE</span>
          <button
            aria-label="Add workspace"
            className="tasks-panel__add-workspace"
            data-testid="workspace-picker-button"
            disabled={shell.phase !== "connected"}
            onClick={() => void shell.addWorkspace()}
            type="button"
          >
            <Plus aria-hidden="true" size={14} strokeWidth={1.8} />
          </button>
        </div>
        <div className="tasks-panel__workspace-list">
          {shell.workspaceItems.length > 0 ? (
            <>
              <div
                className={`tasks-panel__workspace-item${
                  shell.allWorkspacesActive ? " is-active" : ""
                }`}
                data-testid="task-scope-all-workspaces"
              >
                <button
                  className={`tasks-panel__workspace-row${
                    shell.allWorkspacesActive ? " is-active" : ""
                  }`}
                  onClick={shell.showAllTasks}
                  title="All workspaces"
                  type="button"
                >
                  <span className="tasks-panel__workspace-leading">
                    <ShellIcon name="board" />
                    <span className="tasks-panel__workspace-label">
                      All workspaces
                    </span>
                  </span>
                </button>
              </div>
              {shell.workspaceItems.map((item) => {
                const badgeClass = item.badgeTone
                  ? `tasks-panel__workspace-badge tasks-panel__workspace-badge--${item.badgeTone}`
                  : "tasks-panel__workspace-badge";
                return (
                  <div
                    className={`tasks-panel__workspace-item${
                      item.active ? " is-active" : ""
                    }${item.removePending ? " is-pending" : ""}`}
                    data-testid={`workspace-row-${item.id}`}
                    key={item.id}
                  >
                    <button
                      className={`tasks-panel__workspace-row${
                        item.active ? " is-active" : ""
                      }`}
                      onClick={item.onClick}
                      title={item.label}
                      type="button"
                    >
                      <span className="tasks-panel__workspace-leading">
                        <ShellIcon name="workspace" />
                        <span className="tasks-panel__workspace-label">
                          {item.label}
                        </span>
                      </span>
                      {item.active && item.badgeCount ? (
                        <span className={badgeClass}>{item.badgeCount}</span>
                      ) : null}
                    </button>
                    {item.onRemove ? (
                      <button
                        aria-label={`Remove workspace ${item.label}`}
                        className="icon-button tasks-panel__workspace-remove"
                        data-testid="workspace-row-remove-button"
                        disabled={item.removePending}
                        onClick={(event) => {
                          event.stopPropagation();
                          item.onRemove?.();
                        }}
                        type="button"
                      >
                        <Trash2 aria-hidden="true" size={14} strokeWidth={1.9} />
                      </button>
                    ) : null}
                  </div>
                );
              })}
            </>
          ) : (
            <div className="tasks-panel__empty">No workspaces yet</div>
          )}
        </div>
      </div>
    </div>
  );
}
