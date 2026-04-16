import { spawn } from "node:child_process";
import { mkdirSync, realpathSync } from "node:fs";
import path from "node:path";

const desktopRoot = realpathSync(process.cwd());
const defaultTaskHome = path.join(desktopRoot, ".muxagent-dev");
const defaultAppServerStateDir = path.join(defaultTaskHome, "appserver");

function resolveAppServerStateDir(): string {
  const override = process.env.MUXAGENT_APP_SERVER_STATE_DIR?.trim();
  return override && override.length > 0
    ? path.resolve(override)
    : defaultAppServerStateDir;
}

function resolveTaskHome(): string {
  const override = process.env.MUXAGENT_TASK_HOME?.trim();
  return override && override.length > 0
    ? path.resolve(override)
    : defaultTaskHome;
}

function resolveTaskConfigRootDir(taskHome: string): string {
  const override = process.env.MUXAGENT_TASKCONFIG_ROOT?.trim();
  return override && override.length > 0
    ? path.resolve(override)
    : path.join(taskHome, "taskconfig");
}

function main(): void {
  const appServerStateDir = resolveAppServerStateDir();
  const taskHome = resolveTaskHome();
  const taskConfigRootDir = resolveTaskConfigRootDir(taskHome);
  mkdirSync(taskHome, { recursive: true });
  mkdirSync(appServerStateDir, { recursive: true });
  mkdirSync(taskConfigRootDir, { recursive: true });

  const pnpmCommand = process.platform === "win32" ? "pnpm.cmd" : "pnpm";
  const child = spawn(pnpmCommand, ["exec", "tauri", "dev", ...process.argv.slice(2)], {
    stdio: "inherit",
    env: {
      ...process.env,
      MUXAGENT_APP_SERVER_STATE_DIR: appServerStateDir,
      MUXAGENT_TASK_HOME: taskHome,
      MUXAGENT_TASKCONFIG_ROOT: taskConfigRootDir,
    },
  });

  child.once("error", (error) => {
    process.stderr.write(`Failed to start tauri dev: ${error.message}\n`);
    process.exit(1);
  });

  child.once("exit", (code, signal) => {
    if (signal) {
      process.stderr.write(`tauri dev exited from signal ${signal}\n`);
      process.exit(1);
    }
    process.exit(code ?? 0);
  });
}

main();
