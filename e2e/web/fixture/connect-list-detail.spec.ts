import { expect, test } from "@playwright/test";

test("opens a workspace from the shell and drills into task detail", async ({ page }) => {
  await page.goto("/");

  await expect(page.getByTestId("workspace-picker-button")).toBeEnabled();
  page.once("dialog", (dialog) => dialog.accept("/tmp/muxagent-workspace"));
  await page.getByTestId("workspace-picker-button").click();

  await expect(page.getByTestId("entry-shell")).toBeVisible();
  await expect(page.getByTestId("list-row-task-live-fixture")).toContainText(
    "Refactor auth middleware",
  );

  await page.getByTestId("list-row-task-live-fixture").click();

  await expect(page).toHaveURL(/\/workspaces\/[^/]+\/tasks\/task-live-fixture$/);
  await expect(page.getByTestId("task-detail-screen")).toBeVisible();
  await expect(page.getByText("Refactor auth middleware")).toBeVisible();
  await expect(page.getByText("Run · implement")).toBeVisible();
});

test("merges replay history with live output for the selected running run", async ({
  page,
}) => {
  await page.goto("/");

  await expect(page.getByTestId("workspace-picker-button")).toBeEnabled();
  page.once("dialog", (dialog) => dialog.accept("/tmp/muxagent-workspace"));
  await page.getByTestId("workspace-picker-button").click();

  await page.getByTestId("list-row-task-live-fixture").click();

  const outputSurface = page.getByTestId("detail-output-surface");
  await expect(outputSurface).toBeVisible();
  await expect(outputSurface).toContainText("search: auth middleware entry points");
  await expect(outputSurface).toContainText("drafted middleware patch plan");
  await expect(outputSurface).toContainText("edit running: src/auth/middleware.ts");
  await expect(outputSurface).toContainText("applying middleware changes");
});

test("task deep links restore the route workspace even after switching to another workspace", async ({
  page,
}) => {
  await page.goto("/");

  await expect(page.getByTestId("workspace-picker-button")).toBeEnabled();
  page.once("dialog", (dialog) => dialog.accept("/tmp/muxagent-workspace"));
  await page.getByTestId("workspace-picker-button").click();

  await expect(page.getByTestId("list-row-task-live-fixture")).toBeVisible();
  await page.getByTestId("list-row-task-live-fixture").click();
  await expect(page).toHaveURL(/\/workspaces\/[^/]+\/tasks\/task-live-fixture$/);
  const firstWorkspaceDetailPath = new URL(page.url()).pathname;
  await expect(
    page.locator(".shell-workspace__row.is-active .shell-workspace__label").first(),
  ).toContainText(
    "muxagent-workspace",
  );

  await page.goBack();
  await expect(page).toHaveURL(/\/$/);
  await expect(page.getByTestId("entry-shell")).toBeVisible();
  await expect(page.getByTestId("workspace-picker-button")).toBeEnabled();
  page.once("dialog", (dialog) => dialog.accept("/tmp/muxagent-alt-workspace"));
  await page.getByTestId("workspace-picker-button").click();
  await page
    .locator(".shell-workspace__row")
    .filter({ hasText: "muxagent-alt-workspace" })
    .click();
  await expect(
    page.locator(".shell-workspace__row.is-active .shell-workspace__label").first(),
  ).toContainText("muxagent-alt-workspace");

  await page.evaluate((pathname) => {
    window.history.pushState({}, "", pathname);
    window.dispatchEvent(new PopStateEvent("popstate"));
  }, firstWorkspaceDetailPath);

  await expect(page).toHaveURL(new RegExp(`${firstWorkspaceDetailPath}$`));
  await expect(page.getByTestId("task-detail-screen")).toBeVisible();
  await expect(
    page.locator(".shell-workspace__row.is-active .shell-workspace__label").first(),
  ).toContainText(
    "muxagent-workspace",
  );
});

test("treats Tasks as the all-workspaces view and workspace rows as task scope", async ({
  page,
}) => {
  await page.goto("/");

  await expect(page.getByTestId("workspace-picker-button")).toBeEnabled();
  page.once("dialog", (dialog) => dialog.accept("/tmp/muxagent-workspace"));
  await page.getByTestId("workspace-picker-button").click();
  page.once("dialog", (dialog) => dialog.accept("/tmp/muxagent-alt-workspace"));
  await page.getByTestId("workspace-picker-button").click();
  await expect(page.locator(".shell-workspace__row.is-active")).toHaveCount(0);

  await page
    .locator(".shell-workspace__row")
    .filter({ hasText: "muxagent-alt-workspace" })
    .click();
  await expect(
    page.locator(".shell-workspace__row.is-active .shell-workspace__label").first(),
  ).toContainText("muxagent-alt-workspace");

  await page.getByRole("link", { name: /^Tasks$/i }).click();
  await expect(page).toHaveURL(/\/$/);
  await expect(page.locator(".shell-workspace__row.is-active")).toHaveCount(0);
  await expect(page.getByTestId("task-list")).toContainText("muxagent-workspace");
  await expect(page.getByTestId("task-list")).toContainText("muxagent-alt-workspace");

  await page.getByRole("link", { name: /^Configs$/i }).click();
  await expect(page.getByTestId("configs-screen")).toBeVisible();
  await page
    .locator(".shell-workspace__row")
    .filter({ hasText: "muxagent-alt-workspace" })
    .click();
  await expect(page).toHaveURL(/\/$/);
  await expect(
    page.locator(".shell-workspace__row.is-active .shell-workspace__label").first(),
  ).toContainText("muxagent-alt-workspace");
});

test("renders approval and artifact preview task surfaces", async ({ page }) => {
  await page.goto("/");

  await expect(page.getByTestId("workspace-picker-button")).toBeEnabled();
  page.once("dialog", (dialog) => dialog.accept("/tmp/muxagent-workspace"));
  await page.getByTestId("workspace-picker-button").click();

  await page.getByTestId("list-row-task-awaiting-pr").click();
  await expect(page.getByTestId("approval-pane")).toBeVisible();
  await expect(page.getByText("Review PR #42")).toBeVisible();
  await expect(page.getByRole("button", { name: "Approve" })).toBeVisible();

  await page.goBack();
  await expect(page).toHaveURL(/\/$/);
  await page.getByTestId("list-row-task-live-fixture").click();
  await page.getByRole("button", { name: /plan\.md/i }).click();
  await expect(page.getByTestId("artifact-pane")).toBeVisible();
  await expect(page.getByText("Fixture artifact generated by the desktop web bridge.")).toBeVisible();
  await page.getByRole("button", { name: /summary\.md/i }).click();
  await expect(page.getByTestId("artifact-pane")).toBeVisible();
  await expect(page.getByText("Preview · summary.md")).toBeVisible();
});

test("keeps run history visible while showing the clarification action surface", async ({
  page,
}) => {
  await page.goto("/");

  await expect(page.getByTestId("workspace-picker-button")).toBeEnabled();
  page.once("dialog", (dialog) => dialog.accept("/tmp/muxagent-workspace"));
  await page.getByTestId("workspace-picker-button").click();

  await page
    .getByRole("link", { name: /Clarify deployment strategy before implement/i })
    .click();
  await expect(page.getByTestId("clarification-pane")).toBeVisible();
  await expect(page.getByTestId("run-pane")).toBeVisible();
  await expect(
    page.getByText("Which deployment target should we prioritize first?"),
  ).toBeVisible();
  await expect(page.getByTestId("detail-run-run-clarify-implement")).toBeVisible();
  await page.getByTestId("detail-run-run-clarify-plan").click();
  const outputSurface = page.getByTestId("detail-output-surface");
  await expect(outputSurface).toBeVisible();
  await expect(outputSurface).toContainText("read: docs/deploy.md");
  await expect(outputSurface).toContainText("deployment plan drafted");
  await expect(page).toHaveURL(/[\?&]run=run-clarify-plan/);
});

test("resets clarification pager when switching to another clarification task", async ({
  page,
}) => {
  await page.goto("/");

  await expect(page.getByTestId("workspace-picker-button")).toBeEnabled();
  page.once("dialog", (dialog) => dialog.accept("/tmp/muxagent-workspace"));
  await page.getByTestId("workspace-picker-button").click();

  await page
    .getByRole("link", { name: /Clarify deployment strategy before implement/i })
    .click();
  await expect(
    page.getByText("Which deployment target should we prioritize first?"),
  ).toBeVisible();
  await page.getByRole("button", { name: "Next clarification" }).click();
  await expect(
    page.getByText("Should we gate the rollout behind a feature flag?"),
  ).toBeVisible();

  await page.getByTestId("task-detail-back").click();
  await expect(page).toHaveURL(/\/$/);

  await page
    .getByRole("link", { name: /Clarify rollout checklist before verify/i })
    .click();
  await expect(
    page.getByText("Which checklist should verify follow first?"),
  ).toBeVisible();
  await expect(
    page.getByText("Do we need customer-facing confirmation in this pass?"),
  ).not.toBeVisible();
});

test("renders failed and complete task surfaces", async ({ page }) => {
  await page.goto("/");

  await expect(page.getByTestId("workspace-picker-button")).toBeEnabled();
  page.once("dialog", (dialog) => dialog.accept("/tmp/muxagent-workspace"));
  await page.getByTestId("workspace-picker-button").click();

  await page.getByTestId("list-row-task-failed-deploy").click();
  await expect(page.getByTestId("failed-pane")).toBeVisible();
  await expect(
    page.getByTestId("failed-pane").getByText("Health check failed after deploy"),
  ).toBeVisible();

  await page.goBack();
  await expect(page).toHaveURL(/\/$/);
  await page.getByTestId("list-row-task-done-login").click();
  await expect(page.getByTestId("complete-pane")).toBeVisible();
  await expect(page.getByTestId("start-follow-up")).toBeVisible();
});

test("renders the blocked task surface", async ({ page }) => {
  await page.goto("/");

  await expect(page.getByTestId("workspace-picker-button")).toBeEnabled();
  page.once("dialog", (dialog) => dialog.accept("/tmp/muxagent-workspace"));
  await page.getByTestId("workspace-picker-button").click();

  await page.getByTestId("list-row-task-blocked-db").click();
  await expect(page.getByTestId("blocked-pane")).toBeVisible();
  await expect(page.getByText("Waiting for migration window")).toBeVisible();
  await expect(page.getByRole("button", { name: "Continue" })).toBeVisible();
});

test("supports switching between board and list task surfaces", async ({ page }) => {
  await page.goto("/");

  await expect(page.getByTestId("workspace-picker-button")).toBeEnabled();
  page.once("dialog", (dialog) => dialog.accept("/tmp/muxagent-workspace"));
  await page.getByTestId("workspace-picker-button").click();

  await expect(page.getByTestId("task-list")).toBeVisible();
  await expect(page.getByTestId("list-row-task-done-long-copy")).toContainText(
    "帮我想办法给这个网站搞 SEO",
  );

  await page.getByTestId("task-layout-board").click();
  await expect(page.getByTestId("task-board")).toBeVisible();
  await page.getByTestId("task-layout-list").click();
  await expect(page.getByTestId("task-list")).toBeVisible();
});

test("keeps long board cards readable and allows horizontal overflow on narrower widths", async ({
  page,
}) => {
  await page.setViewportSize({ width: 980, height: 860 });
  await page.goto("/");

  await expect(page.getByTestId("workspace-picker-button")).toBeEnabled();
  page.once("dialog", (dialog) => dialog.accept("/tmp/muxagent-workspace"));
  await page.getByTestId("workspace-picker-button").click();

  await page.getByTestId("task-layout-board").click();
  const boardSurface = page.getByTestId("task-board");
  await expect(boardSurface).toBeVisible();

  const hasHorizontalOverflow = await boardSurface.evaluate((element) => {
    return element.scrollWidth > element.clientWidth;
  });
  expect(hasHorizontalOverflow).toBe(true);

  const longCard = page.getByTestId("board-card-task-done-long-copy");
  const title = longCard.locator("h3");
  const meta = longCard.locator(".task-board-card__meta");
  const cardBox = await longCard.boundingBox();

  const titleBox = await title.boundingBox();
  const metaBox = await meta.boundingBox();

  expect(cardBox).not.toBeNull();
  expect(titleBox).not.toBeNull();
  expect(metaBox).not.toBeNull();
  expect(cardBox?.height ?? 0).toBeLessThan(220);
  expect((titleBox?.y ?? 0) + (titleBox?.height ?? 0)).toBeLessThanOrEqual(
    (metaBox?.y ?? 0) + 1,
  );
});

test("keeps dense completed-column cards at their natural height instead of shrinking them", async ({
  page,
}) => {
  await page.goto("/");

  await expect(page.getByTestId("workspace-picker-button")).toBeEnabled();
  page.once("dialog", (dialog) => dialog.accept("/tmp/muxagent-workspace"));
  await page.getByTestId("workspace-picker-button").click();

  await page.getByTestId("task-layout-board").click();
  const completedCard = page.getByTestId("board-card-task-done-login");
  const meta = completedCard.locator(".task-board-card__meta");
  const stamp = completedCard.locator(".task-board-card__stamp");

  await expect(completedCard).toBeVisible();
  await expect(meta).toBeVisible();
  await expect(stamp).toBeVisible();

  const cardBox = await completedCard.boundingBox();
  const metaBox = await meta.boundingBox();
  const stampBox = await stamp.boundingBox();

  expect(cardBox).not.toBeNull();
  expect(metaBox).not.toBeNull();
  expect(stampBox).not.toBeNull();
  expect(cardBox?.height ?? 0).toBeGreaterThanOrEqual(54);
  expect((stampBox?.y ?? 0) + (stampBox?.height ?? 0)).toBeLessThanOrEqual(
    (cardBox?.y ?? 0) + (cardBox?.height ?? 0) + 1,
  );
});
