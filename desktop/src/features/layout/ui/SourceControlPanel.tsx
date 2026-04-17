import {
  ChevronDown,
  FolderGit2,
  GitBranch,
  Plus,
  RefreshCw,
  TriangleAlert,
} from "lucide-react";
import { useMemo, useState } from "react";
import { Link, useLocation } from "react-router-dom";
import { useWorkspaceSelection } from "@/features/app/model/use-workspace-selection";
import {
  buildCheckoutPath,
  buildCommitDiffPath,
  buildFileDiffPath,
  parseCheckoutPath,
  parseCommitDiffPath,
  parseFileDiffPath,
} from "@/domain/routes";
import {
  buildCheckoutSummaryLabel,
  buildCommitSection,
  buildFileSections,
  buildTaskSummaryForCheckout,
  pickPreferredCheckoutPath,
} from "@/features/source-control/model/source-control-presenter";
import {
  useCheckoutDetail,
  useWorkspaceStatus,
} from "@/features/source-control/model/use-source-control-data";
import { tasksForWorkspace, useTaskSnapshotStore } from "@/state/task-snapshot-store";
import { useWorkspaceStore } from "@/state/workspace-store";

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

export function SourceControlPanel() {
  const location = useLocation();
  const workspaces = useWorkspaceStore((state) => state.workspaces);
  const selectedWorkspaceId = useWorkspaceStore(
    (state) => state.selectedWorkspaceId,
  );
  const activeWorkspace =
    workspaces.find(
      (workspace) => workspace.workspace_id === selectedWorkspaceId,
    ) ?? workspaces[0];
  const activeWorkspaceId = activeWorkspace?.workspace_id;
  const tasksById = useTaskSnapshotStore((state) => state.tasksById);
  const taskIdsByWorkspaceId = useTaskSnapshotStore(
    (state) => state.taskIdsByWorkspaceId,
  );
  const workspaceTasks = activeWorkspaceId
    ? tasksForWorkspace(taskIdsByWorkspaceId, tasksById, activeWorkspaceId)
    : [];

  const [workspacePickerOpen, setWorkspacePickerOpen] = useState(false);
  const { selectWorkspaceById } = useWorkspaceSelection();

  const checkoutRoute =
    parseCheckoutPath(location.pathname) ??
    parseFileDiffPath(location.pathname) ??
    parseCommitDiffPath(location.pathname);
  const selectedCheckoutPath = checkoutRoute?.checkoutPath;
  const fileDiffRoute = parseFileDiffPath(location.pathname);
  const commitDiffRoute = parseCommitDiffPath(location.pathname);
  const selectedFileId = fileDiffRoute?.fileId;
  const selectedCommitHash = commitDiffRoute?.commitHash;

  const status = useWorkspaceStatus(activeWorkspaceId);
  const statusData = status.data;

  const checkouts = useMemo(() => {
    if (!statusData) return [];
    return [statusData.main, ...statusData.worktrees];
  }, [statusData]);

  const resolvedSelectedPath = useMemo(() => {
    if (
      selectedCheckoutPath &&
      checkouts.some((checkout) => checkout.path === selectedCheckoutPath)
    ) {
      return selectedCheckoutPath;
    }
    if (statusData) {
      return pickPreferredCheckoutPath(statusData.main, statusData.worktrees);
    }
    return undefined;
  }, [checkouts, selectedCheckoutPath, statusData]);

  const detail = useCheckoutDetail(activeWorkspaceId, resolvedSelectedPath);

  const selectedCheckoutSummary = useMemo(
    () => checkouts.find((checkout) => checkout.path === resolvedSelectedPath),
    [checkouts, resolvedSelectedPath],
  );

  const fileSections = useMemo(
    () => (detail.data ? buildFileSections(detail.data) : []),
    [detail.data],
  );

  const commitSection = useMemo(
    () =>
      selectedCheckoutSummary
        ? buildCommitSection(selectedCheckoutSummary, detail.data?.commits ?? [])
        : undefined,
    [detail.data, selectedCheckoutSummary],
  );

  const workspaceLabel = activeWorkspace?.display_name ?? "Select workspace";
  const primaryEmptyState = status.error
    ? status.error
    : status.loading && checkouts.length === 0
      ? "Loading source control…"
      : checkouts.length === 0
        ? "No git checkouts available."
        : undefined;

  function onSelectWorkspace(workspaceId: string) {
    setWorkspacePickerOpen(false);
    if (!workspaceId || workspaceId === activeWorkspaceId) return;
    void selectWorkspaceById(workspaceId);
  }

  return (
    <div className="source-control__panel" data-testid="source-control-panel">
      <header className="source-control__workspace-bar">
        <div className="source-control__workspace-picker-wrap">
          <button
            className="source-control__workspace-picker"
            data-testid="source-control-workspace-picker"
            onClick={() => setWorkspacePickerOpen((open) => !open)}
            type="button"
          >
            <span className="source-control__workspace-picker-copy">
              <FolderGit2 size={14} strokeWidth={1.9} />
              <span>{workspaceLabel}</span>
              <ChevronDown size={14} strokeWidth={1.9} />
            </span>
          </button>
          {workspacePickerOpen ? (
            <div
              className="source-control__workspace-menu"
              data-testid="source-control-workspace-menu"
            >
              {workspaces.map((workspace) => (
                <button
                  className={`source-control__workspace-option${
                    workspace.display_name === workspaceLabel
                      ? " is-active"
                      : ""
                  }`}
                  key={workspace.workspace_id}
                  onClick={() => onSelectWorkspace(workspace.workspace_id)}
                  type="button"
                >
                  <span>{workspace.display_name}</span>
                  <span>
                    {workspace.display_name === workspaceLabel
                      ? "active"
                      : "switch"}
                  </span>
                </button>
              ))}
            </div>
          ) : null}
        </div>
        <button
          aria-label="Refresh source control"
          className="source-control__icon-button"
          data-testid="source-control-refresh"
          onClick={() => status.reload()}
          type="button"
        >
          <RefreshCw
            className={status.loading ? "is-spinning" : undefined}
            size={14}
            strokeWidth={1.9}
          />
        </button>
      </header>

      <div className="source-control__section-label">
        <span>WORKTREES</span>
        <Plus size={14} strokeWidth={1.9} />
      </div>

      <div
        className="source-control__checkout-list"
        data-testid="source-control-checkout-list"
      >
        {primaryEmptyState ? (
          <div
            className={`source-control__message${status.error ? " source-control__message--error" : ""}`}
          >
            {primaryEmptyState}
          </div>
        ) : null}

        {activeWorkspaceId
          ? checkouts.map((checkout) => {
              const taskSummary = buildTaskSummaryForCheckout(
                activeWorkspaceId,
                checkout.path,
                workspaceTasks,
              );
              const isSelected = checkout.path === resolvedSelectedPath;
              const branchLabel =
                checkout.branch ||
                checkout.path.split(/[\\/]/).at(-1) ||
                checkout.path;
              const summaryLabel = buildCheckoutSummaryLabel(checkout);

              return (
                <div
                  className={`source-control__checkout${
                    isSelected ? " is-selected" : ""
                  }`}
                  key={checkout.path}
                >
                  <Link
                    className="source-control__checkout-header"
                    data-testid={`source-control-checkout-${branchLabel
                      .replace(/[^a-z0-9]+/gi, "-")
                      .toLowerCase()}`}
                    to={buildCheckoutPath(activeWorkspaceId, checkout.path)}
                  >
                    <span className="source-control__checkout-copy">
                      <span className="source-control__checkout-chevron">
                        {isSelected ? "▾" : "▸"}
                      </span>
                      <GitBranch size={13} strokeWidth={1.8} />
                      <span className="source-control__checkout-name">
                        {branchLabel}
                      </span>
                    </span>
                    <span className="source-control__checkout-summary">
                      <span>{summaryLabel}</span>
                      {taskSummary.runningCount > 0 ? (
                        <span className="source-control__checkout-meta">
                          <span className="source-control__dot source-control__dot--running" />
                          <span>{taskSummary.runningCount}</span>
                        </span>
                      ) : null}
                      {taskSummary.attentionCount > 0 ? (
                        <span className="source-control__checkout-meta">
                          <span className="source-control__dot source-control__dot--awaiting" />
                          <span>{taskSummary.attentionCount}</span>
                        </span>
                      ) : null}
                      {checkout.role === "external" &&
                      taskSummary.total === 0 &&
                      checkout.reachable ? (
                        <span className="source-control__checkout-meta source-control__checkout-meta--muted">
                          <TriangleAlert size={11} strokeWidth={1.8} />
                          <span>orphan</span>
                        </span>
                      ) : null}
                    </span>
                  </Link>

                  {isSelected ? (
                    <div className="source-control__checkout-body">
                      {taskSummary.total > 0 ? (
                        <div className="source-control__group">
                          <div className="source-control__group-label">
                            <span>TASKS</span>
                            <span>{taskSummary.total}</span>
                          </div>
                          {taskSummary.rows.map((task) => (
                            <Link
                              className="source-control__task-row"
                              data-testid={`source-control-task-${task.id}`}
                              key={task.id}
                              to={task.href}
                            >
                              <span className={taskToneClassName(task.tone)} />
                              <span>{task.title}</span>
                            </Link>
                          ))}
                        </div>
                      ) : null}

                      {detail.loading ? (
                        <div className="source-control__subtle-copy">
                          Loading checkout detail…
                        </div>
                      ) : null}
                      {detail.error ? (
                        <div className="source-control__subtle-copy source-control__subtle-copy--error">
                          {detail.error}
                        </div>
                      ) : null}

                      {fileSections.map((section) =>
                        section.count > 0 ? (
                          <div
                            className="source-control__group"
                            key={section.id}
                          >
                            <div className="source-control__group-label">
                              <span>{section.label.toUpperCase()}</span>
                              <span>{section.count}</span>
                            </div>
                            {section.rows.map((fileRow) => (
                              <Link
                                className={`source-control__file-row${
                                  selectedFileId === fileRow.id
                                    ? " is-selected"
                                    : ""
                                }`}
                                data-testid={`source-control-file-${fileRow.id}`}
                                key={fileRow.id}
                                to={buildFileDiffPath(
                                  activeWorkspaceId,
                                  checkout.path,
                                  fileRow.id,
                                )}
                              >
                                <span
                                  className={fileToneClassName(fileRow.tone)}
                                >
                                  {fileRow.statusCode}
                                </span>
                                <span className="source-control__file-copy">
                                  <span>{fileRow.path}</span>
                                  {fileRow.origPath ? (
                                    <span>{fileRow.origPath}</span>
                                  ) : null}
                                </span>
                              </Link>
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
                          {commitSection.rows.map((commit) => {
                            const hash = commit.shortHash;
                            return (
                              <Link
                                className={`source-control__commit-row${
                                  selectedCommitHash === hash
                                    ? " is-selected"
                                    : ""
                                }`}
                                data-testid={`source-control-commit-${hash}`}
                                key={commit.id}
                                to={buildCommitDiffPath(
                                  activeWorkspaceId,
                                  checkout.path,
                                  hash,
                                )}
                              >
                                <span>{commit.shortHash}</span>
                                <span>{commit.subject}</span>
                              </Link>
                            );
                          })}
                        </div>
                      ) : null}
                    </div>
                  ) : null}
                </div>
              );
            })
          : null}
      </div>
    </div>
  );
}
