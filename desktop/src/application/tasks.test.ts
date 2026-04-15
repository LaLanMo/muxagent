import assert from "node:assert/strict";
import test from "node:test";
import {
  ARTIFACT_IMAGE_PREVIEW_MAX_BYTES,
  classifyArtifactPreview,
  hydrateTaskDetail,
  loadTaskAncestry,
  readArtifactPreview,
} from "@/application/tasks";
import type { DesktopRuntime, ShellHost, TaskBackendClient } from "@/platform/contract";
import type {
  ArtifactListResult,
  ArtifactRefDto,
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

function makeRuntime(args: {
  taskGetResult?: TaskGetResult;
  artifactListResult?: ArtifactListResult;
  taskGetAncestryResult?: TaskGetAncestryResult;
  taskGetAncestryError?: Error;
  onTaskGetAncestry?: () => void;
  shell?: Partial<ShellHost>;
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
