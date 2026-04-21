import assert from "node:assert/strict";
import test from "node:test";
import {
  ARTIFACT_IMAGE_PREVIEW_MAX_BYTES,
  classifyArtifactPreview,
  hydrateTaskDetail,
  loadTaskWorktreeCleanupInfo,
  loadTaskAncestry,
  readArtifactPreview,
  retryTaskUntilResumed,
  startTask,
  startFollowUpFromTask,
  submitTaskApproval,
} from "@/application/tasks";
import type { DesktopRuntime, ShellHost, TaskBackendClient } from "@/platform/contract";
import type {
  ArtifactListResult,
  ArtifactRefDto,
  CommandAcceptedResult,
  TaskAncestryItemDto,
  TaskFollowUpDto,
  TaskGetAncestryResult,
  TaskGetResult,
  TaskGetWorktreeCleanupInfoResult,
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

function makeArtifact(overrides: Partial<ArtifactRefDto> = {}): ArtifactRefDto {
  return {
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
    ...overrides,
  };
}

function makeFollowUp(): TaskFollowUpDto {
  return {
    default_mode: "continue_here",
    available_modes: ["continue_here", "fork_head", "fork_with_changes"],
    uncommitted_change_count: 3,
  };
}

function makeRuntime(args: {
  taskGetResult?: TaskGetResult;
  taskGetResults?: TaskGetResult[];
  artifactListResult?: ArtifactListResult;
  taskGetAncestryResult?: TaskGetAncestryResult;
  taskGetAncestryError?: Error;
  taskGetWorktreeCleanupInfoResult?: TaskGetWorktreeCleanupInfoResult;
  onTaskGetAncestry?: () => void;
  onTaskStart?: (params: unknown) => void;
  onTaskStartFollowUp?: (params: unknown) => void;
  onTaskSubmitInput?: (params: unknown) => void;
  onTaskRetryNode?: (params: unknown) => void;
  shell?: Partial<ShellHost>;
}): DesktopRuntime {
  let taskGetIndex = 0;
  const backend = {
    taskGet: async () =>
      args.taskGetResults?.[Math.min(taskGetIndex++, args.taskGetResults.length - 1)] ??
      args.taskGetResult ?? {
        task: makeTaskView(),
        follow_up: makeFollowUp(),
        follow_up_state: "refine",
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
          makeArtifact(),
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
    taskGetWorktreeCleanupInfo: async () =>
      args.taskGetWorktreeCleanupInfoResult ?? {
        info: {
          state: "available",
          worktree_group_id: "/tmp/.muxagent/worktrees/task-1",
          worktree_root: "/tmp/.muxagent/worktrees/task-1",
          shared_task_count: 1,
          dirty_count: 3,
          can_remove: true,
          removal_scope: "single_worktree",
          message: "Remove this worktree.",
        },
      },
    taskStart: async (params: unknown) => {
      args.onTaskStart?.(params);
      return {
        accepted: true,
        client_command_id: "cmd-start",
      } satisfies CommandAcceptedResult;
    },
    taskStartFollowUp: async (params: unknown) => {
      args.onTaskStartFollowUp?.(params);
      return {
        accepted: true,
        client_command_id: "cmd-follow-up",
      } satisfies CommandAcceptedResult;
    },
    taskSubmitInput: async (params: unknown) => {
      args.onTaskSubmitInput?.(params);
      return {
        accepted: true,
        client_command_id: "cmd-input",
      } satisfies CommandAcceptedResult;
    },
    taskRetryNode: async (params: unknown) => {
      args.onTaskRetryNode?.(params);
      return {
        accepted: true,
        client_command_id: "cmd-retry",
      } satisfies CommandAcceptedResult;
    },
    taskCleanupWorktree: async () => ({
      outcome: "removed",
      info: {
        state: "missing",
        shared_task_count: 1,
        dirty_count: 0,
        can_remove: false,
        message: "Worktree is already unavailable.",
      },
    }),
  } as unknown as TaskBackendClient;
  const shell = {
    pickDirectory: async () => null,
    readTextFile: async (path: string) => `fixture:${path}`,
    readBinaryFile: async () => Uint8Array.from([1, 2, 3]),
    openPath: async () => undefined,
    ...args.shell,
  } satisfies ShellHost;

  return {
    backend,
    shell,
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
  assert.equal(detail.followUp?.default_mode, "continue_here");
  assert.equal(detail.followUpState, "refine");
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

test("loadTaskWorktreeCleanupInfo returns the backend cleanup payload", async () => {
  const info = await loadTaskWorktreeCleanupInfo(
    makeRuntime({}),
    "workspace-1",
    "task-1",
  );

  assert.equal(info.state, "available");
  assert.equal(info.shared_task_count, 1);
  assert.equal(info.can_remove, true);
});

test("startTask forwards image attachments", async () => {
  let captured:
    | {
        workspace_id: string;
        description: string;
        image_attachments?: unknown[];
      }
    | undefined;

  await startTask(
    makeRuntime({
      onTaskStart: (params) => {
        captured = params as typeof captured;
      },
    }),
    {
      workspace_id: "workspace-1",
      description: "Inspect screenshot",
      config_alias: "default",
      config_path: "/tmp/config.yaml",
      image_attachments: [
        {
          name: "screen.png",
          mime_type: "image/png",
          size_bytes: 4,
          data_base64: "AAAAAA==",
        },
      ],
    },
  );

  assert.equal(captured?.workspace_id, "workspace-1");
  assert.equal(captured?.description, "Inspect screenshot");
  assert.deepEqual(captured?.image_attachments, [
    {
      name: "screen.png",
      mime_type: "image/png",
      size_bytes: 4,
      data_base64: "AAAAAA==",
    },
  ]);
});

test("startFollowUpFromTask forwards each supported follow-up mode", async () => {
  const modes = ["continue_here", "fork_head", "fork_with_changes"] as const;

  for (const mode of modes) {
    let captured:
      | {
          workspace_id: string;
          parent_task_id: string;
          description: string;
          follow_up_mode?: string;
        }
      | undefined;

    await startFollowUpFromTask(
      makeRuntime({
        onTaskStartFollowUp: (params) => {
          captured = params as typeof captured;
        },
      }),
      {
        workspaceId: "workspace-1",
        taskId: "task-1",
        task: makeTaskView("task-1"),
        description: "Follow up on the current task",
        followUpMode: mode,
      },
    );

    assert.equal(captured?.workspace_id, "workspace-1");
    assert.equal(captured?.parent_task_id, "task-1");
    assert.equal(captured?.description, "Follow up on the current task");
    assert.equal(captured?.follow_up_mode, mode);
  }
});

test("startFollowUpFromTask forwards image attachments", async () => {
  let captured:
    | {
        parent_task_id: string;
        image_attachments?: unknown[];
      }
    | undefined;

  await startFollowUpFromTask(
    makeRuntime({
      onTaskStartFollowUp: (params) => {
        captured = params as typeof captured;
      },
    }),
    {
      workspaceId: "workspace-1",
      taskId: "task-1",
      task: makeTaskView("task-1"),
      description: "Follow up with image",
      imageAttachments: [
        {
          name: "follow-up.webp",
          mime_type: "image/webp",
          size_bytes: 4,
          data_base64: "AAAAAA==",
        },
      ],
    },
  );

  assert.equal(captured?.parent_task_id, "task-1");
  assert.deepEqual(captured?.image_attachments, [
    {
      name: "follow-up.webp",
      mime_type: "image/webp",
      size_bytes: 4,
      data_base64: "AAAAAA==",
    },
  ]);
});

test("submitTaskApproval forwards image attachments outside the payload", async () => {
  let captured:
    | {
        payload?: Record<string, unknown>;
        image_attachments?: unknown[];
      }
    | undefined;

  await submitTaskApproval(
    makeRuntime({
      onTaskSubmitInput: (params) => {
        captured = params as typeof captured;
      },
    }),
    {
      workspaceId: "workspace-1",
      taskId: "task-1",
      inputRequest: {
        kind: "human_node",
        task_id: "task-1",
        node_run_id: "run-approve",
        node_name: "approve_plan",
      },
      approved: true,
      feedback: "Looks good",
      imageAttachments: [
        {
          name: "approval.png",
          mime_type: "image/png",
          size_bytes: 4,
          data_base64: "AAAAAA==",
        },
      ],
    },
  );

  assert.deepEqual(captured?.payload, {
    approved: true,
    feedback: "Looks good",
  });
  assert.deepEqual(captured?.image_attachments, [
    {
      name: "approval.png",
      mime_type: "image/png",
      size_bytes: 4,
      data_base64: "AAAAAA==",
    },
  ]);
  assert.equal(Object.hasOwn(captured?.payload ?? {}, "image_attachments"), false);
});

test("retryTaskUntilResumed polls task detail until the failed state clears", async () => {
  let captured:
    | {
        workspace_id: string;
        task_id: string;
        node_run_id: string;
      }
    | undefined;

  const failedTask = makeTaskView("task-1");
  failedTask.status = "failed";
  const runningTask = makeTaskView("task-1");
  runningTask.status = "running";

  const runtime = makeRuntime({
    taskGetResults: [
      {
        task: failedTask,
        live_events: [],
      },
      {
        task: runningTask,
        live_events: [],
      },
    ],
    onTaskRetryNode: (params) => {
      captured = params as typeof captured;
    },
  });

  const resumed = await retryTaskUntilResumed(runtime, {
    workspaceId: "workspace-1",
    taskId: "task-1",
    nodeRunId: "run-implement",
    force: false,
    delayMs: 0,
    attempts: 3,
    loadDetail: () =>
      hydrateTaskDetail(runtime, "workspace-1", "task-1", {
        includeAncestry: false,
      }),
  });

  assert.equal(resumed, true);
  assert.equal(captured?.workspace_id, "workspace-1");
  assert.equal(captured?.task_id, "task-1");
  assert.equal(captured?.node_run_id, "run-implement");
});

test("loadTaskAncestry returns the backend ancestry chain", async () => {
  const ancestry = await loadTaskAncestry(
    makeRuntime({}),
    "workspace-1",
    "task-1",
  );

  assert.deepEqual(ancestry, makeAncestry());
});

test("classifyArtifactPreview prefers markdown over image extensions", () => {
  assert.deepEqual(
    classifyArtifactPreview(
      makeArtifact({
        preview_name: "architecture.svg",
        resolved_path:
          "/tmp/workspace/.muxagent/tasks/task-1/artifacts/run-implement/architecture.svg",
        raw_path: "architecture.svg",
        markdown: true,
      }),
    ),
    { kind: "markdown" },
  );
});

test("classifyArtifactPreview recognizes image artifacts by extension", () => {
  assert.deepEqual(
    classifyArtifactPreview(
      makeArtifact({
        preview_name: "architecture.SVG",
        resolved_path:
          "/tmp/workspace/.muxagent/tasks/task-1/artifacts/run-implement/architecture.svg",
        raw_path: "architecture.svg",
        markdown: false,
      }),
    ),
    { kind: "image", mimeType: "image/svg+xml" },
  );
});

test("readArtifactPreview uses binary reads for image artifacts", async () => {
  let textReadCount = 0;
  let binaryRead:
    | {
        path: string;
        maxBytes: number;
      }
    | undefined;
  const artifact = makeArtifact({
    preview_name: "diagram.png",
    resolved_path:
      "/tmp/workspace/.muxagent/tasks/task-1/artifacts/run-implement/diagram.png",
    raw_path: "diagram.png",
    markdown: false,
  });

  const preview = await readArtifactPreview(
    makeRuntime({
      shell: {
        readTextFile: async () => {
          textReadCount += 1;
          return "unexpected text read";
        },
        readBinaryFile: async (path, maxBytes) => {
          binaryRead = { path, maxBytes };
          return Uint8Array.from([137, 80, 78, 71]);
        },
      },
    }),
    artifact,
  );

  assert.equal(textReadCount, 0);
  assert.deepEqual(binaryRead, {
    path: artifact.resolved_path,
    maxBytes: ARTIFACT_IMAGE_PREVIEW_MAX_BYTES,
  });
  assert.equal(preview.kind, "image");
  assert.equal(preview.mimeType, "image/png");
  assert.equal(preview.byteLength, 4);
  assert.deepEqual(Array.from(preview.bytes), [137, 80, 78, 71]);
});

test("readArtifactPreview returns a stable error for oversized images", async () => {
  await assert.rejects(
    readArtifactPreview(
      makeRuntime({
        shell: {
          readBinaryFile: async () => {
            throw new Error(
              "Artifact preview exceeds the 8 MB inline limit. Open externally to inspect the full file.",
            );
          },
        },
      }),
      makeArtifact({
        preview_name: "diagram.webp",
        resolved_path:
          "/tmp/workspace/.muxagent/tasks/task-1/artifacts/run-implement/diagram.webp",
        raw_path: "diagram.webp",
        markdown: false,
      }),
    ),
    /too large to preview in-app/,
  );
});

test("readArtifactPreview preserves text read failures", async () => {
  await assert.rejects(
    readArtifactPreview(
      makeRuntime({
        shell: {
          readTextFile: async () => {
            throw new Error("permission denied");
          },
        },
      }),
      makeArtifact({
        preview_name: "notes.txt",
        resolved_path:
          "/tmp/workspace/.muxagent/tasks/task-1/artifacts/run-implement/notes.txt",
        raw_path: "notes.txt",
        markdown: false,
      }),
    ),
    /permission denied/,
  );
});
