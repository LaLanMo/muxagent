import { spawn, type ChildProcess } from "node:child_process";
import { realpathSync } from "node:fs";
import { createConnection } from "node:net";

const host = process.env.MUXAGENT_WEB_HOST ?? "127.0.0.1";
const webPort = Number(process.env.MUXAGENT_WEB_PORT ?? "4173");
const devUrl = `http://${host}:${webPort}`;
const workspaceRoot = realpathSync(process.cwd());
const workspaceHeader = "x-muxagent-workspace-root";
const initialParentPid = process.ppid;

let child: ChildProcess | null = null;
let shuttingDown = false;
let parentWatch: NodeJS.Timeout | null = null;

type DevServerProbe =
  | { status: "matching" }
  | { status: "foreign"; actualRoot: string | null }
  | { status: "none" };

async function probeMuxAgentDevServer(): Promise<DevServerProbe> {
  try {
    const response = await fetch(devUrl, {
      headers: {
        accept: "text/html",
      },
    });
    if (!response.ok) {
      return { status: "none" };
    }

    const html = await response.text();
    const isMuxAgentHtml =
      html.includes("<title>MuxAgent</title>") &&
      html.includes('id="root"') &&
      html.includes('/src/main.tsx');
    if (!isMuxAgentHtml) {
      return { status: "none" };
    }

    const actualRoot = response.headers.get(workspaceHeader);
    if (actualRoot === workspaceRoot) {
      return { status: "matching" };
    }

    return { status: "foreign", actualRoot };
  } catch {
    return { status: "none" };
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

function startParentWatch(): void {
  parentWatch = setInterval(() => {
    if (process.ppid !== initialParentPid) {
      shutdown();
      return;
    }

    try {
      process.kill(initialParentPid, 0);
    } catch {
      shutdown();
    }
  }, 1000);
}

function shutdown(): void {
  if (shuttingDown) {
    return;
  }
  shuttingDown = true;
  if (parentWatch) {
    clearInterval(parentWatch);
    parentWatch = null;
  }
  if (child && child.exitCode === null && !child.killed) {
    child.kill("SIGTERM");
    return;
  }
  process.exit(0);
}

async function main(): Promise<void> {
  startParentWatch();

  const probe = await probeMuxAgentDevServer();
  if (probe.status === "matching") {
    process.stdout.write(`Reusing existing MuxAgent dev server at ${devUrl}\n`);
    return;
  }

  if (probe.status === "foreign") {
    const owner = probe.actualRoot ?? "an unknown workspace";
    process.stderr.write(
      `Port ${webPort} is already serving MuxAgent from ${owner}, not ${workspaceRoot}. Stop that dev server and try again.\n`,
    );
    process.exit(1);
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
    if (shuttingDown) {
      process.exit(0);
      return;
    }
    if (signal) {
      process.stderr.write(`Dev server exited from signal ${signal}\n`);
      process.exit(1);
    }
    process.exit(code ?? 0);
  });
}

process.on("SIGINT", shutdown);
process.on("SIGTERM", shutdown);
process.on("SIGHUP", shutdown);

void main().catch((error) => {
  const message = error instanceof Error ? error.message : String(error);
  process.stderr.write(`${message}\n`);
  process.exit(1);
});
