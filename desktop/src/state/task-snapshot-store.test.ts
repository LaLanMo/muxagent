import assert from "node:assert/strict";
import test from "node:test";
import { taskEntityId } from "@/domain/task-identity";
import type { NormalizedTaskRunHistoryResult } from "@/domain/session-history";
import type {
  ArtifactRefDto,
  TaskAncestryItemDto,
  TaskFollowUpDto,
  TaskViewDto,
} from "@/rpc/types";
import { taskSnapshotKey, useTaskSnapshotStore } from "./task-snapshot-store";

const workspaceId = "workspace-1";
const secondaryWorkspaceId = "workspace-2";

function makeTask(args: {
  taskId?: string;
  description?: string;
  status: string;
  updatedAt: string;
  currentNodeName: string;
  nodeStatus: string;
}): TaskViewDto {
  const nextTaskId = args.taskId ?? "task-1";
  return {
    task: {
      id: nextTaskId,
      description: args.description ?? "Keep board/detail task state aligned",
      config_alias: "default",
      config_path: "/tmp/workspace/.muxagent/configs/default.yaml",
      work_dir: "/tmp/workspace",
      execution_dir: "/tmp/workspace",
      created_at: "2026-04-12T08:00:00.000Z",
      updated_at: args.updatedAt,
    },
    status: args.status,
    current_node_name: args.currentNodeName,
    current_node_type: args.currentNodeName === "done" ? "terminal" : "agent",
    node_runs: [
      {
        id: "run-implement",
        task_id: nextTaskId,
        node_name: "implement",
        status: args.nodeStatus,
        started_at: "2026-04-12T08:05:00.000Z",
        completed_at:
          args.nodeStatus === "done" ? "2026-04-12T08:10:00.000Z" : undefined,
      },
      ...(args.status === "done"
        ? [
            {
              id: "run-done",
              task_id: nextTaskId,
              node_name: "done",
              status: "done",
              started_at: args.updatedAt,
              completed_at: args.updatedAt,
            },
          ]
        : []),
    ],
  };
}

function makeArtifact(): ArtifactRefDto {
  return {
    task_id: "task-1",
    node_run_id: "run-implement",
    node_name: "implement",
    raw_path: "summary.md",
    resolved_path: "/tmp/workspace/.muxagent/tasks/task-1/artifacts/run-implement/summary.md",
    display_path: "summary.md",
    preview_name: "summary.md",
    preview_title: "summary.md",
    markdown: true,
  };
}

function makeAncestry(): TaskAncestryItemDto[] {
  return [
    {
      task_id: "task-root",
      description: "Stabilize authentication pipeline",
      status: "done",
      updated_at: "2026-04-12T07:55:00.000Z",
    },
    {
      task_id: "task-parent",
      description: "Harden refresh token handling",
      status: "done",
      updated_at: "2026-04-12T08:00:00.000Z",
      parent_task_id: "task-root",
    },
  ];
}

function makeFollowUp(): TaskFollowUpDto {
  return {
    default_mode: "continue_here",
    available_modes: ["continue_here", "fork_head", "fork_with_changes"],
    uncommitted_change_count: 3,
  };
}

const runHistory: NormalizedTaskRunHistoryResult = {
  taskId: "task-1",
  nodeRunId: "run-implement",
  sessionId: "session-1",
  provenance: "executor_persisted",
  completeness: "complete",
  lastSeq: 1,
  events: [],
};

test.afterEach(() => {
  useTaskSnapshotStore.getState().reset();
});

test("full task-list reload updates the shared task truth without overwriting detail-only cache", () => {
  const runningTask = makeTask({
    status: "running",
    updatedAt: "2026-04-12T08:15:00.000Z",
    currentNodeName: "implement",
    nodeStatus: "running",
  });
  const doneTask = makeTask({
    status: "done",
    updatedAt: "2026-04-12T08:20:00.000Z",
    currentNodeName: "done",
    nodeStatus: "done",
  });

  const store = useTaskSnapshotStore.getState();
  store.setTasks(workspaceId, [runningTask]);
  const generation = store.beginTaskDetailLoad(
    workspaceId,
    "task-1",
    taskSnapshotKey(runningTask),
  );
  store.resolveTaskDetail(workspaceId, "task-1", taskSnapshotKey(runningTask), generation, {
    config: { path: "/tmp/workspace/.muxagent/configs/default.yaml" },
    inputRequest: undefined,
    artifacts: [makeArtifact()],
    ancestry: [],
    liveEventsRunId: "run-implement",
  });
  store.resolveRunHistory(
    workspaceId,
    "task-1",
    "run-implement",
    "run-implement|running",
    runHistory,
  );

  useTaskSnapshotStore.getState().setTasks(workspaceId, [doneTask]);

  const next = useTaskSnapshotStore.getState();
  assert.equal(next.tasksById[taskEntityId(workspaceId, "task-1")]?.status, "done");
  assert.deepEqual(next.taskIdsByWorkspaceId[workspaceId], ["task-1"]);
  assert.equal(next.taskDetailsByWorkspaceId[workspaceId]?.["task-1"]?.artifacts.length, 1);
  assert.equal(
    next.taskDetailsByWorkspaceId[workspaceId]?.["task-1"]?.runHistoryByRunId["run-implement"]
      ?.result?.completeness,
    "complete",
  );
  assert.equal(
    (next.taskDetailsByWorkspaceId[workspaceId]?.["task-1"] as { task?: unknown })?.task,
    undefined,
  );
});

test("runtime upserts keep workspace ordering sorted by the shared task entity timestamps", () => {
  const olderTask = makeTask({
    taskId: "task-old",
    description: "Older task",
    status: "done",
    updatedAt: "2026-04-12T08:10:00.000Z",
    currentNodeName: "done",
    nodeStatus: "done",
  });
  const newerTask = makeTask({
    taskId: "task-new",
    description: "Newer task",
    status: "running",
    updatedAt: "2026-04-12T08:30:00.000Z",
    currentNodeName: "implement",
    nodeStatus: "running",
  });

  const store = useTaskSnapshotStore.getState();
  store.setTasks(workspaceId, [olderTask]);
  store.upsertTask(workspaceId, newerTask);

  assert.deepEqual(nextTaskIds(), ["task-new", "task-old"]);
  assert.equal(
    useTaskSnapshotStore.getState().tasksById[taskEntityId(workspaceId, "task-new")]?.status,
    "running",
  );
});

test("same task ids in different workspaces do not overwrite each other", () => {
  const runningTask = makeTask({
    status: "running",
    updatedAt: "2026-04-12T08:15:00.000Z",
    currentNodeName: "implement",
    nodeStatus: "running",
  });
  const doneTask = makeTask({
    status: "done",
    updatedAt: "2026-04-12T08:20:00.000Z",
    currentNodeName: "done",
    nodeStatus: "done",
  });
  const secondaryWorkspaceTask: TaskViewDto = {
    ...doneTask,
    task: {
      ...doneTask.task,
      work_dir: "/tmp/other-workspace",
      execution_dir: "/tmp/other-workspace",
    },
  };

  const store = useTaskSnapshotStore.getState();
  store.setTasks(workspaceId, [runningTask]);
  store.setTasks(secondaryWorkspaceId, [secondaryWorkspaceTask]);

  const next = useTaskSnapshotStore.getState();
  assert.equal(
    next.tasksById[taskEntityId(workspaceId, "task-1")]?.task.work_dir,
    "/tmp/workspace",
  );
  assert.equal(
    next.tasksById[taskEntityId(secondaryWorkspaceId, "task-1")]?.task.work_dir,
    "/tmp/other-workspace",
  );
  assert.equal(next.tasksById[taskEntityId(workspaceId, "task-1")]?.status, "running");
  assert.equal(next.tasksById[taskEntityId(secondaryWorkspaceId, "task-1")]?.status, "done");
});

test("older upserts do not roll back a newer shared task entity", () => {
  const newerTask = makeTask({
    status: "done",
    updatedAt: "2026-04-12T08:20:00.000Z",
    currentNodeName: "done",
    nodeStatus: "done",
  });
  const olderTask = makeTask({
    status: "running",
    updatedAt: "2026-04-12T08:15:00.000Z",
    currentNodeName: "implement",
    nodeStatus: "running",
  });

  const store = useTaskSnapshotStore.getState();
  store.setTasks(workspaceId, [newerTask]);
  store.upsertTask(workspaceId, olderTask);

  const next = useTaskSnapshotStore.getState();
  assert.equal(next.tasksById[taskEntityId(workspaceId, "task-1")]?.status, "done");
  assert.equal(
    next.tasksById[taskEntityId(workspaceId, "task-1")]?.current_node_name,
    "done",
  );
});

test("detail ancestry survives detail-side cache transitions until the next hydrate replaces it", () => {
  const store = useTaskSnapshotStore.getState();
  const ancestry = makeAncestry();

  const generation = store.beginTaskDetailLoad(
    workspaceId,
    "task-1",
    taskSnapshotKey(
      makeTask({
        status: "running",
        updatedAt: "2026-04-12T08:15:00.000Z",
        currentNodeName: "implement",
        nodeStatus: "running",
      }),
    ),
  );
  store.resolveTaskDetail(workspaceId, "task-1", "running|2026-04-12T08:15:00.000Z", generation, {
    config: { path: "/tmp/workspace/.muxagent/configs/default.yaml" },
    inputRequest: undefined,
    artifacts: [makeArtifact()],
    ancestry,
    liveEventsRunId: "run-implement",
  });

  store.beginRunHistoryLoad(
    workspaceId,
    "task-1",
    "run-implement",
    "run-implement|running",
  );
  store.failTaskDetail(workspaceId, "task-1", "temporary refresh failure");
  store.invalidateTaskDetail(workspaceId, "task-1");

  let entry = useTaskSnapshotStore.getState().taskDetailsByWorkspaceId[workspaceId]?.["task-1"];
  assert.deepEqual(entry?.ancestry, ancestry);
  assert.equal(entry?.stale, true);

  const refreshGeneration = store.beginTaskDetailLoad(
    workspaceId,
    "task-1",
    "done|2026-04-12T08:20:00.000Z",
  );
  store.resolveTaskDetail(
    workspaceId,
    "task-1",
    "done|2026-04-12T08:20:00.000Z",
    refreshGeneration,
    {
    config: { path: "/tmp/workspace/.muxagent/configs/default.yaml" },
    inputRequest: undefined,
    artifacts: [makeArtifact()],
    ancestry: ancestry.slice(0, 1),
    liveEventsRunId: "run-implement",
    },
  );

  entry = useTaskSnapshotStore.getState().taskDetailsByWorkspaceId[workspaceId]?.["task-1"];
  assert.deepEqual(entry?.ancestry, ancestry.slice(0, 1));
});

test("late task detail loads cannot overwrite a newer done-state hydrate", () => {
  const runningTask = makeTask({
    status: "running",
    updatedAt: "2026-04-12T08:15:00.000Z",
    currentNodeName: "implement",
    nodeStatus: "running",
  });
  const doneTask = makeTask({
    status: "done",
    updatedAt: "2026-04-12T08:20:00.000Z",
    currentNodeName: "done",
    nodeStatus: "done",
  });

  const store = useTaskSnapshotStore.getState();
  store.setTasks(workspaceId, [runningTask]);
  const requestA = store.beginTaskDetailLoad(
    workspaceId,
    "task-1",
    taskSnapshotKey(runningTask),
  );
  store.upsertTask(workspaceId, doneTask);
  const requestB = store.beginTaskDetailLoad(
    workspaceId,
    "task-1",
    taskSnapshotKey(doneTask),
  );
  store.resolveTaskDetail(workspaceId, "task-1", taskSnapshotKey(doneTask), requestB, {
    config: { path: "/tmp/workspace/.muxagent/configs/default.yaml" },
    inputRequest: undefined,
    followUp: makeFollowUp(),
    artifacts: [makeArtifact()],
    ancestry: [],
    liveEventsRunId: "run-done",
  });
  store.resolveTaskDetail(workspaceId, "task-1", taskSnapshotKey(runningTask), requestA, {
    config: { path: "/tmp/workspace/.muxagent/configs/default.yaml" },
    inputRequest: undefined,
    artifacts: [],
    ancestry: [],
    liveEventsRunId: "run-implement",
  });
  store.failTaskDetailLoad(
    workspaceId,
    "task-1",
    taskSnapshotKey(runningTask),
    requestA,
    "stale load failed",
  );

  const entry = useTaskSnapshotStore.getState().taskDetailsByWorkspaceId[workspaceId]?.["task-1"];
  assert.equal(entry?.lastAppliedSnapshotKey, taskSnapshotKey(doneTask));
  assert.equal(entry?.latestRequestedSnapshotKey, taskSnapshotKey(doneTask));
  assert.equal(entry?.followUp?.default_mode, "continue_here");
  assert.equal(entry?.error, undefined);
});

test("direct task detail issues still surface during background refresh generations", () => {
  const doneTask = makeTask({
    status: "done",
    updatedAt: "2026-04-12T08:20:00.000Z",
    currentNodeName: "done",
    nodeStatus: "done",
  });
  const store = useTaskSnapshotStore.getState();
  store.setTasks(workspaceId, [doneTask]);
  const initialGeneration = store.beginTaskDetailLoad(
    workspaceId,
    "task-1",
    taskSnapshotKey(doneTask),
  );
  store.resolveTaskDetail(workspaceId, "task-1", taskSnapshotKey(doneTask), initialGeneration, {
    config: { path: "/tmp/workspace/.muxagent/configs/default.yaml" },
    inputRequest: undefined,
    artifacts: [makeArtifact()],
    ancestry: [],
    liveEventsRunId: "run-done",
  });

  const refreshGeneration = store.beginTaskDetailLoad(
    workspaceId,
    "task-1",
    taskSnapshotKey(doneTask),
    { showLoading: false },
  );
  store.failTaskDetail(workspaceId, "task-1", "Follow-up description is required");

  const entry = useTaskSnapshotStore.getState().taskDetailsByWorkspaceId[workspaceId]?.["task-1"];
  assert.equal(entry?.latestRequestGeneration, refreshGeneration);
  assert.equal(entry?.error, "Follow-up description is required");
});

test("hidden detail refreshes still reserve a new generation without forcing loading", () => {
  const doneTask = makeTask({
    status: "done",
    updatedAt: "2026-04-12T08:20:00.000Z",
    currentNodeName: "done",
    nodeStatus: "done",
  });
  const store = useTaskSnapshotStore.getState();
  store.setTasks(workspaceId, [doneTask]);

  const initialGeneration = store.beginTaskDetailLoad(
    workspaceId,
    "task-1",
    taskSnapshotKey(doneTask),
  );
  store.resolveTaskDetail(workspaceId, "task-1", taskSnapshotKey(doneTask), initialGeneration, {
    config: { path: "/tmp/workspace/.muxagent/configs/default.yaml" },
    inputRequest: undefined,
    artifacts: [makeArtifact()],
    ancestry: [],
    liveEventsRunId: "run-done",
  });

  const refreshGeneration = store.beginTaskDetailLoad(
    workspaceId,
    "task-1",
    taskSnapshotKey(doneTask),
    { showLoading: false },
  );

  const entry = useTaskSnapshotStore.getState().taskDetailsByWorkspaceId[workspaceId]?.["task-1"];
  assert.equal(refreshGeneration, initialGeneration + 1);
  assert.equal(entry?.loading, false);
  assert.equal(entry?.latestRequestGeneration, refreshGeneration);
});

function nextTaskIds(): string[] {
  return useTaskSnapshotStore.getState().taskIdsByWorkspaceId[workspaceId] ?? [];
}
