import { useParams } from "react-router-dom";
import {
  buildStageNodes,
  latestRun,
  stageStatusForNode,
  statusTone,
  taskBucket,
} from "@/domain/task-shell";
import { useShellModel } from "@/features/app/model/use-shell-model";
import { useTaskDetailActions } from "@/features/task-detail/model/use-task-detail-actions";
import { useTaskDetailArtifactPreview } from "@/features/task-detail/model/use-task-detail-artifact-preview";
import { useTaskDetailData } from "@/features/task-detail/model/use-task-detail-data";
import { useTaskDetailSelection } from "@/features/task-detail/model/use-task-detail-selection";
import type {
  ArtifactRefDto,
  BlockedStepDto,
  InputRequestDto,
  NodeRunViewDto,
} from "@/rpc/types";

const emptyArtifacts: ArtifactRefDto[] = [];

export type TaskDetailActionSurface =
  | {
      kind: "approval";
      inputRequest: InputRequestDto;
      run?: NodeRunViewDto;
    }
  | {
      kind: "clarification";
      inputRequest: InputRequestDto;
      run?: NodeRunViewDto;
    }
  | {
      kind: "retry";
      run?: NodeRunViewDto;
      failureReason?: string;
    }
  | {
      kind: "blocked";
      blockedStep?: BlockedStepDto;
      run?: NodeRunViewDto;
    }
  | {
      kind: "follow_up";
    }
  | {
      kind: "none";
    };

export function useTaskDetailScreen() {
  const shell = useShellModel();
  const { taskId = "", workspaceId = "" } = useParams();
  const { task: resolvedTask, detailEntry, liveOutput, loadDetail } =
    useTaskDetailData({
      workspaceId,
      taskId,
      connected: shell.phase === "connected",
    });
  const artifacts = detailEntry?.artifacts ?? emptyArtifacts;
  const inputRequest = detailEntry?.inputRequest;
  const detailError = detailEntry?.error;
  const loading = detailEntry?.loading ?? false;
  const latestBlockedStep = resolvedTask?.blocked_steps?.at(-1) as
    | BlockedStepDto
    | undefined;
  const {
    navigatorRuns,
    selection,
    selectedRun,
    selectedArtifact,
    selectOverview,
    selectRun,
    selectArtifact,
  } = useTaskDetailSelection({
    taskId,
    task: resolvedTask,
    artifacts,
    inputRequest,
    blockedStep: latestBlockedStep,
  });
  const { artifactContent, artifactError } =
    useTaskDetailArtifactPreview(selectedArtifact);

  const stageNodes = resolvedTask ? buildStageNodes(resolvedTask) : [];
  const latest = resolvedTask ? latestRun(resolvedTask) : undefined;
  const latestFailedRun = navigatorRuns.length
    ? [...navigatorRuns]
        .reverse()
        .find((run) => run.status.toLowerCase().includes("fail"))
    : undefined;
  const failureReason =
    latestFailedRun?.failure_reason || resolvedTask?.current_issue?.reason || undefined;
  const {
    feedback,
    setFeedback,
    clarificationAnswers,
    setClarificationAnswer,
    submittingDecision,
    submittingClarification,
    followUpDescription,
    setFollowUpDescription,
    submittingFollowUp,
    submittingRetry,
    submittingContinue,
    submitApprove,
    submitReject,
    submitClarification,
    submitFollowUp,
    retryTask,
    continueBlockedTask: continueBlocked,
  } = useTaskDetailActions({
    workspaceId,
    taskId,
    task: resolvedTask,
    inputRequest,
    latestFailedRunId: latestFailedRun?.id,
    loadDetail,
  });
  const blockedRun = latestBlockedStep
    ? [...navigatorRuns]
        .reverse()
        .find((run) => run.node_name === latestBlockedStep.node_name)
    : undefined;
  const actionRun =
    (inputRequest?.node_run_id
      ? navigatorRuns.find((run) => run.id === inputRequest.node_run_id)
      : undefined) ??
    blockedRun ??
    latestFailedRun;
  const actionSurface: TaskDetailActionSurface = inputRequest
    ? inputRequest.kind === "clarification"
      ? {
          kind: "clarification",
          inputRequest,
          run: actionRun,
        }
      : {
          kind: "approval",
          inputRequest,
          run: actionRun,
        }
    : latestBlockedStep
      ? {
          kind: "blocked",
          blockedStep: latestBlockedStep,
          run: actionRun,
        }
      : latestFailedRun
        ? {
            kind: "retry",
            run: latestFailedRun,
            failureReason,
          }
        : resolvedTask && taskBucket(resolvedTask) === "done"
          ? { kind: "follow_up" }
          : { kind: "none" };

  return {
    shell,
    workspaceId,
    taskId,
    task: resolvedTask,
    loading,
    detailError,
    selection,
    navigatorRuns,
    selectedRun,
    selectedArtifact,
    artifactContent,
    artifactError,
    artifacts,
    inputRequest,
    liveOutput,
    feedback,
    setFeedback,
    clarificationAnswers,
    setClarificationAnswer,
    submittingDecision,
    submittingClarification,
    followUpDescription,
    setFollowUpDescription,
    submittingFollowUp,
    submittingRetry,
    submittingContinue,
    blockedStep: latestBlockedStep,
    failureReason,
    actionSurface,
    stageNodes: resolvedTask
      ? stageNodes.map((node) => ({
          name: node,
          status: stageStatusForNode(resolvedTask, node),
        }))
      : [],
    title: resolvedTask?.task.description || resolvedTask?.task.id || "Task detail",
    statusLabel: resolvedTask?.status || "running",
    statusTone: resolvedTask ? statusTone(resolvedTask.status) : "neutral",
    configLabel: resolvedTask?.task.config_alias || "default",
    elapsedLabel: latest?.started_at ? latest.started_at : "",
    timelineRuns: navigatorRuns,
    latestRun: latest,
    selectOverview,
    selectRun,
    selectArtifact,
    submitApprove,
    submitReject,
    submitClarification,
    submitFollowUp,
    retryTask,
    continueBlockedTask: continueBlocked,
  };
}
