import assert from "node:assert/strict";
import test from "node:test";
import { preferredWorkspaceIdsForPath } from "@/features/app/model/task-route";

test("preferredWorkspaceIdsForPath prefers task detail route workspace", () => {
  assert.deepEqual(
    preferredWorkspaceIdsForPath(
      "/workspaces/workspace-a/tasks/task-1",
      "remembered",
    ),
    ["workspace-a", "remembered"],
  );
});

test("preferredWorkspaceIdsForPath prefers workspace board route workspace", () => {
  assert.deepEqual(
    preferredWorkspaceIdsForPath(
      "/workspaces/workspace-b/tasks",
      "remembered",
    ),
    ["workspace-b", "remembered"],
  );
});

test("preferredWorkspaceIdsForPath does not invent workspace ids for root or unrelated routes", () => {
  assert.deepEqual(preferredWorkspaceIdsForPath("/", "remembered"), [
    undefined,
    "remembered",
  ]);
  assert.deepEqual(preferredWorkspaceIdsForPath("/settings", "remembered"), [
    undefined,
    "remembered",
  ]);
});
