import type { ShellChromeModel } from "@/features/app/model/use-shell-chrome";
import { DesktopShellFrame } from "@/features/layout/ui/DesktopShellFrame";
import { NewTaskModal } from "@/features/new-task/ui/NewTaskModal";
import type { ConfigCatalogEntryDto } from "@/rpc/types";
import type { TaskBoardColumnModel } from "@/features/tasks/ui/TaskBoard";
import { TaskBoard } from "@/features/tasks/ui/TaskBoard";

type EntryShellScreenProps = {
  shell: ShellChromeModel;
  columns: TaskBoardColumnModel[];
  hasTasks: boolean;
  launchableEntries: ConfigCatalogEntryDto[];
  onOpenModal: () => void;
  modal: {
    description: string;
    setDescription: (value: string) => void;
    selectedAlias: string;
    setSelectedAlias: (value: string) => void;
    selectedEntry?: ConfigCatalogEntryDto;
    flowNodes: string[];
    useWorktree: boolean;
    setUseWorktree: (value: boolean) => void;
    worktreeAvailable: boolean;
    submitting: boolean;
    canSubmit: boolean;
    error?: string;
    submit: () => Promise<void>;
  };
  modalOpen: boolean;
  onCloseModal: () => void;
};

export function EntryShellScreen({
  shell,
  columns,
  hasTasks,
  launchableEntries,
  onOpenModal,
  modal,
  modalOpen,
  onCloseModal,
}: EntryShellScreenProps) {
  const totalTasks = columns.reduce((sum, column) => sum + column.cards.length, 0);
  const shellSubtitle =
    shell.phase !== "connected"
      ? "Bootstrapping local task control plane."
      : !shell.workDir
        ? "Add a workspace to start."
        : totalTasks > 0
          ? `${shell.workspaceLabel} · ${totalTasks} tasks`
          : `${shell.workspaceLabel} · ready for a new task`;

  return (
    <>
      <DesktopShellFrame
        addWorkspaceDisabled={shell.phase !== "connected"}
        footerNav={shell.footerNav}
        primaryNav={shell.primaryNav}
        secondaryNav={shell.secondaryNav}
        sidebarStatusLabel={shell.connectionLabel}
        sidebarStatusTone={shell.connectionTone}
        workspaceItems={shell.workspaceItems}
        onAddWorkspace={() => void shell.addWorkspace()}
        topBarLeft={
          <div className="screen-heading screen-heading--shell">
            <h1 className="screen-title">All Tasks</h1>
            <div className="screen-heading__subline">
              <span className="screen-heading__support">{shellSubtitle}</span>
            </div>
          </div>
        }
        topBarRight={
          <button
            className="primary-action"
            data-testid="open-new-task"
            disabled={shell.phase !== "connected" || launchableEntries.length === 0}
            onClick={onOpenModal}
            type="button"
          >
            + New Task
          </button>
        }
      >
        <section className="board-screen" data-testid="entry-shell">
          {shell.error ? (
            <div className="inline-banner inline-banner--failed" data-testid="shell-error">
              {shell.error}
            </div>
          ) : null}

          {shell.phase !== "connected" ? (
            <div className="board-empty-state" data-testid="entry-empty-state">
              <h2>Connecting to app-server</h2>
              <p>Bootstrapping the local task control plane.</p>
            </div>
          ) : !shell.workDir ? (
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
              <p>Start the first task for this workspace. Config, runtime, and flow settings stay inside the launch modal.</p>
              <button className="primary-action" onClick={onOpenModal} type="button">
                New Task
              </button>
            </div>
          ) : (
            <TaskBoard columns={columns} />
          )}
        </section>
      </DesktopShellFrame>

      <NewTaskModal
        configDescription={modal.selectedEntry?.description}
        description={modal.description}
        entries={launchableEntries}
        error={modal.error}
        flowNodes={modal.flowNodes}
        onAliasChange={modal.setSelectedAlias}
        onClose={onCloseModal}
        onDescriptionChange={modal.setDescription}
        onSubmit={() => void modal.submit()}
        onToggleWorktree={modal.setUseWorktree}
        open={modalOpen}
        selectedAlias={modal.selectedAlias}
        submitting={modal.submitting}
        canSubmit={modal.canSubmit}
        useWorktree={modal.useWorktree}
        worktreeAvailable={modal.worktreeAvailable}
      />
    </>
  );
}
