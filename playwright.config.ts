import { defineConfig, devices } from "@playwright/test";

export default defineConfig({
  testDir: "./e2e/web",
  timeout: 30_000,
  workers: 1,
  fullyParallel: false,
  retries: 0,
  use: {
    baseURL: "http://127.0.0.1:4373",
    trace: "on-first-retry",
  },
  webServer: {
    command: "npm run dev:web",
    env: {
      ...process.env,
      MUXAGENT_WEB_PORT: "4373",
      MUXAGENT_BRIDGE_PORT: "4374",
    },
    url: "http://127.0.0.1:4373",
    timeout: 120_000,
    reuseExistingServer: false,
  },
  projects: [
    {
      name: "chromium",
      use: { ...devices["Desktop Chrome"] },
    },
  ],
});
