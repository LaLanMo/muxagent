import assert from "node:assert/strict";
import test from "node:test";
import {
  hydrateTaskDetail,
  loadTaskAncestry,
} from "@/application/tasks";
import type { DesktopRuntime, TaskBackendClient } from "@/platform/contract";
import type {
  ArtifactListResult,
  TaskAncestryItemDto,
  TaskGetAncestryResult,
  TaskGetResult,
  TaskViewDto,
} from "@/rpc/types";

function makeTaskView(taskId = "task-1"): TaskViewDto {
  return {
    task: {
      id: taskId,
      description: "Show parent task ancestry in task detail",
      config_alias: "default",
      config_path: "/tmp/workspace/.muxagent/configs/default.yaml",
      work_dir: "/tmp/workspace",
      execution_dir: "/tmp/workspace",
      created_at: "2026-04-14T06:00:00.000Z",
      updated_at: "2026-04-14T06:05:00.000Z",
      parent_task_id: "task-parent",
      parent_task_description: "Harden refresh token handling",
    },
    status: "running",
    current_node_name: "implement",
    current_node_type: "agent",
    node_runs: [
      {
        id: "run-implement",
        task_id: taskId,
        node_name: "implement",
        status: "running",
        session_id: "session-1",
        started_at: "2026-04-14T06:01:00.000Z",
      },
    ],
  };
}

function makeAncestry(): TaskAncestryItemDto[] {
  return [
    {
      task_id: "task-root",
      description: "Stabilize authentication pipeline",
      status: "done",
      updated_at: "2026-04-14T05:00:00.000Z",
    },
    {
      task_id: "task-parent",
      description: "Harden refresh token handling",
      status: "done",
      updated_at: "2026-04-14T05:30:00.000Z",
      parent_task_id: "task-root",
    },
  ];
}

function makeRuntime(args: {
  taskGetResult?: TaskGetResult;
  artifactListResult?: ArtifactListResult;
  taskGetAncestryResult?: TaskGetAncestryResult;
  taskGetAncestryError?: Error;
  onTaskGetAncestry?: () => void;
}): DesktopRuntime {
  const backend = {
    taskGet: async () =>
      args.taskGetResult ?? {
        task: makeTaskView(),
        live_output_run_id: "run-implement",
        live_events: [
          {
            kind: "message",
            event_id: "evt-live-1",
            seq: 1,
            emitted_at: "2026-04-14T06:02:00.000Z",
            recorded_at: "2026-04-14T06:02:00.000Z",
            session_id: "session-1",
            provenance: "executor_persisted",
            role: "assistant",
            part_type: "text",
            text: "Tracing task ancestry for the new header.",
          },
        ],
      },
    artifactList: async () =>
      args.artifactListResult ?? {
        artifacts: [
          {
            task_id: "task-1",
            node_run_id: "run-implement",
            node_name: "implement",
            raw_path: "plan.md",
            resolved_path:
              "/tmp/workspace/.muxagent/tasks/task-1/artifacts/run-implement/plan.md",
            display_path: "plan.md",
            preview_name: "plan.md",
            preview_title: "plan.md",
            markdown: true,
          },
        ],
      },
    taskGetAncestry: async () => {
      args.onTaskGetAncestry?.();
      if (args.taskGetAncestryError) {
        throw args.taskGetAncestryError;
      }
      return args.taskGetAncestryResult ?? {
        ancestors: makeAncestry(),
      };
    },
  } as unknown as TaskBackendClient;

  return {
    backend,
    shell: {} as DesktopRuntime["shell"],
  };
}

test("hydrateTaskDetail includes ancestry when requested", async () => {
  let ancestryRequests = 0;
  const detail = await hydrateTaskDetail(
    makeRuntime({
      onTaskGetAncestry: () => {
        ancestryRequests += 1;
      },
    }),
    "workspace-1",
    "task-1",
    { includeAncestry: true },
  );

  assert.equal(ancestryRequests, 1);
  assert.deepEqual(detail.ancestry, makeAncestry());
  assert.equal(detail.artifacts[0]?.preview_name, "plan.md");
  assert.equal(detail.liveEventsRunId, "run-implement");
  assert.equal(detail.liveEvents[0]?.kind, "message");
  assert.equal(detail.liveEvents[0]?.text, "Tracing task ancestry for the new header.");
});

test("hydrateTaskDetail skips ancestry requests when the caller disables them", async () => {
  let ancestryRequests = 0;
  const detail = await hydrateTaskDetail(
    makeRuntime({
      onTaskGetAncestry: () => {
        ancestryRequests += 1;
      },
    }),
    "workspace-1",
    "task-1",
    { includeAncestry: false },
  );

  assert.equal(ancestryRequests, 0);
  assert.deepEqual(detail.ancestry, []);
});

test("hydrateTaskDetail degrades to an empty ancestry chain when the lookup fails", async () => {
  const detail = await hydrateTaskDetail(
    makeRuntime({
      taskGetAncestryError: new Error("ancestry lookup failed"),
    }),
    "workspace-1",
    "task-1",
    { includeAncestry: true },
  );

  assert.deepEqual(detail.ancestry, []);
});

test("loadTaskAncestry returns the backend ancestry chain", async () => {
  const ancestry = await loadTaskAncestry(
    makeRuntime({}),
    "workspace-1",
    "task-1",
  );

  assert.deepEqual(ancestry, makeAncestry());
});
