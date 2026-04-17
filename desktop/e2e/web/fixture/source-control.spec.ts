import { expect, test, type Page } from "@playwright/test";
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

test("selecting a worktree renders the worktree overview in the right pane", async ({
  page,
}) => {
  await connectFixtureWorkspace(page);
  await openSourceControlPanel(page);

  await page.getByTestId("source-control-checkout-feat-auth-refactor").click();
  await expect(page.getByTestId("worktree-overview")).toBeVisible();
  await expect(page.getByTestId("worktree-overview")).toContainText(
    "feat/auth-refactor",
  );

  await maybeScreenshot(page, "MUXAGENT_WORKTREE_OVERVIEW_SCREENSHOT");
});

test("selecting a file under a worktree renders its diff", async ({ page }) => {
  await connectFixtureWorkspace(page);
  await openSourceControlPanel(page);

  await page.getByTestId("source-control-checkout-feat-auth-refactor").click();
  await expect(page.getByTestId("worktree-overview")).toBeVisible();

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
  await expect(page.getByTestId("worktree-overview")).toBeVisible();

  await page.getByTestId("source-control-commit-fa3b2").first().click();
  await expect(page.getByTestId("source-control-commit-diff")).toBeVisible();
  await expect(page.getByTestId("unified-diff")).toBeVisible();

  await maybeScreenshot(page, "MUXAGENT_COMMIT_DIFF_SCREENSHOT");
});

test("selecting a task under a worktree opens the task detail screen", async ({
  page,
}) => {
  await connectFixtureWorkspace(page);
  await openSourceControlPanel(page);

  await page.getByTestId("source-control-checkout-feat-auth-refactor").click();
  await expect(page.getByTestId("worktree-overview")).toBeVisible();

  const taskLink = page
    .getByTestId("worktree-overview")
    .locator('[data-testid^="worktree-overview-task-"]')
    .first();

  const taskCount = await taskLink.count();
  if (taskCount === 0) {
    test.skip(true, "No tasks seeded on the feat/auth-refactor worktree");
    return;
  }

  await taskLink.click();
  await expect(page.getByTestId("task-detail-screen")).toBeVisible();

  await maybeScreenshot(page, "MUXAGENT_TASK_UNDER_WORKTREE_SCREENSHOT");
});
