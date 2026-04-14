import { mkdir } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { chromium } from '@playwright/test';

const currentFile = fileURLToPath(import.meta.url);
const repoRoot = path.resolve(path.dirname(currentFile), '..');
const outputPath =
  process.env.MUXAGENT_CONFIG_SHOT_PATH?.trim() ||
  path.join(repoRoot, 'artifacts', 'config-editor-current.png');

await mkdir(path.dirname(outputPath), { recursive: true });

const browser = await chromium.launch({ headless: true });
const page = await browser.newPage({ viewport: { width: 1440, height: 960 } });
await page.goto('http://127.0.0.1:4273/');
page.once('dialog', dialog => dialog.accept('/tmp/muxagent-workspace'));
await page.getByTestId('workspace-picker-button').click();
await page.getByRole('link', { name: /^Configs$/i }).click();
await page.getByTestId('config-card-default').getByRole('button', { name: /^Edit$/i }).click();
await page.screenshot({ path: outputPath, fullPage: true });
await browser.close();
