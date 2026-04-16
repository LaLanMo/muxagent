import { expect, test } from "@playwright/test";

test("keeps the entry shell unchanged when add workspace is cancelled", async ({
  page,
}) => {
  await page.goto("/");
  await expect(page.getByTestId("entry-empty-state")).toBeVisible();
  await expect(page.getByTestId("open-new-workspace")).toBeEnabled();
  await expect(page.getByTestId("open-new-task")).toHaveCount(0);
  await expect(page.getByTestId("workspace-picker-button")).toBeEnabled();
  await expect(page.getByTestId("workspace-picker-button")).toHaveAccessibleName(
    "Add workspace",
  );

  page.once("dialog", (dialog) => dialog.dismiss());
  await page.getByTestId("open-new-workspace").click();

  await expect(page.getByTestId("entry-empty-state")).toBeVisible();
  await expect(page.getByTestId("shell-error")).toHaveCount(0);
  await expect(page.locator(".shell-workspace__row")).toHaveCount(0);
  await expect(page.locator(".shell-section__empty")).toContainText("No workspaces yet");
});

test("shows an error when add workspace receives a relative path", async ({
  page,
}) => {
  await page.goto("/");
  await expect(page.getByTestId("entry-empty-state")).toBeVisible();
  await expect(page.getByTestId("open-new-workspace")).toBeEnabled();
  await expect(page.getByTestId("open-new-task")).toHaveCount(0);
  await expect(page.getByTestId("workspace-picker-button")).toBeEnabled();

  page.once("dialog", (dialog) => dialog.accept("relative/workspace"));
  await page.getByTestId("open-new-workspace").click();

  await expect(page.getByTestId("entry-empty-state")).toBeVisible();
  await expect(page.getByTestId("shell-error")).toContainText(
    "path must be an absolute path",
  );
  await expect(page.locator(".shell-workspace__row")).toHaveCount(0);
  await expect(page.locator(".shell-section__empty")).toContainText("No workspaces yet");
});
