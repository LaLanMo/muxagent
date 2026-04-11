import { expect, test, type Page } from "@playwright/test";

async function connectFixtureWorkspace(page: Page, workDir = "/tmp/muxagent-workspace") {
  await page.goto("/");
  await expect(page.getByTestId("workspace-picker-button")).toBeEnabled();
  page.once("dialog", (dialog) => dialog.accept(workDir));
  await page.getByTestId("workspace-picker-button").click();
  await expect(page.getByTestId("entry-shell")).toBeVisible();
}

test("opens the new-task modal and validates launch affordances from the shell", async ({ page }) => {
  await connectFixtureWorkspace(page);

  await page.getByTestId("open-new-task").click();
  await expect(page.getByTestId("new-task-modal")).toBeVisible();
  await expect(page.getByTestId("new-task-submit")).toBeDisabled();
  await expect(page.getByTestId("new-task-config")).toHaveValue("default");

  await page.getByTestId("new-task-description").fill("Draft rollback playbook");
  await expect(page.getByTestId("new-task-submit")).toBeEnabled();
  await page.getByTestId("new-task-description").clear();
  await expect(page.getByTestId("new-task-submit")).toBeDisabled();
});

test("shows config metadata and updates it when switching configs in the new-task modal", async ({
  page,
}) => {
  await connectFixtureWorkspace(page);

  await page.getByTestId("open-new-task").click();
  await expect(page.getByTestId("new-task-modal")).toBeVisible();
  await expect(page.getByText("Agentic workflow with planning, approval, and verification")).toBeVisible();
  await expect(
    page.locator(".task-modal__cfg-field").filter({ hasText: "Runtime" }).getByText("yolo"),
  ).toBeVisible();
  await expect(
    page
      .locator(".task-modal__cfg-field")
      .filter({ hasText: "Max iterations" })
      .getByText("14"),
  ).toBeVisible();
  await expect(
    page.locator(".task-modal__cfg-field").filter({ hasText: "Entry node" }).getByText("draft_plan"),
  ).toBeVisible();

  await page.locator(".task-modal__cfg-header").click();
  await expect(page.locator(".task-modal__cfg-list")).toBeVisible();
  await page.locator(".task-modal__cfg-option").filter({ hasText: "quick" }).click();

  await expect(page.getByTestId("new-task-config")).toHaveValue("quick");
  await expect(page.locator(".task-modal__cfg-list")).toHaveCount(0);
  await expect(page.getByText("Shorter loop for quick issue triage.")).toBeVisible();
  await expect(
    page.locator(".task-modal__cfg-field").filter({ hasText: "Runtime" }).getByText("claude"),
  ).toBeVisible();
  await expect(
    page
      .locator(".task-modal__cfg-field")
      .filter({ hasText: "Max iterations" })
      .getByText("8"),
  ).toBeVisible();
  await expect(
    page.locator(".task-modal__cfg-field").filter({ hasText: "Entry node" }).getByText("inspect"),
  ).toBeVisible();
});

test("still allows starting a task from the all-workspaces task view", async ({ page }) => {
  await connectFixtureWorkspace(page);

  page.once("dialog", (dialog) => dialog.accept("/tmp/muxagent-alt-workspace"));
  await page.getByTestId("workspace-picker-button").click();
  await page.getByRole("link", { name: /^Tasks$/i }).click();

  await expect(page.locator(".shell-workspace__row.is-active")).toHaveCount(0);
  await page.getByTestId("open-new-task").click();
  await expect(page.getByTestId("new-task-modal")).toBeVisible();
  await expect(page.getByTestId("new-task-workspace")).toBeVisible();
  await page.getByTestId("new-task-description").fill("Draft rollback playbook");
  await expect(page.getByTestId("new-task-submit")).toBeEnabled();
});

test("renders the needs-attention task filter and drills back into task detail", async ({ page }) => {
  await connectFixtureWorkspace(page);

  await page.getByTestId("task-view-needs-attention").click();
  await expect(page.getByTestId("task-board")).toBeVisible();
  await expect(page).toHaveURL(/\/\?view=attention$/);
  await expect(page.getByText("Review PR #42")).toBeVisible();
  await expect(page.getByText("Deploy staging")).toBeVisible();

  await page.getByRole("link", { name: /Review PR #42/i }).click();
  await expect(page.getByTestId("task-detail-screen")).toBeVisible();
  await expect(page.getByTestId("approval-pane")).toBeVisible();
});

test("renders configs and settings from the desktop shell", async ({ page }) => {
  await connectFixtureWorkspace(page);

  await page.getByRole("link", { name: /^Configs$/i }).click();
  await expect(page.getByTestId("configs-screen")).toBeVisible();
  await expect(page.getByText("Agentic workflow with planning, approval, and verification")).toBeVisible();
  await expect(page.getByText("draft_plan")).toBeVisible();

  await page.getByRole("link", { name: /^Settings$/i }).click();
  await expect(page.getByTestId("settings-screen")).toBeVisible();
  await expect(page.getByText("muxagent app-server")).toBeVisible();
  await expect(page.getByText("Available")).toBeVisible();
  await expect(page.getByText("Protocol")).toHaveCount(0);
  await expect(page.getByText("Version")).toHaveCount(0);
});
