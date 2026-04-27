import { expect, test } from "@playwright/test";
import { skipOnboarding } from "./_helpers";

test.beforeEach(async ({ page }) => {
  await skipOnboarding(page);
});

test("loads, creates, and prompts local agentchat sessions", async ({ page }) => {
  await page.goto("/chat/fixture-chat-1");

  await expect(page.getByTestId("chat-transcript")).toContainText(
    "Make the desktop chat feel closer to the Pencil mock.",
  );
  await expect(page.getByTestId("chat-transcript")).toContainText(
    "I tightened the shell structure",
  );

  await page
    .getByLabel("Message")
    .fill("Make the desktop chat feel closer to the Pencil mock.");
  await page.getByRole("button", { name: "Send" }).click();
  await expect(page.getByTestId("chat-transcript")).toContainText(
    "Fixture reply: Make the desktop chat feel closer to the Pencil mock.",
  );

  await page.goto("/chat");

  await expect(page.getByTestId("chat-screen-new")).toBeVisible();
  await page.getByPlaceholder("/path/to/workspace").fill("/tmp/workspace");
  await page.getByLabel("Message").fill("hello fixture");
  await page.getByRole("button", { name: "Send" }).click();

  await expect(page).toHaveURL(/\/chat\/fixture-chat-/);
  await expect(page.getByTestId("chat-transcript")).toContainText("hello fixture");
  await expect(page.getByTestId("chat-transcript")).toContainText(
    "Fixture reply: hello fixture",
  );
});
