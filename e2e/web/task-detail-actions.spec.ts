import { expect, test, type Page } from "@playwright/test";

async function connectFixtureWorkspace(page: Page, workDir = "/tmp/muxagent-workspace") {
  await page.goto("/");
  await expect(page.getByTestId("workspace-picker-button")).toBeEnabled();
  page.once("dialog", (dialog) => dialog.accept(workDir));
  await page.getByTestId("workspace-picker-button").click();
  await expect(page.getByTestId("entry-shell")).toBeVisible();
}

test("approves an awaiting task into the complete surface", async ({ page }) => {
  await connectFixtureWorkspace(page);

  await page.getByTestId("board-card-task-awaiting-pr").click();
  await expect(page.getByTestId("approval-pane")).toBeVisible();
  await page.getByTestId("approval-approve").click();

  await expect(page.getByTestId("complete-pane")).toBeVisible();
  await expect(page.getByText("Task completed")).toBeVisible();
});

test("rejects an awaiting task into the failed surface", async ({ page }) => {
  await connectFixtureWorkspace(page);

  await page.getByTestId("board-card-task-awaiting-pr").click();
  await expect(page.getByTestId("approval-pane")).toBeVisible();
  await page.getByTestId("approval-reject").click({ force: true });

  await expect(page.getByTestId("failed-pane")).toBeVisible();
  await expect(page.getByText("Rejected during review")).toBeVisible();
});

test("starts a follow-up task from a completed task", async ({ page }) => {
  await connectFixtureWorkspace(page);

  await page.getByTestId("board-card-task-done-login").click();
  await expect(page.getByTestId("complete-pane")).toBeVisible();
  await page.getByTestId("follow-up-description").fill("Investigate remaining edge cases");
  await page.getByTestId("start-follow-up").click();

  await page.goBack();
  await expect(page).toHaveURL(/\/$/);
  await expect(page.getByTestId("entry-shell")).toBeVisible();
  await expect(page.getByText("Investigate remaining edge cases")).toBeVisible();
});

test("retries a failed task back into live output", async ({ page }) => {
  await connectFixtureWorkspace(page);

  await page.getByTestId("board-card-task-failed-deploy").click();
  await expect(page.getByTestId("failed-pane")).toBeVisible();
  await page.getByTestId("retry-step").click();

  await expect(page.getByTestId("live-pane")).toBeVisible();
  await expect(page.getByText("Output · verify")).toBeVisible();
});

test("continues a blocked task back into live output", async ({ page }) => {
  await connectFixtureWorkspace(page);

  await page.getByTestId("board-card-task-blocked-db").click();
  await expect(page.getByTestId("blocked-pane")).toBeVisible();
  await expect(page.getByText("Waiting for migration window")).toBeVisible();
  await page.getByTestId("continue-blocked").click();

  await expect(page.getByTestId("live-pane")).toBeVisible();
  await expect(page.getByText("Output · verify")).toBeVisible();
});
