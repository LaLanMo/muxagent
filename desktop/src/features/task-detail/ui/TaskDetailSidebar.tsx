import { detailStatusLabel, formatRelativeTime } from "@/domain/task-shell";
import type { TaskDetailSelection } from "@/features/task-detail/model/use-task-detail-selection";
import { FileIcon, StatusIcon } from "@/features/task-detail/ui/NavigatorIcons";
import type { ArtifactRefDto, NodeRunViewDto } from "@/rpc/types";

type ActionKind =
  | "approval"
  | "clarification"
  | "retry"
  | "blocked"
  | "follow_up"
  | "none";

type TaskDetailSidebarProps = {
  loading: boolean;
  hasTask: boolean;
  currentNodeName?: string;
  timelineRuns: NodeRunViewDto[];
  artifacts: ArtifactRefDto[];
  selection: TaskDetailSelection;
  actionRunId?: string;
  actionKind?: ActionKind;
  onSelectOverview: () => void;
  onSelectRun: (runId: string) => void;
  onSelectArtifact: (artifact: ArtifactRefDto) => void;
};

function formatRunTime(run: NodeRunViewDto): string {
  const timestamp = run.completed_at ?? run.started_at;
  return timestamp ? timestamp.slice(11, 16) : "";
}

function artifactCountLabel(count: number): string {
  return `${count} ${count === 1 ? "artifact" : "artifacts"}`;
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

function navigatorMeta(args: {
  run: NodeRunViewDto;
  artifactCount: number;
  actionRunId?: string;
  actionKind?: ActionKind;
}) {
  const { run, artifactCount, actionRunId, actionKind } = args;
  const statusLabel = detailStatusLabel(run.status);

  if (actionRunId === run.id) {
    if (actionKind === "clarification") {
      return "awaiting · clarification needed";
    }
    if (actionKind === "approval") {
      return "awaiting · approval required";
    }
    if (actionKind === "blocked") {
      return "awaiting · waiting to continue";
    }
    if (actionKind === "retry") {
      return "failed · retry available";
    }
  }

  if (statusLabel === "running") {
    return `running · ${formatRelativeTime(run.started_at)}`;
  }

  if (statusLabel === "done" && artifactCount > 0) {
    return `done · ${artifactCountLabel(artifactCount)}`;
  }

  if (statusLabel === "awaiting") {
    return "awaiting";
  }

  if (statusLabel === "failed" && run.failure_reason) {
    return `failed · ${run.failure_reason}`;
  }

  if (artifactCount > 0) {
    return `${statusLabel} · ${artifactCountLabel(artifactCount)}`;
  }

  return statusLabel;
}

function ArtifactNavigatorRow({
  artifact,
  selected,
  onSelectArtifact,
}: {
  artifact: ArtifactRefDto;
  selected: boolean;
  onSelectArtifact: (artifact: ArtifactRefDto) => void;
}) {
  return (
    <button
      aria-label={`Open artifact ${artifact.preview_name}`}
      aria-pressed={selected}
      className={`detail-nav-artifact${selected ? " is-selected" : ""}`}
      key={artifact.resolved_path}
      onClick={() => onSelectArtifact(artifact)}
      type="button"
    >
      <FileIcon />
      <span className="detail-nav-artifact__name">{artifact.preview_name}</span>
    </button>
  );
}

function OverviewRow({
  selected,
  currentNodeName,
  onSelectOverview,
}: {
  selected: boolean;
  currentNodeName?: string;
  onSelectOverview: () => void;
}) {
  return (
    <button
      aria-pressed={selected}
      className={`detail-nav-row${selected ? " is-selected" : ""}`}
      data-testid="detail-overview-row"
      onClick={onSelectOverview}
      type="button"
    >
      <span className="detail-nav-row__title">Overview</span>
      <span className="detail-nav-row__description detail-nav-row__description--flush">
        {currentNodeName
          ? `Task summary · current node ${currentNodeName}`
          : "Task summary and task-level actions"}
      </span>
    </button>
  );
}

function RunNavigatorRow({
  run,
  selected,
  actionRunId,
  actionKind,
  artifacts,
  onSelectRun,
  onSelectArtifact,
  selectedArtifactPath,
}: {
  run: NodeRunViewDto;
  selected: boolean;
  actionRunId?: string;
  actionKind?: ActionKind;
  artifacts: ArtifactRefDto[];
  onSelectRun: (runId: string) => void;
  onSelectArtifact: (artifact: ArtifactRefDto) => void;
  selectedArtifactPath?: string;
}) {
  const statusLabel = detailStatusLabel(run.status);
  const runArtifacts = artifactsForRun(run, artifacts);
  const rowSelected = selected;
  const meta = navigatorMeta({
    run,
    artifactCount: runArtifacts.length,
    actionRunId,
    actionKind,
  });

  return (
    <div
      className={`detail-nav-row detail-nav-row--node${rowSelected ? " is-selected" : ""}`}
    >
      <button
        aria-label={`Open ${run.node_name} run`}
        aria-pressed={rowSelected}
        className="detail-nav-row__button"
        data-testid={`detail-run-${run.id}`}
        onClick={() => onSelectRun(run.id)}
        type="button"
      >
        <div className="detail-nav-row__top">
          <span className="detail-nav-row__title-group">
            <span
              aria-hidden="true"
              className={`detail-nav-row__status detail-nav-row__status--${statusLabel}`}
            >
              <StatusIcon status={statusLabel} />
            </span>
            <span className={`detail-nav-row__title${statusLabel === "pending" ? " detail-nav-row__title--pending" : ""}`}>{run.node_name}</span>
          </span>
          {formatRunTime(run) ? (
            <span className="detail-nav-row__time">{formatRunTime(run)}</span>
          ) : null}
        </div>
        {statusLabel !== "pending" && meta ? <span className="detail-nav-row__description">{meta}</span> : null}
      </button>

      {statusLabel !== "pending" && runArtifacts.length > 0 ? (
        <div className="detail-nav-row__artifacts">
          {runArtifacts.map((artifact) => (
            <ArtifactNavigatorRow
              artifact={artifact}
              key={artifact.resolved_path}
              onSelectArtifact={onSelectArtifact}
              selected={selectedArtifactPath === artifact.resolved_path}
            />
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
  actionKind = "none",
  onSelectOverview,
  onSelectRun,
  onSelectArtifact,
}: TaskDetailSidebarProps) {
  const selectedArtifactPath =
    selection.kind === "artifact" ? selection.artifactPath : undefined;
  const groupedArtifactPaths = new Set(
    timelineRuns.flatMap((run) =>
      artifactsForRun(run, artifacts).map((artifact) => artifact.resolved_path),
    ),
  );
  const ungroupedArtifacts = artifacts.filter(
    (artifact) => !groupedArtifactPaths.has(artifact.resolved_path),
  );

  return (
    <aside className="detail-navigator">
      <div className="detail-navigator__header">
        <div className="detail-navigator__header-copy">
          <span className="detail-navigator__eyebrow">Navigator</span>
          {currentNodeName ? (
            <strong className="detail-navigator__current">Current · {currentNodeName}</strong>
          ) : null}
        </div>
        <span className="detail-navigator__count">{timelineRuns.length}</span>
      </div>
      <div className="detail-navigator__divider" />
      <div className="detail-navigator__body">
        {loading && !hasTask ? <p className="muted-copy">Loading task…</p> : null}
        {hasTask ? (
          <>
            <OverviewRow
              currentNodeName={currentNodeName}
              onSelectOverview={onSelectOverview}
              selected={selection.kind === "overview"}
            />

            {timelineRuns.map((run) => (
              <RunNavigatorRow
                actionKind={actionKind}
                actionRunId={actionRunId}
                artifacts={artifacts}
                key={run.id}
                onSelectArtifact={onSelectArtifact}
                onSelectRun={onSelectRun}
                run={run}
                selected={selection.kind === "run" && selection.runId === run.id}
                selectedArtifactPath={selectedArtifactPath}
              />
            ))}

            {ungroupedArtifacts.length > 0 ? (
              <div className="detail-nav-ungrouped">
                <span className="detail-navigator__eyebrow">Other artifacts</span>
                <div className="detail-nav-row__artifacts detail-nav-row__artifacts--loose">
                  {ungroupedArtifacts.map((artifact) => (
                    <ArtifactNavigatorRow
                      artifact={artifact}
                      key={artifact.resolved_path}
                      onSelectArtifact={onSelectArtifact}
                      selected={selectedArtifactPath === artifact.resolved_path}
                    />
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
