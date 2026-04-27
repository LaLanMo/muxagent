import assert from "node:assert/strict";
import test from "node:test";
import {
  deriveFixtureFollowUpState,
  deriveFixtureWorktreeCleanupInfo,
  FixtureRuntime,
  type FixtureTask,
} from "./fixture-runtime";

type RpcResponse<T> = {
  result?: T;
  error?: {
    code: number;
    message: string;
  };
};

function parseRpcResponse<T>(payload: string): RpcResponse<T> {
  return JSON.parse(payload) as RpcResponse<T>;
}

function makeFixtureTask(overrides: Partial<FixtureTask> = {}): FixtureTask {
  return {
    task: {
      id: "task-1",
      description: "Completed task",
      config_alias: "default",
      config_path: "/tmp/workspace/.muxagent/configs/default.yaml",
      work_dir: "/tmp/workspace",
      execution_dir: "/tmp/workspace",
      created_at: "2026-04-16T08:00:00.000Z",
      updated_at: "2026-04-16T08:05:00.000Z",
    },
    status: "done",
    current_node_name: "done",
    current_node_type: "terminal",
    node_runs: [],
    ...overrides,
  };
}

test("deriveFixtureFollowUpState returns disabled for completed worktree-backed tasks without follow-up metadata", () => {
  const task = makeFixtureTask({
    task: {
      ...makeFixtureTask().task,
      execution_dir: "/tmp/.muxagent/worktrees/task-1/workspace",
    },
  });

  assert.equal(deriveFixtureFollowUpState(task), "disabled");
});

test("deriveFixtureFollowUpState returns refine when explicit follow-up metadata exists", () => {
  const task = makeFixtureTask({
    follow_up: {
      default_mode: "continue_here",
      available_modes: ["continue_here", "fork_head", "fork_with_changes"],
      uncommitted_change_count: 3,
    },
  });

  assert.equal(deriveFixtureFollowUpState(task), "refine");
});

test("deriveFixtureFollowUpState returns basic for completed workspace tasks without follow-up metadata", () => {
  assert.equal(deriveFixtureFollowUpState(makeFixtureTask()), "basic");
});

test("deriveFixtureWorktreeCleanupInfo returns available for completed worktree tasks", () => {
  const task = makeFixtureTask({
    task: {
      ...makeFixtureTask().task,
      execution_dir: "/tmp/.muxagent/worktrees/task-1/workspace",
    },
    follow_up: {
      default_mode: "continue_here",
      available_modes: ["continue_here", "fork_head", "fork_with_changes"],
      uncommitted_change_count: 2,
    },
  });

  assert.deepEqual(deriveFixtureWorktreeCleanupInfo(task, [task]), {
    state: "available",
    worktree_group_id: "/tmp/.muxagent/worktrees/task-1/workspace",
    worktree_root: "/tmp/.muxagent/worktrees/task-1/workspace",
    shared_task_count: 1,
    dirty_count: 2,
    blocked_by: [],
    removal_scope: "single_worktree",
    can_remove: true,
    message: "Remove this worktree.",
  });
});

test("deriveFixtureWorktreeCleanupInfo returns blocked when a live sibling shares the worktree", () => {
  const completedTask = makeFixtureTask({
    task: {
      ...makeFixtureTask().task,
      execution_dir: "/tmp/.muxagent/worktrees/shared/workspace",
    },
  });
  const runningTask = makeFixtureTask({
    task: {
      ...makeFixtureTask().task,
      id: "task-2",
      description: "Sibling task",
      execution_dir: "/tmp/.muxagent/worktrees/shared/workspace",
    },
    status: "running",
  });

  const info = deriveFixtureWorktreeCleanupInfo(completedTask, [
    completedTask,
    runningTask,
  ]);

  assert.equal(info.state, "blocked");
  assert.equal(info.shared_task_count, 2);
  assert.equal(info.can_remove, false);
  assert.deepEqual(info.blocked_by, [
    {
      task_id: "task-2",
      description: "Sibling task",
      status: "running",
    },
  ]);
});

async function flushFixtureEvents(): Promise<void> {
  await Promise.resolve();
}

test("fixture agentchat rpc supports prompt events and scoped load replay", async () => {
  const runtime = new FixtureRuntime();
  const state = runtime.createState();
  const emittedEvents: Array<{ type?: string; sessionId?: string; seq?: number }> =
    [];
  const options = {
    emitNotification: () => {},
    emitAgentChatEvent: (event: { type?: string; sessionId?: string; seq?: number }) => {
      emittedEvents.push(event);
    },
  };
  const call = <T>(id: number, method: string, params: Record<string, unknown>) =>
    parseRpcResponse<T>(
      runtime.handleRpc(
        state,
        {
          jsonrpc: "2.0",
          id,
          method: "agentchat.rpc",
          params: {
            method,
            params,
          },
        },
        options,
      ),
    );

  const runtimeList = call<{ runtimes: Array<{ id: string; ready: boolean }> }>(
    1,
    "runtime.list",
    {},
  );
  assert.equal(runtimeList.result?.runtimes[0]?.id, "codex");
  assert.equal(runtimeList.result?.runtimes[0]?.ready, true);

  const created = call<{
    app: {
      sessionId: string;
      runtime: string;
      cwd: string;
      title: string;
      status: string;
      updatedAt: string;
    };
    acp: {
      sessionId: string;
      configOptions: Array<{ category?: string; currentValue?: string }>;
    };
  }>(2, "session.create", {
    cwd: "/tmp/workspace",
    runtime: "codex",
    permissionMode: "read-only",
  });
  const sessionId = created.result?.acp.sessionId;
  assert.ok(sessionId);
  assert.equal(created.result?.app.sessionId, sessionId);
  assert.equal(created.result?.app.title, "New chat");
  assert.equal(created.result?.app.status, "idle");
  assert.ok(created.result?.app.updatedAt);
  assert.equal(
    created.result?.acp.configOptions.find((option) => option.category === "mode")
      ?.currentValue,
    "read-only",
  );

  const prompted = call<{ accepted: boolean }>(3, "session.prompt", {
    sessionId,
    text: "hello fixture",
  });
  assert.equal(prompted.result?.accepted, true);
  assert.equal(emittedEvents.length, 0);
  await flushFixtureEvents();
  assert.deepEqual(
    emittedEvents.map((event) => event.type),
    ["session.status", "message.delta", "message.delta", "run.finished"],
  );
  assert.deepEqual(
    emittedEvents.map((event) => (event.seq ?? 0) > 0),
    [true, true, true, true],
  );

  emittedEvents.length = 0;
  const loaded = call<{ app: { ok: boolean }; acp: { configOptions: unknown[] } }>(
    4,
    "session.load",
    {
      sessionId,
      cwd: "/tmp/workspace",
      runtime: "codex",
      permissionMode: "full-access",
      model: "gpt-5.4-mini",
    },
  );
  assert.equal(loaded.result?.app.ok, true);
  assert.equal(emittedEvents.length, 0);
  await flushFixtureEvents();
  assert.equal(emittedEvents.length, 5);
  assert.deepEqual(
    emittedEvents.map((event) => event.seq),
    [0, 0, 0, 0, 0],
  );
  assert.deepEqual(
    emittedEvents.map((event) => event.type),
    [
      "mode.changed",
      "model.changed",
      "message.delta",
      "message.delta",
      "history.complete",
    ],
  );

  emittedEvents.length = 0;
  assert.equal(
    call<{ ok: boolean }>(5, "session.cancel", { sessionId }).result?.ok,
    true,
  );
  await flushFixtureEvents();
  assert.equal(emittedEvents.length, 0);
});

test("fixture agentchat create and load require cwd and runtime", () => {
  const runtime = new FixtureRuntime();
  const state = runtime.createState();
  const call = (id: number, method: string, params: Record<string, unknown>) =>
    parseRpcResponse<unknown>(
      runtime.handleRpc(
        state,
        {
          jsonrpc: "2.0",
          id,
          method: "agentchat.rpc",
          params: {
            method,
            params,
          },
        },
        {
          emitNotification: () => {},
          emitAgentChatEvent: () => {},
        },
      ),
    );

  assert.equal(
    call(1, "session.create", { runtime: "codex" }).error?.message,
    "missing cwd",
  );
  assert.equal(
    call(2, "session.create", { cwd: "/tmp/workspace" }).error?.message,
    "missing runtime",
  );
  assert.equal(
    call(3, "session.load", {
      sessionId: "fixture-chat-1",
    }).error?.message,
    "missing cwd",
  );
  assert.equal(
    call(4, "session.load", {
      sessionId: "fixture-chat-1",
      cwd: "/tmp/workspace",
    }).error?.message,
    "missing runtime",
  );
  assert.equal(
    call(5, "session.create", {
      cwd: "/tmp/workspace",
      runtime: "codex",
      permissionMode: "acceptEdits",
    }).error?.message,
    "unsupported permissionMode",
  );
  assert.equal(
    call(6, "session.create", {
      cwd: "/tmp/workspace",
      runtime: "unknown",
    }).error?.message,
    "unsupported runtime",
  );
  assert.equal(
    call(7, "session.create", {
      cwd: "/tmp/workspace",
      runtime: "codex",
      permissionMode: "default",
    }).error,
    undefined,
  );
  assert.equal(
    call(8, "session.load", {
      sessionId: "fixture-chat-1",
      cwd: "/tmp/workspace",
      runtime: "codex",
      permissionMode: "default",
      model: "default",
    }).error,
    undefined,
  );
});

test("fixture agentchat configChanged values are flat appwire values", async () => {
  const runtime = new FixtureRuntime();
  const state = runtime.createState();
  const emittedEvents: Array<{
    type?: string;
    configChanged?: {
      app: {
        values?: Array<{
          value?: string;
          name?: string;
        }>;
      };
    };
  }> = [];
  const response = parseRpcResponse<{ ok: boolean }>(
    runtime.handleRpc(
      state,
      {
        jsonrpc: "2.0",
        id: 1,
        method: "agentchat.rpc",
        params: {
          method: "session.setConfigOption",
          params: {
            sessionId: "fixture-chat-1",
            configId: "model",
            value: "gpt-5.4-mini",
          },
        },
      },
      {
        emitNotification: () => {},
        emitAgentChatEvent: (event) => {
          emittedEvents.push(event);
        },
      },
    ),
  );

  assert.equal(response.result?.ok, true);
  await flushFixtureEvents();
  assert.equal(emittedEvents[0]?.type, "model.changed");
  assert.deepEqual(
    emittedEvents[0]?.configChanged?.app.values?.map((entry) => entry.value),
    ["gpt-5.4", "gpt-5.4-mini", "gpt-5.3-codex"],
  );
});

test("fixture agentchat session list applies runtime and limit params", () => {
  const runtime = new FixtureRuntime();
  const state = runtime.createState();
  const response = parseRpcResponse<{ sessions: Array<{ runtime?: string }> }>(
    runtime.handleRpc(
      state,
      {
        jsonrpc: "2.0",
        id: 1,
        method: "agentchat.rpc",
        params: {
          method: "session.list",
          params: {
            runtime: "codex",
            limit: 1,
          },
        },
      },
      {
        emitNotification: () => {},
        emitAgentChatEvent: () => {},
      },
    ),
  );

  assert.equal(response.result?.sessions.length, 1);
  assert.equal(response.result?.sessions[0]?.runtime, "codex");
});

test("fixture agentchat session list treats zero or missing limit as unbounded", () => {
  const runtime = new FixtureRuntime();
  const state = runtime.createState();
  const call = (id: number, params: Record<string, unknown>) =>
    parseRpcResponse<{ sessions: Array<{ sessionId: string }> }>(
      runtime.handleRpc(
        state,
        {
          jsonrpc: "2.0",
          id,
          method: "agentchat.rpc",
          params: {
            method: "session.list",
            params,
          },
        },
        {
          emitNotification: () => {},
          emitAgentChatEvent: () => {},
        },
      ),
    );

  const first = call(1, { limit: 0 }).result?.sessions.length;
  const second = call(2, {}).result?.sessions.length;

  assert.equal(first, state.agentChatSessions.length);
  assert.equal(second, state.agentChatSessions.length);
});

test("fixture agentchat runtime mode defaults mirror Go runtime options", () => {
  const runtime = new FixtureRuntime();
  const state = runtime.createState();
  const response = parseRpcResponse<{
    runtimes: Array<{
      id: string;
      configOptions: Array<{
        name?: string;
        category?: string;
        currentValue?: string;
        options?: Array<{ value?: string }>;
      }>;
    }>;
  }>(
    runtime.handleRpc(
      state,
      {
        jsonrpc: "2.0",
        id: 1,
        method: "agentchat.rpc",
        params: {
          method: "runtime.list",
          params: {},
        },
      },
      {
        emitNotification: () => {},
        emitAgentChatEvent: () => {},
      },
    ),
  );
  const codexMode = response.result?.runtimes
    .find((entry) => entry.id === "codex")
    ?.configOptions.find((option) => option.category === "mode");
  const claudeMode = response.result?.runtimes
    .find((entry) => entry.id === "claude-code")
    ?.configOptions.find((option) => option.category === "mode");

  assert.equal(codexMode?.currentValue, "read-only");
  assert.equal(codexMode?.name, "Approval Preset");
  assert.deepEqual(
    codexMode?.options?.map((entry) => entry.value),
    ["read-only", "auto", "full-access"],
  );
  assert.equal(claudeMode?.currentValue, "bypassPermissions");
  assert.equal(claudeMode?.name, "Approval Preset");
  assert.deepEqual(
    claudeMode?.options?.map((entry) => entry.value),
    ["default", "acceptEdits", "plan", "dontAsk", "bypassPermissions"],
  );
});

test("fixture agentchat config mutations validate values and emit events", async () => {
  const runtime = new FixtureRuntime();
  const state = runtime.createState();
  const emittedEvents: Array<{
    type?: string;
    seq?: number;
    modeChanged?: { app: { currentModeId: string } };
    configChanged?: { app: { configId: string; currentValue: string } };
  }> = [];
  const options = {
    emitNotification: () => {},
    emitAgentChatEvent: (event: {
      type?: string;
      seq?: number;
      modeChanged?: { app: { currentModeId: string } };
      configChanged?: { app: { configId: string; currentValue: string } };
    }) => {
      emittedEvents.push(event);
    },
  };
  const call = <T>(id: number, method: string, params: Record<string, unknown>) =>
    parseRpcResponse<T>(
      runtime.handleRpc(
        state,
        {
          jsonrpc: "2.0",
          id,
          method: "agentchat.rpc",
          params: { method, params },
        },
        options,
      ),
    );

  assert.equal(
    call(1, "session.setMode", {
      sessionId: "fixture-chat-1",
      permissionMode: "not-a-mode",
    }).error?.message,
    "unsupported permissionMode",
  );

  assert.equal(
    call<{ ok: boolean }>(2, "session.setMode", {
      sessionId: "fixture-chat-1",
      permissionMode: "read-only",
    }).result?.ok,
    true,
  );
  assert.equal(emittedEvents.length, 0);
  await flushFixtureEvents();
  assert.equal(emittedEvents[0]?.type, "mode.changed");
  assert.equal(emittedEvents[0]?.modeChanged?.app.currentModeId, "read-only");
  assert.ok((emittedEvents[0]?.seq ?? 0) > 0);

  assert.equal(
    call<{ ok: boolean }>(3, "session.setConfigOption", {
      sessionId: "fixture-chat-1",
      configId: "model",
      value: "gpt-5.4-mini",
    }).result?.ok,
    true,
  );
  await flushFixtureEvents();
  assert.equal(emittedEvents[1]?.type, "model.changed");
  assert.equal(emittedEvents[1]?.configChanged?.app.configId, "model");
  assert.equal(emittedEvents[1]?.configChanged?.app.currentValue, "gpt-5.4-mini");
  assert.ok((emittedEvents[1]?.seq ?? 0) > 0);
});
