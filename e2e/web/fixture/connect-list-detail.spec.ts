import { expect, test, type Page } from "@playwright/test";

async function connectFixtureWorkspace(
  page: Page,
  workDir = "/tmp/muxagent-workspace",
  path = "/",
) {
  await page.goto(path);

  await expect(page.getByTestId("workspace-picker-button")).toBeEnabled();
  page.once("dialog", (dialog) => dialog.accept(workDir));
  await page.getByTestId("workspace-picker-button").click();

  await expect(page.getByTestId("entry-shell")).toBeVisible();
  await expect(page.getByTestId("task-board")).toBeVisible();
}

async function openTaskFromBoard(page: Page, taskId: string) {
  await page.getByTestId(`board-card-${taskId}`).click();
}

async function triggerWorkspaceTaskReload(page: Page, workspaceId: string) {
  await page.evaluate(async ({ workspaceId }) => {
    const [{ getRuntime }, { useTaskSnapshotStore }] = await Promise.all([
      import("/src/app/runtime.ts"),
      import("/src/state/task-snapshot-store.ts"),
    ]);
    const runtime = getRuntime();
    await runtime.backend.taskStart({
      workspace_id: workspaceId,
      description: "Trigger workspace refresh",
      config_alias: "default",
      config_path: "/tmp/muxagent-sync-workspace/.muxagent/configs/default.yaml",
    });
    const result = await runtime.backend.taskList(workspaceId);
    useTaskSnapshotStore.getState().setTasks(workspaceId, result.tasks);
  }, { workspaceId });
}

test("opens a workspace from the shell and drills into task detail", async ({ page }) => {
  await connectFixtureWorkspace(page);

  await expect(page.getByTestId("board-card-task-live-fixture")).toContainText(
    "Refactor auth middleware",
  );
  await expect(page.getByTestId("board-card-task-live-fixture")).toContainText(
    "muxagent-workspace",
  );

  await openTaskFromBoard(page, "task-live-fixture");

  await expect(page).toHaveURL(/\/workspaces\/[^/]+\/tasks\/task-live-fixture$/);
  await expect(page.getByTestId("task-detail-screen")).toBeVisible();
  await expect(page.getByText("Refactor auth middleware")).toBeVisible();
  await expect(page.getByTestId("detail-run-run-live-plan")).toBeVisible();
  const activityScroll = await page.getByTestId("detail-activity").evaluate((element) => ({
    scrollTop: element.scrollTop,
    scrollHeight: element.scrollHeight,
    clientHeight: element.clientHeight,
  }));
  const implementBox = await page.getByTestId("detail-run-run-live-implement").boundingBox();
  const planBox = await page.getByTestId("detail-run-run-live-plan").boundingBox();
  expect(activityScroll.scrollTop + activityScroll.clientHeight).toBeGreaterThanOrEqual(
    activityScroll.scrollHeight - 1,
  );
  expect(implementBox).not.toBeNull();
  expect(planBox).not.toBeNull();
  expect(planBox!.y).toBeLessThan(implementBox!.y);
  await expect(page.getByTestId("transcript-modal")).toHaveCount(0);
  await expect(page.getByTestId("artifact-modal")).toHaveCount(0);
});

test("merges replay history with live output for the selected running run", async ({
  page,
}) => {
  await connectFixtureWorkspace(page);
  await openTaskFromBoard(page, "task-live-fixture");

  await page.getByTestId("detail-run-run-live-implement").click();
  await expect(page).toHaveURL(/[\?&]run=run-live-implement/);
  await expect(page).toHaveURL(/[\?&]modal=transcript/);

  const transcriptModal = page.getByTestId("live-modal");
  await expect(transcriptModal).toBeVisible();
  const outputSurface = page.getByTestId("detail-output-surface");
  const replayUserMessage = outputSurface
    .locator(".transcript-message--user")
    .filter({ hasText: "please inspect" });
  const clarificationUserMessage = outputSurface
    .locator(".transcript-message--user")
    .filter({ hasText: "Expired session redirect" });
  const toolGroup = page.getByTestId("transcript-tool-group-tool-search-live");
  const assistantPlan = outputSurface.getByText("drafted middleware patch plan");

  await expect(outputSurface).toBeVisible();
  await expect(outputSurface.locator(".transcript-message--user")).toHaveCount(2);
  await expect(replayUserMessage).toHaveCount(1);
  await expect(clarificationUserMessage).toHaveCount(1);
  await expect(outputSurface.locator(".transcript-message__markdown code")).toContainText(
    "auth middleware",
  );
  await expect(outputSurface).toContainText("2 tool calls");
  const toolGroupBox = await toolGroup.boundingBox();
  const clarificationBox = await clarificationUserMessage.boundingBox();
  const assistantPlanBox = await assistantPlan.boundingBox();
  expect(toolGroupBox).not.toBeNull();
  expect(clarificationBox).not.toBeNull();
  expect(assistantPlanBox).not.toBeNull();
  expect(toolGroupBox!.y).toBeLessThan(clarificationBox!.y);
  expect(clarificationBox!.y).toBeLessThan(assistantPlanBox!.y);
  await expect(outputSurface).toContainText("drafted middleware patch plan");
  await expect(outputSurface.locator(".transcript-message__markdown strong")).toContainText(
    "middleware",
  );
  await expect(outputSurface.locator(".transcript-message__list-item").nth(0)).toContainText(
    "trace anonymous requests",
  );
  await expect(outputSurface.locator(".transcript-message__list-item").nth(1)).toContainText(
    "preserve redirect flow",
  );
  await expect(outputSurface).toContainText("applying middleware changes");
  await expect(page.getByTestId("transcript-tool-tool-search-live")).toHaveCount(0);

  await page.getByTestId("transcript-tool-group-tool-search-live").click();
  await expect(page.getByTestId("transcript-tool-tool-search-live")).toContainText(
    "Search · auth middleware entry points",
  );
  await expect(page.getByTestId("transcript-tool-tool-read-live")).toContainText(
    "Read · src/auth/middleware.ts",
  );

  await page.getByTestId("transcript-tool-tool-search-live").click();
  await expect(page.getByTestId("transcript-tool-detail-tool-search-live")).toContainText(
    '"query": "auth middleware entry points"',
  );
  await expect(page.getByTestId("transcript-tool-detail-tool-search-live")).toContainText(
    '"matches"',
  );

  await page.getByTestId("transcript-tool-group-tool-edit-live").click();
  await page.getByTestId("transcript-tool-tool-edit-live").click();
  await expect(page.getByTestId("transcript-tool-detail-tool-edit-live")).toContainText(
    "guard anonymous requests",
  );
  await expect(page.getByTestId("transcript-tool-detail-tool-edit-live")).toContainText(
    "redirect('/login')",
  );
  await expect(page.getByTestId("detail-run-history-source")).toContainText("persisted replay");
  await expect(page.getByTestId("detail-run-history-completeness")).toContainText("open");
  await expect(page.getByTestId("detail-run-session")).toContainText("session-live-implement");
});

test("shows submitted clarification input even when no raw transcript was persisted", async ({
  page,
}) => {
  await connectFixtureWorkspace(page);
  await openTaskFromBoard(page, "task-clarification-fixture");

  await page.getByTestId("detail-run-run-clarification-implement").click();
  await expect(page).toHaveURL(/[\?&]run=run-clarification-implement/);
  await expect(page).toHaveURL(/[\?&]modal=transcript/);

  const transcriptModal = page.getByTestId("transcript-modal");
  const outputSurface = page.getByTestId("detail-output-surface");
  const submittedInput = page.getByTestId("transcript-submitted-input");

  await expect(transcriptModal).toBeVisible();
  await expect(outputSurface).toContainText("No persisted stream for this run");
  await expect(outputSurface).not.toContainText("Expired session redirect");
  await expect(submittedInput).toBeVisible();
  await expect(submittedInput).toContainText("Submitted input");
  await expect(submittedInput).toContainText("Expired session redirect");
  await expect(page.getByTestId("detail-run-history-source")).toContainText("not available");
  await expect(page.getByTestId("detail-run-history-source")).toContainText(
    "no structured transcript yet",
  );
});

test("offers run recovery when the selected active run has no session or transcript", async ({
  page,
}) => {
  await connectFixtureWorkspace(page, "/tmp/muxagent-stale-workspace");
  await openTaskFromBoard(page, "task-stale-fixture");

  await page.getByTestId("detail-run-run-stale-implement").click();
  await expect(page).toHaveURL(/[\?&]modal=transcript/);
  await expect(page.getByTestId("transcript-modal")).toBeVisible();
  await expect(page.getByTestId("detail-output-surface")).toContainText(
    "No live output recorded yet",
  );
  await expect(page.getByTestId("recover-run")).toBeVisible();

  await page.getByTestId("recover-run").click();

  await expect(page.getByTestId("recover-run")).toHaveCount(0);
  await expect(page.getByTestId("transcript-modal")).toContainText(
    "No persisted stream for this run",
  );
  await expect(page.getByTestId("transcript-modal")).toContainText("failed");
  await expect(page.getByTestId("detail-run-run-stale-implement")).toContainText("failed");
});

test("opens New Task from task detail without leaving the current screen", async ({
  page,
}) => {
  await connectFixtureWorkspace(page);
  await openTaskFromBoard(page, "task-live-fixture");
  await page.getByTestId("detail-run-run-live-implement").click();
  await expect(page.getByTestId("live-modal")).toBeVisible();

  const detailPath = new URL(page.url()).pathname;
  await expect(page.getByTestId("task-detail-screen")).toBeVisible();

  await page.evaluate(() => {
    const button = document.querySelector<HTMLButtonElement>(
      '[data-testid="open-new-task"]',
    );
    button?.click();
  });
  await expect(page.getByTestId("new-task-modal")).toBeVisible();
  await expect(page.getByTestId("live-modal")).toHaveCount(0);

  const modalUrl = new URL(page.url());
  expect(modalUrl.pathname).toBe(detailPath);
  expect(modalUrl.searchParams.get("newTask")).toBe("1");
  expect(modalUrl.searchParams.get("modal")).toBeNull();
  await expect(page.getByTestId("task-detail-screen")).toBeVisible();

  await page.getByTestId("new-task-close").click();
  await expect(page.getByTestId("new-task-modal")).toHaveCount(0);
  await expect(page.getByTestId("live-modal")).toHaveCount(0);

  const closedUrl = new URL(page.url());
  expect(closedUrl.pathname).toBe(detailPath);
  expect(closedUrl.searchParams.get("newTask")).toBeNull();
  expect(closedUrl.searchParams.get("modal")).toBeNull();
  await expect(page.getByTestId("task-detail-screen")).toBeVisible();
});

test("keeps task detail aligned when a full workspace task-list reload lands after detail is open", async ({
  page,
}) => {
  await connectFixtureWorkspace(page, "/tmp/muxagent-sync-workspace");
  await openTaskFromBoard(page, "task-sync-fixture");
  const detailUrl = new URL(page.url());
  const detailPath = detailUrl.pathname;
  const workspaceId = detailPath.match(/\/workspaces\/([^/]+)\//)?.[1];
  expect(workspaceId).toBeTruthy();

  const statusBlock = page.getByTestId("detail-task-status");
  await expect(statusBlock).toContainText("Status");
  await expect(statusBlock).toContainText("Running");
  await expect(page.getByTestId("detail-run-run-sync-implement")).toContainText("running");

  await triggerWorkspaceTaskReload(page, workspaceId!);
  await expect(page.getByTestId("task-detail-screen")).toBeVisible();

  const refreshedUrl = new URL(page.url());
  expect(refreshedUrl.pathname).toBe(detailPath);

  await expect(statusBlock).toContainText("Done");
  await expect(page.getByTestId("detail-run-run-sync-implement")).toContainText("done");
});

test("renders MCP transcript rows as grouped tool details with image previews", async ({
  page,
}) => {
  await connectFixtureWorkspace(page);
  await openTaskFromBoard(page, "task-live-mcp");

  await page.getByTestId("detail-run-run-mcp-implement").click();
  await expect(page).toHaveURL(/[\?&]run=run-mcp-implement/);
  await expect(page).toHaveURL(/[\?&]modal=transcript/);

  const outputSurface = page.getByTestId("detail-output-surface");
  await expect(outputSurface).toBeVisible();
  await expect(outputSurface).toContainText("2 tool calls");

  await page.getByTestId("transcript-tool-group-call-provider-render").click();
  await expect(page.getByTestId("transcript-tool-item_22")).toHaveCount(1);
  await expect(page.getByTestId("transcript-tool-item_22")).toContainText(
    "MCP · pencil.get_editor_state",
  );

  await page.getByTestId("transcript-tool-item_22").click();
  await expect(page.getByTestId("transcript-tool-detail-item_22")).toContainText(
    '"include_schema": true',
  );
  await expect(page.getByTestId("transcript-tool-detail-item_22")).toContainText(
    "Loaded the editor schema and confirmed the active canvas selection.",
  );

  await page.getByTestId("transcript-tool-call-provider-render").click();
  await expect(page.getByTestId("transcript-tool-detail-call-provider-render")).toContainText(
    "Rendered a preview image for the selected artboard.",
  );
  await expect(
    page.getByTestId("transcript-tool-detail-call-provider-render").locator("img"),
  ).toBeVisible();

  await expect(outputSurface).not.toContainText('{"type":"item.started"');
  await expect(outputSurface).not.toContainText("item.completed");
});

test("task deep links restore the route workspace even after switching to another workspace", async ({
  page,
}) => {
  await connectFixtureWorkspace(page);

  await expect(page.getByTestId("board-card-task-live-fixture")).toBeVisible();
  await openTaskFromBoard(page, "task-live-fixture");
  await expect(page).toHaveURL(/\/workspaces\/[^/]+\/tasks\/task-live-fixture$/);
  const firstWorkspaceDetailPath = new URL(page.url()).pathname;
  await expect(
    page.locator(".shell-workspace__row.is-active .shell-workspace__label").first(),
  ).toContainText(
    "muxagent-workspace",
  );

  await page.goBack();
  await expect(page).toHaveURL(/\/$/);
  await expect(page.getByTestId("entry-shell")).toBeVisible();
  await expect(page.getByTestId("workspace-picker-button")).toBeEnabled();
  page.once("dialog", (dialog) => dialog.accept("/tmp/muxagent-alt-workspace"));
  await page.getByTestId("workspace-picker-button").click();
  await page
    .locator(".shell-workspace__row")
    .filter({ hasText: "muxagent-alt-workspace" })
    .click();
  await expect(
    page.locator(".shell-workspace__row.is-active .shell-workspace__label").first(),
  ).toContainText("muxagent-alt-workspace");

  await page.evaluate((pathname) => {
    window.history.pushState({}, "", pathname);
    window.dispatchEvent(new PopStateEvent("popstate"));
  }, firstWorkspaceDetailPath);

  await expect(page).toHaveURL(new RegExp(`${firstWorkspaceDetailPath}$`));
  await expect(page.getByTestId("task-detail-screen")).toBeVisible();
  await expect(
    page.locator(".shell-workspace__row.is-active .shell-workspace__label").first(),
  ).toContainText(
    "muxagent-workspace",
  );
});

test("treats Tasks as the all-workspaces view and workspace rows as task scope", async ({
  page,
}) => {
  await connectFixtureWorkspace(page);

  page.once("dialog", (dialog) => dialog.accept("/tmp/muxagent-alt-workspace"));
  await page.getByTestId("workspace-picker-button").click();
  await expect(page.locator(".shell-workspace__row.is-active")).toHaveCount(0);

  await page
    .locator(".shell-workspace__row")
    .filter({ hasText: "muxagent-alt-workspace" })
    .click();
  await expect(
    page.locator(".shell-workspace__row.is-active .shell-workspace__label").first(),
  ).toContainText("muxagent-alt-workspace");

  await page.getByRole("link", { name: /^Tasks$/i }).click();
  await expect(page).toHaveURL(/\/$/);
  await expect(page.locator(".shell-workspace__row.is-active")).toHaveCount(0);
  await expect(page.getByTestId("task-board")).toContainText("muxagent-workspace");
  await expect(page.getByTestId("task-board")).toContainText("muxagent-alt-workspace");

  await page.getByRole("link", { name: /^Configs$/i }).click();
  await expect(page.getByTestId("configs-screen")).toBeVisible();
  await page
    .locator(".shell-workspace__row")
    .filter({ hasText: "muxagent-alt-workspace" })
    .click();
  await expect(page).toHaveURL(/\/$/);
  await expect(
    page.locator(".shell-workspace__row.is-active .shell-workspace__label").first(),
  ).toContainText("muxagent-alt-workspace");
  await expect(page.getByTestId("task-board")).toBeVisible();
});

test("restores the originating task-surface workspace scope after leaving task detail", async ({
  page,
}) => {
  await connectFixtureWorkspace(page);

  page.once("dialog", (dialog) => dialog.accept("/tmp/muxagent-alt-workspace"));
  await page.getByTestId("workspace-picker-button").click();
  await page.getByRole("link", { name: /^Tasks$/i }).click();
  await expect(page.locator(".shell-workspace__row.is-active")).toHaveCount(0);

  const allTasksCard = page
    .locator('[data-testid="board-card-task-live-fixture"]')
    .filter({ hasText: "muxagent-workspace" })
    .first();
  await allTasksCard.click();
  await expect(page.getByTestId("task-detail-screen")).toBeVisible();
  await expect(
    page.locator(".shell-workspace__row.is-active .shell-workspace__label").first(),
  ).toContainText("muxagent-workspace");

  await page.getByTestId("task-detail-back").click();
  await expect(page).toHaveURL(/\/$/);
  await expect(page.locator(".shell-workspace__row.is-active")).toHaveCount(0);

  await allTasksCard.click();
  await expect(page.getByTestId("task-detail-screen")).toBeVisible();
  await page.goBack();
  await expect(page).toHaveURL(/\/$/);
  await expect(page.locator(".shell-workspace__row.is-active")).toHaveCount(0);

  await page
    .locator(".shell-workspace__row")
    .filter({ hasText: "muxagent-alt-workspace" })
    .click();
  await expect(
    page.locator(".shell-workspace__row.is-active .shell-workspace__label").first(),
  ).toContainText("muxagent-alt-workspace");

  await openTaskFromBoard(page, "task-live-fixture");
  await expect(page.getByTestId("task-detail-screen")).toBeVisible();
  await page.goBack();
  await expect(page).toHaveURL(/\/$/);
  await expect(
    page.locator(".shell-workspace__row.is-active .shell-workspace__label").first(),
  ).toContainText("muxagent-alt-workspace");
});

test("renders approval and artifact preview task surfaces", async ({ page }) => {
  await page.setViewportSize({ width: 1200, height: 540 });
  await connectFixtureWorkspace(page);

  await openTaskFromBoard(page, "task-awaiting-pr");
  await expect(page.getByTestId("approval-pane")).toBeVisible();
  await expect(page.getByText("Review PR #42")).toBeVisible();
  await expect(page.getByRole("button", { name: "Approve" })).toBeVisible();
  await expect(page.getByTestId("detail-run-icon-run-awaiting-plan")).toHaveAttribute(
    "data-actor-type",
    "agent",
  );
  await expect(page.getByTestId("detail-run-icon-run-awaiting-review")).toHaveAttribute(
    "data-actor-type",
    "human",
  );

  await page.goBack();
  await expect(page).toHaveURL(/\/$/);
  await openTaskFromBoard(page, "task-live-fixture");
  await page.getByRole("button", { name: /plan\.md/i }).click();
  const artifactModal = page.getByTestId("artifact-modal");
  await expect(artifactModal).toBeVisible();
  await expect(
    artifactModal.getByText("Fixture artifact generated by the desktop web bridge."),
  ).toBeVisible();
  await expect(artifactModal.locator("table")).toBeVisible();
  await expect(artifactModal.locator('input[type="checkbox"]')).toHaveCount(2);
  await expect(artifactModal.getByText("export const fixture = true;")).toBeVisible();
  const artifactBody = artifactModal.locator(".detail-modal-frame__body");
  const scrollInfo = await artifactBody.evaluate((element) => ({
    overflowY: getComputedStyle(element).overflowY,
  }));
  expect(scrollInfo.overflowY).toBe("auto");
  await page.getByRole("button", { name: "Close detail" }).click();
  await expect(artifactModal).toHaveCount(0);
  await page.getByRole("button", { name: /summary\.md/i }).click();
  await expect(page.getByTestId("artifact-modal")).toBeVisible();
  await expect(page.getByTestId("artifact-modal")).toContainText(
    "Fixture artifact generated by the desktop web bridge.",
  );
});

test("keeps run drill-in available while showing the clarification action surface", async ({
  page,
}) => {
  await connectFixtureWorkspace(page);

  await page
    .getByRole("link", { name: /Clarify deployment strategy before implement/i })
    .click();
  await expect(page.getByTestId("clarification-pane")).toBeVisible();
  await expect(page.getByTestId("run-pane")).toHaveCount(0);
  await expect(
    page.getByText("Which deployment target should we prioritize first?"),
  ).toBeVisible();
  await expect(page.getByTestId("detail-run-run-clarify-implement")).toBeVisible();
  await page.getByTestId("detail-run-run-clarify-plan").click();
  await expect(page.getByTestId("transcript-modal")).toBeVisible();
  const outputSurface = page.getByTestId("detail-output-surface");
  await expect(outputSurface).toBeVisible();
  await expect(outputSurface).toContainText("read: docs/deploy.md");
  await expect(outputSurface).toContainText("deployment plan drafted");
  await expect(page).toHaveURL(/[\?&]run=run-clarify-plan/);
  await expect(page).toHaveURL(/[\?&]modal=transcript/);
});

test("resets clarification pager when switching to another clarification task", async ({
  page,
}) => {
  await connectFixtureWorkspace(page);

  await page
    .getByRole("link", { name: /Clarify deployment strategy before implement/i })
    .click();
  await expect(
    page.getByText("Which deployment target should we prioritize first?"),
  ).toBeVisible();
  await page.getByRole("button", { name: "Next clarification" }).click();
  await expect(
    page.getByText("Should we gate the rollout behind a feature flag?"),
  ).toBeVisible();

  await page.getByTestId("task-detail-back").click();
  await expect(page).toHaveURL(/\/$/);

  await page
    .getByRole("link", { name: /Clarify rollout checklist before verify/i })
    .click();
  await expect(
    page.getByText("Which checklist should verify follow first?"),
  ).toBeVisible();
  await expect(
    page.getByText("Do we need customer-facing confirmation in this pass?"),
  ).not.toBeVisible();
});

test("renders failed and complete task surfaces", async ({ page }) => {
  await connectFixtureWorkspace(page);

  await openTaskFromBoard(page, "task-failed-deploy");
  const failedPane = page.getByTestId("failed-pane");
  await expect(failedPane).toBeVisible();
  await expect(
    failedPane.getByText("Health check failed after deploy"),
  ).toBeVisible();
  const failedPaneStyles = await failedPane.evaluate((element) => {
    const styles = getComputedStyle(element);
    return {
      backgroundColor: styles.backgroundColor,
    };
  });
  expect(failedPaneStyles.backgroundColor).toBe("rgba(0, 0, 0, 0)");
  const retryStep = page.getByTestId("retry-step");
  const retryStepStyles = await retryStep.evaluate((element) => {
    const styles = getComputedStyle(element);
    return {
      backgroundColor: styles.backgroundColor,
      borderRadius: styles.borderRadius,
    };
  });
  expect(retryStepStyles.backgroundColor).toBe("rgb(251, 248, 246)");
  expect(retryStepStyles.borderRadius).toBe("4px");

  await page.goBack();
  await expect(page).toHaveURL(/\/$/);
  await openTaskFromBoard(page, "task-done-login");
  await expect(page.getByTestId("complete-pane")).toBeVisible();
  await expect(page.locator('[data-testid="detail-activity"] [data-testid="complete-pane"]')).toHaveCount(
    0,
  );
  await expect(page.getByTestId("follow-up-description")).toBeVisible();
  await expect(page.getByTestId("follow-up-config-trigger")).toContainText("default");
  await page.getByTestId("detail-run-run-login-implement").click();
  await expect(page.getByTestId("transcript-modal")).toBeVisible();
  await expect(page.getByTestId("detail-run-history-source")).toContainText(
    "provider transcript",
  );
  await expect(page.getByTestId("detail-run-session")).toContainText(
    "session-login-implement",
  );
  await expect(page.getByTestId("detail-output-surface")).toContainText(
    "patched the login guard to preserve the authenticated session cookie.",
  );
});

test("switches configs from the compact follow-up rail and starts a fixture follow-up", async ({
  page,
}) => {
  await connectFixtureWorkspace(page);
  await openTaskFromBoard(page, "task-done-login");

  const description = `Fixture follow-up ${Date.now()}`;
  const secondLine = "Carry the rollout note into a second line.";
  const multilineDescription = `${description}\n${secondLine}`;
  const completePane = page.getByTestId("complete-pane");
  const configTrigger = page.getByTestId("follow-up-config-trigger");
  const configPicker = page.getByTestId("follow-up-config-picker");
  const descriptionInput = page.getByTestId("follow-up-description");

  await expect(completePane).toBeVisible();
  await expect(configTrigger).toContainText("default");

  await configTrigger.click();
  await expect(configPicker).toBeVisible();
  await page.keyboard.press("Escape");
  await expect(configPicker).toHaveCount(0);

  await configTrigger.click();
  await expect(configPicker).toBeVisible();
  await page.getByText("Activity").click();
  await expect(configPicker).toHaveCount(0);

  await configTrigger.click();
  await expect(configPicker).toBeVisible();
  await page.getByTestId("follow-up-config-option-quick").click();
  await expect(configPicker).toHaveCount(0);
  await expect(configTrigger).toContainText("quick");
  await expect(descriptionInput).toHaveJSProperty("tagName", "TEXTAREA");

  const previousPath = new URL(page.url()).pathname;
  await descriptionInput.fill(description);
  const initialHeight = await descriptionInput.evaluate((element) => element.clientHeight);
  await descriptionInput.press("Shift+Enter");
  await descriptionInput.type(secondLine);
  await expect(descriptionInput).toHaveValue(multilineDescription);
  await expect
    .poll(() => new URL(page.url()).pathname, { timeout: 10_000 })
    .toBe(previousPath);
  const expandedHeight = await descriptionInput.evaluate((element) => element.clientHeight);
  expect(expandedHeight).toBeGreaterThan(initialHeight);
  await descriptionInput.press("Enter");

  await expect
    .poll(() => new URL(page.url()).pathname, { timeout: 10_000 })
    .not.toBe(previousPath);
  await expect(page.locator(".detail-main-header__prompt-text")).toContainText(description);
  await expect(page.locator(".detail-main-header__prompt-text")).toContainText(secondLine);
  await expect(
    page.locator(".detail-properties__block").filter({ hasText: /^Config/ }),
  ).toContainText("quick");
});

test("renders the blocked task surface", async ({ page }) => {
  await connectFixtureWorkspace(page);

  await openTaskFromBoard(page, "task-blocked-db");
  const blockedPane = page.getByTestId("blocked-pane");
  await expect(blockedPane).toBeVisible();
  await expect(blockedPane).toContainText(
    "Waiting for migration window",
  );
  await expect(blockedPane).not.toContainText("Task paused at");
  const blockedPaneStyles = await blockedPane.evaluate((element) => {
    const styles = getComputedStyle(element);
    return {
      backgroundColor: styles.backgroundColor,
    };
  });
  expect(blockedPaneStyles.backgroundColor).toBe("rgba(0, 0, 0, 0)");
  const continueButton = page.getByTestId("continue-blocked");
  await expect(continueButton).toBeVisible();
  await expect(continueButton.locator("svg")).toHaveCount(1);
  const continueButtonChildOrder = await continueButton.evaluate((element) => {
    return Array.from(element.children).map((child) => child.tagName.toLowerCase());
  });
  expect(continueButtonChildOrder[0]).toBe("svg");
  const continueButtonStyles = await continueButton.evaluate((element) => {
    const styles = getComputedStyle(element);
    return {
      backgroundColor: styles.backgroundColor,
      borderRadius: styles.borderRadius,
    };
  });
  expect(continueButtonStyles.backgroundColor).toBe("rgb(251, 248, 246)");
  expect(continueButtonStyles.borderRadius).toBe("4px");
});

test("adds a new blocked activity row when the next iteration is blocked by max iterations", async ({
  page,
}) => {
  await connectFixtureWorkspace(page);

  await openTaskFromBoard(page, "task-blocked-max-iteration");
  await expect(page.getByTestId("blocked-pane")).toBeVisible();
  await expect(page.getByText('node "implement" exceeded max_iterations')).toBeVisible();

  const completedRun = page.getByTestId("detail-run-run-limit-implement");
  const syntheticBlockedRun = page.getByTestId(
    "detail-run-synthetic-blocked-task-blocked-max-iteration-implement-2",
  );
  await expect(completedRun).toBeVisible();
  await expect(syntheticBlockedRun).toBeVisible();

  const completedRunBox = await completedRun.boundingBox();
  const syntheticBlockedRunBox = await syntheticBlockedRun.boundingBox();
  expect(completedRunBox).not.toBeNull();
  expect(syntheticBlockedRunBox).not.toBeNull();
  expect(completedRunBox!.y).toBeLessThan(syntheticBlockedRunBox!.y);

  await completedRun.click();
  await expect(page.getByTestId("transcript-modal")).toBeVisible();
  await expect(page.getByTestId("detail-output-surface")).toContainText(
    "captured the implementation constraints before the next iteration was blocked by max iterations.",
  );
  await expect(page).toHaveURL(/[\?&]run=run-limit-implement/);
  await expect(page).not.toHaveURL(/synthetic-blocked-task-blocked-max-iteration/);
});

test("defaults to the board-only task surface and ignores legacy list routes", async ({
  page,
}) => {
  await connectFixtureWorkspace(page, "/tmp/muxagent-workspace", "/?layout=list");

  await expect(page.getByTestId("task-board")).toBeVisible();
  await expect(page.getByTestId("task-layout-switch")).toHaveCount(0);
  await expect(page.getByTestId("task-list")).toHaveCount(0);
  await expect(page.getByTestId("board-card-task-done-long-copy")).toContainText(
    "帮我想办法给这个网站搞 SEO",
  );

  await page
    .locator(".shell-workspace__row")
    .filter({ hasText: "muxagent-workspace" })
    .click();
  await expect(page).toHaveURL(/\/$/);
  await expect(page.getByTestId("task-board")).toBeVisible();

  await page.getByRole("link", { name: /^Tasks$/i }).click();
  await expect(page).toHaveURL(/\/$/);
  await expect(page.getByTestId("task-board")).toBeVisible();

  await page.getByTestId("task-view-needs-attention").click();
  await expect(page).toHaveURL(/\/\?view=attention$/);
  await expect(page.getByTestId("task-board")).toBeVisible();
});

test("keeps long board cards readable without forcing horizontal overflow on narrower widths", async ({
  page,
}) => {
  await page.setViewportSize({ width: 980, height: 860 });
  await connectFixtureWorkspace(page);

  const boardSurface = page.getByTestId("task-board");
  const hasHorizontalOverflow = await boardSurface.evaluate((element) => {
    return element.scrollWidth > element.clientWidth;
  });
  expect(hasHorizontalOverflow).toBe(false);

  const longCard = page.getByTestId("board-card-task-done-long-copy");
  const title = longCard.locator("h3");
  const meta = longCard.locator(".task-board-card__meta");
  const cardBox = await longCard.boundingBox();
  const titleBox = await title.boundingBox();
  const metaBox = await meta.boundingBox();

  expect(cardBox).not.toBeNull();
  expect(titleBox).not.toBeNull();
  expect(metaBox).not.toBeNull();
  expect(cardBox?.height ?? 0).toBeLessThan(220);
  expect((titleBox?.y ?? 0) + (titleBox?.height ?? 0)).toBeLessThanOrEqual(
    (metaBox?.y ?? 0) + 1,
  );
});

test("keeps dense completed-column cards at their natural height instead of shrinking them", async ({
  page,
}) => {
  await connectFixtureWorkspace(page);

  const completedCard = page.getByTestId("board-card-task-done-login");
  const meta = completedCard.locator(".task-board-card__meta");

  await expect(completedCard).toBeVisible();
  await expect(meta).toBeVisible();

  const cardBox = await completedCard.boundingBox();
  const metaBox = await meta.boundingBox();

  expect(cardBox).not.toBeNull();
  expect(metaBox).not.toBeNull();
  expect(cardBox?.height ?? 0).toBeGreaterThanOrEqual(54);
  expect((metaBox?.y ?? 0) + (metaBox?.height ?? 0)).toBeLessThanOrEqual(
    (cardBox?.y ?? 0) + (cardBox?.height ?? 0) + 1,
  );
});

test("keeps board lane headers aligned when neighboring columns overflow", async ({
  page,
}) => {
  await page.setViewportSize({ width: 1200, height: 540 });
  await connectFixtureWorkspace(page);

  const lanes = await page.getByTestId("task-board").evaluate((board) => {
    const counts = board.querySelectorAll<HTMLElement>(".board-column__count");
    if (counts[0]) counts[0].textContent = "14";
    if (counts[1]) counts[1].textContent = "2";
    if (counts[2]) counts[2].textContent = "71";

    const stacks = board.querySelectorAll<HTMLElement>(".board-column__stack");
    stacks.forEach((stack, index) => {
      const seed = stack.firstElementChild;
      if (!seed) {
        return;
      }
      const clones = index === 0 ? 12 : index === 2 ? 40 : 0;
      for (let i = 0; i < clones; i += 1) {
        stack.appendChild(seed.cloneNode(true));
      }
    });

    return Array.from(board.querySelectorAll<HTMLElement>(".board-column")).map((column) => {
      const header = column.querySelector<HTMLElement>(".board-column__header");
      const stack = column.querySelector<HTMLElement>(".board-column__stack");
      const label = column.querySelector<HTMLElement>(".board-column__label");
      const headerRect = header?.getBoundingClientRect();
      const stackRect = stack?.getBoundingClientRect();
      return {
        label: label?.textContent ?? "",
        headerHeight: headerRect?.height ?? 0,
        stackY: stackRect?.y ?? 0,
        stackClientHeight: stack?.clientHeight ?? 0,
        stackScrollHeight: stack?.scrollHeight ?? 0,
      };
    });
  });

  expect(lanes).toHaveLength(3);

  const headerHeights = lanes.map((lane) => lane.headerHeight);
  const stackYs = lanes.map((lane) => lane.stackY);
  const overflowingLanes = lanes.filter(
    (lane) => lane.stackScrollHeight > lane.stackClientHeight + 1,
  );

  expect(overflowingLanes).toHaveLength(2);
  expect(Math.max(...headerHeights) - Math.min(...headerHeights)).toBeLessThanOrEqual(1);
  expect(Math.max(...stackYs) - Math.min(...stackYs)).toBeLessThanOrEqual(1);
});

test("hides board lane scrollbars while preserving lane scrolling", async ({
  page,
}) => {
  await page.setViewportSize({ width: 1200, height: 540 });
  await connectFixtureWorkspace(page);

  const lanes = await page.getByTestId("task-board").evaluate((board) => {
    const stacks = board.querySelectorAll<HTMLElement>(".board-column__stack");
    stacks.forEach((stack) => {
      const seed = stack.firstElementChild;
      if (!seed) {
        return;
      }
      for (let i = 0; i < 18; i += 1) {
        stack.appendChild(seed.cloneNode(true));
      }
    });

    return Array.from(stacks).map((stack) => {
      const before = stack.scrollTop;
      stack.scrollTop = 120;
      const after = stack.scrollTop;
      const style = getComputedStyle(stack);
      const webkitScrollbar = getComputedStyle(stack, "::-webkit-scrollbar");

      return {
        clientHeight: stack.clientHeight,
        scrollHeight: stack.scrollHeight,
        before,
        after,
        scrollbarWidth: style.getPropertyValue("scrollbar-width").trim(),
        webkitScrollbarWidth: webkitScrollbar.width,
        webkitScrollbarHeight: webkitScrollbar.height,
      };
    });
  });

  expect(lanes).toHaveLength(3);

  lanes.forEach((lane) => {
    expect(lane.scrollHeight).toBeGreaterThan(lane.clientHeight);
    expect(lane.after).toBeGreaterThan(lane.before);
    expect(
      lane.scrollbarWidth === "none" ||
        lane.webkitScrollbarWidth === "0px" ||
        lane.webkitScrollbarHeight === "0px",
    ).toBe(true);
  });
});
