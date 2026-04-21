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

function allWorkspacesScope(page: Page): Locator {
  return page.getByTestId("task-scope-all-workspaces");
}

async function expectSettingsAtActivityBarBottom(page: Page) {
  const activityBar = page.locator(".workbench__activity-bar");
  const configsButton = page.getByTestId("workbench-activity-configs");
  const settingsButton = page.getByTestId("workbench-activity-settings");

  await expect(activityBar).toBeVisible();
  await expect(configsButton).toBeVisible();
  await expect(settingsButton).toBeVisible();

  const [activityBarBox, configsBox, settingsBox] = await Promise.all([
    activityBar.boundingBox(),
    configsButton.boundingBox(),
    settingsButton.boundingBox(),
  ]);

  if (!activityBarBox || !configsBox || !settingsBox) {
    throw new Error("Unable to measure activity bar placement");
  }

  expect(settingsBox.y).toBeGreaterThan(configsBox.y + configsBox.height);

  const settingsBottomGap =
    activityBarBox.y + activityBarBox.height - (settingsBox.y + settingsBox.height);
  expect(settingsBottomGap).toBeGreaterThanOrEqual(0);
  expect(settingsBottomGap).toBeLessThanOrEqual(14);
}

async function removeWorkspaceFromSidebar(page: Page, label: string) {
  const row = workspaceRow(page, label);
  await row.hover();
  await expect(row.getByTestId("workspace-row-remove-button")).toBeVisible();
  await row.getByTestId("workspace-row-remove-button").click();
  await expect(page.getByTestId("confirm-dialog")).toBeVisible();
  await page.getByTestId("confirm-dialog-submit").click();
}

test("keeps settings split into runtimes and about while removing legacy workspace controls", async ({
  page,
}) => {
  await connectPrimaryWorkspace(page);
  await connectWorkspace(page, "/tmp/muxagent-alt-workspace");
  await expect(page.locator(".workbench__traffic-lights")).toHaveCount(0);
  await expectSettingsAtActivityBarBottom(page);

  await page.getByTestId("workbench-activity-settings").click();
  await expect(page.getByTestId("settings-panel-nav")).toBeVisible();
  await expect(page.getByTestId("settings-panel-runtimes")).toBeVisible();
  await expect(page.getByTestId("settings-panel-about")).toBeVisible();

  await page.getByTestId("settings-panel-runtimes").click();
  await expect(page).toHaveURL(/\/settings\/runtimes$/);
  await expect(page.getByTestId("settings-screen")).toBeVisible();
  await expect(page.getByTestId("settings-panel-runtimes")).toHaveClass(/is-active/);
  await expect(page.getByTestId("settings-runtimes-section")).toContainText("Runtimes");
  await expect(page.getByTestId("settings-runtime-codex")).toContainText("Codex");
  await expect(page.getByTestId("settings-runtime-claude-code")).toContainText("Claude Code");
  await expect(page.getByTestId("settings-runtime-opencode")).toContainText("OpenCode");

  await page.getByTestId("settings-panel-about").click();
  await expect(page.getByTestId("settings-screen")).toBeVisible();
  await expect(page).toHaveURL(/\/settings\/about$/);
  await expect(page.getByTestId("workbench-activity-settings")).toHaveClass(/is-active/);
  await expect(page.getByTestId("workbench-activity-tasks")).toHaveAttribute("aria-pressed", "false");
  await expect(page.getByTestId("workbench-activity-source-control")).toHaveAttribute(
    "aria-pressed",
    "false",
  );
  await expect(page.getByTestId("workbench-activity-configs")).toHaveAttribute(
    "aria-pressed",
    "false",
  );

  await expect(page.getByTestId("settings-workspace-row")).toHaveCount(0);
  await expect(page.getByTestId("workspace-rename-button")).toHaveCount(0);
  await expect(page.getByTestId("workspace-remove-button")).toHaveCount(0);
  await expect(page.getByText("Protocol")).toHaveCount(0);
  await expect(page.getByTestId("settings-about-section")).toContainText("About");
  await expect(
    page.getByTestId("settings-version-row").filter({ hasText: "fixture" }),
  ).toBeVisible();
  await expect(page.getByRole("button", { name: "Check now" })).toHaveCount(0);
});

test("activates the selected workspace row in the tasks panel", async ({ page }) => {
  await connectPrimaryWorkspace(page);
  await connectWorkspace(page, "/tmp/muxagent-alt-workspace");

  await expect(page.locator(".tasks-panel__filter.is-active")).toContainText("All");
  await expect(allWorkspacesScope(page)).toHaveClass(/is-active/);

  await workspaceRow(page, "muxagent-alt-workspace").locator(".tasks-panel__workspace-row").click();
  await expect(page).toHaveURL(/\/$/);
  await expect(
    page.locator(".tasks-panel__workspace-row.is-active .tasks-panel__workspace-label").first(),
  ).toContainText("muxagent-alt-workspace");

  await allWorkspacesScope(page).click();
  await expect(allWorkspacesScope(page)).toHaveClass(/is-active/);
  await expect(
    page.locator('[data-testid^="workspace-row-"] .tasks-panel__workspace-row.is-active'),
  ).toHaveCount(0);
  await expect(page.getByTestId("task-board")).toContainText("muxagent-workspace");
  await expect(page.getByTestId("task-board")).toContainText("muxagent-alt-workspace");
});

test("keeps a stable zero-tab workspace when the last tab closes", async ({
  page,
}) => {
  await connectPrimaryWorkspace(page);

  await expect(page.getByTestId("workbench-tab-task-board")).toBeVisible();
  await page.getByTestId("workbench-tab-close-task-board").focus();
  await page.keyboard.press("Enter");

  await expect(page).toHaveURL(/\/workspace$/);
  await expect(page.getByTestId("workbench-empty-state")).toBeVisible();
  await expect(page.getByTestId("workbench-empty-brand")).toBeFocused();
  await expect(page.getByTestId("workbench-tab-task-board")).toHaveCount(0);
  await expect(page.getByRole("button", { name: "Expand bottom panel" })).toHaveCount(0);
  await expect(page.getByRole("button", { name: "Expand right panel" })).toBeDisabled();

  await page.getByTestId("workbench-activity-settings").click();
  await page.getByTestId("settings-panel-about").click();
  await expect(page).toHaveURL(/\/settings\/about$/);
  await expect(page.getByTestId("workbench-tab-settings")).toBeVisible();

  await page.getByTestId("workbench-tab-close-settings").click();
  await expect(page).toHaveURL(/\/workspace$/);
  await expect(page.getByTestId("workbench-empty-state")).toBeVisible();
  await expect(page.getByTestId("workbench-empty-brand")).toBeFocused();
  await expect(page.getByTestId("workbench-tab-settings")).toHaveCount(0);

  await page.getByTestId("workbench-activity-tasks").click();
  await page.getByTestId("task-view-all").click();
  await expect(page).toHaveURL(/\/$/);
  await expect(page.getByTestId("workbench-empty-state")).toHaveCount(0);
  await expect(page.getByTestId("workbench-tab-task-board")).toBeVisible();
  await expect(page.getByTestId("workbench-tab-settings")).toHaveCount(0);
  await expect(page.getByRole("tab")).toHaveCount(1);
  await expect(page.getByTestId("entry-shell")).toBeVisible();
});

test("reveals a row-scoped sidebar delete action and removes the selected workspace", async ({
  page,
}) => {
  await connectPrimaryWorkspace(page);
  await connectWorkspace(page, "/tmp/muxagent-alt-workspace");

  await workspaceRow(page, "muxagent-alt-workspace").locator(".tasks-panel__workspace-row").click();
  await expect(
    page.locator(".tasks-panel__workspace-row.is-active .tasks-panel__workspace-label").first(),
  ).toContainText("muxagent-alt-workspace");

  await removeWorkspaceFromSidebar(page, "muxagent-alt-workspace");

  await expect(page.getByTestId("confirm-dialog")).toHaveCount(0);
  await expect(workspaceRow(page, "muxagent-alt-workspace")).toHaveCount(0);
  await expect(workspaceRow(page, "muxagent-workspace")).toHaveCount(1);
  await expect(
    page.locator(".tasks-panel__workspace-row.is-active .tasks-panel__workspace-label").first(),
  ).toContainText("muxagent-workspace");
});
