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
    await expect(page.getByTestId("start-follow-up")).toBeVisible();
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

test("starts a real follow-up task from a seeded completed task", async ({
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
    await page.getByTestId("follow-up-description").fill(description);
    const previousPath = new URL(page.url()).pathname;
    await page.getByTestId("start-follow-up").click();

    await expect
      .poll(() => new URL(page.url()).pathname, { timeout: 30_000 })
      .not.toBe(previousPath);
    await expect(page.getByTestId("task-detail-screen")).toBeVisible();
    await expect(page.getByRole("heading", { name: description })).toBeVisible();
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
