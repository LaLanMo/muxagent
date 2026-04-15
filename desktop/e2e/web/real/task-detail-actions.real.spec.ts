import { expect, test } from "@playwright/test";
import {
  addWorkspace,
  withSpawnedDesktopServer,
} from "../support/spawned-backend";

async function delayNextTaskGetForTask(
  page: import("@playwright/test").Page,
  taskId: string,
  delayMs = 700,
) {
  await page.evaluate(async ({ delayMs: nextDelayMs, taskId: nextTaskId }) => {
    const storeModule = await import("/src/state/task-snapshot-store.ts");
    const store = storeModule.useTaskSnapshotStore as {
      getState(): {
        resolveTaskDetail: (
          workspaceId: string,
          taskId: string,
          snapshotKey: string | undefined,
          generation: number,
          detail: {
            config?: unknown;
            inputRequest?: unknown;
            followUp?: unknown;
            artifacts: unknown[];
            ancestry: unknown[];
            liveEventsRunId?: string;
          },
        ) => void;
      };
      setState(
        partial: Partial<{
          resolveTaskDetail: (
            workspaceId: string,
            taskId: string,
            snapshotKey: string | undefined,
            generation: number,
            detail: {
              config?: unknown;
              inputRequest?: unknown;
              followUp?: unknown;
              artifacts: unknown[];
              ancestry: unknown[];
              liveEventsRunId?: string;
            },
          ) => void;
        }>,
      ): void;
    };
    const testWindow = window as Window & {
      __testTaskDetailDelayInstalled?: boolean;
    };
    if (testWindow.__testTaskDetailDelayInstalled) {
      return;
    }
    const originalResolveTaskDetail = store.getState().resolveTaskDetail;
    let delayed = false;
    store.setState({
      resolveTaskDetail: (workspaceId, taskId, snapshotKey, generation, detail) => {
        if (!delayed && taskId === nextTaskId) {
          delayed = true;
          window.setTimeout(() => {
            originalResolveTaskDetail(workspaceId, taskId, snapshotKey, generation, detail);
          }, nextDelayMs);
          return;
        }
        originalResolveTaskDetail(workspaceId, taskId, snapshotKey, generation, detail);
      },
    });
    testWindow.__testTaskDetailDelayInstalled = true;
  }, { delayMs, taskId });
}

test("approves a seeded real awaiting task into the complete surface", async ({
  page,
}) => {
  test.slow();

  await withSpawnedDesktopServer(async ({ url, workDir, seedWorkspace }) => {
    const description = `Seeded approval follow-up ${Date.now()}`;
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
    await expect(page.getByTestId("complete-pane")).toHaveAttribute(
      "data-follow-up-state",
      "basic",
    );
    await expect(page.getByTestId("follow-up-mode-fixed")).toContainText("Continue here");
    await expect(page.getByTestId("follow-up-send")).toBeVisible();

    const previousPath = new URL(page.url()).pathname;
    await page.getByTestId("follow-up-description").fill(description);
    await page.getByTestId("follow-up-send").click();

    await expect
      .poll(() => new URL(page.url()).pathname, { timeout: 30_000 })
      .not.toBe(previousPath);
    await expect(page.getByTestId("task-detail-screen")).toBeVisible();
    await expect(page.locator(".detail-main-header__prompt-text")).toContainText(description);
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
          if (await page.getByTestId("overview-pane").isVisible().catch(() => false)) {
            return "overview";
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
      .toMatch(/^(approval|overview|complete)$/);
  });
});

test("shows explicit follow-up modes for a seeded worktree task and launches a fork", async ({
  page,
}) => {
  test.slow();

  await withSpawnedDesktopServer(async ({ url, workDir, seedWorkspace }) => {
    const description = `Seeded fork ${Date.now()}`;
    const { taskId } = await seedWorkspace("completed-worktree-follow-up");

    await page.goto(`${url}/`);
    await addWorkspace(page, workDir);

    const taskLink = page
      .getByRole("link", { name: /Seeded completed worktree follow-up/i })
      .first();
    await expect(taskLink).toBeVisible();
    await taskLink.click();

    await expect(page).toHaveURL(new RegExp(`/workspaces/[^/]+/tasks/${taskId}$`));
    await expect(page.getByTestId("complete-pane")).toBeVisible();
    await expect(page.getByTestId("complete-pane")).toHaveAttribute(
      "data-follow-up-state",
      "refine",
    );
    await expect(page.getByTestId("follow-up-send")).toBeVisible();
    await expect(page.getByTestId("follow-up-description")).toHaveJSProperty(
      "tagName",
      "TEXTAREA",
    );
    await page.getByTestId("follow-up-mode-trigger").click();
    await expect(page.getByTestId("follow-up-mode-popup")).toBeVisible();
    await page.getByTestId("follow-up-mode-option-fork_head").click();
    await expect(page.getByTestId("follow-up-mode-popup")).toHaveCount(0);
    await expect(page.getByTestId("follow-up-mode-trigger")).toContainText("Fork from HEAD");
    await expect(page.getByTestId("follow-up-dirty-hint")).toContainText("3 uncommitted");
    await page.getByTestId("follow-up-description").fill(description);
    const previousPath = new URL(page.url()).pathname;
    await page.getByTestId("follow-up-send").click();

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

test("shows pending then refine follow-up state for a repo-backed main-checkout task and launches a fork", async ({
  page,
}) => {
  test.slow();

  await withSpawnedDesktopServer(async ({ url, workDir, seedWorkspace }) => {
    const description = `Seeded repo follow-up ${Date.now()}`;
    const { taskId } = await seedWorkspace("completed-repo-follow-up");

    await page.goto(`${url}/`);
    await addWorkspace(page, workDir);
    await delayNextTaskGetForTask(page, taskId);

    const taskLink = page
      .getByRole("link", { name: /Seeded completed repo follow-up/i })
      .first();
    await expect(taskLink).toBeVisible();
    await taskLink.click();

    await expect
      .poll(
        () =>
          page.evaluate(
            () =>
              document
                .querySelector("[data-testid='complete-pane']")
                ?.getAttribute("data-follow-up-state") ?? null,
          ),
        {
          timeout: 5_000,
          intervals: [20, 20, 20, 20, 40, 60, 100],
        },
      )
      .toBe("pending");
    await expect(page).toHaveURL(new RegExp(`/workspaces/[^/]+/tasks/${taskId}$`));
    await expect(page.getByTestId("complete-pane")).toHaveAttribute(
      "data-follow-up-state",
      "refine",
      { timeout: 30_000 },
    );

    await page.getByTestId("follow-up-mode-trigger").click();
    await expect(page.getByTestId("follow-up-mode-popup")).toBeVisible();
    await page.getByTestId("follow-up-mode-option-fork_head").click();
    await expect(page.getByTestId("follow-up-mode-trigger")).toContainText("Fork from HEAD");
    await page.getByTestId("follow-up-description").fill(description);
    const previousPath = new URL(page.url()).pathname;
    await page.getByTestId("follow-up-send").click();

    await expect
      .poll(() => new URL(page.url()).pathname, { timeout: 30_000 })
      .not.toBe(previousPath);
    await expect(page.getByTestId("task-detail-screen")).toBeVisible();
    await expect(page.locator(".detail-main-header__prompt-text")).toContainText(description);
    await expect(page.getByTestId("detail-task-launch-mode")).toContainText("Worktree");
  });
});

test("retries a seeded failed task by appending a new activity run", async ({ page }) => {
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
    const activityRuns = page.locator(
      ".detail-activity-card__summary[data-testid^='detail-run-']",
    );
    await expect(activityRuns).toHaveCount(1);
    await page.getByTestId("retry-step").click();
    await expect
      .poll(() => activityRuns.count(), { timeout: 30_000 })
      .toBeGreaterThan(1);
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
          if (await page.getByTestId("overview-pane").isVisible().catch(() => false)) {
            return "overview";
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
      .toMatch(/^(overview|failed|complete)$/);
  });
});

test("reconciles a seeded stale run into a failed state on open", async ({ page }) => {
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
    await expect(page.getByTestId("detail-task-status")).toContainText("Failed", {
      timeout: 30_000,
    });
    await expect(page.getByTestId("detail-run-run-implement-stale")).toContainText("failed");
    await expect(page.getByTestId("failed-pane")).toBeVisible();
    await expect(page.getByTestId("complete-pane")).toHaveCount(0);
    await expect(page.getByTestId("follow-up-description")).toHaveCount(0);
    await expect(page.getByTestId("follow-up-config-trigger")).toHaveCount(0);
  });
});
