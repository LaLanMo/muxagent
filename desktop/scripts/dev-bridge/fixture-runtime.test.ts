import assert from "node:assert/strict";
import test from "node:test";
import {
  deriveFixtureFollowUpState,
  type FixtureTask,
} from "./fixture-runtime";

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
