import path from "node:path";
import { expect, test, type Locator, type Page } from "@playwright/test";
import {
  addWorkspace,
  withSpawnedDesktopServer,
} from "../support/spawned-backend";

function workspaceRow(page: Page, label: string): Locator {
  return page.locator('[data-testid^="workspace-row-"]').filter({ hasText: label }).first();
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
    await expect(page.locator(".shell-workspace__row")).toHaveCount(1);
    await expect(page.locator(".shell-workspace__row.is-active")).toHaveCount(0);
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
    await expect(page.locator(".shell-workspace__row")).toHaveCount(0);
    await expect(page.locator(".shell-workspace__row.is-active")).toHaveCount(0);
    await expect(page.locator(".shell-section__empty")).toContainText("No workspaces yet");
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
    await expect(page.locator(".shell-workspace__row")).toHaveCount(2);
    await expect(page.locator(".shell-workspace__row.is-active")).toHaveCount(0);

    await page.reload();

    await expect(page.getByTestId("entry-shell")).toBeVisible();
    await expect(page.locator(".shell-workspace__row")).toHaveCount(2);
    await expect(page.locator(".shell-workspace__row.is-active")).toHaveCount(0);
  });
});

test("removes workspaces through the real app-server sidebar", async ({ page }) => {
  test.slow();

  await withSpawnedDesktopServer(async ({ url, workDir, altWorkDir }) => {
    await page.goto(`${url}/`);
    await addWorkspace(page, workDir);
    await addWorkspace(page, altWorkDir);

    await expect(page.locator(".shell-workspace__row.is-active")).toHaveCount(0);
    await workspaceRow(page, "workspace-alt").locator(".shell-workspace__row").click();
    await expect(page).toHaveURL(`${url}/`);
    await expect(
      page.locator(".shell-workspace__row.is-active .shell-workspace__label").first(),
    ).toContainText("workspace-alt");

    await removeWorkspaceFromSidebar(page, "workspace-alt");

    await expect(page.getByTestId("confirm-dialog")).toHaveCount(0);
    await expect(workspaceRow(page, "workspace-alt")).toHaveCount(0);
    await expect(workspaceRow(page, "workspace")).toHaveCount(1);
    await expect(page).toHaveURL(`${url}/`);
    await expect(
      page.locator(".shell-workspace__row.is-active .shell-workspace__label").first(),
    ).toContainText("workspace");
  });
});

test("renders runtime status in settings through the real app-server", async ({ page }) => {
  test.slow();

  await withSpawnedDesktopServer(async ({ url, workDir }) => {
    await page.goto(`${url}/`);
    await addWorkspace(page, workDir);

    await page.getByRole("link", { name: /^Settings$/i }).click();
    await expect(page.getByTestId("settings-screen")).toBeVisible();
    await expect(page.getByTestId("settings-runtime-section")).toContainText("Runtimes");
    await expect(page.getByTestId("settings-runtime-row")).toHaveCount(3);
    await expect(page.getByTestId("settings-about-section")).toContainText("About");
    await expect(page.getByTestId("settings-version-row")).toBeVisible();
    await expect(page.getByTestId("settings-workspace-row")).toHaveCount(0);
    await expect(page.getByTestId("workspace-rename-button")).toHaveCount(0);
    await expect(page.getByTestId("workspace-remove-button")).toHaveCount(0);
  });
});

test("reconnects without a full page reload after an explicit disconnect", async ({
  page,
}) => {
  test.slow();

  await withSpawnedDesktopServer(async ({ url, workDir }) => {
    await page.goto(`${url}/`);
    await addWorkspace(page, workDir);

    await page.getByRole("link", { name: /^Settings$/i }).click();
    await expect(page.getByTestId("settings-screen")).toBeVisible();

    await page.getByRole("button", { name: /^Disconnect$/i }).click();

    await expect(page).toHaveURL(`${url}/`);
    await expect(page.getByTestId("entry-empty-state")).toContainText(
      "App-server disconnected",
    );
    await expect(page.getByTestId("reconnect-app-server")).toBeVisible();

    await page.getByTestId("reconnect-app-server").click();

    await expect(page.getByTestId("workspace-picker-button")).toBeEnabled();
    await expect(page.getByTestId("board-empty-state")).toContainText(
      "No tasks yet",
    );
    await expect(page.locator(".shell-workspace__row.is-active")).toHaveCount(0);
  });
});
