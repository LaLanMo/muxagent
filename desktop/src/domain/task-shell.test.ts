import assert from "node:assert/strict";
import test from "node:test";
import {
  buildBoardMetaDetails,
  groupScopedTasksIntoBoardColumns,
  isWorktreeTask,
  taskWorktreeName,
  type ScopedTaskView,
} from "@/domain/task-shell";
import type { TaskViewDto } from "@/rpc/types";

function iso(offsetMinutes: number): string {
  return new Date(Date.UTC(2026, 3, 14, 6, offsetMinutes, 0)).toISOString();
}

function makeTaskView(args: {
  taskId: string;
  description?: string;
  status?: string;
  updatedAt?: string;
  parentTaskId?: string;
}): TaskViewDto {
  const status = args.status ?? "running";
  return {
    task: {
      id: args.taskId,
      description: args.description ?? args.taskId,
      config_alias: "default",
      config_path: "/tmp/workspace/.muxagent/configs/default.yaml",
      work_dir: "/tmp/workspace",
      execution_dir: "/tmp/workspace",
      created_at: iso(0),
      updated_at: args.updatedAt ?? iso(1),
      parent_task_id: args.parentTaskId,
    },
    status,
    current_node_name: status === "done" ? "done" : "implement",
    current_node_type: status === "done" ? "terminal" : "agent",
    node_runs: [
      {
        id: `run-${args.taskId}`,
        task_id: args.taskId,
        node_name: status === "done" ? "done" : "implement",
        status,
        started_at: iso(0),
        completed_at: status === "done" ? args.updatedAt ?? iso(1) : undefined,
      },
    ],
  };
}

function makeScopedTask(args: {
  workspaceId?: string;
  workspaceLabel?: string;
  taskId: string;
  description?: string;
  status?: string;
  updatedAt?: string;
  parentTaskId?: string;
}): ScopedTaskView {
  return {
    workspaceId: args.workspaceId ?? "workspace-a",
    workspaceLabel: args.workspaceLabel ?? "Workspace A",
    task: makeTaskView(args),
  };
}

test("groupScopedTasksIntoBoardColumns 只保留叶任务并按从祖先到直接父任务输出父链", () => {
  const grouped = groupScopedTasksIntoBoardColumns(
    [
      makeScopedTask({
        taskId: "root",
        status: "done",
        updatedAt: iso(1),
      }),
      makeScopedTask({
        taskId: "parent",
        status: "done",
        updatedAt: iso(2),
        parentTaskId: "root",
      }),
      makeScopedTask({
        taskId: "leaf",
        status: "done",
        updatedAt: iso(3),
        parentTaskId: "parent",
      }),
      makeScopedTask({
        taskId: "standalone",
        status: "running",
        updatedAt: iso(4),
      }),
    ],
    "all",
  );

  assert.deepEqual(
    grouped.allLeafTasks.map((task) => task.leafTask.task.task.id),
    ["standalone", "leaf"],
  );
  assert.deepEqual(
    grouped.allLeafTasks[1]?.ancestors.map((task) => task.task.task.id),
    ["root", "parent"],
  );
  assert.deepEqual(
    grouped.columns.find((column) => column.key === "running")?.tasks.map(
      (task) => task.leafTask.task.task.id,
    ),
    ["standalone"],
  );
  assert.deepEqual(
    grouped.columns.find((column) => column.key === "completed")?.tasks.map(
      (task) => task.leafTask.task.task.id,
    ),
    ["leaf"],
  );
});

test("groupScopedTasksIntoBoardColumns 在父任务缺失时保留叶任务并安全截断父链", () => {
  const grouped = groupScopedTasksIntoBoardColumns(
    [
      makeScopedTask({
        taskId: "leaf-with-missing-parent",
        status: "done",
        updatedAt: iso(5),
        parentTaskId: "missing-parent",
      }),
    ],
    "all",
  );

  assert.deepEqual(
    grouped.allLeafTasks.map((task) => task.leafTask.task.task.id),
    ["leaf-with-missing-parent"],
  );
  assert.deepEqual(grouped.allLeafTasks[0]?.ancestors, []);
});

test("groupScopedTasksIntoBoardColumns 在坏链路成环时不会死循环", () => {
  const grouped = groupScopedTasksIntoBoardColumns(
    [
      makeScopedTask({
        taskId: "cycle-a",
        status: "done",
        updatedAt: iso(1),
        parentTaskId: "cycle-b",
      }),
      makeScopedTask({
        taskId: "cycle-b",
        status: "done",
        updatedAt: iso(2),
        parentTaskId: "cycle-a",
      }),
      makeScopedTask({
        taskId: "leaf",
        status: "running",
        updatedAt: iso(6),
        parentTaskId: "cycle-a",
      }),
    ],
    "all",
  );

  assert.deepEqual(
    grouped.allLeafTasks.map((task) => task.leafTask.task.task.id),
    ["leaf"],
  );
  assert.deepEqual(
    grouped.allLeafTasks[0]?.ancestors.map((task) => task.task.task.id),
    ["cycle-b", "cycle-a"],
  );
});

test("groupScopedTasksIntoBoardColumns 会为共享同一父链的多个叶任务分别保留卡片", () => {
  const grouped = groupScopedTasksIntoBoardColumns(
    [
      makeScopedTask({
        taskId: "root",
        status: "done",
        updatedAt: iso(1),
      }),
      makeScopedTask({
        taskId: "parent",
        status: "done",
        updatedAt: iso(2),
        parentTaskId: "root",
      }),
      makeScopedTask({
        taskId: "leaf-one",
        status: "done",
        updatedAt: iso(3),
        parentTaskId: "parent",
      }),
      makeScopedTask({
        taskId: "leaf-two",
        status: "running",
        updatedAt: iso(7),
        parentTaskId: "parent",
      }),
    ],
    "all",
  );

  assert.deepEqual(
    grouped.allLeafTasks.map((task) => task.leafTask.task.task.id),
    ["leaf-two", "leaf-one"],
  );
  assert.deepEqual(
    grouped.allLeafTasks.map((task) => task.ancestors.map((ancestor) => ancestor.task.task.id)),
    [
      ["root", "parent"],
      ["root", "parent"],
    ],
  );
});

test("groupScopedTasksIntoBoardColumns 用 workspaceId + taskId 避免跨 workspace 串链", () => {
  const grouped = groupScopedTasksIntoBoardColumns(
    [
      makeScopedTask({
        workspaceId: "workspace-a",
        workspaceLabel: "Workspace A",
        taskId: "shared-parent",
        status: "done",
        updatedAt: iso(1),
      }),
      makeScopedTask({
        workspaceId: "workspace-a",
        workspaceLabel: "Workspace A",
        taskId: "leaf-a",
        status: "done",
        updatedAt: iso(4),
        parentTaskId: "shared-parent",
      }),
      makeScopedTask({
        workspaceId: "workspace-b",
        workspaceLabel: "Workspace B",
        taskId: "leaf-b",
        status: "running",
        updatedAt: iso(5),
        parentTaskId: "shared-parent",
      }),
    ],
    "all",
  );

  const leafA = grouped.allLeafTasks.find((task) => task.leafTask.task.task.id === "leaf-a");
  const leafB = grouped.allLeafTasks.find((task) => task.leafTask.task.task.id === "leaf-b");

  assert.deepEqual(
    leafA?.ancestors.map((task) => task.task.task.id),
    ["shared-parent"],
  );
  assert.deepEqual(leafB?.ancestors, []);
});

test("groupScopedTasksIntoBoardColumns 区分全部叶任务和当前筛选下可见叶任务", () => {
  const grouped = groupScopedTasksIntoBoardColumns(
    [
      makeScopedTask({
        taskId: "root",
        status: "done",
        updatedAt: iso(1),
      }),
      makeScopedTask({
        taskId: "leaf",
        status: "done",
        updatedAt: iso(6),
        parentTaskId: "root",
      }),
    ],
    "attention",
  );

  assert.equal(grouped.allLeafTasks.length, 1);
  assert.equal(grouped.visibleLeafTasks.length, 0);
  assert.deepEqual(grouped.columns, []);
});

test("isWorktreeTask 用 execution_dir 和 work_dir 的差异识别 worktree 任务", () => {
  const workspaceTask = makeTaskView({
    taskId: "workspace-task",
  });
  const worktreeTask = makeTaskView({
    taskId: "worktree-task",
  });
  worktreeTask.task.execution_dir = "/tmp/.muxagent/worktrees/worktree-task/workspace";

  assert.equal(isWorktreeTask(workspaceTask), false);
  assert.equal(isWorktreeTask(worktreeTask), true);
});

test("taskWorktreeName 优先显示匹配 checkout 的 branch 名称", () => {
  const task = makeTaskView({
    taskId: "worktree-task",
  });
  task.task.execution_dir = "/tmp/.muxagent/worktrees/worktree-task/workspace";

  assert.equal(
    taskWorktreeName(task, {
      path: "/tmp/.muxagent/worktrees/worktree-task",
      branch: "feat/auth-refactor",
    }),
    "feat/auth-refactor",
  );
});

test("taskWorktreeName 从 muxagent 托管路径推断名称", () => {
  const task = makeTaskView({
    taskId: "worktree-task",
  });
  task.task.execution_dir = "/Users/by/.muxagent/worktrees/01cc7cae/worktree-task/packages/app";

  assert.equal(taskWorktreeName(task), "muxagent/worktree-task");
});

test("taskWorktreeName 兼容没有 repo hash 的 fixture 路径", () => {
  const task = makeTaskView({
    taskId: "task-live-fixture",
  });
  task.task.work_dir = "/tmp/muxagent-workspace";
  task.task.execution_dir = "/tmp/.muxagent/worktrees/task-live-fixture/muxagent-workspace";

  assert.equal(taskWorktreeName(task), "muxagent/task-live-fixture");
});

test("buildBoardMetaDetails 为 board 第二行返回 worktree 作为第一个属性的结构化数据", () => {
  const task = makeTaskView({
    taskId: "worktree-task",
    status: "running",
    updatedAt: iso(8),
  });
  task.task.execution_dir = "/tmp/.muxagent/worktrees/worktree-task/workspace";
  const originalNow = Date.now;
  Date.now = () => Date.parse(iso(16));

  try {
    assert.deepEqual(buildBoardMetaDetails(task, "Mux Workspace"), {
      stage: "implement",
      updatedAt: "8m",
      workspace: "Mux Workspace",
      isWorktree: true,
    });
  } finally {
    Date.now = originalNow;
  }
});
