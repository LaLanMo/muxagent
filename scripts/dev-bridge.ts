import http from "node:http";
import path from "node:path";
import { randomUUID } from "node:crypto";
import { existsSync } from "node:fs";
import { readFile } from "node:fs/promises";
import type { ChildProcessWithoutNullStreams } from "node:child_process";
import { spawn } from "node:child_process";
import { WebSocket, WebSocketServer } from "ws";

type FixtureNodeRun = {
  id: string;
  task_id: string;
  node_name: string;
  status: string;
  started_at: string;
  completed_at?: string;
  failure_reason?: string;
  result?: Record<string, unknown>;
  artifact_paths?: string[];
};

type FixtureTask = {
  task: {
    id: string;
    description: string;
    config_alias: string;
    config_path: string;
    work_dir: string;
    execution_dir: string;
    created_at: string;
    updated_at: string;
    parent_task_id?: string;
    parent_task_description?: string;
  };
  status: string;
  current_node_name: string;
  current_node_type: string;
  current_issue?: {
    kind: string;
    node_name: string;
    iteration: number;
    reason: string;
    occurred_at: string;
  };
  node_runs: FixtureNodeRun[];
  blocked_steps?: Array<Record<string, unknown>>;
};

type FixtureWorkspace = {
  workspace_id: string;
  path: string;
  display_name: string;
  source: string;
  reachable: boolean;
  worktree_available: boolean;
  added_at: string;
  last_opened_at?: string;
  task_counts: {
    running: number;
    awaiting: number;
    done: number;
    failed: number;
  };
  actor: {
    state: string;
    last_error: string;
  };
};

type Session = {
  id: string;
  mode: "fixture" | "spawn";
  process?: ChildProcessWithoutNullStreams;
  sockets: Set<WebSocket>;
  stdoutBuffer: Buffer;
  exitReason?: string;
  fixtureWorkspaces?: FixtureWorkspace[];
  fixtureTasksByWorkspaceId?: Record<string, FixtureTask[]>;
};

const bridgePort = Number(process.env.MUXAGENT_BRIDGE_PORT ?? "4174");
const fixtureMode = process.env.MUXAGENT_BRIDGE_MODE !== "spawn";
const cliPath = process.env.MUXAGENT_CLI_PATH?.trim() || "muxagent";
const sessions = new Map<string, Session>();
const fixtureFileContents = new Map<string, string>();
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

function taskCounts(tasks: FixtureTask[]) {
  const counts = {
    running: 0,
    awaiting: 0,
    done: 0,
    failed: 0,
  };

  for (const task of tasks) {
    const status = task.status.toLowerCase();
    if (["awaiting_user", "awaiting_input", "blocked"].includes(status)) {
      counts.awaiting += 1;
    } else if (["done", "completed", "success"].includes(status)) {
      counts.done += 1;
    } else if (["failed", "error", "cancelled"].includes(status)) {
      counts.failed += 1;
    } else {
      counts.running += 1;
    }
  }

  return counts;
}

function workspaceSummary(
  workspaceId: string,
  workspacePath: string,
  displayName?: string,
): FixtureWorkspace {
  const now = new Date().toISOString();
  return {
    workspace_id: workspaceId,
    path: workspacePath,
    display_name:
      displayName?.trim() || path.basename(workspacePath) || workspacePath,
    source: "user",
    // Fixture mode should stay self-contained and not depend on the host
    // filesystem for synthetic workspaces used by web E2E.
    reachable: fixtureMode ? true : existsSync(workspacePath),
    worktree_available: false,
    added_at: now,
    last_opened_at: now,
    task_counts: {
      running: 0,
      awaiting: 0,
      done: 0,
      failed: 0,
    },
    actor: {
      state: "idle",
      last_error: "",
    },
  };
}

function artifactDirectory(
  workspacePath: string,
  taskId: string,
  nodeRunId: string,
): string {
  return path.join(
    workspacePath,
    ".muxagent",
    "tasks",
    taskId,
    "artifacts",
    nodeRunId,
  );
}

function registerTaskArtifacts(
  workspacePath: string,
  taskId: string,
  description: string,
  nodeRuns: FixtureNodeRun[],
) {
  for (const run of nodeRuns) {
    for (const artifactPath of run.artifact_paths ?? []) {
      const resolved = path.join(artifactDirectory(workspacePath, taskId, run.id), artifactPath);
      if (!fixtureFileContents.has(resolved)) {
        fixtureFileContents.set(
          resolved,
          [
            `# ${description}`,
            "",
            `Task: ${taskId}`,
            `Node: ${run.node_name}`,
            `Artifact: ${artifactPath}`,
            "",
            "Fixture artifact generated by the desktop web bridge.",
          ].join("\n"),
        );
      }
    }
  }
}

function makeFixtureTask(params: {
  workspacePath: string;
  taskId: string;
  description: string;
  configAlias: string;
  createdAt: string;
  updatedAt?: string;
  status: string;
  currentNodeName: string;
  currentNodeType: string;
  nodeRuns: FixtureNodeRun[];
  currentIssue?: FixtureTask["current_issue"];
  blockedSteps?: FixtureTask["blocked_steps"];
}): FixtureTask {
  registerTaskArtifacts(
    params.workspacePath,
    params.taskId,
    params.description,
    params.nodeRuns,
  );

  return {
    task: {
      id: params.taskId,
      description: params.description,
      config_alias: params.configAlias,
      config_path: path.join(
        params.workspacePath,
        ".muxagent",
        "configs",
        `${params.configAlias}.yaml`,
      ),
      work_dir: params.workspacePath,
      execution_dir: params.workspacePath,
      created_at: params.createdAt,
      updated_at: params.updatedAt ?? params.createdAt,
    },
    status: params.status,
    current_node_name: params.currentNodeName,
    current_node_type: params.currentNodeType,
    current_issue: params.currentIssue,
    node_runs: params.nodeRuns,
    blocked_steps: params.blockedSteps,
  };
}

function fixtureTasksForWorkspace(workspacePath: string): FixtureTask[] {
  const base = Date.parse("2026-04-03T03:21:00.000Z");
  const makeTime = (offsetMinutes: number) =>
    new Date(base + offsetMinutes * 60_000).toISOString();

  return [
    makeFixtureTask({
      workspacePath,
      taskId: "task-live-fixture",
      description: "Refactor auth middleware",
      configAlias: "default",
      createdAt: makeTime(0),
      status: "running",
      currentNodeName: "implement",
      currentNodeType: "agent",
      nodeRuns: [
        {
          id: "run-live-plan",
          task_id: "task-live-fixture",
          node_name: "plan",
          status: "done",
          started_at: makeTime(0),
          completed_at: makeTime(2),
          artifact_paths: ["plan.md", "deps.json", "analysis.txt"],
        },
        {
          id: "run-live-implement",
          task_id: "task-live-fixture",
          node_name: "implement",
          status: "running",
          started_at: makeTime(2),
        },
      ],
    }),
    makeFixtureTask({
      workspacePath,
      taskId: "task-running-api",
      description: "Add API endpoint",
      configAlias: "default",
      createdAt: makeTime(6),
      status: "running",
      currentNodeName: "implement",
      currentNodeType: "agent",
      nodeRuns: [
        {
          id: "run-api-plan",
          task_id: "task-running-api",
          node_name: "plan",
          status: "done",
          started_at: makeTime(6),
          completed_at: makeTime(7),
        },
        {
          id: "run-api-implement",
          task_id: "task-running-api",
          node_name: "implement",
          status: "running",
          started_at: makeTime(7),
        },
      ],
    }),
    makeFixtureTask({
      workspacePath,
      taskId: "task-awaiting-pr",
      description: "Review PR #42",
      configAlias: "default",
      createdAt: makeTime(-12),
      status: "awaiting_user",
      currentNodeName: "review",
      currentNodeType: "human",
      nodeRuns: [
        {
          id: "run-awaiting-plan",
          task_id: "task-awaiting-pr",
          node_name: "plan",
          status: "done",
          started_at: makeTime(-12),
          completed_at: makeTime(-11),
        },
        {
          id: "run-awaiting-review",
          task_id: "task-awaiting-pr",
          node_name: "review",
          status: "awaiting_user",
          started_at: makeTime(-11),
        },
      ],
    }),
    makeFixtureTask({
      workspacePath,
      taskId: "task-blocked-db",
      description: "Unblock DB migration",
      configAlias: "default",
      createdAt: makeTime(-30),
      updatedAt: makeTime(-28),
      status: "blocked",
      currentNodeName: "verify",
      currentNodeType: "agent",
      currentIssue: {
        kind: "blocked",
        node_name: "verify",
        iteration: 1,
        reason: "Waiting for migration window",
        occurred_at: makeTime(-28),
      },
      blockedSteps: [
        {
          node_name: "verify",
          iteration: 1,
          reason: "Waiting for migration window",
          created_at: makeTime(-28),
        },
      ],
      nodeRuns: [
        {
          id: "run-blocked-plan",
          task_id: "task-blocked-db",
          node_name: "plan",
          status: "done",
          started_at: makeTime(-30),
          completed_at: makeTime(-29),
        },
        {
          id: "run-blocked-verify",
          task_id: "task-blocked-db",
          node_name: "verify",
          status: "blocked",
          started_at: makeTime(-29),
        },
      ],
    }),
    makeFixtureTask({
      workspacePath,
      taskId: "task-done-login",
      description: "Fix login bug",
      configAlias: "default",
      createdAt: makeTime(-90),
      status: "done",
      currentNodeName: "test",
      currentNodeType: "agent",
      nodeRuns: [
        {
          id: "run-login-plan",
          task_id: "task-done-login",
          node_name: "plan",
          status: "done",
          started_at: makeTime(-90),
          completed_at: makeTime(-88),
        },
        {
          id: "run-login-implement",
          task_id: "task-done-login",
          node_name: "implement",
          status: "done",
          started_at: makeTime(-88),
          completed_at: makeTime(-79),
        },
      ],
    }),
    makeFixtureTask({
      workspacePath,
      taskId: "task-failed-deploy",
      description: "Deploy staging",
      configAlias: "default",
      createdAt: makeTime(-180),
      status: "failed",
      currentNodeName: "verify",
      currentNodeType: "agent",
      nodeRuns: [
        {
          id: "run-deploy-plan",
          task_id: "task-failed-deploy",
          node_name: "plan",
          status: "done",
          started_at: makeTime(-180),
          completed_at: makeTime(-178),
        },
        {
          id: "run-deploy-verify",
          task_id: "task-failed-deploy",
          node_name: "verify",
          status: "failed",
          started_at: makeTime(-178),
          completed_at: makeTime(-176),
          failure_reason: "Health check failed after deploy",
        },
      ],
    }),
  ];
}

function buildFixtureArtifacts(
  workspacePath: string,
  task: FixtureTask,
) {
  return (task.node_runs ?? []).flatMap((run) =>
    (run.artifact_paths ?? []).map((artifactPath) => {
      const resolvedPath = path.join(
        artifactDirectory(workspacePath, task.task.id, run.id),
        artifactPath,
      );
      return {
        task_id: task.task.id,
        node_run_id: run.id,
        node_name: run.node_name,
        source_label: run.node_name,
        raw_path: artifactPath,
        resolved_path: resolvedPath,
        display_path: artifactPath,
        preview_name: artifactPath,
        preview_title: artifactPath,
        markdown: artifactPath.endsWith(".md"),
      };
    }),
  );
}

function respond(id: number | null | undefined, result: unknown) {
  return JSON.stringify({
    jsonrpc: "2.0",
    id,
    result,
  });
}

function fail(id: number | null | undefined, code: number, message: string) {
  return JSON.stringify({
    jsonrpc: "2.0",
    id: id ?? null,
    error: {
      code,
      message,
    },
  });
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

function requireWorkspace(session: Session, workspaceId: string) {
  const workspaces = session.fixtureWorkspaces ?? [];
  return workspaces.find((workspace) => workspace.workspace_id === workspaceId);
}

function fixtureTasks(session: Session, workspaceId: string) {
  return session.fixtureTasksByWorkspaceId?.[workspaceId] ?? [];
}

function handleFixtureRpc(session: Session, payload: Record<string, unknown>) {
  const id = payload.id as number | undefined;
  const method = payload.method as string | undefined;
  const params = (payload.params ?? {}) as Record<string, unknown>;

  switch (method) {
    case "initialize":
      return respond(id, {
        protocol_version: 1,
        server_name: "muxagent app-server",
        server_version: "fixture",
        capabilities: {
          methods: [
            "initialize",
            "service.status",
            "service.shutdown",
            "workspace.list",
            "workspace.add",
            "workspace.get",
            "workspace.update",
            "workspace.remove",
            "config.catalog",
            "task.list",
            "task.get",
            "task.input_request",
            "task.start",
            "task.start_follow_up",
            "task.submit_input",
            "task.retry_node",
            "task.continue_blocked",
            "artifact.list",
          ],
          notifications: ["notification"],
        },
      });
    case "service.status":
      return respond(id, {
        state_dir: "/tmp/muxagent-fixture/appserver",
        server_version: "fixture",
        protocol_version: 1,
        workspace_count: session.fixtureWorkspaces?.length ?? 0,
        runtime_count: 0,
        connected_clients: 1,
      });
    case "workspace.list":
      return respond(id, {
        workspaces: session.fixtureWorkspaces ?? [],
      });
    case "workspace.add": {
      const rawPath = String(params.path ?? "").trim();
      if (!rawPath || !path.isAbsolute(rawPath)) {
        return fail(id, -32602, "path must be an absolute path");
      }
      const normalizedPath = path.resolve(rawPath);
      session.fixtureWorkspaces ??= [];
      session.fixtureTasksByWorkspaceId ??= {};
      const existing = session.fixtureWorkspaces.find(
        (workspace) => path.resolve(workspace.path) === normalizedPath,
      );
      if (existing) {
        return respond(id, { workspace: existing });
      }

      const workspace = workspaceSummary(
        `workspace-${randomUUID().slice(0, 8)}`,
        normalizedPath,
        String(params.display_name ?? ""),
      );
      const tasks = fixtureTasksForWorkspace(normalizedPath);
      workspace.task_counts = taskCounts(tasks);
      session.fixtureWorkspaces.unshift(workspace);
      session.fixtureTasksByWorkspaceId[workspace.workspace_id] = tasks;
      broadcastNotification(session, "workspace.added", workspace.workspace_id, {
        workspace,
      });
      return respond(id, { workspace });
    }
    case "workspace.get": {
      const workspace = requireWorkspace(session, String(params.workspace_id ?? ""));
      if (!workspace) {
        return fail(id, -32010, "workspace not found");
      }
      return respond(id, { workspace });
    }
    case "workspace.update": {
      const workspace = requireWorkspace(session, String(params.workspace_id ?? ""));
      if (!workspace) {
        return fail(id, -32010, "workspace not found");
      }
      const displayName = String(params.display_name ?? "").trim();
      if (displayName) {
        workspace.display_name = displayName;
      }
      broadcastNotification(session, "workspace.updated", workspace.workspace_id, {
        workspace,
      });
      return respond(id, { workspace });
    }
    case "workspace.remove": {
      const workspaceId = String(params.workspace_id ?? "");
      const workspaces = session.fixtureWorkspaces ?? [];
      const index = workspaces.findIndex(
        (workspace) => workspace.workspace_id === workspaceId,
      );
      if (index === -1) {
        return fail(id, -32010, "workspace not found");
      }
      workspaces.splice(index, 1);
      if (session.fixtureTasksByWorkspaceId) {
        delete session.fixtureTasksByWorkspaceId[workspaceId];
      }
      broadcastNotification(session, "workspace.removed", workspaceId, {
        removed: true,
      });
      return respond(id, { removed: true });
    }
    case "config.catalog":
      return respond(id, {
        default_alias: "default",
        default_use_worktree: false,
        entries: [
          {
            alias: "default",
            config_path: "/tmp/muxagent-fixture/default.yaml",
            is_default: true,
            builtin: false,
            launchable: true,
            description: "Agentic workflow with planning, approval, and verification",
            node_names: [
              "draft_plan",
              "review_plan",
              "approve_plan",
              "implement",
              "verify",
              "done",
            ],
          },
        ],
      });
    case "task.list": {
      const workspace = requireWorkspace(session, String(params.workspace_id ?? ""));
      if (!workspace) {
        return fail(id, -32010, "workspace not found");
      }
      return respond(id, { tasks: fixtureTasks(session, workspace.workspace_id) });
    }
    case "task.get": {
      const workspace = requireWorkspace(session, String(params.workspace_id ?? ""));
      if (!workspace) {
        return fail(id, -32010, "workspace not found");
      }
      const taskId = String(params.task_id ?? "");
      const task = fixtureTasks(session, workspace.workspace_id).find(
        (entry) => entry.task.id === taskId,
      );
      if (!task) {
        return fail(id, -32602, "task not found");
      }
      return respond(id, {
        task,
        input_request:
          task.status === "awaiting_user"
            ? {
                kind: "human_node",
                task_id: task.task.id,
                node_run_id: task.node_runs.at(-1)?.id ?? "run-review",
                node_name: task.current_node_name,
              }
            : undefined,
      });
    }
    case "task.input_request": {
      const workspace = requireWorkspace(session, String(params.workspace_id ?? ""));
      if (!workspace) {
        return fail(id, -32010, "workspace not found");
      }
      const taskId = String(params.task_id ?? "");
      const task = fixtureTasks(session, workspace.workspace_id).find(
        (entry) => entry.task.id === taskId,
      );
      if (!task || task.status !== "awaiting_user") {
        return respond(id, { input_request: null });
      }
      return respond(id, {
        input_request: {
          kind: "human_node",
          task_id: task.task.id,
          node_run_id: task.node_runs.at(-1)?.id ?? "run-review",
          node_name: task.current_node_name,
        },
      });
    }
    case "task.start": {
      const workspace = requireWorkspace(session, String(params.workspace_id ?? ""));
      if (!workspace) {
        return fail(id, -32010, "workspace not found");
      }
      const description = String(params.description ?? "").trim();
      if (!description) {
        return fail(id, -32602, "description is required");
      }
      const configAlias = String(params.config_alias ?? "").trim();
      const configPath = String(params.config_path ?? "").trim();
      if (!configAlias || !configPath) {
        return fail(id, -32602, "config_alias and config_path are required");
      }
      const createdAt = new Date().toISOString();
      const taskId = `task-${randomUUID().slice(0, 8)}`;
      const task = makeFixtureTask({
        workspacePath: workspace.path,
        taskId,
        description,
        configAlias,
        createdAt,
        status: "running",
        currentNodeName: "implement",
        currentNodeType: "agent",
        nodeRuns: [
          {
            id: `${taskId}-draft-plan`,
            task_id: taskId,
            node_name: "draft_plan",
            status: "done",
            started_at: createdAt,
            completed_at: createdAt,
            artifact_paths: ["plan.md"],
          },
          {
            id: `${taskId}-implement`,
            task_id: taskId,
            node_name: "implement",
            status: "running",
            started_at: createdAt,
          },
        ],
      });
      session.fixtureTasksByWorkspaceId ??= {};
      session.fixtureTasksByWorkspaceId[workspace.workspace_id] = [
        task,
        ...fixtureTasks(session, workspace.workspace_id),
      ];
      workspace.task_counts = taskCounts(session.fixtureTasksByWorkspaceId[workspace.workspace_id]);
      broadcastNotification(session, "task.created", workspace.workspace_id, {
        client_command_id: String(params.client_command_id ?? ""),
        event: {
          type: "task.created",
          task_id: taskId,
          task_view: task,
        },
      });
      return respond(id, {
        accepted: true,
        client_command_id: String(params.client_command_id ?? ""),
      });
    }
    case "task.start_follow_up": {
      const workspace = requireWorkspace(session, String(params.workspace_id ?? ""));
      if (!workspace) {
        return fail(id, -32010, "workspace not found");
      }
      const parentTaskId = String(params.parent_task_id ?? "").trim();
      if (!parentTaskId) {
        return fail(id, -32602, "parent_task_id is required");
      }
      const parentTask = fixtureTasks(session, workspace.workspace_id).find(
        (entry) => entry.task.id === parentTaskId,
      );
      if (!parentTask) {
        return fail(id, -32602, "parent task not found");
      }
      const description =
        String(params.description ?? "").trim() ||
        `Follow up: ${parentTask.task.description}`;
      const configAlias = String(params.config_alias ?? "").trim() || parentTask.task.config_alias;
      const configPath = String(params.config_path ?? "").trim() || parentTask.task.config_path;
      const createdAt = new Date().toISOString();
      const taskId = `task-${randomUUID().slice(0, 8)}`;
      const task = makeFixtureTask({
        workspacePath: workspace.path,
        taskId,
        description,
        configAlias,
        createdAt,
        status: "running",
        currentNodeName: "implement",
        currentNodeType: "agent",
        nodeRuns: [
          {
            id: `${taskId}-implement`,
            task_id: taskId,
            node_name: "implement",
            status: "running",
            started_at: createdAt,
          },
        ],
      });
      task.task.config_path = configPath;
      task.task.parent_task_id = parentTask.task.id;
      task.task.parent_task_description = parentTask.task.description;
      session.fixtureTasksByWorkspaceId ??= {};
      session.fixtureTasksByWorkspaceId[workspace.workspace_id] = [
        task,
        ...fixtureTasks(session, workspace.workspace_id),
      ];
      workspace.task_counts = taskCounts(session.fixtureTasksByWorkspaceId[workspace.workspace_id]);
      broadcastNotification(session, "task.created", workspace.workspace_id, {
        client_command_id: String(params.client_command_id ?? ""),
        event: {
          type: "task.created",
          task_id: taskId,
          task_view: task,
        },
      });
      return respond(id, {
        accepted: true,
        client_command_id: String(params.client_command_id ?? ""),
      });
    }
    case "task.submit_input": {
      const workspace = requireWorkspace(session, String(params.workspace_id ?? ""));
      if (!workspace) {
        return fail(id, -32010, "workspace not found");
      }
      const taskId = String(params.task_id ?? "");
      const tasks = fixtureTasks(session, workspace.workspace_id);
      const task = tasks.find((entry) => entry.task.id === taskId);
      if (!task) {
        return fail(id, -32602, "task not found");
      }
      const approved = Boolean(
        (params.payload as { approved?: boolean } | undefined)?.approved,
      );
      const now = new Date().toISOString();
      task.status = approved ? "done" : "failed";
      task.current_node_name = approved ? "done" : "approve_plan";
      task.current_node_type = approved ? "agent" : "human";
      task.task.updated_at = now;
      const run = task.node_runs.at(-1);
      if (run) {
        run.status = approved ? "done" : "failed";
        run.completed_at = now;
        run.result = {
          approved,
          ...(params.payload && typeof params.payload === "object"
            ? params.payload
            : {}),
        };
      }
      if (!approved) {
        task.current_issue = {
          kind: "approval_rejected",
          node_name: "approve_plan",
          iteration: 1,
          reason: "Rejected during review",
          occurred_at: now,
        };
      }
      registerTaskArtifacts(workspace.path, taskId, task.task.description, task.node_runs);
      workspace.task_counts = taskCounts(tasks);
      broadcastNotification(session, "task.updated", workspace.workspace_id, {
        client_command_id: String(params.client_command_id ?? ""),
        event: {
          type: "task.updated",
          task_id: taskId,
          task_view: task,
        },
      });
      return respond(id, {
        accepted: true,
        client_command_id: String(params.client_command_id ?? ""),
      });
    }
    case "task.retry_node": {
      const workspace = requireWorkspace(session, String(params.workspace_id ?? ""));
      if (!workspace) {
        return fail(id, -32010, "workspace not found");
      }
      const taskId = String(params.task_id ?? "");
      const nodeRunId = String(params.node_run_id ?? "");
      const tasks = fixtureTasks(session, workspace.workspace_id);
      const task = tasks.find((entry) => entry.task.id === taskId);
      if (!task) {
        return fail(id, -32602, "task not found");
      }
      const run = task.node_runs.find((entry) => entry.id === nodeRunId);
      if (!run) {
        return fail(id, -32602, "node run not found");
      }
      const now = new Date().toISOString();
      const retriedRun: FixtureNodeRun = {
        id: `${taskId}-${run.node_name}-retry-${randomUUID().slice(0, 6)}`,
        task_id: taskId,
        node_name: run.node_name,
        status: "running",
        started_at: now,
      };
      task.node_runs.push(retriedRun);
      task.status = "running";
      task.current_node_name = run.node_name;
      task.current_node_type = "agent";
      task.current_issue = undefined;
      task.blocked_steps = undefined;
      task.task.updated_at = now;
      workspace.task_counts = taskCounts(tasks);
      broadcastNotification(session, "task.updated", workspace.workspace_id, {
        client_command_id: String(params.client_command_id ?? ""),
        event: {
          type: "task.updated",
          task_id: taskId,
          task_view: task,
        },
      });
      return respond(id, {
        accepted: true,
        client_command_id: String(params.client_command_id ?? ""),
      });
    }
    case "task.continue_blocked": {
      const workspace = requireWorkspace(session, String(params.workspace_id ?? ""));
      if (!workspace) {
        return fail(id, -32010, "workspace not found");
      }
      const taskId = String(params.task_id ?? "");
      const tasks = fixtureTasks(session, workspace.workspace_id);
      const task = tasks.find((entry) => entry.task.id === taskId);
      if (!task) {
        return fail(id, -32602, "task not found");
      }
      const blockedNode =
        String(task.blocked_steps?.at(-1)?.node_name ?? "").trim() || task.current_node_name;
      const now = new Date().toISOString();
      task.node_runs.push({
        id: `${taskId}-${blockedNode}-resume-${randomUUID().slice(0, 6)}`,
        task_id: taskId,
        node_name: blockedNode,
        status: "running",
        started_at: now,
      });
      task.status = "running";
      task.current_node_name = blockedNode;
      task.current_node_type = "agent";
      task.current_issue = undefined;
      task.blocked_steps = undefined;
      task.task.updated_at = now;
      workspace.task_counts = taskCounts(tasks);
      broadcastNotification(session, "task.updated", workspace.workspace_id, {
        client_command_id: String(params.client_command_id ?? ""),
        event: {
          type: "task.updated",
          task_id: taskId,
          task_view: task,
        },
      });
      return respond(id, {
        accepted: true,
        client_command_id: String(params.client_command_id ?? ""),
      });
    }
    case "artifact.list": {
      const workspace = requireWorkspace(session, String(params.workspace_id ?? ""));
      if (!workspace) {
        return fail(id, -32010, "workspace not found");
      }
      const taskId = String(params.task_id ?? "");
      const task = fixtureTasks(session, workspace.workspace_id).find(
        (entry) => entry.task.id === taskId,
      );
      if (!task) {
        return fail(id, -32602, "task not found");
      }
      return respond(id, {
        artifacts: buildFixtureArtifacts(workspace.path, task),
      });
    }
    default:
      return fail(id, -32601, `unsupported fixture method ${method ?? ""}`);
  }
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
    session.fixtureWorkspaces = [];
    session.fixtureTasksByWorkspaceId = {};
    return session;
  }

  const child = spawn(cliPath, ["app-server"], {
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
      session.mode === "fixture" ? fixtureFileContents.get(normalized) : null;
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
