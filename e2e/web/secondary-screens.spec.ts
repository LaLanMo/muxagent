import { expect, test, type Page } from "@playwright/test";

async function connectFixtureWorkspace(page: Page, workDir = "/tmp/muxagent-workspace") {
  await page.goto("/");
  await expect(page.getByTestId("workspace-picker-button")).toBeEnabled();
  page.once("dialog", (dialog) => dialog.accept(workDir));
  await page.getByTestId("workspace-picker-button").click();
  await expect(page.getByTestId("entry-shell")).toBeVisible();
}

test("opens the new-task modal and starts a task from the shell", async ({ page }) => {
  await connectFixtureWorkspace(page);

  await page.getByTestId("open-new-task").click();
  await expect(page.getByTestId("new-task-modal")).toBeVisible();
  await expect(page.getByTestId("new-task-submit")).toBeDisabled();
  await expect(page.getByTestId("new-task-config")).toHaveValue("default");

  await page.getByTestId("new-task-description").fill("Draft rollback playbook");
  await expect(page.getByTestId("new-task-submit")).toBeEnabled();
  await page.getByTestId("new-task-submit").click();

  await expect(page.getByTestId("new-task-modal")).toBeHidden();
  await expect(page.getByText("Draft rollback playbook")).toBeVisible();
});

test("renders the inbox surface and drills back into task detail", async ({ page }) => {
  await connectFixtureWorkspace(page);

  await page.getByRole("link", { name: /Inbox/i }).click();
  await expect(page.getByTestId("inbox-screen")).toBeVisible();
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
  await expect(page.getByText("State dir")).toBeVisible();
  await expect(page.getByText("Connected clients")).toBeVisible();
});
