import { mkdir, mkdtemp, rm } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { spawn, type ChildProcess } from "node:child_process";
import { fileURLToPath } from "node:url";
import { expect, test } from "@playwright/test";

const currentFile = fileURLToPath(import.meta.url);
const desktopRoot = path.resolve(path.dirname(currentFile), "../..");
const cliRoot = path.resolve(desktopRoot, "../muxagent-cli");

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
    child.stdout.on("data", () => {
      // Ignore build stdout unless the command fails.
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

async function waitForUrl(url: string): Promise<void> {
  const deadline = Date.now() + 30_000;
  while (Date.now() < deadline) {
    try {
      const response = await fetch(url);
      if (response.ok) {
        return;
      }
    } catch {
      // Keep polling until the server is ready.
    }
    await new Promise((resolve) => setTimeout(resolve, 100));
  }
  throw new Error(`Timed out waiting for ${url}`);
}

async function stopProcess(process: ChildProcess): Promise<void> {
  if (process.exitCode != null || process.signalCode != null) {
    return;
  }
  await new Promise<void>((resolve) => {
    process.once("exit", () => resolve());
    process.kill("SIGTERM");
    setTimeout(() => {
      if (process.exitCode == null && process.signalCode == null) {
        process.kill("SIGKILL");
      }
    }, 2_000);
  });
}

async function withSpawnedDesktopServer(
  run: (context: {
    url: string;
    workDir: string;
    stop: () => Promise<void>;
  }) => Promise<void>,
) {
  const tempRoot = await mkdtemp(path.join(os.tmpdir(), "muxagent-desktop-spawn-"));
  const homeDir = path.join(tempRoot, "home");
  const workDir = path.join(tempRoot, "workspace");
  const cliBinary = path.join(tempRoot, "muxagent-test");
  const webPort = "4273";
  const bridgePort = "4274";

  await mkdir(homeDir, { recursive: true });
  await mkdir(workDir, { recursive: true });
  await runCommand("go", ["build", "-o", cliBinary, "./cmd/muxagent"], {
    cwd: cliRoot,
    env: process.env,
  });

  const server = spawn("npm", ["run", "dev:web"], {
    cwd: desktopRoot,
    env: {
      ...process.env,
      HOME: homeDir,
      MUXAGENT_BRIDGE_MODE: "spawn",
      MUXAGENT_CLI_PATH: cliBinary,
      MUXAGENT_WEB_PORT: webPort,
      MUXAGENT_BRIDGE_PORT: bridgePort,
    },
    stdio: ["ignore", "pipe", "pipe"],
  });

  let serverStderr = "";
  server.stderr.on("data", (chunk) => {
    serverStderr += chunk.toString();
  });

  try {
    const url = `http://127.0.0.1:${webPort}`;
    await waitForUrl(url);
    await run({
      url,
      workDir,
      stop: async () => {
        await stopProcess(server);
      },
    });
  } catch (error) {
    throw new Error(
      `${error instanceof Error ? error.message : String(error)}${
        serverStderr ? `\nspawn dev:web stderr:\n${serverStderr}` : ""
      }`,
    );
  } finally {
    await stopProcess(server);
    await rm(tempRoot, { recursive: true, force: true });
  }
}

test("connects to a real spawned muxagent app-server", async ({ page }) => {
  test.slow();

  await withSpawnedDesktopServer(async ({ url, workDir }) => {
    await page.goto(`${url}/`);
    await expect(page.getByTestId("workspace-picker-button")).toBeEnabled();
    page.once("dialog", (dialog) => dialog.accept(workDir));
    await page.getByTestId("workspace-picker-button").click();

    await expect(page).toHaveURL(`${url}/`);
    await expect(page.getByTestId("board-empty-state")).toContainText(
      "No tasks yet",
    );
  });
});

test("returns to the connect screen when the backend dies after connect", async ({
  page,
}) => {
  test.slow();

  await withSpawnedDesktopServer(async ({ url, workDir, stop }) => {
    await page.goto(`${url}/`);
    await expect(page.getByTestId("workspace-picker-button")).toBeEnabled();
    page.once("dialog", (dialog) => dialog.accept(workDir));
    await page.getByTestId("workspace-picker-button").click();

    await expect(page).toHaveURL(`${url}/`);
    await stop();

    await expect(page).toHaveURL(`${url}/`);
    await expect(page.getByTestId("shell-error")).toContainText(
      "Bridge transport closed",
    );
  });
});
