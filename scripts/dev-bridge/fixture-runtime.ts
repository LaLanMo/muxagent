import path from "node:path";
import { randomUUID } from "node:crypto";

export type FixtureNodeRun = {
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
  blocked_steps?: Array<Record<string, unknown>>;
};

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
  configs: FixtureConfig[];
  runtimes: FixtureRuntimeOption[];
};

type FixtureRuntimeOption = {
  runtime_id: string;
  runtime_name: string;
  command?: string;
  args?: string[];
  configured: boolean;
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

export class FixtureRuntime {
  private readonly fileContents = new Map<string, string>();
  private readonly stateDir: string;

  constructor(options: FixtureRuntimeOptions = {}) {
    this.stateDir = options.stateDir ?? "/tmp/muxagent-fixture/appserver";
  }

  createState(): FixtureState {
    return {
      workspaces: [],
      tasksByWorkspaceId: {},
      configs: this.defaultConfigs(),
      runtimes: this.defaultRuntimes(),
    };
  }

  readFileContent(normalizedPath: string): string | null {
    return this.fileContents.get(normalizedPath) ?? null;
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
              "workspace.update",
              "workspace.remove",
              "config.catalog",
              "config.get",
              "config.clone",
              "config.rename",
              "config.delete",
              "config.reset",
              "config.set_default",
              "config.validate",
              "config.save",
              "config.prompt.get",
              "config.prompt.save",
              "runtime.list",
              "task.list",
              "task.get",
              "task.input_request",
              "task.start",
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
          runtime_count: 0,
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
        if (config.is_default) {
          return this.fail(id, -32602, "default config cannot be deleted");
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
      case "config.set_default": {
        const config = this.requireConfig(state, String(params.alias ?? ""));
        if (!config) {
          return this.fail(id, -32011, "config not found");
        }
        for (const entry of state.configs) {
          entry.is_default = entry === config;
        }
        config.revision = randomUUID();
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
      case "task.list": {
        const workspace = this.requireWorkspace(
          state,
          String(params.workspace_id ?? ""),
        );
        if (!workspace) {
          return this.fail(id, -32010, "workspace not found");
        }
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
          input_request: task.input_request,
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

  private requireConfig(state: FixtureState, alias: string): FixtureConfig | undefined {
    return state.configs.find((config) => config.alias === alias.trim());
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
        state: "idle",
        last_error: "",
      },
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
  ) {
    for (const run of nodeRuns) {
      for (const artifactPath of run.artifact_paths ?? []) {
        const resolved = path.join(
          this.artifactDirectory(workspacePath, taskId, run.id),
          artifactPath,
        );
        if (!this.fileContents.has(resolved)) {
          this.fileContents.set(
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

  private makeFixtureTask(params: {
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
    inputRequest?: FixtureTask["input_request"];
    blockedSteps?: FixtureTask["blocked_steps"];
  }): FixtureTask {
    this.registerTaskArtifacts(
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
      input_request: params.inputRequest,
      node_runs: params.nodeRuns,
      blocked_steps: params.blockedSteps,
    };
  }

  private fixtureTasksForWorkspace(workspacePath: string): FixtureTask[] {
    const base = Date.parse("2026-04-03T03:21:00.000Z");
    const makeTime = (offsetMinutes: number) =>
      new Date(base + offsetMinutes * 60_000).toISOString();

    return [
      this.makeFixtureTask({
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
    return (task.node_runs ?? []).flatMap((run) =>
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
  }

  private requireWorkspace(state: FixtureState, workspaceId: string) {
    return state.workspaces.find(
      (workspace) => workspace.workspace_id === workspaceId,
    );
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
