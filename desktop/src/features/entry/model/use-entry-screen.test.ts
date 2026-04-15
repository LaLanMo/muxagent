import assert from "node:assert/strict";
import test from "node:test";
import type { BoardFilter, ScopedTaskView } from "@/domain/task-shell";
import { buildEntryTaskBoardModel } from "@/features/entry/model/task-board-model";
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
    node_runs: [],
  };
}

function makeScopedTask(args: {
  taskId: string;
  description?: string;
  status?: string;
  updatedAt?: string;
  parentTaskId?: string;
  workspaceId?: string;
  workspaceLabel?: string;
}): ScopedTaskView {
  return {
    workspaceId: args.workspaceId ?? "workspace-a",
    workspaceLabel: args.workspaceLabel ?? "Workspace A",
    task: makeTaskView(args),
  };
}

function buildModel(scopedTasks: ScopedTaskView[], boardFilter: BoardFilter) {
  return buildEntryTaskBoardModel({
    scopedTasks,
    boardFilter,
  });
}

test("buildEntryTaskBoardModel 在当前筛选没有可见卡片时仍保留 hasTasks=true", () => {
  const model = buildModel(
    [
      makeScopedTask({
        taskId: "root",
        status: "done",
        updatedAt: iso(1),
      }),
      makeScopedTask({
        taskId: "leaf",
        status: "done",
        updatedAt: iso(2),
        parentTaskId: "root",
      }),
    ],
    "attention",
  );

  assert.equal(model.hasTasks, true);
  assert.deepEqual(model.columns, []);
  assert.deepEqual(model.rows, []);
});
