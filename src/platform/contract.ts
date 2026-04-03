import type {
  ArtifactListResult,
  CommandAcceptedResult,
  ConfigCatalogResult,
  InitializeResult,
  NotificationEnvelopeParams,
  ServiceStatusResult,
  TaskContinueBlockedParams,
  TaskGetResult,
  TaskInputRequestResult,
  TaskListResult,
  TaskRetryNodeParams,
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
  taskList(workspaceId: string): Promise<TaskListResult>;
  taskGet(workspaceId: string, taskId: string): Promise<TaskGetResult>;
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
