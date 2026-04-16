import { existsSync } from "node:fs";
import { mkdir, mkdtemp, rm } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import net from "node:net";
import { spawn, type ChildProcess } from "node:child_process";
import { fileURLToPath } from "node:url";
import { expect, type Page } from "@playwright/test";

const currentFile = fileURLToPath(import.meta.url);
const desktopRoot = path.resolve(path.dirname(currentFile), "../../..");

function isCliSourceRoot(candidate: string): boolean {
  return (
    existsSync(path.join(candidate, "go.mod")) &&
    existsSync(path.join(candidate, "cmd", "muxagent"))
  );
}

function resolveCliRoot(): string {
  const cliRootOverride = process.env.MUXAGENT_CLI_ROOT?.trim();
  const candidates = [
    cliRootOverride,
    path.resolve(desktopRoot, "../cli"),
    path.resolve(desktopRoot, "../muxagent/cli"),
    path.resolve(desktopRoot, "../muxagent-cli"),
  ].filter((candidate): candidate is string => Boolean(candidate));

  for (const candidate of candidates) {
    if (isCliSourceRoot(candidate)) {
      return candidate;
    }
  }

  throw new Error(
    `Unable to locate muxagent CLI source from ${desktopRoot}. ` +
      "Set MUXAGENT_CLI_ROOT or use either the monorepo layout (`../cli`) " +
      "or the legacy sibling checkout layout (`../muxagent-cli`).",
  );
}

const cliRoot = resolveCliRoot();

async function runCommand(
  command: string,
  args: string[],
  options: {
    cwd: string;
    env?: NodeJS.ProcessEnv;
    input?: string;
  },
): Promise<void> {
  await new Promise<void>((resolve, reject) => {
    const child = spawn(command, args, {
      cwd: options.cwd,
      env: options.env,
      stdio: [options.input ? "pipe" : "ignore", "pipe", "pipe"],
    });

    let stderr = "";
    child.stderr.on("data", (chunk) => {
      stderr += chunk.toString();
    });
    child.stdout.on("data", () => {
      // Ignore build stdout unless the command fails.
    });
    if (options.input && child.stdin) {
      child.stdin.write(options.input);
      child.stdin.end();
    }
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

async function getAvailablePort(): Promise<number> {
  return new Promise<number>((resolve, reject) => {
    const server = net.createServer();
    server.unref();
    server.on("error", reject);
    server.listen(0, "127.0.0.1", () => {
      const address = server.address();
      if (!address || typeof address === "string") {
        server.close(() => reject(new Error("Failed to allocate a TCP port")));
        return;
      }
      const { port } = address;
      server.close((error) => {
        if (error) {
          reject(error);
          return;
        }
        resolve(port);
      });
    });
  });
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

export type SpawnedDesktopServerContext = {
  url: string;
  workDir: string;
  altWorkDir: string;
  appServerStateDir: string;
  taskConfigRootDir: string;
  stop: () => Promise<void>;
  seedWorkspace: (
    kind:
      | "awaiting-review"
      | "completed-review"
      | "completed-repo-follow-up"
      | "completed-worktree-follow-up"
      | "failed-retry"
      | "blocked-continue"
      | "stale-recover",
  ) => Promise<{ taskId: string; description: string; executionDir: string }>;
};

export async function withSpawnedDesktopServer(
  run: (context: SpawnedDesktopServerContext) => Promise<void>,
) {
  const tempRoot = await mkdtemp(path.join(os.tmpdir(), "muxagent-desktop-spawn-"));
  const appServerStateDir = path.join(tempRoot, "appserver-state");
  const taskConfigRootDir = path.join(tempRoot, "taskconfig-root");
  const workDir = path.join(tempRoot, "workspace");
  const altWorkDir = path.join(tempRoot, "workspace-alt");
  const cliBinary = path.join(tempRoot, "muxagent-test");
  const workspaceSeedBinary = path.join(tempRoot, "muxagent-workspace-seed");
  const webPort = String(await getAvailablePort());
  const bridgePort = String(await getAvailablePort());

  await mkdir(appServerStateDir, { recursive: true });
  await mkdir(taskConfigRootDir, { recursive: true });
  await mkdir(workDir, { recursive: true });
  await mkdir(altWorkDir, { recursive: true });
  await runCommand("go", ["build", "-o", cliBinary, "./cmd/muxagent"], {
    cwd: cliRoot,
    env: process.env,
  });
  await runCommand(
    "go",
    ["build", "-o", workspaceSeedBinary, "./internal/testsupport/workspaceseed"],
    {
      cwd: cliRoot,
      env: process.env,
    },
  );

  const server = spawn("npm", ["run", "dev:web"], {
    cwd: desktopRoot,
    env: {
      ...process.env,
      MUXAGENT_BRIDGE_MODE: "spawn",
      MUXAGENT_CLI_PATH: cliBinary,
      MUXAGENT_APP_SERVER_STATE_DIR: appServerStateDir,
      MUXAGENT_TASKCONFIG_ROOT: taskConfigRootDir,
      MUXAGENT_WEB_PORT: webPort,
      MUXAGENT_BRIDGE_PORT: bridgePort,
      HOME: tempRoot,
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
      altWorkDir,
      appServerStateDir,
      taskConfigRootDir,
      stop: async () => {
        await stopProcess(server);
      },
      seedWorkspace: async (kind) => {
        const result = await runCommandAndCapture(
          workspaceSeedBinary,
          ["--workdir", workDir, "--kind", kind],
          {
            cwd: desktopRoot,
            env: {
              ...process.env,
              HOME: tempRoot,
            },
          },
        );
        const parsed = JSON.parse(result.stdout) as {
          task_id: string;
          description: string;
          execution_dir: string;
        };
        return {
          taskId: parsed.task_id,
          description: parsed.description,
          executionDir: parsed.execution_dir,
        };
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
    await rm(tempRoot, {
      recursive: true,
      force: true,
      maxRetries: 10,
      retryDelay: 100,
    });
  }
}

export async function addWorkspace(page: Page, path: string) {
  await expect(page.getByTestId("workspace-picker-button")).toBeEnabled({
    timeout: 30_000,
  });
  page.once("dialog", (dialog) => dialog.accept(path));
  await page.getByTestId("workspace-picker-button").click();
}

export async function startTask(page: Page, description: string) {
  await page.getByTestId("open-new-task").click();
  await expect(page.getByTestId("new-task-modal")).toBeVisible();
  await page.getByTestId("new-task-description").fill(description);
  await expect(page.getByTestId("new-task-submit")).toBeEnabled();
  await page.getByTestId("new-task-submit").click();
  await expect(page.getByTestId("new-task-modal")).toBeHidden();
}

async function runCommandAndCapture(
  command: string,
  args: string[],
  options: {
    cwd: string;
    env?: NodeJS.ProcessEnv;
    input?: string;
  },
): Promise<{ stdout: string; stderr: string }> {
  return new Promise((resolve, reject) => {
    const child = spawn(command, args, {
      cwd: options.cwd,
      env: options.env,
      stdio: [options.input ? "pipe" : "ignore", "pipe", "pipe"],
    });

    let stdout = "";
    let stderr = "";
    child.stdout.on("data", (chunk) => {
      stdout += chunk.toString();
    });
    child.stderr.on("data", (chunk) => {
      stderr += chunk.toString();
    });
    if (options.input && child.stdin) {
      child.stdin.write(options.input);
      child.stdin.end();
    }
    child.once("error", reject);
    child.once("exit", (code) => {
      if (code === 0) {
        resolve({ stdout, stderr });
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
