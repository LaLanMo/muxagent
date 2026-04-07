import type { TaskDetailSelection } from "@/features/task-detail/model/use-task-detail-selection";
import type { ArtifactRefDto, NodeRunViewDto } from "@/rpc/types";

type TaskDetailSidebarProps = {
  loading: boolean;
  hasTask: boolean;
  currentNodeName?: string;
  timelineRuns: NodeRunViewDto[];
  artifacts: ArtifactRefDto[];
  selection: TaskDetailSelection;
  actionRunId?: string;
  onSelectOverview: () => void;
  onSelectRun: (runId: string) => void;
  onSelectArtifact: (artifact: ArtifactRefDto) => void;
};

function formatRunTime(run: NodeRunViewDto): string {
  const timestamp = run.completed_at ?? run.started_at;
  return timestamp ? timestamp.slice(11, 16) : "";
}

function timelineStatusLabel(status: string): string {
  const normalized = status.toLowerCase();
  if (normalized.includes("await")) {
    return "awaiting";
  }
  if (normalized.includes("run") || normalized.includes("start")) {
    return "running";
  }
  if (normalized.includes("fail") || normalized.includes("error")) {
    return "failed";
  }
  if (normalized.includes("done") || normalized.includes("success")) {
    return "done";
  }
  return normalized;
}

function artifactsForRun(
  run: NodeRunViewDto,
  artifacts: ArtifactRefDto[],
): ArtifactRefDto[] {
  return artifacts.filter((artifact) => {
    if (artifact.node_run_id && artifact.node_run_id === run.id) {
      return true;
    }
    return (
      run.artifact_paths?.includes(artifact.raw_path) ||
      run.artifact_paths?.includes(artifact.preview_name)
    );
  });
}

function RunNavigatorRow({
  run,
  currentNodeName,
  selected,
  actionRunId,
  artifacts,
  onSelectRun,
  onSelectArtifact,
  selectedArtifactPath,
}: {
  run: NodeRunViewDto;
  currentNodeName?: string;
  selected: boolean;
  actionRunId?: string;
  artifacts: ArtifactRefDto[];
  onSelectRun: (runId: string) => void;
  onSelectArtifact: (artifact: ArtifactRefDto) => void;
  selectedArtifactPath?: string;
}) {
  const statusLabel = timelineStatusLabel(run.status);
  const isCurrent = currentNodeName === run.node_name;
  const runArtifacts = artifactsForRun(run, artifacts);
  const isSelected =
    selected ||
    runArtifacts.some(
      (artifact) => artifact.resolved_path === selectedArtifactPath,
    );

  return (
    <div className="detail-nav-group">
      <button
        className={`timeline-run timeline-run--${statusLabel}${isSelected ? " is-selected" : ""}`}
        data-testid={`detail-run-${run.id}`}
        onClick={() => onSelectRun(run.id)}
        type="button"
      >
        <div className="timeline-run__header">
          <div className="timeline-run__title">
            <span className={`timeline-run__mark timeline-run__mark--${run.status.toLowerCase()}`}>
              {run.status.toLowerCase().includes("done")
                ? "✓"
                : run.status.toLowerCase().includes("fail")
                  ? "×"
                  : "•"}
            </span>
            <span>{run.node_name}</span>
          </div>
          <span className="timeline-run__time">{formatRunTime(run)}</span>
        </div>

        <div className="timeline-run__meta-row">
          <span className="timeline-run__status">{statusLabel}</span>
          {isCurrent ? <span className="timeline-run__current">current</span> : null}
          {actionRunId === run.id ? <span className="timeline-run__current">needs input</span> : null}
          {runArtifacts.length > 0 ? (
            <span className="timeline-run__status">
              {runArtifacts.length} {runArtifacts.length === 1 ? "artifact" : "artifacts"}
            </span>
          ) : null}
          {run.failure_reason ? (
            <span className="timeline-run__reason">{run.failure_reason}</span>
          ) : null}
        </div>
      </button>

      {runArtifacts.length > 0 ? (
        <div className="timeline-artifact-tree">
          {runArtifacts.map((artifact) => (
            <button
              className={`artifact-row artifact-row--nested${
                selectedArtifactPath === artifact.resolved_path ? " is-selected" : ""
              }`}
              key={artifact.resolved_path}
              onClick={() => onSelectArtifact(artifact)}
              type="button"
            >
              <span className="artifact-row__copy">
                <span className="artifact-row__name">{artifact.preview_name}</span>
                <span className="artifact-row__meta">{artifact.source_label}</span>
              </span>
            </button>
          ))}
        </div>
      ) : null}
    </div>
  );
}

export function TaskDetailSidebar({
  loading,
  hasTask,
  currentNodeName,
  timelineRuns,
  artifacts,
  selection,
  actionRunId,
  onSelectOverview,
  onSelectRun,
  onSelectArtifact,
}: TaskDetailSidebarProps) {
  const selectedArtifactPath =
    selection.kind === "artifact" ? selection.artifactPath : undefined;
  const ungroupedArtifacts = artifacts.filter(
    (artifact) =>
      artifact.node_run_id &&
      !timelineRuns.some((run) => run.id === artifact.node_run_id),
  );

  return (
    <aside className="timeline-pane">
      <div className="timeline-pane__group">
        <div className="timeline-pane__section-head">
          <span className="timeline-pane__eyebrow">Task detail</span>
          <span className="timeline-pane__count">{timelineRuns.length}</span>
        </div>
        {loading && !hasTask ? <p className="muted-copy">Loading task…</p> : null}
        {hasTask ? (
          <>
            <button
              className={`overview-row${
                selection.kind === "overview" ? " is-selected" : ""
              }`}
              data-testid="detail-overview-row"
              onClick={onSelectOverview}
              type="button"
            >
              <span className="overview-row__title">Overview</span>
              <span className="overview-row__meta">Task summary</span>
            </button>

            {timelineRuns.map((run) => (
              <RunNavigatorRow
                actionRunId={actionRunId}
                artifacts={artifacts}
                currentNodeName={currentNodeName}
                key={run.id}
                onSelectArtifact={onSelectArtifact}
                onSelectRun={onSelectRun}
                run={run}
                selected={selection.kind === "run" && selection.runId === run.id}
                selectedArtifactPath={selectedArtifactPath}
              />
            ))}

            {ungroupedArtifacts.length > 0 ? (
              <div className="timeline-pane__group timeline-pane__group--ungrouped">
                <div className="timeline-pane__section-head">
                  <span className="timeline-pane__eyebrow">Other artifacts</span>
                  <span className="timeline-pane__count">{ungroupedArtifacts.length}</span>
                </div>
                <div className="timeline-artifact-tree">
                  {ungroupedArtifacts.map((artifact) => (
                    <button
                      className={`artifact-row artifact-row--nested${
                        selectedArtifactPath === artifact.resolved_path
                          ? " is-selected"
                          : ""
                      }`}
                      key={artifact.resolved_path}
                      onClick={() => onSelectArtifact(artifact)}
                      type="button"
                    >
                      <span className="artifact-row__copy">
                        <span className="artifact-row__name">{artifact.preview_name}</span>
                        <span className="artifact-row__meta">{artifact.source_label}</span>
                      </span>
                    </button>
                  ))}
                </div>
              </div>
            ) : null}
          </>
        ) : (
          <p className="muted-copy">Open a task from the board to inspect its runs.</p>
        )}
      </div>
    </aside>
  );
}
