import { expect, test } from "@playwright/test";
import {
  addWorkspace,
  withSpawnedDesktopServer,
} from "../support/spawned-backend";

test("approves a seeded real awaiting task into the complete surface", async ({
  page,
}) => {
  test.slow();

  await withSpawnedDesktopServer(async ({ url, workDir, seedWorkspace }) => {
    const { taskId } = await seedWorkspace("awaiting-review");

    await page.goto(`${url}/`);
    await addWorkspace(page, workDir);

    const taskLink = page
      .getByRole("link", { name: /Seeded approval review/i })
      .first();
    await expect(taskLink).toBeVisible();
    await taskLink.click();

    await expect(page).toHaveURL(new RegExp(`/workspaces/[^/]+/tasks/${taskId}$`));
    await expect(page.getByTestId("approval-pane")).toBeVisible();
    await page.getByTestId("approval-approve").click();

    await expect(page.getByTestId("complete-pane")).toBeVisible();
    await expect(page.getByTestId("follow-up-description")).toBeVisible();
    await expect(page.getByTestId("follow-up-config-trigger")).toBeVisible();
  });
});

test("rejects a seeded real awaiting task without forcing the synthetic failed surface", async ({
  page,
}) => {
  test.slow();

  await withSpawnedDesktopServer(async ({ url, workDir, seedWorkspace }) => {
    const { taskId } = await seedWorkspace("awaiting-review");

    await page.goto(`${url}/`);
    await addWorkspace(page, workDir);

    const taskLink = page
      .getByRole("link", { name: /Seeded approval review/i })
      .first();
    await expect(taskLink).toBeVisible();
    await taskLink.click();

    await expect(page).toHaveURL(new RegExp(`/workspaces/[^/]+/tasks/${taskId}$`));
    await expect(page.getByTestId("approval-pane")).toBeVisible();
    await page.getByTestId("approval-reject").click({ force: true });

    await expect
      .poll(
        async () => {
          if (await page.getByTestId("approval-pane").isVisible().catch(() => false)) {
            return "approval";
          }
          if (await page.getByTestId("live-pane").isVisible().catch(() => false)) {
            return "live";
          }
          if (await page.getByTestId("failed-pane").isVisible().catch(() => false)) {
            return "failed";
          }
          if (await page.getByTestId("complete-pane").isVisible().catch(() => false)) {
            return "complete";
          }
          return "none";
        },
        { timeout: 30_000 },
      )
      .toMatch(/^(approval|live|complete)$/);
  });
});

test("starts a real follow-up task from a seeded completed task with a switched config", async ({
  page,
}) => {
  test.slow();

  await withSpawnedDesktopServer(async ({ url, workDir, seedWorkspace }) => {
    const description = `Seeded follow-up ${Date.now()}`;
    const { taskId } = await seedWorkspace("completed-review");

    await page.goto(`${url}/`);
    await addWorkspace(page, workDir);

    const taskLink = page
      .getByRole("link", { name: /Seeded completed review/i })
      .first();
    await expect(taskLink).toBeVisible();
    await taskLink.click();

    await expect(page).toHaveURL(new RegExp(`/workspaces/[^/]+/tasks/${taskId}$`));
    await expect(page.getByTestId("complete-pane")).toBeVisible();
    await page.getByTestId("follow-up-config-trigger").click();
    await expect(page.getByTestId("follow-up-config-picker")).toBeVisible();
    await page.getByTestId("follow-up-config-option-default").click();
    await expect(page.getByTestId("follow-up-config-trigger")).toContainText("default");
    await expect(page.getByTestId("follow-up-description")).toHaveJSProperty(
      "tagName",
      "TEXTAREA",
    );
    await page.getByTestId("follow-up-description").fill(description);
    const previousPath = new URL(page.url()).pathname;
    await page.getByTestId("follow-up-description").press("Enter");

    await expect
      .poll(() => new URL(page.url()).pathname, { timeout: 30_000 })
      .not.toBe(previousPath);
    await expect(page.getByTestId("task-detail-screen")).toBeVisible();
    await expect(page.locator(".detail-main-header__prompt-text")).toHaveText(description);
    await expect(
      page.locator(".detail-properties__block").filter({ hasText: /^Config/ }),
    ).toContainText("default");
  });
});

test("retries a seeded failed task into the live surface", async ({ page }) => {
  test.slow();

  await withSpawnedDesktopServer(async ({ url, workDir, seedWorkspace }) => {
    const { taskId } = await seedWorkspace("failed-retry");

    await page.goto(`${url}/`);
    await addWorkspace(page, workDir);

    const taskLink = page
      .getByRole("link", { name: /Seeded failed retry/i })
      .first();
    await expect(taskLink).toBeVisible();
    await taskLink.click();

    await expect(page).toHaveURL(
      new RegExp(`/workspaces/[^/]+/tasks/${taskId}$`),
    );
    await expect(page.getByTestId("failed-pane")).toBeVisible();
    await page.getByTestId("retry-step").click();

    await expect(page.getByTestId("live-pane")).toBeVisible({ timeout: 30_000 });
  });
});

test("continues a seeded blocked task into the live surface", async ({ page }) => {
  test.slow();

  await withSpawnedDesktopServer(async ({ url, workDir, seedWorkspace }) => {
    const { taskId } = await seedWorkspace("blocked-continue");

    await page.goto(`${url}/`);
    await addWorkspace(page, workDir);

    const taskLink = page
      .getByRole("link", { name: /Seeded blocked continue/i })
      .first();
    await expect(taskLink).toBeVisible();
    await taskLink.click();

    await expect(page).toHaveURL(
      new RegExp(`/workspaces/[^/]+/tasks/${taskId}$`),
    );
    await expect(page.getByTestId("blocked-pane")).toBeVisible();
    await page.getByTestId("continue-blocked").click();
    await expect(page.getByTestId("blocked-pane")).toBeHidden({ timeout: 30_000 });
    await expect
      .poll(
        async () => {
          if (await page.getByTestId("live-pane").isVisible().catch(() => false)) {
            return "live";
          }
          if (await page.getByTestId("failed-pane").isVisible().catch(() => false)) {
            return "failed";
          }
          if (await page.getByTestId("complete-pane").isVisible().catch(() => false)) {
            return "complete";
          }
          if (await page.getByTestId("blocked-pane").isVisible().catch(() => false)) {
            return "blocked";
          }
          return "none";
        },
        { timeout: 30_000 },
      )
      .toMatch(/^(live|failed|complete)$/);
  });
});

test("recovers a seeded stale run into a terminal state", async ({ page }) => {
  test.slow();

  await withSpawnedDesktopServer(async ({ url, workDir, seedWorkspace }) => {
    const { taskId } = await seedWorkspace("stale-recover");

    await page.goto(`${url}/`);
    await addWorkspace(page, workDir);

    const taskLink = page
      .getByRole("link", { name: /Seeded stale recovery/i })
      .first();
    await expect(taskLink).toBeVisible();
    await taskLink.click();

    await expect(page).toHaveURL(
      new RegExp(`/workspaces/[^/]+/tasks/${taskId}$`),
    );
    await page.getByTestId("detail-run-run-implement-stale").click();

    await expect(page).toHaveURL(/[\?&]modal=transcript/);
    await expect(page.getByTestId("transcript-modal")).toBeVisible();
    await expect(page.getByTestId("detail-output-surface")).toContainText(
      "No live output recorded yet",
    );
    await expect(page.getByTestId("recover-run")).toBeVisible();

    await page.getByTestId("recover-run").click();

    await expect(page.getByTestId("recover-run")).toHaveCount(0);
    await expect(page.getByTestId("transcript-modal")).toContainText(
      "No persisted stream for this run",
      { timeout: 30_000 },
    );
    await expect(page.getByTestId("transcript-modal")).toContainText("failed");
    await expect(page.getByTestId("detail-run-run-implement-stale")).toContainText(
      "failed",
    );
    await expect(page.getByTestId("failed-pane")).toBeVisible();
  });
});
