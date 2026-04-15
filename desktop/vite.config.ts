import { realpathSync } from "node:fs";
import path from "node:path";
import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

const workspaceRoot = realpathSync(__dirname);

export default defineConfig({
  plugins: [react()],
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
