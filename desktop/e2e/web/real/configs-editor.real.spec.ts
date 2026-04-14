import path from "node:path";
import { expect, test } from "@playwright/test";
import { withSpawnedDesktopServer } from "../support/spawned-backend";

test("shows a built-in config as a read-only file inspector through the real backend", async ({
  page,
}) => {
  test.slow();

  await withSpawnedDesktopServer(async ({ url, taskConfigRootDir }) => {
    await page.goto(`${url}/`);
    await expect(page.getByTestId("workspace-picker-button")).toBeEnabled({
      timeout: 30_000,
    });

    await page.getByRole("link", { name: /^Configs$/i }).click();
    await expect(page.getByTestId("configs-screen")).toBeVisible();

    await page
      .getByTestId("config-card-default")
      .getByRole("button", { name: /^Edit$/i })
      .click();

    await expect(page).toHaveURL(/\/configs\/default$/, {
      timeout: 30_000,
    });
    await expect(page.getByTestId("config-editor-screen")).toBeVisible({
      timeout: 30_000,
    });
    await expect(page.getByLabel("Config graph")).toBeVisible({
      timeout: 30_000,
    });
    await expect(page.getByTestId("config-editor-graph-header")).toBeVisible();
    await expect(page.getByTestId("config-editor-back")).toHaveText("‹  Configs");
    await expect(page.getByTestId("config-editor-config-header")).toContainText(
      "Config File",
    );
    await expect(page.getByTestId("config-open-in-editor-button")).toBeVisible();
    await expect(page.getByTestId("config-reveal-in-finder-button")).toBeVisible();
    await expect(page.getByTestId("config-editor-toggle")).toHaveCount(0);
    await expect(page.getByRole("button", { name: /^Edit workflow$/i })).toHaveCount(0);
    await expect(page.getByText(/^Name$/)).toBeVisible();
    await expect(page.getByText(/^Description$/)).toBeVisible();
    await expect(page.getByText(/^Location$/)).toBeVisible();
    await expect(page.getByText(/^Stats$/)).toBeVisible();
    await expect(page.getByTestId("config-editor-name")).toHaveText("default");
    await expect(page.getByTestId("config-editor-location")).toHaveText(
      path.join(taskConfigRootDir, "taskconfigs", "default", "config.yaml"),
    );
    await expect(page.getByTestId("config-editor-stats")).toContainText("nodes ·");

    await page.getByTestId("config-editor-back").click();
    await expect(page).toHaveURL(/\/configs$/, {
      timeout: 30_000,
    });
    await expect(page.getByTestId("configs-screen")).toBeVisible({
      timeout: 30_000,
    });
  });
});
