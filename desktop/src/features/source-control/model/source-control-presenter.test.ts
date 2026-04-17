import assert from "node:assert/strict";
import test from "node:test";
import {
  buildCheckoutSummaryLabel,
  buildCommitSection,
  buildFileSections,
  buildTaskSummaryForCheckout,
  pickPreferredCheckoutPath,
} from "@/features/source-control/model/source-control-presenter";
import type {
  GitCheckoutDetailDto,
  GitCheckoutSummaryDto,
  TaskViewDto,
} from "@/rpc/types";

function iso(offsetMinutes: number): string {
  return new Date(Date.UTC(2026, 3, 17, 8, offsetMinutes, 0)).toISOString();
}

function makeCheckout(
  overrides: Partial<GitCheckoutSummaryDto> & Pick<GitCheckoutSummaryDto, "path">,
): GitCheckoutSummaryDto {
  const { path, ...rest } = overrides;
  return {
    role: "external",
    path,
    reachable: true,
    ahead_count: 0,
    behind_count: 0,
    staged_count: 0,
    unstaged_count: 0,
    untracked_count: 0,
    conflicted_count: 0,
    total_change_count: 0,
    ...rest,
  };
}

function makeTaskView(args: {
  taskId: string;
  executionDir: string;
  description: string;
  status: string;
  updatedAt: string;
}): TaskViewDto {
  return {
    task: {
      id: args.taskId,
      description: args.description,
      config_alias: "default",
      config_path: "/tmp/workspace/.muxagent/configs/default.yaml",
      work_dir: "/tmp/workspace",
      execution_dir: args.executionDir,
      created_at: iso(0),
      updated_at: args.updatedAt,
    },
    status: args.status,
    current_node_name: "implement",
    current_node_type: "agent",
  };
}

test("pickPreferredCheckoutPath 优先选择脏 worktree", () => {
  const main = makeCheckout({
    path: "/repo",
    role: "main",
  });
  const selected = pickPreferredCheckoutPath(main, [
    makeCheckout({
      path: "/repo-wt/clean",
      total_change_count: 0,
    }),
    makeCheckout({
      path: "/repo-wt/dirty",
      total_change_count: 3,
      unstaged_count: 3,
    }),
  ]);

  assert.equal(selected, "/repo-wt/dirty");
});

test("buildTaskSummaryForCheckout 按 execution_dir 归类并按更新时间倒序截断", () => {
  const summary = buildTaskSummaryForCheckout("workspace-a", "/repo/wt", [
    makeTaskView({
      taskId: "main-task",
      executionDir: "/repo",
      description: "Main task",
      status: "done",
      updatedAt: iso(1),
    }),
    makeTaskView({
      taskId: "wt-older",
      executionDir: "/repo/wt",
      description: "Older worktree task",
      status: "running",
      updatedAt: iso(2),
    }),
    makeTaskView({
      taskId: "wt-newer",
      executionDir: "/repo/wt/nested",
      description: "Newer worktree task",
      status: "awaiting_user",
      updatedAt: iso(3),
    }),
  ]);

  assert.equal(summary.total, 2);
  assert.equal(summary.runningCount, 1);
  assert.equal(summary.attentionCount, 1);
  assert.deepEqual(
    summary.rows.map((row) => row.id),
    ["wt-newer", "wt-older"],
  );
  assert.equal(summary.rows[0]?.href, "/workspaces/workspace-a/tasks/wt-newer");
});

test("buildFileSections 用 bucket 拆分 staged 与 changes 并派生展示字母", () => {
  const detail: GitCheckoutDetailDto = {
    ...makeCheckout({
      path: "/repo/wt",
      total_change_count: 3,
      staged_count: 1,
      unstaged_count: 1,
      untracked_count: 1,
    }),
    files_total: 3,
    files: [
      { path: "src/app.ts", xy: ".M", bucket: "unstaged" },
      { path: "src/types.ts", xy: "M.", bucket: "staged" },
      { path: "tests/app.test.ts", xy: "??", bucket: "untracked" },
    ],
  };

  const [changesSection, stagedSection] = buildFileSections(detail);

  assert.equal(changesSection?.count, 2);
  assert.deepEqual(
    changesSection?.rows.map((row) => `${row.statusCode}:${row.path}`),
    ["M:src/app.ts", "A:tests/app.test.ts"],
  );
  assert.equal(stagedSection?.count, 1);
  assert.deepEqual(
    stagedSection?.rows.map((row) => `${row.statusCode}:${row.path}`),
    ["M:src/types.ts"],
  );
});

test("buildCheckoutSummaryLabel 在 clean 与 unreachable 间切换", () => {
  assert.equal(
    buildCheckoutSummaryLabel(
      makeCheckout({
        path: "/repo",
        role: "main",
      }),
    ),
    "clean",
  );
  assert.equal(
    buildCheckoutSummaryLabel(
      makeCheckout({
        path: "/repo/wt",
        reachable: false,
        unreachable_reason: "path_missing",
      }),
    ),
    "path missing",
  );
});

test("buildCommitSection 用 upstream 生成 ahead 文案", () => {
  const section = buildCommitSection(
    makeCheckout({
      path: "/repo/wt",
      upstream: "origin/main",
      ahead_count: 2,
      head_commit: "abcdef123456",
      head_subject: "Wire middleware into app",
    }),
  );

  assert.equal(section?.label, "ahead of main · 2");
  assert.deepEqual(section?.rows, [
    {
      id: "abcdef123456",
      shortHash: "abcdef1",
      subject: "Wire middleware into app",
    },
  ]);
});
