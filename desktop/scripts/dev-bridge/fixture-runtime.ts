import path from "node:path";
import { randomUUID } from "node:crypto";

export type FixtureNodeRun = {
  id: string;
  task_id: string;
  node_name: string;
  status: string;
  started_at: string;
  completed_at?: string;
  session_id?: string;
  failure_reason?: string;
  result?: Record<string, unknown>;
  clarifications?: Array<{
    created_at?: string;
    responded_at?: string;
    request?: {
      questions?: Array<{
        question?: string;
        why_it_matters?: string;
        options?: Array<{ label: string; description?: string }>;
        multi_select?: boolean;
      }>;
    };
    response?: {
      answers?: Array<{ selected?: string | string[] }>;
    };
  }>;
  artifact_paths?: string[];
};

type FixtureMcpOutputBlock = {
  type: string;
  label?: string;
  text?: string;
  json?: string;
  data_url?: string;
  mime_type?: string;
};

type FixtureMcpTool = {
  server?: string;
  tool?: string;
  arguments_json?: string;
  structured_content_json?: string;
  output_blocks?: FixtureMcpOutputBlock[];
  debug_json?: string;
};

export type FixtureTask = {
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
  follow_up?: {
    default_mode: "continue_here" | "fork_head" | "fork_with_changes";
    available_modes: Array<"continue_here" | "fork_head" | "fork_with_changes">;
    uncommitted_change_count: number;
  };
  follow_up_state?: "basic" | "refine" | "disabled";
  worktree_cleanup_state?: "available" | "blocked" | "missing" | "not_applicable";
  current_issue?: {
    kind: string;
    node_name: string;
    iteration: number;
    reason: string;
    occurred_at: string;
  };
  input_request?: {
    kind: string;
    task_id: string;
    node_run_id: string;
    node_name: string;
    questions?: Array<{
      question: string;
      why_it_matters?: string;
      options?: Array<{ label: string; description?: string }>;
      multi_select?: boolean;
    }>;
  };
  node_runs: FixtureNodeRun[];
  task_artifact_paths?: string[];
  live_events?: Array<{
    event_id?: string;
    seq?: number;
    emitted_at?: string;
    recorded_at?: string;
    session_id?: string;
    provider_record_id?: string;
    provider_subindex?: number;
    provenance?: string;
    kind: "message" | "tool" | "plan" | "usage" | "raw";
    raw?: string;
    message_id?: string;
    part_id?: string;
    role?: string;
    part_type?: string;
    text?: string;
    call_id?: string;
    parent_call_id?: string;
    name?: string;
    tool_kind?: string;
    title?: string;
    status?: string;
    input_summary?: string;
    output_text?: string;
    error_text?: string;
    paths?: string[];
    diffs?: Array<{
      path?: string;
      old_text?: string;
      new_text?: string;
    }>;
    raw_input_json?: string;
    raw_output_json?: string;
    mcp?: FixtureMcpTool;
    plan_id?: string;
    steps?: Array<{ text: string; status?: string }>;
    input_tokens?: number;
    cached_input_tokens?: number;
    output_tokens?: number;
    total_tokens?: number;
    duration_ms?: number;
  }>;
  live_output_run_id?: string;
  blocked_steps?: Array<Record<string, unknown>>;
  run_history_by_run_id?: Record<
    string,
    Array<{
      event_id?: string;
      seq?: number;
      emitted_at?: string;
      recorded_at?: string;
      session_id?: string;
      provider_record_id?: string;
      provider_subindex?: number;
      provenance?: string;
      kind: "message" | "tool" | "plan" | "usage" | "raw";
      raw?: string;
      message_id?: string;
      part_id?: string;
      role?: string;
      part_type?: string;
      text?: string;
      call_id?: string;
      parent_call_id?: string;
      name?: string;
      tool_kind?: string;
      title?: string;
      status?: string;
      input_summary?: string;
      output_text?: string;
      error_text?: string;
      paths?: string[];
      diffs?: Array<{
        path?: string;
        old_text?: string;
        new_text?: string;
      }>;
      raw_input_json?: string;
      raw_output_json?: string;
      mcp?: FixtureMcpTool;
      plan_id?: string;
      steps?: Array<{ text: string; status?: string }>;
      input_tokens?: number;
      cached_input_tokens?: number;
      output_tokens?: number;
      total_tokens?: number;
      duration_ms?: number;
    }>
  >;
};

function normalizeFixtureTaskPath(pathValue: string | undefined): string {
  return (pathValue ?? "").replace(/\\/g, "/").replace(/\/+$/, "");
}

export function deriveFixtureFollowUpState(
  task: FixtureTask,
): FixtureTask["follow_up_state"] | undefined {
  if (task.follow_up_state) {
    return task.follow_up_state;
  }
  if (task.status !== "done") {
    return undefined;
  }
  if (task.follow_up) {
    return "refine";
  }
  const workDir = normalizeFixtureTaskPath(task.task.work_dir);
  const executionDir = normalizeFixtureTaskPath(task.task.execution_dir);
  return executionDir && workDir && executionDir !== workDir ? "disabled" : "basic";
}

export function deriveFixtureWorktreeCleanupInfo(
  task: FixtureTask,
  tasks: FixtureTask[],
) {
  const workDir = normalizeFixtureTaskPath(task.task.work_dir);
  const executionDir = normalizeFixtureTaskPath(task.task.execution_dir);
  const isWorktreeTask = Boolean(workDir && executionDir && workDir !== executionDir);

  if (task.worktree_cleanup_state === "missing") {
    return {
      state: "missing",
      shared_task_count: 0,
      dirty_count: 0,
      can_remove: false,
      message: "Worktree is already unavailable.",
    } as const;
  }
  if (task.status !== "done" || !isWorktreeTask) {
    return {
      state: "not_applicable",
      shared_task_count: 0,
      dirty_count: 0,
      can_remove: false,
      message: "This task does not use a dedicated worktree.",
    } as const;
  }

  const group = tasks.filter((entry) => {
    if (entry.worktree_cleanup_state === "missing") {
      return false;
    }
    const entryWorkDir = normalizeFixtureTaskPath(entry.task.work_dir);
    const entryExecutionDir = normalizeFixtureTaskPath(entry.task.execution_dir);
    return Boolean(
      entryWorkDir &&
        entryExecutionDir &&
        entryWorkDir !== entryExecutionDir &&
        entryExecutionDir === executionDir,
    );
  });
  const blockedBy = group
    .filter(
      (entry) =>
        entry.task.id !== task.task.id &&
        (entry.status === "running" || entry.status === "awaiting_user"),
    )
    .map((entry) => ({
      task_id: entry.task.id,
      description: entry.task.description,
      status: entry.status,
    }));
  const sharedTaskCount = Math.max(group.length, 1);
  const removalScope =
    sharedTaskCount > 1 ? "shared_worktree" : "single_worktree";
  const dirtyCount = task.follow_up?.uncommitted_change_count ?? 0;
  if (blockedBy.length > 0) {
    return {
      state: "blocked",
      worktree_group_id: executionDir,
      worktree_root: executionDir,
      shared_task_count: sharedTaskCount,
      dirty_count: dirtyCount,
      blocked_by: blockedBy,
      removal_scope: removalScope,
      can_remove: false,
      message: `Worktree is still in use by ${blockedBy.length} active task${blockedBy.length === 1 ? "" : "s"}.`,
    } as const;
  }
  return {
    state: "available",
    worktree_group_id: executionDir,
    worktree_root: executionDir,
    shared_task_count: sharedTaskCount,
    dirty_count: dirtyCount,
    blocked_by: [],
    removal_scope: removalScope,
    can_remove: true,
    message:
      removalScope === "shared_worktree"
        ? `Remove the shared worktree used by ${sharedTaskCount} tasks.`
        : "Remove this worktree.",
  } as const;
}

export type FixtureWorkspace = {
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

export type FixtureState = {
  workspaces: FixtureWorkspace[];
  tasksByWorkspaceId: Record<string, FixtureTask[]>;
  pendingSyncCompletionByWorkspaceId: Record<string, boolean>;
  configs: FixtureConfig[];
  runtimes: FixtureRuntimeOption[];
  runtimeStatus: FixtureRuntimeStatus;
};

type FixtureRuntimeOption = {
  runtime_id: string;
  runtime_name: string;
  command?: string;
  args?: string[];
  configured: boolean;
};

type FixtureRuntimeStatus = {
  automatic: FixtureRuntimeAutomatic;
  runtimes: FixtureRuntimeStatusEntry[];
};

type FixtureRuntimeAutomatic = {
  runtime_id: string;
  runtime_name: string;
  launcher?: string;
  available: boolean;
  detected: boolean;
};

type FixtureRuntimeStatusEntry = {
  runtime_id: string;
  runtime_name: string;
  launcher?: string;
  available: boolean;
};

type FixtureConfigDraft = {
  version: number;
  description?: string;
  runtime?: string;
  clarification: {
    max_questions: number;
    max_options_per_question: number;
    min_options_per_question: number;
  };
  topology: {
    max_iterations: number;
    entry: string;
    nodes: Array<{
      name: string;
      max_iterations?: number;
      join?: string;
    }>;
    edges: Array<{
      from: string;
      to: string;
      when?: {
        kind?: string;
        field?: string;
        equals?: unknown;
      };
    }>;
  };
  node_definitions: Record<
    string,
    {
      type?: string;
      system_prompt?: string;
      max_clarification_rounds?: number;
      result_schema: Record<string, unknown>;
    }
  >;
};

type FixtureConfig = {
  alias: string;
  config_path: string;
  bundle_path: string;
  is_default: boolean;
  builtin: boolean;
  builtin_id?: string;
  revision: string;
  config: FixtureConfigDraft;
  prompts: Record<string, string>;
};

type FixtureRuntimeOptions = {
  stateDir?: string;
};

type FixtureNotificationEmitter = (
  kind: string,
  workspaceId: string | undefined,
  payload: unknown,
) => void;

type HandleFixtureRpcOptions = {
  emitNotification: FixtureNotificationEmitter;
};

type FixtureHistoryEvent = NonNullable<
  NonNullable<FixtureTask["run_history_by_run_id"]>[string]
>[number];

function fixtureHistoryProvenance(
  events:
    | NonNullable<FixtureTask["run_history_by_run_id"]>[string]
    | undefined,
): string {
  const values = [...new Set((events ?? []).map((event) => event.provenance).filter(Boolean))];
  if (values.length === 0) {
    return "none";
  }
  if (values.length === 1) {
    return values[0] ?? "none";
  }
  return "mixed_recovered";
}

function compactFixtureHistoryText(
  value: string | undefined,
  limit: number,
): string | undefined {
  const trimmed = value?.replace(/\s+/g, " ").trim();
  if (!trimmed) {
    return undefined;
  }
  if (limit <= 0 || trimmed.length <= limit) {
    return trimmed;
  }
  if (limit <= 1) {
    return trimmed.slice(0, limit);
  }
  return `${trimmed.slice(0, limit - 1)}…`;
}

function summarizeFixtureHistoryEvent(event: FixtureHistoryEvent): FixtureHistoryEvent {
  return {
    ...event,
    raw: event.kind === "raw" ? compactFixtureHistoryText(event.raw, 600) : undefined,
    text: compactFixtureHistoryText(event.text, 600),
    input_summary: compactFixtureHistoryText(event.input_summary, 240),
    output_text: compactFixtureHistoryText(event.output_text, 600),
    error_text: compactFixtureHistoryText(event.error_text, 400),
    raw_input_json: undefined,
    raw_output_json: undefined,
    mcp: undefined,
    diffs: undefined,
    paths: undefined,
    steps: event.steps?.map((step) => ({
      ...step,
      text: compactFixtureHistoryText(step.text, 240) ?? "",
    })),
  };
}

const encoder = new TextEncoder();
const fixtureImageExtensions = new Set([
  ".png",
  ".jpg",
  ".jpeg",
  ".gif",
  ".webp",
  ".bmp",
  ".svg",
]);

function artifactPathExtension(artifactPath: string): string {
  const normalized = artifactPath.trim().replace(/\\/g, "/").toLowerCase();
  const basename = normalized.slice(normalized.lastIndexOf("/") + 1);
  const dotIndex = basename.lastIndexOf(".");
  return dotIndex > 0 ? basename.slice(dotIndex) : "";
}

function isFixtureImageArtifactPath(artifactPath: string): boolean {
  return fixtureImageExtensions.has(artifactPathExtension(artifactPath));
}

function escapeSvgText(value: string): string {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");
}

function buildFixtureImageArtifactBytes(args: {
  description: string;
  taskId: string;
  nodeLabel: string;
  artifactPath: string;
}): Uint8Array {
  const normalizedPath = args.artifactPath.toLowerCase();
  const dimensions = normalizedPath.includes("tiny")
    ? { width: 128, height: 112 }
    : normalizedPath.includes("portrait") || normalizedPath.includes("long")
      ? { width: 420, height: 1180 }
      : normalizedPath.includes("panorama") || normalizedPath.includes("wide")
        ? { width: 1680, height: 420 }
        : { width: 1280, height: 880 };
  const svg = [
    `<svg xmlns="http://www.w3.org/2000/svg" width="${dimensions.width}" height="${dimensions.height}" viewBox="0 0 ${dimensions.width} ${dimensions.height}" fill="none">`,
    '  <defs>',
    '    <linearGradient id="fixture-bg" x1="0" y1="0" x2="1" y2="1">',
    '      <stop offset="0%" stop-color="#f7f1ed" />',
    '      <stop offset="100%" stop-color="#efe3db" />',
    '    </linearGradient>',
    '    <linearGradient id="fixture-panel" x1="0" y1="0" x2="1" y2="0">',
    '      <stop offset="0%" stop-color="#fbf8f6" stop-opacity="0.96" />',
    '      <stop offset="100%" stop-color="#f3ebe6" stop-opacity="0.98" />',
    "    </linearGradient>",
    "  </defs>",
    `  <rect width="${dimensions.width}" height="${dimensions.height}" rx="32" fill="url(#fixture-bg)" />`,
    `  <rect x="28" y="28" width="${dimensions.width - 56}" height="${dimensions.height - 56}" rx="26" fill="url(#fixture-panel)" stroke="#d6c9c1" />`,
    `  <rect x="56" y="64" width="${Math.max(180, Math.round(dimensions.width * 0.34))}" height="20" rx="10" fill="#d2c2b8" opacity="0.45" />`,
    `  <rect x="56" y="108" width="${Math.max(240, Math.round(dimensions.width * 0.5))}" height="44" rx="20" fill="#2f2824" />`,
    `  <rect x="56" y="182" width="${dimensions.width - 112}" height="${Math.max(90, Math.round(dimensions.height * 0.18))}" rx="24" fill="#efe2da" />`,
    `  <rect x="56" y="${Math.round(dimensions.height * 0.48)}" width="${Math.max(180, Math.round(dimensions.width * 0.3))}" height="${Math.max(120, Math.round(dimensions.height * 0.28))}" rx="28" fill="#d7e3ef" />`,
    `  <rect x="${Math.round(dimensions.width * 0.42)}" y="${Math.round(dimensions.height * 0.48)}" width="${Math.round(dimensions.width * 0.24)}" height="${Math.max(120, Math.round(dimensions.height * 0.18))}" rx="28" fill="#f3cfa9" />`,
    `  <rect x="${Math.round(dimensions.width * 0.69)}" y="${Math.round(dimensions.height * 0.48)}" width="${Math.round(dimensions.width * 0.19)}" height="${Math.max(120, Math.round(dimensions.height * 0.34))}" rx="28" fill="#cddabf" />`,
    `  <text x="60" y="138" fill="#fbf8f6" font-family="Geist, Arial, sans-serif" font-size="28" font-weight="600">${escapeSvgText(args.description)}</text>`,
    `  <text x="60" y="${Math.round(dimensions.height - 84)}" fill="#6e625c" font-family="Geist Mono, monospace" font-size="20">Task ${escapeSvgText(args.taskId)} · ${escapeSvgText(args.nodeLabel)} · ${escapeSvgText(args.artifactPath)}</text>`,
    `  <text x="60" y="${Math.round(dimensions.height - 48)}" fill="#8d7f78" font-family="Geist Mono, monospace" font-size="16">Fixture image artifact generated by the desktop web bridge.</text>`,
    "</svg>",
  ].join("\n");
  return encoder.encode(svg);
}

export class FixtureRuntime {
  private readonly fileContents = new Map<string, string>();
  private readonly binaryFileContents = new Map<string, Uint8Array>();
  private readonly stateDir: string;

  constructor(options: FixtureRuntimeOptions = {}) {
    this.stateDir = options.stateDir ?? "/tmp/muxagent-fixture/appserver";
  }

  createState(): FixtureState {
    return {
      workspaces: [],
      tasksByWorkspaceId: {},
      pendingSyncCompletionByWorkspaceId: {},
      configs: this.defaultConfigs(),
      runtimes: this.defaultRuntimes(),
      runtimeStatus: this.defaultRuntimeStatus(),
    };
  }

  private applyPendingSyncCompletion(state: FixtureState, workspaceId: string) {
    if (!state.pendingSyncCompletionByWorkspaceId[workspaceId]) {
      return;
    }
    const syncTask = this.fixtureTasks(state, workspaceId).find(
      (entry) => entry.task.id === "task-sync-fixture",
    );
    if (!syncTask || syncTask.status === "done") {
      delete state.pendingSyncCompletionByWorkspaceId[workspaceId];
      return;
    }
    const completedAt = new Date().toISOString();
    syncTask.status = "done";
    syncTask.current_node_name = "done";
    syncTask.current_node_type = "terminal";
    syncTask.task.updated_at = completedAt;
    syncTask.live_events = [];
    syncTask.live_output_run_id = undefined;
    const implementRun = syncTask.node_runs.find(
      (entry) => entry.id === "run-sync-implement",
    );
    if (implementRun) {
      implementRun.status = "done";
      implementRun.completed_at = completedAt;
    }
    if (!syncTask.node_runs.some((entry) => entry.id === "run-sync-done")) {
      syncTask.node_runs.push({
        id: "run-sync-done",
        task_id: syncTask.task.id,
        node_name: "done",
        status: "done",
        started_at: completedAt,
        completed_at: completedAt,
      });
    }
    delete state.pendingSyncCompletionByWorkspaceId[workspaceId];
  }

  readFileContent(normalizedPath: string): string | null {
    return this.fileContents.get(normalizedPath) ?? null;
  }

  readBinaryFileContent(normalizedPath: string): Uint8Array | null {
    const binary = this.binaryFileContents.get(normalizedPath);
    if (binary) {
      return binary;
    }
    const text = this.fileContents.get(normalizedPath);
    return text != null ? encoder.encode(text) : null;
  }

  handleRpc(
    state: FixtureState,
    payload: Record<string, unknown>,
    options: HandleFixtureRpcOptions,
  ): string {
    const id = payload.id as number | undefined;
    const method = payload.method as string | undefined;
    const params = (payload.params ?? {}) as Record<string, unknown>;

    switch (method) {
      case "initialize":
        return this.respond(id, {
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
              "workspace.git_status",
              "workspace.checkout_status",
              "workspace.file_diff",
              "workspace.commit_diff",
              "workspace.reconcile_stale",
              "workspace.update",
              "workspace.remove",
              "config.catalog",
              "config.get",
              "config.clone",
              "config.rename",
              "config.delete",
              "config.reset",
              "config.set_builtin_runtimes",
              "config.validate",
              "config.save",
              "config.prompt.get",
              "config.prompt.save",
              "runtime.list",
              "runtime.status",
              "task.list",
              "task.get",
              "task.get_ancestry",
              "task.get_worktree_cleanup_info",
              "task.run_history",
              "task.run_history_full",
              "task.input_request",
              "task.start",
              "task.cleanup_worktree",
              "task.recover_stale",
              "artifact.list",
            ],
            notifications: ["notification"],
          },
        });
      case "service.status":
        return this.respond(id, {
          state_dir: this.stateDir,
          server_version: "fixture",
          protocol_version: 1,
          workspace_count: state.workspaces.length,
          runtime_count: state.runtimes.length,
          connected_clients: 1,
        });
      case "workspace.list":
        return this.respond(id, {
          workspaces: state.workspaces,
        });
      case "workspace.add": {
        const rawPath = String(params.path ?? "").trim();
        if (!rawPath || !path.isAbsolute(rawPath)) {
          return this.fail(id, -32602, "path must be an absolute path");
        }
        const normalizedPath = path.resolve(rawPath);
        const existing = state.workspaces.find(
          (workspace) => path.resolve(workspace.path) === normalizedPath,
        );
        if (existing) {
          return this.respond(id, { workspace: existing });
        }

        const workspace = this.workspaceSummary(
          `workspace-${randomUUID().slice(0, 8)}`,
          normalizedPath,
          String(params.display_name ?? ""),
        );
        const tasks = this.fixtureTasksForWorkspace(normalizedPath);
        workspace.task_counts = this.taskCounts(tasks);
        workspace.actor = this.workspaceActor(tasks);
        state.workspaces.unshift(workspace);
        state.tasksByWorkspaceId[workspace.workspace_id] = tasks;
        options.emitNotification("workspace.added", workspace.workspace_id, {
          workspace,
        });
        return this.respond(id, { workspace });
      }
      case "workspace.get": {
        const workspace = this.requireWorkspace(
          state,
          String(params.workspace_id ?? ""),
        );
        if (!workspace) {
          return this.fail(id, -32010, "workspace not found");
        }
        return this.respond(id, { workspace });
      }
      case "workspace.git_status": {
        const workspace = this.requireWorkspace(
          state,
          String(params.workspace_id ?? ""),
        );
        if (!workspace) {
          return this.fail(id, -32010, "workspace not found");
        }
        return this.respond(id, this.fixtureWorkspaceGitStatus(workspace));
      }
      case "workspace.checkout_status": {
        const workspace = this.requireWorkspace(
          state,
          String(params.workspace_id ?? ""),
        );
        if (!workspace) {
          return this.fail(id, -32010, "workspace not found");
        }
        const checkoutPath = String(params.checkout_path ?? "").trim();
        if (!checkoutPath) {
          return this.fail(id, -32602, "checkout_path is required");
        }
        const result = this.fixtureWorkspaceCheckoutStatus(workspace, checkoutPath);
        if (!result) {
          return this.fail(id, -32602, "checkout_path is not part of this workspace");
        }
        return this.respond(id, result);
      }
      case "workspace.file_diff": {
        const workspace = this.requireWorkspace(
          state,
          String(params.workspace_id ?? ""),
        );
        if (!workspace) {
          return this.fail(id, -32010, "workspace not found");
        }
        const checkoutPath = String(params.checkout_path ?? "").trim();
        const filePath = String(params.file_path ?? "").trim();
        if (!checkoutPath) {
          return this.fail(id, -32602, "checkout_path is required");
        }
        if (!filePath) {
          return this.fail(id, -32602, "file_path is required");
        }
        const bucket = String(params.bucket ?? "").trim();
        return this.respond(id, this.fixtureFileDiff(filePath, bucket));
      }
      case "workspace.commit_diff": {
        const workspace = this.requireWorkspace(
          state,
          String(params.workspace_id ?? ""),
        );
        if (!workspace) {
          return this.fail(id, -32010, "workspace not found");
        }
        const checkoutPath = String(params.checkout_path ?? "").trim();
        const commitHash = String(params.commit_hash ?? "").trim();
        if (!checkoutPath) {
          return this.fail(id, -32602, "checkout_path is required");
        }
        if (!commitHash) {
          return this.fail(id, -32602, "commit_hash is required");
        }
        return this.respond(id, this.fixtureCommitDiff(commitHash));
      }
      case "workspace.reconcile_stale": {
        const workspace = this.requireWorkspace(
          state,
          String(params.workspace_id ?? ""),
        );
        if (!workspace) {
          return this.fail(id, -32010, "workspace not found");
        }
        if (workspace.actor.state === "active") {
          return this.respond(id, { outcome: "busy" });
        }
        const tasks = this.fixtureTasks(state, workspace.workspace_id);
        const runningRuns = tasks.flatMap((task) =>
          task.node_runs.filter((run) => run.status === "running"),
        );
        if (runningRuns.length === 0) {
          return this.respond(id, { outcome: "noop" });
        }
        const recoveredAt = new Date().toISOString();
        for (const task of tasks) {
          for (const run of task.node_runs) {
            if (run.status !== "running") {
              continue;
            }
            run.status = "failed";
            run.failure_reason = "orphaned_after_restart";
            run.completed_at = recoveredAt;
            task.status = "failed";
            task.current_issue = {
              kind: "failed_run",
              node_name: run.node_name,
              iteration: 1,
              reason: "orphaned_after_restart",
              occurred_at: recoveredAt,
            };
            task.task.updated_at = recoveredAt;
            task.live_events = [];
            task.live_output_run_id = undefined;
          }
        }
        workspace.task_counts = this.taskCounts(tasks);
        workspace.actor = this.workspaceActor(tasks);
        return this.respond(id, { outcome: "reconciled" });
      }
      case "workspace.update": {
        const workspace = this.requireWorkspace(
          state,
          String(params.workspace_id ?? ""),
        );
        if (!workspace) {
          return this.fail(id, -32010, "workspace not found");
        }
        const displayName = String(params.display_name ?? "").trim();
        if (displayName) {
          workspace.display_name = displayName;
        }
        options.emitNotification("workspace.updated", workspace.workspace_id, {
          workspace,
        });
        return this.respond(id, { workspace });
      }
      case "workspace.remove": {
        const workspaceId = String(params.workspace_id ?? "");
        const index = state.workspaces.findIndex(
          (workspace) => workspace.workspace_id === workspaceId,
        );
        if (index === -1) {
          return this.fail(id, -32010, "workspace not found");
        }
        state.workspaces.splice(index, 1);
        delete state.tasksByWorkspaceId[workspaceId];
        delete state.pendingSyncCompletionByWorkspaceId[workspaceId];
        options.emitNotification("workspace.removed", workspaceId, {
          removed: true,
        });
        return this.respond(id, { removed: true });
      }
      case "config.catalog":
        return this.respond(id, {
          default_alias:
            state.configs.find((config) => config.is_default)?.alias ?? "default",
          default_use_worktree: false,
          entries: state.configs.map((config) => this.configCatalogEntry(state, config)),
        });
      case "config.set_builtin_runtimes": {
        const runtimeId = String(params.runtime_id ?? "").trim();
        if (!runtimeId) {
          return this.fail(id, -32602, "runtime_id is required");
        }
        const knownStatus = state.runtimeStatus.runtimes.find(
          (entry) => entry.runtime_id === runtimeId,
        );
        if (!knownStatus) {
          return this.fail(id, -32602, `runtime ${runtimeId} is not supported`);
        }
        const existing = state.runtimes.find(
          (runtime) => runtime.runtime_id === runtimeId,
        );
        if (existing) {
          existing.configured = true;
        } else {
          state.runtimes.push({
            runtime_id: runtimeId,
            runtime_name: knownStatus.runtime_name,
            command: knownStatus.launcher ?? runtimeId,
            configured: true,
          });
        }
        for (const config of state.configs) {
          if (config.builtin) {
            config.config.runtime = runtimeId;
            config.revision = randomUUID();
          }
        }
        return this.respond(id, {
          default_alias:
            state.configs.find((config) => config.is_default)?.alias ?? "default",
          default_use_worktree: false,
          entries: state.configs.map((config) => this.configCatalogEntry(state, config)),
        });
      }
      case "config.get": {
        const config = this.requireConfig(state, String(params.alias ?? ""));
        if (!config) {
          return this.fail(id, -32011, "config not found");
        }
        return this.respond(id, { entry: this.configDetail(state, config) });
      }
      case "config.clone": {
        const source = this.requireConfig(state, String(params.source_alias ?? ""));
        if (!source) {
          return this.fail(id, -32011, "config not found");
        }
        const nextAlias = String(params.new_alias ?? "").trim();
        if (!nextAlias) {
          return this.fail(id, -32602, "new_alias is required");
        }
        if (this.requireConfig(state, nextAlias)) {
          return this.fail(id, -32602, "config alias already exists");
        }
        const cloned: FixtureConfig = {
          ...source,
          alias: nextAlias,
          config_path: this.configPath(nextAlias),
          bundle_path: this.bundlePath(nextAlias),
          is_default: false,
          builtin: false,
          builtin_id: undefined,
          revision: randomUUID(),
          config: structuredClone(source.config),
          prompts: structuredClone(source.prompts),
        };
        state.configs.push(cloned);
        return this.respond(id, { entry: this.configDetail(state, cloned) });
      }
      case "config.rename": {
        const config = this.requireConfig(state, String(params.alias ?? ""));
        if (!config) {
          return this.fail(id, -32011, "config not found");
        }
        if (config.builtin) {
          return this.fail(id, -32602, "built-in configs cannot be renamed");
        }
        const nextAlias = String(params.new_alias ?? "").trim();
        if (!nextAlias) {
          return this.fail(id, -32602, "new_alias is required");
        }
        if (state.configs.some((entry) => entry.alias === nextAlias && entry !== config)) {
          return this.fail(id, -32602, "config alias already exists");
        }
        config.alias = nextAlias;
        config.config_path = this.configPath(nextAlias);
        config.bundle_path = this.bundlePath(nextAlias);
        config.revision = randomUUID();
        return this.respond(id, { entry: this.configDetail(state, config) });
      }
      case "config.delete": {
        const config = this.requireConfig(state, String(params.alias ?? ""));
        if (!config) {
          return this.fail(id, -32011, "config not found");
        }
        if (config.builtin) {
          return this.fail(id, -32602, "built-in configs cannot be deleted");
        }
        state.configs = state.configs.filter((entry) => entry !== config);
        return this.respond(id, { removed: true });
      }
      case "config.reset": {
        const config = this.requireConfig(state, String(params.alias ?? ""));
        if (!config) {
          return this.fail(id, -32011, "config not found");
        }
        if (!config.builtin) {
          return this.fail(id, -32602, "config is not builtin");
        }
        const reset = this.resetBuiltinConfig(config);
        config.revision = reset.revision;
        config.config = reset.config;
        config.prompts = reset.prompts;
        return this.respond(id, { entry: this.configDetail(state, config) });
      }
      case "config.validate": {
        const config = params.config as FixtureConfigDraft | undefined;
        if (!config) {
          return this.fail(id, -32602, "config is required");
        }
        const validation = this.validateConfig(state, config);
        return this.respond(id, validation);
      }
      case "config.save": {
        const configEntry = this.requireConfig(state, String(params.alias ?? ""));
        if (!configEntry) {
          return this.fail(id, -32011, "config not found");
        }
        const expectedRevision = String(params.expected_revision ?? "");
        if (!expectedRevision || expectedRevision !== configEntry.revision) {
          return this.fail(id, -32009, "config has changed; reload and try again");
        }
        const config = params.config as FixtureConfigDraft | undefined;
        if (!config) {
          return this.fail(id, -32602, "config is required");
        }
        const validation = this.validateConfig(state, config);
        if (!validation.valid) {
          return this.fail(id, -32602, validation.error ?? "config is invalid");
        }
        configEntry.config = structuredClone(config);
        configEntry.revision = randomUUID();
        return this.respond(id, { entry: this.configDetail(state, configEntry) });
      }
      case "config.prompt.get": {
        const config = this.requireConfig(state, String(params.alias ?? ""));
        if (!config) {
          return this.fail(id, -32011, "config not found");
        }
        const prompt = this.resolveFixturePrompt(
          config,
          String(params.node_name ?? ""),
        );
        if ("error" in prompt) {
          return this.fail(id, -32602, prompt.error);
        }
        return this.respond(id, { prompt });
      }
      case "config.prompt.save": {
        const config = this.requireConfig(state, String(params.alias ?? ""));
        if (!config) {
          return this.fail(id, -32011, "config not found");
        }
        const prompt = this.resolveFixturePrompt(
          config,
          String(params.node_name ?? ""),
        );
        if ("error" in prompt) {
          return this.fail(id, -32602, prompt.error);
        }
        const expectedRevision = String(params.expected_revision ?? "");
        if ((prompt.revision ?? "") !== expectedRevision) {
          return this.fail(id, -32009, "prompt has changed; reload and try again");
        }
        const content = String(params.content ?? "");
        if (!content.trim()) {
          return this.fail(id, -32602, "content is required");
        }
        config.prompts[prompt.path] = content;
        return this.respond(id, {
          prompt: this.buildFixturePrompt(config, prompt.node_name, prompt.path, content),
        });
      }
      case "runtime.list":
        return this.respond(id, {
          runtimes: state.runtimes.map((runtime) => ({
            runtime_id: runtime.runtime_id,
            runtime_name: runtime.runtime_name,
            command: runtime.command,
            args: runtime.args,
          })),
        });
      case "runtime.status":
        return this.respond(id, state.runtimeStatus);
      case "task.list": {
        const workspace = this.requireWorkspace(
          state,
          String(params.workspace_id ?? ""),
        );
        if (!workspace) {
          return this.fail(id, -32010, "workspace not found");
        }
        this.applyPendingSyncCompletion(state, workspace.workspace_id);
        return this.respond(id, {
          tasks: this.fixtureTasks(state, workspace.workspace_id),
        });
      }
      case "task.get": {
        const workspace = this.requireWorkspace(
          state,
          String(params.workspace_id ?? ""),
        );
        if (!workspace) {
          return this.fail(id, -32010, "workspace not found");
        }
        const taskId = String(params.task_id ?? "");
        const task = this.fixtureTasks(state, workspace.workspace_id).find(
          (entry) => entry.task.id === taskId,
        );
        if (!task) {
          return this.fail(id, -32602, "task not found");
        }
        return this.respond(id, {
          task,
          config: this.taskConfigView(state, task),
          input_request: task.input_request,
          follow_up: task.follow_up,
          follow_up_state: deriveFixtureFollowUpState(task),
          live_events: task.live_events,
          live_output_run_id: task.live_output_run_id,
        });
      }
      case "task.get_ancestry": {
        const workspace = this.requireWorkspace(
          state,
          String(params.workspace_id ?? ""),
        );
        if (!workspace) {
          return this.fail(id, -32010, "workspace not found");
        }
        const taskId = String(params.task_id ?? "");
        const task = this.fixtureTasks(state, workspace.workspace_id).find(
          (entry) => entry.task.id === taskId,
        );
        if (!task) {
          return this.fail(id, -32602, "task not found");
        }
        return this.respond(id, {
          ancestors: this.fixtureTaskAncestry(state, workspace.workspace_id, task),
        });
      }
      case "task.get_worktree_cleanup_info": {
        const workspace = this.requireWorkspace(
          state,
          String(params.workspace_id ?? ""),
        );
        if (!workspace) {
          return this.fail(id, -32010, "workspace not found");
        }
        const taskId = String(params.task_id ?? "");
        const tasks = this.fixtureTasks(state, workspace.workspace_id);
        const task = tasks.find((entry) => entry.task.id === taskId);
        if (!task) {
          return this.fail(id, -32602, "task not found");
        }
        return this.respond(id, {
          info: deriveFixtureWorktreeCleanupInfo(task, tasks),
        });
      }
      case "task.run_history": {
        const workspace = this.requireWorkspace(
          state,
          String(params.workspace_id ?? ""),
        );
        if (!workspace) {
          return this.fail(id, -32010, "workspace not found");
        }
        const taskId = String(params.task_id ?? "");
        const nodeRunId = String(params.node_run_id ?? "");
        const task = this.fixtureTasks(state, workspace.workspace_id).find(
          (entry) => entry.task.id === taskId,
        );
        if (!task) {
          return this.fail(id, -32602, "task not found");
        }
        const run = task.node_runs.find((entry) => entry.id === nodeRunId);
        if (!run) {
          return this.fail(id, -32602, "node run not found");
        }
        const events = task.run_history_by_run_id?.[nodeRunId] ?? [];
        return this.respond(id, {
          task_id: taskId,
          node_run_id: nodeRunId,
          session_id:
            run.session_id ??
            events.find((event) => event.session_id?.trim())?.session_id,
          provenance: fixtureHistoryProvenance(events),
          completeness:
            run.status !== "running" && run.status !== "awaiting_user"
              ? "complete"
              : events.length
              ? "open"
              : "none",
          last_seq: events[(events.length || 1) - 1]?.seq ?? 0,
          events: events.map((event) => summarizeFixtureHistoryEvent(event)),
        });
      }
      case "task.run_history_full": {
        const workspace = this.requireWorkspace(
          state,
          String(params.workspace_id ?? ""),
        );
        if (!workspace) {
          return this.fail(id, -32010, "workspace not found");
        }
        const taskId = String(params.task_id ?? "");
        const nodeRunId = String(params.node_run_id ?? "");
        const task = this.fixtureTasks(state, workspace.workspace_id).find(
          (entry) => entry.task.id === taskId,
        );
        if (!task) {
          return this.fail(id, -32602, "task not found");
        }
        const run = task.node_runs.find((entry) => entry.id === nodeRunId);
        if (!run) {
          return this.fail(id, -32602, "node run not found");
        }
        const events = task.run_history_by_run_id?.[nodeRunId] ?? [];
        return this.respond(id, {
          task_id: taskId,
          node_run_id: nodeRunId,
          session_id:
            run.session_id ??
            events.find((event) => event.session_id?.trim())?.session_id,
          provenance: fixtureHistoryProvenance(events),
          completeness:
            run.status !== "running" && run.status !== "awaiting_user"
              ? "complete"
              : events.length
                ? "open"
                : "none",
          last_seq: events[(events.length || 1) - 1]?.seq ?? 0,
          events,
        });
      }
      case "task.input_request": {
        const workspace = this.requireWorkspace(
          state,
          String(params.workspace_id ?? ""),
        );
        if (!workspace) {
          return this.fail(id, -32010, "workspace not found");
        }
        const taskId = String(params.task_id ?? "");
        const task = this.fixtureTasks(state, workspace.workspace_id).find(
          (entry) => entry.task.id === taskId,
        );
        if (!task || !task.input_request) {
          return this.respond(id, { input_request: null });
        }
        return this.respond(id, {
          input_request: task.input_request,
        });
      }
      case "task.start": {
        const workspace = this.requireWorkspace(
          state,
          String(params.workspace_id ?? ""),
        );
        if (!workspace) {
          return this.fail(id, -32010, "workspace not found");
        }
        const description = String(params.description ?? "").trim();
        if (!description) {
          return this.fail(id, -32602, "description is required");
        }
        const configAlias = String(params.config_alias ?? "").trim();
        const configPath = String(params.config_path ?? "").trim();
        if (!configAlias || !configPath) {
          return this.fail(id, -32602, "config_alias and config_path are required");
        }
        if (path.basename(workspace.path) === "muxagent-sync-workspace") {
          state.pendingSyncCompletionByWorkspaceId[workspace.workspace_id] = true;
        }
        const createdAt = new Date().toISOString();
        const taskId = `task-${randomUUID().slice(0, 8)}`;
        const task = this.makeFixtureTask({
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
        state.tasksByWorkspaceId[workspace.workspace_id] = [
          task,
          ...this.fixtureTasks(state, workspace.workspace_id),
        ];
        workspace.task_counts = this.taskCounts(
          state.tasksByWorkspaceId[workspace.workspace_id],
        );
        workspace.actor = this.workspaceActor(
          state.tasksByWorkspaceId[workspace.workspace_id],
        );
        options.emitNotification("task.created", workspace.workspace_id, {
          client_command_id: String(params.client_command_id ?? ""),
          event: {
            type: "task.created",
            task_id: taskId,
            task_view: task,
          },
        });
        return this.respond(id, {
          accepted: true,
          client_command_id: String(params.client_command_id ?? ""),
        });
      }
      case "task.cleanup_worktree": {
        const workspace = this.requireWorkspace(
          state,
          String(params.workspace_id ?? ""),
        );
        if (!workspace) {
          return this.fail(id, -32010, "workspace not found");
        }
        const taskId = String(params.task_id ?? "");
        const tasks = this.fixtureTasks(state, workspace.workspace_id);
        const task = tasks.find((entry) => entry.task.id === taskId);
        if (!task) {
          return this.fail(id, -32602, "task not found");
        }
        const info = deriveFixtureWorktreeCleanupInfo(task, tasks);
        if (info.state === "not_applicable") {
          return this.respond(id, { outcome: "not_applicable", info });
        }
        if (info.state === "missing") {
          return this.respond(id, { outcome: "missing", info });
        }
        if (info.state === "blocked") {
          return this.respond(id, { outcome: "blocked", info });
        }
        const executionDir = normalizeFixtureTaskPath(task.task.execution_dir);
        const updatedAt = new Date().toISOString();
        for (const entry of tasks) {
          if (normalizeFixtureTaskPath(entry.task.execution_dir) !== executionDir) {
            continue;
          }
          entry.worktree_cleanup_state = "missing";
          entry.follow_up = undefined;
          entry.follow_up_state = "disabled";
          entry.task.updated_at = updatedAt;
        }
        return this.respond(id, {
          outcome: "removed",
          info: deriveFixtureWorktreeCleanupInfo(task, tasks),
        });
      }
      case "task.start_follow_up": {
        const workspace = this.requireWorkspace(
          state,
          String(params.workspace_id ?? ""),
        );
        if (!workspace) {
          return this.fail(id, -32010, "workspace not found");
        }
        const parentTaskId = String(params.parent_task_id ?? "");
        const parentTask = this.fixtureTasks(state, workspace.workspace_id).find(
          (entry) => entry.task.id === parentTaskId,
        );
        if (!parentTask) {
          return this.fail(id, -32602, "parent task not found");
        }
        const description = String(params.description ?? "").trim();
        if (!description) {
          return this.fail(id, -32602, "description is required");
        }
        const configAlias =
          String(params.config_alias ?? "").trim() || parentTask.task.config_alias;
        const configPath =
          String(params.config_path ?? "").trim() || parentTask.task.config_path;
        const followUpMode =
          String(params.follow_up_mode ?? "").trim() || "continue_here";
        if (!configAlias || !configPath) {
          return this.fail(id, -32602, "config_alias and config_path are required");
        }

        const createdAt = new Date().toISOString();
        const taskId = `task-${randomUUID().slice(0, 8)}`;
        const isQuickConfig = configAlias === "quick";
        const task = this.makeFixtureTask({
          workspacePath: workspace.path,
          taskId,
          description,
          configAlias,
          createdAt,
          status: "running",
          currentNodeName: isQuickConfig ? "inspect" : "implement",
          currentNodeType: "agent",
          taskArtifactPaths: [`follow-up-mode-${followUpMode}.md`],
          nodeRuns: isQuickConfig
            ? [
                {
                  id: `${taskId}-inspect`,
                  task_id: taskId,
                  node_name: "inspect",
                  status: "running",
                  started_at: createdAt,
                },
              ]
            : [
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
        task.task.parent_task_id = parentTaskId;
        task.task.parent_task_description = parentTask.task.description;
        task.task.config_path = configPath;
        state.tasksByWorkspaceId[workspace.workspace_id] = [
          task,
          ...this.fixtureTasks(state, workspace.workspace_id),
        ];
        workspace.task_counts = this.taskCounts(
          state.tasksByWorkspaceId[workspace.workspace_id],
        );
        workspace.actor = this.workspaceActor(
          state.tasksByWorkspaceId[workspace.workspace_id],
        );
        options.emitNotification("task.created", workspace.workspace_id, {
          client_command_id: String(params.client_command_id ?? ""),
          event: {
            type: "task.created",
            task_id: taskId,
            task_view: task,
          },
        });
        return this.respond(id, {
          accepted: true,
          client_command_id: String(params.client_command_id ?? ""),
        });
      }
      case "task.recover_stale": {
        const workspace = this.requireWorkspace(
          state,
          String(params.workspace_id ?? ""),
        );
        if (!workspace) {
          return this.fail(id, -32010, "workspace not found");
        }
        const taskId = String(params.task_id ?? "");
        const nodeRunId = String(params.node_run_id ?? "");
        const task = this.fixtureTasks(state, workspace.workspace_id).find(
          (entry) => entry.task.id === taskId,
        );
        if (!task) {
          return this.fail(id, -32602, "task not found");
        }
        const run = task.node_runs.find((entry) => entry.id === nodeRunId);
        if (!run) {
          return this.fail(id, -32602, "node run not found");
        }
        if (!["running", "awaiting_user"].includes(run.status)) {
          return this.respond(id, { outcome: "already_terminal" });
        }
        if (workspace.actor.state === "active") {
          return this.respond(id, { outcome: "busy" });
        }

        const recoveredAt = new Date().toISOString();
        run.status = "failed";
        run.failure_reason = "orphaned_after_restart";
        run.completed_at = recoveredAt;
        task.status = "failed";
        task.current_issue = {
          kind: "failed_run",
          node_name: run.node_name,
          iteration: 1,
          reason: "orphaned_after_restart",
          occurred_at: recoveredAt,
        };
        task.task.updated_at = recoveredAt;
        task.live_events = [];
        task.live_output_run_id = undefined;
        workspace.task_counts = this.taskCounts(
          state.tasksByWorkspaceId[workspace.workspace_id],
        );
        workspace.actor = this.workspaceActor(
          state.tasksByWorkspaceId[workspace.workspace_id],
        );

        return this.respond(id, { outcome: "recovered_failed" });
      }
      case "artifact.list": {
        const workspace = this.requireWorkspace(
          state,
          String(params.workspace_id ?? ""),
        );
        if (!workspace) {
          return this.fail(id, -32010, "workspace not found");
        }
        const taskId = String(params.task_id ?? "");
        const task = this.fixtureTasks(state, workspace.workspace_id).find(
          (entry) => entry.task.id === taskId,
        );
        if (!task) {
          return this.fail(id, -32602, "task not found");
        }
        return this.respond(id, {
          artifacts: this.buildFixtureArtifacts(workspace.path, task),
        });
      }
      default:
        return this.fail(id, -32601, `unsupported fixture method ${method ?? ""}`);
    }
  }

  private taskCounts(tasks: FixtureTask[]) {
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

  private workspaceActor(tasks: FixtureTask[]) {
    const hasAttachedExecutor = tasks.some(
      (task) =>
        task.status === "running" &&
        (Boolean(task.live_output_run_id) ||
          (task.live_events?.length ?? 0) > 0 ||
          task.node_runs.some(
            (run) =>
              run.status === "running" && Boolean(run.session_id?.trim()),
          )),
    );
    return {
      state: hasAttachedExecutor ? "active" : "cold",
      last_error: "",
    };
  }

  private requireConfig(state: FixtureState, alias: string): FixtureConfig | undefined {
    return state.configs.find((config) => config.alias === alias.trim());
  }

  private taskConfigView(state: FixtureState, task: FixtureTask) {
    const config =
      this.requireConfig(state, task.task.config_alias) ??
      state.configs.find((entry) => entry.config_path === task.task.config_path);
    if (!config) {
      return undefined;
    }
    const materializedConfig = structuredClone(config.config);
    if (!materializedConfig.runtime?.trim()) {
      const automaticRuntimeId = state.runtimeStatus.automatic.runtime_id.trim();
      if (automaticRuntimeId) {
        materializedConfig.runtime = automaticRuntimeId;
      }
    }
    return {
      path: task.task.config_path,
      config: materializedConfig,
    };
  }

  private resolveRuntime(state: FixtureState, runtimeId?: string) {
    if (runtimeId?.trim()) {
      return (
        state.runtimes.find((runtime) => runtime.runtime_id === runtimeId.trim()) ?? {
          runtime_id: runtimeId.trim(),
          runtime_name: runtimeId.trim(),
          configured: false,
        }
      );
    }
    return (
      state.runtimes.find((runtime) => runtime.configured) ?? {
        runtime_id: "automatic",
        runtime_name: "Automatic",
        configured: false,
      }
    );
  }

  private configCatalogEntry(state: FixtureState, config: FixtureConfig) {
    const runtime = this.resolveRuntime(state, config.config.runtime);
    return {
      alias: config.alias,
      bundle_path: config.bundle_path,
      config_path: config.config_path,
      is_default: config.is_default,
      runtime_id: runtime.runtime_id,
      runtime_name: runtime.runtime_name,
      runtime_explicit: Boolean(config.config.runtime?.trim()),
      runtime_configured: runtime.configured,
      node_names: config.config.topology.nodes.map((node) => node.name),
      builtin_id: config.builtin_id,
      builtin: config.builtin,
      description: config.config.description ?? "",
      launchable: runtime.configured,
    };
  }

  private configDetail(state: FixtureState, config: FixtureConfig) {
    const entry = this.configCatalogEntry(state, config);
    return {
      ...entry,
      revision: config.revision,
      config: structuredClone(config.config),
    };
  }

  private resolveFixturePrompt(config: FixtureConfig, nodeName: string) {
    const trimmedNodeName = nodeName.trim();
    if (!trimmedNodeName) {
      return { error: "node_name is required" } as const;
    }
    const definition = config.config.node_definitions[trimmedNodeName];
    if (!definition) {
      return { error: `node ${trimmedNodeName} does not exist` } as const;
    }
    if (definition.type !== "agent") {
      return {
        error: `node ${trimmedNodeName} does not support prompt editing`,
      } as const;
    }
    const promptPath = String(definition.system_prompt ?? "").trim();
    if (!promptPath) {
      return { error: "node prompt path is not set" } as const;
    }
    const exists = Object.prototype.hasOwnProperty.call(config.prompts, promptPath);
    const content = exists ? config.prompts[promptPath] : "";
    return this.buildFixturePrompt(
      config,
      trimmedNodeName,
      promptPath,
      content,
      exists,
    );
  }

  private buildFixturePrompt(
    config: FixtureConfig,
    nodeName: string,
    promptPath: string,
    content: string,
    exists = true,
  ) {
    return {
      alias: config.alias,
      node_name: nodeName,
      node_type: "agent",
      path: promptPath,
      resolved_path: path.join(config.bundle_path, promptPath.replace(/^\.\//, "")),
      content,
      revision: exists ? promptRevision(content) : "",
      readonly: false,
      builtin: config.builtin,
    };
  }

  private resetBuiltinConfig(config: FixtureConfig): Pick<FixtureConfig, "config" | "prompts" | "revision"> {
    switch (config.builtin_id) {
      case "builtin-default": {
        const builtin = this.defaultConfigs().find((entry) => entry.builtin_id === "builtin-default");
        if (!builtin) {
          throw new Error("missing default builtin fixture");
        }
        return {
          config: structuredClone(builtin.config),
          prompts: structuredClone(builtin.prompts),
          revision: randomUUID(),
        };
      }
      default:
        throw new Error(`unsupported builtin fixture reset for ${config.builtin_id ?? "unknown"}`);
    }
  }

  private validateConfig(state: FixtureState, config: FixtureConfigDraft) {
    const nodeNames = config.topology.nodes.map((node) => node.name.trim());
    const uniqueNames = new Set(nodeNames);
    if (nodeNames.length === 0) {
      return {
        valid: false,
        runtime_configured: true,
        error: "At least one node is required",
      };
    }
    if (nodeNames.some((name) => !name)) {
      return {
        valid: false,
        runtime_configured: true,
        error: "Node names cannot be empty",
      };
    }
    if (uniqueNames.size !== nodeNames.length) {
      return {
        valid: false,
        runtime_configured: true,
        error: "Node names must be unique",
      };
    }
    if (!uniqueNames.has(config.topology.entry)) {
      return {
        valid: false,
        runtime_configured: true,
        error: "Entry node must reference an existing node",
      };
    }
    for (const node of nodeNames) {
      const definition = config.node_definitions[node];
      if (!definition) {
        return {
          valid: false,
          runtime_configured: true,
          error: `Missing node definition for ${node}`,
        };
      }
      if (definition.type === "agent" && !String(definition.system_prompt ?? "").trim()) {
        return {
          valid: false,
          runtime_configured: true,
          error: `Agent node ${node} must define a prompt file`,
        };
      }
      if (definition.type !== "agent" && String(definition.system_prompt ?? "").trim()) {
        return {
          valid: false,
          runtime_configured: true,
          error: `Only agent nodes can define a prompt file`,
        };
      }
    }
    for (const edge of config.topology.edges) {
      if (!uniqueNames.has(edge.from) || !uniqueNames.has(edge.to)) {
        return {
          valid: false,
          runtime_configured: true,
          error: "All edges must reference existing nodes",
        };
      }
      if (edge.when?.kind === "when" && !String(edge.when.field ?? "").trim()) {
        return {
          valid: false,
          runtime_configured: true,
          error: "Conditional edges require a field name",
        };
      }
    }
    const runtime = this.resolveRuntime(state, config.runtime);
    const runtimeConfigured = runtime.configured;
    return {
      valid: runtimeConfigured,
      config: structuredClone(config),
      runtime_id: runtime.runtime_id,
      runtime_name: runtime.runtime_name,
      runtime_configured: runtimeConfigured,
      error: runtimeConfigured ? undefined : "Selected runtime is not configured",
    };
  }

  private configPath(alias: string): string {
    return path.join("/tmp/muxagent-fixture/taskconfigs", `${alias}.yaml`);
  }

  private bundlePath(alias: string): string {
    return path.join("/tmp/muxagent-fixture/taskconfigs", alias);
  }

  private defaultRuntimes(): FixtureRuntimeOption[] {
    return [
      {
        runtime_id: "yolo",
        runtime_name: "yolo",
        command: "muxagent-runtime-yolo",
        configured: true,
      },
      {
        runtime_id: "claude",
        runtime_name: "claude",
        command: "claude",
        configured: true,
      },
      {
        runtime_id: "missing-runtime",
        runtime_name: "missing-runtime",
        command: "missing-runtime",
        configured: false,
      },
    ];
  }

  private defaultRuntimeStatus(): FixtureRuntimeStatus {
    return {
      automatic: {
        runtime_id: "codex",
        runtime_name: "Codex",
        launcher: "codex",
        available: true,
        detected: true,
      },
      runtimes: [
        {
          runtime_id: "codex",
          runtime_name: "Codex",
          launcher: "codex",
          available: true,
        },
        {
          runtime_id: "claude-code",
          runtime_name: "Claude Code",
          launcher: "claude",
          available: true,
        },
        {
          runtime_id: "opencode",
          runtime_name: "OpenCode",
          launcher: "opencode",
          available: false,
        },
      ],
    };
  }

  private defaultConfigs(): FixtureConfig[] {
    const baseConfig = (runtime?: string): FixtureConfigDraft => ({
      version: 1,
      description: "Agentic workflow with planning, approval, and verification",
      runtime,
      clarification: {
        max_questions: 3,
        min_options_per_question: 2,
        max_options_per_question: 4,
      },
      topology: {
        max_iterations: 14,
        entry: "draft_plan",
        nodes: [
          { name: "draft_plan" },
          { name: "review_plan" },
          { name: "approve_plan", max_iterations: 1 },
          { name: "implement" },
          { name: "verify" },
          { name: "done" },
        ],
        edges: [
          { from: "draft_plan", to: "review_plan" },
          { from: "review_plan", to: "approve_plan" },
          { from: "approve_plan", to: "implement" },
          { from: "implement", to: "verify" },
          { from: "verify", to: "done" },
          {
            from: "verify",
            to: "implement",
            when: { kind: "when", field: "retry", equals: true },
          },
        ],
      },
      node_definitions: {
        draft_plan: {
          type: "agent",
          system_prompt: "./prompts/draft_plan.md",
          max_clarification_rounds: 1,
          result_schema: { type: "object", properties: { plan: { type: "string" } } },
        },
        review_plan: {
          type: "agent",
          system_prompt: "./prompts/review_plan.md",
          max_clarification_rounds: 1,
          result_schema: { type: "object", properties: { review: { type: "string" } } },
        },
        approve_plan: {
          type: "human",
          max_clarification_rounds: 0,
          result_schema: { type: "object", properties: { approved: { type: "boolean" } } },
        },
        implement: {
          type: "agent",
          system_prompt: "./prompts/implement.md",
          max_clarification_rounds: 2,
          result_schema: { type: "object", properties: { summary: { type: "string" } } },
        },
        verify: {
          type: "agent",
          system_prompt: "./prompts/verify.md",
          max_clarification_rounds: 1,
          result_schema: { type: "object", properties: { retry: { type: "boolean" } } },
        },
        done: {
          type: "terminal",
          system_prompt: "",
          max_clarification_rounds: 0,
          result_schema: { type: "object", properties: {} },
        },
      },
    });

    return [
      {
        alias: "default",
        config_path: this.configPath("default"),
        bundle_path: this.bundlePath("default"),
        is_default: true,
        builtin: true,
        builtin_id: "builtin-default",
        revision: randomUUID(),
        config: baseConfig(),
        prompts: {
          "./prompts/draft_plan.md": "Draft the initial plan.",
          "./prompts/review_plan.md": "Review the plan.",
          "./prompts/implement.md": "Implement the approved changes.",
          "./prompts/verify.md": "Verify the result.",
        },
      },
      {
        alias: "quick",
        config_path: this.configPath("quick"),
        bundle_path: this.bundlePath("quick"),
        is_default: false,
        builtin: false,
        revision: randomUUID(),
        config: {
          ...baseConfig("claude"),
          description: "Shorter loop for quick issue triage.",
          topology: {
            max_iterations: 8,
            entry: "inspect",
            nodes: [{ name: "inspect" }, { name: "verify" }, { name: "done" }],
            edges: [
              { from: "inspect", to: "verify" },
              { from: "verify", to: "done" },
            ],
          },
          node_definitions: {
            inspect: {
              type: "agent",
              system_prompt: "./prompts/inspect.md",
              max_clarification_rounds: 1,
              result_schema: { type: "object", properties: { findings: { type: "string" } } },
            },
            verify: {
              type: "agent",
              system_prompt: "./prompts/verify.md",
              max_clarification_rounds: 0,
              result_schema: { type: "object", properties: { ok: { type: "boolean" } } },
            },
            done: {
              type: "terminal",
              system_prompt: "",
              max_clarification_rounds: 0,
              result_schema: { type: "object", properties: {} },
            },
          },
        },
        prompts: {
          "./prompts/inspect.md": "Inspect the issue quickly.",
          "./prompts/verify.md": "Verify the quick fix.",
        },
      },
    ];
  }

  private workspaceSummary(
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
      reachable: true,
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
        state: "cold",
        last_error: "",
      },
    };
  }

  private fixtureWorkspaceGitStatus(workspace: FixtureWorkspace) {
    const now = new Date().toISOString();
    if (path.basename(workspace.path) === "muxagent-source-control") {
      const managedRoot = path.join("/tmp", ".muxagent", "worktrees", "fixture-repo");
      const featPath = path.join(managedRoot, "feat-auth-refactor");
      const fixPath = path.join(managedRoot, "fix-session-ttl");
      const pocPath = path.join("/tmp", "poc-experiment");
      return {
        main: {
          role: "main",
          path: workspace.path,
          reachable: true,
          branch: "main",
          upstream: "origin/main",
          ahead_count: 0,
          behind_count: 0,
          staged_count: 0,
          unstaged_count: 0,
          untracked_count: 0,
          conflicted_count: 0,
          total_change_count: 0,
          head_commit: "main1234567",
          head_subject: "Stabilize source control fixtures",
          head_authored_at: now,
        },
        worktrees: [
          {
            role: "muxagent_managed",
            path: featPath,
            reachable: true,
            branch: "feat/auth-refactor",
            upstream: "origin/main",
            ahead_count: 2,
            behind_count: 0,
            staged_count: 1,
            unstaged_count: 2,
            untracked_count: 1,
            conflicted_count: 0,
            total_change_count: 4,
            head_commit: "fa3b2c1d4e",
            head_subject: "Wire middleware into app",
            head_authored_at: now,
          },
          {
            role: "muxagent_managed",
            path: fixPath,
            reachable: true,
            branch: "fix/session-ttl",
            upstream: "origin/main",
            ahead_count: 0,
            behind_count: 0,
            staged_count: 0,
            unstaged_count: 1,
            untracked_count: 0,
            conflicted_count: 0,
            total_change_count: 1,
            head_commit: "be83d21a00",
            head_subject: "Tighten session TTL handling",
            head_authored_at: now,
          },
          {
            role: "external",
            path: pocPath,
            reachable: true,
            branch: "poc/experiment",
            ahead_count: 0,
            behind_count: 0,
            staged_count: 0,
            unstaged_count: 2,
            untracked_count: 0,
            conflicted_count: 0,
            total_change_count: 2,
            head_commit: "cafe098765",
            head_subject: "Prototype experiment branch",
            head_authored_at: now,
          },
        ],
        worktrees_total_count: 3,
        collected_at: now,
      };
    }

    return {
      main: {
        role: "main",
        path: workspace.path,
        reachable: true,
        branch: "main",
        upstream: "origin/main",
        ahead_count: 0,
        behind_count: 0,
        staged_count: 0,
        unstaged_count: 0,
        untracked_count: 0,
        conflicted_count: 0,
        total_change_count: 0,
        head_commit: "fixturemain",
        head_subject: "Fixture HEAD",
        head_authored_at: now,
      },
      worktrees: [],
      worktrees_total_count: 0,
      collected_at: now,
    };
  }

  private fixtureWorkspaceCheckoutStatus(
    workspace: FixtureWorkspace,
    checkoutPath: string,
  ) {
    const status = this.fixtureWorkspaceGitStatus(workspace);
    const summary = [status.main, ...status.worktrees].find(
      (entry) => entry.path === checkoutPath,
    );
    if (!summary) {
      return null;
    }

    let files: Array<{
      path: string;
      xy: string;
      bucket: string;
      orig_path?: string;
    }> = [];
    let commits: Array<{
      short_hash: string;
      subject: string;
      authored_at?: string;
    }> = [];

    if (path.basename(workspace.path) === "muxagent-source-control") {
      switch (summary.branch) {
        case "feat/auth-refactor":
          files = [
            { path: "src/auth.ts", xy: ".M", bucket: "unstaged" },
            { path: "src/session.ts", xy: ".M", bucket: "unstaged" },
            { path: "tests/auth.test.ts", xy: "??", bucket: "untracked" },
            { path: "src/types.ts", xy: "M.", bucket: "staged" },
          ];
          commits = [
            {
              short_hash: "fa3b2",
              subject: "Add JWT validation",
              authored_at: summary.head_authored_at,
            },
            {
              short_hash: "e9c1d",
              subject: "Wire middleware into app",
              authored_at: summary.head_authored_at,
            },
          ];
          break;
        case "fix/session-ttl":
          files = [{ path: "src/session.ts", xy: ".M", bucket: "unstaged" }];
          break;
        case "poc/experiment":
          files = [
            { path: "docs/notes.md", xy: ".M", bucket: "unstaged" },
            { path: "scratch/demo.ts", xy: ".M", bucket: "unstaged" },
          ];
          break;
        default:
          files = [];
      }
    }

    return {
      checkout: {
        ...summary,
        files,
        files_total: files.length,
        commits,
      },
      collected_at: new Date().toISOString(),
    };
  }

  private fixtureFileDiff(filePath: string, bucket: string) {
    const isUntracked = bucket === "untracked";
    const shortName = filePath.split("/").at(-1) ?? filePath;
    const patch = isUntracked
      ? [
          `diff --git a/${filePath} b/${filePath}`,
          "new file mode 100644",
          "--- /dev/null",
          `+++ b/${filePath}`,
          "@@ -0,0 +1,4 @@",
          `+// Fixture: new file ${shortName}`,
          "+export function placeholder() {",
          "+  return \"fixture\";",
          "+}",
          "",
        ].join("\n")
      : [
          `diff --git a/${filePath} b/${filePath}`,
          "index 1111111..2222222 100644",
          `--- a/${filePath}`,
          `+++ b/${filePath}`,
          "@@ -1,6 +1,8 @@",
          " import { Logger } from \"./logger\";",
          " ",
          " export function configure(options: Options) {",
          "-  Logger.configure(options);",
          "+  const logger = Logger.configure(options);",
          "+  logger.info(\"fixture configured\");",
          "+  return logger;",
          " }",
          "",
        ].join("\n");
    return {
      diff: {
        reachable: true,
        patch,
        truncated: false,
        binary: false,
        file_count: 1,
      },
      collected_at: new Date().toISOString(),
    };
  }

  private fixtureCommitDiff(commitHash: string) {
    const shortHash = commitHash.slice(0, 7) || "abc1234";
    const patch = [
      `commit ${shortHash}`,
      "Author: Fixture Author <fixture@example.com>",
      "Date:   Mon Jan 01 12:00:00 2026 +0000",
      "",
      "    Fixture commit diff",
      "",
      " src/auth.ts     | 4 ++++",
      " src/session.ts  | 2 +-",
      " 2 files changed, 5 insertions(+), 1 deletion(-)",
      "",
      "diff --git a/src/auth.ts b/src/auth.ts",
      "index aaaaaaa..bbbbbbb 100644",
      "--- a/src/auth.ts",
      "+++ b/src/auth.ts",
      "@@ -10,3 +10,7 @@ export function signIn() {",
      "   return session;",
      " }",
      "+",
      "+export function signOut() {",
      "+  session.clear();",
      "+}",
      "diff --git a/src/session.ts b/src/session.ts",
      "index ccccccc..ddddddd 100644",
      "--- a/src/session.ts",
      "+++ b/src/session.ts",
      "@@ -5,2 +5,2 @@",
      "-export const TTL = 3600;",
      "+export const TTL = 7200;",
      "",
    ].join("\n");
    return {
      diff: {
        reachable: true,
        patch,
        truncated: false,
        binary: false,
        file_count: 2,
        hash: commitHash,
        subject: "Fixture commit diff",
        author: "Fixture Author",
        author_mail: "fixture@example.com",
        authored_at: "2026-01-01T12:00:00Z",
      },
      collected_at: new Date().toISOString(),
    };
  }

  private artifactDirectory(
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

  private registerTaskArtifacts(
    workspacePath: string,
    taskId: string,
    description: string,
    nodeRuns: FixtureNodeRun[],
    taskArtifactPaths: string[] = [],
  ) {
    for (const run of nodeRuns) {
      for (const artifactPath of run.artifact_paths ?? []) {
        const resolved = path.join(
          this.artifactDirectory(workspacePath, taskId, run.id),
          artifactPath,
        );
        if (!this.fileContents.has(resolved) && !this.binaryFileContents.has(resolved)) {
          if (isFixtureImageArtifactPath(artifactPath)) {
            this.binaryFileContents.set(
              resolved,
              buildFixtureImageArtifactBytes({
                description,
                taskId,
                nodeLabel: run.node_name,
                artifactPath,
              }),
            );
            continue;
          }
          const markdownFixture = [
            `# ${description}`,
            "",
            `Task: ${taskId}`,
            `Node: ${run.node_name}`,
            `Artifact: ${artifactPath}`,
            "",
            "Fixture artifact generated by the desktop web bridge.",
            "",
            "## Checklist",
            "",
            "- [x] Connect the workspace",
            "- [ ] Review the follow-up",
            "",
            "## Signals",
            "",
            "| Metric | Value |",
            "| --- | --- |",
            `| Node | ${run.node_name} |`,
            `| Artifact | ${artifactPath} |`,
            "",
            "## References",
            "",
            "- [src/styles/detail.css](src/styles/detail.css)",
            "- [design.pen](design.pen)",
            "",
            "```ts",
            "export const fixture = true;",
            "```",
          ].join("\n");
          this.fileContents.set(
            resolved,
            artifactPath.endsWith(".md")
              ? markdownFixture
              : [
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

    for (const artifactPath of taskArtifactPaths) {
      const resolved = path.join(
        this.artifactDirectory(workspacePath, taskId, "_task"),
        artifactPath,
      );
      if (!this.fileContents.has(resolved) && !this.binaryFileContents.has(resolved)) {
        if (isFixtureImageArtifactPath(artifactPath)) {
          this.binaryFileContents.set(
            resolved,
            buildFixtureImageArtifactBytes({
              description,
              taskId,
              nodeLabel: "task",
              artifactPath,
            }),
          );
          continue;
        }
        const markdownFixture = [
          `# ${description}`,
          "",
          `Task: ${taskId}`,
          "Node: task",
          `Artifact: ${artifactPath}`,
          "",
          "Fixture artifact generated by the desktop web bridge.",
          "",
          "## Checklist",
          "",
          "- [x] Connect the workspace",
          "- [ ] Review the follow-up",
          "",
          "## Signals",
          "",
          "| Metric | Value |",
          "| --- | --- |",
          "| Node | task |",
          `| Artifact | ${artifactPath} |`,
          "",
          "## References",
          "",
          "- [src/styles/detail.css](src/styles/detail.css)",
          "- [design.pen](design.pen)",
          "",
          "```ts",
          "export const fixture = true;",
          "```",
        ].join("\n");
        this.fileContents.set(
          resolved,
          artifactPath.endsWith(".md")
            ? markdownFixture
            : [
                `# ${description}`,
                "",
                `Task: ${taskId}`,
                "Node: task",
                `Artifact: ${artifactPath}`,
                "",
                "Fixture artifact generated by the desktop web bridge.",
              ].join("\n"),
        );
      }
    }
  }

  private makeFixtureTask(params: {
    workspacePath: string;
    executionDir?: string;
    taskId: string;
    description: string;
    configAlias: string;
    createdAt: string;
    updatedAt?: string;
    status: string;
    currentNodeName: string;
    currentNodeType: string;
    nodeRuns: FixtureNodeRun[];
    taskArtifactPaths?: string[];
    followUp?: FixtureTask["follow_up"];
    followUpState?: FixtureTask["follow_up_state"];
    currentIssue?: FixtureTask["current_issue"];
    inputRequest?: FixtureTask["input_request"];
    blockedSteps?: FixtureTask["blocked_steps"];
    liveEvents?: FixtureTask["live_events"];
    liveOutputRunId?: FixtureTask["live_output_run_id"];
    runHistoryByRunId?: FixtureTask["run_history_by_run_id"];
  }): FixtureTask {
    this.registerTaskArtifacts(
      params.workspacePath,
      params.taskId,
      params.description,
      params.nodeRuns,
      params.taskArtifactPaths,
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
        execution_dir: params.executionDir ?? params.workspacePath,
        created_at: params.createdAt,
        updated_at: params.updatedAt ?? params.createdAt,
      },
      status: params.status,
      current_node_name: params.currentNodeName,
      current_node_type: params.currentNodeType,
      follow_up: params.followUp,
      follow_up_state: params.followUpState,
      current_issue: params.currentIssue,
      input_request: params.inputRequest,
      node_runs: params.nodeRuns,
      task_artifact_paths: params.taskArtifactPaths,
      live_events: params.liveEvents,
      live_output_run_id: params.liveOutputRunId,
      blocked_steps: params.blockedSteps,
      run_history_by_run_id: params.runHistoryByRunId,
    };
  }

  private fixtureTasksForWorkspace(workspacePath: string): FixtureTask[] {
    const base = Date.parse("2026-04-03T03:21:00.000Z");
    const makeTime = (offsetMinutes: number) =>
      new Date(base + offsetMinutes * 60_000).toISOString();
    const recentBase = Date.now();
    const makeRecentTime = (offsetMs: number) =>
      new Date(recentBase + offsetMs).toISOString();
    const second = 1_000;
    const minute = 60 * second;
    const day = 24 * 60 * minute;

    if (path.basename(workspacePath) === "muxagent-source-control") {
      const managedRoot = path.join("/tmp", ".muxagent", "worktrees", "fixture-repo");
      const featPath = path.join(managedRoot, "feat-auth-refactor");
      const fixPath = path.join(managedRoot, "fix-session-ttl");
      return [
        this.makeFixtureTask({
          workspacePath,
          taskId: "task-scm-wire-jwt",
          description: "Wire JWT middleware into app",
          configAlias: "default",
          createdAt: makeTime(-42),
          updatedAt: makeTime(-8),
          status: "running",
          currentNodeName: "implement",
          currentNodeType: "agent",
          executionDir: featPath,
          nodeRuns: [
            {
              id: "run-scm-wire-jwt",
              task_id: "task-scm-wire-jwt",
              node_name: "implement",
              status: "running",
              started_at: makeTime(-12),
              session_id: "session-scm-wire-jwt",
            },
          ],
        }),
        this.makeFixtureTask({
          workspacePath,
          taskId: "task-scm-refresh-endpoint",
          description: "Add refresh-token endpoint",
          configAlias: "default",
          createdAt: makeTime(-40),
          updatedAt: makeTime(-10),
          status: "running",
          currentNodeName: "implement",
          currentNodeType: "agent",
          executionDir: featPath,
          nodeRuns: [
            {
              id: "run-scm-refresh-endpoint",
              task_id: "task-scm-refresh-endpoint",
              node_name: "implement",
              status: "running",
              started_at: makeTime(-15),
              session_id: "session-scm-refresh-endpoint",
            },
          ],
        }),
        this.makeFixtureTask({
          workspacePath,
          taskId: "task-scm-fix-ttl-edge",
          description: "Fix edge case in session TTL",
          configAlias: "default",
          createdAt: makeTime(-32),
          updatedAt: makeTime(-5),
          status: "awaiting_user",
          currentNodeName: "verify",
          currentNodeType: "agent",
          executionDir: featPath,
          nodeRuns: [
            {
              id: "run-scm-fix-ttl-edge",
              task_id: "task-scm-fix-ttl-edge",
              node_name: "verify",
              status: "awaiting_user",
              started_at: makeTime(-6),
              session_id: "session-scm-fix-ttl-edge",
            },
          ],
        }),
        this.makeFixtureTask({
          workspacePath,
          taskId: "task-scm-fix-ttl-branch",
          description: "Validate TTL rollback on retry",
          configAlias: "default",
          createdAt: makeTime(-28),
          updatedAt: makeTime(-7),
          status: "awaiting_user",
          currentNodeName: "verify",
          currentNodeType: "agent",
          executionDir: fixPath,
          nodeRuns: [
            {
              id: "run-scm-fix-ttl-branch",
              task_id: "task-scm-fix-ttl-branch",
              node_name: "verify",
              status: "awaiting_user",
              started_at: makeTime(-8),
              session_id: "session-scm-fix-ttl-branch",
            },
          ],
        }),
      ];
    }

    if (path.basename(workspacePath) === "muxagent-stale-workspace") {
      return [
        this.makeFixtureTask({
          workspacePath,
          taskId: "task-stale-fixture",
          description: "Recover orphaned planner run",
          configAlias: "default",
          createdAt: makeTime(0),
          updatedAt: makeTime(105),
          status: "running",
          currentNodeName: "implement",
          currentNodeType: "agent",
          nodeRuns: [
            {
              id: "run-stale-plan",
              task_id: "task-stale-fixture",
              node_name: "draft_plan",
              status: "done",
              started_at: makeTime(0),
              completed_at: makeTime(4),
              artifact_paths: ["plan.md"],
            },
            {
              id: "run-stale-implement",
              task_id: "task-stale-fixture",
              node_name: "implement",
              status: "running",
              started_at: makeTime(5),
            },
          ],
          runHistoryByRunId: {
            "run-stale-implement": [],
          },
        }),
      ];
    }

    if (path.basename(workspacePath) === "muxagent-sync-workspace") {
      return [
        this.makeFixtureTask({
          workspacePath,
          taskId: "task-sync-fixture",
          description: "Keep task detail aligned with board refresh",
          configAlias: "default",
          createdAt: makeTime(0),
          updatedAt: makeTime(12),
          status: "running",
          currentNodeName: "implement",
          currentNodeType: "agent",
          nodeRuns: [
            {
              id: "run-sync-plan",
              task_id: "task-sync-fixture",
              node_name: "draft_plan",
              status: "done",
              started_at: makeTime(0),
              completed_at: makeTime(4),
              artifact_paths: ["plan.md"],
            },
            {
              id: "run-sync-implement",
              task_id: "task-sync-fixture",
              node_name: "implement",
              status: "running",
              started_at: makeTime(5),
              session_id: "session-sync-implement",
            },
          ],
          runHistoryByRunId: {
            "run-sync-implement": [],
          },
        }),
      ];
    }

    return [
      this.makeFixtureTask({
        workspacePath,
        taskId: "task-ancestry-root",
        description: "Stabilize authentication pipeline",
        configAlias: "default",
        createdAt: makeTime(-150),
        updatedAt: makeTime(-145),
        status: "done",
        currentNodeName: "done",
        currentNodeType: "terminal",
        nodeRuns: [
          {
            id: "run-ancestry-root-plan",
            task_id: "task-ancestry-root",
            node_name: "plan",
            status: "done",
            started_at: makeTime(-150),
            completed_at: makeTime(-149),
          },
          {
            id: "run-ancestry-root-done",
            task_id: "task-ancestry-root",
            node_name: "done",
            status: "done",
            started_at: makeTime(-145),
            completed_at: makeTime(-145),
          },
        ],
      }),
      (() => {
        const task = this.makeFixtureTask({
          workspacePath,
          taskId: "task-ancestry-parent",
          description: "Harden refresh token handling",
          configAlias: "default",
          createdAt: makeTime(-140),
          updatedAt: makeTime(-132),
          status: "done",
          currentNodeName: "done",
          currentNodeType: "terminal",
          nodeRuns: [
            {
              id: "run-ancestry-parent-plan",
              task_id: "task-ancestry-parent",
              node_name: "plan",
              status: "done",
              started_at: makeTime(-140),
              completed_at: makeTime(-138),
            },
            {
              id: "run-ancestry-parent-implement",
              task_id: "task-ancestry-parent",
              node_name: "implement",
              status: "done",
              started_at: makeTime(-138),
              completed_at: makeTime(-132),
            },
          ],
        });
        task.task.parent_task_id = "task-ancestry-root";
        task.task.parent_task_description = "Stabilize authentication pipeline";
        return task;
      })(),
      (() => {
        const task = this.makeFixtureTask({
          workspacePath,
          taskId: "task-ancestry-fixture",
          description: "Show parent task ancestry in task detail",
          configAlias: "default",
          createdAt: makeTime(-128),
          updatedAt: makeTime(-118),
          status: "running",
          currentNodeName: "implement",
          currentNodeType: "agent",
          nodeRuns: [
            {
              id: "run-ancestry-plan",
              task_id: "task-ancestry-fixture",
              node_name: "draft_plan",
              status: "done",
              started_at: makeTime(-128),
              completed_at: makeTime(-126),
              artifact_paths: ["plan.md"],
            },
            {
              id: "run-ancestry-implement",
              task_id: "task-ancestry-fixture",
              node_name: "implement",
              status: "running",
              started_at: makeTime(-125),
              session_id: "session-ancestry-implement",
            },
          ],
          liveOutputRunId: "run-ancestry-implement",
          liveEvents: [
            {
              event_id: "evt-ancestry-live-1",
              seq: 1,
              emitted_at: makeTime(-121),
              recorded_at: makeTime(-121),
              session_id: "session-ancestry-implement",
              provenance: "executor_persisted",
              kind: "message",
              role: "assistant",
              part_type: "text",
              text: "Tracing the current task lineage and preparing the ancestry header surface.",
            },
          ],
          runHistoryByRunId: {
            "run-ancestry-implement": [],
          },
        });
        task.task.parent_task_id = "task-ancestry-parent";
        task.task.parent_task_description = "Harden refresh token handling";
        return task;
      })(),
      (() => {
        const rootUpdatedOffset = -2 * day;
        const rootStartOffset = rootUpdatedOffset - 192_000;
        const task = this.makeFixtureTask({
          workspacePath,
          taskId: "task-follow-up-history-root",
          description: "Refactor the auth middleware to use JWT validation with configurable TTL",
          configAlias: "default",
          createdAt: makeRecentTime(rootStartOffset - 8 * minute),
          updatedAt: makeRecentTime(rootUpdatedOffset),
          status: "done",
          currentNodeName: "done",
          currentNodeType: "terminal",
          nodeRuns: [
            {
              id: "run-follow-up-history-root-plan",
              task_id: "task-follow-up-history-root",
              node_name: "draft_plan",
              status: "done",
              started_at: makeRecentTime(rootStartOffset),
              completed_at: makeRecentTime(rootStartOffset + 36_000),
              artifact_paths: ["plan.md"],
            },
            {
              id: "run-follow-up-history-root-review",
              task_id: "task-follow-up-history-root",
              node_name: "review_plan",
              status: "done",
              started_at: makeRecentTime(rootStartOffset + 45_000),
              completed_at: makeRecentTime(rootStartOffset + 78_000),
              artifact_paths: ["plan.md"],
            },
            {
              id: "run-follow-up-history-root-revise",
              task_id: "task-follow-up-history-root",
              node_name: "revise_plan",
              status: "done",
              started_at: makeRecentTime(rootStartOffset + 88_000),
              completed_at: makeRecentTime(rootStartOffset + 102_000),
            },
            {
              id: "run-follow-up-history-root-implement",
              task_id: "task-follow-up-history-root",
              node_name: "implement",
              status: "done",
              started_at: makeRecentTime(rootStartOffset + 118_000),
              completed_at: makeRecentTime(rootStartOffset + 164_000),
              artifact_paths: ["updated_jwt_middleware.ts"],
            },
            {
              id: "run-follow-up-history-root-done",
              task_id: "task-follow-up-history-root",
              node_name: "done",
              status: "done",
              started_at: makeRecentTime(rootUpdatedOffset - 12_000),
              completed_at: makeRecentTime(rootUpdatedOffset),
            },
          ],
        });
        return task;
      })(),
      (() => {
        const parentUpdatedOffset = -1 * day;
        const parentStartOffset = parentUpdatedOffset - 125_000;
        const task = this.makeFixtureTask({
          workspacePath,
          taskId: "task-follow-up-history-parent",
          description: "Add test coverage for the new token refresh logic",
          configAlias: "default",
          createdAt: makeRecentTime(parentStartOffset - 6 * minute),
          updatedAt: makeRecentTime(parentUpdatedOffset),
          status: "done",
          currentNodeName: "done",
          currentNodeType: "terminal",
          nodeRuns: [
            {
              id: "run-follow-up-history-parent-plan",
              task_id: "task-follow-up-history-parent",
              node_name: "draft_plan",
              status: "done",
              started_at: makeRecentTime(parentStartOffset),
              completed_at: makeRecentTime(parentStartOffset + 28_000),
              artifact_paths: ["plan.md"],
            },
            {
              id: "run-follow-up-history-parent-implement",
              task_id: "task-follow-up-history-parent",
              node_name: "implement",
              status: "done",
              started_at: makeRecentTime(parentStartOffset + 42_000),
              completed_at: makeRecentTime(parentStartOffset + 104_000),
              artifact_paths: ["refresh-token-tests.ts"],
            },
            {
              id: "run-follow-up-history-parent-done",
              task_id: "task-follow-up-history-parent",
              node_name: "done",
              status: "done",
              started_at: makeRecentTime(parentUpdatedOffset - 9_000),
              completed_at: makeRecentTime(parentUpdatedOffset),
            },
          ],
        });
        task.task.parent_task_id = "task-follow-up-history-root";
        task.task.parent_task_description =
          "Refactor the auth middleware to use JWT validation with configurable TTL";
        return task;
      })(),
      (() => {
        const currentUpdatedOffset = -2 * minute;
        const currentStartOffset = currentUpdatedOffset - 26 * minute;
        const task = this.makeFixtureTask({
          workspacePath,
          taskId: "task-follow-up-history-fixture",
          description: "Pause running task gracefully when daemon receives SIGTERM",
          configAlias: "default",
          createdAt: makeRecentTime(currentStartOffset - 12 * minute),
          updatedAt: makeRecentTime(currentUpdatedOffset),
          status: "done",
          currentNodeName: "implement",
          currentNodeType: "agent",
          nodeRuns: [
            {
              id: "run-follow-up-history-draft",
              task_id: "task-follow-up-history-fixture",
              node_name: "draft_plan",
              status: "done",
              started_at: makeRecentTime(currentStartOffset),
              completed_at: makeRecentTime(currentStartOffset + 2 * minute),
              artifact_paths: ["plan.md"],
            },
            {
              id: "run-follow-up-history-review",
              task_id: "task-follow-up-history-fixture",
              node_name: "review_plan",
              status: "done",
              started_at: makeRecentTime(currentStartOffset + 3 * minute),
              completed_at: makeRecentTime(currentStartOffset + 6 * minute),
              result: {
                summary:
                  "Reviewed the plan to confirm in-flight work can pause cleanly and resume with the right state trace.",
              },
            },
            {
              id: "run-follow-up-history-upsert",
              task_id: "task-follow-up-history-fixture",
              node_name: "upsert_plan",
              status: "done",
              started_at: makeRecentTime(currentStartOffset + 7 * minute),
              completed_at: makeRecentTime(currentStartOffset + 11 * minute),
              result: {
                summary:
                  "Saved an updated follow-up plan so shutdown handling and resume sequencing stay aligned.",
              },
            },
            {
              id: "run-follow-up-history-implement",
              task_id: "task-follow-up-history-fixture",
              node_name: "implement",
              status: "done",
              started_at: makeRecentTime(currentStartOffset + 12 * minute),
              completed_at: makeRecentTime(currentUpdatedOffset),
              artifact_paths: ["updated_jwt_config.ts"],
            },
          ],
          runHistoryByRunId: {
            "run-follow-up-history-implement": [],
          },
        });
        task.task.parent_task_id = "task-follow-up-history-parent";
        task.task.parent_task_description =
          "Add test coverage for the new token refresh logic";
        return task;
      })(),
      (() => {
        const currentUpdatedOffset = -45 * second;
        const currentStartOffset = currentUpdatedOffset - 18 * minute;
        const task = this.makeFixtureTask({
          workspacePath,
          taskId: "task-follow-up-history-sibling",
          description: "Restore paused daemon state by replaying the last persisted follow-up snapshot",
          configAlias: "default",
          createdAt: makeRecentTime(currentStartOffset - 10 * minute),
          updatedAt: makeRecentTime(currentUpdatedOffset),
          status: "running",
          currentNodeName: "verify",
          currentNodeType: "agent",
          nodeRuns: [
            {
              id: "run-follow-up-history-sibling-draft",
              task_id: "task-follow-up-history-sibling",
              node_name: "draft_plan",
              status: "done",
              started_at: makeRecentTime(currentStartOffset),
              completed_at: makeRecentTime(currentStartOffset + 2 * minute),
              artifact_paths: ["plan.md"],
            },
            {
              id: "run-follow-up-history-sibling-implement",
              task_id: "task-follow-up-history-sibling",
              node_name: "implement",
              status: "done",
              started_at: makeRecentTime(currentStartOffset + 3 * minute),
              completed_at: makeRecentTime(currentStartOffset + 12 * minute),
              artifact_paths: ["resume-snapshot.ts"],
            },
            {
              id: "run-follow-up-history-sibling-verify",
              task_id: "task-follow-up-history-sibling",
              node_name: "verify",
              status: "running",
              started_at: makeRecentTime(currentStartOffset + 13 * minute),
              session_id: "session-follow-up-history-sibling-verify",
            },
          ],
          liveOutputRunId: "run-follow-up-history-sibling-verify",
          liveEvents: [
            {
              event_id: "evt-follow-up-history-sibling-1",
              seq: 1,
              emitted_at: makeRecentTime(currentUpdatedOffset - 20 * second),
              recorded_at: makeRecentTime(currentUpdatedOffset - 20 * second),
              session_id: "session-follow-up-history-sibling-verify",
              provenance: "executor_persisted",
              kind: "message",
              role: "assistant",
              part_type: "text",
              text: "Comparing the resumed daemon snapshot with the persisted follow-up task chain.",
            },
          ],
          runHistoryByRunId: {
            "run-follow-up-history-sibling-verify": [],
          },
        });
        task.task.parent_task_id = "task-follow-up-history-parent";
        task.task.parent_task_description =
          "Add test coverage for the new token refresh logic";
        return task;
      })(),
      this.makeFixtureTask({
        workspacePath,
        executionDir: path.join(
          "/tmp",
          ".muxagent",
          "worktrees",
          "task-live-fixture",
          "muxagent-workspace",
        ),
        taskId: "task-live-fixture",
        description: "Refactor auth middleware",
        configAlias: "default",
        createdAt: makeTime(0),
        status: "running",
        currentNodeName: "implement",
        currentNodeType: "agent",
        taskArtifactPaths: ["summary.md"],
        liveOutputRunId: "run-live-implement",
        liveEvents: [
          {
            event_id: "evt-live-edit",
            seq: 7,
            emitted_at: makeTime(8),
            recorded_at: makeTime(8),
            session_id: "session-live-implement",
            provenance: "executor_persisted",
            kind: "tool",
            call_id: "tool-edit-live",
            name: "Edit",
            tool_kind: "edit",
            status: "in_progress",
            input_summary: "src/auth/middleware.ts",
            output_text: "Applying middleware guard changes and staging the updated branch logic.",
            paths: ["src/auth/middleware.ts"],
            diffs: [
              {
                path: "src/auth/middleware.ts",
                old_text: "if (!session) {\n  return next();\n}",
                new_text: "if (!session) {\n  return redirect('/login');\n}",
              },
            ],
            raw_input_json:
              '{\"path\":\"src/auth/middleware.ts\",\"instruction\":\"guard anonymous requests\"}',
            raw_output_json:
              '{\"updated\":1,\"path\":\"src/auth/middleware.ts\",\"status\":\"running\"}',
            duration_ms: 2100,
          },
          {
            event_id: "evt-live-reasoning",
            seq: 8,
            emitted_at: makeTime(9),
            recorded_at: makeTime(9),
            session_id: "session-live-implement",
            provenance: "executor_persisted",
            kind: "message",
            message_id: "msg-live-reasoning",
            part_id: "part-live-reasoning",
            role: "assistant",
            part_type: "reasoning",
            text: "Need to verify whether the middleware redirect should happen before the anonymous bypass.",
          },
          {
            event_id: "evt-live-message",
            seq: 9,
            emitted_at: makeTime(9.2),
            recorded_at: makeTime(9.2),
            session_id: "session-live-implement",
            provenance: "executor_persisted",
            kind: "message",
            message_id: "msg-live-1",
            part_id: "part-live-1",
            role: "assistant",
            part_type: "text",
            text: "applying middleware changes",
          },
        ],
        nodeRuns: [
          {
            id: "run-live-plan",
            task_id: "task-live-fixture",
            node_name: "plan",
            status: "done",
            started_at: makeTime(0),
            completed_at: makeTime(2),
            result: {
              summary:
                "Scope the middleware refactor around the anonymous bypass first, and verify the redirect ordering before widening the rollout. See `plan.md` for the full breakdown.",
            },
            artifact_paths: [
              "plan.md",
              "deps.json",
              "analysis.txt",
              "review-board.svg",
              "review-panorama.svg",
              "review-portrait.svg",
            ],
          },
          {
            id: "run-live-implement",
            task_id: "task-live-fixture",
            node_name: "implement",
            status: "running",
            started_at: makeTime(2),
            artifact_paths: ["implement-preview.md"],
            clarifications: [
              {
                created_at: makeTime(1.6),
                responded_at: makeTime(1.75),
                request: {
                  questions: [
                    {
                      question: "What should I inspect before editing?",
                      options: [
                        {
                          label: "please inspect `auth middleware` before editing.",
                        },
                      ],
                    },
                  ],
                },
                response: {
                  answers: [{ selected: "please inspect `auth middleware` before editing." }],
                },
              },
              {
                created_at: makeTime(2.6),
                responded_at: makeTime(2.75),
                request: {
                  questions: [
                    {
                      question: "Which auth edge case should I prioritize?",
                      options: [
                        {
                          label: "Expired session redirect",
                        },
                        {
                          label: "Anonymous bypass",
                        },
                      ],
                    },
                  ],
                },
                response: {
                  answers: [{ selected: "Expired session redirect" }],
                },
              },
            ],
          },
        ],
        runHistoryByRunId: {
          "run-live-implement": [
            {
              event_id: "evt_fixture_live_1",
              seq: 1,
              emitted_at: makeTime(1.5),
              recorded_at: makeTime(1.5),
              session_id: "fixture-live-implement-session",
              provenance: "executor_persisted",
              kind: "message",
              message_id: "msg-live-user-1",
              part_id: "part-live-user-1",
              role: "user",
              part_type: "text",
              text: "please inspect `auth middleware` before editing.",
            },
            {
              event_id: "evt_fixture_live_2",
              seq: 2,
              emitted_at: makeTime(2),
              recorded_at: makeTime(2),
              session_id: "fixture-live-implement-session",
              provenance: "executor_persisted",
              kind: "tool",
              call_id: "tool-search-live",
              name: "Search",
              tool_kind: "search",
              status: "completed",
              input_summary: "auth middleware entry points",
              raw_input_json: '{\"query\":\"auth middleware entry points\"}',
              raw_output_json:
                '{\"matches\":[\"src/auth/middleware.ts\",\"src/auth/router.ts\"]}',
              duration_ms: 700,
            },
            {
              event_id: "evt_fixture_live_2b",
              seq: 3,
              emitted_at: makeTime(2.5),
              recorded_at: makeTime(2.5),
              session_id: "fixture-live-implement-session",
              provenance: "executor_persisted",
              kind: "tool",
              call_id: "tool-read-live",
              name: "Read",
              tool_kind: "read",
              status: "completed",
              input_summary: "src/auth/middleware.ts",
              output_text: "Loaded middleware and traced the auth gate used before route handlers.",
              paths: ["src/auth/middleware.ts"],
              raw_output_json:
                '{\"path\":\"src/auth/middleware.ts\",\"lines\":[1,48],\"contains\":\"auth gate\"}',
              duration_ms: 900,
            },
            {
              event_id: "evt_fixture_live_3",
              seq: 4,
              emitted_at: makeTime(3),
              recorded_at: makeTime(3),
              session_id: "fixture-live-implement-session",
              provenance: "executor_persisted",
              kind: "message",
              role: "assistant",
              part_type: "text",
              text: "drafted **middleware** patch plan\n\n- trace anonymous requests\n- preserve redirect flow",
            },
          ],
        },
      }),
      this.makeFixtureTask({
        workspacePath,
        taskId: "task-markdown-detail",
        description: "**Render markdown in task detail**\nKeep multiline summaries readable.",
        configAlias: "default",
        createdAt: makeTime(18),
        updatedAt: makeTime(24),
        status: "done",
        currentNodeName: "done",
        currentNodeType: "agent",
        nodeRuns: [
          {
            id: "run-markdown-detail-plan",
            task_id: "task-markdown-detail",
            node_name: "plan",
            status: "done",
            started_at: makeTime(18),
            completed_at: makeTime(19),
            result: {
              summary:
                "Mapped the header and activity surfaces.\nCaptured the rollout notes in `plan.md`.",
            },
            artifact_paths: ["plan.md"],
          },
          {
            id: "run-markdown-detail-implement",
            task_id: "task-markdown-detail",
            node_name: "implement",
            status: "done",
            started_at: makeTime(19),
            completed_at: makeTime(24),
            result: {
              summary:
                "**Implemented the task detail markdown pass**\nPreserved the multiline summary in `result.md`.",
            },
            artifact_paths: ["result.md"],
          },
        ],
      }),
      this.makeFixtureTask({
        workspacePath,
        taskId: "task-clarification-fixture",
        description: "Resolve transcript clarification follow-up",
        configAlias: "default",
        createdAt: makeTime(3),
        updatedAt: makeTime(7),
        status: "done",
        currentNodeName: "done",
        currentNodeType: "human",
        nodeRuns: [
          {
            id: "run-clarification-plan",
            task_id: "task-clarification-fixture",
            node_name: "plan",
            status: "done",
            started_at: makeTime(3),
            completed_at: makeTime(4),
            artifact_paths: ["plan.md"],
          },
          {
            id: "run-clarification-implement",
            task_id: "task-clarification-fixture",
            node_name: "implement",
            status: "done",
            started_at: makeTime(4),
            completed_at: makeTime(7),
            clarifications: [
              {
                created_at: makeTime(5),
                responded_at: makeTime(6),
                request: {
                  questions: [
                    {
                      question: "Which auth edge case should I prioritize?",
                      why_it_matters:
                        "The follow-up depends on the exact failure mode you want covered.",
                      options: [
                        {
                          label: "Expired session redirect",
                          description:
                            "Handle expired sessions before the middleware reaches the route guard.",
                        },
                        {
                          label: "Anonymous bypass",
                          description:
                            "Keep public routes reachable while protecting authenticated flows.",
                        },
                      ],
                    },
                  ],
                },
                response: {
                  answers: [{ selected: "Expired session redirect" }],
                },
              },
            ],
          },
        ],
        runHistoryByRunId: {
          "run-clarification-implement": [],
        },
      }),
      this.makeFixtureTask({
        workspacePath,
        taskId: "task-live-mcp",
        description: "Inspect MCP runtime transcript",
        configAlias: "default",
        createdAt: makeTime(4),
        status: "running",
        currentNodeName: "implement",
        currentNodeType: "agent",
        liveOutputRunId: "run-mcp-implement",
        liveEvents: [
          {
            event_id: "evt-live-mcp-start",
            seq: 11,
            emitted_at: makeTime(10),
            recorded_at: makeTime(10),
            session_id: "session-live-mcp",
            provenance: "executor_persisted",
            kind: "tool",
            call_id: "item_22",
            name: "get_editor_state",
            tool_kind: "mcp",
            title: "MCP",
            status: "in_progress",
            input_summary: "pencil.get_editor_state",
            raw_output_json:
              "{\"server\":\"pencil\",\"tool\":\"get_editor_state\",\"status\":\"in_progress\",\"block_count\":0,\"block_types\":[],\"mime_types\":[],\"has_structured_content\":false,\"has_error\":false}",
            mcp: {
              server: "pencil",
              tool: "get_editor_state",
              arguments_json: "{\"include_schema\":true}",
              output_blocks: [],
              debug_json:
                "{\"server\":\"pencil\",\"tool\":\"get_editor_state\",\"status\":\"in_progress\",\"block_count\":0,\"block_types\":[],\"mime_types\":[],\"has_structured_content\":false,\"has_error\":false}",
            },
          },
          {
            event_id: "evt-live-mcp-complete",
            seq: 12,
            emitted_at: makeTime(11),
            recorded_at: makeTime(11),
            session_id: "session-live-mcp",
            provenance: "executor_persisted",
            kind: "tool",
            call_id: "item_22",
            name: "get_editor_state",
            tool_kind: "mcp",
            title: "MCP",
            status: "completed",
            duration_ms: 920,
            input_summary: "pencil.get_editor_state",
            output_text: "Loaded the editor schema and confirmed the active canvas selection.",
            raw_output_json:
              "{\"server\":\"pencil\",\"tool\":\"get_editor_state\",\"status\":\"completed\",\"block_count\":1,\"block_types\":[\"text\"],\"mime_types\":[],\"has_structured_content\":true,\"has_error\":false}",
            mcp: {
              server: "pencil",
              tool: "get_editor_state",
              arguments_json: "{\"include_schema\":true}",
              structured_content_json:
                "{\"selection\":{\"id\":\"canvas-root\",\"name\":\"Landing Shell\"}}",
              output_blocks: [
                {
                  type: "text",
                  text: "Loaded the editor schema and confirmed the active canvas selection.",
                },
              ],
              debug_json:
                "{\"server\":\"pencil\",\"tool\":\"get_editor_state\",\"status\":\"completed\",\"block_count\":1,\"block_types\":[\"text\"],\"mime_types\":[],\"has_structured_content\":true,\"has_error\":false}",
            },
          },
        ],
        nodeRuns: [
          {
            id: "run-mcp-plan",
            task_id: "task-live-mcp",
            node_name: "plan",
            status: "done",
            started_at: makeTime(4),
            completed_at: makeTime(5),
          },
          {
            id: "run-mcp-implement",
            task_id: "task-live-mcp",
            node_name: "implement",
            status: "running",
            started_at: makeTime(5),
            session_id: "session-live-mcp",
          },
        ],
        runHistoryByRunId: {
          "run-mcp-implement": [
            {
              event_id: "evt-provider-mcp-1",
              seq: 1,
              emitted_at: makeTime(5.5),
              recorded_at: makeTime(9),
              session_id: "session-live-mcp",
              provenance: "provider_backfilled",
              kind: "tool",
              call_id: "call-provider-render",
              name: "export_nodes",
              tool_kind: "mcp",
              title: "MCP",
              status: "completed",
              duration_ms: 1440,
              input_summary: "pencil.export_nodes",
              output_text: "Rendered a preview image for the selected artboard.",
              raw_output_json:
                "{\"server\":\"pencil\",\"tool\":\"export_nodes\",\"status\":\"completed\",\"block_count\":2,\"block_types\":[\"text\",\"image\"],\"mime_types\":[\"image/png\"],\"has_structured_content\":false,\"has_error\":false}",
              mcp: {
                server: "pencil",
                tool: "export_nodes",
                arguments_json:
                  "{\"nodeIds\":[\"canvas-root\"],\"outputDir\":\"artifacts/devbox/mcp-preview\"}",
                output_blocks: [
                  {
                    type: "text",
                    text: "Rendered a preview image for the selected artboard.",
                  },
                  {
                    type: "image",
                    data_url:
                      "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAYAAACNiR0NAAAAHklEQVR42mP4H2X2n5qYYdTAUQNHDRw1cNTAkWogACay/g6GVKnLAAAAAElFTkSuQmCC",
                    mime_type: "image/png",
                  },
                ],
                debug_json:
                  "{\"server\":\"pencil\",\"tool\":\"export_nodes\",\"status\":\"completed\",\"block_count\":2,\"block_types\":[\"text\",\"image\"],\"mime_types\":[\"image/png\"],\"has_structured_content\":false,\"has_error\":false}",
              },
            },
          ],
        },
      }),
      this.makeFixtureTask({
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
      this.makeFixtureTask({
        workspacePath,
        taskId: "task-awaiting-pr",
        description: "Review PR #42",
        configAlias: "default",
        createdAt: makeTime(-12),
        status: "awaiting_user",
        currentNodeName: "review",
        currentNodeType: "human",
        inputRequest: {
          kind: "approval",
          task_id: "task-awaiting-pr",
          node_run_id: "run-awaiting-review",
          node_name: "review",
        },
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
      this.makeFixtureTask({
        workspacePath,
        taskId: "task-awaiting-clarification",
        description: "Clarify deployment strategy before implement",
        configAlias: "default",
        createdAt: makeTime(-24),
        status: "awaiting_user",
        currentNodeName: "implement",
        currentNodeType: "agent",
        inputRequest: {
          kind: "clarification",
          task_id: "task-awaiting-clarification",
          node_run_id: "run-clarify-implement",
          node_name: "implement",
          questions: [
            {
              question: "Which deployment target should we prioritize first?",
              why_it_matters: "The implementation plan depends on the initial environment.",
              options: [
                {
                  label: "staging",
                  description: "Validate on staging before touching production.",
                },
                {
                  label: "production",
                  description: "Optimize directly for the production rollout.",
                },
              ],
            },
            {
              question: "Should we gate the rollout behind a feature flag?",
              why_it_matters: "It changes how risky the first implementation pass can be.",
              options: [
                {
                  label: "yes",
                  description: "Keep rollout incremental and easy to reverse.",
                },
                {
                  label: "no",
                  description: "Optimize for a direct cutover with fewer moving parts.",
                },
              ],
            },
          ],
        },
        nodeRuns: [
          {
            id: "run-clarify-plan",
            task_id: "task-awaiting-clarification",
            node_name: "plan",
            status: "done",
            started_at: makeTime(-24),
            completed_at: makeTime(-23),
            artifact_paths: ["plan.md"],
          },
          {
            id: "run-clarify-implement",
            task_id: "task-awaiting-clarification",
            node_name: "implement",
            status: "awaiting_user",
            started_at: makeTime(-23),
          },
        ],
        runHistoryByRunId: {
          "run-clarify-plan": [
            {
              event_id: "evt_fixture_plan_1",
              seq: 1,
              emitted_at: makeTime(-24),
              recorded_at: makeTime(-24),
              session_id: "fixture-plan-session",
              provenance: "executor_persisted",
              kind: "tool",
              name: "Read",
              tool_kind: "read",
              status: "completed",
              input_summary: "docs/deploy.md",
              duration_ms: 700,
            },
            {
              event_id: "evt_fixture_plan_2",
              seq: 2,
              emitted_at: makeTime(-23),
              recorded_at: makeTime(-23),
              session_id: "fixture-plan-session",
              provenance: "executor_persisted",
              kind: "message",
              role: "assistant",
              part_type: "text",
              text: "deployment plan drafted",
            },
          ],
        },
      }),
      this.makeFixtureTask({
        workspacePath,
        taskId: "task-awaiting-clarification-alt",
        description: "Clarify rollout checklist before verify",
        configAlias: "default",
        createdAt: makeTime(-26),
        status: "awaiting_user",
        currentNodeName: "verify",
        currentNodeType: "agent",
        inputRequest: {
          kind: "clarification",
          task_id: "task-awaiting-clarification-alt",
          node_run_id: "run-clarify-verify",
          node_name: "verify",
          questions: [
            {
              question: "Which checklist should verify follow first?",
              why_it_matters: "The verify step needs a single source of truth before execution.",
              options: [
                {
                  label: "release",
                  description: "Follow the existing release checklist first.",
                },
                {
                  label: "rollback",
                  description: "Prioritize the rollback checklist before anything else.",
                },
              ],
            },
            {
              question: "Do we need customer-facing confirmation in this pass?",
              why_it_matters: "It decides whether verify should block on external signals.",
              options: [
                {
                  label: "yes",
                  description: "Wait for a visible customer-facing confirmation step.",
                },
                {
                  label: "no",
                  description: "Keep verify internal to the engineering checklist.",
                },
              ],
            },
          ],
        },
        nodeRuns: [
          {
            id: "run-clarify-verify-plan",
            task_id: "task-awaiting-clarification-alt",
            node_name: "plan",
            status: "done",
            started_at: makeTime(-26),
            completed_at: makeTime(-25),
          },
          {
            id: "run-clarify-verify",
            task_id: "task-awaiting-clarification-alt",
            node_name: "verify",
            status: "awaiting_input",
            started_at: makeTime(-25),
          },
        ],
      }),
      this.makeFixtureTask({
        workspacePath,
        taskId: "task-blocked-max-iteration",
        description: "Implement billing cache after iteration limit",
        configAlias: "default",
        createdAt: makeTime(-18),
        updatedAt: makeTime(-14),
        status: "blocked",
        currentNodeName: "implement",
        currentNodeType: "agent",
        currentIssue: {
          kind: "blocked",
          node_name: "implement",
          iteration: 2,
          reason: 'node "implement" exceeded max_iterations',
          occurred_at: makeTime(-14),
        },
        blockedSteps: [
          {
            node_name: "implement",
            iteration: 2,
            reason: 'node "implement" exceeded max_iterations',
            created_at: makeTime(-14),
          },
        ],
        nodeRuns: [
          {
            id: "run-limit-plan",
            task_id: "task-blocked-max-iteration",
            node_name: "plan",
            status: "done",
            started_at: makeTime(-18),
            completed_at: makeTime(-17),
          },
          {
            id: "run-limit-implement",
            task_id: "task-blocked-max-iteration",
            node_name: "implement",
            status: "done",
            started_at: makeTime(-17),
            completed_at: makeTime(-16),
            session_id: "session-limit-implement",
          },
        ],
        runHistoryByRunId: {
          "run-limit-implement": [
            {
              event_id: "evt_limit_implement_1",
              seq: 1,
              emitted_at: makeTime(-17),
              recorded_at: makeTime(-16),
              session_id: "session-limit-implement",
              provenance: "executor_persisted",
              kind: "tool",
              name: "Read",
              tool_kind: "read",
              status: "completed",
              input_summary: "docs/billing/cache-strategy.md",
              output_text: "Reviewed the billing cache strategy and prior clarification notes.",
              duration_ms: 960,
            },
            {
              event_id: "evt_limit_implement_2",
              seq: 2,
              emitted_at: makeTime(-16.5),
              recorded_at: makeTime(-16),
              session_id: "session-limit-implement",
              provenance: "executor_persisted",
              kind: "message",
              role: "assistant",
              part_type: "text",
              text: "captured the implementation constraints before the next iteration was blocked by max iterations.",
            },
          ],
        },
      }),
      this.makeFixtureTask({
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
      this.makeFixtureTask({
        workspacePath,
        taskId: "task-done-login",
        description: "Fix login bug",
        configAlias: "default",
        createdAt: makeTime(-90),
        status: "done",
        currentNodeName: "test",
        currentNodeType: "agent",
        followUp: {
          default_mode: "continue_here",
          available_modes: ["continue_here", "fork_head", "fork_with_changes"],
          uncommitted_change_count: 3,
        },
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
            session_id: "session-login-implement",
            result: {
              summary:
                "Patched the login guard to preserve the authenticated session cookie and captured the rollout notes in `login-fix.md`.",
            },
            artifact_paths: ["login-fix.md"],
          },
        ],
        runHistoryByRunId: {
          "run-login-implement": [
            {
              event_id: "evt_login_provider_1",
              seq: 1,
              emitted_at: makeTime(-88),
              recorded_at: makeTime(-79),
              session_id: "session-login-implement",
              provenance: "provider_backfilled",
              kind: "tool",
              call_id: "tool-login-read",
              name: "Read",
              tool_kind: "read",
              status: "completed",
              input_summary: "src/auth/login.ts",
              output_text: "Loaded the login controller and traced the null session path.",
              paths: ["src/auth/login.ts"],
              duration_ms: 2100,
            },
            {
              event_id: "evt_login_provider_2",
              seq: 2,
              emitted_at: makeTime(-87),
              recorded_at: makeTime(-79),
              session_id: "session-login-implement",
              provenance: "provider_backfilled",
              kind: "message",
              message_id: "msg-login-1",
              part_id: "part-login-1",
              role: "assistant",
              part_type: "text",
              text: "patched the login guard to preserve the authenticated session cookie.",
            },
          ],
        },
      }),
      this.makeFixtureTask({
        workspacePath,
        taskId: "task-done-long-copy",
        description:
          "帮我想办法给这个网站搞 SEO，现在有点太新了。想想怎么搞。注意一点，一定要高质量的 content，不能是滥竽充数的例如重复或者低质量的内容。verify 阶段一定记得 generate ten 份博客 for muxagent web.",
        configAlias: "default",
        createdAt: makeTime(-84),
        status: "done",
        currentNodeName: "done",
        currentNodeType: "agent",
        nodeRuns: [
          {
            id: "run-long-plan",
            task_id: "task-done-long-copy",
            node_name: "draft_plan",
            status: "done",
            started_at: makeTime(-84),
            completed_at: makeTime(-82),
          },
          {
            id: "run-long-verify",
            task_id: "task-done-long-copy",
            node_name: "verify",
            status: "done",
            started_at: makeTime(-82),
            completed_at: makeTime(-80),
          },
          {
            id: "run-long-done",
            task_id: "task-done-long-copy",
            node_name: "done",
            status: "done",
            started_at: makeTime(-80),
            completed_at: makeTime(-79),
          },
        ],
      }),
      this.makeFixtureTask({
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

  private buildFixtureArtifacts(workspacePath: string, task: FixtureTask) {
    const runArtifacts = (task.node_runs ?? []).flatMap((run) =>
      (run.artifact_paths ?? []).map((artifactPath) => {
        const resolvedPath = path.join(
          this.artifactDirectory(workspacePath, task.task.id, run.id),
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
    const taskArtifacts = (task.task_artifact_paths ?? []).map((artifactPath) => {
      const resolvedPath = path.join(
        this.artifactDirectory(workspacePath, task.task.id, "_task"),
        artifactPath,
      );
      return {
        task_id: task.task.id,
        source_label: "task",
        raw_path: artifactPath,
        resolved_path: resolvedPath,
        display_path: artifactPath,
        preview_name: artifactPath,
        preview_title: artifactPath,
        markdown: artifactPath.endsWith(".md"),
      };
    });
    return [...runArtifacts, ...taskArtifacts];
  }

  private requireWorkspace(state: FixtureState, workspaceId: string) {
    return state.workspaces.find(
      (workspace) => workspace.workspace_id === workspaceId,
    );
  }

  private fixtureTaskAncestry(
    state: FixtureState,
    workspaceId: string,
    task: FixtureTask,
  ) {
    const tasks = this.fixtureTasks(state, workspaceId);
    const ancestors: Array<{
      task_id: string;
      description: string;
      status: string;
      updated_at: string;
      parent_task_id?: string;
    }> = [];
    const visited = new Set<string>();
    let parentTaskId = task.task.parent_task_id;

    while (parentTaskId && !visited.has(parentTaskId)) {
      visited.add(parentTaskId);
      const parentTask = tasks.find((entry) => entry.task.id === parentTaskId);
      if (!parentTask) {
        break;
      }
      ancestors.unshift({
        task_id: parentTask.task.id,
        description: parentTask.task.description,
        status: parentTask.status,
        updated_at: parentTask.task.updated_at,
        parent_task_id: parentTask.task.parent_task_id,
      });
      parentTaskId = parentTask.task.parent_task_id;
    }

    return ancestors;
  }

  private fixtureTasks(state: FixtureState, workspaceId: string) {
    return state.tasksByWorkspaceId[workspaceId] ?? [];
  }

  private respond(id: number | null | undefined, result: unknown) {
    return JSON.stringify({
      jsonrpc: "2.0",
      id,
      result,
    });
  }

  private fail(
    id: number | null | undefined,
    code: number,
    message: string,
  ) {
    return JSON.stringify({
      jsonrpc: "2.0",
      id: id ?? null,
      error: {
        code,
        message,
      },
    });
  }
}

function promptRevision(content: string) {
  return `${content.length}-${Buffer.from(content).toString("base64").slice(0, 12)}`;
}
