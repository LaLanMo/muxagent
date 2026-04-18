import assert from "node:assert/strict";
import test from "node:test";
import type {
  ConfigCatalogEntryDto,
  ConfigViewDto,
  NodeRunViewDto,
  TaskViewDto,
} from "@/rpc/types";
import { resolveTaskRuntimeName } from "@/features/task-detail/ui/TaskDetailScreen";

function makeTask(): TaskViewDto {
  return {
    task: {
      id: "task-1",
      description: "Fix login bug",
      config_alias: "default",
      config_path: "/tmp/workspace/.muxagent/tasks/task-1/config.yaml",
      work_dir: "/tmp/workspace",
      execution_dir: "/tmp/workspace",
      created_at: "2026-04-18T08:00:00.000Z",
      updated_at: "2026-04-18T08:05:00.000Z",
    },
    status: "done",
    current_node_name: "done",
    current_node_type: "terminal",
  };
}

function makeRun(nodeName = "implement"): NodeRunViewDto {
  return {
    id: `run-${nodeName}`,
    task_id: "task-1",
    node_name: nodeName,
    status: "done",
    started_at: "2026-04-18T08:01:00.000Z",
    completed_at: "2026-04-18T08:04:00.000Z",
  };
}

function makeConfig(runtime = "codex"): ConfigViewDto {
  return {
    path: "/tmp/workspace/.muxagent/tasks/task-1/config.yaml",
    config: {
      runtime,
      node_definitions: {
        implement: {
          type: "agent",
          system_prompt: "./prompts/implement.md",
          result_schema: {},
        },
        done: {
          type: "terminal",
          result_schema: {},
        },
      },
    },
  };
}

const fallbackEntries: ConfigCatalogEntryDto[] = [
  {
    alias: "default",
    config_path: "/tmp/workspace/.muxagent/tasks/task-1/config.yaml",
    is_default: true,
    runtime_explicit: true,
    runtime_configured: true,
    builtin: false,
    launchable: true,
    runtime_id: "yolo",
    runtime_name: "yolo",
  },
];

test("resolveTaskRuntimeName prefers the selected run runtime from the materialized task config", () => {
  assert.equal(
    resolveTaskRuntimeName(makeTask(), makeRun("implement"), makeConfig("codex"), fallbackEntries),
    "Codex",
  );
});

test("resolveTaskRuntimeName respects per-node runtime overrides", () => {
  const config = makeConfig("codex");
  const nodeDefinitions = (config.config?.node_definitions ?? {}) as Record<string, unknown>;
  nodeDefinitions.implement = {
    ...(nodeDefinitions.implement as Record<string, unknown>),
    runtime: "claude-code",
  };

  assert.equal(
    resolveTaskRuntimeName(makeTask(), makeRun("implement"), config, fallbackEntries),
    "Claude Code",
  );
});
