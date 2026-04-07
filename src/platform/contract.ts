import type {
  ArtifactListResult,
  CommandAcceptedResult,
  ConfigCloneParams,
  ConfigCloneResult,
  ConfigCatalogResult,
  ConfigDeleteParams,
  ConfigDeleteResult,
  ConfigGetResult,
  ConfigResetParams,
  ConfigResetResult,
  ConfigPromptGetResult,
  ConfigPromptSaveParams,
  ConfigPromptSaveResult,
  ConfigRenameParams,
  ConfigRenameResult,
  ConfigSaveParams,
  ConfigSaveResult,
  ConfigSetDefaultParams,
  ConfigSetDefaultResult,
  ConfigValidateParams,
  ConfigValidateResult,
  InitializeResult,
  NotificationEnvelopeParams,
  RuntimeListResult,
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
  configGet(alias: string): Promise<ConfigGetResult>;
  configClone(params: ConfigCloneParams): Promise<ConfigCloneResult>;
  configRename(params: ConfigRenameParams): Promise<ConfigRenameResult>;
  configDelete(params: ConfigDeleteParams): Promise<ConfigDeleteResult>;
  configReset(params: ConfigResetParams): Promise<ConfigResetResult>;
  configSetDefault(params: ConfigSetDefaultParams): Promise<ConfigSetDefaultResult>;
  configValidate(params: ConfigValidateParams): Promise<ConfigValidateResult>;
  configSave(params: ConfigSaveParams): Promise<ConfigSaveResult>;
  configPromptGet(alias: string, nodeName: string): Promise<ConfigPromptGetResult>;
  configPromptSave(
    params: ConfigPromptSaveParams,
  ): Promise<ConfigPromptSaveResult>;
  runtimeList(): Promise<RuntimeListResult>;
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
