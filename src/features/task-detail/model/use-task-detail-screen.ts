import { useParams } from "react-router-dom";
import {
  buildStageNodes,
  detailStatusTitle,
  latestRun,
  stageStatusForNode,
  statusTone,
  taskBucket,
} from "@/domain/task-shell";
import { useShellModel } from "@/features/app/model/use-shell-model";
import { useWorkspaceStore } from "@/state/workspace-store";
import { useTaskDetailActions } from "@/features/task-detail/model/use-task-detail-actions";
import { useTaskDetailArtifactPreview } from "@/features/task-detail/model/use-task-detail-artifact-preview";
import { useTaskDetailData } from "@/features/task-detail/model/use-task-detail-data";
import { useTaskDetailSelection } from "@/features/task-detail/model/use-task-detail-selection";
import { useTaskRunHistory } from "@/features/task-detail/model/use-task-run-history";
import type {
  ArtifactRefDto,
  BlockedStepDto,
  InputRequestDto,
  NodeRunViewDto,
} from "@/rpc/types";

const emptyArtifacts: ArtifactRefDto[] = [];
function isOpenRun(run: NodeRunViewDto) {
  const status = run.status.toLowerCase();
  return status.includes("run") || status.includes("await");
}

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

const emptyConfigEntries: import("@/rpc/types").ConfigCatalogEntryDto[] = [];

export function useTaskDetailScreen() {
  const shell = useShellModel();
  const { taskId = "", workspaceId = "" } = useParams();
  const configEntries = useWorkspaceStore((state) => state.catalog?.entries) ?? emptyConfigEntries;
  const { task: resolvedTask, detailEntry, liveEvents, liveEventsRunId, loadDetail } =
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
    modal,
    selectedRun,
    selectedArtifact,
    selectOverview,
    selectRun,
    selectArtifact,
    openTranscript,
    openArtifact,
  } = useTaskDetailSelection({
    taskId,
    task: resolvedTask,
    artifacts,
    inputRequest,
    blockedStep: latestBlockedStep,
  });
  const { artifactContent, artifactError } =
    useTaskDetailArtifactPreview(selectedArtifact);
  const selectedRunHistory = useTaskRunHistory({
    workspaceId,
    taskId,
    connected: shell.phase === "connected",
    selectedRun,
    detailEntry,
  });

  const stageNodes = resolvedTask ? buildStageNodes(resolvedTask) : [];
  const latest = resolvedTask ? latestRun(resolvedTask) : undefined;
  const currentRun = navigatorRuns.length
    ? [...navigatorRuns].reverse().find((run) => isOpenRun(run))
    : undefined;
  const latestFailedRun = navigatorRuns.length
    ? [...navigatorRuns]
        .reverse()
        .find((run) => run.status.toLowerCase().includes("fail"))
    : undefined;
  const retryRun =
    resolvedTask && taskBucket(resolvedTask) === "failed"
      ? latestFailedRun
      : undefined;
  const failureReason =
    retryRun?.failure_reason || resolvedTask?.current_issue?.reason || undefined;
  const {
    feedback,
    setFeedback,
    clarificationAnswers,
    setClarificationAnswer,
    submittingDecision,
    submittingClarification,
    followUpDescription,
    setFollowUpDescription,
    followUpConfigAlias,
    setFollowUpConfigAlias,
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
    latestFailedRunId: retryRun?.id,
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
    retryRun;
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
      : retryRun
        ? {
            kind: "retry",
            run: retryRun,
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
    modal,
    navigatorRuns,
    selectedRun,
    selectedArtifact,
    artifactContent,
    artifactError,
    artifacts,
    inputRequest,
    liveEvents,
    liveEventsRunId,
    selectedRunHistory,
    feedback,
    setFeedback,
    clarificationAnswers,
    setClarificationAnswer,
    submittingDecision,
    submittingClarification,
    followUpDescription,
    setFollowUpDescription,
    followUpConfigAlias,
    setFollowUpConfigAlias,
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
    statusLabel: resolvedTask ? detailStatusTitle(resolvedTask.status) : "Running",
    statusTone: resolvedTask ? statusTone(resolvedTask.status) : "neutral",
    configLabel: resolvedTask?.task.config_alias || "default",
    configEntries,
    elapsedLabel: latest?.started_at ? latest.started_at : "",
    timelineRuns: navigatorRuns,
    currentRun,
    latestRun: latest,
    selectOverview,
    selectRun,
    selectArtifact,
    openTranscript,
    openArtifact,
    submitApprove,
    submitReject,
    submitClarification,
    submitFollowUp,
    retryTask,
    continueBlockedTask: continueBlocked,
  };
}
