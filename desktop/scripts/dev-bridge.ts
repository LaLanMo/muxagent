import http from "node:http";
import path from "node:path";
import { randomUUID } from "node:crypto";
import { readFile, stat } from "node:fs/promises";
import type { ChildProcessWithoutNullStreams } from "node:child_process";
import { spawn } from "node:child_process";
import { WebSocket, WebSocketServer } from "ws";
import {
  FixtureRuntime,
  type FixtureState,
} from "./dev-bridge/fixture-runtime";

type Session = {
  id: string;
  mode: "fixture" | "spawn";
  process?: ChildProcessWithoutNullStreams;
  sockets: Set<WebSocket>;
  stdoutBuffer: Buffer;
  exitReason?: string;
  fixtureState?: FixtureState;
};

const bridgePort = Number(process.env.MUXAGENT_BRIDGE_PORT ?? "4174");
const fixtureMode = process.env.MUXAGENT_BRIDGE_MODE !== "spawn";
const cliPath = process.env.MUXAGENT_CLI_PATH?.trim() || "muxagent";
const appServerStateDir = process.env.MUXAGENT_APP_SERVER_STATE_DIR?.trim() ?? "";
const sessions = new Map<string, Session>();
const fixtureRuntime = new FixtureRuntime();
let sharedSpawnSessionId: string | null = null;

function encodeFrame(payload: string): Buffer {
  const body = Buffer.from(payload, "utf8");
  return Buffer.concat([
    Buffer.from(`Content-Length: ${body.length}\r\n\r\n`, "utf8"),
    body,
  ]);
}

function extractFrames(session: Session, chunk: Buffer): string[] {
  session.stdoutBuffer = Buffer.concat([session.stdoutBuffer, chunk]);
  const messages: string[] = [];

  while (true) {
    const headerEnd = session.stdoutBuffer.indexOf("\r\n\r\n");
    if (headerEnd === -1) {
      return messages;
    }

    const header = session.stdoutBuffer.subarray(0, headerEnd).toString("utf8");
    const lines = header.split("\r\n");
    let contentLength: number | null = null;
    for (const line of lines) {
      const [name, value] = line.split(":", 2);
      if (name?.trim().toLowerCase() !== "content-length") {
        continue;
      }
      const parsed = Number.parseInt(value?.trim() ?? "", 10);
      if (!Number.isFinite(parsed) || parsed < 0) {
        throw new Error(`invalid Content-Length header: ${line}`);
      }
      contentLength = parsed;
    }

    if (contentLength == null) {
      throw new Error("missing Content-Length header");
    }

    const frameEnd = headerEnd + 4 + contentLength;
    if (session.stdoutBuffer.length < frameEnd) {
      return messages;
    }

    const payload = session.stdoutBuffer
      .subarray(headerEnd + 4, frameEnd)
      .toString("utf8");
    session.stdoutBuffer = session.stdoutBuffer.subarray(frameEnd);
    messages.push(payload);
  }
}

function closeAndClearSessionSockets(
  session: Session,
  code = 1011,
  reason = "bridge session closed",
) {
  for (const socket of session.sockets) {
    if (
      socket.readyState === WebSocket.OPEN ||
      socket.readyState === WebSocket.CONNECTING
    ) {
      socket.close(code, reason);
    }
  }
  session.sockets.clear();
}

function attachSpawnSession(session: Session, child: ChildProcessWithoutNullStreams) {
  child.stdout.on("data", (chunk: Buffer) => {
    try {
      const messages = extractFrames(session, chunk);
      for (const message of messages) {
        for (const socket of session.sockets) {
          if (socket.readyState === WebSocket.OPEN) {
            socket.send(message);
          }
        }
      }
    } catch (error) {
      session.exitReason =
        error instanceof Error ? error.message : "invalid app-server frame";
      void destroySession(session.id);
    }
  });

  child.stderr.on("data", (chunk: Buffer) => {
    process.stderr.write(`[muxagent app-server:${session.id}] ${chunk.toString()}`);
  });

  child.on("error", (error) => {
    if (!sessions.has(session.id)) {
      return;
    }
    sessions.delete(session.id);
    if (sharedSpawnSessionId === session.id) {
      sharedSpawnSessionId = null;
    }
    session.exitReason = `app-server error: ${error.message}`;
    closeAndClearSessionSockets(session, 1011, session.exitReason);
  });

  child.on("exit", (code, signal) => {
    if (!sessions.has(session.id)) {
      return;
    }
    sessions.delete(session.id);
    if (sharedSpawnSessionId === session.id) {
      sharedSpawnSessionId = null;
    }
    session.exitReason = `app-server exited${code != null ? ` (${code})` : signal ? ` (${signal})` : ""}`;
    closeAndClearSessionSockets(session, 1011, session.exitReason);
  });
}

function sendJson(
  res: http.ServerResponse,
  statusCode: number,
  body: Record<string, unknown>,
) {
  res.writeHead(statusCode, {
    "content-type": "application/json",
    "access-control-allow-origin": "*",
    "access-control-allow-methods": "GET,POST,DELETE,OPTIONS",
    "access-control-allow-headers": "content-type",
  });
  res.end(JSON.stringify(body));
}

function sendBinary(
  res: http.ServerResponse,
  statusCode: number,
  body: Uint8Array,
) {
  res.writeHead(statusCode, {
    "content-type": "application/octet-stream",
    "content-length": String(body.byteLength),
    "access-control-allow-origin": "*",
    "access-control-allow-methods": "GET,POST,DELETE,OPTIONS",
    "access-control-allow-headers": "content-type",
  });
  res.end(body);
}

function parseBinaryPreviewLimit(rawValue: string | null): number | null {
  const parsed = Number.parseInt(rawValue?.trim() ?? "", 10);
  if (!Number.isFinite(parsed) || parsed <= 0) {
    return null;
  }
  return parsed;
}

function describeInlinePreviewLimit(maxBytes: number): string {
  const megabytes = maxBytes / (1024 * 1024);
  if (Number.isInteger(megabytes)) {
    return `${megabytes} MB`;
  }
  return `${megabytes.toFixed(1)} MB`;
}

function broadcastNotification(
  session: Session,
  kind: string,
  workspaceId: string | undefined,
  payload: unknown,
) {
  const encoded = JSON.stringify({
    jsonrpc: "2.0",
    method: "notification",
    params: {
      event_id: randomUUID(),
      at: new Date().toISOString(),
      kind,
      ...(workspaceId ? { workspace_id: workspaceId } : {}),
      payload,
    },
  });

  for (const socket of session.sockets) {
    if (socket.readyState === WebSocket.OPEN) {
      socket.send(encoded);
    }
  }
}

function handleFixtureRpc(session: Session, payload: Record<string, unknown>) {
  if (!session.fixtureState) {
    throw new Error("fixture session missing fixture state");
  }
  return fixtureRuntime.handleRpc(session.fixtureState, payload, {
    emitNotification: (kind, workspaceId, params) => {
      broadcastNotification(session, kind, workspaceId, params);
    },
  });
}

async function createSession(): Promise<Session> {
  if (!fixtureMode && sharedSpawnSessionId) {
    const existing = sessions.get(sharedSpawnSessionId);
    if (existing) {
      return existing;
    }
    sharedSpawnSessionId = null;
  }

  const session: Session = {
    id: randomUUID(),
    mode: fixtureMode ? "fixture" : "spawn",
    sockets: new Set(),
    stdoutBuffer: Buffer.alloc(0),
  };

  if (fixtureMode) {
    session.fixtureState = fixtureRuntime.createState();
    return session;
  }

  const args = ["app-server"];
  if (appServerStateDir) {
    args.push("--state-dir", appServerStateDir);
  }

  const child = spawn(cliPath, args, {
    stdio: ["pipe", "pipe", "pipe"],
    env: process.env,
  });
  attachSpawnSession(session, child);
  await new Promise<void>((resolve, reject) => {
    const cleanup = () => {
      child.off("spawn", handleSpawn);
      child.off("error", handleError);
      child.off("exit", handleExit);
    };
    const handleSpawn = () => {
      cleanup();
      resolve();
    };
    const handleError = (error: Error) => {
      cleanup();
      reject(error);
    };
    const handleExit = (code: number | null, signal: NodeJS.Signals | null) => {
      cleanup();
      reject(
        new Error(
          `muxagent app-server exited before bridge attach${
            code != null ? ` (${code})` : signal ? ` (${signal})` : ""
          }`,
        ),
      );
    };

    child.once("spawn", handleSpawn);
    child.once("error", handleError);
    child.once("exit", handleExit);
  });
  session.process = child;
  sharedSpawnSessionId = session.id;
  return session;
}

async function destroySession(sessionId: string): Promise<void> {
  const session = sessions.get(sessionId);
  if (!session) {
    return;
  }
  sessions.delete(sessionId);
  if (sharedSpawnSessionId === sessionId) {
    sharedSpawnSessionId = null;
  }
  closeAndClearSessionSockets(session, 1001, "bridge session closed");
  if (session.process && !session.process.killed) {
    session.process.kill();
  }
}

const server = http.createServer(async (req, res) => {
  if (!req.url || !req.method) {
    sendJson(res, 400, { error: "missing request metadata" });
    return;
  }

  const url = new URL(req.url, `http://127.0.0.1:${bridgePort}`);

  if (req.method === "OPTIONS") {
    sendJson(res, 200, { ok: true });
    return;
  }

  if (req.method === "GET" && url.pathname === "/health") {
    sendJson(res, 200, { ok: true });
    return;
  }

  if (req.method === "POST" && url.pathname === "/bridge/session") {
    try {
      const session = await createSession();
      sessions.set(session.id, session);
      sendJson(res, 200, { session_id: session.id });
    } catch (error) {
      sendJson(res, 500, {
        error:
          error instanceof Error ? error.message : "failed to create bridge session",
      });
    }
    return;
  }

  const sessionMatch = url.pathname.match(/^\/bridge\/session\/([^/]+)$/);
  if (req.method === "DELETE" && sessionMatch) {
    await destroySession(sessionMatch[1]);
    sendJson(res, 200, { ok: true });
    return;
  }

  const fileMatch = url.pathname.match(/^\/bridge\/session\/([^/]+)\/file$/);
  if (req.method === "GET" && fileMatch) {
    const session = sessions.get(fileMatch[1]);
    if (!session) {
      sendJson(res, 404, { error: "session not found" });
      return;
    }
    const requestedPath = url.searchParams.get("path")?.trim() ?? "";
    if (!requestedPath || !path.isAbsolute(requestedPath)) {
      sendJson(res, 400, { error: "path must be an absolute path" });
      return;
    }
    const normalized = path.resolve(requestedPath);
    const fixtureContent =
      session.mode === "fixture"
        ? fixtureRuntime.readFileContent(normalized)
        : null;
    if (fixtureContent != null) {
      sendJson(res, 200, { content: fixtureContent });
      return;
    }
    try {
      const content = await readFile(normalized, "utf8");
      sendJson(res, 200, { content });
    } catch (error) {
      const errno = error as NodeJS.ErrnoException;
      sendJson(res, errno.code === "ENOENT" ? 404 : 500, {
        error:
          error instanceof Error ? error.message : "failed to read file",
      });
    }
    return;
  }

  const binaryFileMatch = url.pathname.match(/^\/bridge\/session\/([^/]+)\/file\/binary$/);
  if (req.method === "GET" && binaryFileMatch) {
    const session = sessions.get(binaryFileMatch[1]);
    if (!session) {
      sendJson(res, 404, { error: "session not found" });
      return;
    }
    const requestedPath = url.searchParams.get("path")?.trim() ?? "";
    if (!requestedPath || !path.isAbsolute(requestedPath)) {
      sendJson(res, 400, { error: "path must be an absolute path" });
      return;
    }
    const maxBytes = parseBinaryPreviewLimit(url.searchParams.get("maxBytes"));
    if (!maxBytes) {
      sendJson(res, 400, { error: "maxBytes must be a positive integer" });
      return;
    }
    const normalized = path.resolve(requestedPath);
    const fixtureContent =
      session.mode === "fixture"
        ? fixtureRuntime.readBinaryFileContent(normalized)
        : null;
    if (fixtureContent) {
      if (fixtureContent.byteLength > maxBytes) {
        sendJson(res, 413, {
          error: `Artifact preview exceeds the ${describeInlinePreviewLimit(maxBytes)} inline limit. Open externally to inspect the full file.`,
        });
        return;
      }
      sendBinary(res, 200, fixtureContent);
      return;
    }
    try {
      const metadata = await stat(normalized);
      if (metadata.size > maxBytes) {
        sendJson(res, 413, {
          error: `Artifact preview exceeds the ${describeInlinePreviewLimit(maxBytes)} inline limit. Open externally to inspect the full file.`,
        });
        return;
      }
      const content = await readFile(normalized);
      sendBinary(res, 200, content);
    } catch (error) {
      const errno = error as NodeJS.ErrnoException;
      sendJson(res, errno.code === "ENOENT" ? 404 : 500, {
        error:
          error instanceof Error ? error.message : "failed to read file",
      });
    }
    return;
  }

  sendJson(res, 404, { error: "not found" });
});

const wss = new WebSocketServer({ noServer: true });

server.on("upgrade", (req, socket, head) => {
  const url = new URL(req.url ?? "/", `http://127.0.0.1:${bridgePort}`);
  const match = url.pathname.match(/^\/bridge\/session\/([^/]+)\/ws$/);
  if (!match) {
    socket.destroy();
    return;
  }

  const session = sessions.get(match[1]);
  if (!session) {
    socket.destroy();
    return;
  }

  wss.handleUpgrade(req, socket, head, (ws) => {
    if (session.exitReason) {
      ws.close(1011, session.exitReason);
      return;
    }
    closeAndClearSessionSockets(session, 1000, "bridge session superseded");
    session.sockets.add(ws);
    ws.on("close", () => {
      session.sockets.delete(ws);
    });
    ws.on("message", (data) => {
      let payload: Record<string, unknown>;
      try {
        payload = JSON.parse(data.toString()) as Record<string, unknown>;
      } catch {
        ws.close(1003, "invalid json-rpc payload");
        return;
      }
      if (session.mode === "fixture") {
        ws.send(handleFixtureRpc(session, payload));
        return;
      }
      if (!session.process || session.process.killed || session.exitReason) {
        ws.close(1011, session.exitReason ?? "bridge session is not available");
        return;
      }
      session.process.stdin.write(encodeFrame(data.toString()));
    });
  });
});

server.listen(bridgePort, "127.0.0.1", () => {
  process.stdout.write(`bridge listening on ${bridgePort}\n`);
});

for (const signal of ["SIGINT", "SIGTERM"] as const) {
  process.on(signal, () => {
    for (const sessionId of sessions.keys()) {
      void destroySession(sessionId);
    }
    server.close(() => {
      process.exit(0);
    });
  });
}
