import { useMemo } from "react";
import { GitBranch } from "lucide-react";
import { Link, useParams } from "react-router-dom";
import {
  buildFileDiffPath,
  buildCommitDiffPath,
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
import {
  tasksForWorkspace,
  useTaskSnapshotStore,
} from "@/state/task-snapshot-store";

function decode(param: string | undefined): string | undefined {
  if (!param) return undefined;
  try {
    return decodeURIComponent(param);
  } catch {
    return param;
  }
}

export function WorktreeOverview() {
  const params = useParams<{ workspaceId: string; checkoutPath: string }>();
  const workspaceId = decode(params.workspaceId);
  const checkoutPath = decode(params.checkoutPath);

  const status = useWorkspaceStatus(workspaceId);
  const detail = useCheckoutDetail(workspaceId, checkoutPath);

  const tasksById = useTaskSnapshotStore((state) => state.tasksById);
  const taskIdsByWorkspaceId = useTaskSnapshotStore(
    (state) => state.taskIdsByWorkspaceId,
  );
  const workspaceTasks = workspaceId
    ? tasksForWorkspace(taskIdsByWorkspaceId, tasksById, workspaceId)
    : [];

  const summary = useMemo(() => {
    if (!status.data || !checkoutPath) return undefined;
    const all = [status.data.main, ...status.data.worktrees];
    return all.find((entry) => entry.path === checkoutPath);
  }, [checkoutPath, status.data]);

  const taskSummary = useMemo(
    () =>
      workspaceId && checkoutPath
        ? buildTaskSummaryForCheckout(workspaceId, checkoutPath, workspaceTasks)
        : undefined,
    [checkoutPath, workspaceId, workspaceTasks],
  );

  const fileSections = useMemo(
    () => (detail.data ? buildFileSections(detail.data) : []),
    [detail.data],
  );

  const commitSection = useMemo(
    () =>
      summary ? buildCommitSection(summary, detail.data?.commits ?? []) : undefined,
    [detail.data, summary],
  );

  if (status.loading && !summary) {
    return (
      <section className="worktree-overview" data-testid="worktree-overview-loading">
        <div className="worktree-overview__loading">Loading worktree…</div>
      </section>
    );
  }

  if (!summary) {
    return (
      <section className="worktree-overview" data-testid="worktree-overview-missing">
        <div className="worktree-overview__missing">
          Worktree not found. Pick one from the panel.
        </div>
      </section>
    );
  }

  return (
    <section className="worktree-overview" data-testid="worktree-overview">
      <header className="worktree-overview__header">
        <div className="worktree-overview__branch">
          <GitBranch size={18} strokeWidth={1.8} />
          <div className="worktree-overview__title-group">
            <h1 className="worktree-overview__title">
              {summary.branch ?? summary.path.split(/[\\/]/).at(-1) ?? summary.path}
            </h1>
            <p className="worktree-overview__subtitle">{summary.path}</p>
          </div>
        </div>
        <div className="worktree-overview__status">
          <span className="worktree-overview__chip">
            {buildCheckoutSummaryLabel(summary)}
          </span>
          <span className="worktree-overview__chip worktree-overview__chip--muted">
            {summary.role}
          </span>
          {summary.ahead_count > 0 ? (
            <span className="worktree-overview__chip">
              ahead {summary.ahead_count}
            </span>
          ) : null}
          {summary.behind_count > 0 ? (
            <span className="worktree-overview__chip">
              behind {summary.behind_count}
            </span>
          ) : null}
        </div>
      </header>

      <div className="worktree-overview__grid">
        <article className="worktree-overview__card">
          <h2>Changes</h2>
          {fileSections.length === 0 || fileSections.every((section) => section.count === 0) ? (
            <p className="worktree-overview__muted">No pending changes.</p>
          ) : (
            fileSections.map((section) =>
              section.count > 0 ? (
                <div className="worktree-overview__section" key={section.id}>
                  <h3>
                    {section.label}
                    <span>{section.count}</span>
                  </h3>
                  <ul>
                    {section.rows.slice(0, 12).map((row) => (
                      <li key={row.id}>
                        <Link
                          className="worktree-overview__file-link"
                          data-testid={`worktree-overview-file-${row.id}`}
                          to={buildFileDiffPath(
                            workspaceId ?? "",
                            checkoutPath ?? "",
                            row.id,
                          )}
                        >
                          <span className="worktree-overview__code">
                            {row.statusCode}
                          </span>
                          <span>{row.path}</span>
                        </Link>
                      </li>
                    ))}
                  </ul>
                </div>
              ) : null,
            )
          )}
        </article>

        <article className="worktree-overview__card">
          <h2>Tasks</h2>
          {taskSummary && taskSummary.total > 0 ? (
            <ul>
              {taskSummary.rows.map((row) => (
                <li key={row.id}>
                  <Link
                    className="worktree-overview__task-link"
                    data-testid={`worktree-overview-task-${row.id}`}
                    to={row.href}
                  >
                    <span
                      className={`worktree-overview__dot worktree-overview__dot--${row.tone}`}
                    />
                    <span>{row.title}</span>
                  </Link>
                </li>
              ))}
            </ul>
          ) : (
            <p className="worktree-overview__muted">No tasks on this worktree.</p>
          )}
        </article>

        <article className="worktree-overview__card">
          <h2>Recent commits</h2>
          {commitSection ? (
            <ul>
              {commitSection.rows.map((commit) => (
                <li key={commit.id}>
                  <Link
                    className="worktree-overview__commit-link"
                    data-testid={`worktree-overview-commit-${commit.shortHash}`}
                    to={buildCommitDiffPath(
                      workspaceId ?? "",
                      checkoutPath ?? "",
                      commit.shortHash,
                    )}
                  >
                    <span className="worktree-overview__code">
                      {commit.shortHash}
                    </span>
                    <span>{commit.subject}</span>
                  </Link>
                </li>
              ))}
            </ul>
          ) : (
            <p className="worktree-overview__muted">No commit history available.</p>
          )}
        </article>
      </div>
    </section>
  );
}
