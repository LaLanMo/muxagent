import { expect, test, type Locator, type Page } from "@playwright/test";
import { skipOnboarding } from "./_helpers";

test.beforeEach(async ({ page }) => {
  await skipOnboarding(page);
});

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

test("keeps settings sparse and removes legacy workspace management controls", async ({ page }) => {
  await connectPrimaryWorkspace(page);
  await connectWorkspace(page, "/tmp/muxagent-alt-workspace");

  await page.getByRole("link", { name: /^Settings$/i }).click();
  await expect(page.getByTestId("settings-screen")).toBeVisible();

  await expect(page.getByTestId("settings-workspace-row")).toHaveCount(0);
  await expect(page.getByTestId("workspace-rename-button")).toHaveCount(0);
  await expect(page.getByTestId("workspace-remove-button")).toHaveCount(0);
  await expect(page.getByText("Protocol")).toHaveCount(0);
  await expect(page.getByTestId("settings-runtime-section")).toContainText("Runtimes");
  await expect(page.getByTestId("settings-runtime-row")).toHaveCount(3);
  await expect(page.getByTestId("settings-about-section")).toContainText("About");
  await expect(page.getByTestId("settings-version-row")).toContainText("fixture");
  await expect(page.getByRole("button", { name: "Check now" })).toHaveCount(0);
  await expect(page.getByTestId("settings-runtime-row").filter({ hasText: "Codex" })).toContainText(
    "Detected",
  );
  await expect(page.getByTestId("settings-runtime-row").filter({ hasText: "Claude Code" })).toContainText("Available");
  await expect(page.getByTestId("settings-runtime-row").filter({ hasText: "OpenCode" })).toContainText("Not found");
});

test("uses a single active destination state between Tasks and workspace rows", async ({ page }) => {
  await connectPrimaryWorkspace(page);
  await connectWorkspace(page, "/tmp/muxagent-alt-workspace");

  await expect(page.locator(".shell-nav__row.is-active")).toContainText("Tasks");
  await expect(page.locator(".shell-workspace__row.is-active")).toHaveCount(0);

  await workspaceRow(page, "muxagent-alt-workspace").locator(".shell-workspace__row").click();
  await expect(page).toHaveURL(/\/$/);
  await expect(
    page.locator(".shell-workspace__row.is-active .shell-workspace__label").first(),
  ).toContainText("muxagent-alt-workspace");
  await expect(page.locator(".shell-nav__row.is-active")).toHaveCount(0);

  await page.getByRole("link", { name: /^Tasks$/i }).click();
  await expect(page.locator(".shell-workspace__row.is-active")).toHaveCount(0);
  await expect(page.locator(".shell-nav__row.is-active")).toContainText("Tasks");
});

test("reveals a row-scoped sidebar delete action and removes the selected workspace", async ({
  page,
}) => {
  await connectPrimaryWorkspace(page);
  await connectWorkspace(page, "/tmp/muxagent-alt-workspace");

  await workspaceRow(page, "muxagent-alt-workspace").locator(".shell-workspace__row").click();
  await expect(
    page.locator(".shell-workspace__row.is-active .shell-workspace__label").first(),
  ).toContainText("muxagent-alt-workspace");

  await removeWorkspaceFromSidebar(page, "muxagent-alt-workspace");

  await expect(page.getByTestId("confirm-dialog")).toHaveCount(0);
  await expect(workspaceRow(page, "muxagent-alt-workspace")).toHaveCount(0);
  await expect(workspaceRow(page, "muxagent-workspace")).toHaveCount(1);
  await expect(
    page.locator(".shell-workspace__row.is-active .shell-workspace__label").first(),
  ).toContainText("muxagent-workspace");
});
