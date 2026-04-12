import { useNavigate, useParams } from "react-router-dom";
import {
  buildStageNodes,
  detailStatusTitle,
  findLatestActionableBlockedRun,
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
  ConfigViewDto,
  InputRequestDto,
  NodeRunViewDto,
  TaskViewDto,
} from "@/rpc/types";

const emptyArtifacts: ArtifactRefDto[] = [];

export type ActivityRunActorType = "agent" | "human";

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null;
}

function resolveNodeActorTypes(
  config: ConfigViewDto | undefined,
): Partial<Record<string, ActivityRunActorType>> {
  if (!isRecord(config?.config)) {
    return {};
  }
  const nodeDefinitions = config.config.node_definitions;
  if (!isRecord(nodeDefinitions)) {
    return {};
  }

  const actorTypes: Partial<Record<string, ActivityRunActorType>> = {};
  for (const [nodeName, definition] of Object.entries(nodeDefinitions)) {
    if (!isRecord(definition)) {
      continue;
    }
    const type = definition.type;
    if (type === "human" || type === "agent") {
      actorTypes[nodeName] = type;
    }
  }

  return actorTypes;
}

function resolveRunActorType(args: {
  run: NodeRunViewDto;
  task?: TaskViewDto;
  inputRequest?: InputRequestDto;
  nodeActorTypes: Partial<Record<string, ActivityRunActorType>>;
}): ActivityRunActorType {
  const { run, task, inputRequest, nodeActorTypes } = args;
  const configActorType = nodeActorTypes[run.node_name];
  if (configActorType) {
    return configActorType;
  }
  if (task?.current_node_name === run.node_name && task.current_node_type === "human") {
    return "human";
  }
  if (inputRequest?.node_run_id === run.id && inputRequest.kind === "approval") {
    return "human";
  }
  return "agent";
}

function isOpenRun(run: NodeRunViewDto) {
  const status = run.status.toLowerCase();
  return status.includes("run") || status.includes("await");
}

function buildSyntheticBlockedRunId(taskId: string, blockedStep: BlockedStepDto) {
  return `synthetic-blocked-${taskId}-${blockedStep.node_name}-${blockedStep.iteration}`;
}

function buildSyntheticBlockedRun(
  taskId: string,
  blockedStep: BlockedStepDto,
): NodeRunViewDto {
  return {
    id: buildSyntheticBlockedRunId(taskId, blockedStep),
    task_id: taskId,
    node_name: blockedStep.node_name,
    status: "blocked",
    started_at: blockedStep.created_at,
  };
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
  const navigate = useNavigate();
  const { taskId = "", workspaceId = "" } = useParams();
  const configEntries = useWorkspaceStore((state) => state.catalog?.entries) ?? emptyConfigEntries;
  const taskSurfaceReturnContext = useWorkspaceStore(
    (state) => state.taskSurfaceReturnContext,
  );
  const backHref = taskSurfaceReturnContext?.path ?? "/";
  const { task: resolvedTask, detailEntry, liveEvents, liveEventsRunId, loadDetail } =
    useTaskDetailData({
      workspaceId,
      taskId,
      connected: shell.phase === "connected",
    });
  const artifacts = detailEntry?.artifacts ?? emptyArtifacts;
  const inputRequest = detailEntry?.inputRequest;
  const nodeActorTypes = resolveNodeActorTypes(detailEntry?.config);
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
  const inputRequestRun = inputRequest?.node_run_id
    ? navigatorRuns.find((run) => run.id === inputRequest.node_run_id)
    : undefined;
  const realBlockedRun = findLatestActionableBlockedRun(
    navigatorRuns,
    latestBlockedStep,
  );
  const blockedActivityRun =
    resolvedTask?.task.id && latestBlockedStep
      ? realBlockedRun ?? buildSyntheticBlockedRun(resolvedTask.task.id, latestBlockedStep)
      : undefined;
  const retrySurfaceRun = retryRun;
  const actionSurface: TaskDetailActionSurface = inputRequest
    ? inputRequest.kind === "clarification"
      ? {
          kind: "clarification",
          inputRequest,
          run: inputRequestRun,
        }
      : {
          kind: "approval",
          inputRequest,
          run: inputRequestRun,
        }
    : latestBlockedStep
      ? {
          kind: "blocked",
          blockedStep: latestBlockedStep,
          run: blockedActivityRun,
        }
      : retrySurfaceRun
        ? {
            kind: "retry",
            run: retrySurfaceRun,
            failureReason,
          }
        : resolvedTask && taskBucket(resolvedTask) === "done"
          ? { kind: "follow_up" }
          : { kind: "none" };

  return {
    shell,
    workspaceId,
    taskId,
    goBackToTaskSurface: () => navigate(backHref),
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
    activityRunActorTypes: Object.fromEntries(
      [
        ...navigatorRuns,
        ...(actionSurface.kind === "blocked" &&
        actionSurface.run &&
        !navigatorRuns.some((run) => run.id === actionSurface.run?.id)
          ? [actionSurface.run]
          : []),
      ].map((run) => [
        run.id,
        resolveRunActorType({
          run,
          task: resolvedTask,
          inputRequest,
          nodeActorTypes,
        }),
      ]),
    ) as Record<string, ActivityRunActorType>,
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
