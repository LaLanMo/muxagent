import { spawn, type ChildProcess } from "node:child_process";

const bridgePort = process.env.MUXAGENT_BRIDGE_PORT ?? "4174";
const webPort = process.env.MUXAGENT_WEB_PORT ?? "4173";
const bridgeOrigin =
  process.env.VITE_BRIDGE_ORIGIN?.trim() || `http://127.0.0.1:${bridgePort}`;

let shuttingDown = false;

function run(
  name: string,
  command: string,
  args: string[],
  extraEnv: Record<string, string> = {},
): ChildProcess {
  const child = spawn(command, args, {
    stdio: "inherit",
    env: {
      ...process.env,
      MUXAGENT_BRIDGE_MODE: process.env.MUXAGENT_BRIDGE_MODE ?? "fixture",
      MUXAGENT_BRIDGE_PORT: bridgePort,
      MUXAGENT_WEB_PORT: webPort,
      VITE_BRIDGE_ORIGIN: bridgeOrigin,
      ...extraEnv,
    },
  });

  child.on("error", (error) => {
    process.stderr.write(`${name} failed: ${error.message}\n`);
    process.exitCode = 1;
    shutdown();
  });

  child.on("exit", (code) => {
    if (shuttingDown) {
      return;
    }
    if (code && code !== 0) {
      process.stderr.write(`${name} exited with code ${code}\n`);
      process.exitCode = code;
    }
    shutdown();
  });

  return child;
}

async function waitForBridgeReady(): Promise<void> {
  const deadline = Date.now() + 20_000;
  while (Date.now() < deadline) {
    try {
      const response = await fetch(`${bridgeOrigin}/health`);
      if (response.ok) {
        return;
      }
    } catch {
      // Keep polling until the bridge is up.
    }
    await new Promise((resolve) => setTimeout(resolve, 100));
  }
  throw new Error("Bridge failed to become ready");
}

const bridge = run("bridge", "tsx", ["scripts/dev-bridge.ts"]);
let vite: ChildProcess | null = null;

void (async () => {
  await waitForBridgeReady();
  vite = run("vite", "vite", [
    "--host",
    "127.0.0.1",
    "--port", webPort,
    "--strictPort",
  ]);
})().catch((error) => {
  process.stderr.write(`${error instanceof Error ? error.message : String(error)}\n`);
  bridge.kill();
  process.exit(1);
});

function shutdown() {
  if (shuttingDown) {
    return;
  }
  shuttingDown = true;
  bridge.kill();
  vite?.kill();
}

process.on("SIGINT", shutdown);
process.on("SIGTERM", shutdown);
