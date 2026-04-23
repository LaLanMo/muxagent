import { useEffect, useMemo, useState } from "react";
import { useNavigate, useParams } from "react-router-dom";
import { getRuntime } from "@/app/runtime";
import { buildTaskDetailPath } from "@/domain/routes";
import { buildTranscriptSnapshot } from "@/domain/session-history";
import {
  buildStageNodes,
  detailStatusLabel,
  detailStatusTitle,
  findLatestActionableBlockedRun,
  latestRun,
  pathIsWithinCheckout,
  stageStatusForNode,
  statusTone,
  taskBucket,
  taskWorktreeName,
} from "@/domain/task-shell";
import { useWorkspaceStatus } from "@/features/source-control/model/use-source-control-data";
import { useShellModel } from "@/features/app/model/use-shell-model";
import {
  deriveRunningActivityPreview,
  deriveTranscriptTimelineItems,
  type RunningActivityPreviewRow,
} from "@/features/task-history/model/timeline";
import {
  taskForWorkspace,
  useTaskSnapshotStore,
} from "@/state/task-snapshot-store";
import { useWorkspaceStore } from "@/state/workspace-store";
import { useTaskDetailActions } from "@/features/task-detail/model/use-task-detail-actions";
import { useTaskDetailArtifactPreview } from "@/features/task-detail/model/use-task-detail-artifact-preview";
import {
  deriveFollowUpDockState,
} from "@/features/task-detail/model/follow-up-dock-state";
import { canShowFollowUpSurface } from "@/features/task-detail/model/task-detail-action-surface";
import { useTaskDetailData } from "@/features/task-detail/model/use-task-detail-data";
import { useTaskWorktreeCleanup } from "@/features/task-detail/model/use-task-worktree-cleanup";
import { useTaskDetailSelection } from "@/features/task-detail/model/use-task-detail-selection";
import {
  useTaskRunFullHistory,
  useTaskRunHistory,
} from "@/features/task-detail/model/use-task-run-history";
import type {
  ArtifactRefDto,
  BlockedStepDto,
  ConfigViewDto,
  InputRequestDto,
  NodeRunViewDto,
  TaskAncestryItemDto,
  TaskViewDto,
} from "@/rpc/types";

const emptyArtifacts: ArtifactRefDto[] = [];
const emptyAncestry: TaskAncestryItemDto[] = [];
const emptyHistoryEntries: TaskDetailHistoryEntry[] = [];

export type ActivityRunActorType = "agent" | "human";
export type TaskDetailHistoryEntry = {
  taskId: string;
  description: string;
  relativeUpdatedAt: string;
  metaLabel?: string;
};

function formatDuration(totalSeconds: number) {
  if (totalSeconds < 60) {
    return `${Math.max(1, totalSeconds)}s`;
  }
  const minutes = Math.floor(totalSeconds / 60);
  const seconds = totalSeconds % 60;
  const hours = Math.floor(minutes / 60);
  if (hours > 0) {
    return `${hours}h ${minutes % 60}m`;
  }
  return `${minutes}m ${seconds}s`;
}

function formatHistoryRelativeTime(iso: string | undefined): string {
  if (!iso) {
    return "just now";
  }
  const ms = Date.now() - Date.parse(iso);
  if (!Number.isFinite(ms) || ms < 0) {
    return "just now";
  }
  const seconds = Math.floor(ms / 1000);
  if (seconds < 60) {
    return `${Math.max(1, seconds)} second${seconds === 1 ? "" : "s"} ago`;
  }
  const minutes = Math.floor(seconds / 60);
  if (minutes < 60) {
    return `${minutes} minute${minutes === 1 ? "" : "s"} ago`;
  }
  const hours = Math.floor(minutes / 60);
  if (hours < 24) {
    return `${hours} hour${hours === 1 ? "" : "s"} ago`;
  }
  const days = Math.floor(hours / 24);
  return `${days} day${days === 1 ? "" : "s"} ago`;
}

function summarizeHistoryMeta(task: TaskViewDto | undefined): string | undefined {
  const runs = task?.node_runs ?? [];
  if (runs.length === 0) {
    return undefined;
  }
  const starts = runs
    .map((run) => Date.parse(run.started_at))
    .filter((value) => Number.isFinite(value));
  if (starts.length === 0) {
    return `${runs.length} ${runs.length === 1 ? "run" : "runs"}`;
  }
  const ends = runs
    .map((run) => Date.parse(run.completed_at ?? ""))
    .filter((value) => Number.isFinite(value));
  const hasOpenRun = runs.some((run) => {
    const status = detailStatusLabel(run.status);
    return status === "running" || status === "awaiting";
  });
  const end = hasOpenRun ? Date.now() : ends.length > 0 ? Math.max(...ends) : Math.max(...starts);
  const duration = formatDuration(Math.max(1, Math.floor((end - Math.min(...starts)) / 1000)));
  return `${runs.length} ${runs.length === 1 ? "run" : "runs"} · ${duration}`;
}

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
  const workspaceStatus = useWorkspaceStatus(workspaceId || undefined);
  const serverMethods =
    useWorkspaceStore((state) => state.server?.capabilities.methods) ?? [];
  const supportsTaskAncestry = serverMethods.includes("task.get_ancestry");
  const supportsWorktreeCleanup =
    serverMethods.includes("task.get_worktree_cleanup_info") &&
    serverMethods.includes("task.cleanup_worktree");
  const configEntries = useWorkspaceStore((state) => state.catalog?.entries) ?? emptyConfigEntries;
  const workspaceActorState = useWorkspaceStore(
    (state) =>
      state.workspaces.find((workspace) => workspace.workspace_id === workspaceId)?.actor
        .state ?? "cold",
  );
  const workspaceReconcilePending = useWorkspaceStore(
    (state) => (state.workspaceReconcileCounts[workspaceId] ?? 0) > 0,
  );
  const { task: resolvedTask, detailEntry, liveEvents, liveEventsRunId, loadDetail } =
    useTaskDetailData({
      workspaceId,
      taskId,
      connected: shell.phase === "connected",
      supportsTaskAncestry,
    });
  const artifacts = detailEntry?.artifacts ?? emptyArtifacts;
  const ancestry = detailEntry?.ancestry ?? emptyAncestry;
  const followUp = detailEntry?.followUp;
  const {
    cleanupInfo,
    cleanupLoading,
    cleanupError,
    loadCleanupInfo,
  } = useTaskWorktreeCleanup({
    workspaceId,
    taskId,
    connected: shell.phase === "connected",
    supported: supportsWorktreeCleanup,
    task: resolvedTask,
  });
  const tasksById = useTaskSnapshotStore((state) => state.tasksById);
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
  const { artifactPreview, artifactError } =
    useTaskDetailArtifactPreview(selectedArtifact);
  const [artifactActionError, setArtifactActionError] = useState<string | undefined>();
  const shouldLoadSelectedRunSummary = selectedRun ? isOpenRun(selectedRun) : false;
  const selectedRunHistory = useTaskRunHistory({
    workspaceId,
    taskId,
    connected: shell.phase === "connected",
    selectedRun,
    detailEntry,
    shouldLoad: shouldLoadSelectedRunSummary,
  });
  const selectedRunFullHistory = useTaskRunFullHistory({
    workspaceId,
    taskId,
    connected: shell.phase === "connected",
    selectedRun,
    detailEntry,
    shouldLoad: modal.kind === "transcript",
  });

  useEffect(() => {
    setArtifactActionError(undefined);
  }, [selectedArtifact?.resolved_path]);

  async function openArtifactExternally() {
    if (!selectedArtifact) {
      return;
    }
    setArtifactActionError(undefined);
    try {
      await getRuntime().shell.openPath(selectedArtifact.resolved_path);
    } catch (actionError) {
      setArtifactActionError(
        actionError instanceof Error
          ? actionError.message
          : "Failed to open artifact externally",
      );
    }
  }

  const stageNodes = useMemo(
    () => (resolvedTask ? buildStageNodes(resolvedTask) : []),
    [resolvedTask],
  );
  const latest = useMemo(
    () => (resolvedTask ? latestRun(resolvedTask) : undefined),
    [resolvedTask],
  );
  const currentRun = useMemo(
    () =>
      navigatorRuns.length
        ? [...navigatorRuns].reverse().find((run) => isOpenRun(run))
        : undefined,
    [navigatorRuns],
  );
  const latestFailedRun = useMemo(
    () =>
      navigatorRuns.length
        ? [...navigatorRuns]
            .reverse()
            .find((run) => run.status.toLowerCase().includes("fail"))
        : undefined,
    [navigatorRuns],
  );
  const retryRun = useMemo(
    () =>
      resolvedTask && taskBucket(resolvedTask) === "failed"
        ? latestFailedRun
        : undefined,
    [latestFailedRun, resolvedTask],
  );
  const failureReason = useMemo(
    () => retryRun?.failure_reason || resolvedTask?.current_issue?.reason || undefined,
    [resolvedTask?.current_issue?.reason, retryRun?.failure_reason],
  );
  const {
    submittingDecision,
    submittingClarification,
    submittingFollowUp,
    worktreeCleanupDialogOpen,
    submittingWorktreeCleanup,
    submittingRetry,
    submittingContinue,
    submittingRecovery,
    submitApprove,
    submitReject,
    submitClarification,
    submitFollowUp,
    openWorktreeCleanupDialog,
    closeWorktreeCleanupDialog,
    confirmWorktreeCleanup,
    retryTask,
    continueBlockedTask: continueBlocked,
    recoverRun,
  } = useTaskDetailActions({
    workspaceId,
    taskId,
    task: resolvedTask,
    configEntries,
    inputRequest,
    latestFailedRunId: retryRun?.id,
    loadDetail,
    worktreeCleanupInfo: cleanupInfo,
    loadCleanupInfo,
  });
  const inputRequestRun = inputRequest?.node_run_id
    ? navigatorRuns.find((run) => run.id === inputRequest.node_run_id)
    : undefined;
  const realBlockedRun = findLatestActionableBlockedRun(
    navigatorRuns,
    latestBlockedStep,
  );
  const blockedActivityRun = useMemo(
    () =>
      resolvedTask?.task.id && latestBlockedStep
        ? realBlockedRun ?? buildSyntheticBlockedRun(resolvedTask.task.id, latestBlockedStep)
        : undefined,
    [latestBlockedStep, realBlockedRun, resolvedTask?.task.id],
  );
  const retrySurfaceRun = retryRun;
  const showFollowUpSurface = useMemo(
    () =>
      canShowFollowUpSurface({
        task: resolvedTask,
        inputRequest,
        latestBlockedStep,
        retryRun: retrySurfaceRun,
      }),
    [inputRequest, latestBlockedStep, resolvedTask, retrySurfaceRun],
  );
  const followUpState = useMemo(
    () =>
      deriveFollowUpDockState({
        task: resolvedTask,
        detailEntry,
        inputRequest,
        latestBlockedStep,
        retryRun: retrySurfaceRun,
      }),
    [detailEntry, inputRequest, latestBlockedStep, resolvedTask, retrySurfaceRun],
  );
  const actionSurface = useMemo<TaskDetailActionSurface>(() => {
    if (inputRequest) {
      return inputRequest.kind === "clarification"
        ? {
            kind: "clarification",
            inputRequest,
            run: inputRequestRun,
          }
        : {
            kind: "approval",
            inputRequest,
            run: inputRequestRun,
          };
    }
    if (latestBlockedStep) {
      return {
        kind: "blocked",
        blockedStep: latestBlockedStep,
        run: blockedActivityRun,
      };
    }
    if (retrySurfaceRun) {
      return {
        kind: "retry",
        run: retrySurfaceRun,
        failureReason,
      };
    }
    if (showFollowUpSurface) {
      return { kind: "follow_up" };
    }
    return { kind: "none" };
  }, [
    blockedActivityRun,
    failureReason,
    inputRequest,
    inputRequestRun,
    latestBlockedStep,
    retrySurfaceRun,
    showFollowUpSurface,
  ]);
  const { runningActivityPreviewByRunId, activityPreviewSignature } = useMemo(() => {
    const previewsByRunId: Record<string, RunningActivityPreviewRow[]> = {};
    const previewParts: string[] = [];
    for (const run of navigatorRuns) {
      if (detailStatusLabel(run.status) !== "running") {
        continue;
      }
      const liveRunEvents = liveEventsRunId === run.id ? liveEvents : [];
      const replay = detailEntry?.runHistoryByRunId?.[run.id]?.result;
      if (liveRunEvents.length === 0 && !replay) {
        continue;
      }
      const preview = deriveRunningActivityPreview(
        deriveTranscriptTimelineItems(
          buildTranscriptSnapshot({
            replay,
            liveEvents: liveRunEvents,
          }),
        ),
      );
      if (preview.length === 0) {
        continue;
      }
      previewsByRunId[run.id] = preview;
      previewParts.push(
        `${run.id}:${preview.map((row) => `${row.id}:${row.text}`).join("|")}`,
      );
    }
    return {
      runningActivityPreviewByRunId: previewsByRunId,
      activityPreviewSignature: previewParts.join("||"),
    };
  }, [detailEntry?.runHistoryByRunId, liveEvents, liveEventsRunId, navigatorRuns]);
  const historyEntries = useMemo(
    () =>
      ancestry.length > 0
        ? ancestry.map((entry) => {
            const task = taskForWorkspace(tasksById, workspaceId, entry.task_id);
            return {
              taskId: entry.task_id,
              description: entry.description.trim() || entry.task_id,
              relativeUpdatedAt: formatHistoryRelativeTime(
                task?.task.updated_at ?? entry.updated_at,
              ),
              metaLabel: summarizeHistoryMeta(task),
            };
          })
        : emptyHistoryEntries,
    [ancestry, tasksById, workspaceId],
  );
  const activityRunActorTypes = useMemo(
    () =>
      Object.fromEntries(
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
    [actionSurface, inputRequest, navigatorRuns, nodeActorTypes, resolvedTask],
  );
  const stageNodeStatuses = useMemo(
    () =>
      resolvedTask
        ? stageNodes.map((node) => ({
            name: node,
            status: stageStatusForNode(resolvedTask, node),
          }))
        : [],
    [resolvedTask, stageNodes],
  );
  const launchModeName = useMemo(() => {
    if (!resolvedTask) {
      return undefined;
    }
    const matchingCheckout = workspaceStatus.data
      ? [workspaceStatus.data.main, ...workspaceStatus.data.worktrees].find((checkout) =>
          pathIsWithinCheckout(resolvedTask.task.execution_dir, checkout.path),
        )
      : undefined;
    return taskWorktreeName(resolvedTask, matchingCheckout);
  }, [resolvedTask, workspaceStatus.data]);

  return {
    shell,
    workspaceId,
    taskId,
    openAncestorTask: (ancestorTaskId: string) =>
      navigate(buildTaskDetailPath(workspaceId, ancestorTaskId)),
    task: resolvedTask,
    config: detailEntry?.config,
    loading,
    detailError,
    selection,
    modal,
    navigatorRuns,
    selectedRun,
    selectedArtifact,
    artifactPreview,
    artifactError,
    artifactActionError,
    artifacts,
    inputRequest,
    liveEvents,
    liveEventsRunId,
    selectedRunHistory,
    selectedRunFullHistory,
    workspaceActorState,
    staleReconcilePending: resolvedTask
      ? workspaceReconcilePending &&
        detailStatusLabel(resolvedTask.status) === "running" &&
        workspaceActorState !== "active"
      : false,
    supportsRunRecovery: serverMethods.includes("task.recover_stale"),
    ancestry,
    historyEntries,
    submittingDecision,
    submittingClarification,
    followUp,
    followUpState,
    worktreeCleanupInfo: cleanupInfo,
    worktreeCleanupLoading: cleanupLoading,
    worktreeCleanupError: cleanupError,
    retryWorktreeCleanupInfo: () => {
      void loadCleanupInfo({ showLoading: true });
    },
    submittingFollowUp,
    worktreeCleanupDialogOpen,
    submittingWorktreeCleanup,
    submittingRetry,
    submittingContinue,
    submittingRecovery,
    blockedStep: latestBlockedStep,
    failureReason,
    actionSurface,
    stageNodes: stageNodeStatuses,
    launchModeName,
    title: resolvedTask?.task.description || resolvedTask?.task.id || "Task detail",
    statusLabel: resolvedTask ? detailStatusTitle(resolvedTask.status) : "Running",
    statusTone: resolvedTask ? statusTone(resolvedTask.status) : "neutral",
    configLabel: resolvedTask?.task.config_alias || "default",
    configEntries,
    elapsedLabel: latest?.started_at ? latest.started_at : "",
    timelineRuns: navigatorRuns,
    runningActivityPreviewByRunId,
    activityPreviewSignature,
    activityRunActorTypes,
    currentRun,
    latestRun: latest,
    selectOverview,
    selectRun,
    selectArtifact,
    openTranscript,
    openArtifact,
    openArtifactExternally,
    submitApprove,
    submitReject,
    submitClarification,
    submitFollowUp,
    openWorktreeCleanupDialog,
    closeWorktreeCleanupDialog,
    confirmWorktreeCleanup,
    retryTask,
    continueBlockedTask: continueBlocked,
    recoverRun,
  };
}
