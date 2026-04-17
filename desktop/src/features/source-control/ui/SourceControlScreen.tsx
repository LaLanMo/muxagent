import {
  FileDiff,
  FolderGit2,
  GitBranch,
  ListTodo,
  Plus,
  RefreshCw,
  Settings,
  SlidersHorizontal,
  TriangleAlert,
} from "lucide-react";
import { NavLink } from "react-router-dom";
import type { SourceControlScreenModel } from "@/features/source-control/model/use-source-control-screen";

function activityButtonClassName(active: boolean): string {
  return active
    ? "source-control__activity-link is-active"
    : "source-control__activity-link";
}

function taskToneClassName(tone: string): string {
  switch (tone) {
    case "awaiting":
      return "source-control__dot source-control__dot--awaiting";
    case "failed":
      return "source-control__dot source-control__dot--failed";
    case "done":
      return "source-control__dot source-control__dot--done";
    case "running":
    default:
      return "source-control__dot source-control__dot--running";
  }
}

function fileToneClassName(tone: string): string {
  switch (tone) {
    case "success":
      return "source-control__status source-control__status--success";
    case "danger":
      return "source-control__status source-control__status--danger";
    case "warning":
    default:
      return "source-control__status source-control__status--warning";
  }
}

export function SourceControlScreen({
  workspaceLabel,
  workspacePath,
  workspaceOptions,
  workspacePickerOpen,
  setWorkspacePickerOpen,
  onSelectWorkspace,
  onRefresh,
  loading,
  error,
  checkoutItems,
  onSelectCheckout,
  selectedCheckoutDetail,
  selectedCheckoutLoading,
  selectedCheckoutError,
  fileSections,
  selectedFileId,
  onSelectFile,
  selectedFile,
  commitSection,
}: SourceControlScreenModel) {
  const primaryEmptyState = error
    ? error
    : loading && checkoutItems.length === 0
      ? "Loading source control…"
      : checkoutItems.length === 0
        ? "No git checkouts available."
        : undefined;

  return (
    <main className="source-control-screen" data-testid="source-control-screen">
      <div className="source-control-screen__window">
        <aside className="source-control__activity-bar">
          <div className="source-control__activity-top">
            <div className="source-control__traffic-lights" aria-hidden="true">
              <span className="source-control__traffic-light is-red" />
              <span className="source-control__traffic-light is-yellow" />
              <span className="source-control__traffic-light is-green" />
            </div>

            <nav className="source-control__activity-nav" aria-label="Primary">
              <NavLink
                className={({ isActive }) => activityButtonClassName(isActive)}
                to="/"
              >
                <ListTodo size={16} strokeWidth={1.9} />
              </NavLink>
              <NavLink
                className={({ isActive }) => activityButtonClassName(isActive)}
                to="/source-control"
              >
                <GitBranch size={16} strokeWidth={1.9} />
              </NavLink>
              <NavLink
                className={({ isActive }) => activityButtonClassName(isActive)}
                to="/configs"
              >
                <SlidersHorizontal size={16} strokeWidth={1.9} />
              </NavLink>
            </nav>
          </div>

          <NavLink
            aria-label="Settings"
            className={({ isActive }) => activityButtonClassName(isActive)}
            to="/settings"
          >
            <Settings size={16} strokeWidth={1.9} />
          </NavLink>
        </aside>

        <section className="source-control__panel">
          <header className="source-control__workspace-bar">
            <div className="source-control__workspace-picker-wrap">
              <button
                className="source-control__workspace-picker"
                data-testid="source-control-workspace-picker"
                disabled={workspaceOptions.length === 0}
                onClick={() => setWorkspacePickerOpen(!workspacePickerOpen)}
                type="button"
              >
                <span className="source-control__workspace-picker-copy">
                  <FolderGit2 size={14} strokeWidth={1.9} />
                  <span>{workspaceLabel}</span>
                  <span>⌄</span>
                </span>
              </button>
              {workspacePickerOpen ? (
                <div className="source-control__workspace-menu" data-testid="source-control-workspace-menu">
                  {workspaceOptions.map((workspace) => (
                    <button
                      className="source-control__workspace-option"
                      key={workspace.id}
                      onClick={() => onSelectWorkspace(workspace.id)}
                      type="button"
                    >
                      <span>{workspace.label}</span>
                    </button>
                  ))}
                </div>
              ) : null}
            </div>

            <button
              aria-label="Refresh source control"
              className="source-control__icon-button"
              data-testid="source-control-refresh"
              onClick={onRefresh}
              type="button"
            >
              <RefreshCw size={14} strokeWidth={1.9} />
            </button>
          </header>

          <div className="source-control__section-label">
            <span>WORKTREES</span>
            <Plus size={14} strokeWidth={1.9} />
          </div>

          <div className="source-control__checkout-list" data-testid="source-control-checkout-list">
            {primaryEmptyState ? (
              <div
                className={`source-control__message${error ? " source-control__message--error" : ""}`}
              >
                {primaryEmptyState}
              </div>
            ) : null}

            {checkoutItems.map((entry) => (
              <div
                className={`source-control__checkout${entry.selected ? " is-selected" : ""}`}
                key={entry.path}
              >
                <button
                  className="source-control__checkout-header"
                  data-testid={`source-control-checkout-${entry.label}`}
                  onClick={() => onSelectCheckout(entry.path)}
                  type="button"
                >
                  <span className="source-control__checkout-copy">
                    <span className="source-control__checkout-chevron">
                      {entry.expanded ? "▾" : "▸"}
                    </span>
                    <GitBranch size={13} strokeWidth={1.8} />
                    <span className="source-control__checkout-name">{entry.label}</span>
                  </span>
                  <span className="source-control__checkout-summary">
                    <span>{entry.summary}</span>
                    {entry.taskSummary.runningCount > 0 ? (
                      <span className="source-control__checkout-meta">
                        <span className="source-control__dot source-control__dot--running" />
                        <span>{entry.taskSummary.runningCount}</span>
                      </span>
                    ) : null}
                    {entry.taskSummary.attentionCount > 0 ? (
                      <span className="source-control__checkout-meta">
                        <span className="source-control__dot source-control__dot--awaiting" />
                        <span>{entry.taskSummary.attentionCount}</span>
                      </span>
                    ) : null}
                    {entry.role === "external" && entry.taskSummary.total === 0 ? (
                      <span className="source-control__checkout-meta source-control__checkout-meta--muted">
                        <TriangleAlert size={11} strokeWidth={1.8} />
                        <span>orphan</span>
                      </span>
                    ) : null}
                  </span>
                </button>

                {entry.expanded ? (
                  <div className="source-control__checkout-body">
                    {entry.taskSummary.total > 0 ? (
                      <div className="source-control__group">
                        <div className="source-control__group-label">
                          <span>TASKS</span>
                          <span>{entry.taskSummary.total}</span>
                        </div>
                        {entry.taskSummary.rows.map((task) => (
                          <NavLink className="source-control__task-row" key={task.id} to={task.href}>
                            <span className={taskToneClassName(task.tone)} />
                            <span>{task.title}</span>
                          </NavLink>
                        ))}
                      </div>
                    ) : null}

                    {selectedCheckoutLoading && !selectedCheckoutDetail ? (
                      <div className="source-control__subtle-copy">Loading checkout detail…</div>
                    ) : null}
                    {selectedCheckoutError ? (
                      <div className="source-control__subtle-copy source-control__subtle-copy--error">
                        {selectedCheckoutError}
                      </div>
                    ) : null}

                    {fileSections.map((section) =>
                      section.count > 0 ? (
                        <div className="source-control__group" key={section.id}>
                          <div className="source-control__group-label">
                            <span>{section.label.toUpperCase()}</span>
                            <span>{section.count}</span>
                          </div>
                          {section.rows.map((file) => (
                            <button
                              className={`source-control__file-row${
                                selectedFileId === file.id ? " is-selected" : ""
                              }`}
                              key={file.id}
                              onClick={() => onSelectFile(file.id)}
                              type="button"
                            >
                              <span className={fileToneClassName(file.tone)}>{file.statusCode}</span>
                              <span className="source-control__file-copy">
                                <span>{file.path}</span>
                                {file.origPath ? <span>from {file.origPath}</span> : null}
                              </span>
                            </button>
                          ))}
                        </div>
                      ) : null,
                    )}

                    {commitSection ? (
                      <div className="source-control__group">
                        <div className="source-control__group-label">
                          <span>COMMITS</span>
                          <span>{commitSection.label}</span>
                        </div>
                        {commitSection.rows.map((commit) => (
                          <div className="source-control__commit-row" key={commit.id}>
                            <span>{commit.shortHash}</span>
                            <span>{commit.subject}</span>
                          </div>
                        ))}
                      </div>
                    ) : null}
                  </div>
                ) : null}
              </div>
            ))}
          </div>

        </section>

        <section className="source-control__main-pane" data-testid="source-control-main-pane">
          {selectedFile ? (
            <div className="source-control__file-detail">
              <div className="source-control__file-detail-icon">
                <FileDiff size={22} strokeWidth={1.8} />
              </div>
              <div className="source-control__file-detail-copy">
                <h2>{selectedFile.path}</h2>
                <p>{workspacePath ?? "Detached HEAD"}</p>
                <div className="source-control__file-detail-meta">
                  <span>{selectedFile.bucket}</span>
                  <span>{selectedFile.statusCode}</span>
                  {selectedFile.origPath ? <span>{selectedFile.origPath}</span> : null}
                </div>
              </div>
            </div>
          ) : (
            <div className="source-control__empty-state">
              <div className="source-control__empty-icon">
                <FileDiff size={22} strokeWidth={1.8} />
              </div>
              <p>Select a change to view diff</p>
              <span>or pick a worktree from the panel to manage</span>
            </div>
          )}
        </section>
      </div>
    </main>
  );
}
