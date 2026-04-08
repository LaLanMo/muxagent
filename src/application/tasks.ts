import type { DesktopRuntime } from "@/platform/contract";
import {
  buildTranscriptSnapshot,
  normalizeStreamEvent,
  normalizeTaskRunHistoryResult,
  summarizeTranscript,
  type NormalizedTaskRunHistoryResult,
  type SessionHistoryEvent,
} from "@/domain/session-history";
import type {
  ArtifactRefDto,
  CommandAcceptedResult,
  ConfigViewDto,
  InputRequestDto,
  TaskContinueBlockedParams,
  TaskRetryNodeParams,
  TaskStartFollowUpParams,
  TaskStartParams,
  TaskSubmitInputParams,
  SessionHistoryEventDto,
  TaskViewDto,
} from "@/rpc/types";
import type { RuntimeNotification } from "@/platform/contract";

export type HydratedTaskDetail = {
  task: TaskViewDto;
  config?: ConfigViewDto;
  inputRequest?: InputRequestDto;
  artifacts: ArtifactRefDto[];
  liveEvents: SessionHistoryEvent[];
  liveEventsRunId?: string;
};

export type ParsedTaskNotification = {
  workspaceId: string;
  taskId: string;
  nodeRunId?: string;
  taskView?: TaskViewDto;
  progressEvents: SessionHistoryEvent[];
  shouldRefreshDetail: boolean;
};

type SubmitTaskApprovalArgs = {
  workspaceId: string;
  taskId: string;
  inputRequest: InputRequestDto;
  approved: boolean;
  feedback?: string;
};

type SubmitTaskClarificationArgs = {
  workspaceId: string;
  taskId: string;
  inputRequest: InputRequestDto;
  answers: Array<string | string[]>;
};

type StartFollowUpFromTaskArgs = {
  workspaceId: string;
  taskId: string;
  task: TaskViewDto;
  description: string;
  configAliasOverride?: string;
};

type StartFollowUpAndReloadTaskListArgs = StartFollowUpFromTaskArgs;

type RetryTaskNodeActionArgs = {
  workspaceId: string;
  taskId: string;
  nodeRunId: string;
  force: boolean;
};

type ContinueBlockedTaskActionArgs = {
  workspaceId: string;
  taskId: string;
};

type WaitForTaskTransitionArgs = {
  loadDetail: () => Promise<HydratedTaskDetail | undefined>;
  predicate: (task: TaskViewDto) => boolean;
  attempts?: number;
  delayMs?: number;
};

type ContinueBlockedUntilResumedArgs = ContinueBlockedTaskActionArgs & {
  loadDetail: () => Promise<HydratedTaskDetail | undefined>;
  attempts?: number;
  delayMs?: number;
};

function nextClientCommandId() {
  return globalThis.crypto?.randomUUID?.() ?? String(Date.now());
}

function delay(ms: number) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

export function mergeStreamLines(historyLines: string[], liveLines: string[]): string[] {
  if (historyLines.length === 0) {
    return [...liveLines];
  }
  if (liveLines.length === 0) {
    return [...historyLines];
  }

  const maxOverlap = Math.min(historyLines.length, liveLines.length);
  for (let overlap = maxOverlap; overlap > 0; overlap -= 1) {
    let matches = true;
    for (let index = 0; index < overlap; index += 1) {
      if (historyLines[historyLines.length - overlap + index] !== liveLines[index]) {
        matches = false;
        break;
      }
    }
    if (matches) {
      return [...historyLines, ...liveLines.slice(overlap)];
    }
  }

  return [...historyLines, ...liveLines];
}

export function parseTaskNotification(
  notification: RuntimeNotification,
): ParsedTaskNotification | undefined {
  const payload = notification.payload as
    | {
        event?: {
          type?: string;
          task_id?: string;
          node_run_id?: string;
          task_view?: TaskViewDto;
          progress?: {
            message?: string;
            session_id?: string;
            events?: SessionHistoryEventDto[];
          };
        };
      }
    | undefined;
  const event = payload?.event;
  const workspaceId = notification.workspace_id ?? "";
  if (!event || !workspaceId) {
    return undefined;
  }

  const taskId = event.task_view?.task.id ?? event.task_id ?? "";
  if (!taskId) {
    return undefined;
  }

  const progressEvents = (event.progress?.events ?? []).map((progressEvent, index) =>
    normalizeStreamEvent(progressEvent, "live", event.node_run_id, index),
  );
  if (progressEvents.length === 0 && event.progress?.message?.trim()) {
    progressEvents.push({
      id: `evt:fallback:live:${event.node_run_id ?? taskId}:${event.type ?? "node.progress"}:${event.progress.message}`,
      source: "live",
      nodeRunId: event.node_run_id,
      sessionId: event.progress.session_id,
      kind: "raw",
      raw: event.progress.message,
      text: event.progress.message,
    });
  }

  return {
    workspaceId,
    taskId,
    nodeRunId: event.node_run_id,
    taskView: event.task_view,
    progressEvents,
    shouldRefreshDetail: event.type !== "node.progress",
  };
}

export function summarizeRunHistory(
  history: NormalizedTaskRunHistoryResult | undefined,
): string[] {
  return summarizeTranscript(buildTranscriptSnapshot({ history }));
}

export async function hydrateTaskDetail(
  runtime: DesktopRuntime,
  workspaceId: string,
  taskId: string,
): Promise<HydratedTaskDetail> {
  const [taskResult, artifactResult] = await Promise.all([
    runtime.backend.taskGet(workspaceId, taskId),
    runtime.backend.artifactList(workspaceId, taskId),
  ]);

  return {
    task: taskResult.task,
    config: taskResult.config,
    inputRequest: taskResult.input_request,
    artifacts: artifactResult.artifacts,
    liveEvents: (taskResult.live_events ?? []).map((event, index) =>
      normalizeStreamEvent(event, "live", taskResult.live_output_run_id, index),
    ),
    liveEventsRunId: taskResult.live_output_run_id,
  };
}

export async function loadTaskRunHistory(
  runtime: DesktopRuntime,
  workspaceId: string,
  taskId: string,
  nodeRunId: string,
): Promise<NormalizedTaskRunHistoryResult> {
  return normalizeTaskRunHistoryResult(
    await runtime.backend.taskRunHistory(workspaceId, taskId, nodeRunId),
  );
}

export async function loadTaskList(
  runtime: DesktopRuntime,
  workspaceId: string,
): Promise<TaskViewDto[]> {
  const taskList = await runtime.backend.taskList(workspaceId);
  return taskList.tasks;
}

export async function startTask(
  runtime: DesktopRuntime,
  params: TaskStartParams,
): Promise<CommandAcceptedResult> {
  return runtime.backend.taskStart(params);
}

export async function startFollowUpTask(
  runtime: DesktopRuntime,
  params: TaskStartFollowUpParams,
): Promise<CommandAcceptedResult> {
  return runtime.backend.taskStartFollowUp(params);
}

export async function submitTaskInput(
  runtime: DesktopRuntime,
  params: TaskSubmitInputParams,
): Promise<CommandAcceptedResult> {
  return runtime.backend.taskSubmitInput(params);
}

export async function retryTaskNode(
  runtime: DesktopRuntime,
  params: TaskRetryNodeParams,
): Promise<CommandAcceptedResult> {
  return runtime.backend.taskRetryNode(params);
}

export async function continueBlockedTask(
  runtime: DesktopRuntime,
  params: TaskContinueBlockedParams,
): Promise<CommandAcceptedResult> {
  return runtime.backend.taskContinueBlocked(params);
}

export async function submitTaskApproval(
  runtime: DesktopRuntime,
  args: SubmitTaskApprovalArgs,
): Promise<CommandAcceptedResult> {
  return submitTaskInput(runtime, {
    workspace_id: args.workspaceId,
    client_command_id: nextClientCommandId(),
    task_id: args.taskId,
    node_run_id: args.inputRequest.node_run_id,
    payload: {
      approved: args.approved,
      ...(args.feedback?.trim() ? { feedback: args.feedback.trim() } : {}),
    },
  });
}

export async function submitTaskClarification(
  runtime: DesktopRuntime,
  args: SubmitTaskClarificationArgs,
): Promise<CommandAcceptedResult> {
  return submitTaskInput(runtime, {
    workspace_id: args.workspaceId,
    client_command_id: nextClientCommandId(),
    task_id: args.taskId,
    node_run_id: args.inputRequest.node_run_id,
    payload: {
      answers: args.answers.map((selected) => ({ selected })),
    },
  });
}

export async function startFollowUpFromTask(
  runtime: DesktopRuntime,
  args: StartFollowUpFromTaskArgs,
): Promise<CommandAcceptedResult> {
  return startFollowUpTask(runtime, {
    workspace_id: args.workspaceId,
    client_command_id: nextClientCommandId(),
    parent_task_id: args.taskId,
    description: args.description.trim(),
    config_alias: args.configAliasOverride ?? args.task.task.config_alias,
    config_path: args.task.task.config_path,
  });
}

export async function startFollowUpAndReloadTaskList(
  runtime: DesktopRuntime,
  args: StartFollowUpAndReloadTaskListArgs,
): Promise<TaskViewDto[]> {
  await startFollowUpFromTask(runtime, args);
  return loadTaskList(runtime, args.workspaceId);
}

export async function retryTaskNodeAction(
  runtime: DesktopRuntime,
  args: RetryTaskNodeActionArgs,
): Promise<CommandAcceptedResult> {
  return retryTaskNode(runtime, {
    workspace_id: args.workspaceId,
    client_command_id: nextClientCommandId(),
    task_id: args.taskId,
    node_run_id: args.nodeRunId,
    force: args.force,
  });
}

export async function continueBlockedTaskAction(
  runtime: DesktopRuntime,
  args: ContinueBlockedTaskActionArgs,
): Promise<CommandAcceptedResult> {
  return continueBlockedTask(runtime, {
    workspace_id: args.workspaceId,
    client_command_id: nextClientCommandId(),
    task_id: args.taskId,
  });
}

export async function waitForTaskTransition({
  loadDetail,
  predicate,
  attempts = 20,
  delayMs = 500,
}: WaitForTaskTransitionArgs): Promise<boolean> {
  for (let index = 0; index < attempts; index += 1) {
    const detail = await loadDetail();
    if (detail && predicate(detail.task)) {
      return true;
    }
    await delay(delayMs);
  }
  return false;
}

export async function continueBlockedUntilResumed(
  runtime: DesktopRuntime,
  args: ContinueBlockedUntilResumedArgs,
): Promise<boolean> {
  await continueBlockedTaskAction(runtime, {
    workspaceId: args.workspaceId,
    taskId: args.taskId,
  });

  return waitForTaskTransition({
    loadDetail: args.loadDetail,
    attempts: args.attempts,
    delayMs: args.delayMs,
    predicate: (task) =>
      task.current_issue?.kind !== "blocked_step" &&
      (task.blocked_steps?.length ?? 0) === 0,
  });
}

export async function readArtifactPreview(
  runtime: DesktopRuntime,
  artifact: ArtifactRefDto,
): Promise<string> {
  return runtime.shell.readTextFile(artifact.resolved_path);
}
