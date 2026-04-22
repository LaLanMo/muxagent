import { expect, test, type Locator, type Page } from "@playwright/test";
import { skipOnboarding } from "./_helpers";

async function connectFixtureWorkspace(
  page: Page,
  workDir = "/tmp/muxagent-source-control",
) {
  await skipOnboarding(page);
  await page.setViewportSize({ width: 1500, height: 980 });
  await page.goto("/");
  await expect(page.getByTestId("workspace-picker-button")).toBeEnabled();
  page.once("dialog", (dialog) => dialog.accept(workDir));
  await page.getByTestId("workspace-picker-button").click();
  await expect(page.getByTestId("entry-shell")).toBeVisible();
}

async function maybeScreenshot(page: Page, envName: string) {
  const screenshotPath = process.env[envName]?.trim();
  if (!screenshotPath) return;
  await page.getByTestId("workbench-shell").screenshot({ path: screenshotPath });
}

async function requiredBox(locator: Locator) {
  const box = await locator.boundingBox();
  expect(box).not.toBeNull();
  return box!;
}

async function openSourceControlPanel(page: Page) {
  await page.getByTestId("workbench-activity-source-control").click();
  await expect(page.getByTestId("source-control-panel")).toBeVisible();
  await expect(page.getByTestId("source-control-checkout-list")).toContainText(
    "feat/auth-refactor",
  );
}

test("tasks panel does not clobber the right pane on empty workspace", async ({
  page,
}) => {
  await connectFixtureWorkspace(page);
  await expect(page.getByTestId("workbench-activity-tasks")).toHaveAttribute(
    "aria-pressed",
    "true",
  );
  await expect(page.getByTestId("tasks-panel")).toBeVisible();
  await expect(page.getByTestId("entry-shell")).toBeVisible();

  await maybeScreenshot(page, "MUXAGENT_PANEL_TASKS_SCREENSHOT");
});

test("opening source-control panel keeps right pane untouched until selection", async ({
  page,
}) => {
  await connectFixtureWorkspace(page);
  await openSourceControlPanel(page);

  // The main pane should still be the entry/board screen, not a diff view.
  await expect(page.getByTestId("entry-shell")).toBeVisible();
  await expect(page.getByTestId("worktree-overview")).toHaveCount(0);
  await expect(page.getByTestId("source-control-file-diff")).toHaveCount(0);
  await expect(page.getByTestId("source-control-commit-diff")).toHaveCount(0);

  await maybeScreenshot(page, "MUXAGENT_PANEL_SOURCE_CONTROL_SCREENSHOT");
});

test("source-control: clicking a collapsed worktree name toggles it open without changing the current route", async ({
  page,
}) => {
  await connectFixtureWorkspace(page);
  await openSourceControlPanel(page);

  await expect(page.getByTestId("source-control-checkout-body-main")).toHaveCount(0);
  await expect(page.getByTestId("source-control-checkout-row-main")).toHaveAttribute(
    "data-selected",
    "false",
  );

  await page.getByTestId("source-control-checkout-main").click();

  await expect(page).toHaveURL(/\/$/);
  await expect(page.getByTestId("entry-shell")).toBeVisible();
  await expect(page.getByTestId("source-control-checkout-body-main")).toBeVisible();
  await expect(page.getByTestId("source-control-checkout-main")).toHaveAttribute(
    "aria-expanded",
    "true",
  );
  await expect(page.getByTestId("source-control-checkout-row-main")).toHaveAttribute(
    "data-selected",
    "false",
  );
});

test("source-control: clicking the same worktree name again collapses it without changing the current route", async ({
  page,
}) => {
  await connectFixtureWorkspace(page);
  await openSourceControlPanel(page);

  await page.getByTestId("source-control-checkout-main").click();
  await expect(page.getByTestId("source-control-checkout-body-main")).toBeVisible();
  await page.getByTestId("source-control-checkout-main").click();

  await expect(page).toHaveURL(/\/$/);
  await expect(page.getByTestId("entry-shell")).toBeVisible();
  await expect(page.getByTestId("source-control-checkout-body-main")).toHaveCount(0);
  await expect(page.getByTestId("source-control-checkout-main")).toHaveAttribute(
    "aria-expanded",
    "false",
  );
});

test("source-control: navigating into one expanded worktree does not collapse other expanded worktrees", async ({
  page,
}) => {
  await connectFixtureWorkspace(page);
  await openSourceControlPanel(page);

  await page.getByTestId("source-control-checkout-main").click();
  await expect(page.getByTestId("source-control-checkout-body-main")).toBeVisible();

  await page.getByTestId("source-control-checkout-feat-auth-refactor").click();
  await expect(
    page.getByTestId("source-control-checkout-body-feat-auth-refactor"),
  ).toBeVisible();

  await page.getByTestId("source-control-file-unstaged:src/auth.ts").first().click();
  await expect(page).toHaveURL(/\/files\/.+$/);
  await expect(page.getByTestId("source-control-file-diff")).toBeVisible();
  await expect(page.getByTestId("source-control-checkout-body-main")).toBeVisible();
  await expect(
    page.getByTestId("source-control-checkout-body-feat-auth-refactor"),
  ).toBeVisible();
});

test("source-control: a worktree header re-expands a collapsed non-selected worktree after route changes without changing the current center route", async ({
  page,
}) => {
  await connectFixtureWorkspace(page);
  await openSourceControlPanel(page);

  await page.getByTestId("source-control-checkout-main").click();
  await expect(page.getByTestId("source-control-checkout-body-main")).toBeVisible();
  await page.getByTestId("source-control-checkout-main").click();
  await expect(page.getByTestId("source-control-checkout-body-main")).toHaveCount(0);

  await page.getByTestId("source-control-checkout-feat-auth-refactor").click();
  await expect(
    page.getByTestId("source-control-checkout-body-feat-auth-refactor"),
  ).toBeVisible();
  await page.getByTestId("source-control-file-unstaged:src/auth.ts").first().click();
  await expect(page.getByTestId("source-control-file-diff")).toBeVisible();

  const activeDiffUrl = page.url();
  await page.getByTestId("source-control-checkout-main").click();

  await expect(page).toHaveURL(activeDiffUrl);
  await expect(page.getByTestId("source-control-file-diff")).toBeVisible();
  await expect(page.getByTestId("source-control-checkout-body-main")).toBeVisible();
  await expect(
    page.getByTestId("source-control-checkout-body-feat-auth-refactor"),
  ).toBeVisible();
});

test("source-control: clicking the selected worktree name on a file diff route toggles expansion without changing the diff route", async ({
  page,
}) => {
  await connectFixtureWorkspace(page);
  await openSourceControlPanel(page);

  await page.getByTestId("source-control-checkout-feat-auth-refactor").click();
  await expect(
    page.getByTestId("source-control-checkout-body-feat-auth-refactor"),
  ).toBeVisible();
  await page.getByTestId("source-control-file-unstaged:src/auth.ts").first().click();
  await expect(page.getByTestId("source-control-file-diff")).toBeVisible();
  await expect(
    page.getByTestId("source-control-checkout-row-feat-auth-refactor"),
  ).toHaveAttribute("data-selected", "true");

  const activeDiffUrl = page.url();

  await page.getByTestId("source-control-checkout-feat-auth-refactor").click();

  await expect(page).toHaveURL(activeDiffUrl);
  await expect(page.getByTestId("source-control-file-diff")).toBeVisible();
  await expect(
    page.getByTestId("source-control-checkout-body-feat-auth-refactor"),
  ).toHaveCount(0);
  await expect(
    page.getByTestId("source-control-checkout-row-feat-auth-refactor"),
  ).toHaveAttribute("data-selected", "true");

  await page.getByTestId("source-control-checkout-feat-auth-refactor").click();
  await expect(page).toHaveURL(activeDiffUrl);
  await expect(page.getByTestId("source-control-file-diff")).toBeVisible();
  await expect(
    page.getByTestId("source-control-checkout-body-feat-auth-refactor"),
  ).toBeVisible();
});

test("source-control: the board route does not mark any worktree selected before navigation", async ({
  page,
}) => {
  await connectFixtureWorkspace(page);
  await openSourceControlPanel(page);

  await expect(page).toHaveURL(/\/$/);
  await expect(page.getByTestId("source-control-checkout-body-main")).toHaveCount(0);
  await expect(
    page.getByTestId("source-control-checkout-body-feat-auth-refactor"),
  ).toHaveCount(0);
  await expect(
    page.getByTestId("source-control-checkout-row-feat-auth-refactor"),
  ).toHaveAttribute("data-selected", "false");
  await expect(page.getByTestId("source-control-checkout-row-main")).toHaveAttribute(
    "data-selected",
    "false",
  );
});

test("selecting a file under a worktree renders its diff", async ({ page }) => {
  await connectFixtureWorkspace(page);
  await openSourceControlPanel(page);

  await page.getByTestId("source-control-checkout-feat-auth-refactor").click();
  await expect(
    page.getByTestId("source-control-checkout-body-feat-auth-refactor"),
  ).toBeVisible();

  await page.getByTestId("source-control-file-unstaged:src/auth.ts").first().click();
  await expect(page.getByTestId("source-control-file-diff")).toBeVisible();
  await expect(page.getByTestId("source-control-file-diff-title")).toContainText(
    "src/auth.ts",
  );
  await expect(page.getByTestId("unified-diff")).toBeVisible();

  await maybeScreenshot(page, "MUXAGENT_FILE_DIFF_SCREENSHOT");
});

test("selecting a commit under a worktree renders the full commit diff", async ({
  page,
}) => {
  await connectFixtureWorkspace(page);
  await openSourceControlPanel(page);

  await page.getByTestId("source-control-checkout-feat-auth-refactor").click();
  await expect(
    page.getByTestId("source-control-checkout-body-feat-auth-refactor"),
  ).toBeVisible();

  await page.getByTestId("source-control-commit-fa3b2").first().click();
  await expect(page.getByTestId("source-control-commit-diff")).toBeVisible();
  await expect(page.getByTestId("source-control-commit-diff-title")).toContainText(
    "Fixture commit diff",
  );
  await expect(page.getByTestId("unified-diff")).toBeVisible();
  await expect(page.getByTestId("unified-diff")).toContainText("src/auth.ts");
  await expect(page.getByTestId("unified-diff")).toContainText(
    "export function signOut",
  );
  await expect(page.getByTestId("unified-diff")).not.toContainText(
    "files changed",
  );

  await maybeScreenshot(page, "MUXAGENT_COMMIT_DIFF_SCREENSHOT");
});

test("source-control: horizontal diff scroll keeps the diff chrome anchored", async ({
  page,
}) => {
  await connectFixtureWorkspace(page);
  await page.setViewportSize({ width: 980, height: 760 });
  await openSourceControlPanel(page);

  await page.getByTestId("source-control-checkout-feat-auth-refactor").click();
  await expect(
    page.getByTestId("source-control-checkout-body-feat-auth-refactor"),
  ).toBeVisible();

  await page.getByTestId("source-control-commit-fa3b2").first().click();
  await expect(page.getByTestId("source-control-commit-diff")).toBeVisible();

  const diff = page.getByTestId("unified-diff");
  const toolbar = diff.locator(".diff-view__toolbar");
  const fileHeader = diff.locator(".diff-view__file-header").first();
  const fileBody = diff.locator(".diff-view__file-body").first();
  await expect(fileBody).toBeVisible();

  const outerScroll = await diff.evaluate((element) => ({
    clientWidth: element.clientWidth,
    scrollWidth: element.scrollWidth,
  }));
  expect(outerScroll.scrollWidth).toBeLessThanOrEqual(outerScroll.clientWidth + 2);

  const bodyScroll = await fileBody.evaluate((element) => ({
    clientWidth: element.clientWidth,
    scrollWidth: element.scrollWidth,
  }));
  expect(bodyScroll.scrollWidth).toBeGreaterThan(bodyScroll.clientWidth + 20);

  const toolbarBefore = await requiredBox(toolbar);
  const headerBefore = await requiredBox(fileHeader);
  const bodyScrollLeft = await fileBody.evaluate((element) => {
    element.scrollLeft = element.scrollWidth;
    return element.scrollLeft;
  });
  expect(bodyScrollLeft).toBeGreaterThan(0);

  const toolbarAfter = await requiredBox(toolbar);
  const headerAfter = await requiredBox(fileHeader);
  expect(Math.abs(toolbarAfter.x - toolbarBefore.x)).toBeLessThanOrEqual(1);
  expect(Math.abs(headerAfter.x - headerBefore.x)).toBeLessThanOrEqual(1);
});

test("selecting a task under a worktree opens the task detail screen", async ({
  page,
}) => {
  await connectFixtureWorkspace(page);
  await openSourceControlPanel(page);

  await page.getByTestId("source-control-checkout-feat-auth-refactor").click();
  await expect(
    page.getByTestId("source-control-checkout-body-feat-auth-refactor"),
  ).toBeVisible();

  const taskLink = page.getByTestId("source-control-task-task-scm-wire-jwt").first();

  const taskCount = await taskLink.count();
  if (taskCount === 0) {
    test.skip(true, "No tasks seeded on the feat/auth-refactor worktree");
    return;
  }

  await taskLink.click();
  await expect(page.getByTestId("task-detail-screen")).toBeVisible();

  await maybeScreenshot(page, "MUXAGENT_TASK_UNDER_WORKTREE_SCREENSHOT");
});

test("source-control: legacy checkout routes fall back to the board", async ({
  page,
}) => {
  await connectFixtureWorkspace(page);
  await openSourceControlPanel(page);

  await page.getByTestId("source-control-checkout-feat-auth-refactor").click();
  await page.getByTestId("source-control-file-unstaged:src/auth.ts").first().click();
  await expect(page.getByTestId("source-control-file-diff")).toBeVisible();

  const legacyCheckoutUrl = page.url().replace(/\/files\/[^/]+$/, "");
  await page.goto(legacyCheckoutUrl);

  await expect(page).toHaveURL(/\/$/);
  await expect(page.getByTestId("entry-shell")).toBeVisible();
});
