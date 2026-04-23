import { expect, test, type Page } from "@playwright/test";
import { skipOnboarding } from "./_helpers";

const tinyPngBase64 =
  "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII=";

const tinyPngFile = {
  name: "fixture-image.png",
  mimeType: "image/png",
};

test.beforeEach(async ({ page }) => {
  await skipOnboarding(page);
});

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
  await page.getByTestId(`board-card-link-${taskId}`).click();
}

function allWorkspacesScope(page: Page) {
  return page.getByTestId("task-scope-all-workspaces");
}

function workspaceRow(page: Page, label: string) {
  return page.locator('[data-testid^="workspace-row-"]').filter({ hasText: label }).first();
}

async function pasteTinyPngInto(page: Page, textareaTestId: string) {
  await page.getByTestId(textareaTestId).evaluate(
    (element, fileData) => {
      const binary = window.atob(fileData.base64);
      const bytes = new Uint8Array(binary.length);
      for (let index = 0; index < binary.length; index += 1) {
        bytes[index] = binary.charCodeAt(index);
      }
      const file = new File([bytes], fileData.name, { type: fileData.mimeType });
      const clipboardData = new DataTransfer();
      clipboardData.items.add(file);
      element.dispatchEvent(
        new ClipboardEvent("paste", {
          bubbles: true,
          cancelable: true,
          clipboardData,
        }),
      );
    },
    {
      base64: tinyPngBase64,
      mimeType: tinyPngFile.mimeType,
      name: tinyPngFile.name,
    },
  );
}

async function readHeaderAlignment(page: Page) {
  await page.getByTestId("detail-main-content").evaluate((element) => {
    element.scrollTop = 0;
  });
  const [promptBox, activityBox] = await Promise.all([
    page.locator(".detail-main-header__prompt-text").boundingBox(),
    page.locator(".detail-activity__eyebrow").boundingBox(),
  ]);
  if (!promptBox || !activityBox) {
    throw new Error("Expected task detail header alignment targets to be visible");
  }
  return {
    activityX: activityBox.x,
    promptX: promptBox.x,
  };
}

async function readHistoryGeometry(page: Page) {
  return page.evaluate(() => {
    const scroller = document.querySelector<HTMLElement>(
      '[data-testid="detail-main-content"]',
    );
    if (scroller) {
      scroller.scrollTop = 0;
    }
    const history = document.querySelector('[data-testid="detail-task-history"]');
    const historyHeader = history?.querySelector(".detail-history__header");
    const headerIcon = history?.querySelector(".detail-history__header-icon");
    const row = history?.querySelector(".detail-history__row");
    const icon = history?.querySelector(".detail-history__row-icon");
    const title = history?.querySelector(".detail-history__row-title-text");
    const time = history?.querySelector(".detail-history__row-time");
    const meta = history?.querySelector(".detail-history__row-meta");
    const activityHeader = document.querySelector(".detail-activity__header");
    const activityRow = document.querySelector(".detail-activity-card");
    const lastActivityRow = document.querySelector(".detail-activity-card:last-child");
    if (
      !history ||
      !historyHeader ||
      !headerIcon ||
      !row ||
      !icon ||
      !title ||
      !time ||
      !meta ||
      !activityHeader ||
      !activityRow ||
      !lastActivityRow
    ) {
      throw new Error("Expected the follow-up history section to be visible");
    }
    const historyRect = history.getBoundingClientRect();
    const historyHeaderRect = historyHeader.getBoundingClientRect();
    const headerIconRect = headerIcon.getBoundingClientRect();
    const rowRect = row.getBoundingClientRect();
    const iconRect = icon.getBoundingClientRect();
    const activityHeaderRect = activityHeader.getBoundingClientRect();
    const activityRowRect = activityRow.getBoundingClientRect();
    const lastActivityRowStyles = getComputedStyle(lastActivityRow);
    const rowStyles = getComputedStyle(row);
    const titleStyles = getComputedStyle(title);
    const timeStyles = getComputedStyle(time);
    const metaStyles = getComputedStyle(meta);
    return {
      activityGap: Math.round(activityRowRect.y - activityHeaderRect.bottom),
      activityLastBorderBottomWidth: lastActivityRowStyles.borderBottomWidth,
      activityLastBoxShadow: lastActivityRowStyles.boxShadow,
      headerInset: Math.round(headerIconRect.x - historyRect.x),
      historyGap: Math.round(rowRect.y - historyHeaderRect.bottom),
      iconHeight: Math.round(iconRect.height),
      iconWidth: Math.round(iconRect.width),
      rowHeight: Math.round(rowRect.height),
      rowInset: Math.round(rowRect.x - historyRect.x),
      rowPaddingLeft: rowStyles.paddingLeft,
      timeFontSize: timeStyles.fontSize,
      titleFontSize: titleStyles.fontSize,
      metaFontSize: metaStyles.fontSize,
    };
  });
}

async function readCollapsedHistoryGeometry(page: Page) {
  return page.evaluate(() => {
    const scroller = document.querySelector<HTMLElement>(
      '[data-testid="detail-main-content"]',
    );
    if (scroller) {
      scroller.scrollTop = 0;
    }
    const topDivider = document.querySelector(".detail-main-divider");
    const history = document.querySelector('[data-testid="detail-task-history"]');
    const historyHeader = history?.querySelector(".detail-history__header");
    const bottomDivider = document.querySelector(".detail-history-divider");
    const feed = history?.querySelector(".detail-history__feed");
    if (!topDivider || !history || !historyHeader || !bottomDivider || !feed) {
      throw new Error("Expected the collapsed history section to be visible");
    }
    const topDividerRect = topDivider.getBoundingClientRect();
    const historyHeaderRect = historyHeader.getBoundingClientRect();
    const bottomDividerRect = bottomDivider.getBoundingClientRect();
    return {
      bottomGap: Math.round(bottomDividerRect.top - historyHeaderRect.bottom),
      feedDisplay: getComputedStyle(feed).display,
      feedHidden: feed.hasAttribute("hidden"),
      topGap: Math.round(historyHeaderRect.top - topDividerRect.bottom),
    };
  });
}

async function readWorkbenchDividerAlignment(page: Page) {
  return page.evaluate(() => {
    const tabbar = document.querySelector(".workbench__tabbar");
    const rightPanel = document.querySelector('[data-testid="workbench-right-panel"]');
    const rightHeader = rightPanel?.querySelector(".workbench__slot-header");
    if (!tabbar || !rightHeader) {
      throw new Error("Expected the workbench tabbar and right-panel header to be visible");
    }
    const tabbarRect = tabbar.getBoundingClientRect();
    const rightHeaderRect = rightHeader.getBoundingClientRect();
    return {
      rightHeaderBottom: Math.round(rightHeaderRect.bottom),
      tabbarBottom: Math.round(tabbarRect.bottom),
    };
  });
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

  await expect(page.getByTestId("board-card-title-task-live-fixture")).toHaveText(
    "Refactor auth middleware",
  );
  await expect(page.getByTestId("board-card-worktree-icon-task-live-fixture")).toBeVisible();
  await expect(page.getByTestId("board-card-workspace-meta-task-live-fixture")).toContainText(
    "muxagent-workspace",
  );
  const firstMetaProperty = await page
    .getByTestId("board-card-task-live-fixture")
    .locator(".task-board-card__meta")
    .evaluate((element) => element.firstElementChild?.getAttribute("data-testid"));
  expect(firstMetaProperty).toBe("board-card-worktree-icon-task-live-fixture");

  await openTaskFromBoard(page, "task-live-fixture");

  await expect(page).toHaveURL(/\/workspaces\/[^/]+\/tasks\/task-live-fixture$/);
  await expect(page.getByTestId("task-detail-screen")).toBeVisible();
  await expect(page.getByTestId("task-detail-back")).toHaveCount(0);
  await expect(page.getByTestId("workbench-tab-task-board")).toBeVisible();
  await expect(page.getByTestId("task-detail-header-description")).toContainText(
    "Refactor auth middleware",
  );
  await expect(page.getByTestId("detail-inline-properties")).toHaveCount(0);
  await expect(page.getByTestId("detail-task-config")).toContainText("default");
  await expect(page.getByTestId("detail-task-duration")).toContainText("Duration");
  await expect(page.getByTestId("detail-task-created")).toContainText("Created");
  await expect(page.getByTestId("detail-task-runs")).toContainText("Runs");
  await expect(page.getByTestId("detail-inline-support")).toHaveCount(0);
  await expect(page.getByTestId("workbench-right-panel")).toBeVisible();
  await expect(page.getByTestId("detail-properties-header")).toContainText("Properties");
  await expect(page.getByRole("button", { name: "Collapse right panel" })).toBeEnabled();
  await expect(page.getByTestId("detail-task-status")).toContainText("Running");
  await expect(page.getByTestId("detail-task-launch-mode")).toContainText("Launch mode");
  await expect(page.getByTestId("detail-task-launch-mode")).toContainText("Worktree");
  await expect(page.getByTestId("detail-task-launch-mode-icon")).toBeVisible();
  await expect(page.getByTestId("detail-task-launch-mode-name")).toContainText(
    "muxagent/task-live-fixture",
  );
  await expect(page.getByTestId("detail-task-flow")).toContainText("plan");
  await expect(page.getByTestId("detail-task-flow")).toContainText("implement");
  const dividerAlignment = await readWorkbenchDividerAlignment(page);
  expect(dividerAlignment.rightHeaderBottom).toBe(dividerAlignment.tabbarBottom);
  await expect(page.getByTestId("detail-run-run-live-plan")).toBeVisible();
  await expect(page.getByTestId("detail-run-summary-run-live-plan")).toContainText(
    "Scope the middleware refactor around the anonymous bypass first",
  );
  await expect(page.getByTestId("detail-run-summary-run-live-plan")).toContainText("plan.md");
  const mainContentScroll = await page.getByTestId("detail-main-content").evaluate((element) => ({
    scrollTop: element.scrollTop,
    scrollHeight: element.scrollHeight,
    clientHeight: element.clientHeight,
  }));
  const activityOverflowY = await page.getByTestId("detail-activity").evaluate((element) => {
    return getComputedStyle(element).overflowY;
  });
  const implementBox = await page.getByTestId("detail-run-run-live-implement").boundingBox();
  const planBox = await page.getByTestId("detail-run-run-live-plan").boundingBox();
  expect(mainContentScroll.scrollTop + mainContentScroll.clientHeight).toBeGreaterThanOrEqual(
    mainContentScroll.scrollHeight - 1,
  );
  expect(activityOverflowY).not.toBe("auto");
  expect(activityOverflowY).not.toBe("scroll");
  expect(implementBox).not.toBeNull();
  expect(planBox).not.toBeNull();
  expect(planBox!.y).toBeLessThan(implementBox!.y);
  await page.getByTestId("detail-main-content").evaluate((element) => {
    element.scrollTop = 0;
  });
  await expect(page.getByTestId("task-detail-header-description")).toBeInViewport();
  await expect(page.getByTestId("transcript-modal")).toHaveCount(0);
  await expect(page.getByTestId("artifact-modal")).toHaveCount(0);
});

test("hides the follow-up rail for running task detail screens", async ({ page }) => {
  await connectFixtureWorkspace(page);
  await openTaskFromBoard(page, "task-live-fixture");

  await expect(page).toHaveURL(/\/workspaces\/[^/]+\/tasks\/task-live-fixture$/);
  await expect(page.getByTestId("complete-pane")).toHaveCount(0);
  await expect(page.getByTestId("follow-up-description")).toHaveCount(0);
  await expect(page.getByTestId("follow-up-config-trigger")).toHaveCount(0);
});

test("renders markdown and preserved line breaks in the task detail header and activity summary", async ({
  page,
}) => {
  await connectFixtureWorkspace(page);

  await openTaskFromBoard(page, "task-markdown-detail");
  await expect(page.getByTestId("task-detail-screen")).toBeVisible();

  const headerDescription = page.getByTestId("task-detail-header-description");
  await expect(headerDescription.locator("strong")).toHaveText("Render markdown in task detail");
  await expect(headerDescription).toContainText("Keep multiline summaries readable.");
  const headerMetrics = await headerDescription.locator("p").evaluate((element) => {
    const styles = window.getComputedStyle(element);
    return {
      height: element.getBoundingClientRect().height,
      lineHeight: Number.parseFloat(styles.lineHeight),
    };
  });
  expect(headerMetrics.height).toBeGreaterThan(headerMetrics.lineHeight * 1.5);

  const summary = page.getByTestId("detail-run-summary-run-markdown-detail-implement");
  await expect(summary.locator("strong")).toHaveText("Implemented the task detail markdown pass");
  await expect(summary.locator("code")).toHaveText("result.md");
  await expect(summary).toContainText("Preserved the multiline summary in result.md.");
  const summaryMetrics = await summary.locator("p").evaluate((element) => {
    const styles = window.getComputedStyle(element);
    return {
      height: element.getBoundingClientRect().height,
      lineHeight: Number.parseFloat(styles.lineHeight),
    };
  });
  expect(summaryMetrics.height).toBeGreaterThan(summaryMetrics.lineHeight * 1.5);
});

test("aligns the task detail header and section labels on one content column in default and follow-up states", async ({
  page,
}) => {
  await connectFixtureWorkspace(page);

  await openTaskFromBoard(page, "task-blocked-db");
  await expect(page.getByTestId("task-detail-screen")).toBeVisible();

  const runningAlignment = await readHeaderAlignment(page);
  expect(Math.abs(runningAlignment.activityX - runningAlignment.promptX)).toBeLessThanOrEqual(1);

  await page.goBack();
  await expect(page).toHaveURL(/\/$/);

  await openTaskFromBoard(page, "task-follow-up-history-fixture");
  await expect(page.getByTestId("complete-pane")).toBeVisible();

  const followUpAlignment = await readHeaderAlignment(page);
  expect(Math.abs(followUpAlignment.activityX - followUpAlignment.promptX)).toBeLessThanOrEqual(1);
});

test("shows parent task history in detail and lets the user navigate up the chain", async ({
  page,
}) => {
  await connectFixtureWorkspace(page);

  await expect(page.getByTestId("board-card-task-follow-up-history-fixture")).toContainText(
    "Pause running task gracefully when daemon receives SIGTERM",
  );

  await openTaskFromBoard(page, "task-follow-up-history-fixture");
  await expect(page).toHaveURL(/\/workspaces\/[^/]+\/tasks\/task-follow-up-history-fixture$/);

  const history = page.getByTestId("detail-task-history");
  const headerPrompt = page.locator(".detail-main-header__prompt-text");
  await expect(history).toBeVisible();
  await expect(page.getByTestId("complete-pane")).toBeVisible();
  await expect(page.getByTestId("complete-pane")).toHaveAttribute(
    "data-follow-up-state",
    "basic",
  );
  await expect(page.getByTestId("follow-up-mode-fixed")).toContainText("Continue here");
  await expect(page.getByTestId("follow-up-send")).toBeVisible();
  await page.getByTestId("follow-up-mode-fixed").click();
  await expect(page.getByTestId("follow-up-mode-popup")).toHaveCount(0);
  await expect(page.getByTestId("detail-task-history-count")).toHaveText("2 iterations");
  await expect(
    page
      .getByTestId("detail-task-ancestor-task-follow-up-history-root")
      .locator(".detail-history__row-title-text"),
  ).toHaveText("Refactor the auth middleware to use JWT validation with configurable TTL");
  await expect(
    page
      .getByTestId("detail-task-ancestor-task-follow-up-history-parent")
      .locator(".detail-history__row-title-text"),
  ).toHaveText("Add test coverage for the new token refresh logic");
  await expect(headerPrompt).toContainText(
    "Pause running task gracefully when daemon receives SIGTERM",
  );

  await page.getByTestId("detail-task-ancestor-task-follow-up-history-parent").click();
  await expect(page).toHaveURL(/\/workspaces\/[^/]+\/tasks\/task-follow-up-history-parent$/);
  await expect(headerPrompt).toContainText("Add test coverage for the new token refresh logic");
  await expect(
    page
      .getByTestId("detail-task-ancestor-task-follow-up-history-root")
      .locator(".detail-history__row-title-text"),
  ).toHaveText("Refactor the auth middleware to use JWT validation with configurable TTL");
  await expect(page.getByTestId("detail-task-ancestor-task-follow-up-history-parent")).toHaveCount(
    0,
  );

  await page.getByTestId("detail-task-ancestor-task-follow-up-history-root").click();
  await expect(page).toHaveURL(/\/workspaces\/[^/]+\/tasks\/task-follow-up-history-root$/);
  await expect(headerPrompt).toContainText(
    "Refactor the auth middleware to use JWT validation with configurable TTL",
  );
  await expect(page.getByTestId("detail-task-history")).toHaveCount(0);
});

test("aggregates follow-up parents on the board and reveals the full lineage on each leaf card", async ({
  page,
}) => {
  await connectFixtureWorkspace(page);

  await expect(page.getByTestId("board-card-task-follow-up-history-root")).toHaveCount(0);
  await expect(page.getByTestId("board-card-task-follow-up-history-parent")).toHaveCount(0);
  await expect(page.getByTestId("board-card-task-follow-up-history-fixture")).toBeVisible();
  await expect(page.getByTestId("board-card-task-follow-up-history-sibling")).toBeVisible();
  await expect(
    page.getByTestId("board-card-lineage-toggle-task-follow-up-history-sibling"),
  ).toContainText("2 PREVIOUS");

  await page.getByTestId("board-card-lineage-toggle-task-follow-up-history-fixture").click();
  await expect(
    page.getByTestId("board-card-lineage-toggle-task-follow-up-history-fixture"),
  ).toContainText("PREVIOUSLY");
  await expect(
    page
      .getByTestId("board-card-lineage-task-follow-up-history-fixture")
      .locator(".task-board-card__ancestor-title"),
  ).toHaveText([
    "Refactor the auth middleware to use JWT validation with configurable TTL",
    "Add test coverage for the new token refresh logic",
  ]);
});

test("matches the follow-up history row geometry from the design frame", async ({ page }) => {
  await connectFixtureWorkspace(page);
  await openTaskFromBoard(page, "task-follow-up-history-fixture");
  await expect(page.getByTestId("detail-task-history")).toBeVisible();
  await expect(page.getByTestId("complete-pane")).toBeVisible();

  const geometry = await readHistoryGeometry(page);
  expect(geometry.historyGap).toBe(14);
  expect(geometry.activityGap).toBe(14);
  expect(geometry.activityLastBorderBottomWidth).toBe("0px");
  expect(geometry.activityLastBoxShadow).toBe("none");
  expect(geometry.headerInset).toBe(8);
  expect(geometry.rowInset).toBe(28);
  expect(geometry.rowPaddingLeft).toBe("16px");
  expect(geometry.rowHeight).toBe(60);
  expect(geometry.iconWidth).toBe(28);
  expect(geometry.iconHeight).toBe(28);
  expect(geometry.titleFontSize).toBe("14px");
  expect(geometry.timeFontSize).toBe("12px");
  expect(geometry.metaFontSize).toBe("12px");
});

test("collapses follow-up history with symmetric header spacing", async ({ page }) => {
  await connectFixtureWorkspace(page);
  await openTaskFromBoard(page, "task-follow-up-history-fixture");

  const historyToggle = page.getByTestId("detail-task-history-toggle");
  const historyFeed = page.locator(".detail-history__feed");

  await expect(historyToggle).toHaveAttribute("aria-expanded", "true");
  await expect(historyFeed).toBeVisible();

  await historyToggle.click();

  await expect(historyToggle).toHaveAttribute("aria-expanded", "false");
  await expect(historyFeed).toBeHidden();

  const geometry = await readCollapsedHistoryGeometry(page);
  expect(geometry.topGap).toBe(16);
  expect(geometry.bottomGap).toBe(16);
  expect(geometry.feedHidden).toBe(true);
  expect(geometry.feedDisplay).toBe("none");
});

test("shows running preview rows on the card and keeps the feed pinned on live updates", async ({
  page,
}) => {
  await connectFixtureWorkspace(page);
  await openTaskFromBoard(page, "task-live-fixture");

  const preview = page.getByTestId("detail-run-preview-run-live-implement");
  const runningCard = page.getByTestId("detail-run-run-live-implement");
  const artifactChip = page.getByRole("button", { name: "implement-preview.md" });

  await expect(preview).toBeVisible();
  await expect(preview).toContainText("applying middleware changes");
  await expect(preview).toContainText("Editing src/auth/middleware.ts");
  await expect(preview).not.toContainText(
    "Need to verify whether the middleware redirect should happen before the anonymous bypass.",
  );
  await expect(runningCard.locator(".detail-activity-card__file-row")).toHaveCount(0);
  await expect(artifactChip).toBeVisible();

  await artifactChip.click();
  await expect(page.getByTestId("artifact-modal")).toBeVisible();
  await expect(page.getByTestId("artifact-modal")).toContainText("implement-preview.md");
  await page.getByRole("button", { name: "Close detail" }).click();
  await expect(page.getByTestId("artifact-modal")).toHaveCount(0);

  await page.evaluate(async () => {
    const [{ useTaskSnapshotStore }] = await Promise.all([
      import("/src/state/task-snapshot-store.ts"),
    ]);
    const workspaceId = window.location.pathname.match(/\/workspaces\/([^/]+)\//)?.[1];
    if (!workspaceId) {
      throw new Error("Missing workspace id");
    }
    const now = new Date().toISOString();
    useTaskSnapshotStore.getState().appendLiveEvents(
      workspaceId,
      "task-live-fixture",
      "run-live-implement",
      [
        {
          id: "evt-live-message-2",
          kind: "message",
          source: "live",
          nodeRunId: "run-live-implement",
          sessionId: "session-live-implement",
          seq: 10,
          at: now,
          recordedAt: now,
          provenance: "executor_persisted",
          messageId: "msg-live-2",
          partId: "part-live-2",
          role: "assistant",
          partType: "text",
          text: "middleware guard patched and ready for verification",
        },
      ],
    );
  });

  await expect(preview).toContainText("middleware guard patched and ready for verification");
  await expect(preview).toContainText("applying middleware changes");
  const mainContentScroll = await page.getByTestId("detail-main-content").evaluate((element) => ({
    scrollTop: element.scrollTop,
    scrollHeight: element.scrollHeight,
    clientHeight: element.clientHeight,
  }));
  expect(mainContentScroll.scrollTop + mainContentScroll.clientHeight).toBeGreaterThanOrEqual(
    mainContentScroll.scrollHeight - 1,
  );

  await runningCard.click();
  await expect(page).toHaveURL(/[\?&]run=run-live-implement/);
  await expect(page).toHaveURL(/[\?&]modal=transcript/);
  await expect(page.getByTestId("live-modal")).toBeVisible();
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

test("automatically reconciles stale runs when opening a cold workspace", async ({
  page,
}) => {
  await connectFixtureWorkspace(page, "/tmp/muxagent-stale-workspace");
  await expect(page.getByTestId("board-card-task-stale-fixture")).toHaveClass(
    /task-board-card--failed/,
  );
  await openTaskFromBoard(page, "task-stale-fixture");

  const statusBlock = page.getByTestId("detail-task-status");
  await expect(statusBlock).toContainText("Failed");
  await expect(page.getByTestId("detail-run-run-stale-implement")).toContainText("failed");
  await expect(page.getByTestId("failed-pane")).toBeVisible();
  await expect(page.getByTestId("retry-step")).toBeVisible();
  await expect(page.getByTestId("recover-run")).toHaveCount(0);
  await expect(page.getByText("orphaned_after_restart")).toBeVisible();

  await page.getByTestId("detail-run-run-stale-implement").click();
  await expect(page).not.toHaveURL(/[\?&]modal=transcript/);
  await expect(page.getByTestId("transcript-modal")).toHaveCount(0);
});

test("shows a transient toast while stale-run reconciliation is in flight", async ({
  page,
}) => {
  await connectFixtureWorkspace(page);
  await openTaskFromBoard(page, "task-live-fixture");

  await page.evaluate(async () => {
    const [{ useWorkspaceStore }] = await Promise.all([
      import("/src/state/workspace-store.ts"),
    ]);
    const workspaceId = window.location.pathname.match(/\/workspaces\/([^/]+)\//)?.[1];
    if (!workspaceId) {
      throw new Error("Missing workspace id");
    }
    const store = useWorkspaceStore.getState();
    const workspace = store.workspaces.find((entry) => entry.workspace_id === workspaceId);
    if (!workspace) {
      throw new Error("Missing workspace in store");
    }
    store.upsertWorkspace({
      ...workspace,
      actor: {
        ...workspace.actor,
        state: "cold",
      },
    });
    store.beginWorkspaceReconcile(workspaceId);
  });

  const toast = page.getByTestId("detail-stale-reconcile-toast");
  await expect(toast).toBeVisible();
  await expect(toast).toContainText("Checking stale run state");

  await page.evaluate(async () => {
    const [{ useWorkspaceStore }] = await Promise.all([
      import("/src/state/workspace-store.ts"),
    ]);
    const workspaceId = window.location.pathname.match(/\/workspaces\/([^/]+)\//)?.[1];
    if (!workspaceId) {
      throw new Error("Missing workspace id");
    }
    const store = useWorkspaceStore.getState();
    const workspace = store.workspaces.find((entry) => entry.workspace_id === workspaceId);
    if (workspace) {
      store.upsertWorkspace({
        ...workspace,
        actor: {
          ...workspace.actor,
          state: "active",
        },
      });
    }
    store.finishWorkspaceReconcile(workspaceId);
  });

  await expect(toast).toHaveCount(0);
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
  const implementStateBadge = page
    .getByTestId("detail-run-run-sync-implement")
    .locator(".detail-activity-card__state");
  await expect(statusBlock).toContainText("Status");
  await expect(statusBlock).toContainText("Running");
  await expect(page.getByTestId("detail-run-run-sync-implement")).toContainText("running");
  await expect(implementStateBadge).toHaveText("running");

  await triggerWorkspaceTaskReload(page, workspaceId!);
  await expect(page.getByTestId("task-detail-screen")).toBeVisible();

  const refreshedUrl = new URL(page.url());
  expect(refreshedUrl.pathname).toBe(detailPath);

  await expect(statusBlock).toContainText("Done");
  await expect(implementStateBadge).toHaveCount(0);
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
    page.locator(".tasks-panel__workspace-row.is-active .tasks-panel__workspace-label").first(),
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
    .locator(".tasks-panel__workspace-row")
    .filter({ hasText: "muxagent-alt-workspace" })
    .click();
  await expect(
    page.locator(".tasks-panel__workspace-row.is-active .tasks-panel__workspace-label").first(),
  ).toContainText("muxagent-alt-workspace");

  await page.evaluate((pathname) => {
    window.history.pushState({}, "", pathname);
    window.dispatchEvent(new PopStateEvent("popstate"));
  }, firstWorkspaceDetailPath);

  await expect(page).toHaveURL(new RegExp(`${firstWorkspaceDetailPath}$`));
  await expect(page.getByTestId("task-detail-screen")).toBeVisible();
  await expect(
    page.locator(".tasks-panel__workspace-row.is-active .tasks-panel__workspace-label").first(),
  ).toContainText(
    "muxagent-workspace",
  );
});

test("keeps status filters independent from workspace scope and exposes all-workspaces reset", async ({
  page,
}) => {
  await connectFixtureWorkspace(page);

  page.once("dialog", (dialog) => dialog.accept("/tmp/muxagent-alt-workspace"));
  await page.getByTestId("workspace-picker-button").click();
  await expect(allWorkspacesScope(page)).toHaveClass(/is-active/);
  await page.getByTestId("task-view-needs-attention").click();
  await expect(page).toHaveURL(/\/\?view=attention$/);

  await workspaceRow(page, "muxagent-alt-workspace")
    .locator(".tasks-panel__workspace-row")
    .click();
  await expect(page).toHaveURL(/\/workspaces\/[^/]+\/tasks\?view=attention$/);
  await expect(
    page.locator(".tasks-panel__workspace-row.is-active .tasks-panel__workspace-label").first(),
  ).toContainText("muxagent-alt-workspace");
  await expect(allWorkspacesScope(page)).not.toHaveClass(/is-active/);
  await expect(page.getByTestId("task-board")).toContainText("muxagent-alt-workspace");
  await expect(page.getByTestId("task-board")).not.toContainText("muxagent-workspace");

  await allWorkspacesScope(page).click();
  await expect(page).toHaveURL(/\/\?view=attention$/);
  await expect(allWorkspacesScope(page)).toHaveClass(/is-active/);
  await expect(page.locator('[data-testid^="workbench-tab-task-board"]')).toHaveCount(2);
  await expect(page.getByTestId("task-board")).toContainText("muxagent-workspace");
  await expect(page.getByTestId("task-board")).toContainText("muxagent-alt-workspace");
});

test("restores the originating task-surface workspace scope after leaving task detail", async ({
  page,
}) => {
  await connectFixtureWorkspace(page);

  page.once("dialog", (dialog) => dialog.accept("/tmp/muxagent-alt-workspace"));
  await page.getByTestId("workspace-picker-button").click();
  await expect(allWorkspacesScope(page)).toHaveClass(/is-active/);

  const allTasksCard = page
    .locator('[data-testid="board-card-task-live-fixture"]')
    .filter({ hasText: "muxagent-workspace" })
    .first();
  const allTasksLink = allTasksCard.getByTestId("board-card-link-task-live-fixture");
  await allTasksLink.click();
  await expect(page.getByTestId("task-detail-screen")).toBeVisible();
  await expect(
    page.locator(".tasks-panel__workspace-row.is-active .tasks-panel__workspace-label").first(),
  ).toContainText("muxagent-workspace");

  await page.getByTestId("workbench-tab-task-board").getByRole("tab").click();
  await expect(page).toHaveURL(/\/$/);
  await expect(allWorkspacesScope(page)).toHaveClass(/is-active/);

  await allTasksLink.click();
  await expect(page.getByTestId("task-detail-screen")).toBeVisible();
  await page.goBack();
  await expect(page).toHaveURL(/\/$/);
  await expect(allWorkspacesScope(page)).toHaveClass(/is-active/);

  await workspaceRow(page, "muxagent-alt-workspace")
    .locator(".tasks-panel__workspace-row")
    .click();
  await expect(page).toHaveURL(/\/workspaces\/[^/]+\/tasks$/);
  await expect(
    page.locator(".tasks-panel__workspace-row.is-active .tasks-panel__workspace-label").first(),
  ).toContainText("muxagent-alt-workspace");

  await openTaskFromBoard(page, "task-live-fixture");
  await expect(page.getByTestId("task-detail-screen")).toBeVisible();
  await page.goBack();
  await expect(page).toHaveURL(/\/workspaces\/[^/]+\/tasks$/);
  await expect(
    page.locator(".tasks-panel__workspace-row.is-active .tasks-panel__workspace-label").first(),
  ).toContainText("muxagent-alt-workspace");
});

test("renders approval and artifact preview task surfaces", async ({ page }) => {
  await page.setViewportSize({ width: 1200, height: 540 });
  await connectFixtureWorkspace(page);

  await openTaskFromBoard(page, "task-awaiting-pr");
  await expect(page.getByTestId("approval-pane")).toBeVisible();
  await expect(page.getByTestId("task-detail-header-description")).toContainText(
    "Review PR #42",
  );
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
  await expect(artifactModal.getByText("src/styles/detail.css")).toBeVisible();
  await expect(artifactModal.getByText("design.pen")).toBeVisible();
  await expect(artifactModal.locator(".detail-artifact-modal__document a")).toHaveCount(2);
  const expectedArtifactPath =
    "/tmp/muxagent-workspace/.muxagent/tasks/task-live-fixture/artifacts/run-live-plan/plan.md";
  const artifactPathCopy = artifactModal.getByTestId("artifact-path-copy");
  await expect(artifactPathCopy).toBeVisible();
  await expect(artifactPathCopy).toHaveAttribute("title", expectedArtifactPath);
  await page.evaluate(() => {
    const windowWithClipboard = window as Window & { __copiedArtifactPath?: string };
    windowWithClipboard.__copiedArtifactPath = "";
    Object.defineProperty(navigator, "clipboard", {
      configurable: true,
      value: {
        writeText(value: string) {
          windowWithClipboard.__copiedArtifactPath = value;
          return Promise.resolve();
        },
      },
    });
  });
  await artifactPathCopy.click();
  await expect
    .poll(() =>
      page.evaluate(
        () => (window as Window & { __copiedArtifactPath?: string }).__copiedArtifactPath ?? "",
      ),
    )
    .toBe(expectedArtifactPath);
  const artifactLink = artifactModal
    .locator(".detail-artifact-modal__document a")
    .first();
  const artifactHrefAttributes = await artifactModal
    .locator(".detail-artifact-modal__document a")
    .evaluateAll((links) => links.map((link) => link.getAttribute("href")));
  expect(artifactHrefAttributes).toEqual([null, null]);
  const artifactModalUrl = page.url();
  await artifactLink.click();
  expect(page.url()).toBe(artifactModalUrl);
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

test("renders image artifacts with zoom controls and reset behavior", async ({
  page,
}) => {
  await page.setViewportSize({ width: 1400, height: 900 });
  await connectFixtureWorkspace(page);

  await openTaskFromBoard(page, "task-live-fixture");
  await page.getByRole("button", { name: /review-portrait\.svg/i }).click();

  const artifactModal = page.getByTestId("artifact-modal");
  const artifactFrame = artifactModal.locator(".detail-modal-frame--artifact");
  const image = artifactModal.getByTestId("artifact-image-preview");
  await expect(artifactModal).toBeVisible();
  await expect(image).toBeVisible();
  await expect(artifactModal.getByText("420 × 1180")).toBeVisible();
  await expect(artifactModal.getByTestId("artifact-open-externally")).toBeVisible();
  await expect(
    artifactModal.getByTestId("artifact-image-mode-contain"),
  ).toHaveAttribute("aria-pressed", "true");

  const viewport = page.viewportSize();
  expect(viewport).not.toBeNull();
  const modalBounds = await artifactFrame.evaluate((element) => {
    const rect = element.getBoundingClientRect();
    return {
      bottom: rect.bottom,
      centerX: rect.left + rect.width / 2,
      left: rect.left,
      right: rect.right,
      top: rect.top,
    };
  });
  expect(modalBounds.left).toBeGreaterThanOrEqual(12);
  expect(modalBounds.right).toBeLessThanOrEqual(viewport!.width - 12);
  expect(modalBounds.top).toBeGreaterThanOrEqual(12);
  expect(modalBounds.bottom).toBeLessThanOrEqual(viewport!.height - 12);
  expect(Math.abs(modalBounds.centerX - viewport!.width / 2)).toBeLessThan(8);

  const containWidth = await image.evaluate(
    (element) => element.getBoundingClientRect().width,
  );

  await artifactModal.getByTestId("artifact-image-mode-fit-width").click();
  await expect(
    artifactModal.getByTestId("artifact-image-mode-fit-width"),
  ).toHaveAttribute("aria-pressed", "true");
  const fitWidthWidth = await image.evaluate(
    (element) => element.getBoundingClientRect().width,
  );
  expect(fitWidthWidth).toBeGreaterThan(containWidth + 40);

  await artifactModal.getByTestId("artifact-image-mode-actual").click();
  await expect(
    artifactModal.getByTestId("artifact-image-mode-actual"),
  ).toHaveAttribute("aria-pressed", "true");
  const actualWidth = await image.evaluate(
    (element) => element.getBoundingClientRect().width,
  );
  expect(Math.abs(actualWidth - fitWidthWidth)).toBeLessThan(8);

  await artifactModal.getByTestId("artifact-image-zoom-in").click();
  const zoomedWidth = await image.evaluate(
    (element) => element.getBoundingClientRect().width,
  );
  expect(zoomedWidth).toBeGreaterThan(actualWidth + 40);

  await artifactModal.getByTestId("artifact-image-zoom-out").click();
  const zoomedOutWidth = await image.evaluate(
    (element) => element.getBoundingClientRect().width,
  );
  expect(zoomedOutWidth).toBeLessThan(zoomedWidth);

  await page.getByRole("button", { name: "Close detail" }).click();
  await expect(artifactModal).toHaveCount(0);

  await page.getByRole("button", { name: /review-portrait\.svg/i }).click();
  const reopenedModal = page.getByTestId("artifact-modal");
  const reopenedImage = reopenedModal.getByTestId("artifact-image-preview");
  await expect(reopenedModal.getByTestId("artifact-image-mode-contain")).toHaveAttribute(
    "aria-pressed",
    "true",
  );
  const reopenedWidth = await reopenedImage.evaluate(
    (element) => element.getBoundingClientRect().width,
  );
  expect(Math.abs(reopenedWidth - containWidth)).toBeLessThan(8);
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

  await page.goBack();
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
  await expect(retryStep.locator(".button__icon--leading svg")).toHaveCount(1);
  const retryStepStyles = await retryStep.evaluate((element) => {
    const styles = getComputedStyle(element);
    return {
      backgroundColor: styles.backgroundColor,
      borderRadius: styles.borderRadius,
    };
  });
  expect(retryStepStyles.backgroundColor).toBe("rgb(251, 248, 246)");
  expect(retryStepStyles.borderRadius).toBe("0px");

  await page.goBack();
  await expect(page).toHaveURL(/\/$/);
  await openTaskFromBoard(page, "task-done-login");
  await expect(page.getByTestId("complete-pane")).toBeVisible();
  await expect(page.locator('[data-testid="detail-activity"] [data-testid="complete-pane"]')).toHaveCount(
    0,
  );
  await expect(page.getByTestId("complete-pane")).toHaveAttribute(
    "data-follow-up-state",
    "refine",
  );
  await expect(page.getByTestId("follow-up-description")).toBeVisible();
  await expect(page.getByTestId("follow-up-send")).toBeVisible();
  await expect(page.locator(".detail-follow-up-rail__divider")).toBeVisible();
  const followUpFrameStyles = await page
    .locator(".detail-follow-up-rail__box")
    .evaluate((element) => {
      const boxStyles = getComputedStyle(element);
      const surface = element.querySelector(".image-composer__surface");
      const surfaceStyles = surface ? getComputedStyle(surface) : undefined;
      return {
        boxShadow: boxStyles.boxShadow,
        surfaceBackgroundColor: surfaceStyles?.backgroundColor,
      };
    });
  expect(followUpFrameStyles.boxShadow).toContain("rgb(209, 200, 194)");
  expect(followUpFrameStyles.boxShadow).toContain("inset");
  expect(followUpFrameStyles.surfaceBackgroundColor).toBe("rgba(0, 0, 0, 0)");
  const modeTrigger = page.getByTestId("follow-up-mode-trigger");
  await expect(modeTrigger).toContainText("Continue here");
  await modeTrigger.click();
  await expect(page.getByTestId("follow-up-mode-popup")).toBeVisible();
  await expect(page.getByTestId("follow-up-mode-option-fork_head")).toContainText(
    "Fork from HEAD",
  );
  await expect(page.getByTestId("follow-up-mode-option-fork_with_changes")).toContainText(
    "Fork with changes",
  );
  await page.keyboard.press("Escape");
  await expect(page.getByTestId("follow-up-mode-popup")).toHaveCount(0);
  await expect(page.getByTestId("follow-up-config-trigger")).toContainText("default");
  await expect(
    page
      .getByTestId("detail-run-run-login-implement")
      .locator(".detail-activity-card__state"),
  ).toHaveCount(0);
  await expect(page.getByTestId("detail-run-summary-run-login-implement")).toContainText(
    "Patched the login guard to preserve the authenticated session cookie",
  );
  await expect(page.getByTestId("detail-run-summary-run-login-implement")).toContainText(
    "login-fix.md",
  );
  await page.getByTestId("detail-run-run-login-implement").click();
  await expect(page.getByTestId("transcript-modal")).toBeVisible();
  await expect(page.getByTestId("detail-run-history-source")).toContainText(
    "provider transcript",
  );
  await expect(page.getByTestId("detail-run-runtime")).toContainText("Codex");
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
  const modeTrigger = page.getByTestId("follow-up-mode-trigger");
  const modePopup = page.getByTestId("follow-up-mode-popup");
  const sendButton = page.getByTestId("follow-up-send");

  await expect(completePane).toBeVisible();
  await expect(completePane).toHaveAttribute("data-follow-up-state", "refine");
  await expect(configTrigger).toContainText("default");
  await expect(modeTrigger).toContainText("Continue here");
  await expect(sendButton).toBeVisible();

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
  await modeTrigger.click();
  await expect(modePopup).toBeVisible();
  await page.getByTestId("follow-up-mode-option-fork_with_changes").click();
  await expect(modePopup).toHaveCount(0);
  await expect(modeTrigger).toContainText("Fork with changes");
  await expect(page.getByTestId("follow-up-dirty-hint")).toContainText("3 uncommitted");

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
  await expect(page.getByTestId("follow-up-image-composer-file-input")).toHaveCount(0);
  await pasteTinyPngInto(page, "follow-up-description");
  await expect(page.getByTestId("follow-up-image-composer-attachments")).toBeVisible();
  await expect(page.getByTestId("follow-up-image-composer-attachment").locator("img")).toBeVisible();
  await sendButton.click();

  await expect
    .poll(() => new URL(page.url()).pathname, { timeout: 10_000 })
    .not.toBe(previousPath);
  await expect(page.locator(".detail-main-header__prompt")).not.toHaveAttribute(
    "data-no-window-drag",
    "true",
  );
  await expect(page.locator(".detail-main-header__prompt-body")).toHaveAttribute(
    "data-no-window-drag",
    "true",
  );
  await expect(page.locator(".detail-main-header__prompt-text")).toContainText(description);
  await expect(page.locator(".detail-main-header__prompt-text")).toContainText(secondLine);
  await expect(page.getByTestId("detail-task-config")).toContainText("quick");
  await expect(page.getByText("follow-up-mode-fork_with_changes.md")).toBeVisible();
});

test("renders the blocked task surface", async ({ page }) => {
  await connectFixtureWorkspace(page);

  await openTaskFromBoard(page, "task-blocked-db");
  const continueButton = page.getByTestId("continue-blocked");
  await expect(continueButton).toBeVisible();
  const blockedPane = continueButton.locator("xpath=ancestor::section[1]");
  await expect(blockedPane).toContainText("Waiting for migration window");
  await expect(blockedPane).not.toContainText("Task paused at");
  const blockedPaneStyles = await blockedPane.evaluate((element) => {
    const styles = getComputedStyle(element);
    return {
      backgroundColor: styles.backgroundColor,
    };
  });
  expect(blockedPaneStyles.backgroundColor).toBe("rgba(0, 0, 0, 0)");
  await expect(continueButton).toBeVisible();
  await expect(continueButton.locator(".button__icon--leading svg")).toHaveCount(1);
  await expect(continueButton.locator(".button__icon--trailing")).toHaveCount(0);
  const continueButtonChildOrder = await continueButton.evaluate((element) => {
    return Array.from(element.children).map((child) =>
      child instanceof HTMLElement ? child.className : child.tagName.toLowerCase(),
    );
  });
  expect(continueButtonChildOrder[0]).toContain("button__icon--leading");
  expect(continueButtonChildOrder[1]).toContain("button__label");
  await expect(continueButton).toHaveClass(/button--ghost/);
  await expect(continueButton).toHaveClass(/button--sm/);
  const continueButtonStyles = await continueButton.evaluate((element) => {
    const styles = getComputedStyle(element);
    const rect = element.getBoundingClientRect();
    return {
      backgroundColor: styles.backgroundColor,
      color: styles.color,
      borderRadius: styles.borderRadius,
      fontSize: styles.fontSize,
      gap: styles.gap,
      paddingLeft: styles.paddingLeft,
      paddingTop: styles.paddingTop,
      width: Math.round(rect.width),
      height: Math.round(rect.height),
    };
  });
  expect(continueButtonStyles.backgroundColor).toBe("rgb(251, 248, 246)");
  expect(continueButtonStyles.color).toBe("rgb(95, 85, 80)");
  expect(continueButtonStyles.borderRadius).toBe("4px");
  expect(continueButtonStyles.fontSize).toBe("13px");
  expect(continueButtonStyles.gap).toBe("6px");
  expect(continueButtonStyles.paddingLeft).toBe("14px");
  expect(continueButtonStyles.paddingTop).toBe("6px");
  expect(continueButtonStyles.width).toBeGreaterThanOrEqual(101);
  expect(continueButtonStyles.width).toBeLessThanOrEqual(106);
  expect(continueButtonStyles.height).toBeGreaterThanOrEqual(28);
  expect(continueButtonStyles.height).toBeLessThanOrEqual(31);
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
    .locator(".tasks-panel__workspace-row")
    .filter({ hasText: "muxagent-workspace" })
    .click();
  await expect(page).toHaveURL(/\/workspaces\/[^/]+\/tasks$/);
  await expect(page.getByTestId("task-board")).toBeVisible();

  await allWorkspacesScope(page).click();
  await expect(page).toHaveURL(/\/$/);
  await expect(allWorkspacesScope(page)).toHaveClass(/is-active/);
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

test("keeps board lane headers aligned when neighboring columns overflow and lineage cards expand", async ({
  page,
}) => {
  await page.setViewportSize({ width: 1200, height: 540 });
  await connectFixtureWorkspace(page);
  await page.getByTestId("board-card-lineage-toggle-task-follow-up-history-sibling").click();
  await page.getByTestId("board-card-lineage-toggle-task-follow-up-history-fixture").click();

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

  const overflowingLabels = overflowingLanes.map((lane) => lane.label);
  expect(overflowingLabels).toContain("Needs Attention");
  expect(overflowingLabels).toContain("Completed");
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
