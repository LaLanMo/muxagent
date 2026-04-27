import { spawn } from "node:child_process";
import { mkdtemp, rm } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { expect, test } from "@playwright/test";
import {
  addWorkspace,
  withSpawnedDesktopServer,
} from "../support/spawned-backend";

const currentFile = fileURLToPath(import.meta.url);
const desktopRoot = path.resolve(path.dirname(currentFile), "../../..");
const cliRoot = process.env.MUXAGENT_CLI_ROOT?.trim() || path.resolve(desktopRoot, "../cli");

async function runCommand(
  command: string,
  args: string[],
  options: {
    cwd: string;
    env?: NodeJS.ProcessEnv;
  },
): Promise<void> {
  await new Promise<void>((resolve, reject) => {
    const child = spawn(command, args, {
      cwd: options.cwd,
      env: options.env,
      stdio: ["ignore", "pipe", "pipe"],
    });

    let stderr = "";
    child.stderr.on("data", (chunk) => {
      stderr += chunk.toString();
    });
    child.once("error", reject);
    child.once("exit", (code) => {
      if (code === 0) {
        resolve();
        return;
      }
      reject(
        new Error(
          `${command} ${args.join(" ")} failed with code ${code ?? "null"}${
            stderr ? `\n${stderr}` : ""
          }`,
        ),
      );
    });
  });
}

async function buildMockAgent(): Promise<{
  bin: string;
  cleanup: () => Promise<void>;
}> {
  const tempRoot = await mkdtemp(path.join(os.tmpdir(), "muxagent-chat-real-"));
  const bin = path.join(tempRoot, "mockagent");
  await runCommand("go", ["build", "-o", bin, "./internal/runtime/acp/testdata/mockagent"], {
    cwd: cliRoot,
    env: process.env,
  });
  return {
    bin,
    cleanup: () => rm(tempRoot, { recursive: true, force: true }),
  };
}

test("creates, prompts, and reloads a real local agentchat session", async ({
  page,
}) => {
  test.slow();

  const mockAgent = await buildMockAgent();
  const previousCodexCommand = process.env.MUXAGENT_RUNTIMES_CODEX_COMMAND;
  process.env.MUXAGENT_RUNTIMES_CODEX_COMMAND = mockAgent.bin;

  try {
    await withSpawnedDesktopServer(async ({ url, workDir }) => {
      await page.goto(`${url}/`);
      await addWorkspace(page, workDir);
      await expect(page.getByTestId("board-empty-state")).toContainText(
        "No tasks yet",
      );

      await page.getByRole("button", { name: /^Chat$/ }).click();
      await page
        .getByTestId("chat-panel")
        .getByRole("button", { name: /^New chat$/ })
        .last()
        .click();
      await expect(page.getByTestId("chat-screen-new")).toBeVisible();
      await expect(page.getByRole("button", { name: /^Runtime: Codex$/ })).toBeEnabled({
        timeout: 30_000,
      });

      await page.getByPlaceholder("/path/to/workspace").fill(workDir);
      await page.getByLabel("Message").fill("hello real agentchat smoke");
      await page.getByRole("button", { name: "Send" }).click();

      await expect(page).toHaveURL(/\/chat\/test-session-001$/);
      await expect(page.getByTestId("chat-transcript")).toContainText(
        "hello real agentchat smoke",
      );
      await expect(page.getByTestId("chat-transcript")).toContainText(
        "I'll help you.",
      );
      await expect(page.getByTestId("chat-transcript")).toContainText("Done!");

      await page.reload();
      await expect(page).toHaveURL(/\/chat\/test-session-001$/);
      await expect(page.getByTestId("chat-transcript")).toContainText(
        "Hi there",
        { timeout: 30_000 },
      );
      await expect(page.getByTestId("chat-transcript")).toContainText(
        "History: replayed message",
      );
    });
  } finally {
    if (previousCodexCommand == null) {
      delete process.env.MUXAGENT_RUNTIMES_CODEX_COMMAND;
    } else {
      process.env.MUXAGENT_RUNTIMES_CODEX_COMMAND = previousCodexCommand;
    }
    await mockAgent.cleanup();
  }
});
