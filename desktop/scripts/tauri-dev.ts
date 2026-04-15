import { spawn } from "node:child_process";
import { mkdirSync, realpathSync } from "node:fs";
import path from "node:path";

const desktopRoot = realpathSync(process.cwd());
const defaultAppServerStateDir = path.join(
  desktopRoot,
  ".muxagent-dev",
  "appserver",
);

function resolveAppServerStateDir(): string {
  const override = process.env.MUXAGENT_APP_SERVER_STATE_DIR?.trim();
  return override && override.length > 0
    ? path.resolve(override)
    : defaultAppServerStateDir;
}

function main(): void {
  const appServerStateDir = resolveAppServerStateDir();
  mkdirSync(appServerStateDir, { recursive: true });

  const pnpmCommand = process.platform === "win32" ? "pnpm.cmd" : "pnpm";
  const child = spawn(pnpmCommand, ["exec", "tauri", "dev", ...process.argv.slice(2)], {
    stdio: "inherit",
    env: {
      ...process.env,
      MUXAGENT_APP_SERVER_STATE_DIR: appServerStateDir,
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
