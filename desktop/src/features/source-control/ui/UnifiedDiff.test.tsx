import assert from "node:assert/strict";
import test from "node:test";
import { renderToStaticMarkup } from "react-dom/server";
import type { GitDiffDto } from "@/rpc/types";
import { UnifiedDiff } from "@/features/source-control/ui/UnifiedDiff";

const patch = [
  "diff --git a/src/auth.ts b/src/auth.ts",
  "index aaaaaaa..bbbbbbb 100644",
  "--- a/src/auth.ts",
  "+++ b/src/auth.ts",
  "@@ -1,3 +1,7 @@",
  " export function signIn() {",
  "   return session;",
  " }",
  "+",
  "+export function signOut() {",
  "+  session.clear();",
  "+}",
  "",
].join("\n");

function renderDiff(diff: Partial<GitDiffDto>) {
  return renderToStaticMarkup(
    <UnifiedDiff
      diff={{
        reachable: true,
        truncated: false,
        binary: false,
        ...diff,
      }}
    />,
  );
}

test("UnifiedDiff preserves loading and error states", () => {
  assert.match(
    renderToStaticMarkup(<UnifiedDiff loading />),
    /data-testid="unified-diff"/,
  );
  assert.match(
    renderToStaticMarkup(<UnifiedDiff error="Failed to load" />),
    /data-testid="unified-diff-error"/,
  );
});

test("UnifiedDiff renders parsed file sections with library diff markup", () => {
  const markup = renderDiff({ file_count: 1, patch });

  assert.match(markup, /data-testid="unified-diff"/);
  assert.match(markup, /data-testid="unified-diff-file"/);
  assert.match(markup, /src\/auth\.ts/);
  assert.match(markup, /export function signOut/);
  assert.match(markup, /class="diff-view__file-body"/);
  assert.match(markup, /class="[^"]*diff-split/);
  assert.match(markup, /class="[^"]*diff-gutter/);
});

test("UnifiedDiff strips legacy prelude before parsing patch text", () => {
  const markup = renderDiff({
    file_count: 1,
    patch: [
      "commit abc1234",
      "Author: Fixture Author <fixture@example.com>",
      " src/auth.ts | 4 ++++",
      " 1 file changed, 4 insertions(+)",
      "",
      patch,
    ].join("\n"),
  });

  assert.match(markup, /src\/auth\.ts/);
  assert.match(markup, /export function signOut/);
  assert.doesNotMatch(markup, /files changed/);
  assert.doesNotMatch(markup, /Author:/);
});
