import type { DesktopRuntime } from "@/platform/contract";
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
  TaskViewDto,
} from "@/rpc/types";

export type HydratedTaskDetail = {
  task: TaskViewDto;
  config?: ConfigViewDto;
  inputRequest?: InputRequestDto;
  artifacts: ArtifactRefDto[];
};

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
  };
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

export async function readArtifactPreview(
  runtime: DesktopRuntime,
  artifact: ArtifactRefDto,
): Promise<string> {
  return runtime.shell.readTextFile(artifact.resolved_path);
}
