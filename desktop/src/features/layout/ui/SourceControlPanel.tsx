import {
  ChevronDown,
  ChevronRight,
  FolderGit2,
  GitBranch,
  Plus,
  RefreshCw,
  TriangleAlert,
} from "lucide-react";
import { useEffect, useMemo, useState } from "react";
import { Link, useLocation } from "react-router-dom";
import { useWorkspaceSelection } from "@/features/app/model/use-workspace-selection";
import {
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
} from "@/features/source-control/model/source-control-presenter";
import {
  useCheckoutDetail,
  useWorkspaceStatus,
} from "@/features/source-control/model/use-source-control-data";
import type { SourceControlTaskSummary } from "@/features/source-control/model/source-control-presenter";
import { tasksForWorkspace, useTaskSnapshotStore } from "@/state/task-snapshot-store";
import { useWorkspaceStore } from "@/state/workspace-store";
import type { GitCheckoutSummaryDto } from "@/rpc/types";

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

function checkoutTestIdSuffix(label: string): string {
  return label.replace(/[^a-z0-9]+/gi, "-").toLowerCase();
}

function SourceControlCheckoutSection({
  activeWorkspaceId,
  checkout,
  taskSummary,
  branchLabel,
  summaryLabel,
  isExpanded,
  isSelected,
  toggleExpanded,
  selectedFileId,
  selectedCommitHash,
}: {
  activeWorkspaceId: string;
  checkout: GitCheckoutSummaryDto;
  taskSummary: SourceControlTaskSummary;
  branchLabel: string;
  summaryLabel: string;
  isExpanded: boolean;
  isSelected: boolean;
  toggleExpanded: (checkoutPath: string) => void;
  selectedFileId?: string;
  selectedCommitHash?: string;
}) {
  const detail = useCheckoutDetail(
    activeWorkspaceId,
    isExpanded ? checkout.path : undefined,
  );
  const fileSections = useMemo(
    () => (detail.data ? buildFileSections(detail.data) : []),
    [detail.data],
  );
  const commitSection = useMemo(
    () => buildCommitSection(checkout, detail.data?.commits ?? []),
    [checkout, detail.data],
  );

  return (
    <div
      className={`source-control__checkout${isSelected ? " is-selected" : ""}`}
      data-selected={isSelected ? "true" : "false"}
      data-testid={`source-control-checkout-row-${checkoutTestIdSuffix(branchLabel)}`}
      key={checkout.path}
    >
      <button
        aria-expanded={isExpanded}
        aria-label={`${isExpanded ? "Collapse" : "Expand"} ${branchLabel}`}
        className="source-control__checkout-header"
        data-testid={`source-control-checkout-${checkoutTestIdSuffix(branchLabel)}`}
        onClick={() => toggleExpanded(checkout.path)}
        type="button"
      >
        <span className="source-control__checkout-copy">
          <span
            aria-hidden="true"
            className="source-control__checkout-chevron"
          >
            {isExpanded ? (
              <ChevronDown size={13} strokeWidth={2} />
            ) : (
              <ChevronRight size={13} strokeWidth={2} />
            )}
          </span>
          <GitBranch size={13} strokeWidth={1.8} />
          <span className="source-control__checkout-name">{branchLabel}</span>
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
      </button>

      {isExpanded ? (
        <div
          className="source-control__checkout-body"
          data-testid={`source-control-checkout-body-${checkoutTestIdSuffix(branchLabel)}`}
        >
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
              <div className="source-control__group" key={section.id}>
                <div className="source-control__group-label">
                  <span>{section.label.toUpperCase()}</span>
                  <span>{section.count}</span>
                </div>
                {section.rows.map((fileRow) => (
                  <Link
                    className={`source-control__file-row${
                      isSelected && selectedFileId === fileRow.id ? " is-selected" : ""
                    }`}
                    data-testid={`source-control-file-${fileRow.id}`}
                    key={fileRow.id}
                    to={buildFileDiffPath(
                      activeWorkspaceId,
                      checkout.path,
                      fileRow.id,
                    )}
                  >
                    <span className={fileToneClassName(fileRow.tone)}>
                      {fileRow.statusCode}
                    </span>
                    <span className="source-control__file-copy">
                      <span>{fileRow.path}</span>
                      {fileRow.origPath ? <span>{fileRow.origPath}</span> : null}
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
                      isSelected && selectedCommitHash === hash ? " is-selected" : ""
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
  const routeSelectedCheckoutPath = checkoutRoute?.checkoutPath;
  const fileDiffRoute = parseFileDiffPath(location.pathname);
  const commitDiffRoute = parseCommitDiffPath(location.pathname);
  const selectedFileId = fileDiffRoute?.fileId;
  const selectedCommitHash = commitDiffRoute?.commitHash;

  const status = useWorkspaceStatus(activeWorkspaceId);
  const statusData = status.data;
  const [expandedCheckoutPaths, setExpandedCheckoutPaths] = useState<string[]>([]);

  const checkouts = useMemo(() => {
    if (!statusData) return [];
    return [statusData.main, ...statusData.worktrees];
  }, [statusData]);

  const workspaceLabel = activeWorkspace?.display_name ?? "Select workspace";
  const primaryEmptyState = status.error
    ? status.error
    : status.loading && checkouts.length === 0
      ? "Loading source control…"
      : checkouts.length === 0
        ? "No git checkouts available."
        : undefined;

  useEffect(() => {
    const validCheckoutPaths = new Set(checkouts.map((checkout) => checkout.path));
    setExpandedCheckoutPaths((current) => {
      let next = current.filter((path) => validCheckoutPaths.has(path));

      if (
        routeSelectedCheckoutPath &&
        validCheckoutPaths.has(routeSelectedCheckoutPath) &&
        !next.includes(routeSelectedCheckoutPath)
      ) {
        next = [...next, routeSelectedCheckoutPath];
      }

      if (
        next.length === current.length &&
        next.every((path, index) => path === current[index])
      ) {
        return current;
      }
      return next;
    });
  }, [checkouts, routeSelectedCheckoutPath]);

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
              const isSelected = checkout.path === routeSelectedCheckoutPath;
              const isExpanded = expandedCheckoutPaths.includes(checkout.path);
              const branchLabel =
                checkout.branch ||
                checkout.path.split(/[\\/]/).at(-1) ||
                checkout.path;
              const summaryLabel = buildCheckoutSummaryLabel(checkout);

              return (
                <SourceControlCheckoutSection
                  activeWorkspaceId={activeWorkspaceId}
                  branchLabel={branchLabel}
                  key={checkout.path}
                  checkout={checkout}
                  isExpanded={isExpanded}
                  isSelected={isSelected}
                  selectedCommitHash={selectedCommitHash}
                  selectedFileId={selectedFileId}
                  summaryLabel={summaryLabel}
                  taskSummary={taskSummary}
                  toggleExpanded={(checkoutPath) => {
                    setExpandedCheckoutPaths((current) =>
                      current.includes(checkoutPath)
                        ? current.filter((path) => path !== checkoutPath)
                        : [...current, checkoutPath],
                    );
                  }}
                />
              );
            })
          : null}
      </div>
    </div>
  );
}
