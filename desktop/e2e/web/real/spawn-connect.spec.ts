import path from "node:path";
import { expect, test, type Locator, type Page } from "@playwright/test";
import {
  addWorkspace,
  withSpawnedDesktopServer,
} from "../support/spawned-backend";

function tasksPanel(page: Page): Locator {
  return page.getByTestId("tasks-panel");
}

function workspaceRow(page: Page, label: string): Locator {
  return tasksPanel(page)
    .locator('[data-testid^="workspace-row-"]')
    .filter({ hasText: label })
    .first();
}

function workspaceRows(page: Page): Locator {
  return tasksPanel(page).locator('[data-testid^="workspace-row-"]');
}

function activeWorkspaceRows(page: Page): Locator {
  return tasksPanel(page).locator('[data-testid^="workspace-row-"].is-active');
}

function allWorkspacesScope(page: Page): Locator {
  return tasksPanel(page).getByTestId("task-scope-all-workspaces");
}

async function removeWorkspaceFromSidebar(page: Page, label: string) {
  const row = workspaceRow(page, label);
  await row.hover();
  await expect(row.getByTestId("workspace-row-remove-button")).toBeVisible();
  await row.getByTestId("workspace-row-remove-button").click();
  await expect(page.getByTestId("confirm-dialog")).toBeVisible();
  await page.getByTestId("confirm-dialog-submit").click();
}

test("connects to a real spawned muxagent app-server", async ({ page }) => {
  test.slow();

  await withSpawnedDesktopServer(async ({ url, workDir }) => {
    await page.goto(`${url}/`);
    await addWorkspace(page, workDir);

    await expect(page).toHaveURL(`${url}/`);
    await expect(page.getByTestId("board-empty-state")).toContainText(
      "No tasks yet",
    );
    await expect(workspaceRow(page, "workspace")).toHaveCount(1);
    await expect(allWorkspacesScope(page)).toHaveClass(/is-active/);
    await expect(activeWorkspaceRows(page)).toHaveCount(0);
  });
});

test("shows unreachable state when adding a missing real workspace", async ({
  page,
}) => {
  test.slow();

  await withSpawnedDesktopServer(async ({ url, workDir }) => {
    const missingWorkDir = path.join(workDir, "missing-workspace");

    await page.goto(`${url}/`);
    await addWorkspace(page, missingWorkDir);

    await expect(page.getByTestId("shell-error")).toContainText(
      "workspace unavailable",
    );
    await expect(page.getByTestId("entry-empty-state")).toBeVisible();
    await expect(workspaceRows(page)).toHaveCount(0);
    await expect(activeWorkspaceRows(page)).toHaveCount(0);
    await expect(page.locator(".tasks-panel__empty")).toContainText("No workspaces yet");
  });
});

test("returns to the connect screen when the backend dies after connect", async ({
  page,
}) => {
  test.slow();

  await withSpawnedDesktopServer(async ({ url, workDir, stop }) => {
    await page.goto(`${url}/`);
    await addWorkspace(page, workDir);

    await expect(page).toHaveURL(`${url}/`);
    await stop();

    await expect(page).toHaveURL(`${url}/`);
    await expect(page.getByTestId("shell-error")).toContainText(
      "Bridge transport closed",
    );
  });
});

test("adds and persists multiple workspaces through the real app-server", async ({ page }) => {
  test.slow();

  await withSpawnedDesktopServer(async ({ url, workDir, altWorkDir }) => {
    await page.goto(`${url}/`);
    await addWorkspace(page, workDir);
    await addWorkspace(page, altWorkDir);

    await expect(page.getByTestId("board-empty-state")).toContainText("No tasks yet");
    await expect(workspaceRow(page, "workspace")).toHaveCount(1);
    await expect(workspaceRow(page, "workspace-alt")).toHaveCount(1);
    await expect(allWorkspacesScope(page)).toHaveClass(/is-active/);
    await expect(activeWorkspaceRows(page)).toHaveCount(0);

    await page.reload();

    await expect(page.getByTestId("entry-shell")).toBeVisible();
    await expect(workspaceRow(page, "workspace")).toHaveCount(1);
    await expect(workspaceRow(page, "workspace-alt")).toHaveCount(1);
    await expect(allWorkspacesScope(page)).toHaveClass(/is-active/);
    await expect(activeWorkspaceRows(page)).toHaveCount(0);
  });
});

test("removes workspaces through the real app-server sidebar", async ({ page }) => {
  test.slow();

  await withSpawnedDesktopServer(async ({ url, workDir, altWorkDir }) => {
    await page.goto(`${url}/`);
    await addWorkspace(page, workDir);
    await addWorkspace(page, altWorkDir);

    await expect(activeWorkspaceRows(page)).toHaveCount(0);
    await workspaceRow(page, "workspace-alt")
      .locator(".tasks-panel__workspace-row")
      .click();
    await expect(page).toHaveURL(`${url}/`);
    await expect(workspaceRow(page, "workspace-alt")).toHaveClass(/is-active/);

    await removeWorkspaceFromSidebar(page, "workspace-alt");

    await expect(page.getByTestId("confirm-dialog")).toHaveCount(0);
    await expect(workspaceRow(page, "workspace-alt")).toHaveCount(0);
    await expect(workspaceRow(page, "workspace")).toHaveCount(1);
    await expect(page).toHaveURL(`${url}/`);
    await expect(workspaceRow(page, "workspace")).toHaveClass(/is-active/);
  });
});

test("renders runtime status in settings through the real app-server", async ({ page }) => {
  test.slow();

  await withSpawnedDesktopServer(async ({ url, workDir }) => {
    await page.goto(`${url}/`);
    await addWorkspace(page, workDir);

    await page.getByRole("button", { name: /^Settings$/i }).click();
    await page.getByRole("link", { name: /^Runtimes$/i }).click();
    await expect(page).toHaveURL(/\/settings\/runtimes$/);
    await expect(page.getByTestId("settings-screen")).toBeVisible();
    await expect(page.getByTestId("settings-runtimes-section")).toContainText("Runtimes");
    await expect(page.locator('[data-testid^="settings-runtime-"]')).toHaveCount(3);

    await page.getByRole("link", { name: /^About$/i }).click();
    await expect(page).toHaveURL(/\/settings\/about$/);
    await expect(page.getByTestId("settings-about-section")).toContainText("About");
    await expect(page.getByTestId("settings-version-row")).toHaveCount(2);
  });
});
