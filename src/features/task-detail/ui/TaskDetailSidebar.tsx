import type { ArtifactRefDto, NodeRunViewDto } from "@/rpc/types";

type TaskDetailSidebarProps = {
  loading: boolean;
  hasTask: boolean;
  currentNodeName?: string;
  timelineRuns: NodeRunViewDto[];
  artifacts: ArtifactRefDto[];
  selectedArtifact?: ArtifactRefDto;
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

function TimelineRunRow({
  run,
  currentNodeName,
  onSelectArtifact,
  artifacts,
}: {
  run: NodeRunViewDto;
  currentNodeName?: string;
  onSelectArtifact: (artifact: ArtifactRefDto) => void;
  artifacts: ArtifactRefDto[];
}) {
  const statusLabel = timelineStatusLabel(run.status);
  const isActive = currentNodeName === run.node_name;

  return (
    <div
      className={`timeline-run timeline-run--${statusLabel}${isActive ? " is-active" : ""}`}
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
        {isActive ? <span className="timeline-run__current">current</span> : null}
        {run.failure_reason ? (
          <span className="timeline-run__reason">{run.failure_reason}</span>
        ) : null}
      </div>

      {run.artifact_paths?.length ? (
        <div className="timeline-run__chips">
          {run.artifact_paths.map((artifactPath) => {
            const artifact = artifacts.find(
              (entry) =>
                entry.raw_path === artifactPath || entry.preview_name === artifactPath,
            );
            return (
              <button
                className="artifact-chip"
                key={artifactPath}
                onClick={() => artifact && onSelectArtifact(artifact)}
                type="button"
              >
                {artifactPath}
              </button>
            );
          })}
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
  selectedArtifact,
  onSelectArtifact,
}: TaskDetailSidebarProps) {
  return (
    <aside className="timeline-pane">
      <div className="timeline-pane__group">
        <div className="timeline-pane__section-head">
          <span className="timeline-pane__eyebrow">Runs</span>
          <span className="timeline-pane__count">{timelineRuns.length}</span>
        </div>
        {loading && !hasTask ? <p className="muted-copy">Loading task…</p> : null}
        {hasTask ? (
          timelineRuns.map((run) => (
            <TimelineRunRow
              artifacts={artifacts}
              currentNodeName={currentNodeName}
              key={run.id}
              onSelectArtifact={onSelectArtifact}
              run={run}
            />
          ))
        ) : (
          <p className="muted-copy">Open a task from the board to inspect its runs.</p>
        )}
      </div>

      {artifacts.length > 0 ? (
        <div className="timeline-pane__group timeline-pane__group--artifacts">
          <div className="timeline-pane__section-head">
            <span className="timeline-pane__eyebrow">Artifacts</span>
            <span className="timeline-pane__count">{artifacts.length}</span>
          </div>
          <div className="timeline-artifact-list">
            {artifacts.map((artifact) => (
              <button
                className={`artifact-row${
                  selectedArtifact?.resolved_path === artifact.resolved_path
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
    </aside>
  );
}
