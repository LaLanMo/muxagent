import {
  JSON_RPC_VERSION,
  type JsonRpcFailure,
  type JsonRpcId,
  type JsonRpcNotification,
  type JsonRpcRequest,
  type JsonRpcSuccess,
} from "@/rpc/types";

export interface RpcTransport {
  connect(): Promise<void>;
  close(): Promise<void>;
  send(message: JsonRpcRequest): void;
  onMessage(listener: (message: JsonRpcSuccess | JsonRpcFailure | JsonRpcNotification) => void): () => void;
  onDisconnect(listener: (error: Error) => void): () => void;
}

export class RpcClient {
  private nextId = 1;
  private pending = new Map<
    JsonRpcId,
    {
      resolve: (value: unknown) => void;
      reject: (error: Error) => void;
    }
  >();

  private notificationListeners = new Set<(notification: JsonRpcNotification) => void>();
  private disconnectListeners = new Set<(error: Error) => void>();
  private unsubscribe: (() => void) | null = null;
  private unsubscribeDisconnect: (() => void) | null = null;

  constructor(private readonly transport: RpcTransport) {}

  async connect(): Promise<void> {
    await this.transport.connect();
    this.unsubscribeDisconnect = this.transport.onDisconnect((error) => {
      this.failPending(error);
      for (const listener of this.disconnectListeners) {
        listener(error);
      }
    });
    this.unsubscribe = this.transport.onMessage((message) => {
      if ("method" in message && !("id" in message)) {
        for (const listener of this.notificationListeners) {
          listener(message);
        }
        return;
      }

      const responseId = message.id;
      if (typeof responseId !== "number") {
        return;
      }

      const pending = this.pending.get(responseId);
      if (!pending) {
        return;
      }
      this.pending.delete(responseId);

      if ("error" in message) {
        pending.reject(new Error(message.error.message));
        return;
      }

      if (!("result" in message)) {
        pending.reject(new Error("RPC response missing result"));
        return;
      }

      pending.resolve(message.result);
    });
  }

  async close(): Promise<void> {
    this.unsubscribe?.();
    this.unsubscribe = null;
    this.unsubscribeDisconnect?.();
    this.unsubscribeDisconnect = null;
    this.failPending(new Error("RPC transport closed"));
    await this.transport.close();
  }

  request<TResult, TParams = unknown>(
    method: string,
    params?: TParams,
  ): Promise<TResult> {
    const id = this.nextId++;
    const request: JsonRpcRequest<TParams> = {
      jsonrpc: JSON_RPC_VERSION,
      id,
      method,
      params,
    };

    return new Promise<TResult>((resolve, reject) => {
      this.pending.set(id, {
        resolve: (value) => resolve(value as TResult),
        reject,
      });
      try {
        this.transport.send(request);
      } catch (error) {
        this.pending.delete(id);
        reject(error instanceof Error ? error : new Error(String(error)));
      }
    });
  }

  subscribe(listener: (notification: JsonRpcNotification) => void): () => void {
    this.notificationListeners.add(listener);
    return () => {
      this.notificationListeners.delete(listener);
    };
  }

  onDisconnect(listener: (error: Error) => void): () => void {
    this.disconnectListeners.add(listener);
    return () => {
      this.disconnectListeners.delete(listener);
    };
  }

  private failPending(error: Error): void {
    for (const pending of this.pending.values()) {
      pending.reject(error);
    }
    this.pending.clear();
  }
}
