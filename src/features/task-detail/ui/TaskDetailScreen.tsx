import { useEffect, useRef, useState } from "react";
import type { ShellChromeModel } from "@/features/app/model/use-shell-chrome";
import { mergeStreamLines, summarizeRunHistory } from "@/application/tasks";
import { Link } from "react-router-dom";
import { formatRelativeTime } from "@/domain/task-shell";
import { DesktopShellFrame } from "@/features/layout/ui/DesktopShellFrame";
import { Toast } from "@/features/shared/ui/Toast";
import { DesktopWorkbenchFrame } from "@/features/layout/ui/DesktopWorkbenchFrame";
import { StatusBadge } from "@/features/shared/ui/StatusBadge";
import type { TaskDetailActionSurface } from "@/features/task-detail/model/use-task-detail-screen";
import type { TaskDetailSelection } from "@/features/task-detail/model/use-task-detail-selection";
import type { RunHistoryCacheEntry } from "@/state/task-snapshot-store";
import { TaskDetailSidebar } from "@/features/task-detail/ui/TaskDetailSidebar";
import {
  TaskApprovalDock,
  TaskArtifactPane,
  TaskBlockedDock,
  TaskClarificationDock,
  TaskFollowUpDock,
  TaskOverviewPane,
  TaskRetryDock,
  TaskRunPane,
} from "@/features/task-detail/ui/TaskDetailPanels";
import type {
  ArtifactRefDto,
  BlockedStepDto,
  ConfigCatalogEntryDto,
  InputRequestDto,
  NodeRunViewDto,
  TaskViewDto,
} from "@/rpc/types";

type StageNode = {
  name: string;
  status: "done" | "current" | "pending" | "failed";
};

function formatUpdatedStamp(iso: string | undefined) {
  if (!iso) {
    return "";
  }
  const value = formatRelativeTime(iso);
  if (!value || value === "now") {
    return "updated now";
  }
  return value.includes("ago") ? `updated ${value}` : `updated ${value} ago`;
}

function formatCount(count: number, singular: string, plural: string) {
  return `${count} ${count === 1 ? singular : plural}`;
}

type TaskDetailScreenProps = {
  shell: ShellChromeModel;
  task?: TaskViewDto;
  loading: boolean;
  detailError?: string;
  title: string;
  statusLabel: string;
  statusTone: "running" | "awaiting" | "done" | "failed" | "neutral";
  configLabel: string;
  elapsedLabel: string;
  stageNodes: StageNode[];
  timelineRuns: NodeRunViewDto[];
  artifacts: ArtifactRefDto[];
  selection: TaskDetailSelection;
  currentRun?: NodeRunViewDto;
  selectedRun?: NodeRunViewDto;
  selectedArtifact?: ArtifactRefDto;
  artifactContent?: string;
  artifactError?: string;
  liveOutput: string[];
  liveOutputRunId?: string;
  selectedRunHistory?: RunHistoryCacheEntry;
  actionSurface: TaskDetailActionSurface;
  inputRequest?: InputRequestDto;
  blockedStep?: BlockedStepDto;
  feedback: string;
  setFeedback: (value: string) => void;
  clarificationAnswers: Array<string | string[]>;
  setClarificationAnswer: (index: number, value: string | string[]) => void;
  submittingClarification: boolean;
  submittingDecision: boolean;
  followUpDescription: string;
  setFollowUpDescription: (value: string) => void;
  followUpConfigAlias?: string;
  setFollowUpConfigAlias: (alias: string) => void;
  configEntries: ConfigCatalogEntryDto[];
  submittingFollowUp: boolean;
  submittingRetry: boolean;
  submittingContinue: boolean;
  failureReason?: string;
  selectOverview: () => void;
  selectRun: (runId: string) => void;
  selectArtifact: (artifact: ArtifactRefDto) => void;
  submitApprove: () => Promise<void>;
  submitReject: () => Promise<void>;
  submitClarification: () => Promise<void>;
  submitFollowUp: () => Promise<void>;
  retryTask: (force?: boolean) => Promise<void>;
  continueBlockedTask: () => Promise<void>;
};

function StageStrip({ nodes }: { nodes: StageNode[] }) {
  if (nodes.length === 0) {
    return null;
  }

  return (
    <div className="stage-strip">
      <div className="stage-strip__list">
        {nodes.map((node) => (
          <div className={`stage-node stage-node--${node.status}`} key={node.name}>
            <span className="stage-node__icon" aria-hidden="true">
              {node.status === "done"
                ? "✓"
                : node.status === "current"
                  ? "•"
                  : node.status === "failed"
                    ? "×"
                    : "○"}
            </span>
            <span className="stage-node__name">{node.name}</span>
          </div>
        ))}
      </div>
    </div>
  );
}

export function TaskDetailScreen({
  shell,
  task,
  loading,
  detailError,
  title,
  statusLabel,
  statusTone,
  configLabel,
  elapsedLabel,
  stageNodes,
  timelineRuns,
  artifacts,
  selection,
  currentRun,
  selectedRun,
  selectedArtifact,
  artifactContent,
  artifactError,
  liveOutput,
  liveOutputRunId,
  selectedRunHistory,
  actionSurface,
  inputRequest,
  blockedStep,
  feedback,
  setFeedback,
  clarificationAnswers,
  setClarificationAnswer,
  submittingClarification,
  submittingDecision,
  followUpDescription,
  setFollowUpDescription,
  followUpConfigAlias,
  setFollowUpConfigAlias,
  configEntries,
  submittingFollowUp,
  submittingRetry,
  submittingContinue,
  failureReason,
  selectOverview,
  selectRun,
  selectArtifact,
  submitApprove,
  submitReject,
  submitClarification,
  submitFollowUp,
  retryTask,
  continueBlockedTask,
}: TaskDetailScreenProps) {
  const paneScrollRef = useRef<HTMLDivElement | null>(null);
  const [dockCollapsed, setDockCollapsed] = useState(false);
  const prevActionKind = useRef(actionSurface.kind);
  useEffect(() => {
    if (actionSurface.kind !== prevActionKind.current) {
      setDockCollapsed(false);
      prevActionKind.current = actionSurface.kind;
    }
  }, [actionSurface.kind]);
  const updatedStamp = formatUpdatedStamp(task?.task.updated_at ?? elapsedLabel);
  const runSummary = formatCount(timelineRuns.length, "run", "runs");
  const artifactSummary = formatCount(artifacts.length, "artifact", "artifacts");
  const actionRunId =
    actionSurface.kind !== "none" && "run" in actionSurface
      ? actionSurface.run?.id
      : undefined;
  const currentRunId = currentRun?.id;
  const selectedRunArtifactCount = selectedRun
    ? artifacts.filter(
        (artifact) =>
          artifact.node_run_id === selectedRun.id ||
          selectedRun.artifact_paths?.includes(artifact.raw_path) ||
          selectedRun.artifact_paths?.includes(artifact.preview_name),
      ).length
    : 0;
  const replayLines = summarizeRunHistory(selectedRunHistory?.result);
  const liveSelectedRunLines =
    selectedRun?.id && liveOutputRunId === selectedRun.id ? liveOutput : [];
  const selectedRunStreamLines =
    liveSelectedRunLines.length > 0
      ? mergeStreamLines(replayLines, liveSelectedRunLines)
      : replayLines;
  const selectedRunStreamSource =
    liveSelectedRunLines.length > 0
      ? "live"
      : selectedRunStreamLines.length > 0
        ? "replay"
        : selectedRunHistory?.loading
          ? "loading"
          : "none";
  const selectionKey =
    selection.kind === "run"
      ? `run:${selection.runId}`
      : selection.kind === "artifact"
        ? `artifact:${selection.artifactPath}`
        : "overview";

  useEffect(() => {
    const container = paneScrollRef.current;
    if (!container) {
      return;
    }
    container.scrollTop = 0;
  }, [selectionKey]);

  const mainPane =
    selection.kind === "artifact" ? (
      <TaskArtifactPane
        artifact={selectedArtifact}
        content={artifactContent}
        error={artifactError}
      />
    ) : selection.kind === "run" ? (
      <TaskRunPane
        artifactCount={selectedRunArtifactCount}
        isCurrentRun={selectedRun?.id === currentRunId}
        streamLines={selectedRunStreamLines}
        streamSource={selectedRunStreamSource}
        run={selectedRun}
        showEmptyOutput={Boolean(selectedRun)}
      />
    ) : (
      <TaskOverviewPane
        artifactCount={artifacts.length}
        runCount={timelineRuns.length}
        task={task}
      />
    );

  let actionPanel = null;
  if (actionSurface.kind === "approval") {
    actionPanel = (
      <TaskApprovalDock
        feedback={feedback}
        nodeName={actionSurface.run?.node_name ?? inputRequest?.node_name}
        setFeedback={setFeedback}
        submitApprove={submitApprove}
        submitReject={submitReject}
        submittingDecision={submittingDecision}
      />
    );
  } else if (actionSurface.kind === "clarification") {
      actionPanel = (
        <TaskClarificationDock
          answers={clarificationAnswers}
          nodeName={actionSurface.run?.node_name ?? inputRequest?.node_name}
          questions={inputRequest?.questions ?? []}
          requestKey={`${inputRequest?.task_id ?? "task"}:${inputRequest?.node_run_id ?? "run"}`}
          setAnswer={setClarificationAnswer}
          submitClarification={submitClarification}
          submittingClarification={submittingClarification}
        />
      );
  } else if (actionSurface.kind === "blocked") {
    actionPanel = (
      <TaskBlockedDock
        blockedStep={blockedStep}
        onContinue={continueBlockedTask}
        submittingContinue={submittingContinue}
      />
    );
  } else if (actionSurface.kind === "retry") {
    actionPanel = (
      <TaskRetryDock
        failureReason={failureReason}
        onRetry={retryTask}
        run={actionSurface.run}
        submittingRetry={submittingRetry}
      />
    );
  } else if (actionSurface.kind === "follow_up") {
    actionPanel = (
      <TaskFollowUpDock
        configEntries={configEntries}
        followUpConfigAlias={followUpConfigAlias ?? configLabel}
        followUpDescription={followUpDescription}
        onConfigChange={setFollowUpConfigAlias}
        onStartFollowUp={submitFollowUp}
        setFollowUpDescription={setFollowUpDescription}
        submittingFollowUp={submittingFollowUp}
      />
    );
  }

  return (
    <DesktopShellFrame
      addWorkspaceDisabled={shell.phase !== "connected"}
      footerNav={shell.footerNav}
      onPrimaryAction={shell.openNewTask}
      primaryActionDisabled={shell.phase !== "connected" || shell.workspaceCount === 0}
      primaryNav={shell.primaryNav}
      topBarClassName="desktop-shell__topbar--detail"
      workspaceItems={shell.workspaceItems}
      onAddWorkspace={() => void shell.addWorkspace()}
      topBarLeft={
        <div className="detail-topbar">
          <div className="detail-topbar__title-row">
            <Link
              aria-label="Back to tasks"
              className="detail-topbar__back"
              data-testid="task-detail-back"
              to="/"
            >
              <svg
                aria-hidden="true"
                fill="none"
                height="16"
                viewBox="0 0 16 16"
                width="16"
              >
                <path
                  d="M9.75 3.5 5.25 8l4.5 4.5"
                  stroke="currentColor"
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeWidth="1.4"
                />
              </svg>
            </Link>
            <h1 className="detail-topbar__title">{title}</h1>
          </div>

          <div className="detail-topbar__info-row">
            <div className="detail-topbar__chips">
              <StatusBadge label={statusLabel} tone={statusTone} />
              <span className="detail-topbar__config">{configLabel}</span>
            </div>
            <div className="detail-topbar__meta">
              <span className="detail-topbar__stat">{runSummary}</span>
              <span className="detail-topbar__stat">{artifactSummary}</span>
              {updatedStamp ? (
                <span className="detail-topbar__updated">{updatedStamp}</span>
              ) : null}
            </div>
          </div>

          {stageNodes.length > 0 ? (
            <div className="detail-topbar__flow-row">
              <span className="detail-topbar__eyebrow">Flow</span>
              <StageStrip nodes={stageNodes} />
            </div>
          ) : null}
        </div>
      }
    >
      <section className="detail-screen" data-testid="task-detail-screen">
        {detailError ? (
          <div className="toast-container">
            <Toast message={detailError} tone="error" onDismiss={() => {}} />
          </div>
        ) : null}

        <DesktopWorkbenchFrame
          className="desktop-workbench--detail"
          center={
            <TaskDetailSidebar
              actionKind={actionSurface.kind}
              actionRunId={actionRunId}
              artifacts={artifacts}
              currentNodeName={task?.current_node_name}
              hasTask={Boolean(task)}
              loading={loading}
              onSelectOverview={selectOverview}
              onSelectArtifact={selectArtifact}
              onSelectRun={selectRun}
              selection={selection}
              timelineRuns={timelineRuns}
            />
          }
          right={
            <div className="detail-pane-host">
              <div className="detail-pane-scroll" ref={paneScrollRef}>
                <div className="detail-pane-stack">
                  {mainPane}
                </div>
              </div>
              {actionPanel ? (
                <div
                  className={`detail-action-dock${dockCollapsed ? " is-collapsed" : ""}`}
                  onClick={(e) => {
                    const target = e.target as HTMLElement;
                    if (target.closest(".detail-surface-panel__header")) {
                      setDockCollapsed((c) => !c);
                    }
                  }}
                >
                  {actionPanel}
                </div>
              ) : null}
            </div>
          }
        />
      </section>
    </DesktopShellFrame>
  );
}
