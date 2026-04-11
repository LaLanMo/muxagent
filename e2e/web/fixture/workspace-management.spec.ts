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

test("keeps settings sparse and removes legacy workspace management controls", async ({ page }) => {
  await connectPrimaryWorkspace(page);
  await connectWorkspace(page, "/tmp/muxagent-alt-workspace");

  await page.getByRole("link", { name: /^Settings$/i }).click();
  await expect(page.getByTestId("settings-screen")).toBeVisible();

  await expect(page.getByTestId("settings-workspace-row")).toHaveCount(0);
  await expect(page.getByTestId("workspace-rename-button")).toHaveCount(0);
  await expect(page.getByTestId("workspace-remove-button")).toHaveCount(0);
  await expect(page.getByText("Protocol")).toHaveCount(0);
  await expect(page.getByText("Version")).toHaveCount(0);
  await expect(page.getByRole("button", { name: "Check now" })).toHaveCount(0);
  await expect(page.getByText("muxagent app-server")).toBeVisible();
  await expect(page.getByText("Available")).toBeVisible();
});

test("uses a single active destination state between Tasks and workspace rows", async ({ page }) => {
  await connectPrimaryWorkspace(page);
  await connectWorkspace(page, "/tmp/muxagent-alt-workspace");

  await expect(page.locator(".shell-nav__row.is-active")).toContainText("Tasks");
  await expect(page.locator(".shell-workspace__row.is-active")).toHaveCount(0);

  await page.locator(".shell-workspace__row").filter({ hasText: "muxagent-alt-workspace" }).click();
  await expect(page).toHaveURL(/\/$/);
  await expect(
    page.locator(".shell-workspace__row.is-active .shell-workspace__label").first(),
  ).toContainText("muxagent-alt-workspace");
  await expect(page.locator(".shell-nav__row.is-active")).toHaveCount(0);

  await page.getByRole("link", { name: /^Tasks$/i }).click();
  await expect(page.locator(".shell-workspace__row.is-active")).toHaveCount(0);
  await expect(page.locator(".shell-nav__row.is-active")).toContainText("Tasks");
});
