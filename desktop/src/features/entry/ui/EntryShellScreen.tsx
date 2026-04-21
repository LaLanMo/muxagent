import { ArrowRight, Inbox, Plus } from "lucide-react";
import type { ShellChromeModel } from "@/features/app/model/use-shell-chrome";
import { Button } from "@/features/shared/ui/Button";
import type { ConfigCatalogEntryDto } from "@/rpc/types";
import type { WorkbenchTabId } from "@/domain/routes";
import { useWorkbenchTab } from "@/features/layout/ui/workbench-surface";
import type { TaskBoardColumnModel } from "@/features/tasks/ui/TaskBoard";
import { TaskBoard } from "@/features/tasks/ui/TaskBoard";

type EntryShellScreenProps = {
  shell: ShellChromeModel;
  columns: TaskBoardColumnModel[];
  hasTasks: boolean;
  launchableEntries: ConfigCatalogEntryDto[];
  boardTabId: WorkbenchTabId;
  boardTitle: string;
};

export function EntryShellScreen({
  shell,
  columns,
  hasTasks,
  boardTabId,
  boardTitle,
}: EntryShellScreenProps) {
  useWorkbenchTab({
    key: `entry-board:${boardTabId}`,
    tabId: boardTabId,
    title: boardTitle,
  });

  const showTaskListEmptyState =
    shell.phase === "connected" && shell.workspaceCount > 0 && !hasTasks;
  const emptyStateTitle = shell.allWorkspacesActive
    ? "No tasks yet"
    : `No tasks in ${shell.workspaceLabel}`;
  const emptyStateBody = shell.allWorkspacesActive
    ? "Create your first task to start a workflow."
    : "Try another status filter or switch back to All workspaces.";

  return (
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
          <Button
            data-testid="entry-reconnect-button"
            onClick={shell.reconnect}
            size="md"
            type="button"
            variant="primary"
          >
            Reconnect
          </Button>
        </div>
      ) : shell.workspaceCount === 0 ? (
        <div className="board-empty-state" data-testid="entry-empty-state">
          <h2>Add a workspace to start</h2>
          <p>Register a local workspace, then start or review tasks from the same shell.</p>
          <Button
            onClick={() => void shell.addWorkspace()}
            size="xl"
            trailingIcon={<ArrowRight strokeWidth={2} />}
            type="button"
            variant="primary"
          >
            Add workspace
          </Button>
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
            <h2>{emptyStateTitle}</h2>
            <p>{emptyStateBody}</p>
            <Button
              leadingIcon={<Plus strokeWidth={2.1} />}
              onClick={shell.openNewTask}
              size="lg"
              type="button"
              variant="primary"
            >
              New Task
            </Button>
          </div>
        </div>
      ) : (
        <TaskBoard columns={columns} />
      )}
    </section>
  );
}
