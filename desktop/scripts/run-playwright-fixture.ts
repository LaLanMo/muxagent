import net from "node:net";
import { spawn } from "node:child_process";

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

const [webPort, bridgePort] = await Promise.all([
  getAvailablePort(),
  getAvailablePort(),
]);

const child = spawn("playwright", ["test", "-c", "playwright.config.ts"], {
  stdio: "inherit",
  shell: true,
  env: {
    ...process.env,
    MUXAGENT_TEST_WEB_PORT: String(webPort),
    MUXAGENT_TEST_BRIDGE_PORT: String(bridgePort),
  },
});

child.once("exit", (code, signal) => {
  if (signal) {
    process.kill(process.pid, signal);
    return;
  }
  process.exit(code ?? 1);
});

child.once("error", (error) => {
  process.stderr.write(`${error.message}\n`);
  process.exit(1);
});
