import type { RpcTransport } from "@/rpc/client";
import type {
  JsonRpcFailure,
  JsonRpcNotification,
  JsonRpcRequest,
  JsonRpcSuccess,
} from "@/rpc/types";

export class BridgeTransport implements RpcTransport {
  private socket: WebSocket | null = null;
  private listeners = new Set<
    (message: JsonRpcSuccess | JsonRpcFailure | JsonRpcNotification) => void
  >();
  private disconnectListeners = new Set<(error: Error) => void>();
  private disconnectNotified = false;

  constructor(private readonly socketUrl: string) {}

  async connect(): Promise<void> {
    if (this.socket && this.socket.readyState === WebSocket.OPEN) {
      return;
    }

    await new Promise<void>((resolve, reject) => {
      const socket = new WebSocket(this.socketUrl);
      this.socket = socket;
      this.disconnectNotified = false;

      const notifyDisconnect = (error: Error) => {
        if (this.disconnectNotified) {
          return;
        }
        this.disconnectNotified = true;
        for (const listener of this.disconnectListeners) {
          listener(error);
        }
      };

      socket.addEventListener("open", () => resolve(), { once: true });
      socket.addEventListener("error", () => {
        const error = new Error("Failed to connect bridge transport");
        reject(error);
        notifyDisconnect(error);
      });
      socket.addEventListener("close", () => {
        this.socket = null;
        notifyDisconnect(new Error("Bridge transport closed"));
      });
      socket.addEventListener("message", (event) => {
        try {
          const message = JSON.parse(event.data as string) as
            | JsonRpcSuccess
            | JsonRpcFailure
            | JsonRpcNotification;
          for (const listener of this.listeners) {
            listener(message);
          }
        } catch (error) {
          notifyDisconnect(
            error instanceof Error
              ? error
              : new Error("Bridge transport received invalid JSON"),
          );
          socket.close();
        }
      });
    });
  }

  async close(): Promise<void> {
    if (!this.socket) {
      return;
    }
    const socket = this.socket;
    this.socket = null;
    await new Promise<void>((resolve) => {
      if (socket.readyState === WebSocket.CLOSED) {
        resolve();
        return;
      }
      socket.addEventListener("close", () => resolve(), { once: true });
      socket.close();
    });
  }

  send(message: JsonRpcRequest): void {
    if (!this.socket || this.socket.readyState !== WebSocket.OPEN) {
      throw new Error("Bridge transport is not connected");
    }
    this.socket.send(JSON.stringify(message));
  }

  onMessage(
    listener: (message: JsonRpcSuccess | JsonRpcFailure | JsonRpcNotification) => void,
  ): () => void {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  }

  onDisconnect(listener: (error: Error) => void): () => void {
    this.disconnectListeners.add(listener);
    return () => {
      this.disconnectListeners.delete(listener);
    };
  }
}
