import assert from "node:assert/strict";
import test from "node:test";
import { canShowFollowUpSurface } from "@/features/task-detail/model/task-detail-action-surface";
import { deriveFollowUpDockState } from "@/features/task-detail/model/follow-up-dock-state";
import type {
  BlockedStepDto,
  InputRequestDto,
  NodeRunViewDto,
  TaskFollowUpDto,
  TaskViewDto,
} from "@/rpc/types";

function makeTask(status: string): TaskViewDto {
  return {
    task: {
      id: `task-${status}`,
      description: "Show the follow-up composer when the task has no competing action surface",
      config_alias: "default",
      config_path: "/tmp/workspace/.muxagent/configs/default.yaml",
      work_dir: "/tmp/workspace",
      execution_dir: "/tmp/workspace",
      created_at: "2026-04-14T06:00:00.000Z",
      updated_at: "2026-04-14T06:05:00.000Z",
    },
    status,
    current_node_name: status === "done" ? "done" : "implement",
    current_node_type: status === "done" ? "terminal" : "agent",
    node_runs: [
      {
        id: `run-${status}`,
        task_id: `task-${status}`,
        node_name: status === "done" ? "done" : "implement",
        status,
        started_at: "2026-04-14T06:01:00.000Z",
        completed_at: status === "done" ? "2026-04-14T06:05:00.000Z" : undefined,
      },
    ],
  };
}

function makeInputRequest(kind: InputRequestDto["kind"]): InputRequestDto {
  return {
    kind,
    task_id: "task-running",
    node_run_id: "run-running",
    node_name: "implement",
  };
}

function makeBlockedStep(): BlockedStepDto {
  return {
    node_name: "verify",
    iteration: 2,
    reason: "Need confirmation before continuing.",
    created_at: "2026-04-14T06:06:00.000Z",
  };
}

function makeRetryRun(): NodeRunViewDto {
  return {
    id: "run-failed",
    task_id: "task-failed",
    node_name: "deploy",
    status: "failed",
    started_at: "2026-04-14T06:00:00.000Z",
    completed_at: "2026-04-14T06:03:00.000Z",
  };
}

function makeFollowUp(): TaskFollowUpDto {
  return {
    default_mode: "continue_here",
    available_modes: ["continue_here", "fork_head", "fork_with_changes"],
    uncommitted_change_count: 3,
  };
}

test("canShowFollowUpSurface returns false for running tasks without higher-priority actions", () => {
  assert.equal(
    canShowFollowUpSurface({
      task: makeTask("running"),
      inputRequest: undefined,
      latestBlockedStep: undefined,
      retryRun: undefined,
    }),
    false,
  );
});

test("canShowFollowUpSurface returns true for completed tasks", () => {
  assert.equal(
    canShowFollowUpSurface({
      task: makeTask("done"),
      inputRequest: undefined,
      latestBlockedStep: undefined,
      retryRun: undefined,
    }),
    true,
  );
});

test("canShowFollowUpSurface returns false when an input request owns the action surface", () => {
  assert.equal(
    canShowFollowUpSurface({
      task: makeTask("running"),
      inputRequest: makeInputRequest("approval"),
      latestBlockedStep: undefined,
      retryRun: undefined,
    }),
    false,
  );
});

test("canShowFollowUpSurface returns false for blocked and failed retry states", () => {
  assert.equal(
    canShowFollowUpSurface({
      task: makeTask("running"),
      inputRequest: undefined,
      latestBlockedStep: makeBlockedStep(),
      retryRun: undefined,
    }),
    false,
  );
  assert.equal(
    canShowFollowUpSurface({
      task: makeTask("failed"),
      inputRequest: undefined,
      latestBlockedStep: undefined,
      retryRun: makeRetryRun(),
    }),
    false,
  );
});

test("deriveFollowUpDockState returns basic for completed non-git tasks once detail matches", () => {
  const task = makeTask("done");
  assert.equal(
    deriveFollowUpDockState({
      task,
      detailEntry: {
        artifacts: [],
        ancestry: [],
        runHistoryByRunId: {},
        loading: false,
        stale: false,
        latestRequestGeneration: 1,
        lastAppliedSnapshotKey: "done|2026-04-14T06:05:00.000Z",
      },
    }),
    "basic",
  );
});

test("deriveFollowUpDockState returns refine for completed repo-backed tasks once detail matches", () => {
  const task = makeTask("done");
  assert.equal(
    deriveFollowUpDockState({
      task,
      detailEntry: {
        followUp: makeFollowUp(),
        artifacts: [],
        ancestry: [],
        runHistoryByRunId: {},
        loading: false,
        stale: false,
        latestRequestGeneration: 2,
        lastAppliedSnapshotKey: "done|2026-04-14T06:05:00.000Z",
      },
    }),
    "refine",
  );
});

test("deriveFollowUpDockState returns pending when detail lags behind a completed snapshot", () => {
  const task = makeTask("done");
  assert.equal(
    deriveFollowUpDockState({
      task,
      detailEntry: {
        artifacts: [],
        ancestry: [],
        runHistoryByRunId: {},
        loading: false,
        stale: true,
        latestRequestGeneration: 3,
        lastAppliedSnapshotKey: "running|2026-04-14T06:04:00.000Z",
      },
    }),
    "pending",
  );
});
