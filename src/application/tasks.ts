import type { DesktopRuntime } from "@/platform/contract";
import type {
  ArtifactRefDto,
  CommandAcceptedResult,
  ConfigViewDto,
  InputRequestDto,
  TaskContinueBlockedParams,
  TaskRetryNodeParams,
  TaskRunHistoryResult,
  TaskStartFollowUpParams,
  TaskStartParams,
  TaskSubmitInputParams,
  TaskViewDto,
} from "@/rpc/types";
import type { RuntimeNotification } from "@/platform/contract";

export type HydratedTaskDetail = {
  task: TaskViewDto;
  config?: ConfigViewDto;
  inputRequest?: InputRequestDto;
  artifacts: ArtifactRefDto[];
  liveOutput: string[];
  liveOutputRunId?: string;
};

export type ParsedTaskNotification = {
  workspaceId: string;
  taskId: string;
  nodeRunId?: string;
  taskView?: TaskViewDto;
  progressLines: string[];
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

function collapseWhitespace(value: string | undefined): string {
  return value?.replace(/\s+/g, " ").trim() ?? "";
}

function compactPaths(paths: string[] | undefined): string[] {
  const results: string[] = [];
  for (const rawPath of paths ?? []) {
    const normalized = rawPath.trim();
    if (!normalized) {
      continue;
    }
    const parts = normalized.split(/[\\/]/).filter(Boolean);
    results.push(parts.at(-1) ?? normalized);
  }
  return results;
}

function prettifyToolName(name: string | undefined): string {
  const trimmed = name?.trim();
  if (!trimmed) {
    return "";
  }
  return trimmed
    .replace(/[_-]+/g, " ")
    .replace(/([a-z0-9])([A-Z])/g, "$1 $2")
    .trim()
    .toLowerCase();
}

function toolLabel(tool: {
  kind?: string;
  name?: string;
}): string {
  switch (tool.kind?.trim()) {
    case "shell":
      return "shell";
    case "search":
      return "search";
    case "read":
      return "read";
    case "edit":
      return "edit";
    case "write":
      return "write";
    case "fetch":
      return "fetch";
    case "file_change":
      return "files";
    case "structured_output":
      return "structured output";
    default:
      return prettifyToolName(tool.name) || "tool";
  }
}

function toolSubject(tool: {
  input_summary?: string;
  title?: string;
  paths?: string[];
}): string {
  const inputSummary = collapseWhitespace(tool.input_summary);
  if (inputSummary) {
    return inputSummary;
  }
  const paths = compactPaths(tool.paths);
  if (paths.length > 0) {
    return paths.join(", ");
  }
  return collapseWhitespace(tool.title);
}

function toolStatusText(status: string | undefined): string {
  switch (status?.trim()) {
    case "in_progress":
    case "pending":
      return "running";
    case "failed":
      return "failed";
    default:
      return "";
  }
}

function summarizeProgressEvent(event: {
  raw?: string;
  message?: Record<string, unknown>;
  tool?: Record<string, unknown>;
  plan?: Record<string, unknown>;
  usage?: Record<string, unknown>;
}): string | undefined {
  if (event.raw?.trim()) {
    return event.raw;
  }

  const message = event.message as
    | {
        role?: string;
        type?: string;
        text?: string;
      }
    | undefined;
  if (message?.text?.trim()) {
    const rolePrefix =
      message.type === "reasoning"
        ? "thinking"
        : typeof message.role === "string" && message.role.trim()
          ? message.role
          : "assistant";
    return `${rolePrefix}: ${message.text}`;
  }

  const tool = event.tool as
    | {
        title?: string;
        kind?: string;
        name?: string;
        status?: string;
        input_summary?: string;
        output_text?: string;
        error_text?: string;
        paths?: string[];
      }
    | undefined;
  if (tool) {
    const subject = toolSubject(tool);
    const label = toolLabel(tool);
    const status = toolStatusText(tool.status);
    if (label && subject && status) {
      return `${label} ${status}: ${subject}`;
    }
    if (label && subject) {
      return `${label}: ${subject}`;
    }
    if (label && status) {
      return `${label} ${status}`;
    }
    if (label) {
      return label;
    }
  }

  if (event.plan) {
    return JSON.stringify({ plan: event.plan });
  }
  if (event.usage) {
    return JSON.stringify({ usage: event.usage });
  }
  if (event.message) {
    return JSON.stringify({ message: event.message });
  }
  if (event.tool) {
    return JSON.stringify({ tool: event.tool });
  }
  return undefined;
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
            events?: Array<{
              raw?: string;
              message?: Record<string, unknown>;
              tool?: Record<string, unknown>;
              plan?: Record<string, unknown>;
              usage?: Record<string, unknown>;
            }>;
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

  const progressLines: string[] = [];
  for (const progressEvent of event.progress?.events ?? []) {
    const line = summarizeProgressEvent(progressEvent);
    if (line?.trim()) {
      progressLines.push(line);
    }
  }
  if (
    progressLines.length === 0 &&
    event.progress?.message?.trim()
  ) {
    progressLines.push(event.progress.message);
  }

  return {
    workspaceId,
    taskId,
    nodeRunId: event.node_run_id,
    taskView: event.task_view,
    progressLines,
    shouldRefreshDetail: event.type !== "node.progress",
  };
}

export function summarizeRunHistory(
  history: TaskRunHistoryResult | undefined,
): string[] {
  const lines: string[] = [];
  for (const chunk of history?.history ?? []) {
    const progress = chunk.progress;
    let chunkEventCount = 0;
    for (const progressEvent of progress.events ?? []) {
      const line = summarizeProgressEvent(progressEvent);
      if (line?.trim()) {
        lines.push(line);
        chunkEventCount += 1;
      }
    }
    if (chunkEventCount === 0 && progress.message?.trim()) {
      lines.push(progress.message);
    }
  }
  return lines;
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
    liveOutput: taskResult.live_output ?? [],
    liveOutputRunId: taskResult.live_output_run_id,
  };
}

export async function loadTaskRunHistory(
  runtime: DesktopRuntime,
  workspaceId: string,
  taskId: string,
  nodeRunId: string,
): Promise<TaskRunHistoryResult> {
  return runtime.backend.taskRunHistory(workspaceId, taskId, nodeRunId);
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
