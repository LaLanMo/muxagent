import { expect, test, type Page } from "@playwright/test";
import { skipOnboarding } from "./_helpers";

test.beforeEach(async ({ page }) => {
  await skipOnboarding(page);
});

async function connectFixtureWorkspace(
  page: Page,
  workDir = "/tmp/muxagent-workspace",
) {
  await page.goto("/");
  await expect(page.getByTestId("workspace-picker-button")).toBeEnabled();
  page.once("dialog", (dialog) => dialog.accept(workDir));
  await page.getByTestId("workspace-picker-button").click();
  await expect(page.getByTestId("entry-shell")).toBeVisible();
}

test("shows a built-in config as a read-only file inspector", async ({
  page,
}) => {
  await connectFixtureWorkspace(page);

  await page.getByTestId("workbench-activity-configs").click();
  await expect(page.getByTestId("configs-panel")).toBeVisible();
  await expect(page.getByTestId("configs-panel-new")).toHaveCount(0);
  await expect(
    page
      .getByTestId("configs-panel-row-default")
      .locator(".configs-panel__row-subtitle"),
  ).toHaveCount(0);
  const sidebarConfigIcon = page
    .getByTestId("configs-panel-row-default")
    .locator(".configs-panel__row-icon svg");
  const sidebarConfigTitle = page
    .getByTestId("configs-panel-row-default")
    .locator(".configs-panel__row-title");
  const [sidebarConfigIconBox, sidebarConfigTitleBox] = await Promise.all([
    sidebarConfigIcon.boundingBox(),
    sidebarConfigTitle.boundingBox(),
  ]);
  expect(sidebarConfigIconBox).not.toBeNull();
  expect(sidebarConfigTitleBox).not.toBeNull();
  const sidebarConfigIconCenterY =
    sidebarConfigIconBox!.y + sidebarConfigIconBox!.height / 2;
  const sidebarConfigTitleCenterY =
    sidebarConfigTitleBox!.y + sidebarConfigTitleBox!.height / 2;
  expect(Math.abs(sidebarConfigIconCenterY - sidebarConfigTitleCenterY)).toBeLessThanOrEqual(
    2,
  );
  await page.getByTestId("configs-panel-view-all").click();
  await expect(page.getByTestId("configs-screen")).toBeVisible();
  await expect(page.getByRole("button", { name: /^\+ New Config$/i })).toHaveCount(0);
  await expect(page.getByTestId("config-card-default")).toBeVisible();
  await expect(
    page.getByTestId("config-card-default").locator(".config-list-card__meta-line"),
  ).toHaveText("6 nodes  ·  default");

  await page
    .getByTestId("config-card-default")
    .getByRole("button", { name: /^Edit$/i })
    .click();

  await expect(page.getByTestId("config-editor-screen")).toBeVisible();
  await expect(page.getByLabel("Config graph")).toBeVisible();
  await expect(page.getByTestId("config-editor-graph-header")).toBeVisible();
  await expect(page.getByTestId("config-editor-back")).toHaveText("‹  Configs");
  await expect(page.getByTestId("config-editor-config-header")).toContainText(
    "Config File",
  );
  await expect(page.getByText(/^Name$/)).toBeVisible();
  await expect(page.getByText(/^Description$/)).toBeVisible();
  await expect(page.getByText(/^Location$/)).toBeVisible();
  await expect(page.getByText(/^Stats$/)).toBeVisible();
  await expect(page.getByTestId("config-open-in-editor-button")).toBeVisible();
  await expect(page.getByTestId("config-reveal-in-finder-button")).toBeVisible();
  await expect(page.getByTestId("config-editor-toggle")).toHaveCount(0);
  await expect(page.getByRole("button", { name: /^Edit workflow$/i })).toHaveCount(0);
  await expect(page.getByRole("button", { name: /^Save$/i })).toHaveCount(0);
  await expect(page.getByRole("button", { name: /^Reset to builtin$/i })).toHaveCount(0);
  await expect(page.getByTestId("config-editor-name")).toHaveText("default");
  await expect(page.getByTestId("config-editor-location")).toContainText("default.yaml");
  await expect(page.getByTestId("config-editor-stats")).toContainText("nodes ·");

  const entryChip = page.getByTestId("config-graph-node-entry-draft_plan");
  const entryName = page.getByTestId("config-graph-node-name-draft_plan");
  const reviewNode = page.getByTestId("config-graph-node-review_plan");
  const doneNode = page.getByTestId("config-graph-node-done");
  const [entryChipBox, entryNameBox, reviewNodeBox, doneNodeBox] = await Promise.all([
    entryChip.boundingBox(),
    entryName.boundingBox(),
    reviewNode.boundingBox(),
    doneNode.boundingBox(),
  ]);

  expect(entryChipBox).not.toBeNull();
  expect(entryNameBox).not.toBeNull();
  expect(reviewNodeBox).not.toBeNull();
  expect(doneNodeBox).not.toBeNull();
  expect(entryChipBox!.y + entryChipBox!.height).toBeLessThanOrEqual(entryNameBox!.y - 2);
  expect(reviewNodeBox!.width).toBeGreaterThan(doneNodeBox!.width);

  await page.getByTestId("config-editor-back").click();
  await expect(page).toHaveURL(/\/configs$/);
  await expect(page.getByTestId("configs-screen")).toBeVisible();
});

test("keeps shell peer-region visibility stable while switching workspace tabs", async ({
  page,
}) => {
  await connectFixtureWorkspace(page);

  await expect(page.getByTestId("workbench-right-panel")).toHaveCount(0);
  await expect(page.getByRole("button", { name: "Expand right panel" })).toBeDisabled();
  await expect(page.getByRole("button", { name: "Expand bottom panel" })).toHaveCount(0);
  await expect(page.getByTestId("workbench-bottom-panel")).toHaveCount(0);

  await page.getByTestId("workbench-activity-configs").click();
  await expect(page.getByTestId("configs-panel")).toBeVisible();
  await page.getByTestId("configs-panel-view-all").click();
  await expect(page.getByTestId("configs-screen")).toBeVisible();
  await page
    .getByTestId("config-card-default")
    .getByRole("button", { name: /^Edit$/i })
    .click();

  await expect(page.getByTestId("config-editor-screen")).toBeVisible();
  await expect(page.getByTestId("workbench-right-panel")).toBeVisible();
  await expect(page.getByTestId("config-editor-config-header")).toContainText(
    "Config File",
  );
  await expect(page.getByRole("button", { name: "Collapse right panel" })).toBeEnabled();
  await expect(page.getByTestId("workbench-bottom-panel")).toHaveCount(0);

  await page.getByRole("button", { name: "Collapse right panel" }).click();
  await expect(page.getByTestId("workbench-right-panel")).toHaveCount(0);
  await expect(page.getByRole("button", { name: "Expand right panel" })).toBeEnabled();
  await expect(page.getByTestId("workbench-bottom-panel")).toHaveCount(0);

  await page
    .getByTestId("workbench-center-tabs")
    .getByRole("tab", { name: "Board" })
    .click();
  await expect(page).toHaveURL(/\/$/);
  await expect(page.getByTestId("entry-shell")).toBeVisible();
  await expect(page.getByTestId("workbench-right-panel")).toHaveCount(0);
  await expect(page.getByRole("button", { name: "Expand right panel" })).toBeDisabled();
  await expect(page.getByTestId("workbench-bottom-panel")).toHaveCount(0);

  await page
    .getByTestId("workbench-center-tabs")
    .getByRole("tab", { name: "default" })
    .click();
  await expect(page.getByTestId("config-editor-screen")).toBeVisible();
  await expect(page.getByTestId("workbench-right-panel")).toHaveCount(0);
  await expect(page.getByRole("button", { name: "Expand right panel" })).toBeEnabled();
  await expect(page.getByTestId("workbench-bottom-panel")).toHaveCount(0);

  await page.getByTestId("workbench-tab-close-config-detail:default").click();
  await expect(page.getByTestId("workbench-tab-config-detail:default")).toHaveCount(0);
  await expect(page).toHaveURL(/\/configs$/);
  await expect(page.getByTestId("configs-screen")).toBeVisible();
  await expect(page.getByRole("button", { name: "Expand right panel" })).toBeDisabled();
  await expect(page.getByTestId("workbench-bottom-panel")).toHaveCount(0);

  await page
    .getByTestId("config-card-default")
    .getByRole("button", { name: /^Edit$/i })
    .click();
  await expect(page.getByTestId("config-editor-screen")).toBeVisible();
  await expect(page.getByTestId("workbench-right-panel")).toBeVisible();
  await expect(page.getByTestId("config-editor-config-header")).toContainText(
    "Config File",
  );
  await expect(page.getByRole("button", { name: "Collapse right panel" })).toBeEnabled();
});

test("deletes a customized config from the config list", async ({ page }) => {
  await connectFixtureWorkspace(page);

  await page.goto("/configs");
  await expect(page.getByTestId("configs-screen")).toBeVisible();
  await expect(page.getByRole("button", { name: /^\+ New Config$/i })).toHaveCount(0);
  await expect(page.getByTestId("config-card-quick")).toBeVisible();

  await page
    .getByTestId("config-card-quick")
    .getByRole("button", { name: /^Delete$/i })
    .click();
  await expect(page.getByTestId("confirm-dialog")).toBeVisible();
  await page.getByTestId("confirm-dialog-submit").click();

  await expect(page.getByTestId("configs-screen")).toBeVisible();
  await expect(page.getByTestId("config-card-quick")).toHaveCount(0);
});
