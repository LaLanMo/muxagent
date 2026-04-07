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

test("edits a built-in config, validates runtime selection, saves, and resets it", async ({
  page,
}) => {
  await connectFixtureWorkspace(page);

  await page.getByRole("link", { name: /^Configs$/i }).click();
  await expect(page.getByTestId("configs-screen")).toBeVisible();
  await expect(page.getByTestId("config-card-default")).toBeVisible();

  await page
    .getByTestId("config-card-default")
    .getByRole("button", { name: /^Edit$/i })
    .click();

  await expect(page.getByTestId("config-editor-screen")).toBeVisible();
  await expect(page.getByTestId("config-alias-input")).toHaveValue("default");
  const initialDescription = await page
    .getByTestId("config-description-input")
    .inputValue();
  const initialRuntime = await page
    .getByTestId("config-runtime-select")
    .inputValue();
  await expect(page.getByTestId("config-prompt-path-input")).toHaveValue(
    "./prompts/draft_plan.md",
  );
  const initialPrompt = await page
    .getByTestId("config-prompt-editor")
    .inputValue();
  await expect(page.getByTestId("config-prompt-editor")).toHaveValue(
    initialPrompt,
  );

  await page
    .getByTestId("config-prompt-editor")
    .fill("Draft the initial plan with a stronger launch checklist.");
  await page.getByTestId("config-prompt-save-button").click();
  await expect(page.getByTestId("config-prompt-save-button")).toBeDisabled();

  await page
    .getByTestId("config-runtime-select")
    .selectOption("missing-runtime");
  await expect(page.getByText("Selected runtime is not configured")).toBeVisible();
  await expect(page.getByTestId("config-save-button")).toBeDisabled();

  await page.getByTestId("config-runtime-select").selectOption("claude");
  await expect(page.getByTestId("config-save-button")).toBeEnabled();

  await page
    .getByTestId("config-description-input")
    .fill("Builtin review loop for web launch tasks.");
  await page.getByTestId("config-save-button").click();
  await expect(page.getByTestId("config-save-button")).toBeDisabled();

  await page.getByRole("link", { name: /^Configs$/i }).click();
  await expect(page.getByTestId("config-card-default")).toBeVisible();
  await expect(page.getByTestId("config-card-default")).toContainText(
    "claude",
  );

  await page.getByTestId("config-card-default").locator(".config-list-card__surface").click();
  await expect(page.getByTestId("config-description-input")).toHaveValue(
    "Builtin review loop for web launch tasks.",
  );
  await expect(page.getByTestId("config-prompt-editor")).toHaveValue(
    "Draft the initial plan with a stronger launch checklist.",
  );

  await page.getByTestId("config-reset-button").click();
  await expect(page.getByTestId("confirm-dialog")).toBeVisible();
  await page.getByTestId("confirm-dialog-submit").click();
  await expect(page.getByTestId("config-description-input")).toHaveValue(initialDescription);
  await expect(page.getByTestId("config-runtime-select")).toHaveValue(initialRuntime);
  await expect(page.getByTestId("config-prompt-editor")).toHaveValue(initialPrompt);
});

test("deletes a customized config from the editor", async ({ page }) => {
  await connectFixtureWorkspace(page);

  await page.getByRole("link", { name: /^Configs$/i }).click();
  await expect(page.getByTestId("configs-screen")).toBeVisible();

  await page
    .getByRole("button", { name: /^\+ New Config$/i })
    .click();

  await expect(page.getByTestId("config-editor-screen")).toBeVisible();
  await expect(page.getByTestId("config-alias-input")).toHaveValue("default-copy");

  await page.getByTestId("config-delete-button").click();
  await expect(page.getByTestId("confirm-dialog")).toBeVisible();
  await page.getByTestId("confirm-dialog-submit").click();

  await expect(page.getByTestId("configs-screen")).toBeVisible();
  await expect(page.getByTestId("config-card-default-copy")).toHaveCount(0);
});
