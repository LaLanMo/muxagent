import assert from "node:assert/strict";
import test from "node:test";
import {
  buildTaskBoardHref,
  buildTaskBoardPath,
  parseTaskBoardHref,
  parseTaskBoardPath,
  resolveWorkbenchTab,
  taskBoardTabId,
} from "@/domain/routes";

test("task board helpers build and parse all-workspaces board routes", () => {
  const scope = { kind: "all" as const };

  assert.equal(buildTaskBoardPath(scope), "/");
  assert.deepEqual(parseTaskBoardPath("/"), scope);
  assert.equal(taskBoardTabId(scope), "task-board");
  assert.equal(buildTaskBoardHref(scope, "?view=attention"), "/?view=attention");
});

test("task board helpers round-trip encoded workspace board routes", () => {
  const scope = { kind: "workspace" as const, workspaceId: "workspace:a b/slash" };

  assert.equal(
    buildTaskBoardPath(scope),
    "/workspaces/workspace%3Aa%20b%2Fslash/tasks",
  );
  assert.deepEqual(
    parseTaskBoardPath("/workspaces/workspace%3Aa%20b%2Fslash/tasks"),
    scope,
  );
  assert.equal(taskBoardTabId(scope), "task-board:workspace:a b/slash");
  assert.equal(
    buildTaskBoardHref(scope, "?view=active"),
    "/workspaces/workspace%3Aa%20b%2Fslash/tasks?view=active",
  );
});

test("parseTaskBoardHref canonicalizes board hrefs and strips transient query", () => {
  assert.deepEqual(parseTaskBoardHref("/?view=history&newTask=1"), {
    scope: { kind: "all" },
    pathname: "/",
    search: "?view=history",
    href: "/?view=history",
  });
  assert.deepEqual(
    parseTaskBoardHref("/workspaces/workspace-a/tasks?layout=list&view=attention"),
    {
      scope: { kind: "workspace", workspaceId: "workspace-a" },
      pathname: "/workspaces/workspace-a/tasks",
      search: "?view=attention",
      href: "/workspaces/workspace-a/tasks?view=attention",
    },
  );
  assert.equal(parseTaskBoardHref("/workspaces/workspace-a/tasks/task-1"), null);
});

test("resolveWorkbenchTab keeps board filters out of tab identity", () => {
  assert.deepEqual(resolveWorkbenchTab("/", "?view=attention&layout=list"), {
    id: "task-board",
    kind: "task-board",
    title: "Board",
    href: "/?view=attention",
    closeable: true,
  });
  assert.deepEqual(
    resolveWorkbenchTab(
      "/workspaces/workspace-a/tasks",
      "?view=active&newTask=1",
    ),
    {
      id: "task-board:workspace-a",
      kind: "task-board",
      title: "Board",
      href: "/workspaces/workspace-a/tasks?view=active",
      closeable: true,
    },
  );
});
