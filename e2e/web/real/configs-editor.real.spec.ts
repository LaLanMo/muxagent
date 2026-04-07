import { readFile } from "node:fs/promises";
import path from "node:path";
import { expect, test } from "@playwright/test";
import { withSpawnedDesktopServer } from "../support/spawned-backend";

test("edits and resets a built-in config through the real backend using an isolated taskconfig root", async ({
  page,
}) => {
  test.slow();

  await withSpawnedDesktopServer(async ({ url, taskConfigRootDir }) => {
    await page.goto(`${url}/`);
    await expect(page.getByTestId("workspace-picker-button")).toBeEnabled({
      timeout: 30_000,
    });

    await page.getByRole("link", { name: /^Configs$/i }).click();
    await expect(page.getByTestId("configs-screen")).toBeVisible();

    await page
      .getByTestId("config-card-default")
      .getByRole("button", { name: /^Edit$/i })
      .click();

    await expect(page).toHaveURL(/\/configs\/default$/, {
      timeout: 30_000,
    });
    await expect(page.getByTestId("config-editor-screen")).toBeVisible({
      timeout: 30_000,
    });
    await expect(page.getByTestId("config-alias-input")).toHaveValue(
      "default",
      {
        timeout: 30_000,
      },
    );
    const initialDescription = await page
      .getByTestId("config-description-input")
      .inputValue();
    const initialRuntime = await page
      .getByTestId("config-runtime-select")
      .inputValue();

    await page
      .getByTestId("config-description-input")
      .fill("Real backend builtin config save coverage.");
    await page
      .getByTestId("config-runtime-select")
      .selectOption("claude-code");
    const builtinPromptPath = path.join(
      taskConfigRootDir,
      "taskconfigs",
      "default",
      "prompts",
      "draft_plan.md",
    );
    const builtinPrompt = await readFile(builtinPromptPath, "utf8");
    await expect(page.getByTestId("config-prompt-editor")).toHaveValue(
      builtinPrompt,
    );
    await page
      .getByTestId("config-prompt-editor")
      .fill("Draft the plan with a strong checklist for launch blockers.");
    await page.getByTestId("config-prompt-save-button").click();
    await expect(page.getByTestId("config-prompt-save-button")).toBeDisabled({
      timeout: 10_000,
    });

    await expect(page.getByTestId("config-save-button")).toBeEnabled({
      timeout: 10_000,
    });
    await page.getByTestId("config-save-button").click();
    await expect(page.getByTestId("config-save-button")).toBeDisabled({
      timeout: 10_000,
    });

    await page.getByRole("link", { name: /^Configs$/i }).click();
    const builtinCard = page.getByTestId("config-card-default");
    await expect(builtinCard).toBeVisible();
    await expect(builtinCard).toContainText("Claude Code");
    await builtinCard.locator(".config-list-card__surface").click();

    await expect(page).toHaveURL(/\/configs\/default$/);
    await expect(page.getByTestId("config-editor-screen")).toBeVisible();
    await expect(page.getByTestId("config-alias-input")).toHaveValue(
      "default",
    );
    await expect(page.getByTestId("config-description-input")).toHaveValue(
      "Real backend builtin config save coverage.",
    );
    await expect(page.getByTestId("config-runtime-select")).toHaveValue(
      "claude-code",
    );
    await expect(page.getByTestId("config-prompt-editor")).toHaveValue(
      "Draft the plan with a strong checklist for launch blockers.",
    );

    const configPath = path.join(
      taskConfigRootDir,
      "taskconfigs",
      "default",
      "config.yaml",
    );
    const promptPath = path.join(
      taskConfigRootDir,
      "taskconfigs",
      "default",
      "prompts",
      "draft_plan.md",
    );

    const configYaml = await readFile(configPath, "utf8");
    expect(configYaml).toContain("Real backend builtin config save coverage.");
    expect(configYaml).toContain("runtime: claude-code");
    expect(await readFile(promptPath, "utf8")).toContain(
      "Draft the plan with a strong checklist for launch blockers.",
    );

    await page.getByTestId("config-reset-button").click();
    await page.getByTestId("confirm-dialog-submit").click();
    await expect(page.getByTestId("config-description-input")).toHaveValue(
      initialDescription,
    );
    await expect(page.getByTestId("config-runtime-select")).toHaveValue(
      initialRuntime,
    );
    await expect(page.getByTestId("config-prompt-editor")).toHaveValue(
      builtinPrompt,
    );
    expect(await readFile(configPath, "utf8")).not.toContain(
      "Real backend builtin config save coverage.",
    );
    expect(await readFile(promptPath, "utf8")).toBe(builtinPrompt);
  });
});
