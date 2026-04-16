import { readFileSync, realpathSync } from "node:fs";
import path from "node:path";
import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

const workspaceRoot = realpathSync(__dirname);
const cargoManifestPath = path.resolve(__dirname, "src-tauri/Cargo.toml");
const cargoManifest = readFileSync(cargoManifestPath, "utf8");
const cargoVersionMatch = cargoManifest.match(/^version = "([^"]+)"$/m);

if (!cargoVersionMatch) {
  throw new Error(`Unable to resolve desktop version from ${cargoManifestPath}`);
}

const desktopVersion = cargoVersionMatch[1];

export default defineConfig({
  plugins: [react()],
  define: {
    __MUXAGENT_DESKTOP_VERSION__: JSON.stringify(desktopVersion),
  },
  resolve: {
    alias: {
      "@": path.resolve(__dirname, "src"),
    },
  },
  server: {
    host: "127.0.0.1",
    port: 4173,
    strictPort: true,
    headers: {
      "X-MuxAgent-Workspace-Root": workspaceRoot,
    },
  },
  preview: {
    host: "127.0.0.1",
    port: 4173,
    strictPort: true,
    headers: {
      "X-MuxAgent-Workspace-Root": workspaceRoot,
    },
  },
});
