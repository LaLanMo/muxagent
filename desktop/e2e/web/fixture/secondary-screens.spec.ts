import { expect, test, type Page } from "@playwright/test";

async function connectFixtureWorkspace(page: Page, workDir = "/tmp/muxagent-workspace") {
  await page.goto("/");
  await expect(page.getByTestId("workspace-picker-button")).toBeEnabled();
  page.once("dialog", (dialog) => dialog.accept(workDir));
  await page.getByTestId("workspace-picker-button").click();
  await expect(page.getByTestId("entry-shell")).toBeVisible();
}

async function delayConfigGet(page: Page, delayMs = 180) {
  await page.evaluate(async ({ delayMs: nextDelayMs }) => {
    const runtimeModule = await import("/src/app/runtime.ts");
    const runtime = runtimeModule.getRuntime();
    const backend = runtime.backend as {
      __testConfigGetDelayInstalled?: boolean;
      configGet: (alias: string) => Promise<unknown>;
    };
    if (backend.__testConfigGetDelayInstalled) {
      return;
    }
    const originalConfigGet = backend.configGet.bind(backend);
    backend.configGet = async (alias: string) => {
      await new Promise((resolve) => window.setTimeout(resolve, nextDelayMs));
      return originalConfigGet(alias);
    };
    backend.__testConfigGetDelayInstalled = true;
  }, { delayMs });
}

type ModalGeometry = {
  modalHeight: number;
  footerTop: number;
  footerBottom: number;
};

async function readModalGeometry(page: Page): Promise<ModalGeometry> {
  const modalBox = await page.locator(".task-modal").boundingBox();
  const footerBox = await page.locator(".task-modal__footer").boundingBox();

  if (!modalBox || !footerBox) {
    throw new Error("New task modal geometry is unavailable");
  }

  return {
    modalHeight: modalBox.height,
    footerTop: footerBox.y,
    footerBottom: footerBox.y + footerBox.height,
  };
}

function expectModalGeometryStable(
  before: ModalGeometry,
  after: ModalGeometry,
  tolerance = 1.5,
) {
  expect(
    Math.abs(after.modalHeight - before.modalHeight),
    "modal height should stay stable while picker is open",
  ).toBeLessThanOrEqual(tolerance);
  expect(
    Math.abs(after.footerTop - before.footerTop),
    "footer top edge should stay stable while picker is open",
  ).toBeLessThanOrEqual(tolerance);
  expect(
    Math.abs(after.footerBottom - before.footerBottom),
    "footer bottom edge should stay stable while picker is open",
  ).toBeLessThanOrEqual(tolerance);
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

test("keeps the new-task modal shell stable while pickers open and dismiss", async ({ page }) => {
  await connectFixtureWorkspace(page);
  await delayConfigGet(page);

  await page.getByTestId("open-new-task").click();
  await expect(page.getByTestId("new-task-modal")).toBeVisible();

  const modal = page.getByTestId("new-task-modal");
  const description = page.getByTestId("new-task-description");
  const workspaceHeader = page.getByTestId("new-task-workspace");
  const workspaceList = page.locator(".task-modal__ws-list");
  const configHeader = page.locator(".task-modal__cfg-header");
  const configList = page.locator(".task-modal__cfg-list");

  const workspaceGeometry = await readModalGeometry(page);
  await workspaceHeader.click();
  await expect(workspaceList).toBeVisible();
  expectModalGeometryStable(workspaceGeometry, await readModalGeometry(page));

  await page.keyboard.press("Escape");
  await expect(workspaceList).toHaveCount(0);
  await expect(modal).toBeVisible();

  await workspaceHeader.click();
  await expect(workspaceList).toBeVisible();
  await description.click();
  await expect(workspaceList).toHaveCount(0);
  await expect(modal).toBeVisible();

  const configGeometry = await readModalGeometry(page);
  await configHeader.click();
  await expect(configList).toBeVisible();
  expectModalGeometryStable(configGeometry, await readModalGeometry(page));
  await page.waitForTimeout(260);
  expectModalGeometryStable(configGeometry, await readModalGeometry(page));

  const configListBox = await configList.boundingBox();
  const selectedConfigBox = await page.locator(".task-modal__cfg-option--selected").boundingBox();
  if (!configListBox || !selectedConfigBox) {
    throw new Error("Config picker geometry is unavailable");
  }

  expect(
    Math.abs(selectedConfigBox.x - configListBox.x),
    "selected config row should align with the picker left edge",
  ).toBeLessThanOrEqual(2);
  expect(
    Math.abs(selectedConfigBox.width - configListBox.width),
    "selected config row should fill the picker width",
  ).toBeLessThanOrEqual(2);

  await page.keyboard.press("Escape");
  await expect(configList).toHaveCount(0);
  await expect(modal).toBeVisible();
  await expect(page.getByText("Agentic workflow with planning, approval, and verification")).toBeVisible();
  await expect(
    page.locator(".task-modal__cfg-field").filter({ hasText: "Entry node" }).getByText("draft_plan"),
  ).toBeVisible();

  await configHeader.click();
  await expect(configList).toBeVisible();
  await description.click();
  await expect(configList).toHaveCount(0);
  await expect(modal).toBeVisible();
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

  await page.getByTestId("new-task-description").fill("Run quick verification");
  await page.getByTestId("new-task-submit").click();
  await expect(page.getByTestId("new-task-modal")).toHaveCount(0);

  await page.getByTestId("open-new-task").click();
  await expect(page.getByTestId("new-task-modal")).toBeVisible();
  await expect(page.getByTestId("new-task-config")).toHaveValue("quick");
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
  await expect(page.getByRole("button", { name: /Make default/i })).toHaveCount(0);
  await expect(page.getByText("Default for new tasks")).toHaveCount(0);

  await page.getByRole("link", { name: /^Settings$/i }).click();
  await expect(page.getByTestId("settings-screen")).toBeVisible();
  await expect(page.getByTestId("settings-app-server-section")).toContainText("App Server");
  await expect(page.getByTestId("settings-runtime-section")).toContainText("Task Runtime");
  await expect(page.getByTestId("settings-runtime-automatic")).toContainText("Codex");
  await expect(page.getByTestId("settings-runtime-row")).toHaveCount(3);
  await expect(page.getByText("Protocol")).toHaveCount(0);
  await expect(page.getByText("Version")).toHaveCount(0);
});
