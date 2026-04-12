import type {
  ArtifactListResult,
  CommandAcceptedResult,
  ConfigCloneParams,
  ConfigCloneResult,
  ConfigCatalogResult,
  ConfigDeleteParams,
  ConfigDeleteResult,
  ConfigGetResult,
  ConfigValidateParams,
  ConfigValidateResult,
  InitializeResult,
  NotificationEnvelopeParams,
  ServiceStatusResult,
  TaskContinueBlockedParams,
  TaskGetResult,
  TaskInputRequestResult,
  TaskListResult,
  TaskRetryNodeParams,
  TaskRunHistoryResult,
  TaskStartParams,
  TaskStartFollowUpParams,
  TaskSubmitInputParams,
  WorkspaceAddParams,
  WorkspaceAddResult,
  WorkspaceGetResult,
  WorkspaceListResult,
  WorkspaceRemoveParams,
  WorkspaceRemoveResult,
  WorkspaceUpdateParams,
  WorkspaceUpdateResult,
} from "@/rpc/types";

export type RuntimeNotification = NotificationEnvelopeParams & { method: string };

export interface TaskBackendClient {
  connect(): Promise<InitializeResult>;
  disconnect(): Promise<void>;
  status(): Promise<ServiceStatusResult>;
  workspaceList(): Promise<WorkspaceListResult>;
  workspaceAdd(params: WorkspaceAddParams): Promise<WorkspaceAddResult>;
  workspaceGet(workspaceId: string): Promise<WorkspaceGetResult>;
  workspaceUpdate(params: WorkspaceUpdateParams): Promise<WorkspaceUpdateResult>;
  workspaceRemove(params: WorkspaceRemoveParams): Promise<WorkspaceRemoveResult>;
  configCatalog(): Promise<ConfigCatalogResult>;
  configGet(alias: string): Promise<ConfigGetResult>;
  configClone(params: ConfigCloneParams): Promise<ConfigCloneResult>;
  configDelete(params: ConfigDeleteParams): Promise<ConfigDeleteResult>;
  configValidate(params: ConfigValidateParams): Promise<ConfigValidateResult>;
  taskList(workspaceId: string): Promise<TaskListResult>;
  taskGet(workspaceId: string, taskId: string): Promise<TaskGetResult>;
  taskRunHistory(
    workspaceId: string,
    taskId: string,
    nodeRunId: string,
  ): Promise<TaskRunHistoryResult>;
  taskInputRequest(
    workspaceId: string,
    taskId: string,
    nodeRunId: string,
  ): Promise<TaskInputRequestResult>;
  taskStart(params: TaskStartParams): Promise<CommandAcceptedResult>;
  taskStartFollowUp(params: TaskStartFollowUpParams): Promise<CommandAcceptedResult>;
  taskSubmitInput(params: TaskSubmitInputParams): Promise<CommandAcceptedResult>;
  taskRetryNode(params: TaskRetryNodeParams): Promise<CommandAcceptedResult>;
  taskContinueBlocked(
    params: TaskContinueBlockedParams,
  ): Promise<CommandAcceptedResult>;
  artifactList(workspaceId: string, taskId: string): Promise<ArtifactListResult>;
  subscribe(listener: (notification: RuntimeNotification) => void): () => void;
  onConnectionLoss(listener: (error: Error) => void): () => void;
}

export interface ShellHost {
  pickDirectory(): Promise<string | null>;
  readTextFile(path: string): Promise<string>;
  openPath(path: string): Promise<void>;
}

export interface DesktopRuntime {
  backend: TaskBackendClient;
  shell: ShellHost;
}
