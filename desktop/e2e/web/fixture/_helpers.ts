import type { Page } from "@playwright/test";

export async function skipOnboarding(page: Page): Promise<void> {
  await page.addInitScript(() => {
    localStorage.setItem(
      "muxagent-desktop:onboarding-completed-at",
      new Date().toISOString(),
    );
  });
}
