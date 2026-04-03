import type { ShellChromeModel } from "@/features/app/model/use-shell-chrome";
import { DesktopShellFrame } from "@/features/layout/ui/DesktopShellFrame";
import { StatusBadge } from "@/features/shared/ui/StatusBadge";
import { TaskDetailSidebar } from "@/features/task-detail/ui/TaskDetailSidebar";
import {
  TaskApprovalPane,
  TaskArtifactPane,
  TaskBlockedPane,
  TaskCompletePane,
  TaskFailedPane,
  TaskLivePane,
} from "@/features/task-detail/ui/TaskDetailPanels";
import type { ArtifactRefDto, BlockedStepDto, NodeRunViewDto } from "@/rpc/types";

type StageNode = {
  name: string;
  status: "done" | "current" | "pending" | "failed";
};

type TaskDetailScreenProps = {
  shell: ShellChromeModel;
  task?: {
    task: {
      id: string;
      updated_at: string;
    };
    status: string;
    current_node_name: string;
  };
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
  selectedArtifact?: ArtifactRefDto;
  artifactContent?: string;
  artifactError?: string;
  liveOutput: string[];
  detailMode: "live" | "approval" | "artifact" | "failed" | "complete" | "blocked";
  inputRequest?: {
    node_name: string;
  };
  blockedStep?: BlockedStepDto;
  feedback: string;
  setFeedback: (value: string) => void;
  submittingDecision: boolean;
  followUpDescription: string;
  setFollowUpDescription: (value: string) => void;
  submittingFollowUp: boolean;
  submittingRetry: boolean;
  submittingContinue: boolean;
  failureReason?: string;
  selectArtifact: (artifact: ArtifactRefDto) => void;
  clearArtifact: () => void;
  submitApprove: () => Promise<void>;
  submitReject: () => Promise<void>;
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
  selectedArtifact,
  artifactContent,
  artifactError,
  liveOutput,
  detailMode,
  inputRequest,
  blockedStep,
  feedback,
  setFeedback,
  submittingDecision,
  followUpDescription,
  setFollowUpDescription,
  submittingFollowUp,
  submittingRetry,
  submittingContinue,
  failureReason,
  selectArtifact,
  clearArtifact,
  submitApprove,
  submitReject,
  submitFollowUp,
  retryTask,
  continueBlockedTask,
}: TaskDetailScreenProps) {
  const updatedStamp = task
    ? `updated ${task.task.updated_at.slice(11, 16)}`
    : elapsedLabel
      ? `updated ${elapsedLabel.slice(11, 16)}`
      : "";

  let rightPane = (
    <TaskLivePane
      lines={liveOutput}
      title={`Output · ${task?.current_node_name ?? "task"}`}
    />
  );
  if (detailMode === "approval") {
    rightPane = (
      <TaskApprovalPane
        feedback={feedback}
        inputRequest={inputRequest}
        setFeedback={setFeedback}
        submitApprove={submitApprove}
        submitReject={submitReject}
        submittingDecision={submittingDecision}
      />
    );
  } else if (detailMode === "artifact") {
    rightPane = (
      <TaskArtifactPane
        artifact={selectedArtifact}
        content={artifactContent}
        error={artifactError}
        onBack={clearArtifact}
      />
    );
  } else if (detailMode === "blocked") {
    rightPane = (
      <TaskBlockedPane
        blockedStep={blockedStep}
        onContinue={continueBlockedTask}
        submittingContinue={submittingContinue}
      />
    );
  } else if (detailMode === "failed") {
    rightPane = (
      <TaskFailedPane
        failureReason={failureReason}
        latestFailure={timelineRuns.at(-1)}
        onRetry={retryTask}
        submittingRetry={submittingRetry}
      />
    );
  } else if (detailMode === "complete") {
    rightPane = (
      <TaskCompletePane
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
      primaryNav={shell.primaryNav}
      secondaryNav={shell.secondaryNav}
      sidebarStatusLabel={shell.connectionLabel}
      sidebarStatusTone={shell.connectionTone}
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
            <span className="task-header__summary">{timelineRuns.length} runs</span>
            <span className="task-header__summary">{artifacts.length} artifacts</span>
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

        <div className="detail-split-view">
          <TaskDetailSidebar
            artifacts={artifacts}
            currentNodeName={task?.current_node_name}
            hasTask={Boolean(task)}
            loading={loading}
            onSelectArtifact={selectArtifact}
            selectedArtifact={selectedArtifact}
            timelineRuns={timelineRuns}
          />

          <div className="detail-split-divider" />

          <div className="detail-pane-host">{rightPane}</div>
        </div>
      </section>
    </DesktopShellFrame>
  );
}
