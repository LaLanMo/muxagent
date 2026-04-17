import { mkdir } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { chromium } from "@playwright/test";

const currentFile = fileURLToPath(import.meta.url);
const repoRoot = path.resolve(path.dirname(currentFile), "..");
const outputDir =
  process.env.MUXAGENT_ONBOARDING_SHOT_DIR?.trim() ||
  path.join(repoRoot, "artifacts", "onboarding");
const baseUrl =
  process.env.MUXAGENT_ONBOARDING_SHOT_URL?.trim() || "http://127.0.0.1:4273";

await mkdir(outputDir, { recursive: true });

const browser = await chromium.launch({ headless: true });
const context = await browser.newContext({ viewport: { width: 1280, height: 900 } });
const page = await context.newPage();

await page.goto(`${baseUrl}/onboarding`);
await page.waitForSelector('[data-testid="onboarding-step-welcome"]');
await page.screenshot({
  path: path.join(outputDir, "step-1-welcome.png"),
  fullPage: true,
});

await page.fill('[data-testid="onboarding-workspace-path"]', "/tmp/muxagent-workspace");
await page.fill('[data-testid="onboarding-workspace-name"]', "muxagent-cli");
await page.click('[data-testid="onboarding-submit-workspace"]');
await page.waitForSelector('[data-testid="onboarding-step-runtime"]', { timeout: 10000 });
await page.screenshot({
  path: path.join(outputDir, "step-2-runtime.png"),
  fullPage: true,
});

await page.click('[data-testid="onboarding-runtime-continue"]');
await page.waitForSelector('[data-testid="onboarding-step-complete"]', { timeout: 10000 });
await page.screenshot({
  path: path.join(outputDir, "step-3-complete.png"),
  fullPage: true,
});

await browser.close();
console.log(`Onboarding screenshots saved to ${outputDir}`);
