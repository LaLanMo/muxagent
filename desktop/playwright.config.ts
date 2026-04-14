import { defineConfig, devices } from "@playwright/test";

const webPort = process.env.MUXAGENT_TEST_WEB_PORT ?? "4373";
const bridgePort = process.env.MUXAGENT_TEST_BRIDGE_PORT ?? "4374";

export default defineConfig({
  testDir: "./e2e/web/fixture",
  timeout: 30_000,
  workers: 1,
  fullyParallel: false,
  retries: 0,
  use: {
    baseURL: `http://127.0.0.1:${webPort}`,
    trace: "retain-on-failure",
  },
  webServer: {
    command: "npm run dev:web",
    env: {
      ...process.env,
      MUXAGENT_WEB_PORT: webPort,
      MUXAGENT_BRIDGE_PORT: bridgePort,
    },
    url: `http://127.0.0.1:${webPort}`,
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
