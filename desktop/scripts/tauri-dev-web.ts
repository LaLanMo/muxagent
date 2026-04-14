import { spawn, type ChildProcess } from "node:child_process";
import { createConnection } from "node:net";

const host = process.env.MUXAGENT_WEB_HOST ?? "127.0.0.1";
const webPort = Number(process.env.MUXAGENT_WEB_PORT ?? "4173");
const devUrl = `http://${host}:${webPort}`;

let child: ChildProcess | null = null;

async function isMuxAgentDevServerRunning(): Promise<boolean> {
  try {
    const response = await fetch(devUrl, {
      headers: {
        accept: "text/html",
      },
    });
    if (!response.ok) {
      return false;
    }

    const html = await response.text();
    return (
      html.includes("<title>MuxAgent</title>") &&
      html.includes('id="root"') &&
      html.includes('/src/main.tsx')
    );
  } catch {
    return false;
  }
}

async function isPortOpen(): Promise<boolean> {
  return await new Promise((resolve) => {
    const socket = createConnection({
      host,
      port: webPort,
    });

    const finish = (open: boolean) => {
      socket.removeAllListeners();
      socket.destroy();
      resolve(open);
    };

    socket.setTimeout(750);
    socket.once("connect", () => finish(true));
    socket.once("timeout", () => finish(false));
    socket.once("error", () => finish(false));
  });
}

function keepAlive(): void {
  setInterval(() => {}, 1 << 30);
}

function shutdown(): void {
  if (child && child.exitCode === null && !child.killed) {
    child.kill("SIGTERM");
  }
  process.exit(0);
}

async function main(): Promise<void> {
  if (await isMuxAgentDevServerRunning()) {
    process.stdout.write(`Reusing existing MuxAgent dev server at ${devUrl}\n`);
    keepAlive();
    return;
  }

  if (await isPortOpen()) {
    process.stderr.write(
      `Port ${webPort} is already in use by a non-MuxAgent process. Stop that process and try again.\n`,
    );
    process.exit(1);
  }

  const pnpmCommand = process.platform === "win32" ? "pnpm.cmd" : "pnpm";
  child = spawn(pnpmCommand, ["dev"], {
    stdio: "inherit",
    env: process.env,
  });

  child.once("error", (error) => {
    process.stderr.write(`Failed to start dev server: ${error.message}\n`);
    process.exit(1);
  });

  child.once("exit", (code, signal) => {
    if (signal) {
      process.stderr.write(`Dev server exited from signal ${signal}\n`);
      process.exit(1);
    }
    process.exit(code ?? 0);
  });
}

process.on("SIGINT", shutdown);
process.on("SIGTERM", shutdown);

void main().catch((error) => {
  const message = error instanceof Error ? error.message : String(error);
  process.stderr.write(`${message}\n`);
  process.exit(1);
});
