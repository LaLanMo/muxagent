import { NavLink } from "react-router-dom";
import type { ShellChromeModel } from "@/features/app/model/use-shell-chrome";
import { DesktopShellFrame } from "@/features/layout/ui/DesktopShellFrame";
import { ShellIcon } from "@/features/layout/ui/ShellIcon";
import { NewTaskModal } from "@/features/new-task/ui/NewTaskModal";
import type { ConfigCatalogEntryDto } from "@/rpc/types";
import type { TaskBoardColumnModel } from "@/features/tasks/ui/TaskBoard";
import { TaskBoard } from "@/features/tasks/ui/TaskBoard";
import type { TaskListRowModel } from "@/features/tasks/ui/TaskList";
import { TaskList } from "@/features/tasks/ui/TaskList";

type EntryShellScreenProps = {
  shell: ShellChromeModel;
  columns: TaskBoardColumnModel[];
  rows: TaskListRowModel[];
  hasTasks: boolean;
  launchableEntries: ConfigCatalogEntryDto[];
  onOpenModal: () => void;
  modal: {
    description: string;
    setDescription: (value: string) => void;
    selectedTargetWorkspaceId: string;
    setSelectedTargetWorkspaceId: (value: string) => void;
    workspaceOptions: Array<{ id: string; label: string; path: string }>;
    selectedAlias: string;
    setSelectedAlias: (value: string) => void;
    selectedEntry?: ConfigCatalogEntryDto;
    flowNodes: string[];
    useWorktree: boolean;
    setUseWorktree: (value: boolean) => void;
    worktreeAvailable: boolean;
    configMaxIterations?: number;
    configEntryNode?: string;
    configPicking: boolean;
    toggleConfigPicker: () => void;
    closeConfigPicker: () => void;
    submitting: boolean;
    canSubmit: boolean;
    error?: string;
    submit: () => Promise<void>;
  };
  modalOpen: boolean;
  onCloseModal: () => void;
};

function slugifyTaskView(label: string) {
  return label.toLowerCase().replace(/\s+/g, "-");
}

function layoutIcon(label: string) {
  return label === "Board" ? "board" : "list";
}

export function EntryShellScreen({
  shell,
  columns,
  rows,
  hasTasks,
  launchableEntries,
  onOpenModal,
  modal,
  modalOpen,
  onCloseModal,
}: EntryShellScreenProps) {
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
          shell.phase === "connected" ? (
            <>
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
              <div className="task-layout-switch" data-testid="task-layout-switch">
                {shell.taskLayoutNav.map((item) => (
                  <NavLink
                    className={({ isActive }) =>
                      `task-layout-switch__item${
                        (typeof item.active === "boolean" ? item.active : isActive)
                          ? " is-active"
                          : ""
                      }`
                    }
                    aria-label={`Switch to ${item.label.toLowerCase()} layout`}
                    data-testid={`task-layout-${item.label.toLowerCase()}`}
                    end={item.to === "/" || item.to?.startsWith("/?")}
                    key={item.label}
                    to={item.to ?? "/"}
                  >
                    <ShellIcon name={layoutIcon(item.label)} />
                  </NavLink>
                ))}
              </div>
            </>
          ) : shell.phase === "connecting" || shell.bootstrapPending ? null : (
            <button
              className="secondary-action"
              data-testid="reconnect-app-server"
              onClick={shell.reconnect}
              type="button"
            >
              Reconnect
            </button>
          )
        }
      >
        <section
          className={`board-screen board-screen--${shell.taskLayout}`}
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
            <div className="board-empty-state" data-testid="board-empty-state">
              <h2>No tasks yet</h2>
              <p>Start the first task for this workspace. Config, runtime, and flow stay in the launch modal.</p>
              <button className="primary-action" onClick={onOpenModal} type="button">
                New Task
              </button>
            </div>
          ) : (
            <>
              {shell.taskLayout === "list" ? (
                <TaskList rows={rows} />
              ) : (
                <TaskBoard columns={columns} />
              )}
            </>
          )}
        </section>
      </DesktopShellFrame>

      <NewTaskModal
        configDescription={modal.selectedEntry?.description}
        selectedRuntimeName={modal.selectedEntry?.runtime_name}
        configMaxIterations={modal.configMaxIterations}
        configEntryNode={modal.configEntryNode}
        configPicking={modal.configPicking}
        onToggleConfigPicker={modal.toggleConfigPicker}
        onCloseConfigPicker={modal.closeConfigPicker}
        description={modal.description}
        entries={launchableEntries}
        error={modal.error}
        flowNodes={modal.flowNodes}
        onTargetWorkspaceChange={modal.setSelectedTargetWorkspaceId}
        onAliasChange={modal.setSelectedAlias}
        onClose={onCloseModal}
        onDescriptionChange={modal.setDescription}
        onSubmit={() => void modal.submit()}
        onToggleWorktree={modal.setUseWorktree}
        open={modalOpen}
        selectedTargetWorkspaceId={modal.selectedTargetWorkspaceId}
        selectedAlias={modal.selectedAlias}
        submitting={modal.submitting}
        canSubmit={modal.canSubmit}
        useWorktree={modal.useWorktree}
        workspaceOptions={modal.workspaceOptions}
        worktreeAvailable={modal.worktreeAvailable}
      />
    </>
  );
}
