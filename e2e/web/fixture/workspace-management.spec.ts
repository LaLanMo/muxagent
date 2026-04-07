import { expect, test, type Page } from "@playwright/test";

async function connectWorkspace(page: Page, path: string) {
  await expect(page.getByTestId("workspace-picker-button")).toBeEnabled();
  page.once("dialog", (dialog) => dialog.accept(path));
  await page.getByTestId("workspace-picker-button").click();
}

async function connectPrimaryWorkspace(page: Page) {
  await page.goto("/");
  await connectWorkspace(page, "/tmp/muxagent-workspace");
  await expect(page.getByTestId("entry-shell")).toBeVisible();
}

test("renames a workspace from settings and reflects it in the shell", async ({ page }) => {
  await connectPrimaryWorkspace(page);
  await connectWorkspace(page, "/tmp/muxagent-alt-workspace");

  await page.getByRole("link", { name: /^Settings$/i }).click();
  await expect(page.getByTestId("settings-screen")).toBeVisible();

  const altRow = page
    .getByTestId("settings-workspace-row")
    .filter({ hasText: "muxagent-alt-workspace" });
  await altRow.getByTestId("workspace-rename-button").click();
  await altRow.getByTestId("workspace-rename-input").fill("Alt Lab");
  await altRow.getByTestId("workspace-rename-save").click();

  await expect(altRow).toContainText("Alt Lab");
  await expect(page.locator(".shell-workspace__row.is-active")).toHaveCount(0);
  await page.locator(".shell-workspace__row").filter({ hasText: "Alt Lab" }).click();
  await expect(page).toHaveURL(/\/$/);
  await expect(
    page.locator(".shell-workspace__row.is-active .shell-workspace__label").first(),
  ).toContainText("Alt Lab");
});

test("removes a workspace and keeps Tasks as the unscoped default", async ({ page }) => {
  await connectPrimaryWorkspace(page);
  await connectWorkspace(page, "/tmp/muxagent-alt-workspace");

  await page.getByRole("link", { name: /^Settings$/i }).click();
  await expect(page.getByTestId("settings-screen")).toBeVisible();

  const altRow = page
    .getByTestId("settings-workspace-row")
    .filter({ hasText: "muxagent-alt-workspace" });
  await altRow.getByTestId("workspace-remove-button").click();

  await expect(page.getByTestId("settings-workspace-row")).toHaveCount(1);
  await expect(page.getByTestId("settings-screen")).not.toContainText("muxagent-alt-workspace");
  await expect(page.locator(".shell-workspace__row.is-active")).toHaveCount(0);
  await page.locator(".shell-workspace__row").filter({ hasText: "muxagent-workspace" }).click();
  await expect(page).toHaveURL(/\/$/);
  await expect(
    page.locator(".shell-workspace__row.is-active .shell-workspace__label").first(),
  ).toContainText("muxagent-workspace");
});
