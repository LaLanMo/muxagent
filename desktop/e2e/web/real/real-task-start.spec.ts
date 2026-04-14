import { access, readdir } from "node:fs/promises";
import path from "node:path";
import { expect, test } from "@playwright/test";
import {
  addWorkspace,
  withSpawnedDesktopServer,
} from "../support/spawned-backend";

async function pathExists(target: string): Promise<boolean> {
  try {
    await access(target);
    return true;
  } catch {
    return false;
  }
}

async function listTaskIds(workDir: string): Promise<string[]> {
  const tasksDir = path.join(workDir, ".muxagent", "tasks");
  try {
    const entries = await readdir(tasksDir, { withFileTypes: true });
    return entries
      .filter((entry) => entry.isDirectory())
      .map((entry) => entry.name)
      .sort();
  } catch {
    return [];
  }
}

test("starts a real task through the browser shell against a spawned app-server", async ({
  page,
}) => {
  test.slow();

  await withSpawnedDesktopServer(async ({ url, workDir }) => {
    const description = `Real browser E2E task ${Date.now()}`;

    await page.goto(`${url}/`);
    await addWorkspace(page, workDir);

    await expect(page.getByTestId("board-empty-state")).toContainText("No tasks yet");

    await page.getByTestId("open-new-task").click();
    await expect(page.getByTestId("new-task-modal")).toBeVisible();
    await page.getByTestId("new-task-description").fill(description);
    await page.getByTestId("new-task-submit").click();

    await expect(page.getByTestId("new-task-modal")).toBeHidden();
    await expect.poll(() => pathExists(path.join(workDir, ".muxagent", "tasks.db"))).toBe(
      true,
    );
    await expect.poll(async () => (await listTaskIds(workDir)).length).toBe(1);

    const taskLink = page.getByRole("link", { name: new RegExp(description) }).first();
    await expect(taskLink).toBeVisible();

    const href = await taskLink.getAttribute("href");
    expect(href).toMatch(/^\/workspaces\/[^/]+\/tasks\/[^/]+$/);
    const taskId = decodeURIComponent(href?.split("/").at(-1) ?? "");
    expect(taskId).not.toBe("");

    await expect
      .poll(() =>
        pathExists(path.join(workDir, ".muxagent", "tasks", taskId, "config.yaml")),
      )
      .toBe(true);

    await taskLink.click();

    await expect(page).toHaveURL(new RegExp(`/workspaces/[^/]+/tasks/${taskId}$`));
    await expect(page.getByTestId("task-detail-screen")).toBeVisible();
    await expect(page.getByRole("heading", { name: description })).toBeVisible();
    await expect(
      page
        .locator(
          '[data-testid="run-pane"], [data-testid="overview-pane"], [data-testid="artifact-pane"]',
        )
        .first(),
    ).toBeVisible();
  });
});
