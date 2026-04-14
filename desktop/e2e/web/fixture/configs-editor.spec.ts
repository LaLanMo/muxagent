import { expect, test, type Page } from "@playwright/test";

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

  await page.getByRole("link", { name: /^Configs$/i }).click();
  await expect(page.getByTestId("configs-screen")).toBeVisible();
  await expect(page.getByRole("button", { name: /^\+ New Config$/i })).toHaveCount(0);
  await expect(page.getByTestId("config-card-default")).toBeVisible();

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

test("deletes a customized config from the config list", async ({ page }) => {
  await connectFixtureWorkspace(page);

  await page.getByRole("link", { name: /^Configs$/i }).click();
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
