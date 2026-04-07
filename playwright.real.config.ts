import { defineConfig, devices } from "@playwright/test";

export default defineConfig({
  testDir: "./e2e/web/real",
  timeout: 30_000,
  workers: 1,
  fullyParallel: false,
  retries: 0,
  use: {
    trace: "retain-on-failure",
  },
  projects: [
    {
      name: "chromium",
      use: { ...devices["Desktop Chrome"] },
    },
  ],
});
