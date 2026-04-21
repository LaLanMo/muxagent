import { invoke } from "@tauri-apps/api/core";
import { listen } from "@tauri-apps/api/event";
import type {
  ArtifactListResult,
  CommandAcceptedResult,
  ConfigCloneParams,
  ConfigCloneResult,
  ConfigCatalogResult,
  ConfigDeleteParams,
  ConfigDeleteResult,
  ConfigGetResult,
  ConfigSetBuiltinRuntimesParams,
  ConfigValidateParams,
  ConfigValidateResult,
  InitializeResult,
  JsonRpcNotification,
  NotificationEnvelopeParams,
  RuntimeStatusResult,
  ServiceStatusResult,
  TaskContinueBlockedParams,
  TaskCleanupWorktreeParams,
  TaskCleanupWorktreeResult,
  TaskGetAncestryResult,
  TaskGetWorktreeCleanupInfoResult,
  TaskRecoverStaleParams,
  TaskRecoverStaleResult,
  TaskRunHistoryResult,
  TaskStartParams,
  TaskStartFollowUpParams,
  TaskSubmitInputParams,
  TaskGetResult,
  TaskInputRequestResult,
  TaskListResult,
  TaskRetryNodeParams,
  WorkspaceAddParams,
  WorkspaceAddResult,
  WorkspaceCheckoutStatusParams,
  WorkspaceCheckoutStatusResult,
  WorkspaceCommitDiffParams,
  WorkspaceCommitDiffResult,
  WorkspaceFileDiffParams,
  WorkspaceFileDiffResult,
  WorkspaceGetResult,
  WorkspaceGitStatusParams,
  WorkspaceGitStatusResult,
  WorkspaceReconcileParams,
  WorkspaceReconcileResult,
  WorkspaceListResult,
  WorkspaceRemoveParams,
  WorkspaceRemoveResult,
  WorkspaceUpdateParams,
  WorkspaceUpdateResult,
} from "@/rpc/types";
import type {
  DesktopRuntime,
  RuntimeNotification,
  ShellHost,
  TaskBackendClient,
} from "@/platform/contract";

const notificationEvent = "app-server-notification";
const disconnectedEvent = "app-server-disconnected";

type DisconnectedPayload = {
  message?: string;
};

class TauriTaskBackendClient implements TaskBackendClient {
  private listeners = new Set<(notification: RuntimeNotification) => void>();
  private connectionLossListeners = new Set<(error: Error) => void>();
  private unlistenNotification: (() => void) | null = null;
  private unlistenDisconnected: (() => void) | null = null;

  async connect(): Promise<InitializeResult> {
    await this.ensureSubscriptions();
    return invoke<InitializeResult>("app_server_connect");
  }

  async disconnect(): Promise<void> {
    await invoke("app_server_disconnect").catch(() => undefined);
  }

  status(): Promise<ServiceStatusResult> {
    return this.request("service.status");
  }

  runtimeStatus(): Promise<RuntimeStatusResult> {
    return this.request("runtime.status");
  }

  workspaceList(): Promise<WorkspaceListResult> {
    return this.request("workspace.list");
  }

  workspaceAdd(params: WorkspaceAddParams): Promise<WorkspaceAddResult> {
    return this.request("workspace.add", params);
  }

  workspaceGet(workspaceId: string): Promise<WorkspaceGetResult> {
    return this.request("workspace.get", { workspace_id: workspaceId });
  }

  workspaceGitStatus(
    params: WorkspaceGitStatusParams,
  ): Promise<WorkspaceGitStatusResult> {
    return this.request("workspace.git_status", params);
  }

  workspaceCheckoutStatus(
    params: WorkspaceCheckoutStatusParams,
  ): Promise<WorkspaceCheckoutStatusResult> {
    return this.request("workspace.checkout_status", params);
  }

  workspaceFileDiff(
    params: WorkspaceFileDiffParams,
  ): Promise<WorkspaceFileDiffResult> {
    return this.request("workspace.file_diff", params);
  }

  workspaceCommitDiff(
    params: WorkspaceCommitDiffParams,
  ): Promise<WorkspaceCommitDiffResult> {
    return this.request("workspace.commit_diff", params);
  }

  workspaceReconcileStale(
    params: WorkspaceReconcileParams,
  ): Promise<WorkspaceReconcileResult> {
    return this.request("workspace.reconcile_stale", params);
  }

  workspaceUpdate(params: WorkspaceUpdateParams): Promise<WorkspaceUpdateResult> {
    return this.request("workspace.update", params);
  }

  workspaceRemove(params: WorkspaceRemoveParams): Promise<WorkspaceRemoveResult> {
    return this.request("workspace.remove", params);
  }

  configCatalog(): Promise<ConfigCatalogResult> {
    return this.request("config.catalog");
  }

  configGet(alias: string): Promise<ConfigGetResult> {
    return this.request("config.get", { alias });
  }

  configClone(params: ConfigCloneParams): Promise<ConfigCloneResult> {
    return this.request("config.clone", params);
  }

  configDelete(params: ConfigDeleteParams): Promise<ConfigDeleteResult> {
    return this.request("config.delete", params);
  }

  configSetBuiltinRuntimes(
    params: ConfigSetBuiltinRuntimesParams,
  ): Promise<ConfigCatalogResult> {
    return this.request("config.set_builtin_runtimes", params);
  }

  configValidate(params: ConfigValidateParams): Promise<ConfigValidateResult> {
    return this.request("config.validate", params);
  }

  taskList(workspaceId: string): Promise<TaskListResult> {
    return this.request("task.list", { workspace_id: workspaceId });
  }

  taskGet(workspaceId: string, taskId: string): Promise<TaskGetResult> {
    return this.request("task.get", { workspace_id: workspaceId, task_id: taskId });
  }

  taskGetAncestry(
    workspaceId: string,
    taskId: string,
  ): Promise<TaskGetAncestryResult> {
    return this.request("task.get_ancestry", {
      workspace_id: workspaceId,
      task_id: taskId,
    });
  }

  taskGetWorktreeCleanupInfo(
    workspaceId: string,
    taskId: string,
  ): Promise<TaskGetWorktreeCleanupInfoResult> {
    return this.request("task.get_worktree_cleanup_info", {
      workspace_id: workspaceId,
      task_id: taskId,
    });
  }

  taskRunHistory(
    workspaceId: string,
    taskId: string,
    nodeRunId: string,
  ): Promise<TaskRunHistoryResult> {
    return this.request("task.run_history", {
      workspace_id: workspaceId,
      task_id: taskId,
      node_run_id: nodeRunId,
    });
  }

  taskRunHistoryFull(
    workspaceId: string,
    taskId: string,
    nodeRunId: string,
  ): Promise<TaskRunHistoryResult> {
    return this.request("task.run_history_full", {
      workspace_id: workspaceId,
      task_id: taskId,
      node_run_id: nodeRunId,
    });
  }

  taskInputRequest(
    workspaceId: string,
    taskId: string,
    nodeRunId: string,
  ): Promise<TaskInputRequestResult> {
    return this.request("task.input_request", {
      workspace_id: workspaceId,
      task_id: taskId,
      node_run_id: nodeRunId,
    });
  }

  taskStart(params: TaskStartParams): Promise<CommandAcceptedResult> {
    return this.request("task.start", params);
  }

  taskStartFollowUp(params: TaskStartFollowUpParams): Promise<CommandAcceptedResult> {
    return this.request("task.start_follow_up", params);
  }

  taskSubmitInput(params: TaskSubmitInputParams): Promise<CommandAcceptedResult> {
    return this.request("task.submit_input", params);
  }

  taskRetryNode(params: TaskRetryNodeParams): Promise<CommandAcceptedResult> {
    return this.request("task.retry_node", params);
  }

  taskContinueBlocked(
    params: TaskContinueBlockedParams,
  ): Promise<CommandAcceptedResult> {
    return this.request("task.continue_blocked", params);
  }

  taskCleanupWorktree(
    params: TaskCleanupWorktreeParams,
  ): Promise<TaskCleanupWorktreeResult> {
    return this.request("task.cleanup_worktree", params);
  }

  taskRecoverStale(params: TaskRecoverStaleParams): Promise<TaskRecoverStaleResult> {
    return this.request("task.recover_stale", params);
  }

  artifactList(workspaceId: string, taskId: string): Promise<ArtifactListResult> {
    return this.request("artifact.list", {
      workspace_id: workspaceId,
      task_id: taskId,
    });
  }

  subscribe(listener: (notification: RuntimeNotification) => void): () => void {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  }

  onConnectionLoss(listener: (error: Error) => void): () => void {
    this.connectionLossListeners.add(listener);
    return () => {
      this.connectionLossListeners.delete(listener);
    };
  }

  private async request<TResult, TParams = unknown>(
    method: string,
    params?: TParams,
  ): Promise<TResult> {
    return invoke<TResult>("app_server_request", { method, params });
  }

  private async ensureSubscriptions(): Promise<void> {
    if (!this.unlistenNotification) {
      this.unlistenNotification = await listen<JsonRpcNotification>(
        notificationEvent,
        (event) => {
          const notification = event.payload;
          const payload = {
            method: notification.method,
            ...(notification.params as NotificationEnvelopeParams | undefined),
          } as RuntimeNotification;
          for (const listener of this.listeners) {
            listener(payload);
          }
        },
      );
    }

    if (!this.unlistenDisconnected) {
      this.unlistenDisconnected = await listen<DisconnectedPayload>(
        disconnectedEvent,
        (event) => {
          const error = new Error(
            event.payload?.message ?? "App server disconnected",
          );
          for (const listener of this.connectionLossListeners) {
            listener(error);
          }
        },
      );
    }
  }
}

class TauriShellHost implements ShellHost {
  async pickDirectory(): Promise<string | null> {
    return invoke<string | null>("pick_directory");
  }

  async readTextFile(path: string): Promise<string> {
    return invoke<string>("read_text_file", { path });
  }

  async readBinaryFile(path: string, maxBytes: number): Promise<Uint8Array> {
    const bytes = await invoke<number[]>("read_binary_file", { path, maxBytes });
    return Uint8Array.from(bytes);
  }

  async openPath(path: string): Promise<void> {
    await invoke("open_path", { path });
  }

  async openExternalUrl(url: string): Promise<void> {
    await invoke("open_url", { url });
  }
}

export function createTauriRuntime(): DesktopRuntime {
  return {
    backend: new TauriTaskBackendClient(),
    shell: new TauriShellHost(),
  };
}
