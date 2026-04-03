import { RpcClient } from "@/rpc/client";
import {
  JSON_RPC_VERSION,
  PROTOCOL_VERSION,
  type ArtifactListResult,
  type CommandAcceptedResult,
  type ConfigCatalogResult,
  type InitializeResult,
  type JsonRpcNotification,
  type NotificationEnvelopeParams,
  type ServiceStatusResult,
  type TaskContinueBlockedParams,
  type TaskStartParams,
  type TaskStartFollowUpParams,
  type TaskSubmitInputParams,
  type TaskGetResult,
  type TaskInputRequestResult,
  type TaskListResult,
  type TaskRetryNodeParams,
  type WorkspaceAddParams,
  type WorkspaceAddResult,
  type WorkspaceGetResult,
  type WorkspaceListResult,
  type WorkspaceRemoveParams,
  type WorkspaceRemoveResult,
  type WorkspaceUpdateParams,
  type WorkspaceUpdateResult,
} from "@/rpc/types";
import type { DesktopRuntime, RuntimeNotification, ShellHost, TaskBackendClient } from "@/platform/contract";
import { BridgeTransport } from "@/platform/browser/bridge-transport";

const bridgeOrigin =
  import.meta.env.VITE_BRIDGE_ORIGIN?.trim() || "http://127.0.0.1:4174";

class BrowserTaskBackendClient implements TaskBackendClient {
  private rpcClient: RpcClient | null = null;
  private sessionId: string | null = null;
  private listeners = new Set<(notification: RuntimeNotification) => void>();
  private connectionLossListeners = new Set<(error: Error) => void>();
  private unsubscribeNotifications: (() => void) | null = null;
  private unsubscribeRpcDisconnect: (() => void) | null = null;

  async connect(): Promise<InitializeResult> {
    await this.disconnect();

    const response = await fetch(`${bridgeOrigin}/bridge/session`, {
      method: "POST",
      headers: {
        "content-type": "application/json",
      },
    });
    if (!response.ok) {
      const payload = (await response.json().catch(() => null)) as
        | { error?: string }
        | null;
      throw new Error(payload?.error ?? "Failed to create bridge session");
    }
    const payload = (await response.json()) as { session_id: string };

    const bridgeUrl = new URL(bridgeOrigin);
    const protocol = bridgeUrl.protocol === "https:" ? "wss" : "ws";
    const transport = new BridgeTransport(
      `${protocol}://${bridgeUrl.host}/bridge/session/${payload.session_id}/ws`,
    );
    const rpcClient = new RpcClient(transport);
    try {
      await rpcClient.connect();
      this.unsubscribeRpcDisconnect = rpcClient.onDisconnect((error) => {
        this.handleConnectionLoss(error);
      });
      const initializeResult = await rpcClient.request<InitializeResult>("initialize", {
        client_name: "muxagent-desktop-browser",
        client_version: "0.1.0",
        protocol_version: PROTOCOL_VERSION,
      });
      this.unsubscribeNotifications = rpcClient.subscribe((notification) => {
        this.forwardNotification(notification);
      });
      this.rpcClient = rpcClient;
      this.sessionId = payload.session_id;
      return initializeResult;
    } catch (error) {
      this.unsubscribeRpcDisconnect?.();
      this.unsubscribeRpcDisconnect = null;
      await rpcClient.close().catch(() => undefined);
      await this.deleteSession(payload.session_id);
      throw error;
    }
  }

  async disconnect(): Promise<void> {
    this.unsubscribeNotifications?.();
    this.unsubscribeNotifications = null;
    this.unsubscribeRpcDisconnect?.();
    this.unsubscribeRpcDisconnect = null;

    const sessionId = this.sessionId;
    this.sessionId = null;

    if (this.rpcClient) {
      await this.rpcClient.close();
      this.rpcClient = null;
    }

    if (sessionId) {
      await this.deleteSession(sessionId);
    }
  }

  status(): Promise<ServiceStatusResult> {
    return this.request("service.status");
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

  workspaceUpdate(params: WorkspaceUpdateParams): Promise<WorkspaceUpdateResult> {
    return this.request("workspace.update", params);
  }

  workspaceRemove(params: WorkspaceRemoveParams): Promise<WorkspaceRemoveResult> {
    return this.request("workspace.remove", params);
  }

  configCatalog(): Promise<ConfigCatalogResult> {
    return this.request("config.catalog");
  }

  taskList(workspaceId: string): Promise<TaskListResult> {
    return this.request("task.list", { workspace_id: workspaceId });
  }

  taskGet(workspaceId: string, taskId: string): Promise<TaskGetResult> {
    return this.request("task.get", { workspace_id: workspaceId, task_id: taskId });
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
    if (!this.rpcClient) {
      throw new Error("Not connected to bridge session");
    }
    return this.rpcClient.request<TResult, TParams>(method, params);
  }

  private forwardNotification(notification: JsonRpcNotification): void {
    const payload = {
      method: notification.method,
      ...(notification.params as NotificationEnvelopeParams | undefined),
    } as RuntimeNotification;
    for (const listener of this.listeners) {
      listener(payload);
    }
  }

  getActiveSessionId(): string | null {
    return this.sessionId;
  }

  private async deleteSession(sessionId: string): Promise<void> {
    await fetch(`${bridgeOrigin}/bridge/session/${sessionId}`, {
      method: "DELETE",
    }).catch(() => undefined);
  }

  private handleConnectionLoss(error: Error): void {
    const lostSessionId = this.sessionId;
    this.sessionId = null;
    this.unsubscribeNotifications?.();
    this.unsubscribeNotifications = null;
    this.unsubscribeRpcDisconnect?.();
    this.unsubscribeRpcDisconnect = null;
    this.rpcClient = null;
    if (lostSessionId) {
      void this.deleteSession(lostSessionId);
    }
    for (const listener of this.connectionLossListeners) {
      listener(error);
    }
  }
}

class BrowserShellHost implements ShellHost {
  constructor(private readonly backend: BrowserTaskBackendClient) {}

  async pickDirectory(): Promise<string | null> {
    return window.prompt("Workspace absolute path")?.trim() ?? null;
  }

  async readTextFile(path: string): Promise<string> {
    const sessionId = this.backend.getActiveSessionId();
    if (!sessionId) {
      throw new Error("No active bridge session");
    }
    const response = await fetch(
      `${bridgeOrigin}/bridge/session/${sessionId}/file?path=${encodeURIComponent(path)}`,
    );
    if (!response.ok) {
      const payload = (await response.json().catch(() => null)) as
        | { error?: string }
        | null;
      throw new Error(payload?.error ?? "Failed to read file");
    }
    const payload = (await response.json()) as { content: string };
    return payload.content;
  }

  async openPath(path: string): Promise<void> {
    window.open(`file://${path}`, "_blank", "noopener,noreferrer");
  }
}

export function createBrowserRuntime(): DesktopRuntime {
  const backend = new BrowserTaskBackendClient();
  return {
    backend,
    shell: new BrowserShellHost(backend),
  };
}

export const browserRuntime = createBrowserRuntime();

export { JSON_RPC_VERSION };
