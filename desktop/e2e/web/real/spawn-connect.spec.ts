import path from "node:path";
import { expect, test } from "@playwright/test";
import {
  addWorkspace,
  withSpawnedDesktopServer,
} from "../support/spawned-backend";

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

test("adds and persists multiple workspaces through the real app-server", async ({
  page,
}) => {
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

test("renames and removes workspaces through the real app-server", async ({ page }) => {
  test.slow();

  await withSpawnedDesktopServer(async ({ url, workDir, altWorkDir }) => {
    await page.goto(`${url}/`);
    await addWorkspace(page, workDir);
    await addWorkspace(page, altWorkDir);

    await page.getByRole("link", { name: /^Settings$/i }).click();
    await expect(page.getByTestId("settings-screen")).toBeVisible();

    const altRow = page
      .getByTestId("settings-workspace-row")
      .filter({ hasText: "workspace-alt" });
    await altRow.getByTestId("workspace-rename-button").click();
    await altRow.getByTestId("workspace-rename-input").fill("Alt Lab");
    await altRow.getByTestId("workspace-rename-save").click();

    await expect(altRow).toContainText("Alt Lab");
    await expect(page.locator(".shell-workspace__row.is-active")).toHaveCount(0);
    await page.locator(".shell-workspace__row").filter({ hasText: "Alt Lab" }).click();
    await expect(page).toHaveURL(`${url}/`);
    await expect(
      page.locator(".shell-workspace__row.is-active .shell-workspace__label").first(),
    ).toContainText("Alt Lab");

    await page.getByRole("link", { name: /^Settings$/i }).click();
    await expect(page.getByTestId("settings-screen")).toBeVisible();

    await altRow.getByTestId("workspace-remove-button").click();

    await expect(page.getByTestId("settings-workspace-row")).toHaveCount(1);
    await expect(page.getByTestId("settings-screen")).not.toContainText("Alt Lab");
    await expect(page.locator(".shell-workspace__row.is-active")).toHaveCount(0);
    await page.locator(".shell-workspace__row").filter({ hasText: "workspace" }).click();
    await expect(page).toHaveURL(`${url}/`);
    await expect(
      page.locator(".shell-workspace__row.is-active .shell-workspace__label").first(),
    ).toContainText("workspace");
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
