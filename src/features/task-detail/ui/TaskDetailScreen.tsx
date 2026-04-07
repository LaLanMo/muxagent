import type { ShellChromeModel } from "@/features/app/model/use-shell-chrome";
import { DesktopShellFrame } from "@/features/layout/ui/DesktopShellFrame";
import { DesktopWorkbenchFrame } from "@/features/layout/ui/DesktopWorkbenchFrame";
import { StatusBadge } from "@/features/shared/ui/StatusBadge";
import type { TaskDetailActionSurface } from "@/features/task-detail/model/use-task-detail-screen";
import type { TaskDetailSelection } from "@/features/task-detail/model/use-task-detail-selection";
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
  InputRequestDto,
  NodeRunViewDto,
  TaskViewDto,
} from "@/rpc/types";

type StageNode = {
  name: string;
  status: "done" | "current" | "pending" | "failed";
};

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
  selectedRun?: NodeRunViewDto;
  selectedArtifact?: ArtifactRefDto;
  artifactContent?: string;
  artifactError?: string;
  liveOutput: string[];
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
      <span className="stage-strip__label">Flow</span>
      <div className="stage-strip__list">
        {nodes.map((node) => (
          <div className={`stage-node stage-node--${node.status}`} key={node.name}>
            <span className="stage-node__icon" aria-hidden="true">
              {node.status === "failed" ? "×" : "•"}
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
  selectedRun,
  selectedArtifact,
  artifactContent,
  artifactError,
  liveOutput,
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
  const updatedStamp = task
    ? `updated ${task.task.updated_at.slice(11, 16)}`
    : elapsedLabel
      ? `updated ${elapsedLabel.slice(11, 16)}`
      : "";
  const runSummary = formatCount(timelineRuns.length, "run", "runs");
  const artifactSummary = formatCount(artifacts.length, "artifact", "artifacts");
  const actionRunId =
    actionSurface.kind !== "none" && "run" in actionSurface
      ? actionSurface.run?.id
      : undefined;
  const selectedRunArtifactCount = selectedRun
    ? artifacts.filter(
        (artifact) =>
          artifact.node_run_id === selectedRun.id ||
          selectedRun.artifact_paths?.includes(artifact.raw_path) ||
          selectedRun.artifact_paths?.includes(artifact.preview_name),
      ).length
    : 0;

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
        isCurrentRun={selectedRun?.id === actionRunId || task?.current_node_name === selectedRun?.node_name}
        liveLines={liveOutput}
        run={selectedRun}
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
        configLabel={configLabel}
        followUpDescription={followUpDescription}
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
      workspaceItems={shell.workspaceItems}
      onAddWorkspace={() => void shell.addWorkspace()}
      topBarLeft={
        <div className="screen-heading screen-heading--task">
          <div className="task-header task-header--detail">
            <h1 className="screen-title">{title}</h1>
            <div className="task-header__badges">
              <StatusBadge label={statusLabel} tone={statusTone} />
              <StatusBadge label={configLabel} mono tone="neutral" />
            </div>
          </div>
          <div className="task-header__subline">
            <span className={`task-header__state task-header__state--${statusTone}`}>
              {task?.current_node_name ?? "No active node"}
            </span>
            <span className="task-header__summary">{runSummary}</span>
            <span className="task-header__summary">{artifactSummary}</span>
          </div>
        </div>
      }
      topBarRight={
        <div className="task-header__context-meta">
          {selectedArtifact ? (
            <span className="detail-preview-indicator">
              previewing {selectedArtifact.preview_name}
            </span>
          ) : null}
          <span className="screen-meta">{updatedStamp}</span>
        </div>
      }
    >
      <section className="detail-screen" data-testid="task-detail-screen">
        {detailError ? (
          <div className="inline-banner inline-banner--failed">{detailError}</div>
        ) : null}

        <StageStrip nodes={stageNodes} />

        <DesktopWorkbenchFrame
          center={
            <TaskDetailSidebar
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
              <div className="detail-pane-scroll">{mainPane}</div>
              {actionPanel ? <div className="detail-pane-footer">{actionPanel}</div> : null}
            </div>
          }
        />
      </section>
    </DesktopShellFrame>
  );
}
