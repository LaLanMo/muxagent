import { expect, test } from "@playwright/test";
import { skipOnboarding } from "./_helpers";

test.beforeEach(async ({ page }) => {
  await skipOnboarding(page);
});

test("redirects task deep links back to the root shell when no workspace session exists", async ({
  page,
}) => {
  await page.goto("/workspaces/workspace-missing/tasks/task-live-fixture");

  await expect(page).toHaveURL(/\/$/);
  await expect(page.getByTestId("entry-empty-state")).toBeVisible();
  await expect(page.getByTestId("workspace-picker-button")).toBeVisible();
});
